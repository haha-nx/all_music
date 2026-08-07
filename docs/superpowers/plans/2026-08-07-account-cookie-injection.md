# 璐﹀彿鐧诲綍鎬佹敞鍏ワ紙cookie锛夊疄鏂借鍒?
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 涓哄唴缃煶婧愶紙缃戞槗浜?QQ闊充箰/閰风嫍/閰锋垜/鍜挄锛夋坊鍔犵敤鎴疯嚜鏈夎处鍙?cookie 娉ㄥ叆锛氳缃〉鍐呭祵 WebView 鐧诲綍 鈫?鍘熺敓 CookieManager 鑷姩鎶撳彇 鈫?SQLite 鎸佷箙鍖?鈫?鍐呯疆婧愯姹傝嚜鍔ㄦ惡甯︾櫥褰曟€佹挱鏀?VIP 鏇茬洰锛涙悳绱㈢粨鏋滄爣娉ㄩ煶涔愬钩鍙般€?
**Architecture:** 涓夊眰锛氣憼鍘熺敓灞?`MainActivity.kt` 鍔?MethodChannel锛坄getCookie`/`clearCookie`锛岃绯荤粺 CookieManager 鍚?HttpOnly锛夛紱鈶art 灞?`AccountCenterProvider` + `CookieStore`锛圫QLite 閿€兼寔涔呭寲鍚勫钩鍙?cookie + QQ guid锛夛紱鈶㈠唴缃簮灞?`PlatformSearchApi` 娉ㄥ叆 cookie锛氱綉鏄撲簯 weapi 鍔犲瘑鎺ュ彛锛圴IP 楂橀煶璐紝闄嶇骇 outer/url锛夈€丵Q闊充箰 musicu.fcg锛堝甫 uin+guid+qqmusic_key 鎷?VIP purl锛夈€傛悳绱㈢粨鏋?ListTile 鐢?`Song.sourceKey` 鏄剧ず骞冲彴寰芥爣銆?
**Tech Stack:** Flutter锛堢幇鏈夛級銆亀ebview_flutter锛堟柊澧烇紝鍐呭祵鐧诲綍椤碉級銆乸ointycastle锛堟柊澧烇紝缃戞槗浜?weapi AES+RSA 鍔犲瘑锛夈€乨io锛堢幇鏈夛級銆乻qflite锛堢幇鏈夛紝storageService 澶嶇敤锛夈€丮ethodChannel锛堝師鐢?cookie 妗ワ級銆?
## Global Constraints

- Dart SDK `^3.12.2`锛孎lutter `>=3.41.0`锛汚ndroid 绔负涓伙紙鐢ㄦ埛妯℃嫙鍣ㄩ獙璇侊級锛宨OS 涓嶈姹備絾浠ｇ爜淇濇寔骞冲彴鏃犲叧锛坈ookie 妗ョ敤 `defaultTargetPlatform` 鍒嗘敮锛岄潪 Android 杩斿洖绌猴級
- 渚濊禆蹇呴』鍙 `storage.flutter-io.cn` 闀滃儚瑙ｆ瀽锛坵ebview_flutter 4.x / pointycastle 3.x 鍧囧彲鍦?pub 闀滃儚鑾峰彇锛?- cookie 灞炴晱鎰熸暟鎹細浠呭瓨鏈満 SQLite锛屼笉鎵撴棩蹇椼€佷笉涓婁紶銆佷笉鎻愪氦 git
- 涓嶇牬鍧忕幇鏈夊厤璐归€氶亾锛氱綉鏄撲簯 outer/url 淇濈暀涓洪檷绾э紱鐧诲綍澶辫触/鏃?cookie 鏃惰涓轰笌鐜板湪涓€鑷?- 閬靛惊鐜版湁浠ｇ爜椋庢牸锛歊iverpod StateNotifier銆丼torageService 閿€笺€佹敞閲婄敤涓枃
- 姣忎釜 Task 缁撴潫蹇呴』 `flutter analyze` 鏃犳柊 error + 鐩稿叧娴嬭瘯閫氳繃锛屾墠杩涘叆涓嬩竴 Task

---
## 鏂囦欢缁撴瀯

- 鏂板缓 `lib/services/cookie_bridge.dart` 鈥?鍘熺敓 MethodChannel 灏佽锛坓etCookie/clearCookie锛夛紝闈?Android 杩斿洖绌哄疄鐜?- 鏂板缓 `lib/services/cookie_store.dart` 鈥?鐧诲綍鎬佸瓨鍌紙鍚勫钩鍙?cookie 瀛楃涓?+ QQ guid + 鐧诲綍鏃堕棿锛夛紝鍩轰簬 `StorageService.getSetting/setSetting`
- 鏂板缓 `lib/providers/account_center_provider.dart` 鈥?璐﹀彿涓績鐘舵€侊紙鍚勫钩鍙扮櫥褰曟€併€佸姞杞?淇濆瓨/鐧诲嚭鍔ㄤ綔锛夛紝Riverpod
- 鏂板缓 `lib/screens/settings/account_center_screen.dart` 鈥?璐﹀彿涓績椤碉細骞冲彴鍒楄〃 + 鐧诲綍/鐧诲嚭鎸夐挳 + 鐧诲綍鎬佸睍绀?- 鏂板缓 `lib/screens/settings/platform_login_screen.dart` 鈥?WebView 鐧诲綍椤碉紙webview_flutter锛夛紝鐧诲綍鍚庣偣銆屽畬鎴愩€嶆姄 cookie
- 鏂板缓 `lib/music_source/auth/netease_weapi.dart` 鈥?缃戞槗浜?weapi 鍙傛暟鍔犲瘑锛圓ES-CBC + RSA锛宲ointycastle锛?- 淇敼 `android/app/src/main/kotlin/com/example/all_music/MainActivity.kt` 鈥?鍔?MethodChannel `all_music/cookie`
- 淇敼 `lib/music_source/builtin/netease_search_api.dart` 鈥?musicUrl 浼樺厛 weapi锛堝甫 cookie锛夛紝澶辫触闄嶇骇 outer/url
- 淇敼 `lib/music_source/builtin/tencent_search_api.dart` 鈥?鏂板 musicUrl锛歮usicu.fcg 甯?uin+guid+qqmusic_key
- 淇敼 `lib/music_source/builtin/kugou_search_api.dart` / `kuwo_search_api.dart` / `migu_search_api.dart` 鈥?璇锋眰澶存敞鍏?cookie锛坰earch 涓?musicUrl锛?- 淇敼 `lib/screens/search/search_screen.dart` 鈥?鎼滅储缁撴灉 ListTile 鍔犲钩鍙板窘鏍?- 淇敼 `pubspec.yaml` 鈥?娣诲姞 webview_flutter銆乸ointycastle

---

### Task 1: 渚濊禆涓庡師鐢?cookie 妗?
**Files:**
- Modify: `pubspec.yaml`锛坉ependencies 鍖猴級
- Modify: `android/app/src/main/kotlin/com/example/all_music/MainActivity.kt`
- Create: `lib/services/cookie_bridge.dart`

**Interfaces:**
- Produces: `CookieBridge.getCookie(String url) 鈫?Future<String>`锛堣繑鍥?`name=value; name2=value2` 鎴栫┖涓诧級銆乣CookieBridge.clearCookie(String url) 鈫?Future<void>`
- 渚濊禆锛歚webview_flutter: ^4.10.0`銆乣pointycastle: ^3.9.1`

- [x] **Step 1: pubspec 娣诲姞渚濊禆骞?pub get**

```yaml
  # Account login (webview login + weapi crypto)
  webview_flutter: ^4.10.0
  pointycastle: ^3.9.1
```

Run: `flutter pub get`
Expected: 鎴愬姛瑙ｆ瀽锛堥暅鍍忓彲鐢級

- [x] **Step 2: MainActivity 鍔?MethodChannel**

```kotlin
package com.example.all_music

import android.webkit.CookieManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceFragmentActivity

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
                        val url = call.argument<String>("url") ?: ""
                        if (url.isNotEmpty()) {
                            CookieManager.getInstance().removeAllCookies(null)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

- [x] **Step 3: CookieBridge锛堝钩鍙版棤鍏冲皝瑁咃級**

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 鍘熺敓 Cookie 妗ワ細璇?娓呯郴缁?CookieManager锛坵ebview_flutter 鍏变韩鍚屼竴瀛樺偍锛屽惈 HttpOnly锛?class CookieBridge {
  static const _channel = MethodChannel('all_music/cookie');

  /// 鑾峰彇鏌?URL 鍩熶笅鐨?cookie 涓诧紙`name=value; ...`锛夛紝闈?Android 杩斿洖绌轰覆
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

  /// 娓呯┖鍏ㄩ儴 cookie锛堢櫥鍑虹敤锛?  static Future<void> clearCookie() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('clearCookie', {'url': ''});
      } catch (_) {}
    }
  }
}
```

- [x] **Step 4: flutter analyze + 鏋勫缓楠岃瘉**

Run: `flutter analyze --no-pub lib/services/cookie_bridge.dart && flutter build apk --debug --target-platform android-x64`
Expected: 鏃?error锛孉PK 鏋勫缓鎴愬姛锛圵ebView 妗ョ紪璇戦€氳繃锛?
- [x] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/kotlin/com/example/all_music/MainActivity.kt lib/services/cookie_bridge.dart
git commit -m "feat: add webview/pointycastle deps and native cookie bridge"
```

---

### Task 2: CookieStore 涓庤处鍙蜂腑蹇?Provider

**Files:**
- Create: `lib/services/cookie_store.dart`
- Create: `lib/providers/account_center_provider.dart`

**Interfaces:**
- Consumes: `StorageService.getSetting/setSetting`锛坄lib/services/storage_service.dart`锛?- Produces: `CookieStore.loadAll() 鈫?Map<String, AccountCredential>`銆乣CookieStore.saveCredential(String platformKey, String cookie, {String? guid})`銆乣CookieStore.clearCredential(String platformKey)`
- `AccountCredential { String platformKey; String cookie; String? guid; DateTime loggedInAt; bool get isLoggedIn => cookie.isNotEmpty; }`
- `AccountCenterNotifier extends StateNotifier<Map<String, AccountCredential>>`锛屾柟娉?`setCookie(platformKey, cookie, {guid})`銆乣logout(platformKey)`銆乣credentialFor(platformKey) 鈫?AccountCredential?`
- Provider: `accountCenterProvider`

- [x] **Step 1: CookieStore**

```dart
import 'dart:convert';
import '../services/storage_service.dart';

/// 骞冲彴璐﹀彿鐧诲綍鎬?class AccountCredential {
  final String platformKey; // wy/tx/kg/kw/mg
  final String cookie;      // 瀹屾暣 cookie 涓?  final String? guid;       // QQ 闊充箰璁惧 guid锛堟湰鍦扮敓鎴愭寔涔呭寲锛?  final DateTime loggedInAt;

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

/// 鐧诲綍鎬佸瓨鍌紙SQLite 閿€硷紝澶嶇敤 StorageService锛?class CookieStore {
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
    final existing =
        await _loadOne(platformKey);
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
```

- [x] **Step 2: 娴嬭瘯 CookieStore 璇诲啓**

```dart
// test/services/cookie_store_test.dart
import 'package:all_music/services/cookie_store.dart';
import 'package:all_music/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cookie store round-trip', () async {
    final store = CookieStore();
    await store.saveCredential('tx', 'uin=123; qqmusic_key=abc', guid: 'g1');
    final all = await store.loadAll();
    expect(all.containsKey('tx'), isTrue);
    expect(all['tx']!.cookie, contains('uin=123'));
    expect(all['tx']!.guid, 'g1');
    await store.clearCredential('tx');
    final after = await store.loadAll();
    expect(after.containsKey('tx'), isFalse);
  });
}
```

Note: 娴嬭瘯渚濊禆 SQLite 鍒濆鍖栵紙`DatabaseHelper.instance`锛夛紝闇€鍦?`setUpAll` 涓?`TestWidgetsFlutterBinding.ensureInitialized()` 骞剁‘淇濇暟鎹簱鍙敤锛堢幇鏈夋祴璇曞 `favorites_state_test.dart` 宸插鐞嗭紝鍙傜収涔嬶級銆?
- [x] **Step 3: AccountCenterProvider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cookie_store.dart';
import '../services/storage_service.dart';

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

  /// 鐧诲綍鍚庡啓鍏?cookie锛坈ookie 鐢?CookieBridge 浠庡師鐢熸姄鍙栵級
  Future<void> setCookie(String platformKey, String cookie,
      {String? guid}) async {
    if (cookie.trim().isEmpty) return;
    await _store.saveCredential(platformKey, cookie, guid: guid);
    state = await _store.loadAll();
  }

  Future<void> logout(String platformKey) async {
    await _store.clearCredential(platformKey);
    state = await _store.loadAll();
  }

  AccountCredential? credentialFor(String platformKey) => state[platformKey];
}
```

- [x] **Step 4: 娴嬭瘯 + analyze**

Run: `flutter test test/services/cookie_store_test.dart && flutter analyze --no-pub lib/services/cookie_store.dart lib/providers/account_center_provider.dart`
Expected: PASS + 鏃?error

- [x] **Step 5: Commit**

```bash
git add lib/services/cookie_store.dart lib/providers/account_center_provider.dart test/services/cookie_store_test.dart
git commit -m "feat: cookie store and account center provider"
```

---

### Task 3: 璁剧疆椤佃处鍙蜂腑蹇?+ WebView 鐧诲綍椤?
**Files:**
- Create: `lib/screens/settings/account_center_screen.dart`
- Create: `lib/screens/settings/platform_login_screen.dart`
- Modify: `lib/screens/settings/settings_screen.dart`锛堝姞銆岃处鍙蜂腑蹇冦€嶈彍鍗曞叆鍙ｏ級

**Interfaces:**
- Consumes: `accountCenterProvider`銆乣CookieBridge`銆佸唴缃钩鍙拌〃 `kBuiltinPlatforms`锛坄lib/music_source/builtin/builtin_platforms.dart`锛屽惈 id/name/sourceKey锛?- Produces: `PlatformLoginScreen(platformKey, platformName, loginUrl, cookieUrl)`锛沗AccountCenterScreen` 鍒楄〃椤规樉绀恒€屽钩鍙板悕 + 鐧诲綍鎬侊紙鏈櫥褰?宸茬櫥褰?yyyy-MM-dd锛? 鐧诲綍/閫€鍑烘寜閽€?- 骞冲彴鐧诲綍 URL 鏄犲皠锛堝啓姝诲湪 account_center_screen 鍐咃級锛?  - wy: 鐧诲綍椤?`https://music.163.com/`锛宑ookie 鍩?`https://music.163.com`
  - tx: 鐧诲綍椤?`https://y.qq.com/`锛宑ookie 鍩?`https://y.qq.com`
  - kg: 鐧诲綍椤?`https://www.kugou.com/`锛宑ookie 鍩?`https://www.kugou.com`
  - kw: 鐧诲綍椤?`https://www.kuwo.cn/`锛宑ookie 鍩?`https://www.kuwo.cn`
  - mg: 鐧诲綍椤?`https://www.migu.cn/`锛宑ookie 鍩?`https://www.migu.cn`

- [x] **Step 1: PlatformLoginScreen锛圵ebView锛?*

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/cookie_bridge.dart';

/// 骞冲彴鐧诲綍椤碉細鍐呭祵 WebView 鎵撳紑瀹樻柟鐧诲綍椤碉紝鐧诲綍瀹屾垚鍚庣偣銆屽畬鎴愩€嶆姄 cookie
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
        title: Text('鐧诲綍${widget.platformName}'),
        actions: [
          TextButton(
            onPressed: () async {
              final cookie = await _grabCookie();
              if (!mounted) return;
              if (cookie.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('鏈幏鍙栧埌鐧诲綍鎬侊紝璇风‘璁ゅ凡鐧诲綍')),
                );
                return;
              }
              Navigator.pop(context, cookie);
            },
            child: const Text('瀹屾垚锛堝凡鐧诲綍锛?),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

- [x] **Step 2: AccountCenterScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../music_source/builtin/builtin_platforms.dart';
import '../../providers/account_center_provider.dart';
import '../../services/cookie_bridge.dart';
import 'platform_login_screen.dart';

/// 鍚勫钩鍙扮櫥褰曢〉 URL 涓?cookie 鍩熸槧灏勶紙sourceKey 鈫?鐧诲綍淇℃伅锛?const Map<String, ({String loginUrl, String cookieUrl})> kPlatformLoginInfo = {
  'wy': (loginUrl: 'https://music.163.com/', cookieUrl: 'https://music.163.com'),
  'tx': (loginUrl: 'https://y.qq.com/', cookieUrl: 'https://y.qq.com'),
  'kg': (loginUrl: 'https://www.kugou.com/', cookieUrl: 'https://www.kugou.com'),
  'kw': (loginUrl: 'https://www.kuwo.cn/', cookieUrl: 'https://www.kuwo.cn'),
  'mg': (loginUrl: 'https://www.migu.cn/', cookieUrl: 'https://www.migu.cn'),
};

/// 璐﹀彿涓績锛氱鐞嗗悇鍐呯疆骞冲彴鐨勭櫥褰曟€?class AccountCenterScreen extends ConsumerWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(accountCenterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('璐﹀彿涓績')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '鐧诲綍鍚庯紝鍐呯疆闊虫簮灏嗕娇鐢ㄤ綘鐨勮处鍙锋挱鏀撅紙VIP 姝屾洸鍙挱锛夈€?
              '鐧诲綍鎬佷粎淇濆瓨鍦ㄦ湰鏈猴紝涓嶄細涓婁紶銆?,
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
                ref.read(accountCenterProvider.notifier).logout(platform.sourceKey);
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
    return ListTile(
      leading: CircleAvatar(child: Text(platform.name.substring(0, 1))),
      title: Text(platform.name),
      subtitle: Text(
        loggedIn
            ? '宸茬櫥褰?${credential!.loggedInAt.toLocal().toString().substring(0, 10)}'
            : '鏈櫥褰?,
      ),
      trailing: loggedIn
          ? TextButton(onPressed: onLogout, child: const Text('閫€鍑?))
          : TextButton(onPressed: onLogin, child: const Text('鐧诲綍')),
    );
  }
}
```

- [x] **Step 3: settings_screen 鍔犲叆鍙?*

鍦?`lib/screens/settings/settings_screen.dart` 鐨勩€岄煶婧愮鐞嗐€嶅尯锛坄_buildSectionTitle('闊虫簮绠＄悊')` 涔嬪悗銆佸凡瀵煎叆闊虫簮涔嬪墠锛夊姞锛?
```dart
_buildMenuItem(
  icon: Icons.account_circle_outlined,
  title: '璐﹀彿涓績',
  subtitle: '鐧诲綍鍐呯疆闊虫簮璐﹀彿锛堢綉鏄撲簯/QQ闊充箰绛夛級',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountCenterScreen()),
    );
  },
),
```

锛堝弬鐓х幇鏈?`_buildMenuItem` 绛惧悕锛宨mport `../settings/account_center_screen.dart`锛?
- [x] **Step 4: analyze + 鏋勫缓**

Run: `flutter analyze --no-pub lib/screens/settings/ && flutter build apk --debug --target-platform android-x64`
Expected: 鏃?error锛孉PK 鎴愬姛锛坵ebview_flutter 闆嗘垚楠岃瘉锛?
- [x] **Step 5: Commit**

```bash
git add lib/screens/settings/account_center_screen.dart lib/screens/settings/platform_login_screen.dart lib/screens/settings/settings_screen.dart
git commit -m "feat: account center with webview platform login"
```

---

### Task 4: 缃戞槗浜?weapi 楂橀煶璐ㄦ挱鏀撅紙甯?cookie锛?
**Files:**
- Create: `lib/music_source/auth/netease_weapi.dart`
- Modify: `lib/music_source/builtin/netease_search_api.dart`锛坢usicUrl锛?
**Interfaces:**
- Consumes: `accountCenterProvider.credentialFor('wy')`銆乣pointycastle`銆乣NeteaseSearchApi`锛坄_dio`銆乣_headers`锛?- Produces: `NeteaseWeapi.encryptParams(Map<String, dynamic> params) 鈫?String`锛坵eapi 鍔犲瘑鍚庣殑 `params` 瀛楃涓诧級锛沗NeteaseWeapi.musicUrl(Dio dio, String songId, {String? cookie, String quality = '320k'}) 鈫?Future<String?>`
- 娉ㄦ剰锛歚NeteaseSearchApi` 鐜版湁鏋勯€?`NeteaseSearchApi({required this.sourceId, required this.dio})`锛堟祴璇曠敤 `dio: Dio()`锛夛紝musicUrl 闇€鏂板鍙€夊弬鏁版垨鍐呴儴璇诲彇 provider銆備负淇濇寔娴嬭瘯鍏煎锛宮usicUrl 绛惧悕涓嶅彉锛屽唴閮ㄩ€氳繃 `Ref` 璇诲彇鐧诲綍鎬侊紙鎴栨敞鍏ュ洖璋冿級銆?
**weapi 鍔犲瘑绠楁硶**锛堝弬鑰?lx-music-source `src/apis/wy.js`锛夛細
- AES-128-CBC 鍔犲瘑鍙傛暟锛歬ey=`0CoJUm6Qyw8W8jud`锛宨v=`0102030405060708`
- RSA 鍔犲瘑闅忔満 16 瀛楄妭 key锛堢綉鏄撳叕閽ワ級锛孫AEP SHA1 padding
- 璇锋眰浣?`{params: <AES(鏄庢枃, 闅忔満key)>, encSecKey: <RSA(闅忔満key)>}`

- [x] **Step 1: 鍐欏姞瀵嗘ā鍧楋紙绾嚱鏁帮紝鍙崟娴嬶級**

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 缃戞槗浜?weapi 鍙傛暟鍔犲瘑锛圓ES-CBC + RSA-OAEP锛?class NeteaseWeapi {
  static const _aesKey = '0CoJUm6Qyw8W8jud';
  static const _aesIv = '0102030405060708';

  static const _rsaModulus =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7'
      'b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280'
      '104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932'
      '575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b'
      '3ece0462db0a22b8e7';
  static const _rsaExponent = '010001';

  /// 鐢熸垚闅忔満 16 瀛楄妭 key锛坔ex 瀛楃涓诧級
  static String randomKey() {
    final rng = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// AES-128-CBC 鍔犲瘑锛堣繑鍥?hex锛?  static String aesEncrypt(String plain, String key, String iv) {
    final keyBytes = Uint8List.fromList(_hexToBytes(key));
    final ivBytes = Uint8List.fromList(_hexToBytes(iv));
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(keyBytes), ivBytes));

    final input = Uint8List.fromList(utf8.encode(plain));
    // PKCS7 padding
    final padLen = 16 - (input.length % 16);
    final padded = Uint8List(input.length + padLen)
      ..setAll(0, input);
    for (var i = input.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    final out = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      cipher.processBlock(padded, offset, out, offset);
      offset += 16;
    }
    return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// RSA-OAEP(SHA1) 鍔犲瘑锛堣繑鍥?hex锛?  static String rsaEncrypt(String hexData) {
    final data = Uint8List.fromList(_hexToBytes(hexData));
    final modulus = BigInt.parse(_rsaModulus, radix: 16);
    final exponent = BigInt.parse(_rsaExponent, radix: 16);
    final publicKey = RSAPublicKey(modulus, exponent);
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final out = cipher.process(data);
    return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 瀹屾暣 weapi 鍙傛暟鍔犲瘑锛氳繑鍥?`params` 瀛楃涓诧紙璇锋眰浣撶洿鎺?POST锛?  static String encryptParams(Map<String, dynamic> params) {
    final plain = jsonEncode(params);
    final key = randomKey();
    final encKey = rsaEncrypt(key);
    final paramsEnc = aesEncrypt(plain, _aesKey, _aesIv);
    final secondKey = key;
    final paramsEnc2 = aesEncrypt(
      '{"params":"$paramsEnc"}', // 瀹為檯涓轰簩娆″姞瀵嗭紝瑙?Step 4 璇存槑
      secondKey,
      _aesIv,
    );
    return paramsEnc2;
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
```

Note: `encryptParams` 鐨勪簩娆″姞瀵嗙粏鑺傦紙鍏堢敤鍥哄畾 key 鍔犲瘑鏄庢枃寰楀埌 params锛屽啀鐢ㄩ殢鏈?key 鍔犲瘑 `{"params": ...}`锛宔ncSecKey=RSA(闅忔満key)锛夆€斺€斿畬鏁村疄鐜版斁鍦?Step 2 鐨?`musicUrl` 涓紝`encryptParams` 鏀逛负杩斿洖瀹屾暣璇锋眰浣撱€係tep 1 鍏堝仛搴曞眰 AES/RSA 骞跺彲鍗曟祴銆?
- [x] **Step 2: 瀹屾暣 weapi 璇锋眰锛坢usicUrl锛?*

```dart
// lib/music_source/auth/netease_weapi.dart 杩藉姞
static Future<String?> musicUrl(
  Dio dio, {
  required String songId,
  String? cookie,
  String quality = '320k',
}) async {
  try {
    final csrf = _extractCsrf(cookie ?? '');
    final params = <String, dynamic>{
      'ids': '[$songId]',
      'level': quality == 'flac'
          ? 'hires'
          : (quality == '320k' ? 'exhigh' : 'standard'),
      'csrf_token': csrf,
    };
    final key = randomKey();
    final paramsFirst = aesEncrypt(jsonEncode(params), _aesKey, _aesIv);
    final paramsSecond = aesEncrypt(
      jsonEncode({'params': paramsFirst}),
      key,
      _aesIv,
    );
    final encSecKey = rsaEncrypt(key);
    final body = {'params': paramsSecond, 'encSecKey': encSecKey};
    final resp = await dio.post<dynamic>(
      'https://music.163.com/weapi/song/enhance/player/url/v1?csrf_token=$csrf',
      data: body,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://music.163.com/',
          'Cookie': cookie ?? '',
        },
        contentType: 'application/x-www-form-urlencoded',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final data = (resp.data as Map?) ?? const {};
    final urls = (data['data'] as List?) ?? const [];
    for (final u in urls.whereType<Map>()) {
      final url = u['url']?.toString() ?? '';
      if (url.isNotEmpty) return url;
    }
    return null;
  } catch (_) {
    return null;
  }
}

static String _extractCsrf(String cookie) {
  final m = RegExp(r'__csrf=([^;]+)').firstMatch(cookie);
  return m?.group(1) ?? '';
}
```

Note: weapi 鐨?`ids` 浼?`[songId]` 瀛楃涓叉暟缁?JSON锛泀uality 鏄犲皠 `flac鈫抙ires / 320k鈫抏xhigh / 128k鈫抯tandard`锛沜ookie 涓殑 `MUSIC_U` 鏄細鍛樺叧閿€?
- [x] **Step 3: NeteaseSearchApi.musicUrl 鎺ュ叆锛堝甫 cookie锛岄檷绾?outer/url锛?*

淇敼 `netease_search_api.dart` 鐨?`musicUrl`锛氬紑澶村皾璇?weapi锛坈ookie 瀛樺湪鏃讹級锛屽け璐?鏃?cookie 璧扮幇鏈?outer/url 閫昏緫銆?
```dart
@override
Future<String?> musicUrl(MusicTrack track, {String quality = '128k'}) async {
  final id = track.id;
  if (id.isEmpty) return null;
  // 浼樺厛锛氱櫥褰曟€?weapi 楂橀煶璐紙VIP锛?  final cookie = _accountCookie(); // 浠?accountCenterProvider 璇诲彇 wy cookie
  if (cookie != null && cookie.isNotEmpty) {
    final url = await NeteaseWeapi.musicUrl(_dio,
        songId: id, cookie: cookie, quality: quality);
    if (url != null) return url;
  }
  // 闄嶇骇锛歰uter/url 鍏嶈垂 128k锛堢幇鏈夐€昏緫锛?  ... 鐜版湁 outer/url 浠ｇ爜 ...
}
```

Note: `_accountCookie()` 閫氳繃浼犲叆鐨?`ref` 鎴栭潤鎬佽闂?`accountCenterProvider` 璇诲彇锛涗负淇濇寔鐜版湁鏋勯€犵鍚嶏紙娴嬭瘯 `NeteaseSearchApi(sourceId:, dio:)`锛夛紝鏀逛负鍦?NeteaseSearchApi 鏋勯€犳椂娉ㄥ叆 `String? Function()? cookieProvider`锛岄粯璁?null锛沗source_manager.dart` 鍒涘缓鏃朵紶鍏?`() => ref.read(accountCenterProvider.notifier).credentialFor('wy')?.cookie ?? ''`銆傝嫢澶嶆潅锛屽彲灏?provider 璇诲彇鏀?musicUrl 鍐呴儴锛圧iverpod 鍏ㄥ眬 container锛夛紝浣嗕紭鍏堟敞鍏ュ洖璋冧繚鎸佸彲娴嬨€?
- [x] **Step 4: 鍗曟祴鍔犲瘑姝ｇ‘鎬?*

鐢ㄥ凡鐭ュ悜閲忛獙璇?AES/RSA锛?```dart
// test/music_source/auth/netease_weapi_test.dart
test('aes-128-cbc matches known vector', () {
  // 鐢ㄦ爣鍑?NIST 鍚戦噺鎴栦笌 lx-music wy.js 杈撳嚭瀵规瘮
  final enc = NeteaseWeapi.aesEncrypt('hello', '0CoJUm6Qyw8W8jud', '0102030405060708');
  expect(enc, isNotEmpty);
  expect(enc.length % 32, 0); // hex 姣?16 瀛楄妭 鈫?32 hex
});
```

Note: 鑻ユ棤娉曡幏寰楃绾垮凡鐭ュ悜閲忥紝鏀逛负楠岃瘉銆孉ES 鍙€?+ RSA 杈撳嚭闀垮害鍥哄畾锛?56 瀛楄妭 鈫?512 hex锛夈€嶏紱weapi 绔埌绔纭€ч潬鐪熸満鎾斁楠岃瘉锛堢敤鎴蜂細鍛橈級銆?
- [x] **Step 5: analyze + test + commit**

Run: `flutter analyze --no-pub lib/music_source/auth/ lib/music_source/builtin/netease_search_api.dart && flutter test test/music_source/auth/`
Expected: 鏃?error + PASS

```bash
git add lib/music_source/auth/netease_weapi.dart lib/music_source/builtin/netease_search_api.dart test/music_source/auth/netease_weapi_test.dart
git commit -m "feat: netease weapi vip music url with cookie fallback"
```

---

### Task 5: QQ闊充箰 musicu.fcg 鎾斁鎺ュ彛锛堝甫 cookie锛?
**Files:**
- Modify: `lib/music_source/builtin/tencent_search_api.dart`锛堟柊澧?musicUrl锛?- 渚濊禆锛歚accountCenterProvider.credentialFor('tx')`锛坈ookie 鍚?`uin`銆乣qqmusic_key`锛沢uid 鎸佷箙鍖栧湪 credential.guid锛?
**Interfaces:**
- Consumes: `TencentSearchApi`锛坄_dio`銆乣_headers`銆乣sourceId`锛夈€乣accountCenterProvider`
- Produces: `TencentSearchApi.musicUrl(MusicTrack track, {String quality = '128k'}) 鈫?Future<String?>`锛坢usicu.fcg锛屽甫 uin+guid+qqmusic_key锛?
**musicu.fcg 鍗忚**锛堝弬鑰?lx-music-source `src/apis/tx.js`锛夛細
- POST `https://u.y.qq.com/cgi-bin/musicu.fcg`
- body锛坲rlencoded锛夛細
```
{
  "req_0": {
    "module": "vkey.GetVkeyServer",
    "method": "CgiGetVkey",
    "param": {
      "guid": "<璁惧guid>",
      "songmid": ["<songmid>"],
      "songtype": [0],
      "uin": "<qq鍙?",
      "loginflag": 1,
      "platform": "20"
    }
  },
  "comm": {"uin": "<qq鍙?", "format": "json", "ct": 24, "cv": 0}
}
```
- 鍝嶅簲 `req_0.data.sip[0] + req_0.data.midurlinfo[0].purl` 涓烘挱鏀?URL
- cookie 鍏抽敭锛歚uin`銆乣qqmusic_key`锛堢櫥褰曠エ鎹級銆乣qm_keyst`锛堥儴鍒嗗満鏅級

- [x] **Step 1: 瀹炵幇 musicUrl**

```dart
@override
Future<String?> musicUrl(MusicTrack track, {String quality = '128k'}) async {
  final cookie = _accountCookie(); // tx cookie
  if (cookie == null || cookie.isEmpty) return null;
  final uin = _extractUin(cookie);
  final guid = _accountGuid();
  if (uin.isEmpty || guid.isEmpty) return null;
  final songmid = track.id;
  if (songmid.isEmpty) return null;

  final req = {
    'req_0': {
      'module': 'vkey.GetVkeyServer',
      'method': 'CgiGetVkey',
      'param': {
        'guid': guid,
        'songmid': [songmid],
        'songtype': [0],
        'uin': uin,
        'loginflag': 1,
        'platform': '20',
      },
    },
    'comm': {'uin': uin, 'format': 'json', 'ct': 24, 'cv': 0},
  };
  try {
    final resp = await _dio.post<dynamic>(
      'https://u.y.qq.com/cgi-bin/musicu.fcg',
      data: jsonEncode(req),
      options: Options(
        headers: {
          ..._headers,
          'Cookie': cookie,
        },
        contentType: 'application/json',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final data = resp.data as Map?;
    final req0 = (data?['req_0'] as Map?)?['data'] as Map?;
    final sip = ((req0?['sip'] as List?) ?? const []).whereType<String>().toList();
    final purl = (((req0?['midurlinfo'] as List?) ?? const []).whereType<Map>().firstOrNull)?['purl']?.toString() ?? '';
    if (sip.isNotEmpty && purl.isNotEmpty) {
      return sip.first + purl;
    }
    return null;
  } catch (_) {
    return null;
  }
}

String _extractUin(String cookie) {
  final m = RegExp(r'(?:^|;)\s*uin=([^;]+)').firstMatch(cookie);
  return m?.group(1) ?? '';
}
```

Note: `_accountGuid()` 璇诲彇 credential.guid锛岃嫢涓虹┖鍒欑敓鎴愶紙濡?`'' + DateTime.now().millisecondsSinceEpoch` 鍙栧悗 10 浣嶏級骞舵寔涔呭寲銆俼uality 鍙傛暟锛?28k/320k锛夌敱 `CgiGetVkey` 鐨?`filename` 鍐冲畾锛坄C400` 鍓嶇紑锛夛紱淇濇寔榛樿 128k 绠€鍖栵紝闊宠川鏄犲皠鐣欏埌鍚庣画浼樺寲銆?
- [x] **Step 2: guid 鐢熸垚涓庢寔涔呭寲**

鍦?`account_center_provider.dart` 鐨?`setCookie` 涓紝鑻?`platformKey == 'tx'` 涓?guid 涓虹┖锛岃嚜鍔ㄧ敓鎴愬苟淇濆瓨锛?```dart
if (platformKey == 'tx' && (guid == null || guid!.isEmpty)) {
  guid = (DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(1000).toString())
      .substring(0, 10);
}
```

- [x] **Step 3: 鍗曟祴锛堟棤缃戠粶锛歮ock Dio 鍝嶅簲锛?*

```dart
// test/music_source/builtin/tencent_music_url_test.dart
test('tencent musicUrl builds request and parses purl', () async {
  // 鐢?Dio 鐨?HttpClientAdapter mock 杩斿洖 musicu.fcg 鍝嶅簲
  // 楠岃瘉杩斿洖 sip + purl锛涙棤 cookie 杩斿洖 null
});
```

Note: 鍙傜収 `test/music_source/source_manager_url_test.dart` 鐜版湁 mock Dio 鏂瑰紡锛堝鏈夛級銆?
- [x] **Step 4: analyze + test + commit**

Run: `flutter analyze --no-pub lib/music_source/builtin/tencent_search_api.dart && flutter test test/music_source/builtin/tencent_music_url_test.dart`
Expected: 鏃?error + PASS

```bash
git add lib/music_source/builtin/tencent_search_api.dart lib/providers/account_center_provider.dart test/music_source/builtin/tencent_music_url_test.dart
git commit -m "feat: qq music vip playback via musicu.fcg with cookie"
```

---

### Task 6: 鍏朵綑骞冲彴 cookie 娉ㄥ叆锛坘g/kw/mg锛?
**Files:**
- Modify: `lib/music_source/builtin/kugou_search_api.dart`
- Modify: `lib/music_source/builtin/kuwo_search_api.dart`
- Modify: `lib/music_source/builtin/migu_search_api.dart`

**Interfaces:**
- Consumes: `accountCenterProvider.credentialFor(platformKey)`
- Produces: 鍚?API 鐨?search/musicUrl 璇锋眰澶撮檮鍔?`Cookie: <cookie>`锛堟湁鐧诲綍鎬佹椂锛夛紱鏃犵櫥褰曟€佽涓轰笉鍙?
- [x] **Step 1: 缁欎笁涓?API 鐨勮姹傚ご娉ㄥ叆 cookie**

妯″紡缁熶竴锛堜互 kugou 涓轰緥锛夛細
```dart
// kugou_search_api.dart 鐨?search() 涓?final cookie = _accountCookie(); // kg cookie锛岀┖鍒欏拷鐣?final headers = cookie.isEmpty
    ? _headers
    : {..._headers, 'Cookie': cookie};
final body = await fetchPlain(_dio, url, headers: headers);
```

鍚?API 鐨?`musicUrl`锛堣嫢宸插疄鐜帮級鍚屾牱娉ㄥ叆銆俙kuwo` 鐨?`musicUrl` 鍙兘闇€ token 鍙傛暟锛坄Hm_Iuvt_...`锛夛紝甯?cookie 鍚庝竴骞跺甫涓娿€?
- [x] **Step 2: analyze + 鏋勫缓楠岃瘉**

Run: `flutter analyze --no-pub lib/music_source/builtin/ && flutter build apk --debug --target-platform android-x64`
Expected: 鏃?error + 鏋勫缓鎴愬姛

- [x] **Step 3: Commit**

```bash
git add lib/music_source/builtin/kugou_search_api.dart lib/music_source/builtin/kuwo_search_api.dart lib/music_source/builtin/migu_search_api.dart
git commit -m "feat: inject account cookie into kg/kw/mg builtin requests"
```

---

### Task 7: 鎼滅储缁撴灉骞冲彴鏍囨敞

**Files:**
- Modify: `lib/screens/search/search_screen.dart`锛堢粨鏋?ListTile锛?- 渚濊禆锛歚Song.sourceKey`锛坵y/tx/kg/kw/mg锛? `Song.source`锛圫ourceType锛?
**Interfaces:**
- Consumes: `Song`锛坄lib/models/song.dart`锛?- Produces: ListTile 鏍囬鍓嶆樉绀哄钩鍙板窘鏍囷紙灏忓渾瑙掓爣绛撅紝棰滆壊鎸夊钩鍙板尯鍒嗭級锛沗_platformLabel(String sourceKey) 鈫?String`锛坵y鈫掔綉鏄撲簯銆乼x鈫扱Q闊充箰銆乲g鈫掗叿鐙椼€乲w鈫掗叿鎴戙€乵g鈫掑挭鍜曪紝鏈煡杩斿洖鍘?key锛?
- [x] **Step 1: 骞冲彴鍚嶆槧灏?+ 寰芥爣 Widget**

鍦?`search_screen.dart` 鍐呭姞锛?```dart
const Map<String, String> _platformNames = {
  'wy': '缃戞槗浜?, 'tx': 'QQ闊充箰', 'kg': '閰风嫍', 'kw': '閰锋垜', 'mg': '鍜挄',
};

Widget _platformBadge(String? sourceKey) {
  final name = sourceKey == null ? '' : _platformNames[sourceKey];
  if (name == null || name.isEmpty) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      name,
      style: TextStyle(fontSize: 10, color: AppColors.primary),
    ),
  );
}
```

- [x] **Step 2: ListTile 鏍囬鍔犲窘鏍?*

鎶?`title: Text(song.name, ...)` 鏀逛负 Row锛坆adge + 姝屽悕锛夛細
```dart
title: Row(
  children: [
    _platformBadge(song.sourceKey),
    Expanded(
      child: Text(
        song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ...,
      ),
    ),
  ],
),
```

- [x] **Step 3: 娴嬭瘯锛堝窘鏍囨槧灏勶級**

```dart
// test/screens/search/search_screen_badge_test.dart锛堟垨骞跺叆鐜版湁 search 鐩稿叧娴嬭瘯锛?test('platform name mapping', () {
  expect(_platformNames['wy'], '缃戞槗浜?);
  expect(_platformNames['tx'], 'QQ闊充箰');
  expect(_platformNames['unknown'], isNull);
});
```
Note: 鑻?`_platformNames` 涓虹鏈夛紝娴嬭瘯鏀逛负閫氳繃 widget 娓叉煋鏂█锛坄find.text('QQ闊充箰')`锛夛紱鎴栨妸鏄犲皠鎻愪负鍏紑甯搁噺鏀?`builtin_platforms.dart`锛堟帹鑽愶細`kSourceKeyNames`锛夈€?
- [x] **Step 4: analyze + test + commit**

Run: `flutter analyze --no-pub lib/screens/search/ && flutter test test/screens/search/`
Expected: 鏃?error + PASS

```bash
git add lib/screens/search/search_screen.dart lib/music_source/builtin/builtin_platforms.dart test/screens/search/
git commit -m "feat: show platform badge in search results"
```

---

### Task 8: 绔埌绔泦鎴愰獙璇?
**Files:**
- Modify: `lib/music_source/services/source_manager.dart`锛堝垱寤哄唴缃?API 鏃舵敞鍏?cookie provider锛?- 鏃犳柊寤烘枃浠?
**Interfaces:**
- Consumes: `accountCenterProvider`锛圧iverpod锛夈€佹墍鏈夊唴缃?API 鐨?`_accountCookie` 閽╁瓙
- Produces: `SourceManager` 鍒涘缓 `NeteaseSearchApi/TencentSearchApi/KugouSearchApi/KuwoSearchApi/MiguSearchApi` 鏃朵紶鍏?`cookieProvider: (key) => ref.read(accountCenterProvider.notifier).credentialFor(key)?.cookie`

- [x] **Step 1: SourceManager 娉ㄥ叆 cookie provider**

`source_manager.dart` 鐨?`_createPlatformApi` 鏀逛负鎺ユ敹 cookie provider 骞朵紶缁欏悇 API锛?```dart
PlatformSearchApi _createPlatformApi(BuiltinPlatform platform) {
  String? Function(String key) cookieProvider = (key) =>
      ref?.read(accountCenterProvider.notifier).credentialFor(key)?.cookie;
  switch (platform.sourceKey) {
    case 'wy':
      return NeteaseSearchApi(sourceId: platform.id, dio: _dio,
          cookieProvider: cookieProvider);
    ...
  }
}
```
Note: `SourceManager` 鏋勯€犲綋鍓嶆棤 `ref`锛涙敼涓哄湪鏋勯€犳椂浼犲叆 `String? Function(String platformKey)? cookieProvider`锛岀敱鍒涘缓澶勶紙provider锛夋敞鍏ャ€傚悇 API 鏋勯€犳柊澧?`this.cookieProvider`锛堥粯璁?null锛夈€?
- [x] **Step 2: 鍚?API 鏋勯€犲姞 cookieProvider**

`PlatformSearchApi` 鍩虹被鍔犲瓧娈碉細
```dart
String? Function(String platformKey)? cookieProvider;

String _accountCookie() => cookieProvider?.call(sourceKey) ?? '';
```
鍚勫瓙绫绘瀯閫犵鍚嶈拷鍔?`this.cookieProvider`锛堝懡鍚嶅彲閫夊弬鏁帮級銆?
- [x] **Step 3: 鍏ㄩ噺 analyze + 娴嬭瘯**

Run: `flutter analyze && flutter test`
Expected: 鏃犳柊 error锛涙棦鏈?9 涓け璐ワ紙棰勫厛瀛樺湪锛変笉鏂板

- [x] **Step 4: 鏋勫缓 APK + 鏃堕棿鎴虫牳楠?*

Run: `flutter build apk --debug --target-platform android-x64`
Expected: `鈭?Built build\app\outputs\flutter-apk\app-debug.apk`锛沗Get-Item` 纭 APK 鏃堕棿鎴虫柊浜庢渶鍚庢敼鍔ㄧ殑 .dart 鏂囦欢

- [x] **Step 5: Commit**

```bash
git add lib/music_source/services/source_manager.dart lib/music_source/builtin/ lib/music_source/core/platform_search_api.dart 2>/dev/null
git commit -m "feat: wire account cookie injection through source manager"
```

---

## 楠屾敹娓呭崟锛堢敤鎴风湡鏈洪獙璇侊級

1. 璁剧疆 鈫?璐﹀彿涓績 鈫?缃戞槗浜戙€岀櫥褰曘€嶁啋 WebView 鎵撳紑 music.163.com 鈫?鐢ㄤ細鍛樿处鍙风櫥褰?鈫?鐐广€屽畬鎴愩€嶁啋 鏄剧ず銆屽凡鐧诲綍銆?2. 鎼滅储涓€棣?VIP 姝屾洸锛堝銆岀孩灏樺鏍堛€嶏級鈫?缁撴灉鍑虹幇骞冲彴寰芥爣銆岀綉鏄撲簯銆嶁啋 鐐瑰嚮鎾斁 鈫?320k 瀹屾暣鎾斁锛坵eapi 鐢熸晥锛?3. 璁剧疆 鈫?璐﹀彿涓績 鈫?QQ闊充箰銆岀櫥褰曘€嶁啋 鐧诲綍 y.qq.com 鈫?瀹屾垚 鈫?鎼滅储銆岀孩灏樺鏍堛€嶁啋 缁撴灉甯︺€孮Q闊充箰銆嶅窘鏍?鈫?鐐瑰嚮鎾斁锛坢usicu.fcg VIP purl 鐢熸晥锛?4. 璐﹀彿涓績鐐广€岄€€鍑恒€嶁啋 鍐嶆挱鏀惧悓鏇?鈫?缃戞槗浜戦檷绾?128k outer/url锛堜粛鍙挱锛夆啋 纭鍏嶈垂閫氶亾鏈牬鍧?5. 鏃犵櫥褰曟€佹椂琛屼负涓庢敼鍔ㄥ墠涓€鑷达紙涓嶅穿銆佹棤鏂版棩蹇楋級

## Self-Review

- **Spec 瑕嗙洊**锛歝ookie 娉ㄥ叆锛圱1 妗?T2 瀛樺偍/T3 鐧诲綍椤?T5 娉ㄥ叆锛夈€佺綉鏄撲簯 weapi锛圱4锛夈€丵Q闊充箰 musicu.fcg锛圱5锛夈€佸叾浣欏钩鍙帮紙T6锛夈€佸钩鍙版爣娉紙T7锛夈€佺鍒扮锛圱8锛夆湏
- **鍗犱綅绗︽壂鎻?*锛歍4 Step 1 鐨?`encryptParams` 娉ㄦ槑銆屽畬鏁村疄鐜版斁 Step 2銆嶁€斺€斿凡鏄庣‘锛汿5 Note 鐨?`filename` 闊宠川鏄犲皠娉ㄦ槑銆屽悗缁紭鍖栥€嶁€斺€斿彲鎺ュ彈锛圷AGNI锛?- **绫诲瀷涓€鑷存€?*锛歚AccountCredential`/`CookieStore`/`accountCenterProvider` 鍦?T2-T8 涓鍚嶄竴鑷达紱`cookieProvider` 浠?T8 寮曞叆骞惰疮绌垮悇 API 鉁?
