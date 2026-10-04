import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import 'customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  final Dio _dio;
  ApiCustomerRepository(this._dio);

  @override
  Future<PageResult<Customer>> find(
      ProductQuery q, {
        CancelToken? cancelToken,
      }) =>
      guard(() async {
        final response = await _dio.get(
          '/customers',
          cancelToken: cancelToken,
          queryParameters: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            'sort': 'fullName,${q.sortAscending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult<Customer>(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Customer.fromJson)
              .toList(),
          page: (data['page'] as num?)?.toInt() ?? 1,
          size: (data['size'] as num?)?.toInt() ?? q.size,
          total: (data['total'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<Customer?> findById(int id) => guard(() async {
    final response = await _dio.get('/customers/$id');
    return Customer.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Customer> create(Customer c) => guard(() async {
    final response =
    await _dio.post('/customers', data: c.toInputJson());
    return Customer.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Customer> update(Customer c) => guard(() async {
    final response =
    await _dio.put('/customers/${c.id}', data: c.toInputJson());
    return Customer.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/customers/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
        () => _dio.delete('/customers/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/customers/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response =
    await _dio.post('/customers/bulk-delete', data: {'ids': ids});
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });

  @override
  Future<bool> emailExists(String email, {int? exceptId}) => guard(() async {
    final response = await _dio.get(
      '/customers',
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
}