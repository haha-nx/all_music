import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/album_art.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/liquid_bottom_bar.dart';
import '../../../widgets/song_context_menu.dart';
import '../core/track_adapter.dart';
import '../models/music_list.dart';
import '../models/music_track.dart';
import '../core/music_backend.dart';
import '../providers/music_source_provider.dart';

/// 榜单详情 — 展示榜单歌曲列表（lx-music listDetail 动作）
class ListDetailScreen extends ConsumerStatefulWidget {
  final MusicListInfo listInfo;

  const ListDetailScreen({super.key, required this.listInfo});

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  static const _pageSize = 100;

  final _tracks = <MusicTrack>[];
  final _scrollController = ScrollController();
  MusicBackend? _backend;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _backend = await ref
        .read(sourceListProvider.notifier)
        .getBackend(widget.listInfo.sourceId);
    await _loadPage();
    if (mounted) setState(() => _initialLoading = false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadPage();
    }
  }

  /// 分页加载：每页 [_pageSize] 首，滚动到底自动加载下一页
  Future<void> _loadPage() async {
    if (_loadingMore || !_hasMore || _backend == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _backend!.listDetail(
        widget.listInfo,
        page: _page,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (page.isEmpty) {
          _hasMore = false;
        } else {
          _tracks.addAll(page);
          _page++;
          if (page.length < _pageSize) _hasMore = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _hasMore = false;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _playAll(List<MusicTrack> tracks) {
    if (tracks.isEmpty) return;
    final songs = TrackAdapter.toLegacySongs(tracks);
    ref.read(playerProvider.notifier).playPlaylist(songs);
  }

  void _playAt(List<MusicTrack> tracks, int index) {
    if (tracks.isEmpty) return;
    final songs = TrackAdapter.toLegacySongs(tracks);
    ref.read(playerProvider.notifier).playPlaylist(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _initialLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _tracks.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无歌曲数据',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _buildSongList(_tracks),
                ),
              ],
            ),
            // 底部播放胶囊（无歌曲时自动隐藏）
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlayerCapsuleBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, AppSizes.paddingH, 8),
      child: Row(
        children: [
          GlassPanel(
            blur: 8,
            borderRadius: 24,
            tintColor: AppColors.surfaceLight,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          Text(
            widget.listInfo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSongList(List<MusicTrack> tracks) {
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));
    final songs = TrackAdapter.toLegacySongs(tracks);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: songs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          // 头部大封面 + 播放全部
          return _buildHero(tracks);
        }
        if (index == songs.length + 1) {
          // 底部加载状态：加载中 / 到底
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Text(
                      _error != null
                          ? '加载失败：$_error'
                          : _hasMore
                          ? '上拉加载更多'
                          : '已显示全部 ${songs.length} 首',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
            ),
          );
        }
        final song = songs[index - 1];
        final isPlaying = currentSong?.dedupeKey == song.dedupeKey;

        return GestureDetector(
          behavior: HitTestBehavior.opaque, // 整行任意位置可点（含行内空隙）
          onTap: () => _playAt(tracks, index - 1),
          onLongPress: () => showSongContextMenu(context, ref, song),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingH,
              vertical: 6,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isPlaying
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AlbumArt(
                  coverUrl: song.albumCover,
                  size: 44,
                  borderRadius: 12,
                  isPlaying: isPlaying,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isPlaying
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showSongContextMenu(context, ref, song),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(List<MusicTrack> tracks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingH,
        16,
        AppSizes.paddingH,
        20,
      ),
      child: Row(
        children: [
          GlassPanel(
            blur: 12,
            borderRadius: 20,
            tintColor: AppColors.surfaceLight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child:
                  widget.listInfo.picUrl != null &&
                      widget.listInfo.picUrl!.isNotEmpty
                  ? Image.network(
                      widget.listInfo.picUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.listInfo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.listInfo.countText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _playAll(tracks),
                  child: GlassPanel(
                    blur: 10,
                    borderRadius: 20,
                    tintColor: AppColors.primary.withValues(alpha: 0.25),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '播放全部',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 120,
      height: 120,
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
      child: const Center(
        child: Icon(
          Icons.leaderboard_rounded,
          color: AppColors.textSecondary,
          size: 36,
        ),
      ),
    );
  }
}
