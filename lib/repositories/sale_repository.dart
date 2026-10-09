import 'package:dio/dio.dart';

import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/sale.dart';

abstract interface class SaleRepository {
  Future<PageResult<Sale>> find(
      ProductQuery query, {
        CancelToken? cancelToken,
      });
  Future<Sale> create({
    required int customerId,
    required int productId,
    required int quantity,
  });
  Future<Sale> close(int saleId);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}