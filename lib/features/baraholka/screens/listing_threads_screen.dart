import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/listing_thread_model.dart';
import '../providers/listing_threads_provider.dart';
import 'listing_thread_screen.dart';

/// «Входящие»: список всех личных переписок пользователя — по
/// объявлениям барахолки и прямых диалогов из чата — вперемешку по
/// последней активности. Тап открывает переписку.
class ListingThreadsScreen extends ConsumerWidget {
  const ListingThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(listingThreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(listingThreadsProvider),
        child: threadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить переписки.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          data: (threads) {
            if (threads.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Здесь появятся личные переписки — вопросы продавцам '
                      'по объявлениям и диалоги из чата.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ThreadTile(thread: threads[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});

  final ListingThreadModel thread;

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;
    final isDirect = thread.isDirect;

    // Прямой диалог из чата: объявления нет — в заголовке имя собеседника,
    // в «подписи объявления» — «Личный диалог», в аватарке — фото
    // собеседника (или иконка человека).
    final leadingUrl =
        isDirect ? thread.counterpartyAvatarUrl : thread.listingPhotoUrl;
    final titleText = isDirect
        ? thread.counterpartyName
        : (thread.listingTitle ?? 'Объявление');
    final captionText =
        isDirect ? 'Личный диалог' : thread.counterpartyName;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: leadingUrl != null
              ? Image.network(
                  leadingUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _photoPlaceholder(isDirect),
                )
              : _photoPlaceholder(isDirect),
        ),
      ),
      title: Text(
        titleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            captionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _preview(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (thread.lastMessageAt != null)
            Text(
              _shortTime(thread.lastMessageAt!),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '${thread.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingThreadScreen(thread: thread),
          ),
        );
      },
    );
  }

  String _preview() {
    final prefix = thread.lastMessageMine ? 'Вы: ' : '';
    if (thread.lastMessageText != null &&
        thread.lastMessageText!.trim().isNotEmpty) {
      return '$prefix${thread.lastMessageText!.trim()}';
    }
    if (thread.lastMessagePhotoUrl != null) return '$prefix📷 Фото';
    return 'Нет сообщений';
  }

  String _shortTime(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay
        ? DateFormat.Hm().format(local)
        : DateFormat('dd.MM').format(local);
  }

  Widget _photoPlaceholder(bool isDirect) {
    return Container(
      color: AppColors.primaryLight,
      child: Icon(
        isDirect ? Icons.person : Icons.photo_camera_back_outlined,
        color: AppColors.primary,
        size: 20,
      ),
    );
  }
}
