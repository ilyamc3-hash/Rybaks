/// Конфигурация Supabase-проекта.
///
/// Значения передаются через --dart-define при сборке/запуске, например:
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// Так реальные ключи не попадают в git. На этапе разработки можно
/// временно подставить значения по умолчанию ниже.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nwerzgirwbrfcbtdotlf.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_0PY0lp0IdYWWh-l8H_GOcw__Sabzpv7',
  );
}

/// Названия таблиц в базе данных Supabase — используются сервисами,
/// чтобы не разбрасывать строковые литералы по коду.
class SupabaseTables {
  SupabaseTables._();

  static const String users = 'users';

  /// Представление `user_public_profiles` — имя/аватар без телефона.
  /// Читать чужие профили можно только отсюда: RLS на `users` отдаёт
  /// пользователю лишь его собственную строку (см. supabase/users_rls_fix.sql).
  static const String userPublicProfiles = 'user_public_profiles';
  static const String regions = 'regions';
  static const String messages = 'messages';
  static const String listings = 'listings';
  static const String listingThreads = 'listing_threads';
  static const String listingMessages = 'listing_messages';
}

/// Названия бакетов Supabase Storage.
class SupabaseBuckets {
  SupabaseBuckets._();

  static const String avatars = 'avatars';
  static const String chatPhotos = 'chat-photos';
  static const String listingPhotos = 'listing-photos';
  static const String threadPhotos = 'thread-photos';
}

/// Общие текстовые константы приложения.
class AppStrings {
  AppStrings._();

  static const String appName = 'Клёв';
}
