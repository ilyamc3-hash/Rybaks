import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/listing_message_model.dart';

/// Одно сообщение в личной переписке по объявлению. Диалог 1:1, поэтому
/// имя автора не показываем (оно в шапке экрана) — только текст/фото,
/// время и для своих сообщений галочку прочтения.
class ListingMessageBubble extends StatelessWidget {
  const ListingMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ListingMessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(message.createdAt.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.photoUrl != null)
              GestureDetector(
                onTap: () => _openPhoto(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    message.photoUrl!,
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _photoPlaceholder(),
                  ),
                ),
              ),
            if (message.text != null)
              Padding(
                padding: EdgeInsets.only(top: message.photoUrl != null ? 6 : 0),
                child: Text(message.text!),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: InteractiveViewer(
                      child: Image.network(message.photoUrl!,
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: SafeArea(
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 200,
      height: 150,
      color: AppColors.primaryLight,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
