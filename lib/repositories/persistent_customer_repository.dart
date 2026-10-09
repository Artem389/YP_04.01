import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import 'customer_repository.dart';

class PersistentCustomerRepository implements CustomerRepository {
  static const _key = 'customers_v1';
  final SharedPreferences _prefs;
  List<Customer> _items = [];
  int _nextId = 1;
  bool _wasReset = false;
  bool get wasReset => _wasReset;

  PersistentCustomerRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _items = [...seedCustomers];
      _nextId = seedCustomers.length + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _items = list
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
      _nextId = _items.isEmpty
          ? 1
          : _items.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
      _items = [...seedCustomers];
      _nextId = seedCustomers.length + 1;
      _wasReset = true;
      _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_items.map((c) => c.toJson()).toList()),
    );
  }

  @override
  Future<PageResult<Customer>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var rows = _items.where((c) => q.includeDeleted || !c.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where(
            (c) =>
                c.fullName.toLowerCase().contains(needle) ||
                c.email.toLowerCase().contains(needle) ||
                c.phone.contains(needle),
          )
          .toList();
    }

    rows.sort(
      (a, b) => q.sortAscending
          ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
          : b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()),
    );

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Customer>[] : rows.sublist(from, to);

    return PageResult<Customer>(
      items: items,
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<Customer?> findById(int id) async {
    final i = _items.indexWhere((c) => c.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<Customer> create(Customer customer) async {
    final created = Customer(
      id: _nextId++,
      fullName: customer.fullName,
      email: customer.email,
      phone: customer.phone,
      card: customer.card,
    );
    _items.add(created);
    await _persist();
    return created;
  }

  @override
  Future<Customer> update(Customer customer) async {
    final i = _items.indexWhere((c) => c.id == customer.id);
    if (i == -1) throw StateError('Покупатель ${customer.id} не найден');
    _items[i] = customer;
    await _persist();
    return customer;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Покупатель $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _items.removeWhere((c) => c.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Покупатель $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _items.indexWhere((c) => c.id == id && !c.isDeleted);
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
      (c) => c.email.toLowerCase() == email.toLowerCase() && c.id != exceptId,
    );
  }
}
