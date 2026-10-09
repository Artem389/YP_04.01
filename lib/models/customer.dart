import 'discount_card.dart';

class Customer {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final DiscountCard? card;
  final DateTime? deletedAt;

  const Customer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.card,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get hasCard => card != null;

  Customer copyWith({
    String? fullName,
    String? email,
    String? phone,
    DiscountCard? card,
    bool clearCard = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Customer(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: clearCard ? null : (card ?? this.card),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toInputJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    if (card != null)
      'card': {
        'number': card!.number,
        'discountPercent': card!.discountPercent,
        'issuedAt': card!.issuedAt.toIso8601String(),
      },
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card?.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: (json['id'] as num?)?.toInt() ?? 0,
    fullName: (json['fullName'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    card: json['card'] == null
        ? null
        : DiscountCard.fromJson(json['card'] as Map<String, dynamic>),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(json['deletedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Customer && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
