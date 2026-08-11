import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/list_provider.dart';
import '../../music_source/models/music_track.dart';
import '../../music_source/models/music_list.dart';
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
  void initState() {
    super.initState();
    // 首次进入预加载排行榜（内置源官方接口，无需搜索）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listsProvider.notifier).refresh();
    });
  }

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
    final listsState = ref.watch(listsProvider);
    final sourceNotifier = ref.read(sourceListProvider.notifier);
    final engineReady = sourceNotifier.isEngineReady;
    final engineLoading = sourceNotifier.readyState == SourceReadyState.loading;
    final engineError = sourceNotifier.readyError;

    return CustomScrollView(
      slivers: [
        // 大标题
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              60.w,
              AppSizes.paddingH,
              12.w,
            ),
            child: Text(
              '搜索',
              style: TextStyle(
                fontSize: 34.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              0,
              AppSizes.paddingH,
              12.w,
            ),
            child: GlassPanel(
              blur: 12,
              borderRadius: 20,
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
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

        // 排行榜（未搜索时展示；内置源官方接口，无需登录/第三方音源）
        if (!searchState.hasSearched) ..._buildTopListSlivers(listsState),

        // 音源状态提示
        if (engineLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.accentBlue.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20.w, height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '音源引擎初始化中...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
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
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.error.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '引擎错误: $engineError',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
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
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '请先在设置中导入音源',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
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
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.error.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '所有音源已禁用，请在设置中启用至少一个音源',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
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
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 8.w),
              child: GlassPanel(
                blur: 10,
                borderRadius: 14,
                tintColor: AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          searchState.error!,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp, height: 1.4),
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
                  Icon(Icons.search_off_rounded, size: 64.sp, color: AppColors.textTertiary),
                  SizedBox(height: 16.w),
                  Text(
                    '未找到相关结果',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                    vertical: 3.w,
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.w),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32.w,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isPlaying ? AppColors.primary : AppColors.textTertiary,
                              ),
                            ),
                          ),
                          AlbumArt(
                            coverUrl: song.albumCover,
                            size: 44.w,
                            borderRadius: 12,
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
                                fontSize: 15.sp,
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
                          fontSize: 13.sp,
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

        SliverToBoxAdapter(child: SizedBox(height: 120.w)),
      ],
    );
  }

  // ──── 排行榜区块（搜索页顶部，未搜索时展示）────

  /// 排行榜：聚合所有启用音源的官方榜单，两列网格上下滑动
  List<Widget> _buildTopListSlivers(ListsState state) {
    // 每个来源取前 8 个，多来源交错展示（避免单一来源刷屏）
    final all = <MusicListInfo>[];
    for (final s in state.sections) {
      all.addAll(s.lists.take(8));
    }

    return [
      // 标题行
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.paddingH,
            20.w,
            AppSizes.paddingH,
            12.w,
          ),
          child: Row(
            children: [
              Text(
                '排行榜',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (state.isLoading)
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => ref.read(listsProvider.notifier).refresh(),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: () => context.push('/lists'),
                child: Text(
                  '查看全部',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
      // 空态 / 两列网格
      if (all.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
            child: GlassPanel(
              blur: 10,
              borderRadius: 14,
              tintColor: AppColors.surfaceLight,
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  children: [
                    Icon(
                      Icons.leaderboard_outlined,
                      color: AppColors.textTertiary,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        state.error ?? '暂无榜单数据，请稍后重试',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(listsProvider.notifier).refresh(),
                      child: Text(
                        '重试',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.paddingH,
            0,
            AppSizes.paddingH,
            24.w,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10.w,
              crossAxisSpacing: 16.w,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final info = all[index];
                return _TopListCard(
                  info: info,
                  onTap: () => context.push('/list-detail', extra: info),
                );
              },
              childCount: all.length,
            ),
          ),
        ),
    ];
  }

  // ──── 搜索类型切换 ────

  /// 平台徽标（搜索结果标注音源）
  Widget _platformBadge(String? sourceKey) {
    final name = sourceKey == null ? '' : kSourceKeyNames[sourceKey] ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(right: 6.w),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 10.sp, color: AppColors.primary),
      ),
    );
  }

  Widget _buildTypeChips() {
    final type = ref.watch(searchProvider.select((s) => s.searchType));
    return SizedBox(
      height: 40.w,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH - 4.w),
        children: [
          for (final t in SearchType.values)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: GestureDetector(
                onTap: () => ref.read(searchProvider.notifier).setSearchType(t),
                child: GlassPanel(
                  blur: 10,
                  borderRadius: 20,
                  tintColor: type == t
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.surfaceLight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13.sp,
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
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16.w,
          crossAxisSpacing: 12.w,
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingH,
        vertical: 4.w,
      ),
      child: GlassPanel(
        blur: 8,
        borderRadius: 12,
        tintColor: AppColors.error.withValues(alpha: 0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16.sp,
                color: AppColors.error,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${failedSources.join('、')} 搜索失败',
                  style: TextStyle(
                    fontSize: 12.sp,
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
            borderRadius: BorderRadius.circular(14),
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
          SizedBox(height: 6.w),
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
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
      child: Center(
        child: Icon(
          Icons.album_rounded,
          color: AppColors.textTertiary,
          size: 32.sp,
        ),
      ),
    );
  }
}

/// 搜索页排行榜卡片（两列网格）
class _TopListCard extends StatelessWidget {
  final MusicListInfo info;
  final VoidCallback onTap;

  const _TopListCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sourceName = kSourceKeyNames[info.sourceKey] ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（网格全宽 1:1）
          GlassPanel(
            blur: 10,
            borderRadius: 20,
            tintColor: AppColors.surfaceLight,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (info.picUrl != null && info.picUrl!.isNotEmpty)
                      Image.network(
                        info.picUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _coverPlaceholder(),
                      )
                    else
                      _coverPlaceholder(),
                    // 平台徽标
                    if (sourceName.isNotEmpty)
                      Positioned(
                        left: 8.w,
                        top: 8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.w),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sourceName,
                            style: TextStyle(
                                fontSize: 10.sp, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 6.w),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              info.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.accentPurple.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.leaderboard_rounded,
          color: AppColors.textSecondary,
          size: 36.sp,
        ),
      ),
    );
  }
}
