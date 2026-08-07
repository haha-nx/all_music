package com.example.all_music

import android.webkit.CookieManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceFragmentActivity

/// audio_service 官方推荐的方式：直接继承 AudioServiceFragmentActivity
/// 这样 audio_service 插件可以自动管理 FlutterEngine 的提供
class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "all_music/cookie")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCookie" -> {
                        val url = call.argument<String>("url") ?: ""
                        val cookie = if (url.isEmpty()) "" else
                            CookieManager.getInstance().getCookie(url) ?: ""
                        result.success(cookie)
                    }
                    "clearCookie" -> {
                        // Dart 侧 clearCookie() 语义为"清空全部 cookie（登出用）"，无条件调用
                        CookieManager.getInstance().removeAllCookies(null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
