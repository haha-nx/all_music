import 'dart:convert';
import 'storage_service.dart';

/// 平台账号登录态
class AccountCredential {
  final String platformKey; // wy/tx/kg/kw/mg
  final String cookie;      // 完整 cookie 串
  final String? guid;       // QQ 音乐设备 guid（本地生成持久化）
  final DateTime loggedInAt;

  const AccountCredential({
    required this.platformKey,
    required this.cookie,
    this.guid,
    required this.loggedInAt,
  });

  bool get isLoggedIn => cookie.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'platformKey': platformKey,
        'cookie': cookie,
        'guid': guid,
        'loggedInAt': loggedInAt.toIso8601String(),
      };

  factory AccountCredential.fromJson(Map<String, dynamic> json) =>
      AccountCredential(
        platformKey: json['platformKey'] as String,
        cookie: (json['cookie'] as String?) ?? '',
        guid: json['guid'] as String?,
        loggedInAt:
            DateTime.tryParse((json['loggedInAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}

/// 登录态存储（SQLite 键值，复用 StorageService）
class CookieStore {
  static const _prefix = 'account_credential_';

  Future<Map<String, AccountCredential>> loadAll() async {
    final result = <String, AccountCredential>{};
    for (final key in const ['wy', 'tx', 'kg', 'kw', 'mg']) {
      final raw = await storageService.getSetting('$_prefix$key');
      if (raw == null || raw.isEmpty) continue;
      try {
        final c = AccountCredential.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        if (c.isLoggedIn) result[key] = c;
      } catch (_) {}
    }
    return result;
  }

  Future<void> saveCredential(String platformKey, String cookie,
      {String? guid}) async {
    final existing = await _loadOne(platformKey);
    final cred = AccountCredential(
      platformKey: platformKey,
      cookie: cookie,
      guid: guid ?? existing?.guid,
      loggedInAt: DateTime.now(),
    );
    await storageService
        .setSetting('$_prefix$platformKey', jsonEncode(cred.toJson()));
  }

  Future<void> clearCredential(String platformKey) async {
    await storageService.setSetting('$_prefix$platformKey', '');
  }

  Future<AccountCredential?> _loadOne(String platformKey) async {
    final raw = await storageService.getSetting('$_prefix$platformKey');
    if (raw == null || raw.isEmpty) return null;
    try {
      return AccountCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
