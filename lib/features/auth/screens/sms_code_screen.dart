import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../main_navigation/main_navigation_screen.dart';
import '../providers/auth_provider.dart';

/// Экран 2 из 2 авторизации: ввод кода, пришедшего в SMS.
class SmsCodeScreen extends ConsumerStatefulWidget {
  const SmsCodeScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends ConsumerState<SmsCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length < 4) return;

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.verifyOtp(
      phone: widget.phone,
      code: code,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Неверный код. ${error ?? ''}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Введите код из SMS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Код отправлен на ${widget.phone}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _codeController,
                label: 'Код из SMS',
                hintText: '••••',
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Войти',
                isLoading: isLoading,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
