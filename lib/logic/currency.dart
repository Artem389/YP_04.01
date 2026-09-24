/// Курсы валют к рублю. Константы в коде.
const Map<String, double> kRates = {
  'RUB': 1.0,
  'USD': 92.5,
  'EUR': 100.2,
  'CNY': 12.8,
  'KZT': 0.19,
  'TRY': 2.9,
};

const List<String> kCurrencies = ['RUB', 'USD', 'EUR', 'CNY', 'KZT', 'TRY'];

sealed class ConvertResult {
  const ConvertResult();
}

class ConvertSuccess extends ConvertResult {
  final double value;
  const ConvertSuccess(this.value);
}

class ConvertFailure extends ConvertResult {
  final String message;
  const ConvertFailure(this.message);
}

ConvertResult convert(String? rawAmount, String? from, String? to) {
  final amount = double.tryParse(rawAmount?.replaceAll(',', '.') ?? '');
  if (amount == null) return const ConvertFailure('В адресе передана не сумма');
  if (from == null || to == null) {
    return const ConvertFailure('Не указана валюта');
  }
  final fromRate = kRates[from];
  final toRate = kRates[to];
  if (fromRate == null || toRate == null) {
    return const ConvertFailure('Неизвестная валюта');
  }
  if (amount < 0) return const ConvertFailure('Сумма не может быть отрицательной');
  return ConvertSuccess(amount * fromRate / toRate);
}