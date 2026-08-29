import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/product_model.dart';
import '../../../services/supabase_service.dart';

/// Список товаров из таблицы `products` в Supabase.
///
/// Доступен без авторизации (в т.ч. в dev-режиме) — RLS в
/// supabase/schema.sql разрешает публичное чтение. Если таблица
/// пустая, выполните supabase/seed.sql — он добавит несколько
/// тестовых товаров.
final catalogProvider = FutureProvider<List<ProductModel>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseTables.products)
      .select()
      .order('created_at', ascending: false);
  return rows.map(ProductModel.fromJson).toList();
});
