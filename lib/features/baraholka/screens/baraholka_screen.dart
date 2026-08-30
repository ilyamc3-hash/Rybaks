import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/region_model.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/dev_auth_provider.dart';
import '../../main_navigation/providers/tab_index_provider.dart';
import '../../regions/providers/regions_provider.dart';
import '../providers/listing_threads_provider.dart';
import '../providers/listings_provider.dart';
import '../widgets/listing_card.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'listing_threads_screen.dart';

/// Вкладка «Барахолка»: объявления пользователей в текущем выбранном
/// регионе (тот же регион, что у чата). Регион выбирается на вкладке
/// «Регионы»; пока он не выбран — показываем подсказку.
class BaraholkaScreen extends ConsumerWidget {
  const BaraholkaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(selectedRegionProvider);

    if (region == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Барахолка')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Выберите регион на вкладке «Регионы» — объявления показываются '
              'по вашему региону.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return _RegionBaraholka(region: region);
  }
}

class _RegionBaraholka extends ConsumerWidget {
  const _RegionBaraholka({required this.region});

  final RegionModel region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(regionListingsProvider(region.id));
    final isDevTestUser = ref.watch(devTestUserProvider);
    final canPost = SupabaseService.isAuthenticated && !isDevTestUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Барахолка · ${region.name}'),
        actions: [
          // Входящие переписки по объявлениям барахолки. Показываем только
          // тем, кто вообще может писать/получать сообщения (реальная
          // сессия, не dev) — у остальных «Сообщения» всегда пустые.
          if (canPost)
            Consumer(
              builder: (context, ref, _) {
                final unread = ref.watch(listingThreadsProvider).maybeWhen(
                      data: (threads) => threads.fold<int>(
                        0,
                        (sum, t) => sum + t.unreadCount,
                      ),
                      orElse: () => 0,
                    );
                // Цвет наследуется из AppBarTheme.foregroundColor.
                const icon = Icon(Icons.mail_outline);
                return IconButton(
                  tooltip: 'Сообщения',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ListingThreadsScreen(),
                    ),
                  ),
                  icon: unread > 0
                      ? Badge(label: Text('$unread'), child: icon)
                      : icon,
                );
              },
            ),
          // Та же кнопка смены региона, что и в чате — Барахолка и Чат
          // всегда показывают один и тот же регион, но легко забыть,
          // какой именно, если долго не открывал вкладку «Регионы».
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
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateListingScreen(region: region),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Разместить объявление'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(regionListingsProvider(region.id)),
        child: listingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить объявления.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          data: (listings) {
            if (listings.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      canPost
                          ? 'В этом регионе пока нет объявлений.\n'
                              'Разместите первое — кнопка внизу.'
                          : 'В этом регионе пока нет объявлений.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return ListingCard(
                  listing: listing,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
