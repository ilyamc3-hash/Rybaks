import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/region_model.dart';
import '../baraholka/screens/baraholka_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../regions/providers/regions_provider.dart';
import '../regions/screens/regions_screen.dart';
import 'providers/tab_index_provider.dart';

/// Корневой экран приложения после входа: нижний таб-бар с четырьмя
/// разделами — Регионы, Чат, Барахолка, Профиль.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    // Восстанавливаем регион, выбранный в прошлом запуске приложения
    // (сохранён в SharedPreferences/localStorage — см.
    // RegionPreferenceService). Без этого шага выбор региона живёт
    // только в памяти текущей сессии и обнуляется при полном
    // перезапуске приложения.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreRegion());
  }

  Future<void> _restoreRegion() async {
    // Если пользователь уже успел выбрать регион в этой сессии — не
    // перетираем его выбор сохранённым значением.
    if (ref.read(selectedRegionProvider) != null) return;

    final savedId = ref.read(savedRegionIdProvider);
    if (savedId == null) return;

    final regions = await ref.read(regionsProvider.future);
    if (!mounted) return;
    if (ref.read(selectedRegionProvider) != null) return;

    RegionModel? match;
    for (final region in regions) {
      if (region.id == savedId) {
        match = region;
        break;
      }
    }
    if (match != null) {
      ref.read(selectedRegionProvider.notifier).state = match;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRegion = ref.watch(selectedRegionProvider);
    final currentIndex = ref.watch(currentTabIndexProvider);

    final screens = <Widget>[
      const RegionsScreen(),
      selectedRegion == null
          ? const _NoRegionSelected()
          : ChatScreen(region: selectedRegion),
      const BaraholkaScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(currentTabIndexProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Регионы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sell_outlined),
            activeIcon: Icon(Icons.sell),
            label: 'Барахолка',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

/// Заглушка вкладки «Чат», пока пользователь не выбрал регион.
class _NoRegionSelected extends StatelessWidget {
  const _NoRegionSelected();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чат')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Выберите регион на вкладке «Регионы», чтобы открыть его чат',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
