import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Флаг «вход тестовым пользователем» — только для локальной разработки,
/// когда нет настроенного SMS-провайдера в Supabase.
///
/// Важно: это НЕ создаёт настоящую сессию Supabase, а лишь имитирует
/// вход внутри приложения. Кнопка, которая включает этот флаг, показывается
/// только в debug-сборке (см. PhoneInputScreen).
final devTestUserProvider = StateProvider<bool>((ref) => false);

/// Данные тестового пользователя, которыми заполняются экраны (профиль,
/// чат), когда включён dev-режим и реальной сессии Supabase ещё нет.
class DevTestUser {
  DevTestUser._();

  static const id = 'dev-test-user';
  static const phone = '+7 000 000-00-00';
  static const name = 'Тестовый пользователь (dev)';
}
