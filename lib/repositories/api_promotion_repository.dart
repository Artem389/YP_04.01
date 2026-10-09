import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/promotion.dart';
import 'promotion_repository.dart';

class ApiPromotionRepository implements PromotionRepository {
  final Dio _dio;
  ApiPromotionRepository(this._dio);

  @override
  Future<PageResult<Promotion>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) => guard(() async {
    final response = await _dio.get(
      '/promotions',
      cancelToken: cancelToken,
      queryParameters: {
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        'sort': 'name,${q.sortAscending ? 'asc' : 'desc'}',
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PageResult<Promotion>(
      items: (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Promotion.fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      size: (data['size'] as num?)?.toInt() ?? q.size,
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  });

  @override
  Future<List<Promotion>> findAll() => guard(() async {
    final response = await _dio.get(
      '/promotions',
      queryParameters: {'size': 100},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Promotion.fromJson)
        .toList();
  });

  @override
  Future<Promotion?> findById(int id) => guard(() async {
    final response = await _dio.get('/promotions/$id');
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Promotion> create(Promotion p) => guard(() async {
    final response = await _dio.post('/promotions', data: p.toInputJson());
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<Promotion> update(Promotion p) => guard(() async {
    final response = await _dio.put(
      '/promotions/${p.id}',
      data: p.toInputJson(),
    );
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/promotions/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
    () => _dio.delete('/promotions/$id', queryParameters: {'hard': true}),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/promotions/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await _dio.post(
      '/promotions/bulk-delete',
      data: {'ids': ids},
    );
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });
}
