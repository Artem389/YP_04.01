import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../repositories/product_repository.dart';

class SellProductScreen extends StatefulWidget {
  final int productId;
  const SellProductScreen({super.key, required this.productId});

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  bool _saving = false;

  Future<void> _sell() async {
    setState(() => _saving = true);
    final repo = context.read<ProductRepository>();
    try {
      final product = await repo.findById(widget.productId);
      if (product == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товар не найден')),
        );
        context.go('/products');
        return;
      }
      if (product.stockAvailable < 1) {
        throw const ConflictException('Нет свободных экземпляров');
      }
      await repo.update(
        product.copyWith(stockAvailable: product.stockAvailable - 1),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Продажа оформлена')),
      );
      context.go('/products');
    } on ConflictException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Продажа невозможна'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформить продажу')),
      body: Center(
        child: _saving
            ? const CircularProgressIndicator()
            : FilledButton(
          onPressed: _sell,
          child: const Text('Продать один экземпляр'),
        ),
      ),
    );
  }
}