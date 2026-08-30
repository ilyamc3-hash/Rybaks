import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/region_preference_service.dart';
import '../../chat/screens/chat_screen.dart';
import '../providers/regions_provider.dart';

/// Главный экран приложения: список регионов. Тап по региону запоминает
/// выбор (для вкладки «Чат») и открывает чат этого региона.
class RegionsScreen extends ConsumerWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsProvider);
    final selectedRegion = ref.watch(selectedRegionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регионы'),
        // Дублируем текущий выбор в подзаголовке — это единственный
        // экран, где видно сразу все регионы, поэтому здесь важнее
        // всего не потерять из виду, какой из них активен сейчас.
        bottom: selectedRegion == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Сейчас выбран: ${selectedRegion.name}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
      ),
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
              final isSelected = region.id == selectedRegion?.id;
              return Card(
                shape: isSelected
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      )
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      isSelected
                          ? Icons.location_on
                          : Icons.location_on_outlined,
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
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(selectedRegionProvider.notifier).state = region;
                    // Сохраняем выбор на диск, чтобы он пережил полный
                    // перезапуск приложения, а не только сворачивание.
                    RegionPreferenceService.saveRegionId(region.id);
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
