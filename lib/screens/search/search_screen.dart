import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/source_provider.dart';
import '../../widgets/album_art.dart';
import '../../widgets/song_context_menu.dart';

/// 搜索页 — 搜索 + 结果展示
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final sources = ref.watch(sourceProvider);
    final playerState = ref.watch(playerProvider);

    return CustomScrollView(
      slivers: [
        // 大标题
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              60,
              AppSizes.paddingH,
              12,
            ),
            child: Text(
              '搜索',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              0,
              AppSizes.paddingH,
              12,
            ),
            child: GlassPanel(
              blur: 12,
              borderRadius: 14,
              tintColor: AppColors.surfaceLight,
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌手、专辑',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  ref.read(searchProvider.notifier).searchWithDebounce(value.trim());
                },
              ),
            ),
          ),
        ),

        // 音源状态提示
        if (sources.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '请先在设置中导入音源',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (sources.every((s) => !s.enabled))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.error.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '所有音源已禁用，请在设置中启用至少一个音源',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 搜索结果
        if (searchState.isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (searchState.results.isEmpty && searchState.hasSearched)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    '未找到相关结果',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else if (searchState.results.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // 在列表最前面插入失败音源提示
                if (index == 0 && searchState.failedSources.isNotEmpty) {
                  return _FailedSourcesBanner(failedSources: searchState.failedSources);
                }
                final songIndex = index - (searchState.failedSources.isNotEmpty ? 1 : 0);
                final song = searchState.results[songIndex];
                final isPlaying = playerState.currentSong?.dedupeKey == song.dedupeKey;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                    vertical: 3,
                  ),
                  child: GlassPanel(
                    blur: 8,
                    borderRadius: 14,
                    tintColor: isPlaying
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    child: Material(
                      color: Colors.transparent,
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
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        isPlaying ? Icons.equalizer : Icons.play_circle_outline,
                        color: isPlaying ? AppColors.primary : AppColors.textTertiary,
                      ),
                      onTap: () {
                        ref.read(playerProvider.notifier).playPlaylist(
                          searchState.results,
                          startIndex: songIndex,
                        );
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        showSongContextMenu(context, ref, song);
                      },
                    ),
                    ),
                  ),
                );
              },
              childCount: searchState.results.length +
                  (searchState.failedSources.isNotEmpty ? 1 : 0),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

/// 搜索失败音源提示条
class _FailedSourcesBanner extends StatelessWidget {
  final List<String> failedSources;

  const _FailedSourcesBanner({required this.failedSources});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingH,
        vertical: 4,
      ),
      child: GlassPanel(
        blur: 8,
        borderRadius: 10,
        tintColor: AppColors.error.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${failedSources.join('、')} 搜索失败',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
