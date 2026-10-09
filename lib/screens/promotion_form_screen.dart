import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/product_category.dart';
import '../models/promotion.dart';
import '../repositories/product_category_repository.dart';
import '../repositories/promotion_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_form.dart';

class PromotionFormScreen extends StatefulWidget {
  final int? promotionId;
  const PromotionFormScreen({super.key, this.promotionId});

  @override
  State<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends State<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _discount = TextEditingController();
  final _minTotal = TextEditingController(text: '0');
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 30));
  int? _categoryId;
  List<ProductCategory> _categories = const [];
  Promotion? _original;
  bool _loaded = false;
  bool _saved = false;

  bool get isEdit => widget.promotionId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _categories = await context.read<ProductCategoryRepository>().findAll();
      if (!mounted) return;
      if (isEdit) {
        await _load();
      } else {
        setState(() => _loaded = true);
      }
    });
  }

  Future<void> _load() async {
    final p =
    await context.read<PromotionRepository>().findById(widget.promotionId!);
    if (!mounted) return;
    if (p == null) {
      _saved = true;
      context.go('/promotions');
      return;
    }
    setState(() {
      _original = p;
      _name.text = p.name;
      _description.text = p.description;
      _discount.text = p.discountPercent.toString();
      _minTotal.text = p.minTotal.toString();
      _startsAt = p.startsAt;
      _endsAt = p.endsAt;
      _categoryId = p.categoryId;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _discount.dispose();
    _minTotal.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _startsAt : _endsAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        if (_endsAt.isBefore(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(days: 1));
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Окончание должно быть позже начала')),
      );
      return;
    }
    final repo = context.read<PromotionRepository>();
    final draft = Promotion(
      id: widget.promotionId ?? 0,
      name: _name.text.trim(),
      description: _description.text.trim(),
      discountPercent: int.parse(_discount.text),
      categoryId: _categoryId,
      productIds: _original?.productIds ?? const [],
      minTotal: double.tryParse(_minTotal.text.replaceAll(',', '.')) ?? 0,
      startsAt: _startsAt,
      endsAt: _endsAt,
    );
    if (isEdit) {
      await repo.update(draft);
    } else {
      await repo.create(draft);
    }
    if (!mounted) return;
    await context.read<EntityListNotifier<Promotion>>().load();
    if (!mounted) return;
    setState(() => _saved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.go('/promotions');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактирование акции' : 'Новая акция'),
      ),
      body: EntityForm(
        formKey: _formKey,
        title: isEdit ? 'Редактирование акции' : 'Новая акция',
        submitLabel: isEdit ? 'Сохранить' : 'Создать',
        onSubmit: _submit,
        onCancel: () {
          setState(() => _saved = true);
          context.go('/promotions');
        },
        fields: [
          FormFieldSpec(
            key: 'name',
            label: 'Название',
            controller: _name,
            validator: V.combine([V.required(), V.length(min: 2, max: 120)]),
          ),
          FormFieldSpec(
            key: 'description',
            label: 'Описание',
            controller: _description,
            maxLines: 3,
            validator: V.length(max: 255),
          ),
          FormFieldSpec(
            key: 'discount',
            label: 'Скидка, %',
            controller: _discount,
            keyboardType: TextInputType.number,
            validator: V.integer(min: 1, max: 90),
          ),
          FormFieldSpec(
            key: 'minTotal',
            label: 'Минимальная сумма, ₽',
            controller: _minTotal,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            validator: V.positiveNumber(allowZero: true),
          ),
        ],
        extraFields: [
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Категория (необязательно)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final c in _categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today),
                  label: Text('С ${_startsAt.toString().substring(0, 10)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event),
                  label: Text('По ${_endsAt.toString().substring(0, 10)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}