import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/dev_auth_provider.dart';
import '../../auth/screens/phone_input_screen.dart';
import '../../baraholka/screens/my_listings_screen.dart';
import '../providers/profile_provider.dart';

/// Экран профиля: номер телефона, имя и фото пользователя, выход из
/// аккаунта. Редактирование имени/фото доступно только при настоящей
/// сессии Supabase — dev-тестовый пользователь ничего не пишет в БД
/// (см. DevTestUser и комментарий в ChatController).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  String? _loadedName;
  bool _isSavingName = false;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    // Сбрасываем и dev-вход тестовым пользователем, если он был активен.
    ref.read(devTestUserProvider.notifier).state = false;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
      (route) => false,
    );
  }

  Future<void> _saveName() async {
    setState(() => _isSavingName = true);
    try {
      await SupabaseService.updateProfile(name: _nameController.text.trim());
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя сохранено')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить имя. $error')),
      );
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final avatarUrl = await SupabaseService.uploadAvatar(photo);
      await SupabaseService.updateProfile(avatarUrl: avatarUrl);
      ref.invalidate(currentUserProfileProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить фото. $error')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(currentUserPhoneProvider);
    final isDevTestUser = ref.watch(devTestUserProvider);
    final canEditProfile = SupabaseService.isAuthenticated && !isDevTestUser;

    final profileAsync = ref.watch(currentUserProfileProvider);

    // Подставляем сохранённое имя в поле ввода один раз, когда профиль
    // загрузится — дальше поле принадлежит пользователю, перезаписывать
    // набранный текст при каждом ребилде не нужно. Мутируем контроллер
    // напрямую (а не через setState): TextEditingController сам оповещает
    // подписанный на него TextField.
    profileAsync.whenData((profile) {
      if (_loadedName == null) {
        _loadedName = profile?.name ?? '';
        _nameController.text = _loadedName!;
      }
    });

    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 44,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    if (canEditProfile)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: AppColors.primary,
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                phone,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                isDevTestUser ? 'Рыбак (dev-режим)' : 'Рыбак',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (canEditProfile) ...[
                AppTextField(
                  controller: _nameController,
                  label: 'Имя',
                  hintText: 'Как вас называть в чате',
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Сохранить имя',
                  isLoading: _isSavingName,
                  onPressed: _saveName,
                ),
                const SizedBox(height: 24),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Имя и фото профиля доступны после входа по SMS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (canEditProfile) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyListingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('Мои объявления'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Выйти',
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
