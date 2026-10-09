import 'package:flutter/foundation.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import '../repositories/supplier_repository.dart';

class SupplierListNotifier extends ChangeNotifier {
  final SupplierRepository _repo;
  SupplierListNotifier(this._repo);

  List<Supplier> _items = [];
  bool _disposed = false;

  List<Supplier> get items => List.unmodifiable(_items);

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

  Supplier? byId(int id) {
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }
}
