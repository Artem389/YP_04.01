import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart';
import '../logic/sale_calculator.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/promotion.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/promotion_repository.dart';
import '../repositories/sale_repository.dart';
import '../state/product_list_notifier.dart';

class SellProductScreen extends StatefulWidget {
  final int productId;
  const SellProductScreen({super.key, required this.productId});

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');

  Product? _product;
  List<Customer> _customers = const [];
  List<Promotion> _promotions = const [];
  int? _customerId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  SaleTotals? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final productRepo = context.read<ProductRepository>();
      final customerRepo = context.read<CustomerRepository>();
      final promotionRepo = context.read<PromotionRepository>();

      final product = await productRepo.findById(widget.productId);
      if (!mounted) return;
      if (product == null) {
        _error = 'Товар не найден';
        setState(() => _loading = false);
        return;
      }

      // Покупателей тянем все — у нас их немного, зато сразу видно,
      // к кому применить скидку карты.
      final customersPage =
      await customerRepo.find(const ProductQuery(size: 500));
      final promos = await promotionRepo.findAll();

      if (!mounted) return;
      setState(() {
        _product = product;
        _customers = customersPage.items;
        _promotions = promos;
        _customerId = _customers.isNotEmpty ? _customers.first.id : null;
        _loading = false;
      });
      _recalc();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _recalc() {
    final p = _product;
    if (p == null) return;
    final qty = int.tryParse(_quantity.text) ?? 1;
    final customer = _customers.firstWhere(
          (c) => c.id == _customerId,
      orElse: () => _customers.isEmpty
          ? Customer(id: 0, fullName: '', email: '', phone: '')
          : _customers.first,
    );
    setState(() {
      _preview = SaleCalculator.calculate(
        lines: [CartLine(product: p, quantity: qty.clamp(1, 1000))],
        customer: customer.id == 0 ? null : customer,
        promotions: _promotions,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _product;
    if (p == null) return;

    if (p.stockAvailable < int.parse(_quantity.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'На складе только ${p.stockAvailable} шт.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<SaleRepository>().create(
        customerId: _customerId!,
        productId: p.id,
        quantity: int.parse(_quantity.text),
      );
      if (!mounted) return;
      // Обновляем список товаров — остаток изменился.
      await context.read<ProductListNotifier>().load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Продажа оформлена')),
      );
      context.go('/sales');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Назад',
            onPressed: () => context.go('/products'),
          ),
          title: const Text('Оформление продажи'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.go('/products'),
                child: const Text('К каталогу'),
              ),
            ],
          ),
        ),
      );
    }

    final p = _product!;
    final totals = _preview;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'К каталогу',
          onPressed: () => context.go('/products'),
        ),
        title: const Text('Оформление продажи'),
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
                    Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          'Артикул: ${p.sku} • '
                              'Цена: ${p.price.toStringAsFixed(2)} ₽ • '
                              'На складе: ${p.stockAvailable}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _customerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Покупатель',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in _customers)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.card == null
                                  ? c.fullName
                                  : '${c.fullName} • карта ${c.card!.discountPercent}%',
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _customerId = v);
                        _recalc();
                      },
                      validator: (v) => v == null ? 'Выберите покупателя' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _recalc(),
                      validator: V.integer(min: 1, max: 1000),
                    ),

                    const SizedBox(height: 24),

                    if (totals != null) _totalsCard(totals),

                    const SizedBox(height: 24),

                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.check),
                      label: const Text('Оформить продажу'),
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

  Widget _totalsCard(SaleTotals t) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('Подытог', t.subtotal),
            if (t.cardDiscount > 0)
              _row('Скидка по карте', -t.cardDiscount),
            if (t.promoDiscount > 0)
              _row('Скидка по акции', -t.promoDiscount),
            if (t.appliedPromotions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Применено: ${t.appliedPromotions.join(', ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(),
            _row('Сумма со скидкой', t.afterDiscounts),
            _row('НДС $vatPercent %', t.vat),
            const Divider(),
            _row('Итого', t.total, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text('${value.toStringAsFixed(2)} ₽', style: style),
        ],
      ),
    );
  }
}