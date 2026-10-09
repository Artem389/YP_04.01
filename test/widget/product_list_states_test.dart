import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_web/core/role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_project_web/core/token_storage.dart';
import 'package:flutter_project_web/models/page_result.dart';
import 'package:flutter_project_web/models/product.dart';
import 'package:flutter_project_web/models/product_category.dart';
import 'package:flutter_project_web/models/product_query.dart';
import 'package:flutter_project_web/models/supplier.dart';
import 'package:flutter_project_web/repositories/auth_repository.dart';
import 'package:flutter_project_web/repositories/product_category_repository.dart';
import 'package:flutter_project_web/repositories/product_repository.dart';
import 'package:flutter_project_web/repositories/supplier_repository.dart';
import 'package:flutter_project_web/screens/product_list_screen.dart';
import 'package:flutter_project_web/state/auth_notifier.dart';
import 'package:flutter_project_web/state/product_list_notifier.dart';
import 'package:flutter_project_web/state/reference_data_notifier.dart';

// ────────── Заглушки репозиториев ──────────

class _FakeProductRepo implements ProductRepository {
  final Future<PageResult<Product>> Function() onFind;
  _FakeProductRepo(this.onFind);

  @override
  Future<PageResult<Product>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) => onFind();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyCategoryRepo implements ProductCategoryRepository {
  @override
  Future<List<ProductCategory>> findAll() async => const <ProductCategory>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySupplierRepo implements SupplierRepository {
  @override
  Future<List<Supplier>> findAll() async => const <Supplier>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ────────── Реальный AuthNotifier с предустановленной ролью ──────────
//
// Вместо мока мы используем настоящий AuthNotifier и подменяем ему
// пользователя через защищённый метод. Если такого метода нет —
// используем хак: создаём реальный AuthNotifier и вручную вызываем
// приватный setter нельзя, поэтому добавляем в AuthNotifier
// публичный @visibleForTesting сеттер (см. патч ниже).

Future<AuthNotifier> _makeAuth(Role role) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStorage(prefs);
  final api = AuthRepository(Dio(), tokens);
  final auth = AuthNotifier(api, tokens);
  // Ставим пользователя вручную — метод добавлен ниже.
  auth.debugSetUser(_userWithRole(role));
  return auth;
}

AppUser _userWithRole(Role role) => AppUser(
  id: 1,
  username: 'test',
  fullName: 'Test User',
  email: 'test@example.com',
  role: role,
);

// ────────── Вспомогательная сборка ──────────

Widget _wrap({
  required ProductRepository productRepo,
  required AuthNotifier auth,
  Map<String, String> queryParams = const {},
}) {
  final list = ProductListNotifier(productRepo);
  final refs = ReferenceDataNotifier(
    _EmptyCategoryRepo(),
    _EmptySupplierRepo(),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ProductListScreen(queryParams: queryParams),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthNotifier>.value(value: auth),
      ChangeNotifierProvider<ProductListNotifier>.value(value: list),
      ChangeNotifierProvider<ReferenceDataNotifier>.value(value: refs),
      Provider<Dio>(create: (_) => Dio()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('Показывает индикатор загрузки, пока данные не пришли', (
    tester,
  ) async {
    final completer = Completer<PageResult<Product>>();
    final repo = _FakeProductRepo(() => completer.future);
    final auth = await _makeAuth(Role.manager);

    await tester.pumpWidget(_wrap(productRepo: repo, auth: auth));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const PageResult(items: [], page: 1, size: 10, total: 0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('Показывает текст «Товары не найдены» при пустом результате', (
    tester,
  ) async {
    final repo = _FakeProductRepo(
      () async => const PageResult(items: [], page: 1, size: 10, total: 0),
    );
    final auth = await _makeAuth(Role.manager);
    await tester.pumpWidget(_wrap(productRepo: repo, auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Товары не найдены'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Показывает ошибку и кнопку «Повторить»', (tester) async {
    final repo = _FakeProductRepo(() async => throw Exception('boom'));
    final auth = await _makeAuth(Role.manager);
    await tester.pumpWidget(_wrap(productRepo: repo, auth: auth));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось загрузить'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('Кнопка «Добавить товар» видна менеджеру', (tester) async {
    final repo = _FakeProductRepo(
      () async => const PageResult(items: [], page: 1, size: 10, total: 0),
    );
    final auth = await _makeAuth(Role.manager);
    await tester.pumpWidget(_wrap(productRepo: repo, auth: auth));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Кнопка «Добавить товар» скрыта покупателю', (tester) async {
    final repo = _FakeProductRepo(
      () async => const PageResult(items: [], page: 1, size: 10, total: 0),
    );
    final auth = await _makeAuth(Role.client);
    await tester.pumpWidget(_wrap(productRepo: repo, auth: auth));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNothing);
  });
}
