import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/message_model.dart';
import 'full_screen_photo_view.dart';

/// Одно сообщение в списке чата: аватар-инициал, имя автора, текст/фото,
/// время отправки.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onAuthorTap,
  });

  final MessageModel message;
  final bool isMine;

  /// Тап по имени автора над чужим сообщением — открыть личный диалог с
  /// ним. null — если это недоступно (своё сообщение, не залогинен,
  /// автор — dev-пользователь). Тогда имя показывается без подсказки.
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(message.createdAt);

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        // Чужим сообщениям чуть меньше места — рядом ещё аватар автора.
        maxWidth: MediaQuery.of(context).size.width * (isMine ? 0.75 : 0.65),
      ),
      decoration: BoxDecoration(
        color: isMine ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _AuthorName(
                name: message.authorName,
                onTap: onAuthorTap,
              ),
            ),
          if (message.localPhotoBytes != null || message.photoUrl != null)
            GestureDetector(
              onTap: () => _openFullScreen(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: message.localPhotoBytes != null
                    ? Image.memory(
                        message.localPhotoBytes!,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoPlaceholder(),
                      )
                    : Image.network(
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
              padding: const EdgeInsets.only(top: 4),
              child: Text(message.text!),
            ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    // Чужие сообщения — с аватаром автора слева от пузыря (заглушка-иконка,
    // если фото профиля не загружено).
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: message.authorAvatarUrl != null
                ? NetworkImage(message.authorAvatarUrl!)
                : null,
            child: message.authorAvatarUrl == null
                ? const Icon(Icons.person, size: 16, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenPhotoView(
          photoUrl: message.localPhotoBytes == null ? message.photoUrl : null,
          photoBytes: message.localPhotoBytes,
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

/// Имя автора над чужим сообщением. Если задан [onTap] — кликабельно
/// (подчёркнуто) и ведёт в личный диалог с этим пользователем.
class _AuthorName extends StatelessWidget {
  const _AuthorName({required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
      fontSize: 12,
      decoration: onTap == null ? null : TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    final text = Text(name, style: style);
    if (onTap == null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: text,
    );
  }
}
