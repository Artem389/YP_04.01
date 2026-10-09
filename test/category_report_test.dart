import 'package:flutter_project_web/logic/category_report.dart';
import 'package:flutter_project_web/models/product.dart';
import 'package:flutter_project_web/models/product_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryReport', () {
    test('считает количество, остаток и стоимость по категории', () {
      final cats = [
        const ProductCategory(id: 1, name: 'Молочка', description: ''),
        const ProductCategory(id: 2, name: 'Хлеб', description: ''),
      ];
      final products = [
        Product(
          id: 1,
          name: 'A',
          sku: 'S1',
          price: 10,
          weightGr: 1,
          categoryId: 1,
          stockTotal: 100,
          stockAvailable: 5,
        ),
        Product(
          id: 2,
          name: 'B',
          sku: 'S2',
          price: 20,
          weightGr: 1,
          categoryId: 1,
          stockTotal: 100,
          stockAvailable: 3,
        ),
        Product(
          id: 3,
          name: 'C',
          sku: 'S3',
          price: 5,
          weightGr: 1,
          categoryId: 2,
          stockTotal: 100,
          stockAvailable: 10,
        ),
      ];
      final rows = CategoryReport.build(categories: cats, products: products);
      expect(rows.length, 2);
      // Категория 1: 2 товара, 8 остаток, 10*5 + 20*3 = 110
      final dairy = rows.firstWhere((r) => r.category.id == 1);
      expect(dairy.productCount, 2);
      expect(dairy.totalStock, 8);
      expect(dairy.totalValue, 110);
      // Категория 2: 1 товар, 10 остаток, 50
      final bread = rows.firstWhere((r) => r.category.id == 2);
      expect(bread.productCount, 1);
      expect(bread.totalStock, 10);
      expect(bread.totalValue, 50);
    });

    test('удалённые товары не учитываются', () {
      final rows = CategoryReport.build(
        categories: const [ProductCategory(id: 1, name: 'X', description: '')],
        products: [
          Product(
            id: 1,
            name: 'A',
            sku: 'S1',
            price: 100,
            weightGr: 1,
            categoryId: 1,
            stockTotal: 10,
            stockAvailable: 5,
            deletedAt: DateTime(2025),
          ),
        ],
      );
      expect(rows.first.productCount, 0);
      expect(rows.first.totalStock, 0);
      expect(rows.first.totalValue, 0);
    });

    test('сортировка по убыванию стоимости', () {
      final rows = CategoryReport.build(
        categories: const [
          ProductCategory(id: 1, name: 'Дешёвая', description: ''),
          ProductCategory(id: 2, name: 'Дорогая', description: ''),
        ],
        products: [
          Product(
            id: 1,
            name: 'A',
            sku: 'A',
            price: 1,
            weightGr: 1,
            categoryId: 1,
            stockTotal: 10,
            stockAvailable: 1,
          ),
          Product(
            id: 2,
            name: 'B',
            sku: 'B',
            price: 100,
            weightGr: 1,
            categoryId: 2,
            stockTotal: 10,
            stockAvailable: 1,
          ),
        ],
      );
      expect(rows.first.category.id, 2);
    });
  });
}
