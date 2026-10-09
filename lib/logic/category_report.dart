import '../models/product.dart';
import '../models/product_category.dart';

/// Строка отчёта: категория и её показатели.
class CategoryReportRow {
  final ProductCategory category;
  final int productCount;
  final int totalStock;
  final double totalValue; // сумма (price × stockAvailable)

  const CategoryReportRow({
    required this.category,
    required this.productCount,
    required this.totalStock,
    required this.totalValue,
  });
}

/// Сводный отчёт по категориям.
class CategoryReport {
  /// Собрать отчёт.
  static List<CategoryReportRow> build({
    required List<ProductCategory> categories,
    required List<Product> products,
  }) {
    final byCategory = <int, List<Product>>{};
    for (final p in products) {
      if (p.isDeleted) continue;
      byCategory.putIfAbsent(p.categoryId, () => []).add(p);
    }

    final rows = categories.map((c) {
      final items = byCategory[c.id] ?? const <Product>[];
      var stock = 0;
      var value = 0.0;
      for (final p in items) {
        stock += p.stockAvailable;
        value += p.price * p.stockAvailable;
      }
      return CategoryReportRow(
        category: c,
        productCount: items.length,
        totalStock: stock,
        totalValue: _round2(value),
      );
    }).toList();

    // Сортировка: сначала самые дорогие по стоимости склада.
    rows.sort((a, b) => b.totalValue.compareTo(a.totalValue));
    return rows;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
