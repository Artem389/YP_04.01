import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/sale.dart';
import 'sale_repository.dart';

class ApiSaleRepository implements SaleRepository {
  final Dio _dio;
  ApiSaleRepository(this._dio);

  @override
  Future<PageResult<Sale>> find(
      ProductQuery q, {
        CancelToken? cancelToken,
      }) =>
      guard(() async {
        final response = await _dio.get(
          '/sales',
          cancelToken: cancelToken,
          queryParameters: {
            'sort': 'soldAt,${q.sortAscending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult<Sale>(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Sale.fromJson)
              .toList(),
          page: (data['page'] as num?)?.toInt() ?? 1,
          size: (data['size'] as num?)?.toInt() ?? q.size,
          total: (data['total'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<Sale> create({
    required int customerId,
    required int productId,
    required int quantity,
  }) =>
      guard(() async {
        final response = await _dio.post('/sales', data: {
          'customerId': customerId,
          'productId': productId,
          'quantity': quantity,
        });
        return Sale.fromJson(response.data as Map<String, dynamic>);
      });

  @override
  Future<Sale> close(int saleId) => guard(() async {
    final response = await _dio.post('/sales/$saleId/close');
    return Sale.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) => guard(() => _dio.delete('/sales/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
        () => _dio.delete('/sales/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/sales/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response =
    await _dio.post('/sales/bulk-delete', data: {'ids': ids});
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });
}