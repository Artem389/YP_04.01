import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/role.dart';
import '../state/auth_notifier.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Продуктовый магазин'),
        actions: [
          if (user != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(fontSize: 13)),
                    Text(user.role.label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Выйти',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthNotifier>().logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Доступно всем залогиненным.
                _MenuButton(
                  icon: Icons.storefront,
                  label: 'Каталог товаров',
                  onPressed: () => context.go('/products'),
                ),
                const SizedBox(height: 16),

                // Категории и поставщики — менеджер и выше.
                if (auth.has(Role.manager)) ...[
                  _MenuButton(
                    icon: Icons.category,
                    label: 'Категории',
                    onPressed: () => context.go('/categories'),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: Icons.bar_chart,
                    label: 'Отчёт по категориям',
                    onPressed: () => context.go('/reports/categories'),
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
                  const SizedBox(height: 16),
                  if (auth.has(Role.manager)) ...[
                    _MenuButton(
                      icon: Icons.local_offer,
                      label: 'Акции',
                      onPressed: () => context.go('/promotions'),
                    ),

                  ],
                  const SizedBox(height: 16),
                ],

                // Мои покупки — доступно всем, но данные зависят от роли.
                _MenuButton(
                  icon: Icons.receipt_long,
                  label: 'Продажи',
                  onPressed: () => context.go('/sales'),
                ),
                const SizedBox(height: 16),

                // Только админ.
                if (auth.has(Role.admin))
                  _MenuButton(
                    icon: Icons.admin_panel_settings,
                    label: 'Пользователи (админ)',
                    onPressed: () => context.go('/admin/users'),
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