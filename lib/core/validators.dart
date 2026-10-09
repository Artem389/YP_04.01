// lib/core/validators.dart
typedef Validator = String? Function(String?);

class V {
  static Validator required([String message = 'Поле обязательно']) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }

  static Validator length({int min = 0, int max = 255}) {
    return (v) {
      final text = v?.trim() ?? '';
      if (text.length < min) return 'Не короче $min символов';
      if (text.length > max) return 'Не длиннее $max символов';
      return null;
    };
  }

  static Validator positiveNumber({bool allowZero = false}) {
    return (v) {
      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
      if (n == null) return 'Введите число';
      if (allowZero ? n < 0 : n <= 0) {
        return allowZero
            ? 'Не может быть отрицательным'
            : 'Должно быть больше нуля';
      }
      return null;
    };
  }

  static Validator nonNegativeInt() {
    return (v) {
      final n = int.tryParse(v?.trim() ?? '');
      if (n == null) return 'Введите целое число';
      if (n < 0) return 'Не может быть отрицательным';
      return null;
    };
  }

  /// Целое в диапазоне — для года, количества страниц и т. п.
  static Validator integer({int? min, int? max}) {
    return (v) {
      final n = int.tryParse(v?.trim() ?? '');
      if (n == null) return 'Введите целое число';
      if (min != null && n < min) return 'Значение не меньше $min';
      if (max != null && n > max) return 'Значение не больше $max';
      return null;
    };
  }

  static Validator email() {
    final re = RegExp(r'^[\w.+]+@[\w.-]+\.[\w.-]+$');
    return (v) =>
        re.hasMatch(v?.trim() ?? '') ? null : 'Некорректный адрес почты';
  }

  static Validator combine(List<Validator> validators) {
    return (v) {
      for (final f in validators) {
        final error = f(v);
        if (error != null) return error;
      }
      return null;
    };
  }
}
