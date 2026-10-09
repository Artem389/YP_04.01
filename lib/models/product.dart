class Product {
  final int id;
  final String name;
  final String sku;
  final double price;
  final int weightGr;
  final int categoryId;
  final int stockTotal;
  final int stockAvailable;
  final DateTime? deletedAt;
  final List<int> supplierIds;

  // Развёрнутые объекты из ответа сервера (кэш для отображения).
  final String? categoryName;
  final List<String> supplierNames;

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
    this.categoryName,
    this.supplierNames = const [],
  });

  bool get isDeleted => deletedAt != null;
  bool get isOutOfStock => stockAvailable == 0;

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
    String? categoryName,
    List<String>? supplierNames,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      weightGr: weightGr ?? this.weightGr,
      categoryId: categoryId ?? this.categoryId,
      stockTotal: stockTotal ?? this.stockTotal,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      supplierIds: supplierIds ?? this.supplierIds,
      categoryName: categoryName ?? this.categoryName,
      supplierNames: supplierNames ?? this.supplierNames,
    );
  }

  /// Тело для POST/PUT.
  Map<String, dynamic> toInputJson() => {
    'name': name,
    'sku': sku,
    'price': price,
    'weightGr': weightGr,
    'categoryId': categoryId,
    'supplierId': supplierIds.isEmpty ? null : supplierIds.first,
    'stockTotal': stockTotal,
  };

  /// Чтение из ответа сервера (развёрнутое представление).
  factory Product.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v == null ? null : (v as num).toInt();
    double asDouble(dynamic v) => v == null ? 0 : (v as num).toDouble();

    final category = json['category'] as Map<String, dynamic>?;
    final supplier = json['supplier'] as Map<String, dynamic>?;

    return Product(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      price: asDouble(json['price']),
      weightGr: asInt(json['weightGr']) ?? 0,
      categoryId: asInt(category?['id']) ?? 0,
      stockTotal: asInt(json['stockTotal']) ?? 0,
      stockAvailable: asInt(json['stockAvailable']) ?? 0,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.tryParse(json['deletedAt'] as String),
      supplierIds: supplier != null && supplier['id'] != null
          ? [asInt(supplier['id'])!]
          : const [],
      categoryName: category?['name'] as String?,
      supplierNames: supplier != null && supplier['name'] != null
          ? [supplier['name'] as String]
          : const [],
    );
  }

  /// Сериализация для localStorage (ПР3). Оставляем — данные кэшируются
  /// в офлайне, пока идёт запрос.
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
    'categoryName': categoryName,
    'supplierNames': supplierNames,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
