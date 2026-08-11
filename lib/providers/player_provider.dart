import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/lyric.dart';
import '../music_source/builtin/builtin_search_helpers.dart';
import '../music_source/core/track_adapter.dart';
import '../music_source/models/music_track.dart';
import '../music_source/providers/music_source_provider.dart';
import '../services/audio_handler.dart';
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
    if (h > 0)
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
      state = state.copyWith(position: position, currentLyricIndex: lyricIdx);
    });

    // 监听总时长
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    // 监听播放状态
    _audioPlayer.playerStateStream.listen((playerState) async {
      state = state.copyWith(isPlaying: playerState.playing);

      // 播放完成时自动下一首；单曲循环则重播
      if (playerState.processingState == ProcessingState.completed) {
        if (state.repeatMode == MusicRepeatMode.one) {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
        } else {
          await next();
        }
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

  /// 从音源获取歌词
  ///
  /// 失败自动重试（最多 3 次尝试）：冷启动时账号登录态异步初始化会触发
  /// sourceListProvider 重建（旧 backend 被 dispose），首播的歌词请求
  /// 可能正好撞上重建窗口而失败；重试时用最新的音源实例，并在歌曲已
  /// 切换时放弃，避免歌词错位。
  Future<void> fetchLyrics({int attempt = 0}) async {
    final song = state.currentSong;
    if (song == null) {
      debugPrint('[歌词] 跳过：currentSong 为空');
      return;
    }
    debugPrint('[歌词] attempt=$attempt 歌曲=${song.name} id=${song.id} '
        'sourceId=${song.sourceId} sourceKey=${song.sourceKey}');

    try {
      final track = TrackAdapter.fromLegacySong(song);
      // 每次尝试都重新拿 notifier：sourceListProvider 重建后必须用新实例
      final sourceNotifier = _ref.read(sourceListProvider.notifier);
      final tryOrder = <String>[
        if (song.sourceId != null) song.sourceId!,
        ...sourceNotifier.enabledSources.map((s) => s.id),
      ];
      debugPrint('[歌词] tryOrder=$tryOrder '
          'enabled=${sourceNotifier.enabledSources.map((s) => s.id).toList()}');

      String? lrc;
      final tried = <String>{};
      for (final sourceId in tryOrder) {
        if (!tried.add(sourceId)) continue;
        final backend = await sourceNotifier.getBackend(sourceId);
        if (backend == null) {
          debugPrint('[歌词] $sourceId backend 为 null');
          continue;
        }

        // 跨源歌词兜底：源不同时，先在该源按「歌名+歌手」搜索匹配歌曲，
        // 用匹配到的该源真实 track 再取歌词（直接用原平台 id 查其他源
        // 必然失败，如网易云数字 id 查 QQ songmid）。本源的歌曲不搜索，
        // 优先用自己源的标准歌词。
        var target = track;
        if (sourceId != song.sourceId && backend.searchKeys.isNotEmpty) {
          try {
            final results = await backend.search(
              '${song.name} ${song.artist}'.trim(),
              limit: 5,
              type: SearchType.song,
            );
            // 优先歌手匹配，其次取第一个结果
            MusicTrack? matched;
            if (song.artist.isNotEmpty) {
              matched = results.where((t) {
                final a = t.artist.toLowerCase();
                final want = song.artist.toLowerCase();
                return a.contains(want) || want.contains(a);
              }).firstOrNull;
            }
            matched ??= results.firstOrNull;
            if (matched != null) {
              target = MusicTrack(
                id: matched.id,
                title: matched.title,
                artist: matched.artist,
                album: matched.album,
                coverUrl: matched.coverUrl,
                durationMs: matched.durationMs,
                sourceId: sourceId,
                sourceKey: matched.sourceKey,
                lyricId: matched.lyricId,
                rawData: matched.rawData,
                mediaMid: matched.mediaMid,
              );
              debugPrint('[歌词] 跨源 $sourceId 搜索命中 '
                  '${matched.title}（${matched.id}）');
            } else {
              debugPrint('[歌词] 跨源 $sourceId 搜索无匹配');
            }
          } catch (e) {
            debugPrint('[歌词] 跨源 $sourceId 搜索异常: $e');
          }
        }

        final result = await backend.getLyric(target);
        debugPrint('[歌词] $sourceId getLyric 返回 '
            '${result == null ? 'null' : '${result.length} 字符'}');
        if (result != null && result.isNotEmpty) {
          lrc = result;
          debugPrint('[歌词] 命中 $sourceId');
          break;
        }
      }

      if (lrc != null &&
          lrc.isNotEmpty &&
          mounted &&
          state.currentSong?.dedupeKey == song.dedupeKey) {
        final lyric = Lyric.fromLrc(lrc, songId: song.id);
        debugPrint('[歌词] 解析成功 lines=${lyric.lines.length}');
        state = state.copyWith(
          lyricLines: lyric.lines,
          currentLyricIndex: lyric.currentIndex(state.position),
        );
        return;
      }
      debugPrint('[歌词] 未取到有效歌词');
    } catch (e) {
      debugPrint('[歌词] 异常: $e');
    }

    // 失败后重试：冷启动时账号登录态初始化会重建音源引擎（backend 被
    // dispose），首次尝试可能正好撞上重建窗口。先等待引擎就绪再重试，
    // 最长 ~8 秒，覆盖重建耗时超过固定延迟的场景。
    if (attempt < 5 && mounted) {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      var ready = false;
      while (!ready && DateTime.now().isBefore(deadline) && mounted) {
        try {
          ready = _ref.read(sourceListProvider.notifier).isEngineReady;
        } catch (_) {
          ready = false;
        }
        if (!ready) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      debugPrint('[歌词] 引擎就绪=$ready，第 ${attempt + 1} 次重试');
      if (mounted && state.currentSong?.dedupeKey == song.dedupeKey) {
        fetchLyrics(attempt: attempt + 1);
      }
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

    state = state.copyWith(queue: newQueue, currentIndex: currentIdx);
  }

  /// 播放歌曲（内部方法，返回是否成功）
  Future<bool> _playSong(Song song, {List<Song>? queue}) async {
    try {
      if (song.sourceId == null) {
        state = state.copyWith(playbackError: '缺少音源信息，无法播放');
        return false;
      }

      // ── 严格同源：只在该歌曲所属平台获取播放链接，绝不跨源降级 ──
      // （跨平台搜索同名歌会把「周杰伦-」这类翻唱当作原唱播放，已废弃）
      String? url;
      String? lastError;

      final sourceNotifier = _ref.read(sourceListProvider.notifier);
      final track = TrackAdapter.fromLegacySong(song);
      // 使用设置中的默认音质
      final quality = _ref.read(settingsProvider).defaultQuality;

      // 诊断：确认播放请求走的是哪个源（builtin_* 走内置 API，其他走 lx 脚本）
      // ignore: avoid_print
      print('[播放] ${song.name} | sourceId=${song.sourceId} '
          'sourceKey=${song.sourceKey ?? ''} quality=$quality');

      final bridge = await sourceNotifier.getBackend(song.sourceId!);
      if (bridge == null) {
        state = state.copyWith(
          playbackError: '「${song.name}」所属音源不可用，无法播放',
        );
        return false;
      }
      try {
        url = await bridge.getMusicUrl(track, quality: quality);
      } catch (e) {
        lastError = '$e';
      }

      if (url == null || url.isEmpty) {
        state = state.copyWith(
          playbackError: '「${song.name}」无法播放：该平台未登录或歌曲无可用播放地址'
              '${lastError != null ? '（$lastError）' : ''}',
        );
        return false;
      }

      final safeUrl = url.trim();
      if (safeUrl.contains('/undefined/') ||
          safeUrl.contains('undefined?') ||
          safeUrl.contains('/null/') ||
          !(safeUrl.startsWith('http://') || safeUrl.startsWith('https://'))) {
        state = state.copyWith(
          playbackError: '「${song.name}」播放地址无效（脚本返回了错误链接）',
        );
        return false;
      }

      // 播放时带浏览器 UA：QQ/网易 CDN 拒绝 ExoPlayer 默认 UA（404）
      await _audioPlayer.setUrl(
        safeUrl,
        headers: {'User-Agent': kBrowserUserAgent},
      );

      // 记录到最近播放
      _ref.read(favoritesProvider.notifier).addToRecent(song);

      // 歌曲切换后清空并异步获取歌词。注意：必须在 play() 之前触发——
      // just_audio 首次播放时 play() 的 Future 可能因内部 HTTP proxy
      // 异常（Bad state: Headers already sent）悬挂不返回，若等 play()
      // 完成再取歌词会导致首播无歌词（重播时才恢复）。
      state = state.copyWith(
        lyricLines: [],
        currentLyricIndex: 0,
        clearError: true,
      );
      debugPrint('[歌词] 播放成功，触发 fetchLyrics');
      fetchLyrics();

      await _audioPlayer.play();
      // 更新锁屏信息
      _updateMediaItem();
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
      state = state.copyWith(currentSong: song, currentIndex: nextIndex);
      // 尝试播放
      final ok = await _playSong(song, queue: state.queue);
      if (ok) return; // 播放成功，退出
      // URL 失败，继续尝试下一首
      // ignore: avoid_print
      print('[Player] 跳过 (URL获取失败): ${song.name}');
    }
    // ignore: avoid_print
    print('[Player] 队列中所有歌曲 URL 均获取失败');
    state = state.copyWith(playbackError: '队列中所有歌曲暂无可用播放源', isPlaying: false);
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
      state = state.copyWith(currentSong: song, currentIndex: prevIndex);
      final ok = await _playSong(song, queue: state.queue);
      if (ok) return;
      // ignore: avoid_print
      print('[Player] 跳过 (URL获取失败): ${song.name}');
    }
    // 所有歌曲都失败
    state = state.copyWith(playbackError: '队列中所有歌曲暂无可用播放源', isPlaying: false);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 切换播放模式：顺序 -> 随机 -> 单曲循环 -> 顺序
  ///
  /// 模式由 shuffleMode + repeatMode 组合推导：
  /// - 随机：shuffleMode = true
  /// - 单曲循环：repeatMode = one
  /// - 顺序：其余
  void cyclePlayMode() {
    if (state.shuffleMode) {
      // 随机 -> 单曲循环
      state = state.copyWith(
          shuffleMode: false, repeatMode: MusicRepeatMode.one);
    } else if (state.repeatMode == MusicRepeatMode.one) {
      // 单曲循环 -> 顺序
      state = state.copyWith(repeatMode: MusicRepeatMode.off);
    } else {
      // 顺序 -> 随机
      if (state.queue.isNotEmpty) _regenerateShuffleOrder();
      state = state.copyWith(shuffleMode: true);
    }
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

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier(ref, audioPlayerInstance, audioHandlerInstance);
});
