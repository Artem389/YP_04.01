class ProductCategory {
  final int id;
  final String name;
  final String description;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  ProductCategory copyWith({String? name, String? description}) =>
      ProductCategory(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is ProductCategory && other.id == id);

  @override
  int get hashCode => id.hashCode;
}