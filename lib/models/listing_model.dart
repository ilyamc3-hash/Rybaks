/// Объявление барахолки. Соответствует таблице `listings` в Supabase.
///
/// Поля `seller*` заполняются, когда запрос делает join на `users`
/// (`*, seller:users(id, phone, name, avatar_url)`) — RLS отдаёт профиль
/// продавца только авторизованным пользователям, поэтому у анонимного
/// зрителя они останутся null.
class ListingModel {
  const ListingModel({
    required this.id,
    required this.sellerId,
    required this.regionId,
    required this.title,
    required this.status,
    this.description,
    this.price,
    this.photoUrl,
    this.createdAt,
    this.sellerName,
    this.sellerPhone,
    this.sellerAvatarUrl,
  });

  final String id;
  final String sellerId;
  final String regionId;
  final String title;

  /// 'active' | 'sold' | 'archived'
  final String status;
  final String? description;

  /// null — цена не указана («Цена договорная»).
  final double? price;
  final String? photoUrl;
  final DateTime? createdAt;

  final String? sellerName;
  final String? sellerPhone;
  final String? sellerAvatarUrl;

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';

  /// Как показывать продавца в карточке: имя, иначе телефон, иначе общая
  /// подпись (профиль скрыт RLS для анонимных зрителей).
  String get sellerDisplayName {
    final name = sellerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final phone = sellerPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Продавец';
  }

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    return ListingModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      regionId: json['region_id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'active',
      description: json['description'] as String?,
      price: json['price'] == null ? null : (json['price'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      sellerName: seller?['name'] as String?,
      sellerPhone: seller?['phone'] as String?,
      sellerAvatarUrl: seller?['avatar_url'] as String?,
    );
  }
}
