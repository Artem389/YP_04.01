import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_category.dart';
import '../state/product_category_list_notifier.dart';
import '../widgets/entity_table.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<ProductCategoryListNotifier>();
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      body: switch (n.status) {
        ProductCategoryStatus.idle || ProductCategoryStatus.loading =>
        const Center(child: CircularProgressIndicator()),
        ProductCategoryStatus.error =>
            Center(child: Text(n.error ?? 'Ошибка')),
        ProductCategoryStatus.success => n.categories.isEmpty
            ? const Center(child: Text('Категорий нет'))
            : EntityTable<ProductCategory>(
          items: n.categories,
          idOf: (c) => c.id,
          columns: [
            TableColumnSpec(
              label: 'Название',
              sortField: 'name',
              build: (c) => Text(c.name),
            ),
            TableColumnSpec(
              label: 'Описание',
              build: (c) => Text(c.description),
            ),
          ],
        ),
      },
    );
  }
}