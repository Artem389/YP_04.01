import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'models/customer.dart';
import 'models/product_category.dart';
import 'models/supplier.dart';
import 'repositories/customer_repository.dart';
import 'repositories/persistent_customer_repository.dart';
import 'repositories/persistent_product_category_repository.dart';
import 'repositories/persistent_product_repository.dart';
import 'repositories/persistent_supplier_repository.dart';
import 'repositories/product_category_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/supplier_repository.dart';
import 'state/customer_list_notifier.dart';
import 'state/entity_list_notifier.dart';
import 'state/product_category_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/supplier_list_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),

        Provider<ProductRepository>(
          create: (_) => PersistentProductRepository(prefs),
        ),
        Provider<ProductCategoryRepository>(
          create: (_) => PersistentProductCategoryRepository(prefs),
        ),
        Provider<SupplierRepository>(
          create: (_) => PersistentSupplierRepository(prefs),
        ),
        Provider<CustomerRepository>(
          create: (_) => PersistentCustomerRepository(prefs),
        ),

        ChangeNotifierProvider(
          create: (ctx) =>
          SupplierListNotifier(ctx.read<SupplierRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
          CustomerListNotifier(ctx.read<CustomerRepository>())..load(),
        ),

        ChangeNotifierProvider(
          create: (ctx) =>
              ProductListNotifier(ctx.read<ProductRepository>()),
        ),

        // Обобщённые нотифаеры для поставщиков, покупателей и категорий
        ChangeNotifierProvider<EntityListNotifier<Supplier>>(
          create: (ctx) => EntityListNotifier<Supplier>(
            fetcher: ctx.read<SupplierRepository>().find,
            deleteMany: (ids) async {
              final repo = ctx.read<SupplierRepository>();
              var count = 0;
              for (final id in ids) {
                await repo.softDelete(id);
                count++;
              }
              return count;
            },
          ),
        ),
        ChangeNotifierProvider<EntityListNotifier<Customer>>(
          create: (ctx) => EntityListNotifier<Customer>(
            fetcher: ctx.read<CustomerRepository>().find,
            deleteMany: (ids) async {
              final repo = ctx.read<CustomerRepository>();
              var count = 0;
              for (final id in ids) {
                await repo.softDelete(id);
                count++;
              }
              return count;
            },
          ),
        ),

// НОВЫЙ — для категорий:
        ChangeNotifierProvider<EntityListNotifier<ProductCategory>>(
          create: (ctx) => EntityListNotifier<ProductCategory>(
            fetcher: ctx.read<ProductCategoryRepository>().find,
            deleteMany: (ids) async {
              final repo = ctx.read<ProductCategoryRepository>();
              var count = 0;
              for (final id in ids) {
                await repo.softDelete(id);
                count++;
              }
              return count;
            },
          ),
        ),
      ],
      child: const GroceryApp(),
    ),
  );
}

class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Продуктовый магазин',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
      // Показ SnackBar при сбросе данных из-за старого формата.
      builder: (context, child) => _ResetNotifier(child: child ?? const SizedBox()),
    );
  }
}

/// Обёртка, которая после первого кадра проверяет, сбрасывались ли
/// данные из-за несовместимого формата, и показывает SnackBar.
class _ResetNotifier extends StatefulWidget {
  final Widget child;
  const _ResetNotifier({required this.child});

  @override
  State<_ResetNotifier> createState() => _ResetNotifierState();
}

class _ResetNotifierState extends State<_ResetNotifier> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final repo = context.read<ProductRepository>();
      if (repo is PersistentProductRepository && repo.wasReset) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Данные товаров были сброшены: старый формат не поддерживается',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}