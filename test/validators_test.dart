import 'package:flutter_project_web/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V.required', () {
    test('пусто и пробелы отклоняются', () {
      expect(V.required()(''), isNotNull);
      expect(V.required()('   '), isNotNull);
    });
    test('непустая строка принимается', () {
      expect(V.required()('Молоко'), isNull);
    });
  });

  group('V.length', () {
    test('ниже минимума — ошибка', () {
      expect(V.length(min: 3)('ab'), isNotNull);
    });
    test('в диапазоне — ok', () {
      expect(V.length(min: 2, max: 5)('abc'), isNull);
    });
    test('выше максимума — ошибка', () {
      expect(V.length(max: 3)('abcd'), isNotNull);
    });
  });

  group('V.integer', () {
    test('не число — ошибка', () {
      expect(V.integer()('abc'), isNotNull);
    });
    test('меньше минимума — ошибка', () {
      expect(V.integer(min: 10)('5'), isNotNull);
    });
    test('в диапазоне — ok', () {
      expect(V.integer(min: 1, max: 100)('50'), isNull);
    });
  });

  group('V.email', () {
    test('некорректный — ошибка', () {
      expect(V.email()('not-an-email'), isNotNull);
    });
    test('корректный — ok', () {
      expect(V.email()('user@example.com'), isNull);
    });
  });

  group('V.combine', () {
    test('возвращает первую сработавшую ошибку', () {
      final v = V.combine([V.required(), V.length(min: 5)]);
      expect(v(''), 'Поле обязательно');
      expect(v('ab'), 'Не короче 5 символов');
      expect(v('abcdef'), isNull);
    });
  });
}
