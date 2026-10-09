import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import 'product_category_repository.dart';

class ApiProductCategoryRepository implements ProductCategoryRepository {
  final Dio _dio;
  ApiProductCategoryRepository(this._dio);

  @override
  Future<PageResult<ProductCategory>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) => guard(() async {
    final response = await _dio.get(
      '/categories',
      cancelToken: cancelToken,
      queryParameters: {
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        'sort':
            '${q.sortField == 'description' ? 'description' : 'name'},'
            '${q.sortAscending ? 'asc' : 'desc'}',
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PageResult<ProductCategory>(
      items: (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductCategory.fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      size: (data['size'] as num?)?.toInt() ?? q.size,
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  });

  @override
  Future<List<ProductCategory>> findAll() => guard(() async {
    final response = await _dio.get(
      '/categories',
      queryParameters: {'size': 100},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ProductCategory.fromJson)
        .toList();
  });

  @override
  Future<ProductCategory?> findById(int id) => guard(() async {
    final response = await _dio.get('/categories/$id');
    return ProductCategory.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<ProductCategory> create(ProductCategory c) => guard(() async {
    final response = await _dio.post('/categories', data: c.toInputJson());
    return ProductCategory.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<ProductCategory> update(ProductCategory c) => guard(() async {
    final response = await _dio.put(
      '/categories/${c.id}',
      data: c.toInputJson(),
    );
    return ProductCategory.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/categories/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
    () => _dio.delete('/categories/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/categories/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await _dio.post(
      '/categories/bulk-delete',
      data: {'ids': ids},
    );
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });

  @override
  Future<bool> nameExists(String name, {int? exceptId}) => guard(() async {
    final response = await _dio.get(
      '/categories',
      queryParameters: {'search': name, 'size': 100},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List).whereType<Map<String, dynamic>>().any(
      (m) =>
          (m['name'] as String?)?.toLowerCase() == name.toLowerCase() &&
          (m['id'] as num?)?.toInt() != exceptId,
    );
  });
}
