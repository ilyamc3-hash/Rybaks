import 'package:shared_preferences/shared_preferences.dart';

/// Хранит id последнего выбранного региона в локальном хранилище
/// устройства (SharedPreferences на Android, localStorage в вебе),
/// чтобы выбор переживал полный перезапуск приложения — не только
/// сворачивание/сессию в памяти.
///
/// Без этого `selectedRegionProvider` (Riverpod StateProvider) живёт
/// только в памяти процесса: пользователь мог выбрать ЯНАО в одной
/// сессии, свернуть приложение, вернуться через день и увидеть чат/
/// барахолку ЯНАО без явного понимания, что это сохранённый выбор,
/// а не заново подтверждённый.
class RegionPreferenceService {
  RegionPreferenceService._();

  static const String _key = 'selected_region_id';

  /// Возвращает сохранённый id региона, либо null, если выбор ещё
  /// не сохранялся.
  static Future<String?> loadRegionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Сохраняет id выбранного региона.
  static Future<void> saveRegionId(String regionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, regionId);
  }

  /// Очищает сохранённый регион (например, при выходе из аккаунта).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
