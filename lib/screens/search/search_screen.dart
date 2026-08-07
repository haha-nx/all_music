import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../music_source/models/music_track.dart';
import '../../music_source/builtin/builtin_platforms.dart';
import '../../music_source/providers/music_source_provider.dart';
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
    final sources = ref.watch(sourceListProvider);
    final playerState = ref.watch(playerProvider);
    final sourceNotifier = ref.read(sourceListProvider.notifier);
    final engineReady = sourceNotifier.isEngineReady;
    final engineLoading = sourceNotifier.readyState == SourceReadyState.loading;
    final engineError = sourceNotifier.readyError;

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

        // 搜索类型切换（单曲/专辑/歌手/歌单）
        SliverToBoxAdapter(
          child: _buildTypeChips(),
        ),

        // 音源状态提示
        if (engineLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.accentBlue.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '音源引擎初始化中...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (!engineReady && engineError != null)
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
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '引擎错误: $engineError',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (sources.isEmpty)
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
        else if (searchState.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 8),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          searchState.error!,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        else if (searchState.results.isNotEmpty &&
            searchState.searchType != SearchType.song)
          SliverToBoxAdapter(
            child: _buildMediaGrid(searchState.results),
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
                      title: Row(
                        children: [
                          _platformBadge(song.sourceKey),
                          Expanded(
                            child: Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isPlaying ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
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

  // ──── 搜索类型切换 ────

  /// 平台徽标（搜索结果标注音源）
  Widget _platformBadge(String? sourceKey) {
    final name = sourceKey == null ? '' : kSourceKeyNames[sourceKey] ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 10, color: AppColors.primary),
      ),
    );
  }

  Widget _buildTypeChips() {
    final type = ref.watch(searchProvider.select((s) => s.searchType));
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH - 4),
        children: [
          for (final t in SearchType.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => ref.read(searchProvider.notifier).setSearchType(t),
                child: GlassPanel(
                  blur: 10,
                  borderRadius: 20,
                  tintColor: type == t
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.surfaceLight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: type == t
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──── 专辑/歌手/歌单结果网格 ────

  Widget _buildMediaGrid(List<Song> songs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _MediaCard(song: song, onTap: () => _onMediaTap(song));
        },
      ),
    );
  }

  /// 点击专辑/歌手/歌单卡片 → 用其名称搜索歌曲（lx 标准契约不提供实体歌曲列表，回退为单曲搜索）
  void _onMediaTap(Song song) {
    final notifier = ref.read(searchProvider.notifier);
    final type = ref.read(searchProvider).searchType;
    final keyword = switch (type) {
      SearchType.artist => song.name,
      SearchType.album =>
        song.artist.isNotEmpty ? '${song.name} ${song.artist}' : song.name,
      SearchType.playlist => song.name,
      _ => song.name,
    };
    _searchController.text = keyword;
    notifier.search(keyword.trim(), type: SearchType.song);
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

/// 专辑/歌手/歌单搜索结果卡片
class _MediaCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _MediaCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = song.artist.isNotEmpty
        ? song.artist
        : (song.album?.isNotEmpty == true ? song.album! : '');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（自适应宽高比 1:1）
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: song.albumCover != null && song.albumCover!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: song.albumCover!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _placeholder(),
                      errorWidget: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.accentPurple.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: AppColors.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}
