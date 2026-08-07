import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/cookie_bridge.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {},
      ))
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  Future<String> _grabCookie() async {
    return CookieBridge.getCookie(widget.cookieUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登录${widget.platformName}'),
        actions: [
          TextButton(
            onPressed: () async {
              final cookie = await _grabCookie();
              if (!context.mounted) return;
              if (cookie.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未获取到登录态，请确认已登录')),
                );
                return;
              }
              Navigator.pop(context, cookie);
            },
            child: const Text('完成（已登录）'),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
