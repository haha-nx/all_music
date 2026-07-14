import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/song.dart';
import '../providers/favorites_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 歌曲信息头
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AlbumArt(
                    coverUrl: song.albumCover,
                    size: 48,
                    borderRadius: 8,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(
              color: AppColors.textTertiary.withValues(alpha: 0.2),
              height: 1,
            ),
            const SizedBox(height: 4),

            // 操作列表
            _MenuItem(
              icon: Icons.queue_play_next,
              title: '下一首播放',
              onTap: () {
                ref.read(playerProvider.notifier).playNext(song);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已添加到下一首播放'),
                    backgroundColor: AppColors.surfaceDark,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
              icon: Icons.playlist_add_rounded,
              title: '添加到歌单',
              onTap: () {
                Navigator.pop(context);
                _showPlaylistPicker(context, ref, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '添加到歌单',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            alreadyIn
                                ? Icons.check_rounded
                                : Icons.queue_music_rounded,
                            color: alreadyIn
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
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
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
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
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
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
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}
