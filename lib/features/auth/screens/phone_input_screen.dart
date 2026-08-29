import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../main_navigation/main_navigation_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/dev_auth_provider.dart';
import 'sms_code_screen.dart';

/// Экран 1 из 2 авторизации: ввод номера телефона для получения SMS-кода.
class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _phoneController = TextEditingController(text: '+7');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 11) return;

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.sendOtp(phone);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SmsCodeScreen(phone: phone)),
      );
    } else {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить код. $error')),
      );
    }
  }

  /// Dev-режим: вход тестовым пользователем без реальной отправки SMS.
  /// Используется, пока в проекте не настроен реальный SMS-провайдер.
  /// Доступно только в debug-сборке.
  void _loginAsTestUser() {
    ref.read(devTestUserProvider.notifier).state = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phishing,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите номер телефона для входа',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _phoneController,
                label: 'Номер телефона',
                hintText: '+7 900 123-45-67',
                keyboardType: TextInputType.phone,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Получить код',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Для разработки',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loginAsTestUser,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Войти как тестовый пользователь'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
