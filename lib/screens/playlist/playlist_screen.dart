import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/album_art.dart';
import '../../widgets/song_context_menu.dart';

/// 歌单详情页
class PlaylistScreen extends ConsumerWidget {
  final String playlistId;
  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    final playerState = ref.watch(playerProvider);

    if (playlist == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: Text('歌单不存在', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                playlist.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.backgroundDark],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.queue_music_rounded, size: 64, color: Colors.white70),
                      const SizedBox(height: 8),
                      Text('${playlist.songCount} 首歌曲', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 操作栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 12),
              child: Row(
                children: [
                  GlassPanel(
                    blur: 10,
                    borderRadius: 12,
                    tintColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: GestureDetector(
                        onTap: playlist.songs.isNotEmpty
                            ? () => ref.read(playerProvider.notifier).playPlaylist(playlist.songs)
                            : null,
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
          if (playlist.songs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('歌单为空', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = playlist.songs[index];
                  final isPlaying = playerState.currentSong?.dedupeKey == song.dedupeKey;

                  return Dismissible(
                    key: ValueKey('playlist_${playlist.id}_${song.dedupeKey}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: GlassPanel(
                            blur: 20,
                            borderRadius: 20,
                            tintColor: AppColors.surfaceDark,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('从「${playlist.name}」中移除？', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const SizedBox(height: 8),
                                  Text('${song.name} - ${song.artist}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                                      const SizedBox(width: 12),
                                      GlassPanel(
                                        blur: 10,
                                        borderRadius: 12,
                                        tintColor: Colors.red.withValues(alpha: 0.3),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          child: GestureDetector(
                                            onTap: () => Navigator.pop(ctx, true),
                                            child: const Text('移除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onDismissed: (_) {
                      ref.read(playlistProvider.notifier).removeSongFromPlaylist(playlistId, song);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 3),
                      child: GlassPanel(
                        blur: 8,
                        borderRadius: 14,
                        tintColor: isPlaying ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
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
                                  style: TextStyle(fontSize: 14, color: isPlaying ? AppColors.primary : AppColors.textTertiary),
                                ),
                              ),
                              AlbumArt(coverUrl: song.albumCover, size: 44, borderRadius: 8, isPlaying: isPlaying),
                            ],
                          ),
                          title: Text(
                            song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isPlaying ? AppColors.primary : AppColors.textPrimary),
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
                            ref.read(playerProvider.notifier).playPlaylist(playlist.songs, startIndex: index);
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            showSongContextMenu(context, ref, song);
                          },
                        ),
                      ),
                      ),
                    ),
                  );
                },
                childCount: playlist.songs.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}