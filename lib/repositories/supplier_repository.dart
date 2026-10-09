import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';

import 'package:dio/dio.dart';

abstract interface class SupplierRepository {
  Future<PageResult<Supplier>> find(
    ProductQuery query, {
    CancelToken? cancelToken,
  });
  Future<List<Supplier>> findAll();
  Future<Supplier?> findById(int id);
  Future<Supplier> create(Supplier supplier);
  Future<Supplier> update(Supplier supplier);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<bool> emailExists(String email, {int? exceptId});
  Future<int> countLinkedProducts(int supplierId);
}
