import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/product_query.dart';
import '../repositories/customer_repository.dart';

class CustomerListNotifier extends ChangeNotifier {
  final CustomerRepository _repo;
  CustomerListNotifier(this._repo);

  List<Customer> _items = [];
  bool _disposed = false;

  List<Customer> get items => List.unmodifiable(_items);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final result = await _repo.find(const ProductQuery(size: 1000));
    _items = result.items;
    _safeNotify();
  }

  Customer? byId(int id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }
}