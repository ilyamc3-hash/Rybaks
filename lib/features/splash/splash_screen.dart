import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/phone_input_screen.dart';
import '../main_navigation/main_navigation_screen.dart';

/// Экран-заставка: логотип и автопереход либо на главный экран
/// (если пользователь уже авторизован), либо на экран входа.
///
/// Переход ждёт событие `initialSession` из `authStateChangesProvider` —
/// Supabase эмитит его сразу после попытки восстановить сессию из
/// локального хранилища (SharedPreferences на Android, localStorage в
/// вебе), поэтому решение "куда вести" принимается по факту восстановления
/// сессии, а не по угаданной задержке таймера. Таймер оставлен только как
/// защита на случай, если событие почему-то не пришло.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Подстраховка: если событие initialSession не пришло за 3 секунды
    // (например, из-за неожиданной ошибки в SDK), не оставляем
    // пользователя навсегда на заставке.
    Future.delayed(const Duration(seconds: 3), () {
      _navigateNext(SupabaseService.isAuthenticated);
    });
  }

  void _navigateNext(bool isAuthenticated) {
    if (_navigated || !mounted) return;
    _navigated = true;

    final nextScreen = isAuthenticated
        ? const MainNavigationScreen()
        : const PhoneInputScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (_, next) {
      next.whenData((authState) {
        if (authState.event == AuthChangeEvent.initialSession) {
          _navigateNext(authState.session != null);
        }
      });
    });

    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phishing, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              AppStrings.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Чат и маркетплейс рыбаков',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
