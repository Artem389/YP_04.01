import 'package:flutter_project_web/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Promotion.isActiveAt', () {
    Promotion make({DateTime? start, DateTime? end, DateTime? deleted}) =>
        Promotion(
          id: 1,
          name: 'A',
          description: '',
          discountPercent: 10,
          startsAt: start ?? DateTime(2025),
          endsAt: end ?? DateTime(2030),
          deletedAt: deleted,
        );

    test('внутри интервала — активна', () {
      expect(make().isActiveAt(DateTime(2026)), isTrue);
    });
    test('до начала — неактивна', () {
      expect(make().isActiveAt(DateTime(2024)), isFalse);
    });
    test('после окончания — неактивна', () {
      expect(make().isActiveAt(DateTime(2031)), isFalse);
    });
    test('удалённая всегда неактивна', () {
      expect(make(deleted: DateTime(2025)).isActiveAt(DateTime(2026)), isFalse);
    });
  });

  group('Promotion.fromJson', () {
    test('устойчив к отсутствующим полям', () {
      final p = Promotion.fromJson({'id': 1});
      expect(p.name, '');
      expect(p.discountPercent, 0);
      expect(p.productIds, isEmpty);
      expect(p.isDeleted, isFalse);
    });
  });
}
