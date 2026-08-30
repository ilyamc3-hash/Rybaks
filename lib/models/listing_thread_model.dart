/// Тред приватной переписки 1:1. Соответствует таблице `listing_threads`.
/// Два вида: по объявлению барахолки ([listingId] задан) или прямой
/// диалог из общего чата региона ([listingId] == null, см. [isDirect]).
///
/// Поля `listing*` и `counterparty*` заполняются embed'ом на `listings`
/// и `user_public_profiles` (имя/аватар, без телефона) при загрузке
/// списка тредов. Поля `lastMessage*` и [unreadCount] дозаполняет
/// `listingThreadsProvider` отдельным запросом к `listing_messages`
/// (аналогия — `MessageModel.copyWithAuthor`).
class ListingThreadModel {
  const ListingThreadModel({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    required this.iAmBuyer,
    this.listingTitle,
    this.listingPhotoUrl,
    this.listingStatus,
    this.counterpartyName = 'Собеседник',
    this.counterpartyAvatarUrl,
    this.lastMessageText,
    this.lastMessagePhotoUrl,
    this.lastMessageAt,
    this.lastMessageMine = false,
    this.unreadCount = 0,
  });

  final String id;

  /// null — прямой диалог из общего чата (не привязан к объявлению).
  final String? listingId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;

  /// true — текущий пользователь в этом треде покупатель / инициатор;
  /// false — он продавец / вторая сторона.
  final bool iAmBuyer;

  /// Прямой диалог из чата, а не переписка по объявлению.
  bool get isDirect => listingId == null;

  final String? listingTitle;
  final String? listingPhotoUrl;

  /// 'active' | 'sold' | 'archived' — статус объявления на момент запроса.
  final String? listingStatus;

  /// Имя/телефон второй стороны диалога (не текущего пользователя).
  final String counterpartyName;
  final String? counterpartyAvatarUrl;

  final String? lastMessageText;
  final String? lastMessagePhotoUrl;
  final DateTime? lastMessageAt;

  /// true — последнее сообщение отправил текущий пользователь.
  final bool lastMessageMine;

  /// Сколько сообщений от собеседника ещё не прочитано текущим пользователем.
  final int unreadCount;

  bool get hasMessages => lastMessageAt != null;

  factory ListingThreadModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final buyerId = json['buyer_id'] as String;
    final sellerId = json['seller_id'] as String;
    final iAmBuyer = currentUserId == buyerId;

    final listing = json['listing'] as Map<String, dynamic>?;
    final counterparty =
        (iAmBuyer ? json['seller'] : json['buyer']) as Map<String, dynamic>?;

    return ListingThreadModel(
      id: json['id'] as String,
      listingId: json['listing_id'] as String?,
      buyerId: buyerId,
      sellerId: sellerId,
      createdAt: DateTime.parse(json['created_at'] as String),
      iAmBuyer: iAmBuyer,
      listingTitle: listing?['title'] as String?,
      listingPhotoUrl: listing?['photo_url'] as String?,
      listingStatus: listing?['status'] as String?,
      counterpartyName: _displayName(counterparty),
      counterpartyAvatarUrl: counterparty?['avatar_url'] as String?,
    );
  }

  /// Имя собеседника из `user_public_profiles` (телефона там нет): имя,
  /// иначе общая подпись.
  static String _displayName(Map<String, dynamic>? user) {
    final name = (user?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Собеседник';
  }

  /// Копия с подставленными данными последнего сообщения и счётчиком
  /// непрочитанных. Все параметры провайдер передаёт всегда, поэтому
  /// «не передан» и «передан null» здесь не различаются намеренно.
  ListingThreadModel copyWithSummary({
    required String? lastMessageText,
    required String? lastMessagePhotoUrl,
    required DateTime? lastMessageAt,
    required bool lastMessageMine,
    required int unreadCount,
  }) {
    return ListingThreadModel(
      id: id,
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
      createdAt: createdAt,
      iAmBuyer: iAmBuyer,
      listingTitle: listingTitle,
      listingPhotoUrl: listingPhotoUrl,
      listingStatus: listingStatus,
      counterpartyName: counterpartyName,
      counterpartyAvatarUrl: counterpartyAvatarUrl,
      lastMessageText: lastMessageText,
      lastMessagePhotoUrl: lastMessagePhotoUrl,
      lastMessageAt: lastMessageAt,
      lastMessageMine: lastMessageMine,
      unreadCount: unreadCount,
    );
  }
}
