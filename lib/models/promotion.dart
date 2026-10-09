/// Акция. Может действовать:
///  * на набор товаров (many-to-many: Promotion ↔ Product),
///  * на категорию (many-to-one: Promotion → Category) — тогда
///    распространяется на все товары этой категории.
/// Условие: акция активна, если now внутри [startsAt, endsAt]
/// и текущая сумма/количество попадают в порог.
class Promotion {
  final int id;
  final String name;
  final String description;

  /// Процент скидки от 1 до 90.
  final int discountPercent;

  /// Категория, к которой применяется акция (может быть null).
  final int? categoryId;

  /// Список id товаров, на которые распространяется акция.
  final List<int> productIds;

  /// Минимальная сумма корзины, при которой акция срабатывает.
  final double minTotal;

  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? deletedAt;

  const Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.discountPercent,
    this.categoryId,
    this.productIds = const [],
    this.minTotal = 0,
    required this.startsAt,
    required this.endsAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Активна ли акция в указанный момент.
  bool isActiveAt(DateTime moment) =>
      !isDeleted && !moment.isBefore(startsAt) && !moment.isAfter(endsAt);

  Promotion copyWith({
    String? name,
    String? description,
    int? discountPercent,
    Object? categoryId = _unset,
    List<int>? productIds,
    double? minTotal,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Promotion(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      discountPercent: discountPercent ?? this.discountPercent,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      productIds: productIds ?? this.productIds,
      minTotal: minTotal ?? this.minTotal,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toInputJson() => {
    'name': name,
    'description': description,
    'discountPercent': discountPercent,
    'categoryId': categoryId,
    'productIds': productIds,
    'minTotal': minTotal,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
  };

  Map<String, dynamic> toJson() => {
    ...toInputJson(),
    'id': id,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
    categoryId: (json['categoryId'] as num?)?.toInt(),
    productIds:
        (json['productIds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
    minTotal: (json['minTotal'] as num?)?.toDouble() ?? 0,
    startsAt:
        DateTime.tryParse(json['startsAt'] as String? ?? '') ?? DateTime.now(),
    endsAt:
        DateTime.tryParse(json['endsAt'] as String? ?? '') ??
        DateTime.now().add(const Duration(days: 30)),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(json['deletedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Promotion && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

const _unset = Object();
