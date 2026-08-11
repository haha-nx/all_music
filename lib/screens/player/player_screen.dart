import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/lyric.dart';
import '../../providers/player_provider.dart'
    show PlayerState, MusicRepeatMode, SleepTimerOption, playerProvider;
import '../../providers/cover_theme_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../utils/cover_theme.dart';
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

  /// 歌词首尾留白（半屏左右），保证首末行也能滚动到视口中央
  static const double _lyricsEdgePadding = 160;

  /// 行距（行槽 = 歌词内容高度 + 该值，文字顶对齐）。
  /// 行高随每行激活状态动态伸缩：激活行 32px 大字（可能两行）行高较大，
  /// 播放完变回非激活 22px 小字（一行）行高随之缩小，不会留下空洞；
  /// 行距恒定为该值，长句与短句之间间距一致。
  static const double _lyricsRowGap = 28;

  /// 各行在激活（32px）/非激活（22px）状态下的内容高度缓存，
  /// 行高 = 状态高度 + 行距。同一份歌词 + 同一宽度时复用。
  List<double>? _activeHeights;
  List<double>? _inactiveHeights;
  List<LyricLine>? _heightLines;
  double _heightWidth = 0;

  /// 当前封面提取的主题色（build 时从 coverThemeProvider 刷新）
  CoverTheme? _theme;
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
    if (!mounted) return; // 页面已退出（unmounted）时不再使用 context
    if (_lastDisplayedError == error) return; // 避免重复显示相同错误
    _lastDisplayedError = error;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 计算该行内容在给定基础字号下的自然高度（允许多行换行，跟随系统字体缩放）
  double _contentHeight(LyricLine line, double width, double mainSize, double trSize) {
    final scaler = MediaQuery.textScalerOf(context);
    final mainTp = TextPainter(
      text: TextSpan(
        text: line.text,
        style: TextStyle(fontSize: mainSize, height: 1.4),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    var h = mainTp.height;
    final tr = line.translation;
    if (tr != null && tr.isNotEmpty) {
      final trTp = TextPainter(
        text: TextSpan(
          text: tr,
          style: TextStyle(fontSize: trSize, height: 1.3),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      h += 3 + trTp.height;
    }
    return h;
  }

  /// 歌词行集或可用宽度变化时重建激活/非激活高度缓存
  void _ensureHeightCache(List<LyricLine> lines, double width) {
    if (identical(_heightLines, lines) && _heightWidth == width) return;
    _heightLines = lines;
    _heightWidth = width;
    _activeHeights = [for (final l in lines) _contentHeight(l, width, 32, 14)];
    _inactiveHeights = [
      for (final l in lines) _contentHeight(l, width, 22, 12),
    ];
    // 歌词切换后允许重新滚动定位
    _lastHighlightIndex = -1;
  }

  /// 自动滚动歌词到当前行（当前行精确居中）。
  /// 前序行按非激活高度、当前行按激活高度累加，与渲染保持一致。
  void _scrollToCurrentLine(int index) {
    if (index == _lastHighlightIndex) return;
    _lastHighlightIndex = index;
    if (!_lyricsScrollController.hasClients || _activeHeights == null) return;
    final inact = _inactiveHeights!;
    final act = _activeHeights!;
    if (index < 0 || index >= act.length) return;

    // 目标偏移 = 前序行（非激活高 + 行距）之和 + 当前行激活内容中心 + 首留白 - 视口/2
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += inact[i] + _lyricsRowGap;
    }
    offset += act[index] / 2;
    final viewport = _lyricsScrollController.position.viewportDimension;
    final targetOffset = offset + _lyricsEdgePadding - viewport / 2;
    _lyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    _theme = ref.watch(coverThemeProvider).valueOrNull;
    final playerState = ref.watch(playerProvider);
    final isFavorited = playerState.currentSong != null
        ? ref
              .watch(favoritesProvider.notifier)
              .isFavorite(playerState.currentSong!)
        : false;

    // 检测播放错误并显示 SnackBar
    if (playerState.playbackError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // 页面已退出，跳过
        _showPlaybackError(playerState.playbackError!);
      });
    } else {
      _lastDisplayedError = null; // 错误清除后允许再次显示
    }

    // 歌词滚动同步
    if (playerState.lyricLines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // 页面已退出，跳过
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
                    horizontal: AppSizes.paddingH,
                  ),
                  child: _buildTopBar(playerState),
                ),

                // 播放错误提示（内联）
                if (playerState.playbackError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingH,
                      8,
                      AppSizes.paddingH,
                      0,
                    ),
                    child: _buildPlaybackErrorBanner(
                      playerState.playbackError!,
                    ),
                  ),
                const SizedBox(height: 12),

                // 中间内容：歌曲信息 + 歌词
                Expanded(child: _buildCenterContent(playerState)),

                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                  ),
                  child: _buildProgressBar(playerState),
                ),
                const SizedBox(height: 4),

                // 控制按钮
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                  ),
                  child: _buildControls(playerState),
                ),
                const SizedBox(height: 16),

                // 底部功能按钮
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                  ),
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

  /// 强调色：专辑主题色；无封面/提取失败时回退白色（不再用固定红色）
  Color get _accent => _theme?.dominant ?? Colors.white;

  /// 强调色上的图标/文字色：亮主题 → 黑，暗主题 → 白
  Color get _onAccent => _theme?.onDominant ?? Colors.black;

  /// 弹窗/面板中的选中项颜色
  Color get _selectedColor => _theme?.dominant ?? AppColors.textPrimary;

  /// 未激活控件/辅助文字颜色：按主题色亮度自动选黑/白（歌词页背景为模糊封面）
  Color _inactiveColor(PlayerState s) =>
      _theme?.onDominant ?? AppColors.textPrimary;

  Widget _buildBackground(PlayerState state) {
    final coverUrl = state.currentSong?.albumCover;

    // 歌词页：专辑封面全屏高斯模糊作背景（Apple Music 风格，不直接显示封面）
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Transform.scale(
                scale: 1.2,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppColors.backgroundDark),
                ),
              ),
            ),
          ),
          // 半透明暗色遮罩，保证歌词可读性
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            state.currentSong != null
                ? _accent.withValues(alpha: 0.15)
                : AppColors.backgroundDark,
            AppColors.backgroundDark,
            AppColors.backgroundDark,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerState state) {
    final hasSleep = state.sleepTimerRemaining > Duration.zero;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          color: _inactiveColor(state),
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
        // 右上角菜单：播放速度 / 定时关闭
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            size: 28,
            color: _inactiveColor(state),
          ),
          color: AppColors.surfaceDark,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            switch (value) {
              case 'speed':
                _showSpeedSheet();
              case 'sleep':
                _showSleepTimerSheet();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'speed',
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '播放速度  ${_formatSpeed(state.speed)}x',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sleep',
              child: Row(
                children: [
                  Icon(
                    hasSleep ? Icons.timer_off_rounded : Icons.timer_rounded,
                    size: 18,
                    color: hasSleep ? _selectedColor : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasSleep
                        ? '定时关闭  ${SleepTimerOption.format(state.sleepTimerRemaining)}'
                        : '定时关闭',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasSleep ? _selectedColor : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 中间内容区域：歌曲信息 + 歌词（Apple Music 风格，歌词页即播放页）
  Widget _buildCenterContent(PlayerState state) {
    return Column(
      children: [
        // 左上角：歌曲名 + 歌手
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildSongInfo(state, leftAligned: true),
          ),
        ),
        const SizedBox(height: 4),
        // 歌词占满剩余空间
        Expanded(child: _buildLyricsView(state)),
      ],
    );
  }

  /// 歌词视图 — 双语 + 逐字进度填充
  ///
  /// 动态行高 + 长歌词自动换行；行高按激活态字号计算（各行动态不同，
  /// 不随激活状态抖动），首尾留白保证首末行也能滚动到视口中央。
  Widget _buildLyricsView(PlayerState state) {
    if (state.lyricLines.isEmpty) {
      return Center(
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
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 可用歌词文本宽度（水平 padding 28*2），下限保护避免极端窄屏
        final width =
            (constraints.maxWidth - 56).clamp(40.0, double.infinity).toDouble();
        _ensureHeightCache(state.lyricLines, width);

        return ListView.builder(
          controller: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(
            vertical: _lyricsEdgePadding,
            horizontal: 28,
          ),
          itemCount: state.lyricLines.length,
          itemBuilder: (context, index) {
            final line = state.lyricLines[index];
            final isActive = index == state.currentLyricIndex;
            final past = index < state.currentLyricIndex;
            final distance = (index - state.currentLyricIndex).abs();

            // 行高随激活状态动态伸缩：激活 32px 大字（可能两行）行高较大，
            // 非激活 22px 小字行高随之缩小，不留空洞；行距恒定
            final rowH =
                isActive ? _activeHeights![index] : _inactiveHeights![index];

            final textColor = isActive
                ? AppColors.textPrimary
                : Colors.white.withValues(alpha: past ? 0.45 : 0.6);

            // 行槽 = 状态内容高度 + 固定行距，文字顶对齐
            Widget content = SizedBox(
              height: rowH + _lyricsRowGap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 主歌词行（允许换行，字号随激活状态变化）
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 350),
                    style: TextStyle(
                      fontSize: isActive ? 32 : 22,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                      height: 1.4,
                    ),
                    child: Text(line.text, textAlign: TextAlign.start),
                  ),
                  // 翻译行（允许换行）
                  if (line.translation != null && line.translation!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 350),
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight: FontWeight.normal,
                          color: isActive
                              ? AppColors.textSecondary
                              : Colors.white.withValues(
                                  alpha: past ? 0.35 : 0.45,
                                ),
                          height: 1.3,
                        ),
                        child: Text(
                          line.translation!,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                ],
              ),
            );

            // 非当前行浅浅的高斯模糊（重模糊由背景层负责，歌词层浅即可）
            if (!isActive) {
              final sigma = (0.5 + distance * 0.7).clamp(1.0, 3.0).toDouble();
              content = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: content,
              );
            }

            // 点击歌词行跳转到对应时间
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(playerProvider.notifier).seek(line.time),
              child: content,
            );
          },
        );
      },
    );
  }

  Widget _buildSongInfo(PlayerState state, {bool leftAligned = false}) {
    final song = state.currentSong;
    return Column(
      crossAxisAlignment: leftAligned
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          song?.name ?? '未在播放',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _inactiveColor(state),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: leftAligned ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          song?.artist ?? '选择一首歌开始播放',
          style: TextStyle(
            fontSize: 15,
            color: _inactiveColor(state).withValues(alpha: 0.72),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: leftAligned ? TextAlign.start : TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(PlayerState state) {
    final maxMs = state.duration.inMilliseconds.toDouble().clamp(
      1,
      double.infinity,
    );
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
                  ref
                      .read(playerProvider.notifier)
                      .seek(Duration(milliseconds: seekMs));
                  setState(() {
                    _isDraggingSeekBar = false;
                  });
                },
                onTapUp: (details) {
                  final dx = details.localPosition.dx.clamp(0.0, trackWidth);
                  final seekMs = ((dx / trackWidth) * maxMs).toInt();
                  ref
                      .read(playerProvider.notifier)
                      .seek(Duration(milliseconds: seekMs));
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
                          color: _inactiveColor(state).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // filled track
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: _isDraggingSeekBar ? 8 : 3,
                          decoration: BoxDecoration(
                            color: _accent,
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
                              color: _accent,
                              shape: BoxShape.circle,
                              boxShadow: _isDraggingSeekBar
                                  ? [
                                      BoxShadow(
                                        color: _accent.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
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
                style: TextStyle(
                  fontSize: 12,
                  color: _inactiveColor(state).withValues(alpha: 0.55),
                ),
              ),
              Text(
                _formatDuration(state.duration),
                style: TextStyle(
                  fontSize: 12,
                  color: _inactiveColor(state).withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatSpeed(double speed) {
    return speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _showSpeedSheet() {
    final notifier = ref.read(playerProvider.notifier);
    final current = ref.read(playerProvider).speed;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '播放速度',
        children: [
          for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            ListTile(
              dense: true,
              title: Text(
                '${_formatSpeed(speed)}x',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: (speed - current).abs() < 0.001
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: (speed - current).abs() < 0.001
                      ? _selectedColor
                      : AppColors.textPrimary,
                ),
              ),
              trailing: (speed - current).abs() < 0.001
                  ? Icon(Icons.check_rounded, color: _selectedColor, size: 20)
                  : null,
              onTap: () {
                Navigator.pop(context);
                notifier.setSpeed(speed);
              },
            ),
        ],
      ),
    );
  }

  void _showSleepTimerSheet() {
    final notifier = ref.read(playerProvider.notifier);
    final active = ref.read(playerProvider).sleepTimerRemaining;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '定时关闭',
        children: [
          for (final option in SleepTimerOption.options)
            ListTile(
              dense: true,
              title: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                notifier.setSleepTimer(option.duration);
              },
            ),
          if (active > Duration.zero)
            ListTile(
              dense: true,
              title: const Text(
                '取消定时',
                style: TextStyle(fontSize: 15, color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                notifier.setSleepTimer(null);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildControls(PlayerState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 上一首
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
          color: _inactiveColor(state),
          onPressed: () => ref.read(playerProvider.notifier).previous(),
        ),
        // 播放/暂停
        GlassPanel(
          blur: 12,
          borderRadius: 30,
          tintColor: _accent.withValues(alpha: 0.9),
          child: GestureDetector(
            onTap: () => ref.read(playerProvider.notifier).togglePlay(),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: _onAccent,
                size: 36,
              ),
            ),
          ),
        ),
        // 下一首
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 36),
          color: _inactiveColor(state),
          onPressed: () => ref.read(playerProvider.notifier).next(),
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
            color: isFavorited
                ? _accent
                : _inactiveColor(playerState).withValues(alpha: 0.8),
            size: 24,
          ),
          onPressed: () {
            final song = ref.read(playerProvider).currentSong;
            if (song != null) {
              ref.read(favoritesProvider.notifier).toggleFavorite(song);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play_rounded, size: 24),
          color: _inactiveColor(playerState).withValues(alpha: 0.8),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            );
          },
        ),
        // 播放模式：顺序 -> 随机 -> 单曲循环
        _buildPlayModeButton(playerState),
      ],
    );
  }

  /// 单个播放模式按钮，点击循环切换 顺序/随机/单曲循环
  Widget _buildPlayModeButton(PlayerState state) {
    final isShuffle = state.shuffleMode;
    final isOne = state.repeatMode == MusicRepeatMode.one;
    final IconData icon = isShuffle
        ? Icons.shuffle_rounded
        : isOne
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final label = isShuffle
        ? '随机播放'
        : isOne
        ? '单曲循环'
        : '顺序播放';
    return IconButton(
      tooltip: '播放模式：$label（点击切换）',
      icon: Icon(
        icon,
        size: 24,
        color: (isShuffle || isOne)
            ? _accent
            : _inactiveColor(state).withValues(alpha: 0.8),
      ),
      onPressed: () => ref.read(playerProvider.notifier).cyclePlayMode(),
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

/// 通用底部选项面板
class _OptionSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _OptionSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 20,
      borderRadius: 20,
      tintColor: AppColors.surfaceDark,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
