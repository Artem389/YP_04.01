import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/not_found_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) {
        // Все фильтры приходят через query — ПР2 п.16.
        return ProductListScreen(queryParams: state.uri.queryParameters);
      },
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const ProductFormScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return ProductFormScreen(productId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/categories',
      builder: (_, __) => const CategoryListScreen(),
    ),
  ],
  errorBuilder: (_, state) => NotFoundScreen(location: state.uri.toString()),
);