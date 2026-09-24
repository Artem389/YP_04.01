import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/converter_screen.dart';
import 'screens/result_screen.dart';
import 'screens/not_found_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/calculator',
      builder: (context, state) => const CalculatorScreen(),
      routes: [
        GoRoute(
          path: 'result',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            final rawOp = q['op'] ?? '+';
            final op = (rawOp.isEmpty || rawOp == ' ') ? '+' : rawOp;

            return ResultScreen(
              title: 'Результат вычисления',
              expression: '${q['a']} $op ${q['b']}',
              rawQuery: q,
              backPath: '/calculator',
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/converter',
      builder: (context, state) => const ConverterScreen(),
      routes: [
        GoRoute(
          path: 'result',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            return ResultScreen(
              title: 'Результат конвертации',
              expression: '${q['amount']} ${q['from']} → ${q['to']}',
              rawQuery: q,
              backPath: '/converter',
            );
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);