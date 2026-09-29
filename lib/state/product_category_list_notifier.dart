import 'package:flutter/foundation.dart';
import '../models/product_category.dart';
import '../repositories/product_category_repository.dart';

enum ProductCategoryStatus { idle, loading, success, error }

class ProductCategoryListNotifier extends ChangeNotifier {
  final ProductCategoryRepository _repository;
  ProductCategoryListNotifier(this._repository);

  List<ProductCategory> _categories = [];
  ProductCategoryStatus _status = ProductCategoryStatus.idle;
  String? _error;
  bool _disposed = false;

  List<ProductCategory> get categories => List.unmodifiable(_categories);
  ProductCategoryStatus get status => _status;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _status = ProductCategoryStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _categories = await _repository.findAll();
      _status = ProductCategoryStatus.success;
    } catch (e) {
      _error = 'Ошибка загрузки категорий: $e';
      _status = ProductCategoryStatus.error;
    }
    _safeNotify();
  }

  ProductCategory? byId(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}