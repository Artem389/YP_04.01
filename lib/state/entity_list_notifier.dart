import 'package:flutter/foundation.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';

enum LoadStatus { idle, loading, success, error }

/// Обобщённый нотифаер для списка любой сущности.
/// Используется для поставщиков, покупателей, категорий.
class EntityListNotifier<T> extends ChangeNotifier {
  final Future<PageResult<T>> Function(ProductQuery) _fetcher;
  final Future<int> Function(List<int>)? _deleteMany;

  EntityListNotifier({
    required Future<PageResult<T>> Function(ProductQuery) fetcher,
    Future<int> Function(List<int>)? deleteMany,
  })  : _fetcher = fetcher,
        _deleteMany = deleteMany;

  ProductQuery _query = const ProductQuery();
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  bool _disposed = false;

  ProductQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    // Откладываем уведомление, если мы внутри build/didUpdateWidget.
    // Это безопасная и дешёвая защита от частой ошибки.
    Future.microtask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _result = await _fetcher(_query);
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(ProductQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  Future<void> deleteSelected() async {
    if (_deleteMany == null) return;
    await _deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }
}