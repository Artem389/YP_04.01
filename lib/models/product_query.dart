const _unset = Object();

class ProductQuery {
  final String search;
  final int? categoryId;
  final int? supplierId;
  final double? priceFrom;
  final double? priceTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const ProductQuery({
    this.search = '',
    this.categoryId,
    this.supplierId,
    this.priceFrom,
    this.priceTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  ProductQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? supplierId = _unset,
    Object? priceFrom = _unset,
    Object? priceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      supplierId: supplierId == _unset ? this.supplierId : supplierId as int?,
      priceFrom: priceFrom == _unset ? this.priceFrom : priceFrom as double?,
      priceTo: priceTo == _unset ? this.priceTo : priceTo as double?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Смена любого фильтра возвращает на первую страницу.
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  /// Разбор query-параметров адреса в объект запроса.
  factory ProductQuery.fromUri(Map<String, String> q) {
    int? parseInt(String? s) => s == null ? null : int.tryParse(s);
    double? parseDouble(String? s) => s == null ? null : double.tryParse(s);
    final page = parseInt(q['page']) ?? 1;
    final size = parseInt(q['size']) ?? 10;
    return ProductQuery(
      search: q['search'] ?? '',
      categoryId: parseInt(q['categoryId']),
      supplierId: parseInt(q['supplierId']),
      priceFrom: parseDouble(q['priceFrom']),
      priceTo: parseDouble(q['priceTo']),
      sortField: q['sort'] ?? 'name',
      sortAscending: (q['dir'] ?? 'asc') != 'desc',
      page: page < 1 ? 1 : page,
      size: [10, 25, 50].contains(size) ? size : 10,
      includeDeleted: q['deleted'] == 'true',
    );
  }

  /// Обратное преобразование: объект запроса в query-параметры.
  Map<String, String> toUri() {
    final m = <String, String>{};
    if (search.isNotEmpty) m['search'] = search;
    if (categoryId != null) m['categoryId'] = '$categoryId';
    if (supplierId != null) m['supplierId'] = '$supplierId';
    if (priceFrom != null) m['priceFrom'] = '$priceFrom';
    if (priceTo != null) m['priceTo'] = '$priceTo';
    if (sortField != 'name') m['sort'] = sortField;
    if (!sortAscending) m['dir'] = 'desc';
    if (page > 1) m['page'] = '$page';
    if (size != 10) m['size'] = '$size';
    if (includeDeleted) m['deleted'] = 'true';
    return m;
  }
}
