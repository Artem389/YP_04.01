class Product {
  final int id;
  final String name;
  final String sku;          // артикул
  final double price;        // цена, руб.
  final int weightGr;        // вес, граммы
  final int categoryId;
  final int stockTotal;
  final int stockAvailable;
  final DateTime? deletedAt;
  final List<int> supplierIds;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.weightGr,
    required this.categoryId,
    required this.stockTotal,
    required this.stockAvailable,
    this.deletedAt,
    this.supplierIds = const [],
  });

  Product copyWith({
    String? name,
    String? sku,
    double? price,
    int? weightGr,
    int? categoryId,
    int? stockTotal,
    int? stockAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    List<int>? supplierIds,
  }) {
    return Product(
      id: id, // id менять нельзя — он идентификатор
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      weightGr: weightGr ?? this.weightGr,
      categoryId: categoryId ?? this.categoryId,
      stockTotal: stockTotal ?? this.stockTotal,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      // Ловушка copyWith: clearDeletedAt позволяет отличить
      // «не менять поле» от «сбросить в null» (восстановление товара).
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      supplierIds: supplierIds ?? this.supplierIds,
    );
  }

  bool get isDeleted => deletedAt != null;
  bool get isOutOfStock => stockAvailable == 0;

  // lib/models/product.dart (дополнение)
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'price': price,
    'weightGr': weightGr,
    'categoryId': categoryId,
    'stockTotal': stockTotal,
    'stockAvailable': stockAvailable,
    'deletedAt': deletedAt?.toIso8601String(),
    'supplierIds': supplierIds,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    weightGr: json['weightGr'] as int? ?? 0,
    categoryId: json['categoryId'] as int? ?? 0,
    stockTotal: json['stockTotal'] as int? ?? 0,
    stockAvailable: json['stockAvailable'] as int? ?? 0,
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(json['deletedAt'] as String),
    supplierIds: (json['supplierIds'] as List?)?.cast<int>() ?? const [],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

