import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/lyric.dart';
import '../../providers/player_provider.dart'
    show PlayerState, MusicRepeatMode, playerProvider;
import '../../providers/favorites_provider.dart';
import '../../widgets/album_art.dart';
import 'queue_screen.dart';

/// 全屏播放器 — 液态玻璃风格
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastHighlightIndex = -1;
  bool _isDraggingSeekBar = false;
  double _dragValue = 0;
  String? _lastDisplayedError;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  /// 显示播放错误提示
  void _showPlaybackError(String error) {
    if (_lastDisplayedError == error) return; // 避免重复显示相同错误
    _lastDisplayedError = error;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(error, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '知道了',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 自动滚动歌词到当前行
  void _scrollToCurrentLine(int index) {
    if (index == _lastHighlightIndex) return;
    _lastHighlightIndex = index;
    if (!_lyricsScrollController.hasClients) return;
    final targetOffset = (index * 40.0) - 120.0;
    _lyricsScrollController.animateTo(
      targetOffset.clamp(
          0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final isFavorited = playerState.currentSong != null
        ? ref
            .watch(favoritesProvider.notifier)
            .isFavorite(playerState.currentSong!)
        : false;

    // 检测播放错误并显示 SnackBar
    if (playerState.playbackError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPlaybackError(playerState.playbackError!);
      });
    } else {
      _lastDisplayedError = null; // 错误清除后允许再次显示
    }

    // 歌词滚动同步
    if (playerState.showLyrics && playerState.lyricLines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentLine(playerState.currentLyricIndex);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          _buildBackground(playerState),
          SafeArea(
            child: Column(
              children: [
                // 顶栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingH),
                  child: _buildTopBar(),
                ),

                // 播放错误提示（内联）
                if (playerState.playbackError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSizes.paddingH, 8, AppSizes.paddingH, 0),
                    child: _buildPlaybackErrorBanner(playerState.playbackError!),
                  ),
                const SizedBox(height: 12),

                // 中间内容：专辑封面或歌词
                Expanded(child: _buildCenterContent(playerState)),

                // 歌曲信息（非歌词模式下显示）
                if (!playerState.showLyrics) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingH),
                    child: _buildSongInfo(playerState),
                  ),
                  const SizedBox(height: 20),
                ],

                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingH),
                  child: _buildProgressBar(playerState),
                ),
                const SizedBox(height: 8),

                // 控制按钮
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingH),
                  child: _buildControls(playerState),
                ),
                const SizedBox(height: 16),

                // 底部功能按钮
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingH),
                  child: _buildBottomActions(isFavorited, playerState),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(PlayerState state) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            state.currentSong != null
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.backgroundDark,
            AppColors.backgroundDark,
            AppColors.backgroundDark,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        Text(
          '正在播放',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, size: 28),
          color: AppColors.textPrimary,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildAlbumArt(PlayerState state) {
    final isCompact = state.showLyrics && state.lyricLines.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = isCompact ? screenWidth * 0.32 : screenWidth * 0.6;
    final radius = isCompact ? 14.0 : 24.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: GlassPanel(
        key: ValueKey(state.currentSong?.dedupeKey),
        blur: 16,
        borderRadius: radius,
        tintColor: AppColors.surfaceLight,
        child: AlbumArt(
          coverUrl: state.currentSong?.albumCover,
          size: artSize,
          isPlaying: state.isPlaying,
          borderRadius: radius,
        ),
      ),
    );
  }

  /// 中间内容区域：专辑封面 或 歌词
  Widget _buildCenterContent(PlayerState state) {
    final showLyrics = state.showLyrics && state.lyricLines.isNotEmpty;

    if (showLyrics) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAlbumArt(state),
          const SizedBox(height: 12),
          _buildSongInfo(state),
          const SizedBox(height: 4),
          _buildLyricsView(state),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Spacer(flex: 2),
        _buildAlbumArt(state),
        const Spacer(flex: 2),
      ],
    );
  }

  /// 歌词视图 — 双语 + 逐字进度填充
  Widget _buildLyricsView(PlayerState state) {
    if (state.lyricLines.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 36,
                color: AppColors.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                '暂无歌词',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundDark,
              Colors.transparent,
              Colors.transparent,
              AppColors.backgroundDark,
            ],
            stops: const [0.0, 0.12, 0.88, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          itemCount: state.lyricLines.length,
          itemBuilder: (context, index) {
            final line = state.lyricLines[index];
            final isActive = index == state.currentLyricIndex;
            final past = index < state.currentLyricIndex;

            final textColor = isActive
                ? AppColors.textPrimary
                : past
                    ? AppColors.textTertiary
                    : AppColors.textTertiary.withValues(alpha: 0.4);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  // 主歌词行 — 逐字填充效果
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 350),
                    style: TextStyle(
                      fontSize: isActive ? 20 : 15,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: Colors.transparent,
                      height: 1.6,
                    ),
                    child: isActive && line.wordTimings != null && line.wordTimings!.isNotEmpty
                        ? _buildWordProgressLine(line, state.position, textColor)
                        : isActive
                            ? _buildProgressFillLine(line.text, line.progressAt(state.position), textColor, pastColor: AppColors.textTertiary.withValues(alpha: 0.4))
                            : Text(line.text, textAlign: TextAlign.center, style: TextStyle(color: textColor)),
                  ),
                  // 翻译行
                  if (line.translation != null && line.translation!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 350),
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight: FontWeight.normal,
                          color: isActive
                              ? AppColors.textSecondary
                              : AppColors.textTertiary.withValues(alpha: past ? 0.3 : 0.2),
                          height: 1.4,
                        ),
                        child: Text(
                          line.translation!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 逐字进度填充（有逐字时间标记）
  Widget _buildWordProgressLine(LyricLine line, Duration position, Color activeColor) {
    final timings = line.wordTimings!;
    final children = <InlineSpan>[];

    for (final wt in timings) {
      final wordProgress = position >= wt.end
          ? 1.0
          : position > wt.start
              ? ((position - wt.start).inMilliseconds / (wt.end - wt.start).inMilliseconds).clamp(0.0, 1.0)
              : 0.0;

      children.add(WidgetSpan(
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [activeColor, activeColor, AppColors.textTertiary.withValues(alpha: 0.4)],
            stops: [0.0, wordProgress, wordProgress + 0.001],
          ).createShader(bounds),
          child: Text(
            wt.word,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.6),
          ),
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: children),
      textAlign: TextAlign.center,
    );
  }

  /// 进度填充行（无逐字时间时使用）
  Widget _buildProgressFillLine(String text, double progress, Color activeColor, {Color? pastColor}) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [activeColor, activeColor, pastColor ?? activeColor],
        stops: [0.0, progress, progress + 0.001],
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSongInfo(PlayerState state) {
    final song = state.currentSong;
    return Column(
      children: [
        Text(
          song?.name ?? '未在播放',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          song?.artist ?? '选择一首歌开始播放',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar(PlayerState state) {
    final maxMs = state.duration.inMilliseconds.toDouble().clamp(1, double.infinity);
    final currentMs = _isDraggingSeekBar
        ? _dragValue * maxMs
        : state.position.inMilliseconds.toDouble().clamp(0, maxMs);
    final progress = maxMs > 0 ? (currentMs / maxMs).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (details) {
                  final dx = details.localPosition.dx.clamp(0.0, trackWidth);
                  setState(() {
                    _isDraggingSeekBar = true;
                    _dragValue = dx / trackWidth;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  final dx = details.localPosition.dx.clamp(0.0, trackWidth);
                  setState(() {
                    _dragValue = dx / trackWidth;
                  });
                },
                onHorizontalDragEnd: (_) {
                  final seekMs = (_dragValue * maxMs).toInt();
                  ref.read(playerProvider.notifier).seek(Duration(milliseconds: seekMs));
                  setState(() {
                    _isDraggingSeekBar = false;
                  });
                },
                onTapUp: (details) {
                  final dx = details.localPosition.dx.clamp(0.0, trackWidth);
                  final seekMs = ((dx / trackWidth) * maxMs).toInt();
                  ref.read(playerProvider.notifier).seek(Duration(milliseconds: seekMs));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: _isDraggingSeekBar ? 44 : 28,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // background track
                      Container(
                        height: _isDraggingSeekBar ? 8 : 3,
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // filled track
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: _isDraggingSeekBar ? 8 : 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // thumb
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isDraggingSeekBar ? 22 : 14,
                            height: _isDraggingSeekBar ? 22 : 14,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: _isDraggingSeekBar
                                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDurationMs(currentMs.toInt()),
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              Text(
                _formatDuration(state.duration),
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(PlayerState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 随机播放
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: state.shuffleMode ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
        ),
        // 上一首
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
          color: AppColors.textPrimary,
          onPressed: () => ref.read(playerProvider.notifier).previous(),
        ),
        // 播放/暂停
        GlassPanel(
          blur: 12,
          borderRadius: 30,
          tintColor: AppColors.primary.withValues(alpha: 0.8),
          child: GestureDetector(
            onTap: () => ref.read(playerProvider.notifier).togglePlay(),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        // 下一首
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 36),
          color: AppColors.textPrimary,
          onPressed: () => ref.read(playerProvider.notifier).next(),
        ),
        // 循环模式
        IconButton(
          icon: Icon(
            _getRepeatIcon(state.repeatMode),
            color: state.repeatMode != MusicRepeatMode.off
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          onPressed: () => ref.read(playerProvider.notifier).toggleRepeat(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(bool isFavorited, PlayerState playerState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(
            isFavorited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: isFavorited ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          onPressed: () {
            final song = ref.read(playerProvider).currentSong;
            if (song != null) {
              ref.read(favoritesProvider.notifier).toggleFavorite(song);
            }
          },
        ),
        // 歌词切换
        IconButton(
          icon: Icon(
            Icons.lyrics_outlined,
            size: 24,
            color: playerState.showLyrics
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          onPressed: () =>
              ref.read(playerProvider.notifier).toggleLyrics(),
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play_rounded, size: 24),
          color: AppColors.textSecondary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String _formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  IconData _getRepeatIcon(MusicRepeatMode mode) {
    switch (mode) {
      case MusicRepeatMode.off:
        return Icons.repeat_rounded;
      case MusicRepeatMode.all:
        return Icons.repeat_rounded;
      case MusicRepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  /// 内联播放错误横幅
  Widget _buildPlaybackErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
