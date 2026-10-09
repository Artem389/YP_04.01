import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import 'supplier_repository.dart';

class PersistentSupplierRepository implements SupplierRepository {
  static const _key = 'suppliers_v1';
  final SharedPreferences _prefs;
  List<Supplier> _items = [];
  int _nextId = 1;
  bool _wasReset = false;
  bool get wasReset => _wasReset;

  PersistentSupplierRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _items = [...seedSuppliers];
      _nextId = seedSuppliers.length + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _items = list
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList();
      _nextId = _items.isEmpty
          ? 1
          : _items.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
      _items = [...seedSuppliers];
      _nextId = seedSuppliers.length + 1;
      _wasReset = true;
      _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_items.map((s) => s.toJson()).toList()),
    );
  }

  @override
  Future<PageResult<Supplier>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var rows = _items.where((s) => q.includeDeleted || !s.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where(
            (s) =>
                s.name.toLowerCase().contains(needle) ||
                s.email.toLowerCase().contains(needle),
          )
          .toList();
    }

    rows.sort(
      (a, b) => q.sortAscending
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
    );

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Supplier>[] : rows.sublist(from, to);

    return PageResult<Supplier>(
      items: items,
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<List<Supplier>> findAll() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_items.where((s) => !s.isDeleted));
  }

  @override
  Future<Supplier?> findById(int id) async {
    final i = _items.indexWhere((s) => s.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<Supplier> create(Supplier supplier) async {
    final created = Supplier(
      id: _nextId++,
      name: supplier.name,
      email: supplier.email,
      phone: supplier.phone,
    );
    _items.add(created);
    await _persist();
    return created;
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    final i = _items.indexWhere((s) => s.id == supplier.id);
    if (i == -1) throw StateError('Поставщик ${supplier.id} не найден');
    _items[i] = supplier;
    await _persist();
    return supplier;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i == -1) throw StateError('Поставщик $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _items.removeWhere((s) => s.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i == -1) throw StateError('Поставщик $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _items.indexWhere((s) => s.id == id && !s.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }

  @override
  Future<bool> emailExists(String email, {int? exceptId}) async {
    return _items.any(
      (s) => s.email.toLowerCase() == email.toLowerCase() && s.id != exceptId,
    );
  }

  @override
  Future<int> countLinkedProducts(int supplierId) async {
    // Реализация передаётся через callback из ProductRepository
    // (см. SupplierListNotifier в блоке 5).
    return 0;
  }
}
