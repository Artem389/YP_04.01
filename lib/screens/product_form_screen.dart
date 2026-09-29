import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../state/product_category_list_notifier.dart';

class ProductFormScreen extends StatefulWidget {
  final int? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _weight = TextEditingController();
  final _stockTotal = TextEditingController();
  final _stockAvailable = TextEditingController();
  int? _categoryId;

  bool get isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final p = await context.read<ProductRepository>().findById(widget.productId!);
        if (p == null || !mounted) return;
        setState(() {
          _name.text = p.name;
          _sku.text = p.sku;
          _price.text = p.price.toString();
          _weight.text = p.weightGr.toString();
          _stockTotal.text = p.stockTotal.toString();
          _stockAvailable.text = p.stockAvailable.toString();
          _categoryId = p.categoryId;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _weight.dispose();
    _stockTotal.dispose();
    _stockAvailable.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию')),
      );
      return;
    }
    final repo = context.read<ProductRepository>();
    final draft = Product(
      id: widget.productId ?? 0,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      price: double.parse(_price.text.replaceAll(',', '.')),
      weightGr: int.parse(_weight.text),
      categoryId: _categoryId!,
      supplierId: 1,
      stockTotal: int.parse(_stockTotal.text),
      stockAvailable: int.parse(_stockAvailable.text),
    );
    if (isEdit) {
      await repo.update(draft);
    } else {
      await repo.create(draft);
    }
    if (!mounted) return;
    context.go('/products');
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductCategoryListNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактирование товара' : 'Новый товар'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        border: OutlineInputBorder(),
                      ),
                      validator: V.combine([V.required(), V.length(min: 2, max: 120)]),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(
                        labelText: 'Артикул',
                        border: OutlineInputBorder(),
                      ),
                      validator: V.combine([V.required(), V.length(min: 3, max: 30)]),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Выберите категорию' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(
                        labelText: 'Цена, ₽',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: V.positiveNumber(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weight,
                      decoration: const InputDecoration(
                        labelText: 'Вес, г',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: V.positiveNumber(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockTotal,
                            decoration: const InputDecoration(
                              labelText: 'Всего на складе',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: V.nonNegativeInt(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stockAvailable,
                            decoration: const InputDecoration(
                              labelText: 'Доступно',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: V.nonNegativeInt(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(isEdit ? 'Сохранить' : 'Создать'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/products'),
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}