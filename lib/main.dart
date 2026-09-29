import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'repositories/in_memory_product_category_repository.dart';
import 'repositories/in_memory_product_repository.dart';
import 'repositories/product_category_repository.dart';
import 'repositories/product_repository.dart';
import 'state/product_category_list_notifier.dart';
import 'state/product_list_notifier.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>(
          create: (_) => InMemoryProductRepository(),
        ),
        Provider<ProductCategoryRepository>(
          create: (_) => InMemoryProductCategoryRepository(),
        ),
        ChangeNotifierProvider<ProductCategoryListNotifier>(
          create: (ctx) => ProductCategoryListNotifier(
            ctx.read<ProductCategoryRepository>(),
          )..load(),
        ),
        ChangeNotifierProvider<ProductListNotifier>(
          create: (ctx) => ProductListNotifier(
            ctx.read<ProductRepository>(),
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