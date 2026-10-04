// lib/repositories/persistent_product_repository.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';

class PersistentProductRepository implements ProductRepository {
  static const _key = 'products_v1';
  final SharedPreferences _prefs;
  List<Product> _products = [];
  int _nextId = 1;
  bool _wasReset = false;
  bool get wasReset => _wasReset;

  PersistentProductRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _products = [...seedProducts];
      _nextId = seedProducts.length + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _products = list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      _nextId = _products.isEmpty
          ? 1
          : _products.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
      // Данные испорчены или формат изменился — начинаем заново.
      _products = [...seedProducts];
      _nextId = seedProducts.length + 1;
      _wasReset = true;
      _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_products.map((p) => p.toJson()).toList()),
    );
  }

  @override
  Future<PageResult<Product>> find(ProductQuery q, {
    CancelToken? cancelToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));

    var rows = _products.where((p) => q.includeDeleted || !p.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((p) =>
      p.name.toLowerCase().contains(needle) ||
          p.sku.toLowerCase().contains(needle))
          .toList();
    }
    if (q.categoryId != null) {
      rows = rows.where((p) => p.categoryId == q.categoryId).toList();
    }
    if (q.supplierId != null) {
      rows = rows
          .where((p) => p.supplierIds.contains(q.supplierId))
          .toList();
    }
    if (q.priceFrom != null) {
      rows = rows.where((p) => p.price >= q.priceFrom!).toList();
    }
    if (q.priceTo != null) {
      rows = rows.where((p) => p.price <= q.priceTo!).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'price' => a.price.compareTo(b.price),
        'weight' => a.weightGr.compareTo(b.weightGr),
        'stock' => a.stockAvailable.compareTo(b.stockAvailable),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Product>[] : rows.sublist(from, to);

    return PageResult<Product>(
      items: items,
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<Product?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _products.indexWhere((p) => p.id == id);
    return i == -1 ? null : _products[i];
  }

  @override
  Future<Product> create(Product product) async {
    final created = product.copyWith(); // id присвоим вручную
    final withId = Product(
      id: _nextId++,
      name: created.name,
      sku: created.sku,
      price: created.price,
      weightGr: created.weightGr,
      categoryId: created.categoryId,
      supplierIds: created.supplierIds,
      stockTotal: created.stockTotal,
      stockAvailable: created.stockAvailable,
    );
    _products.add(withId);
    await _persist();
    return withId;
  }

  @override
  Future<Product> update(Product product) async {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i == -1) throw StateError('Товар ${product.id} не найден');
    _products[i] = product;
    await _persist();
    return product;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _products[i] = _products[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _products.removeWhere((p) => p.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _products[i] = _products[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _products.indexWhere((p) => p.id == id && !p.isDeleted);
      if (i != -1) {
        _products[i] = _products[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }

  /// Проверка уникальности артикула (ПР3, п.12).
  Future<bool> skuExists(String sku, {int? exceptId}) async {
    return _products.any((p) =>
    p.sku.toLowerCase() == sku.toLowerCase() && p.id != exceptId);
  }

  @override
  Future<int> countByCategory(int categoryId) async {
    return _products
        .where((p) => p.categoryId == categoryId && !p.isDeleted)
        .length;
  }

  @override
  Future<int> countBySupplier(int supplierId) async {
    return _products
        .where((p) => p.supplierIds.contains(supplierId) && !p.isDeleted)
        .length;
  }

  @override
  Future<List<int>> supplierIdsOf(int productId) async {
    final p = _products.firstWhere((p) => p.id == productId);
    return p.supplierIds;
  }
}