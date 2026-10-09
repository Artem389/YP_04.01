import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final withSelection = onToggleSelect != null;
    final withActions = actions != null;

    // ВАЖНО: число колонок в header должно совпадать с числом ячеек в DataRow.
    // Считаем его один раз и используем в обоих местах.
    final columnCount = columns.length + (withActions ? 1 : 0);
    assert(columnCount > 0, 'У таблицы должна быть хотя бы одна колонка');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Ширина таблицы = max(ширина окна, минимальная комфортная ширина).
            // Минимум подобран так, чтобы колонки не сжимались в кашу.
            minWidth: MediaQuery.sizeOf(context).width < 900
                ? 900
                : MediaQuery.sizeOf(context).width,
          ),
          child: DataTable(
            sortColumnIndex: _sortIndex(),
            sortAscending: sortAscending,
            columnSpacing: 24,
            horizontalMargin: 12,
            // Колонку под штатный чекбокс DataRow НЕ добавляем — её рисует
            // сам DataRow.onSelectChanged. Пользовательские колонки идут
            // с индекса 0, поэтому sortColumnIndex = i.
            columns: [
              for (var i = 0; i < columns.length; i++)
                DataColumn(
                  label: Text(columns[i].label),
                  numeric: columns[i].numeric,
                  onSort: (columns[i].sortField != null && onSort != null)
                      ? (_, __) => onSort!(columns[i].sortField!)
                      : null,
                ),
              if (withActions) const DataColumn(label: Text('')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  selected: withSelection && selected.contains(idOf(item)),
                  onSelectChanged: withSelection
                      ? (_) => onToggleSelect!(idOf(item))
                      : null,
                  // Число ячеек строго равно columnCount:
                  // columns.length пользовательских + 1 под действия.
                  cells: [
                    for (final c in columns) DataCell(c.build(item)),
                    if (withActions)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!(item),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Индекс колонки сортировки. Штатный чекбокс DataRow НЕ считается
  /// колонкой в sortColumnIndex — он встроен в первую пользовательскую.
  int? _sortIndex() {
    if (sortField == null) return null;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].sortField == sortField) {
        return i;
      }
    }
    return null;
  }
}
