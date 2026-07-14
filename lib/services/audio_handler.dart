import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// 后台音频处理器 — 桥接 just_audio 和 audio_service
/// 实现锁屏控制、通知栏控制、蓝牙耳机控制
class MusicAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;

  /// 外部回调：由 PlayerNotifier 注入
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

  MusicAudioHandler(this._player) {
    // 监听播放器事件，同步到 audio_service 状态
    _player.playbackEventStream.listen(_broadcastState);
  }

  /// 向系统广播播放状态
  void _broadcastState(PlaybackEvent event) {
    if (playbackState.value.processingState == AudioProcessingState.completed) return;

    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      playing: playing,
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.buffering,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ??
          AudioProcessingState.idle,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    ));
  }

  /// 更新锁屏/通知栏显示的歌曲信息
  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  // ── 系统媒体控制回调 ──

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
}
