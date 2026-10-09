class Sale {
  final int id;
  final int customerId;
  final String customerName;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double total;   // итог с учётом скидок и НДС, если сервер вернёт
  final DateTime soldAt;
  final DateTime? closedAt;
  final DateTime? deletedAt;

  const Sale({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.total,
    required this.soldAt,
    this.closedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  String get status => closedAt == null ? 'active' : 'closed';

  factory Sale.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final unit = (json['unitPrice'] as num?)?.toDouble() ??
        (product?['price'] as num?)?.toDouble() ??
        0;
    return Sale(
      id: (json['id'] as num?)?.toInt() ?? 0,
      customerId: (customer?['id'] as num?)?.toInt() ?? 0,
      customerName: (customer?['fullName'] ?? '') as String,
      productId: (product?['id'] as num?)?.toInt() ?? 0,
      productName: (product?['name'] ?? '') as String,
      quantity: qty,
      unitPrice: unit,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? unit * qty,
      total: (json['total'] as num?)?.toDouble() ?? unit * qty,
      soldAt: DateTime.tryParse(json['soldAt'] as String? ?? '') ??
          DateTime.now(),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.tryParse(json['closedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.tryParse(json['deletedAt'] as String),
    );
  }
}