import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

/// Хранит сообщения чата конкретного региона: подгружает историю из
/// таблицы `messages` и подписывается на Supabase Realtime, чтобы новые
/// сообщения появлялись у всех участников без перезагрузки экрана.
///
/// Dev-режим входа (`devTestUserProvider`) не создаёт настоящую сессию
/// Supabase, поэтому у него нет `auth.uid()` — писать в реальную таблицу
/// `messages` для него нельзя (это отклонят и RLS, и внешний ключ на
/// users). Чтение истории и realtime продолжают работать (SELECT открыт
/// всем), а собственные сообщения dev-пользователя добавляются только
/// локально, в состояние этого контроллера.
class ChatController extends StateNotifier<AsyncValue<List<MessageModel>>> {
  ChatController(this.regionId) : super(const AsyncLoading()) {
    _init();
  }

  final String regionId;
  RealtimeChannel? _channel;

  /// Кэш имени/аватара авторов по их id — заполняется join'ом при загрузке
  /// истории и точечными запросами для новых авторов из realtime (сам
  /// Postgres Changes payload приходит без join на `users`).
  final Map<String, UserModel> _authorCache = {};

  Future<void> _init() async {
    try {
      final rows = await SupabaseService.client
          .from(SupabaseTables.messages)
          // Имя/аватар автора — из представления user_public_profiles
          // (без телефона). Хинт !messages_author_id_fkey — имя FK
          // messages.author_id → users.id, нужен для embed через view.
          .select(
            '*, author:user_public_profiles!messages_author_id_fkey'
            '(id, name, avatar_url)',
          )
          .eq('region_id', regionId)
          // ascending: true обязателен — без него supabase-клиент
          // сортирует по убыванию, и старые сообщения оказываются внизу.
          // Новые сообщения из realtime дописываются в конец списка.
          .order('created_at', ascending: true);

      final messages = rows.map((row) {
        final authorJson = row['author'] as Map<String, dynamic>?;
        if (authorJson != null) {
          final author = UserModel.fromJson(authorJson);
          _authorCache[author.id] = author;
        }
        return _applyAuthor(MessageModel.fromJson(row), row['author_id'] as String);
      }).toList();

      state = AsyncData(messages);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
    _subscribeToRealtime();
  }

  /// Подставляет имя/аватар из кэша в сообщение: заполненное имя
  /// пользователя, иначе остаётся общая подпись из fromJson («Рыбак»).
  /// Телефон в подписи не используем — его больше нет в профиле автора
  /// (user_public_profiles), да и светить номер в общем чате не нужно.
  MessageModel _applyAuthor(MessageModel message, String authorId) {
    final author = _authorCache[authorId];
    if (author == null) return message;
    final name = author.name?.trim();
    return message.copyWithAuthor(
      authorName: (name != null && name.isNotEmpty) ? name : null,
      authorAvatarUrl: author.avatarUrl,
    );
  }

  void _subscribeToRealtime() {
    _channel = SupabaseService.client
        .channel('messages-region-$regionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseTables.messages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'region_id',
            value: regionId,
          ),
          callback: (payload) async {
            var message = MessageModel.fromJson(payload.newRecord);
            final current = state.valueOrNull ?? [];
            if (current.any((m) => m.id == message.id)) return;

            if (!_authorCache.containsKey(message.authorId)) {
              try {
                final row = await SupabaseService.client
                    .from(SupabaseTables.userPublicProfiles)
                    .select()
                    .eq('id', message.authorId)
                    .maybeSingle();
                if (row != null) {
                  _authorCache[message.authorId] = UserModel.fromJson(row);
                }
              } catch (_) {
                // Профиль не подгрузился — просто остаётся общая подпись
                // из fromJson.
              }
            }
            message = _applyAuthor(message, message.authorId);

            final latest = state.valueOrNull ?? [];
            if (latest.any((m) => m.id == message.id)) return;
            state = AsyncData([...latest, message]);
          },
        )
        .subscribe();
  }

  /// Отправка текстового сообщения. У авторизованного пользователя —
  /// настоящая запись в Supabase (само сообщение вернётся через realtime
  /// выше). У dev-пользователя — только локальное добавление в состояние.
  Future<void> sendText(
    String text, {
    required String authorId,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (SupabaseService.isAuthenticated) {
      await SupabaseService.client.from(SupabaseTables.messages).insert({
        'region_id': regionId,
        'author_id': authorId,
        'text': trimmed,
      });
      return;
    }

    _appendLocal(
      MessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        regionId: regionId,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        text: trimmed,
      ),
    );
  }

  /// Отправка фото. У авторизованного пользователя — загрузка байтов в
  /// Supabase Storage (бакет `chat-photos`) и запись сообщения с публичным
  /// URL (само сообщение вернётся через realtime выше, как и sendText).
  /// Читаем файл через XFile.readAsBytes() (не dart:io File) — так фото
  /// отправляется одинаково на вебе и на Android.
  ///
  /// У dev-пользователя настоящей сессии нет, поэтому сообщение с фото
  /// добавляется только локально — байты фото сохраняются в состоянии
  /// контроллера и показываются через Image.memory (см. MessageModel и
  /// ChatController._init).
  Future<void> sendPhoto(
    XFile photo, {
    required String authorId,
    required String authorName,
  }) async {
    if (SupabaseService.isAuthenticated) {
      final photoUrl = await SupabaseService.uploadChatPhoto(photo, regionId: regionId);
      await SupabaseService.client.from(SupabaseTables.messages).insert({
        'region_id': regionId,
        'author_id': authorId,
        'photo_url': photoUrl,
      });
      return;
    }

    final bytes = await photo.readAsBytes();
    _appendLocal(
      MessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        regionId: regionId,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        localPhotoBytes: bytes,
      ),
    );
  }

  void _appendLocal(MessageModel message) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, message]);
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController,
    AsyncValue<List<MessageModel>>, String>((ref, regionId) {
  return ChatController(regionId);
});
