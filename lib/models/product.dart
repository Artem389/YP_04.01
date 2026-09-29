class Product {
  final int id;
  final String name;
  final String sku;          // артикул
  final double price;        // цена, руб.
  final int weightGr;        // вес, граммы
  final int categoryId;
  final int supplierId;
  final int stockTotal;
  final int stockAvailable;
  final DateTime? deletedAt;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.weightGr,
    required this.categoryId,
    required this.supplierId,
    required this.stockTotal,
    required this.stockAvailable,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isOutOfStock => stockAvailable == 0;

  Product copyWith({
    String? name,
    String? sku,
    double? price,
    int? weightGr,
    int? categoryId,
    int? supplierId,
    int? stockTotal,
    int? stockAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      weightGr: weightGr ?? this.weightGr,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      stockTotal: stockTotal ?? this.stockTotal,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      // Ловушка copyWith: clearDeletedAt позволяет отличить
      // «не менять» от «сбросить в null» (восстановление товара).
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}