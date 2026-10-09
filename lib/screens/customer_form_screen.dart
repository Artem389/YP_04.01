// lib/screens/customer_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/customer.dart';
import '../models/discount_card.dart';
import '../repositories/customer_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_form.dart';

class CustomerFormScreen extends StatefulWidget {
  final int? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _hasCard = false;
  final _cardNumber = TextEditingController();
  final _cardDiscount = TextEditingController();

  Map<String, String> _serverErrors = {};
  bool _loaded = false;
  Customer? _original;
  bool _saved = false;

  bool get isEdit => widget.customerId != null;

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
    final c = await context.read<CustomerRepository>().findById(
      widget.customerId!,
    );
    if (!mounted) return;
    if (c == null) {
      _saved = true;
      context.go('/customers');
      return;
    }
    setState(() {
      _original = c;
      _fullName.text = c.fullName;
      _email.text = c.email;
      _phone.text = c.phone;
      _hasCard = c.card != null;
      _cardNumber.text = c.card?.number ?? '';
      _cardDiscount.text = c.card?.discountPercent.toString() ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _cardNumber.dispose();
    _cardDiscount.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_saved) return false;
    if (!isEdit) {
      return _fullName.text.isNotEmpty ||
          _email.text.isNotEmpty ||
          _phone.text.isNotEmpty ||
          _hasCard;
    }
    if (_original == null) return false;
    return _fullName.text != _original!.fullName ||
        _email.text != _original!.email ||
        _phone.text != _original!.phone ||
        (_original!.card == null) != !_hasCard ||
        (_hasCard && _cardNumber.text != (_original!.card?.number ?? ''));
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<CustomerRepository>();
    final draft = Customer(
      id: widget.customerId ?? 0,
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      card: _hasCard
          ? DiscountCard(
              number: _cardNumber.text.trim(),
              discountPercent: int.parse(_cardDiscount.text),
              issuedAt: _original?.card?.issuedAt ?? DateTime.now(),
            )
          : null,
    );

    final exists = await repo.emailExists(
      draft.email,
      exceptId: widget.customerId,
    );
    if (exists) {
      setState(
        () => _serverErrors = {'email': 'Покупатель с таким email уже есть'},
      );
      _formKey.currentState!.validate();
      return;
    }

    if (isEdit) {
      await repo.update(draft);
    } else {
      await repo.create(draft);
    }
    if (!mounted) return;
    await context.read<EntityListNotifier<Customer>>().load();
    if (!mounted) return;

    setState(() => _saved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.go('/customers');
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_saved || !_hasChanges) {
      if (context.mounted) context.go('/customers');
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
      context.go('/customers');
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
          context.go('/customers');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () => _handleBack(context),
          ),
          title: Text(
            isEdit ? 'Редактирование покупателя' : 'Новый покупатель',
          ),
        ),
        body: EntityForm(
          formKey: _formKey,
          title: isEdit ? 'Редактирование покупателя' : 'Новый покупатель',
          submitLabel: isEdit ? 'Сохранить' : 'Создать',
          onSubmit: _submit,
          onCancel: () => _handleBack(context),
          fields: [
            FormFieldSpec(
              key: 'fullName',
              label: 'ФИО',
              controller: _fullName,
              validator: V.combine([V.required(), V.length(min: 3, max: 120)]),
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
              validator: V.combine([V.required(), V.length(min: 5, max: 20)]),
            ),
          ],
          extraFields: [
            CheckboxListTile(
              title: const Text('Есть карта лояльности'),
              value: _hasCard,
              onChanged: (v) => setState(() => _hasCard = v ?? false),
            ),
            if (_hasCard) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardNumber,
                decoration: const InputDecoration(
                  labelText: 'Номер карты',
                  border: OutlineInputBorder(),
                ),
                validator: V.combine([V.required(), V.length(min: 4, max: 20)]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardDiscount,
                decoration: const InputDecoration(
                  labelText: 'Скидка, %',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: V.integer(min: 1, max: 50),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
