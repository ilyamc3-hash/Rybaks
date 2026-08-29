import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/region_model.dart';
import '../../../services/supabase_service.dart';
import '../providers/listings_provider.dart';

/// Форма создания объявления. Объявление привязывается к [region]
/// (текущий выбранный регион) и к текущему пользователю.
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key, required this.region});

  final RegionModel region;

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo != null) setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название объявления')),
      );
      return;
    }

    final priceText =
        _priceController.text.trim().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    double? price;
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Цена указана неверно')),
        );
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await SupabaseService.uploadListingPhoto(_photo!);
      }
      await ref.read(listingActionsProvider.notifier).create(
            regionId: widget.region.id,
            title: title,
            description: _descriptionController.text.trim(),
            price: price,
            photoUrl: photoUrl,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Объявление размещено')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось разместить объявление. $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новое объявление')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Регион: ${widget.region.name}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _PhotoPicker(photo: _photo, onTap: _submitting ? null : _pickPhoto),
              const SizedBox(height: 20),
              AppTextField(
                controller: _titleController,
                label: 'Название',
                hintText: 'Например: Спиннинг Shimano, 2.4 м',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'Состояние, комплектность, причина продажи…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _priceController,
                label: 'Цена, ₽',
                hintText: 'Можно оставить пустым — «Цена договорная»',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Разместить',
                isLoading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              const Text(
                'Оплата и передача — напрямую между покупателем и продавцом, '
                'вне приложения.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onTap});

  final XFile? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 32),
                  SizedBox(height: 8),
                  Text('Добавить фото',
                      style: TextStyle(color: AppColors.primary)),
                ],
              )
            : FutureBuilder<Uint8List>(
                future: photo!.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
