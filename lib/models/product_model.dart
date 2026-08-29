/// Модель товара в каталоге. Соответствует таблице `products`.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.description,
    this.sellerId,
    this.regionId,
    this.createdAt,
  });

  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String? description;
  final String? sellerId;
  final String? regionId;
  final DateTime? createdAt;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String?,
      sellerId: json['seller_id'] as String?,
      regionId: json['region_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'seller_id': sellerId,
      'region_id': regionId,
    };
  }
}
