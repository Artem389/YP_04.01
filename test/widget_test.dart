import 'package:flutter_project_web/logic/calculator.dart';
import 'package:flutter_project_web/logic/currency.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('Калькулятор', () {
    test('сложение', () {
      final r = calculate('2', '+', '3');
      expect(r, isA<CalcSuccess>());
      expect((r as CalcSuccess).value, 5);
    });

    test('вычитание', () {
      final r = calculate('10', '-', '4');
      expect((r as CalcSuccess).value, 6);
    });

    test('умножение', () {
      final r = calculate('3', '*', '4');
      expect((r as CalcSuccess).value, 12);
    });

    test('деление', () {
      final r = calculate('9', '/', '3');
      expect((r as CalcSuccess).value, 3);
    });

    test('деление на ноль даёт ошибку', () {
      final r = calculate('5', '/', '0');
      expect(r, isA<CalcFailure>());
      expect((r as CalcFailure).message, contains('ноль'));
    });

    test('нечисловой ввод даёт ошибку', () {
      final r = calculate('abc', '+', '3');
      expect(r, isA<CalcFailure>());
    });

    test('неизвестная операция даёт ошибку', () {
      final r = calculate('2', '%', '3');
      expect(r, isA<CalcFailure>());
    });

    test('пустой параметр даёт ошибку', () {
      final r = calculate(null, '+', '3');
      expect(r, isA<CalcFailure>());
    });

    test('округление убирает хвостовые нули', () {
      expect(formatNumber(3.3333333333333335), '3.333333');
      expect(formatNumber(5.0), '5');
    });
  });

  group('Конвертер', () {
    test('перевод USD в RUB', () {
      final r = convert('10', 'USD', 'RUB');
      expect((r as ConvertSuccess).value, closeTo(925, 0.01));
    });

    test('неизвестная валюта', () {
      final r = convert('10', 'XXX', 'RUB');
      expect(r, isA<ConvertFailure>());
    });

    test('отрицательная сумма', () {
      final r = convert('-5', 'USD', 'RUB');
      expect(r, isA<ConvertFailure>());
    });
  });
}