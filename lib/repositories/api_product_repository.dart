import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';

class ApiProductRepository implements ProductRepository {
  final Dio _dio;
  ApiProductRepository(this._dio);

  @override
  Future<PageResult<Product>> find(
      ProductQuery q, {
        CancelToken? cancelToken,
      }) =>
      guard(() async {
        final response = await _dio.get(
          '/products',
          cancelToken: cancelToken,
          queryParameters: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            if (q.categoryId != null) 'categoryId': q.categoryId,
            if (q.supplierId != null) 'supplierId': q.supplierId,
            if (q.priceFrom != null) 'priceFrom': q.priceFrom,
            if (q.priceTo != null) 'priceTo': q.priceTo,
            'sort': '${_sortField(q.sortField)},${q.sortAscending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,

            // '__fail': 500,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult<Product>(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Product.fromJson)
              .toList(),
          page: (data['page'] as num?)?.toInt() ?? 1,
          size: (data['size'] as num?)?.toInt() ?? q.size,
          total: (data['total'] as num?)?.toInt() ?? 0,
        );
      });

  /// Локальное имя поля → имя, которое понимает сервер.
  String _sortField(String local) => switch (local) {
    'price' => 'price',
    'weight' => 'weightGr',
    'stock' => 'stockAvailable',
    _ => 'name',
  };

  @override
  Future<Product?> findById(int id) => guard(() async {
    final response = await _dio.get(
      '/products/$id',
      queryParameters: {'includeDeleted': true},
    );
    return Product.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Product> create(Product product) => guard(() async {
    final response = await _dio.post('/products', data: product.toInputJson());
    return Product.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Product> update(Product product) => guard(() async {
    final response = await _dio.put(
      '/products/${product.id}',
      data: product.toInputJson(),
    );
    return Product.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/products/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
        () => _dio.delete('/products/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/products/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response =
    await _dio.post('/products/bulk-delete', data: {'ids': ids});
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });

  @override
  Future<int> countByCategory(int categoryId) => guard(() async {
    final response = await _dio.get(
      '/products',
      queryParameters: {
        'categoryId': categoryId,
        'size': 1,        // вернём одну запись — считаем только total
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<int> countBySupplier(int supplierId) => guard(() async {
    final response = await _dio.get(
      '/products',
      queryParameters: {
        'supplierId': supplierId,
        'size': 1,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<List<int>> supplierIdsOf(int productId) => guard(() async {
    final p = await findById(productId);
    return p?.supplierIds ?? const [];
  });

  @override
  Future<bool> skuExists(String sku, {int? exceptId}) => guard(() async {
    final response = await _dio.get(
      '/products',
      queryParameters: {'search': sku, 'size': 100},
    );
    final data = response.data as Map<String, dynamic>;
    final list = (data['items'] as List).whereType<Map<String, dynamic>>();
    return list.any((m) =>
    (m['isbn'] as String?)?.toLowerCase() == sku.toLowerCase() &&
        (m['id'] as num?)?.toInt() != exceptId);
  });
}