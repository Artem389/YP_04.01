import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/role.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../state/product_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_card.dart';
import '../widgets/entity_table.dart';

class ProductListScreen extends StatefulWidget {
  final Map<String, String> queryParams;
  const ProductListScreen({super.key, required this.queryParams});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.queryParams['search'] ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Справочники — из кэша, без повторного запроса при каждом заходе.
      context.read<ReferenceDataNotifier>().ensureLoaded();

      final q = ProductQuery.fromUri(widget.queryParams);
      context.read<ProductListNotifier>().applyQuery(q);
    });
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryParams != widget.queryParams) {
      final q = ProductQuery.fromUri(widget.queryParams);
      final current = context.read<ProductListNotifier>().query;
      if (_searchController.text != q.search) {
        _searchController.text = q.search;
      }
      if (q.toUri().toString() != current.toUri().toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<ProductListNotifier>().applyQuery(q);
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
      path: '/products',
      queryParameters: q.toUri().isEmpty ? null : q.toUri(),
    );
    context.go(uri.toString());
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _updateQuery(
        context.read<ProductListNotifier>().query.copyWith(search: value),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProductListNotifier>();
    final refs = context.watch<ReferenceDataNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог товаров'),
        actions: [
          if (notifier.hasSelection && context.watch<AuthNotifier>().has(Role.manager)) ...[
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
          IconButton(
            tooltip: 'Добавить товар',
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/products/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(context, notifier, refs),
          Expanded(child: _body(context, notifier, refs)),
          _pager(context, notifier),
        ],
      ),
    );
  }

  Widget _filters(
      BuildContext context,
      ProductListNotifier n,
      ReferenceDataNotifier refs,
      ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Поиск по названию или артикулу',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              value: n.query.categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Все категории')),
                for (final cat in refs.categories)
                  DropdownMenuItem(value: cat.id, child: Text(cat.name)),
              ],
              onChanged: (v) => _updateQuery(n.query.copyWith(categoryId: v)),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextFormField(
              initialValue: n.query.priceFrom?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Цена от',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: (v) => _updateQuery(
                n.query.copyWith(priceFrom: double.tryParse(v)),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextFormField(
              initialValue: n.query.priceTo?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Цена до',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: (v) => _updateQuery(
                n.query.copyWith(priceTo: double.tryParse(v)),
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

  Widget _body(
      BuildContext context,
      ProductListNotifier n,
      ReferenceDataNotifier refs,
      ) {
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
          return const Center(child: Text('Товары не найдены'));
        }
        return byScreen(
          context,
          compact: _cardList(context, n, refs),
          medium: _table(context, n, refs),
          expanded: _table(context, n, refs),
        );
    }
  }

  Widget _cardList(
      BuildContext context,
      ProductListNotifier n,
      ReferenceDataNotifier refs,
      ) {
    // Менеджер и выше видят кнопки редактирования/удаления.
    final canManage = context.watch<AuthNotifier>().has(Role.manager);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: n.result.items.length,
      itemBuilder: (_, i) {
        final p = n.result.items[i];
        return EntityCard<Product>(
          item: p,
          title: Text(p.name),
          lines: [
            Text('Артикул: ${p.sku}'),
            Text('Категория: ${refs.categoryById(p.categoryId)?.name ?? '—'}'),
            Text('Цена: ${p.price.toStringAsFixed(2)} ₽'),
            Text('В наличии: ${p.stockAvailable} / ${p.stockTotal}'),
          ],
          selected: n.selected.contains(p.id),
          // Отметку тоже прячем: у клиента нет массовых операций.
          onToggle: canManage ? () => n.toggleSelection(p.id) : null,
          actions: canManage
              ? [
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/products/${p.id}/edit'),
            ),
            if (p.isDeleted)
              IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.restore),
                onPressed: () => n.restore(p.id),
              )
            else
              IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, p.id),
              ),
            PopupMenuButton<String>(
              tooltip: 'Ещё',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'hard') {
                  await _confirmHardDelete(context, p);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'hard',
                  child: ListTile(
                    leading:
                    Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Удалить навсегда'),
                  ),
                ),
              ],
            ),
          ]
              : const [],
        );
      },
    );
  }

  Widget _table(
      BuildContext context,
      ProductListNotifier n,
      ReferenceDataNotifier refs,
      ) {
    final canManage = context.watch<AuthNotifier>().has(Role.manager);

    return EntityTable<Product>(
      items: n.result.items,
      idOf: (p) => p.id,
      selected: n.selected,
      // Без прав на управление чекбоксы не нужны.
      onToggleSelect: canManage ? n.toggleSelection : null,
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
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (p) => Text(p.name),
        ),
        TableColumnSpec(label: 'Артикул', build: (p) => Text(p.sku)),
        TableColumnSpec(
          label: 'Категория',
          build: (p) => Text(refs.categoryById(p.categoryId)?.name ?? '—'),
        ),
        TableColumnSpec(
          label: 'Цена, ₽',
          sortField: 'price',
          numeric: true,
          build: (p) => Text(p.price.toStringAsFixed(2)),
        ),
        TableColumnSpec(
          label: 'Вес, г',
          sortField: 'weight',
          numeric: true,
          build: (p) => Text('${p.weightGr}'),
        ),
        TableColumnSpec(
          label: 'В наличии',
          sortField: 'stock',
          numeric: true,
          build: (p) => Text('${p.stockAvailable} / ${p.stockTotal}'),
        ),
      ],
      actions: canManage
          ? (p) => [
        IconButton(
          tooltip: 'Редактировать',
          icon: const Icon(Icons.edit),
          onPressed: () => context.go('/products/${p.id}/edit'),
        ),
        if (p.isDeleted)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => n.restore(p.id),
          )
        else
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, p.id),
          ),
        PopupMenuButton<String>(
          tooltip: 'Ещё',
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'hard') {
              await _confirmHardDelete(context, p);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'hard',
              child: ListTile(
                leading:
                Icon(Icons.delete_forever, color: Colors.red),
                title: Text('Удалить навсегда'),
              ),
            ),
          ],
        ),
      ]
          : null,
    );
  }

  Widget _pager(BuildContext context, ProductListNotifier n) {
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
                ? () => _updateQuery(n.query.copyWith(page: 1), resetPage: false)
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

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Запись будет помечена как удалённая.'),
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
      await context.read<ProductListNotifier>().softDelete(id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text(
          'Товар «${p.name}» будет удалён физически. '
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
      await context.read<ProductListNotifier>().hardDelete(p.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final n = context.read<ProductListNotifier>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить выбранные товары?'),
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