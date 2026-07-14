import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/lyric.dart';
import '../services/source_api.dart';
import '../services/audio_handler.dart';
import 'source_provider.dart';
import 'favorites_provider.dart';

/// 播放模式
enum MusicRepeatMode { off, all, one }

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
      final sources = _ref.read(sourceProvider);
      final source = sources.firstWhere(
        (s) => s.id == song.sourceId,
        orElse: () => sources.first,
      );
      final api = await SourceApi.create(source, _ref);
      final lyric = await api.getLyric(song);
      if (lyric != null && mounted) {
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


  /// 播放歌曲
  Future<void> play(Song song, {List<Song>? queue}) async {
    try {
      // 查找对应的音源获取播放URL
      if (song.sourceId != null) {
        final sources = _ref.read(sourceProvider);
        final source = sources.firstWhere(
          (s) => s.id == song.sourceId,
          orElse: () => sources.first,
        );
        final api = await SourceApi.create(source, _ref);
        final url = await api.getSongUrl(song);
        if (url == null || url.isEmpty) return;
        await _audioPlayer.setUrl(url);
      } else {
        return; // 没有可用音源
      }

      if (queue != null) {
        final index = queue.indexWhere((s) => s.dedupeKey == song.dedupeKey);
        state = state.copyWith(
          currentSong: song,
          queue: queue,
          currentIndex: index >= 0 ? index : 0,
        );
        // 队列变更时重新生成随机播放顺序
        if (state.shuffleMode) _regenerateShuffleOrder();
      } else {
        state = state.copyWith(currentSong: song);
      }

      // 记录到最近播放
      _ref.read(favoritesProvider.notifier).addToRecent(song);

      await _audioPlayer.play();
      // 更新锁屏信息
      _updateMediaItem();
      // 歌曲切换后清空并异步获取歌词
      state = state.copyWith(lyricLines: [], currentLyricIndex: 0);
      fetchLyrics();
    } catch (e) {
      // 播放失败，静默处理
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

  /// 下一首（支持 Fisher-Yates 随机播放）
  Future<void> next() async {
    if (state.queue.isEmpty) return;

    int nextIndex;
    if (state.shuffleMode) {
      _shufflePosition++;
      // 已播完一轮
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

    await play(state.queue[nextIndex], queue: state.queue);
  }

  /// 上一首（支持 Fisher-Yates 随机播放）
  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    // 如果已经播放超过 3 秒，重新播放当前歌曲
    if (state.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (state.shuffleMode) {
      _shufflePosition--;
      if (_shufflePosition < 0) {
        if (state.repeatMode == MusicRepeatMode.all) {
          _shufflePosition = _shuffleOrder.length - 1;
        } else {
          _shufflePosition = 0;
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
        }
      }
    }

    await play(state.queue[prevIndex], queue: state.queue);
  }

  /// 跳转到指定位置
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

  @override
  void dispose() {
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
