/// Одно сообщение в личной переписке по объявлению барахолки.
/// Соответствует таблице `listing_messages` в Supabase.
///
/// Отдельная модель от [MessageModel] (региональный чат): у диалога по
/// объявлению нет региона и есть `read_at` — момент прочтения получателем.
class ListingMessageModel {
  const ListingMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.photoUrl,
    this.readAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final DateTime createdAt;
  final String? text;
  final String? photoUrl;

  /// Момент, когда получатель открыл переписку и увидел это сообщение.
  /// null — ещё не прочитано.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory ListingMessageModel.fromJson(Map<String, dynamic> json) {
    return ListingMessageModel(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      text: json['text'] as String?,
      photoUrl: json['photo_url'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }
}
