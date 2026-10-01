import 'package:flutter/material.dart';

/// Универсальная карточка сущности — аналог ProductCard,
/// но настраиваемая через описание полей.
class EntityCard<T> extends StatelessWidget {
  final T item;
  /// Основной заголовок (обычно первая колонка).
  final Widget title;
  /// Дополнительные строки (остальные колонки).
  final List<Widget> lines;
  final bool selected;
  final VoidCallback? onToggle;
  final List<Widget> actions;

  const EntityCard({
    super.key,
    required this.item,
    required this.title,
    this.lines = const [],
    this.selected = false,
    this.onToggle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: onToggle == null
            ? null
            : Checkbox(value: selected, onChanged: (_) => onToggle!()),
        title: title,
        subtitle: lines.isEmpty
            ? null
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines) ...[
              l,
              const SizedBox(height: 2),
            ],
          ],
        ),
        isThreeLine: lines.length >= 2,
        trailing: actions.isEmpty
            ? null
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }
}