import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'router.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // убирает решётку из адреса
  await ThemeController.instance.load();
  runApp(const CalcApp());
}

class CalcApp extends StatelessWidget {
  const CalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Калькулятор и конвертер',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          routerConfig: appRouter,
        );
      },
    );
  }
}