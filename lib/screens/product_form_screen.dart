// lib/screens/product_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/supplier.dart';
import '../repositories/product_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_form.dart';

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
  final Set<int> _supplierIds = {};
  Map<String, String> _serverErrors = {};
  bool _loaded = false;

  Product? _original;
  bool _saved = false;

  bool get isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cats = context.read<EntityListNotifier<ProductCategory>>();
      if (cats.status == LoadStatus.idle) cats.load();
      final sups = context.read<EntityListNotifier<Supplier>>();
      if (sups.status == LoadStatus.idle) sups.load();
      if (isEdit) {
        await _load();
      } else if (mounted) {
        setState(() => _loaded = true);
      }
    });
  }

  Future<void> _load() async {
    final repo = context.read<ProductRepository>();
    final p = await repo.findById(widget.productId!);
    if (!mounted) return;
    if (p == null) {
      _saved = true;
      context.go('/products');
      return;
    }
    setState(() {
      _original = p;
      _name.text = p.name;
      _sku.text = p.sku;
      _price.text = p.price.toString();
      _weight.text = p.weightGr.toString();
      _stockTotal.text = p.stockTotal.toString();
      _stockAvailable.text = p.stockAvailable.toString();
      _categoryId = p.categoryId;
      _supplierIds
        ..clear()
        ..addAll(p.supplierIds);
      _loaded = true;
    });
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

  bool get _hasChanges {
    if (_saved) return false;
    if (!isEdit) {
      return _name.text.isNotEmpty ||
          _sku.text.isNotEmpty ||
          _price.text.isNotEmpty ||
          _weight.text.isNotEmpty ||
          _stockTotal.text.isNotEmpty ||
          _stockAvailable.text.isNotEmpty ||
          _categoryId != null ||
          _supplierIds.isNotEmpty;
    }
    if (_original == null) return false;
    return _name.text != _original!.name ||
        _sku.text != _original!.sku ||
        double.tryParse(_price.text.replaceAll(',', '.')) != _original!.price ||
        int.tryParse(_weight.text) != _original!.weightGr ||
        int.tryParse(_stockTotal.text) != _original!.stockTotal ||
        int.tryParse(_stockAvailable.text) != _original!.stockAvailable ||
        _categoryId != _original!.categoryId ||
        !_sameIds(_supplierIds, _original!.supplierIds);
  }

  bool _sameIds(Set<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
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
      supplierIds: _supplierIds.toList(),
      stockTotal: int.parse(_stockTotal.text),
      stockAvailable: int.parse(_stockAvailable.text),
    );

    final exists = await repo.skuExists(draft.sku, exceptId: widget.productId);
    if (exists) {
      setState(() {
        _serverErrors = {'sku': 'Товар с таким артикулом уже существует'};
      });
      _formKey.currentState!.validate();
      return;
    }

    if (isEdit) {
      await repo.update(draft);
    } else {
      await repo.create(draft);
    }
    if (!mounted) return;

    // Ставим флаг «сохранено» и даём кадру перерисоваться,
    // чтобы PopScope успел пересчитать canPop = true.
    setState(() => _saved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.go('/products');
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_saved || !_hasChanges) {
      if (context.mounted) context.go('/products');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Выйти без сохранения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      setState(() => _saved = true);
      context.go('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categories = context.watch<EntityListNotifier<ProductCategory>>();
    final suppliers = context.watch<EntityListNotifier<Supplier>>();

    final filteredSuppliers = _categoryId == null
        ? suppliers.result.items
        : suppliers.result.items
        .where((s) => _supplierAvailableForCategory(s.id, _categoryId!))
        .toList();

    return PopScope(
      // КЛЮЧЕВОЕ: canPop == true, если сохранено или изменений нет.
      // Тогда context.go() проходит без диалога.
      canPop: _saved || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Изменения есть — спрашиваем пользователя.
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Несохранённые изменения'),
            content: const Text('Выйти без сохранения?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          setState(() => _saved = true);
          context.go('/products');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () => _handleBack(context),
          ),
          title: Text(isEdit ? 'Редактирование товара' : 'Новый товар'),
        ),
        body: EntityForm(
          formKey: _formKey,
          title: isEdit ? 'Редактирование товара' : 'Новый товар',
          submitLabel: isEdit ? 'Сохранить' : 'Создать',
          onSubmit: _submit,
          onCancel: () => _handleBack(context),
          fields: [
            FormFieldSpec(
              key: 'name',
              label: 'Название',
              controller: _name,
              validator: V.combine([
                V.required(),
                V.length(min: 2, max: 120),
                    (v) => _serverErrors['name'],
              ]),
            ),
            FormFieldSpec(
              key: 'sku',
              label: 'Артикул',
              controller: _sku,
              validator: V.combine([
                V.required(),
                V.length(min: 3, max: 30),
                    (v) => _serverErrors['sku'],
              ]),
            ),
            FormFieldSpec(
              key: 'price',
              label: 'Цена, ₽',
              controller: _price,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              validator: V.positiveNumber(),
            ),
            FormFieldSpec(
              key: 'weight',
              label: 'Вес, г',
              controller: _weight,
              keyboardType: TextInputType.number,
              validator: V.integer(min: 1, max: 100000),
            ),
            FormFieldSpec(
              key: 'stockTotal',
              label: 'Всего на складе',
              controller: _stockTotal,
              keyboardType: TextInputType.number,
              validator: V.nonNegativeInt(),
            ),
            FormFieldSpec(
              key: 'stockAvailable',
              label: 'Доступно',
              controller: _stockAvailable,
              keyboardType: TextInputType.number,
              validator: V.nonNegativeInt(),
            ),
          ],
          extraFields: [
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
              items: categories.result.items
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _categoryId = v;
                _supplierIds.removeWhere(
                        (id) => !_supplierAvailableForCategory(id, v ?? 0));
              }),
              validator: (v) => v == null ? 'Выберите категорию' : null,
            ),
            const SizedBox(height: 16),
            FormField<List<int>>(
              initialValue: _supplierIds.toList(),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Выберите хотя бы одного поставщика'
                  : null,
              builder: (field) {
                return InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Поставщики',
                    border: const OutlineInputBorder(),
                    errorText: field.errorText,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredSuppliers.map((s) {
                      final selected = _supplierIds.contains(s.id);
                      return FilterChip(
                        label: Text(s.name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selected
                                ? _supplierIds.remove(s.id)
                                : _supplierIds.add(s.id);
                          });
                          field.didChange(_supplierIds.toList());
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _supplierAvailableForCategory(int supplierId, int categoryId) {
    switch (categoryId) {
      case 1:
        return supplierId == 1 || supplierId == 5;
      case 6:
        return supplierId == 6;
      default:
        return true;
    }
  }
}