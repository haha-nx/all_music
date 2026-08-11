import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'providers/player_provider.dart';
import 'music_source/builtin/builtin_search_helpers.dart';

/// 全局 HTTP 客户端覆盖：dart:io HttpClient 默认 UA 改为浏览器 UA
///
/// 网易云图片 CDN（p1/p2/p3.music.126.net）会拒绝 dart:io 默认 UA
/// （`Dart/3.x (dart:io)`，返回 403），导致 CachedNetworkImage/Image.network
/// 加载网易云封面全部失败（QQ 图床不检查 UA 所以正常）。
/// 这里把默认 UA 设为浏览器 UA，全局生效且不影响 Dio（Dio 自带 headers）。
class _BrowserUserAgentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent = kBrowserUserAgent;
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 图片/资源请求默认带浏览器 UA（网易云 CDN 403 修复）
  HttpOverrides.global = _BrowserUserAgentHttpOverrides();

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

  // ScreenUtil 适配：移动端基准 390×844；桌面端 scale≈1（不放大）
  final binding = WidgetsBinding.instance;
  final isDesktop = !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  Size designSize = const Size(390, 844);
  if (isDesktop) {
    final view = binding.platformDispatcher.views.first;
    designSize = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
  }
  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => const MusicApp(),
      ),
    ),
  );
}
