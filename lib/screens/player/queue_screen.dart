import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/player_provider.dart';
import '../../widgets/album_art.dart';

/// 播放队列管理页
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.w, AppSizes.paddingH, 8.w),
              child: Row(
                children: [
                  GlassPanel(
                    blur: 8,
                    circle: true,
                    tintColor: AppColors.surfaceLight,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18.sp),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '播放队列 (${queue.length})',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            SizedBox(height: 8.w),
            // 当前播放高亮区
            if (playerState.currentSong != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
                child: GlassPanel(
                  blur: 14,
                  borderRadius: 16,
                  tintColor: AppColors.primary.withValues(alpha: 0.15),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.w),
                    leading: AlbumArt(
                      coverUrl: playerState.currentSong!.albumCover,
                      size: 44.w,
                      borderRadius: 12,
                      isPlaying: playerState.isPlaying,
                    ),
                    title: Text(
                      playerState.currentSong!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    subtitle: Text(
                      playerState.currentSong!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
                    ),
                    trailing: Icon(
                      playerState.isPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSizes.paddingH, 16.w, AppSizes.paddingH, 8.w),
              child: Row(
                children: [
                  Text(
                    '接下来',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${queue.length - playerState.currentIndex - 1} 首',
                    style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // 队列列表（可拖拽排序）
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded, size: 64.sp, color: AppColors.textTertiary.withValues(alpha: 0.3)),
                          SizedBox(height: 16.w),
                          Text('队列为空', style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp)),
                        ],
                      ),
                    )
                  : Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.only(bottom: 20.w),
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) {
                          HapticFeedback.lightImpact();
                          ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              final animValue = Curves.easeInOut.transform(animation.value);
                              return Transform.scale(
                                scale: 1.0 + animValue * 0.04,
                                child: Opacity(opacity: 0.85 + animValue * 0.15, child: child),
                              );
                            },
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          final isCurrent = index == playerState.currentIndex;

                          return Dismissible(
                            key: ValueKey('queue_${song.dedupeKey}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 24.w),
                              margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 3.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.red.withValues(alpha: 0.8),
                              ),
                              child: Icon(Icons.delete_rounded, color: Colors.white, size: 24.sp),
                            ),
                            onDismissed: (_) {
                              ref.read(playerProvider.notifier).removeFromQueue(index);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH, vertical: 3.w),
                              child: GlassPanel(
                                blur: 8,
                                borderRadius: 16,
                                tintColor: isCurrent
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surfaceLight,
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.w),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.drag_handle_rounded, color: AppColors.textTertiary, size: 20.sp),
                                      SizedBox(width: 8.w),
                                      AlbumArt(
                                        coverUrl: song.albumCover,
                                        size: 44.w,
                                        borderRadius: 12,
                                        isPlaying: isCurrent,
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    song.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                      color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 20.sp),
                                    onPressed: () {
                                      ref.read(playerProvider.notifier).removeFromQueue(index);
                                    },
                                  ),
                                  onTap: isCurrent
                                      ? null
                                      : () {
                                          // 点击切到该歌曲
                                          ref.read(playerProvider.notifier).play(song, queue: queue);
                                        },
                                ),
                              ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
