import 'package:flutter/material.dart';

/// Единая цветовая палитра приложения.
///
/// Тематика — вода/рыбалка: глубокий сине-бирюзовый как основной цвет,
/// янтарный акцент для кнопок действия и уведомлений.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B6E8F);
  static const Color primaryDark = Color(0xFF084F68);
  static const Color primaryLight = Color(0xFFE3F2F7);

  static const Color accent = Color(0xFFE8A23D);

  static const Color background = Color(0xFFF6F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1B2429);
  static const Color textSecondary = Color(0xFF6B7B80);

  static const Color error = Color(0xFFD64545);
  static const Color success = Color(0xFF3E9C5C);
  static const Color divider = Color(0xFFE1E8EA);
}
