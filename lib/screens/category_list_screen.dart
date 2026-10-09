// lib/screens/category_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import '../repositories/product_category_repository.dart';
import '../repositories/product_repository.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_card.dart';
import '../widgets/entity_table.dart';

class CategoryListScreen extends StatefulWidget {
  final Map<String, String> queryParams;
  const CategoryListScreen({super.key, required this.queryParams});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Кэш числа товаров по категории, чтобы не дёргать репозиторий
  /// в build.
  final Map<int, int> _linkedProductsCountCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.queryParams['search'] ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q = ProductQuery.fromUri(widget.queryParams);
      context.read<EntityListNotifier<ProductCategory>>().applyQuery(q);
    });
  }

  @override
  void didUpdateWidget(covariant CategoryListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryParams != widget.queryParams) {
      final q = ProductQuery.fromUri(widget.queryParams);
      final current =
          context.read<EntityListNotifier<ProductCategory>>().query;
      if (_searchController.text != q.search) {
        _searchController.text = q.search;
      }
      if (q.toUri().toString() != current.toUri().toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context
              .read<EntityListNotifier<ProductCategory>>()
              .applyQuery(q);
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

  /// Применяет новый запрос, отражая его в адресной строке.
  void _updateQuery(ProductQuery next, {bool resetPage = true}) {
    final q = resetPage ? next.copyWith(page: 1) : next;
    final uri = Uri(
      path: '/categories',
      queryParameters: q.toUri().isEmpty ? null : q.toUri(),
    );
    context.go(uri.toString());
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final n = context.read<EntityListNotifier<ProductCategory>>();
      _updateQuery(n.query.copyWith(search: value));
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _updateQuery(const ProductQuery());
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<EntityListNotifier<ProductCategory>>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Категории'),
        actions: [
          if (n.hasSelection) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Выбрано: ${n.selected.length}'),
              ),
            ),
            IconButton(
              tooltip: 'Удалить выбранные',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _confirmDeleteSelected(context),
            ),
          ],
          IconButton(
            tooltip: 'Добавить категорию',
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/categories/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(n),
          Expanded(child: _body(n)),
          _pager(n),
        ],
      ),
    );
  }

  Widget _filters(EntityListNotifier<ProductCategory> n) {
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
                labelText: 'Поиск по названию или описанию',
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
            onPressed: _resetFilters,
            icon: const Icon(Icons.clear),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  Widget _body(EntityListNotifier<ProductCategory> n) {
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
          return const Center(child: Text('Категорий не найдено'));
        }
        // Перед отрисовкой обновим кэш счётчиков.
        _refreshLinkedCounts(n.result.items);
        return byScreen(
          context,
          compact: _cardList(context, n),
          medium: _table(context, n),
          expanded: _table(context, n),
        );
    }
  }

  Widget _cardList(
      BuildContext context, EntityListNotifier<ProductCategory> n) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: n.result.items.length,
      itemBuilder: (_, i) {
        final c = n.result.items[i];
        final linked = _linkedProductsCountCache[c.id];

        return EntityCard<ProductCategory>(
          item: c,
          title: Text(c.name),
          lines: [
            Text('Описание: ${c.description}'),
            Text('Товаров: ${linked ?? '…'}'),
          ],
          selected: n.selected.contains(c.id),
          onToggle: () => n.toggleSelection(c.id),
          actions: [
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/categories/${c.id}/edit'),
            ),
            if (c.isDeleted)
              IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.restore),
                onPressed: () => _restore(context, c),
              )
            else
              IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmSoftDelete(context, c),
              ),
          ],
        );
      },
    );
  }

  Widget _table(
      BuildContext context, EntityListNotifier<ProductCategory> n) {
    return EntityTable<ProductCategory>(
      items: n.result.items,
      idOf: (c) => c.id,
      selected: n.selected,
      onToggleSelect: n.toggleSelection,
      sortField: n.query.sortField,
      sortAscending: n.query.sortAscending,
      onSort: (field) {
        final same = field == n.query.sortField;
        _updateQuery(
          n.query.copyWith(
            sortField: field,
            sortAscending: same ? !n.query.sortAscending : true,
          ),
          resetPage: false,
        );
      },
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (c) => Text(c.name),
        ),
        TableColumnSpec(
          label: 'Описание',
          sortField: 'description',
          build: (c) => Text(c.description),
        ),
        TableColumnSpec(
          label: 'Товаров',
          numeric: true,
          build: (c) => Text('${_linkedProductsCountCache[c.id] ?? '…'}'),
        ),
      ],
      actions: (c) => [
        IconButton(
          tooltip: 'Редактировать',
          icon: const Icon(Icons.edit),
          onPressed: () => context.go('/categories/${c.id}/edit'),
        ),
        if (c.isDeleted)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(context, c),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Действия',
            onSelected: (value) async {
              if (value == 'soft') {
                await _confirmSoftDelete(context, c);
              } else if (value == 'hard') {
                await _confirmHardDelete(context, c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'soft',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Пометить как удалённое'),
                ),
              ),
              PopupMenuItem(
                value: 'hard',
                child: ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Удалить навсегда'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _pager(EntityListNotifier<ProductCategory> n) {
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
                ? () => _updateQuery(
              n.query.copyWith(page: 1),
              resetPage: false,
            )
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

  /// Обновляет кэш «сколько товаров в каждой категории».
  Future<void> _refreshLinkedCounts(List<ProductCategory> cats) async {
    final repo = context.read<ProductRepository>();
    var changed = false;
    for (final c in cats) {
      if (_linkedProductsCountCache.containsKey(c.id)) continue;
      try {
        final count = await repo.countByCategory(c.id);
        _linkedProductsCountCache[c.id] = count;
        changed = true;
      } catch (_) {
        // не критично для отображения списка — оставим «…»
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmSoftDelete(
      BuildContext context, ProductCategory c) async {
    final productRepo = context.read<ProductRepository>();
    final linked = await productRepo.countByCategory(c.id);
    if (!context.mounted) return;

    if (linked > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Удаление невозможно'),
          content: Text(
            'На категорию «${c.name}» ссылаются $linked товаров.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «${c.name}» будет помечена как удалённая.',
        ),
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
      await context.read<ProductCategoryRepository>().softDelete(c.id);
      if (context.mounted) {
        await context
            .read<EntityListNotifier<ProductCategory>>()
            .load();
      }
    }
  }

  Future<void> _confirmHardDelete(
      BuildContext context, ProductCategory c) async {
    final productRepo = context.read<ProductRepository>();
    final linked = await productRepo.countByCategory(c.id);
    if (!context.mounted) return;

    if (linked > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Удаление невозможно'),
          content: Text(
            'На категорию «${c.name}» ссылаются $linked товаров.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить категорию навсегда?'),
        content: Text(
          'Категория «${c.name}» будет удалена физически. '
              'Восстановление невозможно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ProductCategoryRepository>().hardDelete(c.id);
      _linkedProductsCountCache.remove(c.id);
      if (context.mounted) {
        await context
            .read<EntityListNotifier<ProductCategory>>()
            .load();
      }
    }
  }

  Future<void> _restore(
      BuildContext context, ProductCategory c) async {
    await context.read<ProductCategoryRepository>().restore(c.id);
    if (context.mounted) {
      await context.read<EntityListNotifier<ProductCategory>>().load();
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final n = context.read<EntityListNotifier<ProductCategory>>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить выбранные категории?'),
        content: Text(
          'Будет помечено как удалённых: ${n.selected.length}.',
        ),
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
      // после удаления сбрасываем кэш — количество могло измениться
      _linkedProductsCountCache.clear();
    }
  }
}