import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'features/regions/providers/regions_provider.dart';
import 'services/region_preference_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Локализация дат/времени для форматирования сообщений в чате.
  await initializeDateFormatting('ru_RU');

  // Инициализация Supabase (URL и ключ — см. core/constants/app_constants.dart).
  await SupabaseService.initialize();

  // Регион, выбранный пользователем в прошлый раз — читаем из локального
  // хранилища до старта, чтобы MainNavigationScreen мог его восстановить
  // (см. savedRegionIdProvider и RegionPreferenceService).
  final savedRegionId = await RegionPreferenceService.loadRegionId();

  runApp(
    ProviderScope(
      overrides: [
        savedRegionIdProvider.overrideWithValue(savedRegionId),
      ],
      child: const KlevApp(),
    ),
  );
}
