import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Хранит access- и refresh-токены в localStorage.
class TokenStorage {
  static const _kAccess = 'auth_access_token_v1';
  static const _kRefresh = 'auth_refresh_token_v1';
  static const _kUser = 'auth_user_v1';

  final SharedPreferences _prefs;
  TokenStorage(this._prefs);

  String? get accessToken => _prefs.getString(_kAccess);
  String? get refreshToken => _prefs.getString(_kRefresh);

  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    await _prefs.setString(_kAccess, accessToken);
    await _prefs.setString(_kRefresh, refreshToken);
    await _prefs.setString(_kUser, jsonEncode(user));
  }

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
  }
}
