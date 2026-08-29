import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

/// Поток изменений состояния авторизации Supabase (вход/выход/обновление
/// токена). Используется на splash-экране, чтобы решить, куда вести
/// пользователя дальше.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

/// Управляет процессом входа по номеру телефона: отправка SMS-кода
/// и его подтверждение. Состояние — `AsyncValue&lt;void&gt;`, где error
/// содержит текст последней ошибки для отображения пользователю.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncData(null));

  Future<bool> sendOtp(String phone) async {
    state = const AsyncLoading();
    try {
      await SupabaseService.sendOtp(phone);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String code}) async {
    state = const AsyncLoading();
    try {
      await SupabaseService.verifyOtp(phone: phone, otpCode: code);
      await SupabaseService.upsertCurrentUserProfile();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController();
});
