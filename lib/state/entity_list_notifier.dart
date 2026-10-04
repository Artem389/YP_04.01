import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';

enum LoadStatus { idle, loading, success, error }

class EntityListNotifier<T> extends ChangeNotifier {
  final Future<PageResult<T>> Function(
      ProductQuery query, {
      CancelToken? cancelToken,
      }) _fetcher;
  final Future<int> Function(List<int>)? _deleteMany;

  EntityListNotifier({
    required Future<PageResult<T>> Function(
        ProductQuery query, {
        CancelToken? cancelToken,
        }) fetcher,
    Future<int> Function(List<int>)? deleteMany,
  })  : _fetcher = fetcher,
        _deleteMany = deleteMany;

  ProductQuery _query = const ProductQuery();
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  bool _disposed = false;
  CancelToken? _inflight;
  int _loadSeq = 0;

  ProductQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    _inflight?.cancel('disposed');
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _inflight?.cancel('новый запрос');
    final token = CancelToken();
    _inflight = token;
    final seq = ++_loadSeq;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final page = await _fetcher(_query, cancelToken: token);
      if (_disposed || seq != _loadSeq) return;
      _result = page;
      _status = LoadStatus.success;
    } on ApiException catch (e) {
      if (_disposed || seq != _loadSeq) return;
      if (e is NetworkException && e.message.contains('отменён')) return;
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      if (_disposed || seq != _loadSeq) return;
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