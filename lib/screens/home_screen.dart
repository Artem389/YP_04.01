import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../repositories/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Продуктовый магазин'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthRepository>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MenuButton(
                  icon: Icons.storefront,
                  label: 'Каталог товаров',
                  onPressed: () => context.go('/products'),
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.category,
                  label: 'Категории',
                  onPressed: () => context.go('/categories'),
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.local_shipping,
                  label: 'Поставщики',
                  onPressed: () => context.go('/suppliers'),
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.people,
                  label: 'Покупатели',
                  onPressed: () => context.go('/customers'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}