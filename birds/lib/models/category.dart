
class Category {
  final int categoryId;
  final String? name;
  final String? description;

  const Category({
    required this.categoryId,
    this.name,
    this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: json['category_id'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
  }
}
