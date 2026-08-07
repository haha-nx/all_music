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

  /// 生成 QQ 音乐设备 guid（时间戳 + 随机数，取 10 位）
  static String generateGuid() {
    return (DateTime.now().millisecondsSinceEpoch.toString() +
            Random().nextInt(1000).toString())
        .substring(0, 10);
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
