import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../config/constants.dart';
import '../models/song.dart';
import '../providers/favorites_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../music_source/core/track_adapter.dart';
import '../music_source/providers/music_source_provider.dart';
import 'album_art.dart';

/// 歌曲操作菜单 - 长按或更多操作时弹出
void showSongContextMenu(BuildContext context, WidgetRef ref, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SongContextMenu(song: song),
  );
}

class SongContextMenu extends ConsumerWidget {
  final Song song;
  const SongContextMenu({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorited = ref.watch(favoritesProvider.notifier).isFavorite(song);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Container(
              width: 36.w,
              height: 4.w,
              margin: EdgeInsets.only(top: 8.w, bottom: 16.w),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 歌曲信息头
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  AlbumArt(
                    coverUrl: song.albumCover,
                    size: 48.w,
                    borderRadius: 12,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.w),
            Divider(
              color: AppColors.textTertiary.withValues(alpha: 0.2),
              height: 1,
            ),
            SizedBox(height: 4.w),

            // 操作列表
            _MenuItem(
              icon: Icons.queue_play_next,
              title: '下一首播放',
              onTap: () {
                ref.read(playerProvider.notifier).playNext(song);
                // 先取 messenger，pop 后 context 不可再用
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('已添加到下一首播放'),
                    backgroundColor: AppColors.surfaceDark,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            _MenuItem(
              icon: isFavorited
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              title: isFavorited ? '取消收藏' : '收藏',
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(song);
                Navigator.pop(context);
              },
            ),
            _MenuItem(
              icon: Icons.download_rounded,
              title: '下载',
              onTap: () {
                Navigator.pop(context);
                _download(context, ref, song);
              },
            ),
            _MenuItem(
              icon: Icons.playlist_add_rounded,
              title: '添加到歌单',
              onTap: () {
                Navigator.pop(context);
                _showPlaylistPicker(context, ref, song);
              },
            ),
            SizedBox(height: 8.w),
          ],
        ),
      ),
    );
  }

  /// 下载歌曲：按默认音质获取播放地址后加入下载队列
  Future<void> _download(BuildContext context, WidgetRef ref, Song song) async {
    final messenger = ScaffoldMessenger.of(context);
    final quality = ref.read(settingsProvider).defaultQuality;

    if (song.sourceId == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('本地歌曲无需下载'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text('正在获取「${song.name}」播放地址...'),
      backgroundColor: AppColors.surfaceDark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));

    try {
      final track = TrackAdapter.fromLegacySong(song);
      final sourceNotifier = ref.read(sourceListProvider.notifier);
      final tryOrder = <String>[
        if (song.sourceId != null) song.sourceId!,
        ...sourceNotifier.enabledSources.map((s) => s.id),
      ];

      String? url;
      final tried = <String>{};
      for (final sourceId in tryOrder) {
        if (!tried.add(sourceId)) continue;
        final backend = await sourceNotifier.getBackend(sourceId);
        if (backend == null) continue;
        final result = await backend.getMusicUrl(track, quality: quality);
        if (result != null && result.isNotEmpty) {
          url = result;
          break;
        }
      }
      if (url == null || url.isEmpty) throw Exception('获取播放地址失败');

      ref.read(downloadProvider.notifier).addAndStart(
            track,
            url,
            quality: quality,
          );
      messenger.showSnackBar(SnackBar(
        content: Text('已开始下载：${song.name}'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('下载失败：$e'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showPlaylistPicker(BuildContext context, WidgetRef ref, Song song) {
    final playlists = ref.read(playlistProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.w,
                margin: EdgeInsets.only(top: 8.w, bottom: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.w, 20.w, 8.w),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '添加到歌单',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (playlists.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    '暂无歌单，请先创建一个',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      final alreadyIn = playlist.songs.any(
                        (s) => s.dedupeKey == song.dedupeKey,
                      );
                      return ListTile(
                        leading: Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            alreadyIn
                                ? Icons.check_rounded
                                : Icons.queue_music_rounded,
                            color: alreadyIn
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20.sp,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(
                            color: alreadyIn
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${playlist.songCount} 首',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12.sp,
                          ),
                        ),
                        onTap: alreadyIn
                            ? null
                            : () {
                                ref
                                    .read(playlistProvider.notifier)
                                    .addSongToPlaylist(playlist.id, song);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已添加到 ${playlist.name}'),
                                    backgroundColor: AppColors.surfaceDark,
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                      );
                    },
                  ),
                ),
              SizedBox(height: 8.w),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary, size: 22.sp),
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15.sp),
      ),
      onTap: onTap,
    );
  }
}
