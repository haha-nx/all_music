import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import 'glass_panel.dart';
import 'album_art.dart';

/// 液态玻璃底部导航栏 — Apple Music 风格三区布局
/// 左：音乐库圆形按钮 | 中：播放胶囊 | 右：搜索圆形按钮
class LiquidBottomBar extends ConsumerWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const LiquidBottomBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerData = ref.watch(
      playerProvider.select(
        (s) => (song: s.currentSong, isPlaying: s.isPlaying),
      ),
    );
    final song = playerData.song;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 24.w),
      child: SizedBox(
        height: 60.w,
        child: Row(
          children: [
            // ======== 左：音乐库圆形按钮 ========
            _CircleNavButton(
              icon: Icons.library_music_rounded,
              isSelected: selectedTab == 0,
              onTap: () => onTabChanged(0),
            ),
            SizedBox(width: 16.w),
            // ======== 中：播放胶囊 / 空状态 ========
            Expanded(
              child: song != null
                  ? _PlayerCapsule(
                      song: song,
                      isPlaying: playerData.isPlaying,
                      onTogglePlay: () =>
                          ref.read(playerProvider.notifier).togglePlay(),
                      onTap: () => context.push('/player'),
                    )
                  : _EmptyCapsule(),
            ),
            SizedBox(width: 16.w),
            // ======== 右：搜索圆形按钮 ========
            _CircleNavButton(
              icon: Icons.search_rounded,
              isSelected: selectedTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 独立播放胶囊 — 用于歌单/排行榜等没有底部导航栏的页面
///
/// 与 LiquidBottomBar 中间的播放胶囊样式一致；无歌曲时不占位。
class PlayerCapsuleBar extends ConsumerWidget {
  const PlayerCapsuleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      playerProvider.select(
        (s) => (song: s.currentSong, isPlaying: s.isPlaying),
      ),
    );
    final song = data.song;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.w),
      child: _PlayerCapsule(
        song: song,
        isPlaying: data.isPlaying,
        onTogglePlay: () => ref.read(playerProvider.notifier).togglePlay(),
        onTap: () => context.push('/player'),
      ),
    );
  }
}

/// 圆形导航按钮（与播放胶囊一致的液态玻璃模糊）
class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CircleNavButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 12,
      circle: true,
      tintColor: AppColors.surfaceLight,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 60.w,
          height: 60.w,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            icon,
            size: 22.sp,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 播放胶囊 — 封面 + 歌名/歌手 + 播放暂停
class _PlayerCapsule extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onTap;

  const _PlayerCapsule({
    required this.song,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        blur: 12,
        stadium: true,
        tintColor: AppColors.surfaceLight,
        child: Container(
          height: 60.w,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
          child: Row(
            children: [
              // 封面缩略图
              AlbumArt(
                coverUrl: song.albumCover,
                size: 32.w,
                borderRadius: 8,
                isPlaying: isPlaying,
              ),
              SizedBox(width: 10.w),

              // 歌曲信息
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),

              // 播放/暂停按钮
              GestureDetector(
                onTap: () {
                  // 阻止冒泡到父级 GestureDetector
                  onTogglePlay();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPlaying
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
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

/// 空胶囊占位 — 无歌曲时显示
class _EmptyCapsule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 8,
      stadium: true,
      tintColor: AppColors.surfaceLight,
      child: SizedBox(
        height: 60.w,
        child: Center(
          child: Text(
            '选择一首歌开始播放',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}
