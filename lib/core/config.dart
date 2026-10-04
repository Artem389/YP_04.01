/// Базовый адрес API. Задаётся при сборке:
///   flutter run -d chrome --web-port=5555 \
///     --dart-define=API_BASE_URL=http://localhost:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Срок жизни access-токена в секундах (совпадает с настройками сервера).
const accessTokenTtl = Duration(seconds: 900);