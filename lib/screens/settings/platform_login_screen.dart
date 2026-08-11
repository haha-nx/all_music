import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/constants.dart';
import '../../services/cookie_analyzer.dart';
import '../../services/cookie_bridge.dart';

/// 桌面版 Chrome UA：让各平台返回 PC 版页面（移动 UA 只会给下载 App 引导页，无登录入口）
const String kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// 平台登录页：内嵌 WebView 打开官方登录页，登录完成后点「完成」抓 cookie
class PlatformLoginScreen extends StatefulWidget {
  final String platformKey;
  final String platformName;
  final String loginUrl;
  final String cookieUrl;

  const PlatformLoginScreen({
    super.key,
    required this.platformKey,
    required this.platformName,
    required this.loginUrl,
    required this.cookieUrl,
  });

  @override
  State<PlatformLoginScreen> createState() => _PlatformLoginScreenState();
}

class _PlatformLoginScreenState extends State<PlatformLoginScreen> {
  late final WebViewController _controller;

  /// 自动完成流程中，防止重复触发
  bool _autoCompleting = false;

  /// 已自动完成（返回 cookie），忽略后续 URL 变化
  bool _completed = false;

  /// 页面是否已完成过至少一次加载。首次加载完成前不做自动完成判定，
  /// 避免页面还在加载就因旧 cookie 自动退出（「刚打开就闪退」的观感）；
  /// 加载完成后 onUrlChange/onPageFinished 都会尝试自动抓取 cookie。
  bool _pageLoadedOnce = false;

  /// WebView 是否正在加载：加载中盖一层深色占位，避免白屏闪烁
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(kDesktopUserAgent)
      ..setBackgroundColor(AppColors.backgroundDark)
      ..setNavigationDelegate(NavigationDelegate(
        onUrlChange: (details) {
          final url = details.url?.toString() ?? '';
          debugPrint('[WebView] urlChange: $url');
          if (!_pageLoadedOnce) return;
          _maybeAutoComplete(url);
        },
        onPageStarted: (url) {
          debugPrint('[WebView] pageStarted: $url');
          if (mounted && !_loading) {
            setState(() => _loading = true);
          }
        },
        onPageFinished: (url) {
          debugPrint('[WebView] pageFinished: $url');
          if (mounted && _loading) {
            setState(() => _loading = false);
          }
          // 每次页面加载完成都主动尝试自动抓取：覆盖
          // ① 已有登录态时打开登录页直接返回；
          // ② 登录成功后 SPA 仅刷新页面、URL 未变化（onUrlChange 不会触发）
          //    两类场景。首次加载完成前 onUrlChange 的判定被拦，这里才放行。
          _pageLoadedOnce = true;
          _maybeAutoComplete(url);
        },
        onWebResourceError: (error) {
          debugPrint(
            '[WebView] resourceError: ${error.errorCode} '
            '${error.description} '
            '(${(error.isForMainFrame ?? false) ? 'main' : 'sub'})',
          );
          // 主 frame 加载失败：撤掉占位，让用户看到错误页而非一直转圈
          if ((error.isForMainFrame ?? false) && mounted && _loading) {
            setState(() => _loading = false);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  /// 该 URL 是否属于「登录完成后会停留」的页面域
  ///
  /// - 网易云（SPA）：停在 music.163.com 且不在 /login 登录页（登录后跳 /discover）
  /// - QQ 音乐：回到 y.qq.com（微信登录经 wx_redirect 回跳）或 u.y.qq.com
  bool _isLoginDoneUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    switch (widget.platformKey) {
      case 'wy':
        if (uri.host != 'music.163.com') return false;
        return !uri.path.contains('login') && !uri.fragment.contains('login');
      case 'tx':
        return uri.host == 'y.qq.com' || uri.host == 'u.y.qq.com';
      default:
        return false;
    }
  }

  /// URL 变化到登录完成域后：延迟抓 cookie 并校验，有效则自动返回
  Future<void> _maybeAutoComplete(String url) async {
    if (_completed || _autoCompleting) return;
    if (!_isLoginDoneUrl(url)) return;
    _autoCompleting = true;
    try {
      // 等待页面跳转与 cookie 写入稳定
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final cookie = await _grabCookie();
      // 登录态未就绪则不打扰用户（等下次 URL 变化或手动点完成）
      if (cookie.isEmpty ||
          missingLoginKeys(widget.platformKey, cookie).isNotEmpty) {
        return;
      }
      _completed = true;
      if (!mounted) return;
      Navigator.pop(context, cookie);
    } finally {
      _autoCompleting = false;
    }
  }

  /// 抓取 cookie：合并平台相关域的 cookie（QQ 微信登录态可能跨多个域）
  Future<String> _grabCookie() async {
    final urls = kPlatformCookieUrls[widget.platformKey] ?? [widget.cookieUrl];
    final parts = <String>[];
    for (final url in urls) {
      final c = await CookieBridge.getCookie(url);
      if (c.isNotEmpty) parts.add(c);
    }
    return mergeCookies(parts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: Text(
          '登录${widget.platformName}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: () async {
              final cookie = await _grabCookie();
              if (!context.mounted) return;
              if (cookie.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未获取到登录态，请确认已登录')),
                );
                return;
              }
              // 校验登录态关键键：缺少则保存后必然播放失败，明确提示重试
              final missing = missingLoginKeys(widget.platformKey, cookie);
              if (missing.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '登录态不完整（缺 ${missing.join('、')}）。\n'
                      '请等待登录页完整跳转后再点完成（QQ 扫码后需等跳回 y.qq.com）',
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
                return;
              }
              _completed = true;
              Navigator.pop(context, cookie);
            },
              child: const Text('完成（已登录）'),
            ),
          ),
        ],
      ),
      // WebView 常驻 Stack 不销毁重建；加载中盖深色占位（与主题一致），
      // 避免网易云页面重载时黑白交替造成的闪烁观感。
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const ColoredBox(
              color: AppColors.backgroundDark,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
