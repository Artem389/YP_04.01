import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/role.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';
import '../models/sale.dart';
import '../repositories/sale_repository.dart';
import '../state/auth_notifier.dart';

class MySalesScreen extends StatefulWidget {
  final Map<String, String> queryParams;
  const MySalesScreen({super.key, required this.queryParams});

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> {
  PageResult<Sale> _page = PageResult<Sale>.empty();
  bool _loading = true;
  String? _error;
  int _pageIndex = 1;
  int _size = 10;
  bool _includeDeleted = false;

  @override
  void initState() {
    super.initState();
    _includeDeleted = widget.queryParams['deleted'] == 'true';
    _size = int.tryParse(widget.queryParams['size'] ?? '') ?? 10;
    _pageIndex = int.tryParse(widget.queryParams['page'] ?? '') ?? 1;
    if (_pageIndex < 1) _pageIndex = 1;
    if (![10, 25, 50].contains(_size)) _size = 10;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MySalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryParams != widget.queryParams) {
      final newDeleted = widget.queryParams['deleted'] == 'true';
      final newSize = int.tryParse(widget.queryParams['size'] ?? '') ?? 10;
      final newPage = int.tryParse(widget.queryParams['page'] ?? '') ?? 1;

      final changed = newDeleted != _includeDeleted ||
          newSize != _size ||
          (newPage < 1 ? 1 : newPage) != _pageIndex;

      if (changed) {
        setState(() {
          _includeDeleted = newDeleted;
          _size = [10, 25, 50].contains(newSize) ? newSize : 10;
          _pageIndex = newPage < 1 ? 1 : newPage;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _load();
        });
      }
    }
  }

  void _updateUri({bool? includeDeleted, int? size, int? page}) {
    final q = <String, String>{};
    final d = includeDeleted ?? _includeDeleted;
    final s = size ?? _size;
    final p = page ?? _pageIndex;
    if (d) q['deleted'] = 'true';
    if (s != 10) q['size'] = '$s';
    if (p > 1) q['page'] = '$p';
    final uri = Uri(
      path: '/sales',
      queryParameters: q.isEmpty ? null : q,
    );
    context.go(uri.toString());
  }

  Future<void> _load() async {

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<SaleRepository>().find(
        ProductQuery(page: _pageIndex, size: _size, includeDeleted: _includeDeleted,),
      );
      if (!mounted) return;
      setState(() {
        _page = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }
  Widget _buildTrailing(Sale s, bool canManage) {
    // Клиент действий не видит — только статус.
    if (!canManage) {
      return Chip(
        label: Text(s.status),
        visualDensity: VisualDensity.compact,
      );
    }

    // Менеджер/админ: меню действий, набор зависит от состояния записи.
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'close':
            await _close(s);
            break;
          case 'delete':
            await _softDelete(s);
            break;
          case 'restore':
            await _restore(s);
            break;
          case 'hard':
            await _hardDelete(s);
            break;
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];

        // Удалённая запись: только восстановить или удалить навсегда.
        if (s.isDeleted) {
          items.add(const PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: Icon(Icons.restore),
              title: Text('Восстановить'),
            ),
          ));
          items.add(const PopupMenuItem(
            value: 'hard',
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Удалить навсегда'),
            ),
          ));
          return items;
        }

        // Активная продажа: закрыть или пометить как удалённую.
        if (s.status == 'active') {
          items.add(const PopupMenuItem(
            value: 'close',
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Закрыть продажу'),
            ),
          ));
        }
        items.add(const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Удалить'),
          ),
        ));
        return items;
      },
    );
  }
  Future<void> _restore(Sale s) async {
    try {
      await context.read<SaleRepository>().restore(s.id);
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _hardDelete(Sale s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text('Продажа №${s.id} будет удалена физически.'),
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
    if (ok == true && mounted) {
      try {
        await context.read<SaleRepository>().hardDelete(s.id);
        if (mounted) await _load();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }
  Future<void> _softDelete(Sale s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить продажу?'),
        content: Text('Продажа №${s.id} будет помечена как удалённая.'),
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
    if (ok == true && mounted) {
      try {
        await context.read<SaleRepository>().softDelete(s.id);
        if (mounted) await _load();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  Future<void> _close(Sale s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Закрыть продажу?'),
        content: Text('Продажа №${s.id} будет помечена как завершённая.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await context.read<SaleRepository>().close(s.id);
        if (mounted) await _load();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<AuthNotifier>().has(Role.manager);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Продажи'),
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
                FilterChip(
                  label: const Text('Показать удалённые'),
                  selected: _includeDeleted,

                  onSelected: (v) => _updateUri(includeDeleted: v, page: 1),
                ),
                TextButton.icon(
                  onPressed: () => _updateUri(
                    includeDeleted: false,
                    size: 10,
                    page: 1,
                  ),
                  icon: const Icon(Icons.clear),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(canManage)),
        ],
      ),
    );
  }

  Widget _buildBody(bool canManage) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_page.items.isEmpty) {
      return const Center(child: Text('Продаж пока нет'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _page.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = _page.items[i];
              final isDeleted = s.isDeleted;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(s.productName.isEmpty
                      ? '?'
                      : s.productName[0].toUpperCase()),
                ),
                title: Text(s.productName),
                subtitle: Text(
                  '${s.customerName} • ${s.quantity} шт. × '
                      '${s.unitPrice.toStringAsFixed(2)} ₽ = '
                      '${s.subtotal.toStringAsFixed(2)} ₽\n'
                      '${s.soldAt.toLocal().toString().substring(0, 16)}'
                      '${isDeleted ? '\nУДАЛЕНА' : ''}',
                ),
                isThreeLine: true,
                trailing: _buildTrailing(s, canManage),
              );
            },
          ),
        ),
        _pager(),
      ],
    );
  }

  Widget _pager() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Всего: ${_page.total}'),
          const Spacer(),
          DropdownButton<int>(
            value: _size,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _size = v;
                _pageIndex = 1;
              });
              _load();
            },
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page.hasPrevious
                ? () {
              _pageIndex--;
              _load();
            }
                : null,
          ),
          Text('${_page.page} / ${_page.totalPages}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page.hasNext
                ? () {
              _pageIndex++;
              _load();
            }
                : null,
          ),
        ],
      ),
    );
  }
}