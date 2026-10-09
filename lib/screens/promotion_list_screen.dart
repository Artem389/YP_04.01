import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/role.dart';
import '../models/product_query.dart';
import '../models/promotion.dart';
import '../repositories/promotion_repository.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_card.dart';
import '../widgets/entity_table.dart';

class PromotionListScreen extends StatefulWidget {
  final Map<String, String> queryParams;
  const PromotionListScreen({super.key, required this.queryParams});

  @override
  State<PromotionListScreen> createState() => _PromotionListScreenState();
}

class _PromotionListScreenState extends State<PromotionListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.queryParams['search'] ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q = ProductQuery.fromUri(widget.queryParams);
      context.read<EntityListNotifier<Promotion>>().applyQuery(q);
    });
  }

  @override
  void didUpdateWidget(covariant PromotionListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пользователь кликнул по фильтру, роутер заменил query-параметры —
    // State переиспользуется, initState повторно не вызывается.
    if (oldWidget.queryParams != widget.queryParams) {
      final q = ProductQuery.fromUri(widget.queryParams);
      final notifier = context.read<EntityListNotifier<Promotion>>();
      final current = notifier.query;

      // Синхронизируем поле поиска.
      if (_searchController.text != q.search) {
        _searchController.text = q.search;
      }

      // Если запрос реально отличается — перезагружаем.
      // notifyListeners нельзя вызывать в build/didUpdateWidget,
      // поэтому откладываем на следующий кадр.
      if (q.toUri().toString() != current.toUri().toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<EntityListNotifier<Promotion>>().applyQuery(q);
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
      path: '/promotions',
      queryParameters: q.toUri().isEmpty ? null : q.toUri(),
    );
    context.go(uri.toString());
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _updateQuery(
        context.read<EntityListNotifier<Promotion>>().query.copyWith(
          search: value,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<EntityListNotifier<Promotion>>();
    final canManage = context.watch<AuthNotifier>().has(Role.manager);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Акции'),
        actions: [
          if (n.hasSelection && canManage) ...[
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
          if (canManage)
            IconButton(
              tooltip: 'Добавить акцию',
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/promotions/new'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
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
                  onPressed: () {
                    _searchController.clear();
                    _updateQuery(const ProductQuery());
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ),
          Expanded(child: _body(context, n, canManage)),
          _pager(context, n),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    EntityListNotifier<Promotion> n,
    bool canManage,
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
          return const Center(child: Text('Акций не найдено'));
        }
        return byScreen(
          context,
          compact: _cardList(context, n, canManage),
          medium: _table(context, n, canManage),
          expanded: _table(context, n, canManage),
        );
    }
  }

  Widget _cardList(
    BuildContext context,
    EntityListNotifier<Promotion> n,
    bool canManage,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: n.result.items.length,
      itemBuilder: (_, i) {
        final p = n.result.items[i];
        final active = p.isActiveAt(DateTime.now());
        return EntityCard<Promotion>(
          item: p,
          title: Text(p.name),
          lines: [
            Text(p.description),
            Text('Скидка: ${p.discountPercent}%'),
            Text(active ? 'Активна' : 'Неактивна'),
            Text('${p.startsAt.toLocal()} — ${p.endsAt.toLocal()}'),
          ],
          selected: n.selected.contains(p.id),
          onToggle: canManage ? () => n.toggleSelection(p.id) : null,
          actions: canManage
              ? [
                  IconButton(
                    tooltip: 'Редактировать',
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.go('/promotions/${p.id}/edit'),
                  ),
                  if (p.isDeleted)
                    IconButton(
                      tooltip: 'Восстановить',
                      icon: const Icon(Icons.restore),
                      onPressed: () => _restore(context, p.id),
                    )
                  else
                    IconButton(
                      tooltip: 'Удалить',
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _confirmSoftDelete(context, p.id, p.name),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Ещё',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'hard') {
                        await _confirmHardDelete(context, p.id, p.name);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'hard',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
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
    EntityListNotifier<Promotion> n,
    bool canManage,
  ) {
    return EntityTable<Promotion>(
      items: n.result.items,
      idOf: (p) => p.id,
      selected: n.selected,
      onToggleSelect: canManage ? n.toggleSelection : null,
      sortField: n.query.sortField,
      sortAscending: n.query.sortAscending,
      columns: [
        TableColumnSpec(label: 'Название', build: (p) => Text(p.name)),
        TableColumnSpec(label: 'Описание', build: (p) => Text(p.description)),
        TableColumnSpec(
          label: 'Скидка',
          numeric: true,
          build: (p) => Text('${p.discountPercent}%'),
        ),
        TableColumnSpec(
          label: 'Статус',
          build: (p) =>
              Text(p.isActiveAt(DateTime.now()) ? 'Активна' : 'Неактивна'),
        ),
        TableColumnSpec(
          label: 'Период',
          build: (p) => Text(
            '${p.startsAt.toLocal().toString().substring(0, 10)} — '
            '${p.endsAt.toLocal().toString().substring(0, 10)}',
          ),
        ),
      ],
      actions: canManage
          ? (p) => [
              IconButton(
                tooltip: 'Редактировать',
                icon: const Icon(Icons.edit),
                onPressed: () => context.go('/promotions/${p.id}/edit'),
              ),
              if (p.isDeleted)
                IconButton(
                  tooltip: 'Восстановить',
                  icon: const Icon(Icons.restore),
                  onPressed: () => _restore(context, p.id),
                )
              else
                IconButton(
                  tooltip: 'Удалить',
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmSoftDelete(context, p.id, p.name),
                ),
              PopupMenuButton<String>(
                tooltip: 'Ещё',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'hard') {
                    await _confirmHardDelete(context, p.id, p.name);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'hard',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: Text('Удалить навсегда'),
                    ),
                  ),
                ],
              ),
            ]
          : null,
    );
  }

  Widget _pager(BuildContext context, EntityListNotifier<Promotion> n) {
    final r = n.result;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Всего: ${r.total}'),
          const Spacer(),
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
    final n = context.read<EntityListNotifier<Promotion>>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить выбранные акции?'),
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

  Future<void> _restore(BuildContext context, int id) async {
    await context.read<PromotionRepository>().restore(id);
    if (context.mounted) {
      await context.read<EntityListNotifier<Promotion>>().load();
    }
  }

  Future<void> _confirmSoftDelete(
    BuildContext context,
    int id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить акцию?'),
        content: Text('«$name» будет помечена как удалённая.'),
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
      await context.read<PromotionRepository>().softDelete(id);
      if (context.mounted) {
        await context.read<EntityListNotifier<Promotion>>().load();
      }
    }
  }

  Future<void> _confirmHardDelete(
    BuildContext context,
    int id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text('Акция «$name» будет удалена физически.'),
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
      await context.read<PromotionRepository>().hardDelete(id);
      if (context.mounted) {
        await context.read<EntityListNotifier<Promotion>>().load();
      }
    }
  }
}
