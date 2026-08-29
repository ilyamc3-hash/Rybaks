import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Полноэкранный просмотр фото из чата: чёрный фон, фото по центру, тап по
/// фону или крестик в углу закрывают экран. Принимает либо байты локального
/// превью (dev-режим), либо URL загруженного фото — тот же выбор, что и в
/// ChatMessageBubble, поэтому работает одинаково на вебе и на Android.
class FullScreenPhotoView extends StatelessWidget {
  const FullScreenPhotoView({super.key, this.photoUrl, this.photoBytes})
      : assert(photoUrl != null || photoBytes != null);

  final String? photoUrl;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final image = photoBytes != null
        ? Image.memory(photoBytes!, fit: BoxFit.contain)
        : Image.network(photoUrl!, fit: BoxFit.contain);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(child: Center(child: image)),
            Positioned(
              top: 4,
              right: 4,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
