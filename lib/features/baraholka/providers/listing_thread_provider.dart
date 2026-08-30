import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/listing_message_model.dart';
import '../../../services/supabase_service.dart';
import 'listing_threads_provider.dart';

/// Сообщения одного треда переписки по объявлению: грузит историю из
/// `listing_messages` и подписывается на Supabase Realtime (INSERT по
/// `thread_id`), чтобы ответы собеседника появлялись без перезагрузки.
///
/// Архитектура подписки — как у `ChatController` регионального чата:
/// один канал на тред, снимается в [dispose]. Отличие: здесь ещё
/// проставляется `read_at` входящим сообщениям (для бейджа непрочитанных
/// в списке тредов).
///
/// Отправлять сообщения может только пользователь с реальной сессией
/// Supabase — RLS требует `sender_id = auth.uid()`. У dev-пользователя
/// сессии нет, поэтому экран переписки просто прячет поле ввода.
class ListingThreadController
    extends StateNotifier<AsyncValue<List<ListingMessageModel>>> {
  ListingThreadController(this.threadId, this.ref)
      : super(const AsyncLoading()) {
    _init();
  }

  final String threadId;
  final Ref ref;
  RealtimeChannel? _channel;

  Future<void> _init() async {
    try {
      final rows = await SupabaseService.client
          .from(SupabaseTables.listingMessages)
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      state = AsyncData(rows.map(ListingMessageModel.fromJson).toList());
      await _markIncomingRead();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'thread_id',
      value: threadId,
    );
    _channel = SupabaseService.client
        .channel('listing-messages-thread-$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseTables.listingMessages,
          filter: filter,
          callback: (payload) async {
            final message = ListingMessageModel.fromJson(payload.newRecord);
            final current = state.valueOrNull ?? [];
            if (current.any((m) => m.id == message.id)) return;
            state = AsyncData([...current, message]);

            final myId = SupabaseService.currentUser?.id;
            if (myId != null && message.senderId != myId) {
              await _markIncomingRead();
            }
          },
        )
        // UPDATE — в основном проставленный собеседником read_at: обновляем
        // сообщение на месте, чтобы галочка «прочитано» у своих сообщений
        // менялась вживую.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseTables.listingMessages,
          filter: filter,
          callback: (payload) {
            final updated = ListingMessageModel.fromJson(payload.newRecord);
            final current = state.valueOrNull;
            if (current == null) return;
            state = AsyncData([
              for (final m in current) m.id == updated.id ? updated : m,
            ]);
          },
        )
        .subscribe();
  }

  /// Помечает прочитанными все сообщения треда от собеседника. Вызывается
  /// при открытии экрана и при каждом входящем сообщении, пока экран
  /// открыт. Свои сообщения RLS трогать не даст — фильтр по sender_id
  /// здесь только чтобы не делать лишний UPDATE.
  Future<void> _markIncomingRead() async {
    final myId = SupabaseService.currentUser?.id;
    if (myId == null) return;
    try {
      await SupabaseService.client
          .from(SupabaseTables.listingMessages)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('thread_id', threadId)
          .neq('sender_id', myId)
          .isFilter('read_at', null);
      if (mounted) ref.invalidate(listingThreadsProvider);
    } catch (_) {
      // Некритично: счётчик непрочитанных обновится при следующем заходе.
    }
  }

  Future<void> sendText(String text, {required String senderId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await SupabaseService.client.from(SupabaseTables.listingMessages).insert({
      'thread_id': threadId,
      'sender_id': senderId,
      'text': trimmed,
    });
    // Само сообщение вернётся через realtime-подписку выше.
  }

  Future<void> sendPhoto(XFile photo, {required String senderId}) async {
    final photoUrl = await SupabaseService.uploadListingThreadPhoto(
      photo,
      threadId: threadId,
    );
    await SupabaseService.client.from(SupabaseTables.listingMessages).insert({
      'thread_id': threadId,
      'sender_id': senderId,
      'photo_url': photoUrl,
    });
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

final listingThreadControllerProvider = StateNotifierProvider.family<
    ListingThreadController,
    AsyncValue<List<ListingMessageModel>>,
    String>((ref, threadId) => ListingThreadController(threadId, ref));
