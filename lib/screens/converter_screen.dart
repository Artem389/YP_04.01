import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/currency.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String _from = 'USD';
  String _to = 'RUB';

  static const _fromKey = 'converter_from';
  static const _toKey = 'converter_to';

  @override
  void initState() {
    super.initState();
    _restoreLastPair();
  }

  Future<void> _restoreLastPair() async {
    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString(_fromKey);
    final to = prefs.getString(_toKey);
    if (!mounted) return;
    setState(() {
      if (from != null && kRates.containsKey(from)) _from = from;
      if (to != null && kRates.containsKey(to)) _to = to;
    });
  }

  Future<void> _rememberPair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fromKey, _from);
    await prefs.setString(_toKey, _to);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите сумму';
    final n = double.tryParse(value.replaceAll(',', '.'));
    if (n == null) return 'Это не число';
    if (n < 0) return 'Сумма не может быть отрицательной';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _amountController.text.replaceAll(',', '.');
    await _rememberPair();
    if (!mounted) return;
    context.go(
      '/converter/result?amount=$amount&from=$_from&to=$_to',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конвертер валют')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _from,
                      decoration: const InputDecoration(
                        labelText: 'Из валюты',
                        border: OutlineInputBorder(),
                      ),
                      items: kCurrencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _from = v ?? 'USD'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _to,
                      decoration: const InputDecoration(
                        labelText: 'В валюту',
                        border: OutlineInputBorder(),
                      ),
                      items: kCurrencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _to = v ?? 'RUB'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Сумма',
                        border: OutlineInputBorder(),
                      ),
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Конвертировать'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('На главную'),
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