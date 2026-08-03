import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/album_art.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/song_context_menu.dart';
import '../core/track_adapter.dart';
import '../models/music_list.dart';
import '../models/music_track.dart';
import '../providers/music_source_provider.dart';

/// 榜单详情 — 展示榜单歌曲列表（lx-music listDetail 动作）
class ListDetailScreen extends ConsumerStatefulWidget {
  final MusicListInfo listInfo;

  const ListDetailScreen({super.key, required this.listInfo});

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  late Future<List<MusicTrack>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<List<MusicTrack>> _loadDetail() async {
    final backend = await ref
        .read(sourceListProvider.notifier)
        .getBackend(widget.listInfo.sourceId);
    if (backend == null) return [];
    return backend.listDetail(widget.listInfo, limit: 50);
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
        child: FutureBuilder<List<MusicTrack>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final tracks = snapshot.data ?? [];
            final songs = TrackAdapter.toLegacySongs(tracks);

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: tracks.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无歌曲数据',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _buildSongList(tracks, songs),
                ),
              ],
            );
          },
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
            borderRadius: 20,
            tintColor: AppColors.surfaceLight,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 18),
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

  Widget _buildSongList(List<MusicTrack> tracks, List<Song> songs) {
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: songs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // 头部大封面 + 播放全部
          return _buildHero(tracks);
        }
        final song = songs[index - 1];
        final isPlaying = currentSong?.dedupeKey == song.dedupeKey;

        return GestureDetector(
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
                  borderRadius: 8,
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
      padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 16, AppSizes.paddingH, 20),
      child: Row(
        children: [
          GlassPanel(
            blur: 12,
            borderRadius: 16,
            tintColor: AppColors.surfaceLight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.listInfo.picUrl != null && widget.listInfo.picUrl!.isNotEmpty
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
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _playAll(tracks),
                  child: GlassPanel(
                    blur: 10,
                    borderRadius: 12,
                    tintColor: AppColors.primary.withValues(alpha: 0.25),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
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
        child: Icon(Icons.leaderboard_rounded,
            color: AppColors.textSecondary, size: 36),
      ),
    );
  }
}
