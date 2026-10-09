import 'package:flutter_project_web/logic/sale_calculator.dart';
import 'package:flutter_project_web/models/customer.dart';
import 'package:flutter_project_web/models/discount_card.dart';
import 'package:flutter_project_web/models/product.dart';
import 'package:flutter_project_web/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p({
  int id = 1,
  double price = 100,
  int categoryId = 1,
}) =>
    Product(
      id: id,
      name: 'Товар $id',
      sku: 'SKU-$id',
      price: price,
      weightGr: 100,
      categoryId: categoryId,
      stockTotal: 100,
      stockAvailable: 100,
    );

void main() {
  group('SaleCalculator — базовая арифметика', () {
    test('без скидок и без карты — сумма, НДС 20%, итог', () {
      final t = SaleCalculator.calculate(
        lines: [CartLine(product: _p(price: 100), quantity: 2)],
      );
      expect(t.subtotal, 200);
      expect(t.cardDiscount, 0);
      expect(t.promoDiscount, 0);
      expect(t.afterDiscounts, 200);
      expect(t.vat, 40);
      expect(t.total, 240);
    });

    test('скидка карты 10% применяется ко всей корзине', () {
      final t = SaleCalculator.calculate(
        lines: [
          CartLine(product: _p(id: 1, price: 100), quantity: 1),
          CartLine(product: _p(id: 2, price: 100), quantity: 1),
        ],
        customer: Customer(
          id: 1,
          fullName: 'Иван',
          email: 'i@e.ru',
          phone: '',
          card: DiscountCard(
            number: 'DC-1',
            discountPercent: 10,
            issuedAt: DateTime(2025),
          ),
        ),
      );
      expect(t.cardDiscount, 20); // 10% от 200
      expect(t.afterDiscounts, 180);
      expect(t.vat, 36);
      expect(t.total, 216);
    });

    test('скидка по акции применяется только к подходящим позициям', () {
      final t = SaleCalculator.calculate(
        lines: [
          CartLine(product: _p(id: 1, price: 100, categoryId: 1), quantity: 1),
          CartLine(product: _p(id: 2, price: 100, categoryId: 2), quantity: 1),
        ],
        promotions: [
          Promotion(
            id: 1,
            name: 'Молочка 10%',
            description: '',
            discountPercent: 10,
            categoryId: 1,
            startsAt: DateTime(2025),
            endsAt: DateTime(2030),
          ),
        ],
        at: DateTime(2026),
      );
      expect(t.promoDiscount, 10);
      expect(t.afterDiscounts, 190);
      expect(t.appliedPromotions, ['Молочка 10%']);
    });

    test('не суммирует скидки: берётся наибольшая', () {
      // Карта 5% против акции 20% — выигрывает акция.
      final t = SaleCalculator.calculate(
        lines: [CartLine(product: _p(price: 100, categoryId: 1), quantity: 1)],
        customer: Customer(
          id: 1,
          fullName: 'Иван',
          email: 'i@e.ru',
          phone: '',
          card: DiscountCard(
            number: 'DC-1',
            discountPercent: 5,
            issuedAt: DateTime(2025),
          ),
        ),
        promotions: [
          Promotion(
            id: 1,
            name: 'Скидка 20%',
            description: '',
            discountPercent: 20,
            categoryId: 1,
            startsAt: DateTime(2025),
            endsAt: DateTime(2030),
          ),
        ],
        at: DateTime(2026),
      );
      expect(t.cardDiscount, 0);
      expect(t.promoDiscount, 20);
      expect(t.total, 96); // 80 * 1.2
    });

    test('неактивная акция игнорируется', () {
      final t = SaleCalculator.calculate(
        lines: [CartLine(product: _p(price: 100, categoryId: 1), quantity: 1)],
        promotions: [
          Promotion(
            id: 1,
            name: 'Просроченная',
            description: '',
            discountPercent: 50,
            categoryId: 1,
            startsAt: DateTime(2020),
            endsAt: DateTime(2021),
          ),
        ],
        at: DateTime(2026),
      );
      expect(t.promoDiscount, 0);
      expect(t.total, 120);
    });

    test('акция применяется по списку товаров без категории', () {
      final t = SaleCalculator.calculate(
        lines: [CartLine(product: _p(id: 5, price: 100), quantity: 1)],
        promotions: [
          Promotion(
            id: 1,
            name: 'По списку',
            description: '',
            discountPercent: 25,
            productIds: const [5],
            startsAt: DateTime(2025),
            endsAt: DateTime(2030),
          ),
        ],
        at: DateTime(2026),
      );
      expect(t.promoDiscount, 25);
      expect(t.total, 90);
    });
  });
}