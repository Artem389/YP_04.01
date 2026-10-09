class Supplier {
  final int id;
  final String name;
  final String email; // city
  final String phone; // mapped phone
  final DateTime? deletedAt;

  const Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Supplier copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toInputJson() => {
    'name': name,
    'city': email,
    'phone': phone,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '') as String,
    email: (json['city'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(json['deletedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Supplier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
