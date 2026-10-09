import '../models/customer.dart';
import '../models/product.dart';
import '../models/promotion.dart';

/// Позиция корзины: товар и количество.
class CartLine {
  final Product product;
  final int quantity;
  const CartLine({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}

/// Результат расчёта продажи.
class SaleTotals {
  /// Сумма без скидок.
  final double subtotal;

  /// Скидка по карте лояльности (если карта есть).
  final double cardDiscount;

  /// Скидка по акции (если подходит).
  final double promoDiscount;

  /// Сумма после скидок.
  final double afterDiscounts;

  /// НДС 20 %.
  final double vat;

  /// Итог к оплате.
  final double total;

  /// Названия применённых акций.
  final List<String> appliedPromotions;

  const SaleTotals({
    required this.subtotal,
    required this.cardDiscount,
    required this.promoDiscount,
    required this.afterDiscounts,
    required this.vat,
    required this.total,
    required this.appliedPromotions,
  });
}

/// НДС в процентах.
const vatPercent = 20;

/// Калькулятор продажи.
///
/// Правила:
///  1. Скидка по карте лояльности применяется ко всей корзине.
///  2. Скидки по акциям применяются к позициям, попадающим под условия.
///  3. Скидки не суммируются: применяется наибольшая из
///     (карта, акция) на каждую позицию. Это осознанное бизнес-правило,
///     чтобы не отдавать товар бесплатно при наложении акций.
///  4. НДС 20 % начисляется на итог после скидок.
class SaleCalculator {
  /// Пересчитать корзину.
  ///
  /// [at] позволяет подставить «текущий момент» — нужно для тестов.
  static SaleTotals calculate({
    required List<CartLine> lines,
    Customer? customer,
    List<Promotion> promotions = const [],
    DateTime? at,
  }) {
    final moment = at ?? DateTime.now();
    final subtotal = lines.fold<double>(0, (s, l) => s + l.subtotal);

    // Скидка карты в процентах.
    final cardPercent = customer?.card?.discountPercent ?? 0;

    double cardDiscount = 0;
    double promoDiscount = 0;
    final appliedPromos = <String>{};

    for (final line in lines) {
      // Акции, применимые к этому товару и активные сейчас.
      final suitable = promotions.where((p) {
        if (!p.isActiveAt(moment)) return false;
        if (p.productIds.contains(line.product.id)) return true;
        if (p.categoryId != null &&
            p.categoryId == line.product.categoryId) {
          return true;
        }
        return false;
      }).toList();

      // Лучшая акция для позиции.
      int bestPromo = 0;
      for (final p in suitable) {
        if (p.discountPercent > bestPromo) bestPromo = p.discountPercent;
      }

      // Выбираем наибольшую из двух скидок: карты или акции.
      if (cardPercent >= bestPromo && cardPercent > 0) {
        cardDiscount += line.subtotal * cardPercent / 100;
      } else if (bestPromo > 0) {
        promoDiscount += line.subtotal * bestPromo / 100;
        appliedPromos.addAll(
          suitable
              .where((p) => p.discountPercent == bestPromo)
              .map((p) => p.name),
        );
      }
    }

    final afterDiscounts = subtotal - cardDiscount - promoDiscount;
    final vat = afterDiscounts * vatPercent / 100;
    final total = afterDiscounts + vat;

    return SaleTotals(
      subtotal: _round2(subtotal),
      cardDiscount: _round2(cardDiscount),
      promoDiscount: _round2(promoDiscount),
      afterDiscounts: _round2(afterDiscounts),
      vat: _round2(vat),
      total: _round2(total),
      appliedPromotions: appliedPromos.toList(),
    );
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}