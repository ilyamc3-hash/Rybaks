import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/listing_message_model.dart';
import '../../../models/listing_thread_model.dart';
import '../../../models/listing_model.dart';
import '../../../services/supabase_service.dart';

/// Селект треда вместе с объявлением и обеими сторонами диалога. RLS на
/// `listing_threads` уже отдаёт только треды текущего пользователя, но
/// имя/аватар собеседника приезжают join'ом на `users`.
const _threadSelect =
    '*, listing:listings(id, title, photo_url, status), '
    'buyer:users(id, phone, name, avatar_url), '
    'seller:users(id, phone, name, avatar_url)';

/// «Входящие» барахолки: все треды текущего пользователя — и как
/// покупателя, и как продавца — с превью последнего сообщения и числом
/// непрочитанных. Свежие по активности сверху.
///
/// Пусто без реальной сессии Supabase (аноним / dev-режим): RLS всё
/// равно ничего не отдаст, а `currentUser` == null.
final listingThreadsProvider =
    FutureProvider.autoDispose<List<ListingThreadModel>>((ref) async {
  final userId = SupabaseService.currentUser?.id;
  if (userId == null) return const [];

  final threadRows = await SupabaseService.client
      .from(SupabaseTables.listingThreads)
      .select(_threadSelect)
      .or('buyer_id.eq.$userId,seller_id.eq.$userId')
      .order('created_at', ascending: false);

  final threads = threadRows
      .map((row) => ListingThreadModel.fromJson(row, currentUserId: userId))
      .toList();
  if (threads.isEmpty) return threads;

  // Последнее сообщение и счётчик непрочитанных — одним запросом по всем
  // тредам сразу, чтобы не делать N+1.
  final messageRows = await SupabaseService.client
      .from(SupabaseTables.listingMessages)
      .select()
      .inFilter('thread_id', threads.map((t) => t.id).toList())
      .order('created_at');

  final lastByThread = <String, ListingMessageModel>{};
  final unreadByThread = <String, int>{};
  for (final row in messageRows) {
    final message = ListingMessageModel.fromJson(row);
    lastByThread[message.threadId] = message; // ascending → последний победит
    if (message.readAt == null && message.senderId != userId) {
      unreadByThread[message.threadId] =
          (unreadByThread[message.threadId] ?? 0) + 1;
    }
  }

  final result = threads
      .map((thread) {
        final last = lastByThread[thread.id];
        return thread.copyWithSummary(
          lastMessageText: last?.text,
          lastMessagePhotoUrl: last?.photoUrl,
          lastMessageAt: last?.createdAt,
          lastMessageMine: last != null && last.senderId == userId,
          unreadCount: unreadByThread[thread.id] ?? 0,
        );
      })
      // Тред, который покупатель открыл, но так и не написал, продавцу не
      // показываем — для него это шум от чужого случайного тапа «Написать».
      .where((thread) => thread.hasMessages || thread.iAmBuyer)
      .toList();

  result.sort((a, b) {
    final aAt = a.lastMessageAt ?? a.createdAt;
    final bAt = b.lastMessageAt ?? b.createdAt;
    return bAt.compareTo(aAt);
  });
  return result;
});

/// Найти существующий тред по объявлению для текущего пользователя-
/// покупателя или создать новый. Держит флаг занятости для блокировки
/// кнопки «Написать».
class ListingThreadActions extends StateNotifier<bool> {
  ListingThreadActions(this.ref) : super(false);

  final Ref ref;

  bool get isBusy => state;

  /// Возвращает тред текущего пользователя (как покупателя) с продавцом
  /// [listing]. Повторный вызов по тому же объявлению не создаёт дубль —
  /// сначала ищем существующий, а гонку на уникальном индексе
  /// (listing_id, buyer_id) ловим и перечитываем.
  Future<ListingThreadModel> openOrCreate(ListingModel listing) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('Написать продавцу можно только после входа по SMS.');
    }
    if (userId == listing.sellerId) {
      throw StateError('Это ваше объявление.');
    }

    state = true;
    try {
      final existing = await SupabaseService.client
          .from(SupabaseTables.listingThreads)
          .select(_threadSelect)
          .eq('listing_id', listing.id)
          .eq('buyer_id', userId)
          .maybeSingle();
      if (existing != null) {
        return ListingThreadModel.fromJson(existing, currentUserId: userId);
      }

      try {
        final inserted = await SupabaseService.client
            .from(SupabaseTables.listingThreads)
            .insert({
              'listing_id': listing.id,
              'buyer_id': userId,
              'seller_id': listing.sellerId,
            })
            .select(_threadSelect)
            .single();
        ref.invalidate(listingThreadsProvider);
        return ListingThreadModel.fromJson(inserted, currentUserId: userId);
      } on PostgrestException catch (error) {
        // 23505 — тред создан параллельно (двойной тап). Перечитываем.
        if (error.code != '23505') rethrow;
        final row = await SupabaseService.client
            .from(SupabaseTables.listingThreads)
            .select(_threadSelect)
            .eq('listing_id', listing.id)
            .eq('buyer_id', userId)
            .single();
        return ListingThreadModel.fromJson(row, currentUserId: userId);
      }
    } finally {
      state = false;
    }
  }
}

final listingThreadActionsProvider =
    StateNotifierProvider<ListingThreadActions, bool>(
        (ref) => ListingThreadActions(ref));
