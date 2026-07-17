import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置音频会话（允许后台播放）—— 容错：失败不影响主流程
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('[Main] AudioSession 初始化失败: $e');
  }

  // 初始化 AudioService handler（锁屏/通知栏控制）—— 容错
  try {
    audioHandlerInstance = MusicAudioHandler(audioPlayerInstance);
    await AudioService.init(
      builder: () => audioHandlerInstance,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.allmusic.audio',
        androidNotificationChannelName: 'All Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: false,
      ),
    );
  } catch (e) {
    debugPrint('[Main] AudioService 初始化失败: $e');
    // audioHandlerInstance 保持未初始化状态，播放器将降级为纯前台模式
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 注意：数据库初始化不再在 main() 中提前执行。
  // DatabaseHelper 使用懒初始化，首次读写时自动打开，
  // 此时 FlutterEngine 已完全就绪，不会有 Activity 相关异常。
  runApp(const ProviderScope(child: MusicApp()));
}
