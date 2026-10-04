import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';
import 'token_storage.dart';

/// Собирает Dio со всеми интерсепторами:
///
/// * добавляет заголовок `Authorization`;
/// * разбирает 4xx в прикладные исключения;
/// * журналирует запросы в режиме отладки;
/// * выполняет авто-повтор для идемпотентных методов (GET/HEAD).
Dio buildDio({
  required TokenStorage tokens,
  Future<bool> Function()? onRefreshToken,
  Future<void> Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на коды 4xx — разберём их сами.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // ─── Автоповтор при сетевых сбоях (только для чтения) ─────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final isRead = error.requestOptions.method.toUpperCase() == 'GET';
        final canRetry = isRead &&
            (error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout);

        final attempt =
            (error.requestOptions.extra['__retry'] as int?) ?? 0;

        if (canRetry && attempt < 3) {
          final delayMs = (pow(2, attempt) * 300).toInt();
          await Future.delayed(Duration(milliseconds: delayMs));
          final options = error.requestOptions;
          options.extra['__retry'] = attempt + 1;
          try {
            final response = await dio.fetch(options);
            return handler.resolve(response);
          } on DioException catch (e) {
            return handler.next(e);
          }
        }
        return handler.next(error);
      },
    ),
  );

  // ─── Авторизация и обновление токена ──────────────────────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokens.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        final status = response.statusCode ?? 0;

        // 401 → пробуем обновить токен один раз.
        if (status == 401 && onRefreshToken != null) {
          final refreshed = await onRefreshToken();
          if (refreshed) {
            final options = response.requestOptions;
            options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
            try {
              final retried = await dio.fetch(options);
              return handler.resolve(retried);
            } on DioException catch (e) {
              return handler.reject(e, true);
            }
          } else {
            await onUnauthorized?.call();
          }
        }

        // Коды 4xx попадают сюда, а не в onError — из-за validateStatus.
        if (status >= 400) {
          // Нельзя бросать исключение из интерсептора: Dio завернёт его
          // в DioException типа unknown, и наш ValidationException окажется
          // спрятан внутри поля error. Поэтому отправляем ответ по ветке
          // ошибок сами, приложив уже разобранное исключение.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
    ),
  );

  // ─── Журналирование в режиме отладки ──────────────────────────────────
  if (kDebugMode) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('[API →] ${options.method} ${options.uri}');
          if (options.queryParameters.isNotEmpty) {
            debugPrint('        query: ${options.queryParameters}');
          }
          if (options.data != null && options.data is Map) {
            debugPrint('        body:  ${options.data}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[API ←] ${response.statusCode} ${response.requestOptions.uri}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
            '[API ✗] ${error.type} ${error.requestOptions.uri} '
                '${error.response?.statusCode ?? ''}',
          );
          return handler.next(error);
        },
      ),
    );
  }

  return dio;
}