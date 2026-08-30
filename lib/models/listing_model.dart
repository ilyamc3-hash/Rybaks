/// Объявление барахолки. Соответствует таблице `listings` в Supabase.
///
/// Поля `seller*` заполняются embed-запросом на представление
/// `user_public_profiles` (`*, seller:user_public_profiles!listings_seller_id_fkey(id, name, avatar_url)`).
/// Телефона продавца здесь нет намеренно — связь только через встроенную
/// переписку (кнопка «Написать»). Свой полный профиль с телефоном
/// пользователь читает отдельно из `users` (fetchCurrentUserProfile).
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
  final String? sellerAvatarUrl;

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';

  /// Как показывать продавца в карточке: имя, иначе общая подпись
  /// (имя ещё не задано, либо профиль не приехал).
  String get sellerDisplayName {
    final name = sellerName?.trim();
    if (name != null && name.isNotEmpty) return name;
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
      sellerAvatarUrl: seller?['avatar_url'] as String?,
    );
  }
}
