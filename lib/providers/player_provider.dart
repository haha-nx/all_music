import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/lyric.dart';
import '../music_source/core/track_adapter.dart';
import '../services/audio_handler.dart';
import 'source_provider.dart';
import 'favorites_provider.dart';
import 'settings_provider.dart';

/// 播放模式
enum MusicRepeatMode { off, all, one }

/// 定时关闭选项
class SleepTimerOption {
  final String label;
  final Duration duration;

  const SleepTimerOption(this.label, this.duration);

  static const List<SleepTimerOption> options = [
    SleepTimerOption('15 分钟', Duration(minutes: 15)),
    SleepTimerOption('30 分钟', Duration(minutes: 30)),
    SleepTimerOption('45 分钟', Duration(minutes: 45)),
    SleepTimerOption('60 分钟', Duration(minutes: 60)),
    SleepTimerOption('90 分钟', Duration(minutes: 90)),
  ];

  /// 根据剩余时间格式化为倒计时文本
  static String format(Duration remaining) {
    if (remaining <= Duration.zero) return '';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 播放器状态
class PlayerState {
  final Song? currentSong;
  final List<Song> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffleMode;
  final MusicRepeatMode repeatMode;
  final List<LyricLine> lyricLines;
  final int currentLyricIndex;
  final bool showLyrics;
  /// 播放错误消息（非 null 时表示播放失败，应显示给用户）
  final String? playbackError;

  /// 播放速度（0.5 ~ 2.0）
  final double speed;

  /// 定时关闭剩余时间（Duration.zero 表示未开启）
  final Duration sleepTimerRemaining;

  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleMode = false,
    this.repeatMode = MusicRepeatMode.off,
    this.lyricLines = const [],
    this.currentLyricIndex = 0,
    this.showLyrics = false,
    this.playbackError,
    this.speed = 1.0,
    this.sleepTimerRemaining = Duration.zero,
  });

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffleMode,
    MusicRepeatMode? repeatMode,
    List<LyricLine>? lyricLines,
    int? currentLyricIndex,
    bool? showLyrics,
    String? playbackError,
    bool clearError = false,
    double? speed,
    Duration? sleepTimerRemaining,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      repeatMode: repeatMode ?? this.repeatMode,
      lyricLines: lyricLines ?? this.lyricLines,
      currentLyricIndex: currentLyricIndex ?? this.currentLyricIndex,
      showLyrics: showLyrics ?? this.showLyrics,
      playbackError: clearError ? null : (playbackError ?? this.playbackError),
      speed: speed ?? this.speed,
      sleepTimerRemaining: sleepTimerRemaining ?? this.sleepTimerRemaining,
    );
  }
}

/// 播放器状态管理
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AudioPlayer _audioPlayer;
  final MusicAudioHandler _audioHandler;

  /// Fisher-Yates 随机播放索引序列
  List<int> _shuffleOrder = [];
  int _shufflePosition = 0;

  /// 定时关闭计时器
  Timer? _sleepTimer;

  PlayerNotifier(this._ref, this._audioPlayer, this._audioHandler)
      : super(const PlayerState()) {
    // 连接系统媒体控制回调
    _audioHandler.onSkipToNext = next;
    _audioHandler.onSkipToPrevious = previous;
    // 监听播放位置
    _audioPlayer.positionStream.listen((position) {
      final lyricIdx = _findCurrentLyricIndex(position);
      state = state.copyWith(
        position: position,
        currentLyricIndex: lyricIdx,
      );
    });

    // 监听总时长
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    // 监听播放状态
    _audioPlayer.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);

      // 播放完成时自动下一首
      if (playerState.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  /// 根据播放位置查找当前歌词行索引
  int _findCurrentLyricIndex(Duration position) {
    final lines = state.lyricLines;
    if (lines.isEmpty) return 0;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) return i;
    }
    return 0;
  }

  /// 更新锁屏/通知栏媒体信息
  void _updateMediaItem() {
    final song = state.currentSong;
    if (song == null) return;
    _audioHandler.updateMediaItem(
      MediaItem(
        id: song.dedupeKey,
        title: song.name,
        artist: song.artist,
        album: song.album ?? '',
        artUri: song.albumCover != null ? Uri.tryParse(song.albumCover!) : null,
        duration: state.duration,
      ),
    );
  }

  /// 切换歌词显示
  void toggleLyrics() {
    state = state.copyWith(showLyrics: !state.showLyrics);
    // 首次显示歌词时获取
    if (state.showLyrics && state.lyricLines.isEmpty) {
      fetchLyrics();
    }
  }

  /// 从音源获取歌词
  Future<void> fetchLyrics() async {
    final song = state.currentSong;
    if (song == null) return;

    try {
      final backend = await _ref.read(sourceProvider.notifier).getBackend(song.sourceId ?? '');
      if (backend == null) return;

      final track = TrackAdapter.fromLegacySong(song);
      final lrc = await backend.getLyric(track);
      if (lrc != null && lrc.isNotEmpty && mounted) {
        final lyric = Lyric.fromLrc(lrc, songId: song.id);
        state = state.copyWith(
          lyricLines: lyric.lines,
          currentLyricIndex: lyric.currentIndex(state.position),
        );
      }
    } catch (_) {
      // 歌词获取失败静默处理
    }
  }

  /// 下一首播放 - 插入到当前歌曲之后
  void playNext(Song song) {
    final newQueue = List<Song>.from(state.queue);
    final insertIndex = (state.currentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertIndex, song);
    state = state.copyWith(queue: newQueue);
  }

  /// 从队列中移除指定位置的歌曲
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = List<Song>.from(state.queue);
    newQueue.removeAt(index);

    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      if (newQueue.isEmpty) {
        _audioPlayer.stop();
        state = const PlayerState();
        return;
      }
      newIndex = newIndex.clamp(0, newQueue.length - 1);
      play(newQueue[newIndex], queue: newQueue);
      return;
    }

    state = state.copyWith(
      queue: newQueue,
      currentIndex: newIndex.clamp(0, newQueue.length - 1),
    );
  }

  /// 拖拽重排队列
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final newQueue = List<Song>.from(state.queue);
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, song);

    int currentIdx = state.currentIndex;
    if (oldIndex < currentIdx && newIndex >= currentIdx) {
      currentIdx--;
    } else if (oldIndex > currentIdx && newIndex <= currentIdx) {
      currentIdx++;
    } else if (oldIndex == currentIdx) {
      currentIdx = newIndex;
    }

    state = state.copyWith(
      queue: newQueue,
      currentIndex: currentIdx,
    );
  }


  /// 播放歌曲（内部方法，返回是否成功）
  Future<bool> _playSong(Song song, {List<Song>? queue}) async {
    try {
      if (song.sourceId == null) {
        state = state.copyWith(playbackError: '缺少音源信息，无法播放');
        return false;
      }

      // ── URL 降级链：按优先级尝试多个源获取播放链接 ──
      String? url;
      String? lastError;

      final sourceNotifier = _ref.read(sourceProvider.notifier);
      final track = TrackAdapter.fromLegacySong(song);
      // 使用设置中的默认音质
      final quality = _ref.read(settingsProvider).defaultQuality;

      // 构建尝试顺序：原始源 → 其他已启用源
      final tryOrder = <String>[];
      if (song.sourceId != null) tryOrder.add(song.sourceId!);
      for (final s in sourceNotifier.enabledSources) {
        if (!tryOrder.contains(s.id)) tryOrder.add(s.id);
      }

      final triedIds = <String>{};
      for (final sourceId in tryOrder) {
        if (!triedIds.add(sourceId)) continue;

        try {
          final bridge = await sourceNotifier.getBackend(sourceId);
          if (bridge == null) continue;

          // 如果音源有多个子源key，尝试匹配
          final result = await bridge.getMusicUrl(track, quality: quality);
          if (result != null && result.isNotEmpty) {
            url = result;
            break;
          }
        } catch (e) {
          lastError = '$sourceId: $e';
          continue;
        }
      }

      if (url == null || url.isEmpty) {
        state = state.copyWith(
          playbackError: '「${song.name}」暂无可用播放源${lastError != null ? '（$lastError）' : ''}',
        );
        return false;
      }

      await _audioPlayer.setUrl(url);

      // 记录到最近播放
      _ref.read(favoritesProvider.notifier).addToRecent(song);

      await _audioPlayer.play();
      // 更新锁屏信息
      _updateMediaItem();
      // 歌曲切换后清空并异步获取歌词
      state = state.copyWith(
        lyricLines: [],
        currentLyricIndex: 0,
        clearError: true,
      );
      fetchLyrics();
      return true;
    } catch (e) {
      print('[Player] 播放异常: $e');
      state = state.copyWith(playbackError: '播放失败: $e');
      return false;
    }
  }

  /// 播放歌曲
  Future<void> play(Song song, {List<Song>? queue}) async {
    // 先更新队列和当前歌曲信息（即使 URL 获取失败，队列也要正确）
    if (queue != null) {
      final index = queue.indexWhere((s) => s.dedupeKey == song.dedupeKey);
      state = state.copyWith(
        currentSong: song,
        queue: queue,
        currentIndex: index >= 0 ? index : 0,
        clearError: true,
      );
      if (state.shuffleMode) _regenerateShuffleOrder();
    } else {
      state = state.copyWith(currentSong: song, clearError: true);
    }

    final ok = await _playSong(song, queue: queue);
    if (!ok) {
      // _playSong 已经设置了 playbackError，此处暂停播放状态
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 播放歌单
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await play(songs[startIndex], queue: songs);
  }

  /// 切换播放/暂停
  Future<void> togglePlay() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  /// Fisher-Yates 洗牌：生成随机播放顺序，当前歌曲始终排第一
  void _regenerateShuffleOrder() {
    final len = state.queue.length;
    _shuffleOrder = List.generate(len, (i) => i);
    // Dart 内置 Fisher-Yates shuffle
    _shuffleOrder.shuffle();
    // 把当前播放位置移到首位
    final currentPos = _shuffleOrder.indexOf(state.currentIndex);
    if (currentPos >= 0) {
      _shuffleOrder.removeAt(currentPos);
      _shuffleOrder.insert(0, state.currentIndex);
    }
    _shufflePosition = 0;
  }

  /// 下一首（支持 Fisher-Yates 随机播放，URL 失败自动跳过）
  Future<void> next() async {
    if (state.queue.isEmpty) return;

    // 最多尝试 queue.length 次，避免全部失败时无限循环
    for (int attempt = 0; attempt < state.queue.length; attempt++) {
      int nextIndex;
      if (state.shuffleMode) {
        _shufflePosition++;
        if (_shufflePosition >= _shuffleOrder.length) {
          if (state.repeatMode == MusicRepeatMode.all) {
            _regenerateShuffleOrder();
          } else {
            return; // 不循环，停在最后一首
          }
        }
        nextIndex = _shuffleOrder[_shufflePosition];
      } else {
        nextIndex = state.currentIndex + 1;
        if (nextIndex >= state.queue.length) {
          if (state.repeatMode == MusicRepeatMode.all) {
            nextIndex = 0;
          } else {
            return;
          }
        }
      }

      final song = state.queue[nextIndex];
      // 先更新状态
      state = state.copyWith(
        currentSong: song,
        currentIndex: nextIndex,
      );
      // 尝试播放
      final ok = await _playSong(song, queue: state.queue);
      if (ok) return; // 播放成功，退出
      // URL 失败，继续尝试下一首
      // ignore: avoid_print
      print('[Player] 跳过 (URL获取失败): ${song.name}');
    }
    // ignore: avoid_print
    print('[Player] 队列中所有歌曲 URL 均获取失败');
    state = state.copyWith(
      playbackError: '队列中所有歌曲暂无可用播放源',
      isPlaying: false,
    );
  }

  /// 上一首（支持 Fisher-Yates 随机播放，URL 失败自动跳过）
  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    // 如果已经播放超过 3 秒，重新播放当前歌曲
    if (state.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    for (int attempt = 0; attempt < state.queue.length; attempt++) {
      int prevIndex;
      if (state.shuffleMode) {
        _shufflePosition--;
        if (_shufflePosition < 0) {
          if (state.repeatMode == MusicRepeatMode.all) {
            _shufflePosition = _shuffleOrder.length - 1;
          } else {
            _shufflePosition = 0;
            return;
          }
        }
        prevIndex = _shuffleOrder[_shufflePosition];
      } else {
        prevIndex = state.currentIndex - 1;
        if (prevIndex < 0) {
          if (state.repeatMode == MusicRepeatMode.all) {
            prevIndex = state.queue.length - 1;
          } else {
            prevIndex = 0;
            return;
          }
        }
      }

      final song = state.queue[prevIndex];
      state = state.copyWith(
        currentSong: song,
        currentIndex: prevIndex,
      );
      final ok = await _playSong(song, queue: state.queue);
      if (ok) return;
      // ignore: avoid_print
      print('[Player] 跳过 (URL获取失败): ${song.name}');
    }
    // 所有歌曲都失败
    state = state.copyWith(
      playbackError: '队列中所有歌曲暂无可用播放源',
      isPlaying: false,
    );
  }
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 切换随机播放
  void toggleShuffle() {
    final newShuffle = !state.shuffleMode;
    if (newShuffle && state.queue.isNotEmpty) {
      _regenerateShuffleOrder();
    }
    state = state.copyWith(shuffleMode: newShuffle);
  }

  /// 切换循环模式
  void toggleRepeat() {
    final modes = MusicRepeatMode.values;
    final nextIndex = (state.repeatMode.index + 1) % modes.length;
    state = state.copyWith(repeatMode: modes[nextIndex]);
  }

  /// 设置定时关闭（null 或 Duration.zero 取消）
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null || duration <= Duration.zero) {
      state = state.copyWith(sleepTimerRemaining: Duration.zero);
      return;
    }
    state = state.copyWith(sleepTimerRemaining: duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.sleepTimerRemaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        state = state.copyWith(sleepTimerRemaining: Duration.zero);
        _audioPlayer.pause();
        return;
      }
      state = state.copyWith(sleepTimerRemaining: remaining);
    });
  }

  /// 设置播放速度（0.5x ~ 2.0x）
  Future<void> setSpeed(double speed) async {
    final s = speed.clamp(0.5, 2.0);
    await _audioPlayer.setSpeed(s);
    state = state.copyWith(speed: s);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioHandler.onSkipToNext = null;
    _audioHandler.onSkipToPrevious = null;
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// 全局共享 AudioPlayer（由 main 创建）
final audioPlayerInstance = AudioPlayer();

/// 全局共享 MusicAudioHandler（由 main 初始化）
late final MusicAudioHandler audioHandlerInstance;

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref, audioPlayerInstance, audioHandlerInstance);
});
