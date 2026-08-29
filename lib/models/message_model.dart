import 'dart:typed_data';

/// Модель сообщения в чате региона. Соответствует таблице `messages`.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.regionId,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.text,
    this.photoUrl,
    this.authorAvatarUrl,
    this.localPhotoBytes,
  });

  final String id;
  final String regionId;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String? text;
  final String? photoUrl;
  final String? authorAvatarUrl;

  /// Байты фото для локального превью сообщений dev-пользователя (см.
  /// комментарий в ChatController.sendPhoto) — такие сообщения никогда не
  /// уходят в Supabase, поэтому фото показывается сразу из памяти через
  /// Image.memory вместо URL. Работает одинаково на вебе и на Android, в
  /// отличие от dart:io File, который на вебе недоступен.
  final Uint8List? localPhotoBytes;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      regionId: json['region_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Рыбак',
      createdAt: DateTime.parse(json['created_at'] as String),
      text: json['text'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  /// Возвращает копию с подставленными именем/аватаром автора — используется,
  /// когда имя/фото пользователя резолвятся отдельным запросом к `users`
  /// (join при загрузке истории, кэш при новых сообщениях из realtime).
  MessageModel copyWithAuthor({String? authorName, String? authorAvatarUrl}) {
    return MessageModel(
      id: id,
      regionId: regionId,
      authorId: authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt,
      text: text,
      photoUrl: photoUrl,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      localPhotoBytes: localPhotoBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'region_id': regionId,
      'author_id': authorId,
      'text': text,
      'photo_url': photoUrl,
    };
  }
}
