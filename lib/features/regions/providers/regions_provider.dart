import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/region_model.dart';
import '../../../services/supabase_service.dart';

/// Список регионов из таблицы `regions` в Supabase.
///
/// Доступен без авторизации (в т.ч. в dev-режиме) — RLS в
/// supabase/schema.sql разрешает публичное чтение. Если таблица
/// пустая, выполните supabase/seed.sql — он добавит Москву и
/// Санкт-Петербург.
final regionsProvider = FutureProvider<List<RegionModel>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseTables.regions)
      .select()
      .order('name', ascending: true);
  return rows.map(RegionModel.fromJson).toList();
});

/// Регион, выбранный пользователем последним — используется вкладкой «Чат».
final selectedRegionProvider = StateProvider<RegionModel?>((ref) => null);
