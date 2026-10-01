// lib/repositories/product_category_repository.dart
import '../models/page_result.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';

abstract interface class ProductCategoryRepository {
  Future<PageResult<ProductCategory>> find(ProductQuery query);
  Future<List<ProductCategory>> findAll();
  Future<ProductCategory?> findById(int id);
  Future<ProductCategory> create(ProductCategory category);
  Future<ProductCategory> update(ProductCategory category);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<bool> nameExists(String name, {int? exceptId});
}