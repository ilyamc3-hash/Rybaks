import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/region_model.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/dev_auth_provider.dart';
import '../../main_navigation/providers/tab_index_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';

/// Экран чата внутри выбранного региона: история сообщений из Supabase
/// (с realtime-подпиской на новые), поле ввода текста и кнопка
/// прикрепления фото.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.region});

  final RegionModel region;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  String get _userId => SupabaseService.currentUser?.id ?? DevTestUser.id;
  String get _userName =>
      SupabaseService.currentUser?.phone ?? DevTestUser.name;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    try {
      await ref.read(chatControllerProvider(widget.region.id).notifier).sendText(
            text,
            authorId: _userId,
            authorName: _userName,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить сообщение. $error')),
      );
    }
  }

  Future<void> _attachPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo == null) return;
    try {
      await ref.read(chatControllerProvider(widget.region.id).notifier).sendPhoto(
            photo,
            authorId: _userId,
            authorName: _userName,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить фото. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Прокручиваем список вниз каждый раз, когда в нём появляется новое
    // сообщение — своё локальное или пришедшее через realtime от других.
    ref.listen(chatControllerProvider(widget.region.id), (previous, next) {
      final prevCount = previous?.valueOrNull?.length;
      final nextCount = next.valueOrNull?.length;
      if (prevCount != null && nextCount != null && nextCount > prevCount) {
        _scrollToBottom();
      }
    });

    final messagesAsync = ref.watch(chatControllerProvider(widget.region.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Чат: ${widget.region.name}'),
        actions: [
          // Явная возможность сменить регион прямо из чата — чтобы не
          // приходилось помнить, что текущий регион вообще выбран, и не
          // искать вкладку «Регионы» отдельно.
          TextButton.icon(
            onPressed: () =>
                ref.read(currentTabIndexProvider.notifier).state = 0,
            // Цвета не задаём — TextButton в AppBar берёт foregroundColor
            // из textButtonTheme (AppColors.primary).
            icon: const Icon(Icons.sync_alt, size: 18),
            label: const Text('Сменить'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Не удалось загрузить чат.\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('Пока нет сообщений'));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ChatMessageBubble(
                        message: message,
                        isMine: message.authorId == _userId,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            _MessageInputBar(
              controller: _textController,
              onAttachPhoto: _attachPhoto,
              onSend: _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.onAttachPhoto,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onAttachPhoto;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onAttachPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Прикрепить фото',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Написать сообщение...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
