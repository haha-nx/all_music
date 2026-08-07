import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../music_source/builtin/builtin_platforms.dart';
import '../../providers/account_center_provider.dart';
import '../../services/cookie_bridge.dart';
import '../../services/cookie_store.dart';
import 'platform_login_screen.dart';

/// 各平台登录页 URL 与 cookie 域映射（sourceKey → 登录信息）
const Map<String, ({String loginUrl, String cookieUrl})> kPlatformLoginInfo = {
  'wy': (loginUrl: 'https://music.163.com/', cookieUrl: 'https://music.163.com'),
  'tx': (loginUrl: 'https://y.qq.com/', cookieUrl: 'https://y.qq.com'),
  'kg': (loginUrl: 'https://www.kugou.com/', cookieUrl: 'https://www.kugou.com'),
  'kw': (loginUrl: 'https://www.kuwo.cn/', cookieUrl: 'https://www.kuwo.cn'),
  'mg': (loginUrl: 'https://www.migu.cn/', cookieUrl: 'https://www.migu.cn'),
};

/// 账号中心：管理各内置平台的登录态
class AccountCenterScreen extends ConsumerWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(accountCenterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账号中心')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '登录后，内置音源将使用你的账号播放（VIP 歌曲可播）。'
              '登录态仅保存在本机，不会上传。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          for (final platform in kBuiltinPlatforms)
            _PlatformTile(
              platform: platform,
              credential: credentials[platform.sourceKey],
              onLogin: () async {
                final info = kPlatformLoginInfo[platform.sourceKey]!;
                final cookie = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlatformLoginScreen(
                      platformKey: platform.sourceKey,
                      platformName: platform.name,
                      loginUrl: info.loginUrl,
                      cookieUrl: info.cookieUrl,
                    ),
                  ),
                );
                if (cookie != null && cookie.isNotEmpty) {
                  ref
                      .read(accountCenterProvider.notifier)
                      .setCookie(platform.sourceKey, cookie);
                }
              },
              onLogout: () {
                ref
                    .read(accountCenterProvider.notifier)
                    .logout(platform.sourceKey);
                CookieBridge.clearCookie();
              },
            ),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final BuiltinPlatform platform;
  final AccountCredential? credential;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _PlatformTile({
    required this.platform,
    required this.credential,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final loggedIn = credential?.isLoggedIn ?? false;
    final dateText = loggedIn
        ? credential!.loggedInAt.toLocal().toString().substring(0, 10)
        : '';
    return ListTile(
      leading: CircleAvatar(child: Text(platform.name.substring(0, 1))),
      title: Text(platform.name),
      subtitle: Text(loggedIn ? '已登录 $dateText' : '未登录'),
      trailing: loggedIn
          ? TextButton(onPressed: onLogout, child: const Text('退出'))
          : TextButton(onPressed: onLogin, child: const Text('登录')),
    );
  }
}
