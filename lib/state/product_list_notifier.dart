import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../repositories/product_repository.dart';
import 'entity_list_notifier.dart' show LoadStatus;

class ProductListNotifier extends ChangeNotifier {
  final ProductRepository _repository;
  ProductListNotifier(this._repository);

  ProductQuery _query = const ProductQuery();
  PageResult<Product> _result = PageResult<Product>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  bool _disposed = false;

  /// Токен для отмены устаревших запросов.
  CancelToken? _inflight;

  /// Монотонный счётчик: помогает отбросить запоздавший ответ,
  /// если отмена не успела сработать.
  int _loadSeq = 0;

  ProductQuery get query => _query;
  PageResult<Product> get result => _result;
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
    // Отменяем предыдущий запрос: пользователь уже набрал новый текст
    // и ждёт свежий результат.
    _inflight?.cancel('новый запрос');
    final token = CancelToken();
    _inflight = token;
    final seq = ++_loadSeq;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final page = await _repository.find(_query, cancelToken: token);
      if (_disposed || seq != _loadSeq) return; // ответ устарел
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
    await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }
}
