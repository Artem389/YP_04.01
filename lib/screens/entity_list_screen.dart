import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/product_query.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_card.dart';
import '../widgets/entity_table.dart';

/// Обобщённый экран списка для любой сущности.
/// Настраивается: колонки, маршруты, обработчик удаления.
class EntityListScreen<T> extends StatefulWidget {
  final String title;
  final String basePath; // '/products', '/suppliers'
  final Map<String, String> queryParams;
  final List<TableColumnSpec<T>> Function(BuildContext) columnsBuilder;
  final List<Widget> Function(BuildContext, T)? actionsBuilder;
  final Future<void> Function(BuildContext, T) onDelete;
  final String? newPath; // '/suppliers/new'

  const EntityListScreen({
    super.key,
    required this.title,
    required this.basePath,
    required this.queryParams,
    required this.columnsBuilder,
    required this.onDelete,
    this.actionsBuilder,
    this.newPath,
  });

  @override
  State<EntityListScreen<T>> createState() => _EntityListScreenState<T>();
}

class _EntityListScreenState<T> extends State<EntityListScreen<T>> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.queryParams['search'] ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final q = ProductQuery.fromUri(widget.queryParams);
      context.read<EntityListNotifier<T>>().applyQuery(q);
    });
  }

  @override
  void didUpdateWidget(covariant EntityListScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пользователь нажал «назад» или вставил другой URL — перечитываем.
    if (oldWidget.queryParams != widget.queryParams) {
      final q = ProductQuery.fromUri(widget.queryParams);
      final notifier = context.read<EntityListNotifier<T>>();
      final current = notifier.query;

      // Синхронизация поля поиска — это безопасно: обычный setState,
      // он не будит провайдер.
      if (_searchController.text != q.search) {
        _searchController.text = q.search;
      }

      if (q.toUri().toString() != current.toUri().toString()) {
        // КЛЮЧЕВОЙ МОМЕНТ: notifyListeners() нельзя вызывать в build/didUpdateWidget.
        // Откладываем на следующий кадр.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<EntityListNotifier<T>>().applyQuery(q);
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(ProductQuery next, {bool resetPage = true}) {
    final q = resetPage ? next.copyWith(page: 1) : next;
    final uri = Uri(
      path: widget.basePath,
      queryParameters: q.toUri().isEmpty ? null : q.toUri(),
    );
    context.go(uri.toString());
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _updateQuery(
        context.read<EntityListNotifier<T>>().query.copyWith(search: value),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<EntityListNotifier<T>>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () => context.go('/'),
        ),
        title: Text(widget.title),
        actions: [
          if (notifier.hasSelection) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
            IconButton(
              tooltip: 'Удалить выбранные',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _confirmDeleteSelected(context),
            ),
          ],
          if (widget.newPath != null)
            IconButton(
              tooltip: 'Добавить',
              icon: const Icon(Icons.add),
              onPressed: () => context.go(widget.newPath!),
            ),
        ],
      ),
      body: Column(
        children: [
          _filters(notifier),
          Expanded(child: _body(notifier)),
          _pager(notifier),
        ],
      ),
    );
  }

  Widget _filters(EntityListNotifier<T> n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Поиск',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          FilterChip(
            label: const Text('Показать удалённые'),
            selected: n.query.includeDeleted,
            onSelected: (v) =>
                _updateQuery(n.query.copyWith(includeDeleted: v)),
          ),
          TextButton.icon(
            onPressed: () => _updateQuery(const ProductQuery()),
            icon: const Icon(Icons.clear),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  Widget _body(EntityListNotifier<T> n) {
    switch (n.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(n.error ?? 'Ошибка'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => n.load(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        );
      case LoadStatus.success:
        if (n.result.items.isEmpty) {
          return const Center(child: Text('Записей не найдено'));
        }
        return byScreen(
          context,
          compact: _cardList(context, n),
          medium: _table(context, n),
          expanded: _table(context, n),
        );
    }
  }

  Widget _cardList(BuildContext context, EntityListNotifier<T> n) {
    final cols = widget.columnsBuilder(context);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: n.result.items.length,
      itemBuilder: (_, i) {
        final item = n.result.items[i];
        final id = _idOf(item);

        final titleWidget = cols.isNotEmpty
            ? DefaultTextStyle(
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
                child: cols[0].build(item),
              )
            : const SizedBox.shrink();

        final lines = <Widget>[];
        for (var k = 1; k < cols.length; k++) {
          final col = cols[k];
          lines.add(
            Row(
              children: [
                Text(
                  '${col.label}: ',
                  style: const TextStyle(color: Colors.grey),
                ),
                Expanded(child: col.build(item)),
              ],
            ),
          );
        }

        final actions = <Widget>[
          if (widget.actionsBuilder != null)
            ...widget.actionsBuilder!(context, item),
        ];

        return EntityCard<T>(
          item: item,
          title: titleWidget,
          lines: lines,
          selected: n.selected.contains(id),
          onToggle: () => n.toggleSelection(id),
          actions: actions,
        );
      },
    );
  }

  Widget _table(BuildContext context, EntityListNotifier<T> n) {
    return EntityTable<T>(
      items: n.result.items,
      idOf: (item) => _idOf(item),
      selected: n.selected,
      onToggleSelect: n.toggleSelection,
      sortField: n.query.sortField,
      sortAscending: n.query.sortAscending,
      onSort: (field) {
        final sameField = field == n.query.sortField;
        _updateQuery(
          n.query.copyWith(
            sortField: field,
            sortAscending: sameField ? !n.query.sortAscending : true,
          ),
          resetPage: false,
        );
      },
      columns: widget.columnsBuilder(context),
      actions: (item) => widget.actionsBuilder?.call(context, item) ?? [],
    );
  }

  int _idOf(T item) {
    // Ищем поле id через рефлексию нельзя — используем соглашение:
    // все модели имеют поле id. Приводим через dynamic.
    final dynamic d = item;
    return d.id as int;
  }

  Widget _pager(EntityListNotifier<T> n) {
    final r = n.result;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Всего: ${r.total}'),
          const Spacer(),
          DropdownButton<int>(
            value: n.query.size,
            onChanged: (v) {
              if (v == null) return;
              _updateQuery(n.query.copyWith(size: v), resetPage: false);
            },
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: r.hasPrevious
                ? () =>
                      _updateQuery(n.query.copyWith(page: 1), resetPage: false)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: r.hasPrevious
                ? () => _updateQuery(
                    n.query.copyWith(page: n.query.page - 1),
                    resetPage: false,
                  )
                : null,
          ),
          Text('${r.page} / ${r.totalPages}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: r.hasNext
                ? () => _updateQuery(
                    n.query.copyWith(page: n.query.page + 1),
                    resetPage: false,
                  )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: r.hasNext
                ? () => _updateQuery(
                    n.query.copyWith(page: r.totalPages),
                    resetPage: false,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final n = context.read<EntityListNotifier<T>>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить выбранные?'),
        content: Text('Будет помечено как удалённых: ${n.selected.length}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await n.deleteSelected();
    }
  }
}
