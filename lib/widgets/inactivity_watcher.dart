import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

/// Сбрасывает таймер неактивности при любом действии пользователя.
/// Оборачивает всё приложение (см. main.dart).
class InactivityWatcher extends StatefulWidget {
  final Widget child;
  const InactivityWatcher({super.key, required this.child});

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально: виджет обёртки не имеет FocusNode,
    // поэтому KeyboardListener не подойдёт — он не получал бы события
    // при наборе текста в форме.
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// false — событие не поглощено, передаём дальше.
  bool _onKey(KeyEvent event) {
    context.read<AuthNotifier>().onUserActivity();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Перехват без поглощения: события идут к виджетам дальше.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => context.read<AuthNotifier>().onUserActivity(),
      onPointerMove: (_) => context.read<AuthNotifier>().onUserActivity(),
      onPointerSignal: (_) => context.read<AuthNotifier>().onUserActivity(),
      child: widget.child,
    );
  }
}