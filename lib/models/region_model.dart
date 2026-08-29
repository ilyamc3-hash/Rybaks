/// Модель региона. Соответствует таблице `regions` в Supabase.
///
/// Регион — это точка входа в приложение: пользователь выбирает регион
/// и попадает в его локальный чат.
class RegionModel {
  const RegionModel({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}
