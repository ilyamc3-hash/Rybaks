import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/listing_model.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/dev_auth_provider.dart';
import '../providers/listing_threads_provider.dart';
import '../providers/listings_provider.dart';
import 'listing_thread_screen.dart';

/// Карточка объявления: фото, цена, описание, продавец + кнопка
/// «Написать» (единственный способ связи — телефон не показываем).
/// Если объявление принадлежит текущему пользователю — кнопки
/// «Отметить проданным» и «Удалить».
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final ListingModel listing;

  bool get _isMine => SupabaseService.currentUser?.id == listing.sellerId;

  Future<void> _markSold(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(listingActionsProvider.notifier).markSold(listing);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось обновить объявление. $error')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Восстановить его будет нельзя.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(listingActionsProvider.notifier).delete(listing);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить объявление. $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(listingActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Объявление')),
      body: ListView(
        children: [
          if (listing.photoUrl != null)
            Image.network(
              listing.photoUrl!,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 260,
                child: ColoredBox(
                  color: AppColors.primaryLight,
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.primary, size: 40),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatRub(listing.price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                if (listing.isSold) ...[
                  const SizedBox(height: 8),
                  const _Badge(text: 'Продано'),
                ],
                if (listing.description != null &&
                    listing.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(listing.description!.trim(),
                      style: const TextStyle(height: 1.4)),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _SellerBlock(listing: listing, isMine: _isMine),
                if (_isMine) ...[
                  const SizedBox(height: 24),
                  if (listing.isActive)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _markSold(context, ref),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Отметить проданным'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: busy ? null : () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    label: const Text('Удалить объявление',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerBlock extends ConsumerWidget {
  const _SellerBlock({required this.listing, required this.isMine});

  final ListingModel listing;
  final bool isMine;

  Future<void> _openThread(BuildContext context, WidgetRef ref) async {
    try {
      final thread = await ref
          .read(listingThreadActionsProvider.notifier)
          .openOrCreate(listing);
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingThreadScreen(thread: thread),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть переписку. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // «Написать» — только реальному покупателю: не своё объявление, есть
    // настоящая сессия Supabase (RLS требует auth.uid()), не dev-режим.
    // Телефон продавца в приложении больше не показывается — связь
    // только через встроенную переписку.
    final isDevTestUser = ref.watch(devTestUserProvider);
    final threadBusy = ref.watch(listingThreadActionsProvider);
    final canMessage =
        !isMine && SupabaseService.isAuthenticated && !isDevTestUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isMine ? 'Ваше объявление' : 'Продавец',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: listing.sellerAvatarUrl != null
                  ? NetworkImage(listing.sellerAvatarUrl!)
                  : null,
              child: listing.sellerAvatarUrl == null
                  ? const Icon(Icons.person, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                listing.sellerDisplayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (canMessage) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: threadBusy ? null : () => _openThread(context, ref),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Написать'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    );
  }
}
