import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;

  const ProductCard({
    super.key,
    required this.product,
    required this.categoryName,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
        title: Text(product.name),
        subtitle: Text(
          '$categoryName • ${product.sku} • ${product.price.toStringAsFixed(2)} ₽\n'
              '${product.stockAvailable} из ${product.stockTotal} в наличии',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            if (onRestore != null)
              IconButton(icon: const Icon(Icons.restore), onPressed: onRestore)
            else
              IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}