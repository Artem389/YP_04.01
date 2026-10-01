class DiscountCard {
  final String number;
  final int discountPercent;
  final DateTime issuedAt;

  const DiscountCard({
    required this.number,
    required this.discountPercent,
    required this.issuedAt,
  });

  DiscountCard copyWith({
    String? number,
    int? discountPercent,
    DateTime? issuedAt,
  }) {
    return DiscountCard(
      number: number ?? this.number,
      discountPercent: discountPercent ?? this.discountPercent,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'discountPercent': discountPercent,
    'issuedAt': issuedAt.toIso8601String(),
  };

  factory DiscountCard.fromJson(Map<String, dynamic> json) => DiscountCard(
    number: json['number'] as String? ?? '',
    discountPercent: json['discountPercent'] as int? ?? 0,
    issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}