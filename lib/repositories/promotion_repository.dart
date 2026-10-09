import 'package:dio/dio.dart';

import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/promotion.dart';

abstract interface class PromotionRepository {
  Future<PageResult<Promotion>> find(
      ProductQuery query, {
        CancelToken? cancelToken,
      });
  Future<List<Promotion>> findAll();
  Future<Promotion?> findById(int id);
  Future<Promotion> create(Promotion promotion);
  Future<Promotion> update(Promotion promotion);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}