import 'package:dio/dio.dart';

/// Базовый класс всех прикладных ошибок.
/// Виджеты работают только с ним и никогда не видят `DioException`.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Сеть недоступна, таймаут, CORS, сервер выключен.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Сервер недоступен. Проверьте соединение.']);
}

/// 401 — не аутентифицирован либо истёк токен.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Недостаточно прав для этого действия.']);
}

/// 404.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям.
class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

/// 5xx.
class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

/// Преобразование HTTP-кода в исключение предметной области.
ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(message ?? 'Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
      message ?? 'Ошибка валидации',
      (body is Map && body['errors'] is Map)
          ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : const {},
    ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

/// Разбор `DioException`, пришедшего из интерсептора или сетевого слоя.
ApiException mapDioError(DioException e) {
  // Если интерсептор уже положил сюда прикладное исключение — используем его.
  // Без этой проверки 422 придёт как ServerException, и обработчик
  // `on ValidationException` никогда не сработает.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
    const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
          'Если сервер запущен, откройте консоль браузера и проверьте ошибку CORS.',
    ),
    DioExceptionType.cancel => const NetworkException('Запрос отменён.'),
    DioExceptionType.badResponse => mapHttpError(
      e.response?.statusCode ?? 500,
      e.response?.data,
    ),
    _ => const ServerException(),
  };
}

/// Обёртка над любым сетевым вызовом: гарантирует, что наружу
/// уйдёт только ApiException, а не DioException.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}