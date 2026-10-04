import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/token_storage.dart';

class AuthRepository {
  final Dio _dio;
  final TokenStorage _tokens;
  AuthRepository(this._dio, this._tokens);

  Future<void> login(String username, String password) => guard(() async {
    final response = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: data['user'] as Map<String, dynamic>,
    );
  });

  Future<void> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) =>
      guard(() async {
        await _dio.post('/auth/register', data: {
          'username': username,
          'password': password,
          'email': email,
          'fullName': fullName,
        });
        await login(username, password);
      });

  Future<void> refresh() => guard(() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null) throw const UnauthorizedException();
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refresh},
    );
    final data = response.data as Map<String, dynamic>;
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: data['user'] as Map<String, dynamic>,
    );
  });

  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout', data: {'refreshToken': refresh});
      } catch (_) {/* сеть может быть недоступна — не критично */}
    }
    await _tokens.clear();
  }
}