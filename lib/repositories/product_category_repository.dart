import '../models/product_category.dart';

abstract interface class ProductCategoryRepository {
  Future<List<ProductCategory>> findAll();
  Future<ProductCategory?> findById(int id);
}