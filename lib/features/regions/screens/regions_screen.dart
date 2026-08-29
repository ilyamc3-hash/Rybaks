import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/screens/chat_screen.dart';
import '../providers/regions_provider.dart';

/// Главный экран приложения: список регионов. Тап по региону запоминает
/// выбор (для вкладки «Чат») и открывает чат этого региона.
class RegionsScreen extends ConsumerWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Регионы')),
      body: regionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить регионы.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (regions) {
          if (regions.isEmpty) {
            return const Center(child: Text('Регионы пока не добавлены'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: regions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final region = regions[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    region.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: region.description != null
                      ? Text(region.description!)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(selectedRegionProvider.notifier).state = region;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(region: region),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
