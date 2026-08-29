// Базовый smoke-test: приложение запускается и показывает splash-экран.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klev_app/app.dart';
import 'package:klev_app/core/constants/app_constants.dart';

void main() {
  testWidgets('Splash screen отображается при старте', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KlevApp()),
    );

    expect(find.text(AppStrings.appName), findsOneWidget);

    // Сплэш ждёт событие initialSession, а если его нет — таймер-подстраховку
    // на 3 секунды. Прокручиваем время за этот порог и даём отработать
    // навигации на экран входа, чтобы после теста не осталось живых таймеров.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
