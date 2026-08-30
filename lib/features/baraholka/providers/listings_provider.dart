import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/listing_model.dart';
import '../../../services/supabase_service.dart';

/// Профиль продавца приезжает embed'ом на представление
/// `user_public_profiles` (имя/аватар, без телефона). Хинт
/// `!listings_seller_id_fkey` — имя FK-констрейнта listings.seller_id →
/// users.id; PostgREST требует его для embed через view. Сверить точное
/// имя: `select conname from pg_constraint where contype='f'
/// and conrelid='listings'::regclass;`
const _sellerSelect =
    '*, seller:user_public_profiles!listings_seller_id_fkey(id, name, avatar_url)';

/// Активные объявления барахолки выбранного региона (свежие сверху).
///
/// Доступно без авторизации (RLS открывает SELECT всем). Имя продавца
/// берётся из `user_public_profiles`; если имя не задано — в карточке
/// общая подпись «Продавец».
final regionListingsProvider = FutureProvider.autoDispose
    .family<List<ListingModel>, String>((ref, regionId) async {
  final rows = await SupabaseService.client
      .from(SupabaseTables.listings)
      .select(_sellerSelect)
      .eq('region_id', regionId)
      .eq('status', 'active')
      .order('created_at', ascending: false);
  return rows.map(ListingModel.fromJson).toList();
});

/// Объявления текущего пользователя — все статусы, свежие сверху.
/// Пусто без реальной сессии Supabase (dev-режим ничего не пишет в БД).
final myListingsProvider =
    FutureProvider.autoDispose<List<ListingModel>>((ref) async {
  final userId = SupabaseService.currentUser?.id;
  if (userId == null) return const [];
  final rows = await SupabaseService.client
      .from(SupabaseTables.listings)
      .select(_sellerSelect)
      .eq('seller_id', userId)
      .order('created_at', ascending: false);
  return rows.map(ListingModel.fromJson).toList();
});

/// Действия над объявлениями (создание/статус/удаление). Держит флаг
/// [isBusy] для блокировки кнопок формы; после успеха вызывающий код
/// инвалидирует [regionListingsProvider] / [myListingsProvider].
class ListingActions extends StateNotifier<bool> {
  ListingActions(this.ref) : super(false);

  final Ref ref;

  bool get isBusy => state;

  Future<void> _run(Future<void> Function() action) async {
    state = true;
    try {
      await action();
    } finally {
      state = false;
    }
    ref.invalidate(myListingsProvider);
  }

  Future<void> create({
    required String regionId,
    required String title,
    String? description,
    double? price,
    String? photoUrl,
  }) {
    return _run(() async {
      await SupabaseService.createListing(
        regionId: regionId,
        title: title,
        description: description,
        price: price,
        photoUrl: photoUrl,
      );
      ref.invalidate(regionListingsProvider(regionId));
    });
  }

  Future<void> markSold(ListingModel listing) {
    return _run(() async {
      await SupabaseService.setListingStatus(listing.id, 'sold');
      ref.invalidate(regionListingsProvider(listing.regionId));
    });
  }

  Future<void> delete(ListingModel listing) {
    return _run(() async {
      await SupabaseService.deleteListing(listing.id);
      ref.invalidate(regionListingsProvider(listing.regionId));
    });
  }
}

final listingActionsProvider =
    StateNotifierProvider<ListingActions, bool>((ref) => ListingActions(ref));
