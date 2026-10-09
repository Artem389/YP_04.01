import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../logic/category_report.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import '../repositories/product_category_repository.dart';
import '../repositories/product_repository.dart';

class CategoryReportScreen extends StatefulWidget {
  const CategoryReportScreen({super.key});

  @override
  State<CategoryReportScreen> createState() => _CategoryReportScreenState();
}

class _CategoryReportScreenState extends State<CategoryReportScreen> {
  List<CategoryReportRow> _rows = const [];
  bool _loading = true;
  String? _error;

  /// Индекс колонки сортировки: 0 — название, 1 — товаров, 2 — остаток, 3 — стоимость.
  int _sortIndex = 3;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catRepo = context.read<ProductCategoryRepository>();
      final prodRepo = context.read<ProductRepository>();

      final cats = await catRepo.findAll();
      // Одним запросом вытягиваем все товары (страницы по 200).
      final all = <Product>[];
      var page = 1;
      while (true) {
        final res = await prodRepo.find(ProductQuery(page: page, size: 200));
        all.addAll(res.items);
        if (res.items.length < 200 || page >= res.totalPages) break;
        page++;
      }

      if (!mounted) return;
      final rows = CategoryReport.build(categories: cats, products: all);
      setState(() {
        _rows = rows;
        _sort();
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

  void _sort() {
    _rows.sort((a, b) {
      final cmp = switch (_sortIndex) {
        1 => a.productCount.compareTo(b.productCount),
        2 => a.totalStock.compareTo(b.totalStock),
        3 => a.totalValue.compareTo(b.totalValue),
        _ => a.category.name.compareTo(b.category.name),
      };
      return _sortAsc ? cmp : -cmp;
    });
  }

  void _onSort(int index) {
    setState(() {
      if (_sortIndex == index) {
        _sortAsc = !_sortAsc;
      } else {
        _sortIndex = index;
        _sortAsc = true;
      }
      _sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Отчёт по категориям'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    if (_rows.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }

    // Сводные показатели сверху.
    final totalStock = _rows.fold<int>(0, (s, r) => s + r.totalStock);
    final totalValue = _rows.fold<double>(0, (s, r) => s + r.totalValue);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _summary('Категорий', '${_rows.length}'),
              _summary('Остаток', '$totalStock шт.'),
              _summary(
                'Стоимость склада',
                '${totalValue.toStringAsFixed(2)} ₽',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.sizeOf(context).width < 900
                      ? 900
                      : MediaQuery.sizeOf(context).width,
                ),
                child: DataTable(
                  sortColumnIndex: _sortIndex,
                  sortAscending: _sortAsc,
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  columns: [
                    DataColumn(
                      label: const Text('Категория'),
                      onSort: (i, _) => _onSort(0),
                    ),
                    DataColumn(
                      label: const Text('Товаров'),
                      numeric: true,
                      onSort: (i, _) => _onSort(1),
                    ),
                    DataColumn(
                      label: const Text('Остаток, шт.'),
                      numeric: true,
                      onSort: (i, _) => _onSort(2),
                    ),
                    DataColumn(
                      label: const Text('Стоимость склада, ₽'),
                      numeric: true,
                      onSort: (i, _) => _onSort(3),
                    ),
                  ],
                  rows: [
                    for (final r in _rows)
                      DataRow(
                        cells: [
                          DataCell(Text(r.category.name)),
                          DataCell(Text('${r.productCount}')),
                          DataCell(Text('${r.totalStock}')),
                          DataCell(Text(r.totalValue.toStringAsFixed(2))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
