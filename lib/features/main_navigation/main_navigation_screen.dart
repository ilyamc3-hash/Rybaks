import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../baraholka/screens/baraholka_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../regions/providers/regions_provider.dart';
import '../regions/screens/regions_screen.dart';

/// Корневой экран приложения после входа: нижний таб-бар с четырьмя
/// разделами — Регионы, Чат, Барахолка, Профиль.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedRegion = ref.watch(selectedRegionProvider);

    final screens = <Widget>[
      const RegionsScreen(),
      selectedRegion == null
          ? const _NoRegionSelected()
          : ChatScreen(region: selectedRegion),
      const BaraholkaScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
