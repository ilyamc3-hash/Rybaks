/// Модель пользователя. Соответствует таблице `users` в Supabase.
class UserModel {
  const UserModel({
    required this.id,
    this.phone,
    this.name,
    this.avatarUrl,
    this.regionId,
    this.createdAt,
  });

  final String id;

  /// Телефон приходит только когда пользователь читает СВОЙ профиль
  /// напрямую из `users` (`fetchCurrentUserProfile`). В embed-запросах и
  /// при чтении чужих профилей используется представление
  /// `user_public_profiles`, где телефона нет — тогда null.
  final String? phone;
  final String? name;
  final String? avatarUrl;
  final String? regionId;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      regionId: json['region_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'avatar_url': avatarUrl,
      'region_id': regionId,
    };
  }
}
