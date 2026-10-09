import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/supplier.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../screens/admin_users_screen.dart';
import '../screens/category_form_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/category_report_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_sales_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/promotion_form_screen.dart';
import '../screens/promotion_list_screen.dart';
import '../screens/register_screen.dart';
import '../screens/sell_product_screen.dart';
import '../screens/supplier_form_screen.dart';
import '../state/auth_notifier.dart';
import '../widgets/entity_table.dart';
import 'role.dart';

/// Собирает роутер. Вызывается из main после создания AuthNotifier.
GoRouter buildRouter(AuthNotifier auth) {
  return GoRouter(
    // Важно: при каждом notifyListeners() пересчитывается redirect,
    // поэтому после входа/выхода маршрутизатор сам перебросит пользователя.
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      // Не вошёл и идёт на закрытый экран — на вход,
      // запомнив адрес, куда хотел попасть (п. 11).
      if (!loggedIn && !isPublic) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }

      // Уже вошёл и идёт на экран входа — на главную.
      if (loggedIn && isPublic) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),

      // ─── Продажи: доступно всем ролям, данные фильтрует сервер ───
      GoRoute(
        path: '/sales',
        builder: (context, state) =>
            MySalesScreen(queryParams: state.uri.queryParameters),
      ),

      // ─── ТОВАРЫ ───
      GoRoute(
        path: '/products',
        builder: (context, state) =>
            ProductListScreen(queryParams: state.uri.queryParameters),
        routes: [
          GoRoute(
            path: 'new',
            // Добавлять товар — только manager и выше.
            redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
            builder: (_, __) => const ProductFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
            builder: (_, state) => ProductFormScreen(
              productId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: ':id/sell',
            // Оформлять покупку может только покупатель (client),
            // а не менеджер и не админ.
            redirect: (_, __) {
              final isClient =
                  auth.has(Role.client) &&
                  !auth.has(Role.manager) &&
                  !auth.has(Role.admin);
              return isClient ? null : '/forbidden';
            },
            builder: (_, state) => SellProductScreen(
              productId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),

      // ─── КАТЕГОРИИ (manager+) ───
      GoRoute(
        path: '/categories',
        redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
        builder: (context, state) =>
            CategoryListScreen(queryParams: state.uri.queryParameters),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const CategoryFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => CategoryFormScreen(
              categoryId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),

      // ─── ПОСТАВЩИКИ (manager+) ───
      GoRoute(
        path: '/suppliers',
        redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
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
            TableColumnSpec(label: 'Email', build: (s) => Text(s.email)),
            TableColumnSpec(label: 'Телефон', build: (s) => Text(s.phone)),
          ],
          actionsBuilder: (ctx, s) => [
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit),
              onPressed: () => ctx.go('/suppliers/${s.id}/edit'),
            ),
          ],
        ),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const SupplierFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => SupplierFormScreen(
              supplierId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),

      // ─── ПОКУПАТЕЛИ (manager+) ───
      GoRoute(
        path: '/customers',
        redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
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
            TableColumnSpec(label: 'Email', build: (c) => Text(c.email)),
            TableColumnSpec(label: 'Телефон', build: (c) => Text(c.phone)),
            TableColumnSpec(
              label: 'Карта',
              build: (c) => Text(
                c.card == null
                    ? '—'
                    : '${c.card!.number} (${c.card!.discountPercent}%)',
              ),
            ),
          ],
          actionsBuilder: (ctx, c) => [
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit),
              onPressed: () => ctx.go('/customers/${c.id}/edit'),
            ),
          ],
        ),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const CustomerFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => CustomerFormScreen(
              customerId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      // ─── АКЦИИ (manager+) ───
      GoRoute(
        path: '/promotions',
        redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
        builder: (context, state) =>
            PromotionListScreen(queryParams: state.uri.queryParameters),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const PromotionFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => PromotionFormScreen(
              promotionId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/reports/categories',
        redirect: (_, __) => auth.has(Role.manager) ? null : '/forbidden',
        builder: (_, __) => const CategoryReportScreen(),
      ),

      // ─── АДМИН: пользователи ───
      GoRoute(
        path: '/admin/users',
        redirect: (_, __) => auth.has(Role.admin) ? null : '/forbidden',
        builder: (_, __) => const AdminUsersScreen(),
      ),
    ],
    errorBuilder: (_, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
