import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Локализация дат/времени для форматирования сообщений в чате.
  await initializeDateFormatting('ru_RU');

  // Инициализация Supabase (URL и ключ — см. core/constants/app_constants.dart).
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: KlevApp(),
    ),
  );
}
