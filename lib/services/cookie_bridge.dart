import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生 Cookie 桥：读/清系统 CookieManager（webview_flutter 共享同一存储，含 HttpOnly）
class CookieBridge {
  static const _channel = MethodChannel('all_music/cookie');

  /// 获取某 URL 域下的 cookie 串（`name=value; ...`），非 Android 返回空串
  static Future<String> getCookie(String url) async {
    if (!kIsWeb && Platform.isAndroid && url.isNotEmpty) {
      try {
        final v = await _channel.invokeMethod<String>('getCookie', {'url': url});
        return v ?? '';
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  /// 清空全部 cookie（登出用）
  static Future<void> clearCookie() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('clearCookie', {'url': ''});
      } catch (_) {}
    }
  }
}
