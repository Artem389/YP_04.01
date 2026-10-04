import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import 'supplier_repository.dart';

class ApiSupplierRepository implements SupplierRepository {
  final Dio _dio;
  ApiSupplierRepository(this._dio);

  @override
  Future<PageResult<Supplier>> find(
      ProductQuery q, {
        CancelToken? cancelToken,
      }) =>
      guard(() async {
        final response = await _dio.get(
          '/suppliers',
          cancelToken: cancelToken,
          queryParameters: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            'sort': '${q.sortField == 'name' ? 'name' : 'name'},'
                '${q.sortAscending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult<Supplier>(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Supplier.fromJson)
              .toList(),
          page: (data['page'] as num?)?.toInt() ?? 1,
          size: (data['size'] as num?)?.toInt() ?? q.size,
          total: (data['total'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<List<Supplier>> findAll() => guard(() async {
    final response =
    await _dio.get('/suppliers', queryParameters: {'size': 100});
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Supplier.fromJson)
        .toList();
  });

  @override
  Future<Supplier?> findById(int id) => guard(() async {
    final response = await _dio.get('/suppliers/$id');
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Supplier> create(Supplier s) => guard(() async {
    final response =
    await _dio.post('/suppliers', data: s.toInputJson());
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Supplier> update(Supplier s) => guard(() async {
    final response =
    await _dio.put('/suppliers/${s.id}', data: s.toInputJson());
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/suppliers/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
        () => _dio.delete('/suppliers/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/suppliers/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response =
    await _dio.post('/suppliers/bulk-delete', data: {'ids': ids});
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });

  @override
  Future<bool> emailExists(String email, {int? exceptId}) => guard(() async {
    // Проверяем по email (в нашей модели email = email).
    final response = await _dio.get(
      '/suppliers',
      queryParameters: {'search': email, 'size': 100},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List).whereType<Map<String, dynamic>>().any(
          (m) =>
      (m['email'] as String?)?.toLowerCase() ==
          email.toLowerCase() &&
          (m['id'] as num?)?.toInt() != exceptId,
    );
  });

  @override
  Future<int> countLinkedProducts(int supplierId) => guard(() async {
    final response = await _dio.get(
      '/products',
      queryParameters: {'supplierId': supplierId, 'size': 1},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  });
}