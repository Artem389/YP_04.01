import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/supplier.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../screens/category_form_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/supplier_form_screen.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_table.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),

    // ---- ТОВАРЫ ----
    GoRoute(
      path: '/products',
      builder: (context, state) =>
          ProductListScreen(queryParams: state.uri.queryParameters),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const ProductFormScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) => ProductFormScreen(
            productId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
        ),
      ],
    ),

    // ---- КАТЕГОРИИ ----
    GoRoute(
      path: '/categories',
      builder: (_, __) => const CategoryListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const CategoryFormScreen(),

        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) => CategoryFormScreen(
            categoryId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
        ),
      ],
    ),

    // ---- ПОСТАВЩИКИ ----
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => EntityListScreen<Supplier>(
        title: 'Поставщики',
        basePath: '/suppliers',
        newPath: '/suppliers/new',
        queryParams: state.uri.queryParameters,
        onDelete: (ctx, s) async {
          await ctx.read<SupplierRepository>().softDelete(s.id);
        },
        columnsBuilder: (ctx) => [
          TableColumnSpec(
            label: 'Название',
            sortField: 'name',
            build: (s) => Text(s.name),
          ),
          TableColumnSpec(
            label: 'Email',
            build: (s) => Text(s.email),
          ),
          TableColumnSpec(
            label: 'Телефон',
            build: (s) => Text(s.phone),
          ),
        ],
        actionsBuilder: (ctx, s) => [
          IconButton(
            tooltip: 'Редактировать',
            icon: const Icon(Icons.edit),
            onPressed: () => ctx.go('/suppliers/${s.id}/edit'),
          ),
          if (s.isDeleted)
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore),
              onPressed: () async {
                await ctx.read<SupplierRepository>().restore(s.id);
                if (ctx.mounted) {
                  await ctx.read<EntityListNotifier<Supplier>>().load();
                }
              },
            )
          else
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDeleteSupplier(ctx, s),
            ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'hard') {
                await _confirmHardDeleteSupplier(ctx, s);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'hard',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Удалить навсегда'),
                ),
              ),
            ],
          ),
        ],
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const SupplierFormScreen(),

        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) => SupplierFormScreen(
            supplierId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
        ),
      ],
    ),

    // ---- ПОКУПАТЕЛИ ----
    GoRoute(
      path: '/customers',
      builder: (context, state) => EntityListScreen<Customer>(
        title: 'Покупатели',
        basePath: '/customers',
        newPath: '/customers/new',
        queryParams: state.uri.queryParameters,
        onDelete: (ctx, c) async {
          await ctx.read<CustomerRepository>().softDelete(c.id);
        },
        columnsBuilder: (ctx) => [
          TableColumnSpec(
            label: 'ФИО',
            sortField: 'name',
            build: (c) => Text(c.fullName),
          ),
          TableColumnSpec(
            label: 'Email',
            build: (c) => Text(c.email),
          ),
          TableColumnSpec(
            label: 'Телефон',
            build: (c) => Text(c.phone),
          ),
          TableColumnSpec(
            label: 'Карта',
            build: (c) =>
                Text(c.card == null ? '—' : '${c.card!.number} (${c.card!.discountPercent}%)'),
          ),
        ],
        actionsBuilder: (ctx, c) => [
          IconButton(
            tooltip: 'Редактировать',
            icon: const Icon(Icons.edit),
            onPressed: () => ctx.go('/customers/${c.id}/edit'),
          ),
          if (c.isDeleted)
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore),
              onPressed: () async {
                await ctx.read<CustomerRepository>().restore(c.id);
                if (ctx.mounted) {
                  await ctx.read<EntityListNotifier<Customer>>().load();
                }
              },
            )
          else
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDeleteCustomer(ctx, c),
            ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'hard') {
                await _confirmHardDeleteCustomer(ctx, c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'hard',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Удалить навсегда'),
                ),
              ),
            ],
          ),
        ],
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const CustomerFormScreen(),

        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) => CustomerFormScreen(
            customerId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (_, state) => NotFoundScreen(location: state.uri.toString()),
);

Future<void> _confirmHardDeleteCustomer(
    BuildContext context, Customer c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Удалить навсегда?'),
      content: Text(
          'Покупатель «${c.fullName}» будет удалён физически. '
              'Восстановление невозможно.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Удалить навсегда'),
        ),
      ],
    ),
  );

  if (ok == true && context.mounted) {
    await context.read<CustomerRepository>().hardDelete(c.id);
    if (context.mounted) {
      await context.read<EntityListNotifier<Customer>>().load();
    }
  }
}

Future<void> _confirmHardDeleteSupplier(
    BuildContext context, Supplier s) async {
  final repo = context.read<SupplierRepository>();

  // Сначала — проверка связанных товаров.
  final count = await repo.countLinkedProducts(s.id);
  if (!context.mounted) return;
  if (count > 0) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление невозможно'),
        content: Text(
            'На поставщика «${s.name}» ссылаются $count товаров. '
                'Сначала переназначьте их.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно')),
        ],
      ),
    );
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Удалить навсегда?'),
      content: Text(
          'Поставщик «${s.name}» будет удалён физически. '
              'Восстановление невозможно.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Удалить навсегда'),
        ),
      ],
    ),
  );

  if (ok == true && context.mounted) {
    await repo.hardDelete(s.id);
    if (context.mounted) {
      await context.read<EntityListNotifier<Supplier>>().load();
    }
  }
}

Future<bool> _confirmExit(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Несохранённые изменения'),
      content: const Text('Выйти без сохранения?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти')),
      ],
    ),
  );
  return result ?? false;   // false — заблокировать уход
}

Future<void> _confirmDeleteSupplier(BuildContext context, Supplier s) async {
  final repo = context.read<SupplierRepository>();
  final count = await repo.countLinkedProducts(s.id);
  if (!context.mounted) return;
  if (count > 0) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление невозможно'),
        content: Text(
            'На поставщика «${s.name}» ссылаются $count товаров.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Удалить поставщика?'),
      content: Text('Поставщик «${s.name}» будет помечен как удалённый.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await repo.softDelete(s.id);
    if (context.mounted) {
      await context.read<EntityListNotifier<Supplier>>().load();
    }
  }
}

Future<void> _confirmDeleteCustomer(BuildContext context, Customer c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Удалить покупателя?'),
      content: Text('Покупатель «${c.fullName}» будет помечен как удалённый.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await context.read<CustomerRepository>().softDelete(c.id);
    if (context.mounted) {
      await context.read<EntityListNotifier<Customer>>().load();
    }
  }
}