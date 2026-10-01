// lib/screens/supplier_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/supplier.dart';
import '../repositories/supplier_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_form.dart';

class SupplierFormScreen extends StatefulWidget {
  final int? supplierId;
  const SupplierFormScreen({super.key, this.supplierId});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  Map<String, String> _serverErrors = {};
  bool _loaded = false;
  Supplier? _original;
  bool _saved = false;

  bool get isEdit => widget.supplierId != null;

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
    final s =
    await context.read<SupplierRepository>().findById(widget.supplierId!);
    if (!mounted) return;
    if (s == null) {
      _saved = true;
      context.go('/suppliers');
      return;
    }
    setState(() {
      _original = s;
      _name.text = s.name;
      _email.text = s.email;
      _phone.text = s.phone;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_saved) return false;
    if (!isEdit) {
      return _name.text.isNotEmpty ||
          _email.text.isNotEmpty ||
          _phone.text.isNotEmpty;
    }
    if (_original == null) return false;
    return _name.text != _original!.name ||
        _email.text != _original!.email ||
        _phone.text != _original!.phone;
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<SupplierRepository>();
    final draft = Supplier(
      id: widget.supplierId ?? 0,
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
    );

    final exists =
    await repo.emailExists(draft.email, exceptId: widget.supplierId);
    if (exists) {
      setState(() =>
      _serverErrors = {'email': 'Такой email уже используется'});
      _formKey.currentState!.validate();
      return;
    }

    if (isEdit) {
      await repo.update(draft);
    } else {
      await repo.create(draft);
    }
    if (!mounted) return;
    await context.read<EntityListNotifier<Supplier>>().load();
    if (!mounted) return;

    setState(() => _saved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.go('/suppliers');
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_saved || !_hasChanges) {
      if (context.mounted) context.go('/suppliers');
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
      context.go('/suppliers');
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
          context.go('/suppliers');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () => _handleBack(context),
          ),
          title: Text(isEdit ? 'Редактирование поставщика' : 'Новый поставщик'),
        ),
        body: EntityForm(
          formKey: _formKey,
          title: isEdit ? 'Редактирование поставщика' : 'Новый поставщик',
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
              ]),
            ),
            FormFieldSpec(
              key: 'email',
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: V.combine([
                V.required(),
                V.email(),
                    (v) => _serverErrors['email'],
              ]),
            ),
            FormFieldSpec(
              key: 'phone',
              label: 'Телефон',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: V.combine([
                V.required(),
                V.length(min: 5, max: 20),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}