// 平台登录态 cookie 分析工具
//
// 处理三个问题：
// 1. 各平台登录 cookie 可能分散在多个域（QQ 微信登录跨 y.qq.com / u.y.qq.com /
//    graph.qq.com），需要合并去重；
// 2. 登录页抓到的 cookie 可能不含关键登录键（如网易云 MUSIC_U、QQ 的
//    wxopenid/wxskey）——WebView 渲染进程崩溃或未等待跳转完成时常见，
//    这类 cookie 保存后必然播放失败，需要提前识别；
// 3. 账号中心据此展示登录态诊断。

/// 各平台需要抓取的 cookie 域（合并顺序敏感，后者域补充前者缺失的键）
const Map<String, List<String>> kPlatformCookieUrls = {
  'wy': ['https://music.163.com'],
  'tx': ['https://y.qq.com', 'https://u.y.qq.com', 'https://graph.qq.com'],
};

/// 单条登录关键键规则：label 用于展示，pattern 匹配 cookie 中的键
class LoginKeyRule {
  final String label;
  final RegExp pattern;

  const LoginKeyRule(this.label, this.pattern);
}

/// 各平台登录态关键键（缺失任一即视为登录态不完整）
///
/// 注意：RegExp 无 const 构造函数，此 map 用 final 而非 const。
final Map<String, List<LoginKeyRule>> kPlatformLoginKeys = {
  'wy': [
    // 网易云登录态核心键（HttpOnly，CookieManager 可读）
    LoginKeyRule('MUSIC_U', RegExp(r'(?:^|;)\s*MUSIC_U=')),
  ],
  'tx': [
    // QQ 号登录：uin/qqmusic_uin/p_uin；微信登录：wxuin/wxopenid
    LoginKeyRule(
      'uin/wxuin/wxopenid',
      RegExp(r'(?:^|;)\s*(?:uin|qqmusic_uin|p_uin|wxuin|wxopenid)='),
    ),
    // 播放授权键（musicu.fcg 的 comm.authst 来源）
    LoginKeyRule(
      'qm_keyst/qqmusic_key/wxskey',
      RegExp(r'(?:^|;)\s*(?:qm_keyst|qqmusic_key|music_key|wxskey)='),
    ),
  ],
};

/// 合并多域 cookie 串：同名键去重（保留最后一个），返回 `k=v; k2=v2` 格式
String mergeCookies(Iterable<String> cookies) {
  final merged = <String, String>{};
  for (final c in cookies) {
    if (c.isEmpty) continue;
    for (final part in c.split(';')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      final eq = token.indexOf('=');
      final key = eq < 0 ? token : token.substring(0, eq).trim();
      merged[key] = token;
    }
  }
  return merged.values.join('; ');
}

/// 返回缺失的登录关键键 label 列表（空列表 = 登录态完整）
List<String> missingLoginKeys(String platformKey, String cookie) {
  final rules = kPlatformLoginKeys[platformKey] ?? const <LoginKeyRule>[];
  return [
    for (final r in rules)
      if (!r.pattern.hasMatch(cookie)) r.label,
  ];
}

/// 判定某平台登录态是否有效（无规则平台视为有效）
bool isValidLogin(String platformKey, String cookie) =>
    missingLoginKeys(platformKey, cookie).isEmpty;
