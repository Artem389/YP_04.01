import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_web/repositories/api_sale_repository.dart';
import 'package:flutter_project_web/repositories/sale_repository.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/token_storage.dart';
import 'models/customer.dart';
import 'models/product_category.dart';
import 'models/promotion.dart';
import 'models/supplier.dart';
import 'repositories/api_customer_repository.dart';
import 'repositories/api_product_category_repository.dart';
import 'repositories/api_product_repository.dart';
import 'repositories/api_promotion_repository.dart';
import 'repositories/api_supplier_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/product_category_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/promotion_repository.dart';
import 'repositories/supplier_repository.dart';
import 'state/auth_notifier.dart';
import 'state/entity_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/reference_data_notifier.dart';
import 'widgets/inactivity_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStorage(prefs);

  AuthNotifier? authRef;

  final dio = buildDio(
    tokens: tokens,
    onRefreshToken: () async {
      final auth = AuthRepository(buildDio(tokens: tokens), tokens);
      try {
        await auth.refresh();
        return true;
      } catch (_) {
        return false;
      }
    },
    onTokensRefreshed: () async {
      await authRef?.onTokensRefreshed();
    },
    onUnauthorized: () async {
      await authRef?.logout();
    },
  );

  final authApi = AuthRepository(dio, tokens);
  final auth = AuthNotifier(authApi, tokens);
  authRef = auth;

  await auth.restore();

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<TokenStorage>.value(value: tokens),
        Provider<Dio>.value(value: dio),
        Provider<AuthRepository>.value(value: authApi),
        Provider<SaleRepository>(create: (_) => ApiSaleRepository(dio)),

        ChangeNotifierProvider<AuthNotifier>.value(value: auth),

        Provider<ProductRepository>(create: (_) => ApiProductRepository(dio)),
        Provider<ProductCategoryRepository>(
          create: (_) => ApiProductCategoryRepository(dio),
        ),
        Provider<SupplierRepository>(create: (_) => ApiSupplierRepository(dio)),
        Provider<CustomerRepository>(create: (_) => ApiCustomerRepository(dio)),
        Provider<PromotionRepository>(
          create: (_) => ApiPromotionRepository(dio),
        ),

        ChangeNotifierProvider<ReferenceDataNotifier>(
          create: (ctx) => ReferenceDataNotifier(
            ctx.read<ProductCategoryRepository>(),
            ctx.read<SupplierRepository>(),
          )..ensureLoaded(),
        ),

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
        ChangeNotifierProvider<EntityListNotifier<Promotion>>(
          create: (ctx) => EntityListNotifier<Promotion>(
            fetcher: ctx.read<PromotionRepository>().find,
            deleteMany: (ids) async {
              var count = 0;
              final repo = ctx.read<PromotionRepository>();
              for (final id in ids) {
                await repo.softDelete(id);
                count++;
              }
              return count;
            },
          ),
        ),
      ],
      child: GroceryApp(auth: auth),
    ),
  );
}

class GroceryApp extends StatefulWidget {
  final AuthNotifier auth;
  const GroceryApp({super.key, required this.auth});

  @override
  State<GroceryApp> createState() => _GroceryAppState();
}

class _GroceryAppState extends State<GroceryApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(widget.auth);
    widget.auth.onSessionExpired = (reason) {
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Сессия завершена'),
          content: Text(reason),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _router.go('/login');
              },
              child: const Text('Войти заново'),
            ),
          ],
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Продуктовый магазин',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: _router,
      builder: (context, child) {
        // Пока роутер не отрисовал первый экран, показываем заглушку.
        // Это убирает белый экран при холодной загрузке.
        return InactivityWatcher(child: child ?? _StartupPlaceholder());
      },
    );
  }
}

class _StartupPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Продуктовый магазин',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
