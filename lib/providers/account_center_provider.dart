import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cookie_store.dart';

final accountCenterProvider = StateNotifierProvider<AccountCenterNotifier,
    Map<String, AccountCredential>>((ref) => AccountCenterNotifier());

class AccountCenterNotifier
    extends StateNotifier<Map<String, AccountCredential>> {
  AccountCenterNotifier() : super({}) {
    _init();
  }

  final _store = CookieStore();

  Future<void> _init() async {
    try {
      state = await _store.loadAll();
    } catch (_) {}
  }

  /// 生成 QQ 音乐设备 guid（与 Mineradio 一致：8 位随机数）
  ///
  /// 注意：CgiGetVkey 的 vkey 与 guid 绑定，guid 格式必须是 8 位数字，
  /// 时间戳格式（如 1786340479）会导致服务器生成无效 vkey → CDN 404。
  static String generateGuid() {
    return (10000000 + Random().nextInt(90000000)).toString();
  }

  /// 登录后写入 cookie（cookie 由 CookieBridge 从原生抓取）
  Future<void> setCookie(String platformKey, String cookie,
      {String? guid}) async {
    if (cookie.trim().isEmpty) return;
    // QQ 音乐需要设备 guid：为空时自动生成并持久化
    if (platformKey == 'tx' && (guid == null || guid.isEmpty)) {
      guid = generateGuid();
    }
    await _store.saveCredential(platformKey, cookie, guid: guid);
    state = await _store.loadAll();
  }

  Future<void> logout(String platformKey) async {
    await _store.clearCredential(platformKey);
    state = await _store.loadAll();
  }

  AccountCredential? credentialFor(String platformKey) => state[platformKey];
}
