import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/token_storage.dart';
import 'models/customer.dart';
import 'models/product_category.dart';
import 'models/supplier.dart';
import 'repositories/api_customer_repository.dart';
import 'repositories/api_product_category_repository.dart';
import 'repositories/api_product_repository.dart';
import 'repositories/api_supplier_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/product_category_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/supplier_repository.dart';
import 'state/entity_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/reference_data_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStorage(prefs);
  configureRouterAuth(tokens);

  // Собираем Dio с автообновлением токена и логированием.
  final dio = buildDio(
    tokens: tokens,
    onRefreshToken: () async {
      final auth = AuthRepository(
        buildDio(tokens: tokens),
        tokens,
      );
      try {
        await auth.refresh();
        return true;
      } catch (_) {
        return false;
      }
    },
    onUnauthorized: () async {
      await tokens.clear();
    },
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<TokenStorage>.value(value: tokens),
        Provider<AuthRepository>(
          create: (_) => AuthRepository(dio, tokens),
        ),

        // ─── Репозитории ─────────────────────────────────────────────
        Provider<ProductRepository>(
          create: (_) => ApiProductRepository(dio),
        ),
        Provider<ProductCategoryRepository>(
          create: (_) => ApiProductCategoryRepository(dio),
        ),
        Provider<SupplierRepository>(
          create: (_) => ApiSupplierRepository(dio),
        ),
        Provider<CustomerRepository>(
          create: (_) => ApiCustomerRepository(dio),
        ),

        // ─── Справочники (кэш) ──────────────────────────────────────
        ChangeNotifierProvider<ReferenceDataNotifier>(
          create: (ctx) => ReferenceDataNotifier(
            ctx.read<ProductCategoryRepository>(),
            ctx.read<SupplierRepository>(),
          )..ensureLoaded(),
        ),

        // ─── Списки сущностей ───────────────────────────────────────
        ChangeNotifierProvider<ProductListNotifier>(
          create: (ctx) => ProductListNotifier(ctx.read<ProductRepository>()),
        ),
        ChangeNotifierProvider<EntityListNotifier<ProductCategory>>(
          create: (ctx) => EntityListNotifier<ProductCategory>(
            fetcher: ctx.read<ProductCategoryRepository>().find,
            deleteMany: (ids) async {
              var count = 0;
              final repo = ctx.read<ProductCategoryRepository>();
              for (final id in ids) {
                await repo.softDelete(id);
                count++;
              }
              return count;
            },
          ),
        ),
        ChangeNotifierProvider<EntityListNotifier<Supplier>>(
          create: (ctx) => EntityListNotifier<Supplier>(
            fetcher: ctx.read<SupplierRepository>().find,
            deleteMany: (ids) async {
              var count = 0;
              final repo = ctx.read<SupplierRepository>();
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
              var count = 0;
              final repo = ctx.read<CustomerRepository>();
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
    );
  }
}