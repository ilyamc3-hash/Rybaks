import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Индекс текущей вкладки нижнего таб-бара (Регионы / Чат / Барахолка /
/// Профиль).
///
/// Вынесен в отдельный провайдер (а не приватный `_currentIndex` внутри
/// `_MainNavigationScreenState`), чтобы экраны Чата и Барахолки могли
/// программно переключить пользователя на вкладку «Регионы» кнопкой
/// «Сменить регион» в шапке, не имея прямого доступа к состоянию
/// `MainNavigationScreen`.
final currentTabIndexProvider = StateProvider<int>((ref) => 0);
