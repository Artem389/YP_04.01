// lib/repositories/persistent_product_category_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import 'product_category_repository.dart';

class PersistentProductCategoryRepository
    implements ProductCategoryRepository {
  static const _key = 'categories_v2';   // <-- подняли версию
  final SharedPreferences _prefs;
  List<ProductCategory> _categories = [];
  int _nextId = 1;
  bool _wasReset = false;
  bool get wasReset => _wasReset;

  PersistentProductCategoryRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _categories = [...seedCategories];
      _nextId = seedCategories.length + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _categories = list
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      _nextId = _categories.isEmpty
          ? 1
          : _categories.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
      _categories = [...seedCategories];
      _nextId = seedCategories.length + 1;
      _wasReset = true;
      _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_categories.map((c) => c.toJson()).toList()),
    );
  }

  @override
  Future<PageResult<ProductCategory>> find(ProductQuery q) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var rows = _categories
        .where((c) => q.includeDeleted || !c.isDeleted)
        .toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((c) =>
      c.name.toLowerCase().contains(needle) ||
          c.description.toLowerCase().contains(needle))
          .toList();
    }

    rows.sort((a, b) {
      final r = switch (q.sortField) {
        'description' =>
            a.description.toLowerCase().compareTo(b.description.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? r : -r;
    });

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <ProductCategory>[] : rows.sublist(from, to);

    return PageResult<ProductCategory>(
      items: items,
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<List<ProductCategory>> findAll() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_categories.where((c) => !c.isDeleted));
  }

  @override
  Future<ProductCategory?> findById(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    return i == -1 ? null : _categories[i];
  }

  @override
  Future<ProductCategory> create(ProductCategory category) async {
    final created = ProductCategory(
      id: _nextId++,
      name: category.name,
      description: category.description,
    );
    _categories.add(created);
    await _persist();
    return created;
  }

  @override
  Future<ProductCategory> update(ProductCategory category) async {
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i == -1) throw StateError('Категория ${category.id} не найдена');
    _categories[i] = category;
    await _persist();
    return category;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Категория $id не найдена');
    _categories[i] = _categories[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _categories.removeWhere((c) => c.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _categories.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Категория $id не найдена');
    _categories[i] = _categories[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _categories.indexWhere((c) => c.id == id && !c.isDeleted);
      if (i != -1) {
        _categories[i] = _categories[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }

  @override
  Future<bool> nameExists(String name, {int? exceptId}) async {
    return _categories.any((c) =>
    c.name.toLowerCase() == name.toLowerCase() && c.id != exceptId);
  }
}