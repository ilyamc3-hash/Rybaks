import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Обёртка над Supabase-клиентом: инициализация SDK и методы
/// авторизации по номеру телефона (SMS-код).
///
/// Остальные фичи (регионы/чат/каталог) обращаются к базе данных
/// через `SupabaseService.client`, когда переходят с тестовых данных
/// на реальные запросы.
class SupabaseService {
  SupabaseService._();

  /// Вызывается один раз в main() до runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static Session? get currentSession => auth.currentSession;

  static User? get currentUser => auth.currentUser;

  /// false, если сессии нет или Supabase ещё не инициализирован
  /// (например, экран построен раньше main() — в тестах).
  static bool get isAuthenticated {
    try {
      return currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Шаг 1 авторизации: отправляет SMS с кодом на указанный номер.
  /// Номер должен быть в формате E.164, например +79001234567.
  static Future<void> sendOtp(String phone) {
    return auth.signInWithOtp(phone: phone);
  }

  /// Шаг 2 авторизации: проверяет код из SMS и создаёт сессию.
  static Future<AuthResponse> verifyOtp({
    required String phone,
    required String otpCode,
  }) {
    return auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: otpCode,
    );
  }

  static Future<void> signOut() {
    return auth.signOut();
  }

  /// Создаёт (или обновляет) строку профиля текущего пользователя в
  /// таблице `users`. Вызывается сразу после успешного verifyOtp: без неё
  /// отправка сообщений/товаров упадёт на внешнем ключе, ссылающемся на
  /// `users(id)`.
  static Future<void> upsertCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return;
    await client.from(SupabaseTables.users).upsert({
      'id': user.id,
      'phone': user.phone ?? '',
    });
  }

  /// Загружает профиль текущего пользователя (имя, аватар) из таблицы
  /// `users`. null, если нет реальной сессии (в т.ч. в dev-режиме).
  static Future<UserModel?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await client
        .from(SupabaseTables.users)
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UserModel.fromJson(row);
  }

  /// Обновляет имя и/или ссылку на аватар текущего пользователя.
  static Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final user = currentUser;
    if (user == null) return;
    await client.from(SupabaseTables.users).upsert({
      'id': user.id,
      'phone': user.phone ?? '',
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  /// Загружает фото профиля в Supabase Storage (бакет `avatars`, путь
  /// "{user_id}/avatar" — новая загрузка перезаписывает старую) и
  /// возвращает публичный URL. Требует настоящую сессию Supabase.
  static Future<String> uploadAvatar(XFile photo) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Нет авторизованного пользователя для загрузки аватара.');
    }
    final bytes = await photo.readAsBytes();
    final path = '${user.id}/avatar';
    await client.storage.from(SupabaseBuckets.avatars).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: photo.mimeType ?? 'image/jpeg',
            upsert: true,
          ),
        );
    final publicUrl = client.storage.from(SupabaseBuckets.avatars).getPublicUrl(path);
    // Путь не меняется между загрузками — добавляем метку времени, чтобы
    // Image.network не показывал закэшированную старую версию фото.
    return '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Загружает фото сообщения чата в Supabase Storage (бакет `chat-photos`,
  /// путь "{user_id}/{region_id}-{timestamp}.jpg") и возвращает публичный
  /// URL. Читает файл как байты через XFile.readAsBytes(), а не через
  /// dart:io File — на вебе dart:io недоступен, а XFile.readAsBytes()
  /// работает одинаково на вебе и на Android (тот же подход, что и в
  /// uploadAvatar). Требует настоящую сессию Supabase.
  static Future<String> uploadChatPhoto(XFile photo, {required String regionId}) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Нет авторизованного пользователя для загрузки фото.');
    }
    final bytes = await photo.readAsBytes();
    final path = '${user.id}/$regionId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from(SupabaseBuckets.chatPhotos).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo.mimeType ?? 'image/jpeg'),
        );
    return client.storage.from(SupabaseBuckets.chatPhotos).getPublicUrl(path);
  }

  /// Загружает фото объявления барахолки в Storage (бакет `listing-photos`,
  /// путь "{user_id}/{timestamp}.jpg") и возвращает публичный URL.
  /// Байты читаются через XFile.readAsBytes() — одинаково на вебе и на
  /// Android (тот же подход, что в uploadAvatar/uploadChatPhoto). Требует
  /// настоящую сессию Supabase.
  static Future<String> uploadListingPhoto(XFile photo) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Нет авторизованного пользователя для загрузки фото.');
    }
    final bytes = await photo.readAsBytes();
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from(SupabaseBuckets.listingPhotos).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo.mimeType ?? 'image/jpeg'),
        );
    return client.storage.from(SupabaseBuckets.listingPhotos).getPublicUrl(path);
  }

  /// Создаёт объявление барахолки от имени текущего пользователя. Регион —
  /// текущий выбранный (тот же, что у чата). RLS требует seller_id =
  /// auth.uid(), поэтому нужна настоящая сессия.
  static Future<void> createListing({
    required String regionId,
    required String title,
    String? description,
    double? price,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Разместить объявление можно только после входа по SMS.');
    }
    await client.from(SupabaseTables.listings).insert({
      'seller_id': user.id,
      'region_id': regionId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (price != null) 'price': price,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }

  /// Меняет статус объявления ('active' | 'sold' | 'archived').
  /// RLS пропустит только объявления текущего пользователя.
  static Future<void> setListingStatus(String listingId, String status) {
    return client
        .from(SupabaseTables.listings)
        .update({'status': status}).eq('id', listingId);
  }

  /// Удаляет объявление. RLS пропустит только объявления текущего
  /// пользователя.
  static Future<void> deleteListing(String listingId) {
    return client.from(SupabaseTables.listings).delete().eq('id', listingId);
  }
}
