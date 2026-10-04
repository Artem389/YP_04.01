import 'package:flutter/foundation.dart';

import '../models/product_category.dart';
import '../models/supplier.dart';
import '../repositories/product_category_repository.dart';
import '../repositories/supplier_repository.dart';

/// Кэш справочников: категорий и поставщиков.
/// Загружается один раз и используется формами без повторных запросов.
class ReferenceDataNotifier extends ChangeNotifier {
  final ProductCategoryRepository _categories;
  final SupplierRepository _suppliers;

  ReferenceDataNotifier(this._categories, this._suppliers);

  List<ProductCategory> _cats = const [];
  List<Supplier> _sups = const [];
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  List<ProductCategory> get categories => _cats;
  List<Supplier> get suppliers => _sups;
  bool get isLoading => _loading;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_cats.isNotEmpty && _sups.isNotEmpty) return;
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final results = await Future.wait([
        _categories.findAll(),
        _suppliers.findAll(),
      ]);
      _cats = results[0] as List<ProductCategory>;
      _sups = results[1] as List<Supplier>;
    } catch (e) {
      _error = 'Не удалось загрузить справочники: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> invalidate() async {
    _cats = const [];
    _sups = const [];
    await ensureLoaded();
  }

  ProductCategory? categoryById(int id) {
    for (final c in _cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Supplier? supplierById(int id) {
    for (final s in _sups) {
      if (s.id == id) return s;
    }
    return null;
  }
}