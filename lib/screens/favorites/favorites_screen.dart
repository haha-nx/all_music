import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/player_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/album_art.dart';
import '../../widgets/song_context_menu.dart';

/// 收藏详情页
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final favorites = favoritesState.favorites;
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // 返回按钮 + 大标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 52, 0, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GlassPanel(
                  blur: 8,
                  borderRadius: 20,
                  tintColor: AppColors.surfaceLight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 12, AppSizes.paddingH, 8),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.6),
                          AppColors.primary.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '我的收藏',
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${favorites.length} 首歌曲',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 播放全部按钮
          if (favorites.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 8),
                child: Row(
                  children: [
                    GlassPanel(
                      blur: 10,
                      borderRadius: 12,
                      tintColor: AppColors.primary.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: GestureDetector(
                          onTap: () => ref.read(playerProvider.notifier).playPlaylist(favorites),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white),
                              SizedBox(width: 4),
                              Text('播放全部', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassPanel(
                      blur: 10,
                      borderRadius: 12,
                      tintColor: AppColors.surfaceLight,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.shuffle_rounded, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 歌曲列表
          if (favorites.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 80, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text('还没有收藏歌曲', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('在搜索中找到喜欢的歌曲并收藏', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = favorites[index];
                  final isPlaying = playerState.currentSong?.dedupeKey == song.dedupeKey;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 3),
                    child: GlassPanel(
                      blur: 8,
                      borderRadius: 14,
                      tintColor: isPlaying
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceLight,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isPlaying ? AppColors.primary : AppColors.textTertiary,
                                ),
                              ),
                            ),
                            AlbumArt(
                              coverUrl: song.albumCover,
                              size: 44,
                              borderRadius: 8,
                              isPlaying: isPlaying,
                            ),
                          ],
                        ),
                        title: Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isPlaying ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        trailing: Icon(
                          isPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
                          color: isPlaying ? AppColors.primary : AppColors.textTertiary,
                        ),
                        onTap: () {
                          ref.read(playerProvider.notifier).playPlaylist(favorites, startIndex: index);
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          showSongContextMenu(context, ref, song);
                        },
                      ),
                    ),
                  );
                },
                childCount: favorites.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
