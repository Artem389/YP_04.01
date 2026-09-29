import '../data/seed_data.dart';
import '../models/product_category.dart';
import 'product_category_repository.dart';

class InMemoryProductCategoryRepository implements ProductCategoryRepository {
  final List<ProductCategory> _categories = [...seedCategories];

  @override
  Future<List<ProductCategory>> findAll() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_categories);
  }

  @override
  Future<ProductCategory?> findById(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    return i == -1 ? null : _categories[i];
  }
}