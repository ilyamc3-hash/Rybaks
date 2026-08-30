import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/listing_thread_model.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/dev_auth_provider.dart';
import '../providers/listing_thread_provider.dart';
import '../widgets/listing_message_bubble.dart';

/// Экран личной переписки по объявлению барахолки. По образу
/// `ChatScreen` регионального чата (ввод текста + фото, realtime), но в
/// шапке — название объявления и имя собеседника вместо региона.
class ListingThreadScreen extends ConsumerStatefulWidget {
  const ListingThreadScreen({super.key, required this.thread});

  final ListingThreadModel thread;

  @override
  ConsumerState<ListingThreadScreen> createState() =>
      _ListingThreadScreenState();
}

class _ListingThreadScreenState extends ConsumerState<ListingThreadScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  String get _threadId => widget.thread.id;
  String? get _userId => SupabaseService.currentUser?.id;

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
    final userId = _userId;
    if (userId == null) return;
    _textController.clear();
    try {
      await ref
          .read(listingThreadControllerProvider(_threadId).notifier)
          .sendText(text, senderId: userId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить сообщение. $error')),
      );
    }
  }

  Future<void> _attachPhoto() async {
    final userId = _userId;
    if (userId == null) return;
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo == null) return;
    try {
      await ref
          .read(listingThreadControllerProvider(_threadId).notifier)
          .sendPhoto(photo, senderId: userId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить фото. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(listingThreadControllerProvider(_threadId), (previous, next) {
      final prevCount = previous?.valueOrNull?.length;
      final nextCount = next.valueOrNull?.length;
      if (prevCount != null && nextCount != null && nextCount > prevCount) {
        _scrollToBottom();
      }
    });

    final messagesAsync =
        ref.watch(listingThreadControllerProvider(_threadId));
    final isDevTestUser = ref.watch(devTestUserProvider);
    final canWrite = SupabaseService.isAuthenticated && !isDevTestUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.listingTitle ?? 'Объявление',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.thread.counterpartyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
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
                      'Не удалось загрузить переписку.\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Напишите первое сообщение по этому объявлению.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ListingMessageBubble(
                        message: message,
                        isMine: message.senderId == _userId,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            if (canWrite)
              _MessageInputBar(
                controller: _textController,
                onAttachPhoto: _attachPhoto,
                onSend: _sendText,
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Отвечать в переписке можно только после входа по SMS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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
