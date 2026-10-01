// lib/screens/category_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/product_category.dart';
import '../repositories/product_category_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_form.dart';

class CategoryFormScreen extends StatefulWidget {
  final int? categoryId;
  const CategoryFormScreen({super.key, this.categoryId});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  Map<String, String> _serverErrors = {};
  bool _loaded = false;
  ProductCategory? _original;
  bool _saved = false;

  bool get isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (isEdit) {
        await _load();
      } else if (mounted) {
        setState(() => _loaded = true);
      }
    });
  }

  Future<void> _load() async {
    final c = await context
        .read<ProductCategoryRepository>()
        .findById(widget.categoryId!);
    if (!mounted) return;
    if (c == null) {
      _saved = true;
      context.go('/categories');
      return;
    }
    setState(() {
      _original = c;
      _name.text = c.name;
      _description.text = c.description;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_saved) return false;
    if (!isEdit) {
      return _name.text.isNotEmpty || _description.text.isNotEmpty;
    }
    if (_original == null) return false;
    return _name.text != _original!.name ||
        _description.text != _original!.description;
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<ProductCategoryRepository>();
    final draft = ProductCategory(
      id: widget.categoryId ?? 0,
      name: _name.text.trim(),
      description: _description.text.trim(),
    );

    final exists =
    await repo.nameExists(draft.name, exceptId: widget.categoryId);
    if (exists) {
      setState(() {
        _serverErrors = {'name': 'Категория с таким названием уже есть'};
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
    await context.read<EntityListNotifier<ProductCategory>>().load();
    if (!mounted) return;

    setState(() => _saved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.go('/categories');
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_saved || !_hasChanges) {
      if (context.mounted) context.go('/categories');
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
      context.go('/categories');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: _saved || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
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
          context.go('/categories');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () => _handleBack(context),
          ),
          title: Text(isEdit ? 'Редактирование категории' : 'Новая категория'),
        ),
        body: EntityForm(
          formKey: _formKey,
          title: isEdit ? 'Редактирование категории' : 'Новая категория',
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
                V.length(min: 2, max: 80),
                    (v) => _serverErrors['name'],
              ]),
            ),
            FormFieldSpec(
              key: 'description',
              label: 'Описание',
              controller: _description,
              maxLines: 3,
              validator: V.length(max: 255),
            ),
          ],
        ),
      ),
    );
  }
}