import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/role.dart';
import '../core/token_storage.dart';
import '../repositories/auth_repository.dart';

/// Модель пользователя приложения.
class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final Role role;
  final int? customerId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.customerId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: (json['username'] ?? '') as String,
    fullName: (json['fullName'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    role: Role.parse(json['role'] as String?),
    customerId: (json['customerId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.wire,
    'customerId': customerId,
  };
}

/// Состояние аутентификации + таймеры сессии.
/// Реализует пункты 13–16 ПР5.
class AuthNotifier extends ChangeNotifier {
  final AuthRepository _api;
  final TokenStorage _tokens;

  AuthNotifier(this._api, this._tokens);

  AppUser? _user;
  bool _restored = false;
  bool _busy = false;
  String? _error;

  /// Таймер общей длительности сессии (п. 15).
  Timer? _sessionTimer;

  /// Таймер неактивности (п. 14).
  Timer? _inactivityTimer;

  /// Таймер предупреждения о скором выходе.
  Timer? _warningTimer;

  /// Колбэк, который вызовется при завершении сессии (для показа диалога).
  void Function(String reason)? onSessionExpired;

  /// Общая длительность сессии и таймаут неактивности.
  static const sessionLifetime = Duration(minutes: 30);
  static const inactivityTimeout = Duration(minutes: 3);
  static const warningBefore = Duration(seconds: 30);

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isRestored => _restored;

  /// Есть ли у пользователя роль не ниже указанной.
  bool has(Role min) => _user != null && _user!.role.allows(min);

  /// Только для тестов: подставить пользователя без обращения к сети.
  @visibleForTesting
  void debugSetUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }
  // ─────────────────────────── восстановление сессии ─────────────────────

  /// Вызывается один раз при старте приложения.
  Future<void> restore() async {
    final access = _tokens.accessToken;
    if (access == null) {
      _restored = true;
      notifyListeners();
      return;
    }

    // Пытаемся получить актуальные данные пользователя.
    try {
      final json = await _api.me();
      _user = AppUser.fromJson(json);
      _startSessionTimers();
    } on UnauthorizedException {
      // Токен истёк — пробуем обновить.
      try {
        await _api.refresh();
        final json = await _api.me();
        _user = AppUser.fromJson(json);
        _startSessionTimers();
      } catch (_) {
        await _clearLocal();
      }
    } catch (_) {
      // Сервер недоступен: не разлогиниваем, но пользователя не показываем.
      // При следующем запросе интерсептор обновит токен.
      final saved = _tokens.user;
      if (saved != null) {
        _user = AppUser.fromJson(saved);
        _startSessionTimers();
      }
    }

    _restored = true;
    notifyListeners();
  }

  // ───────────────────────────── вход/выход ──────────────────────────────

  Future<void> login(String username, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.login(username, password);
      _user = AppUser.fromJson(result['user'] as Map<String, dynamic>);
      _startSessionTimers();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.register(
        username: username,
        password: password,
        email: email,
        fullName: fullName,
      );
      _user = AppUser.fromJson(_tokens.user!);
      _startSessionTimers();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopSessionTimers();
    try {
      await _api.logout();
    } finally {
      await _clearLocal();
      notifyListeners();
    }
  }

  Future<void> _clearLocal() async {
    _user = null;
    await _tokens.clear();
  }

  /// Вызывается интерсептором после успешного обновления токена.
  /// Обновляет пользователя и перезапускает таймеры.
  Future<void> onTokensRefreshed() async {
    final saved = _tokens.user;
    if (saved != null) {
      _user = AppUser.fromJson(saved);
    }
    _startSessionTimers();
    notifyListeners();
  }

  // ──────────────────────────── таймеры (п. 14, 15) ──────────────────────

  void _startSessionTimers() {
    _stopSessionTimers();

    // Общая длительность сессии.
    _sessionTimer = Timer(sessionLifetime, () {
      onSessionExpired?.call('Сессия истекла. Войдите заново.');
      logout();
    });

    // Таймер неактивности запускается сразу.
    _restartInactivity();
  }

  /// Сброс таймера неактивности. Вызывается на любое действие пользователя
  /// (см. InactivityWatcher).
  void _restartInactivity() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();

    final warningAt = inactivityTimeout - warningBefore;
    if (warningAt > Duration.zero) {
      _warningTimer = Timer(warningAt, () {
        onSessionExpired?.call(
          'Через 30 секунд сессия будет завершена из-за неактивности.',
        );
      });
    }

    _inactivityTimer = Timer(inactivityTimeout, () {
      onSessionExpired?.call('Сессия завершена из-за неактивности.');
      logout();
    });
  }

  /// Публичный метод — вызывается виджетом InactivityWatcher.
  void onUserActivity() {
    if (_user == null) return;
    _restartInactivity();
  }

  void _stopSessionTimers() {
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _sessionTimer = null;
    _inactivityTimer = null;
    _warningTimer = null;
  }

  @override
  void dispose() {
    _stopSessionTimers();
    super.dispose();
  }
}
