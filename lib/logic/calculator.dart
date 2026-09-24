/// Результат вычисления: либо значение, либо описание ошибки.
sealed class CalcResult {
  const CalcResult();
}

class CalcSuccess extends CalcResult {
  final double value;
  const CalcSuccess(this.value);
}

class CalcFailure extends CalcResult {
  final String message;
  const CalcFailure(this.message);
}

/// Округление до 6 знаков и удаление хвостовых нулей.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '—';
  final rounded = double.parse(value.toStringAsFixed(6));
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toString();
}

CalcResult calculate(String? rawA, String? rawOp, String? rawB) {
  final a = double.tryParse(rawA?.replaceAll(',', '.') ?? '');
  final b = double.tryParse(rawB?.replaceAll(',', '.') ?? '');

  if (a == null || b == null) {
    return const CalcFailure('В адресе переданы не числа');
  }

  // Нормализация: '+' в query-строке декодируется в пробел.
  // Приводим пробел и пустую строку к '+' как наиболее вероятной операции.
  final op = switch (rawOp) {
    null || '' || ' ' => '+',
    _ => rawOp,
  };

  return switch (op) {
    '+' => CalcSuccess(a + b),
    '-' => CalcSuccess(a - b),
    '*' => CalcSuccess(a * b),
    '/' => b == 0
        ? const CalcFailure('Деление на ноль невозможно')
        : CalcSuccess(a / b),
    _ => CalcFailure('Неизвестная операция: "$op"'),
  };
}