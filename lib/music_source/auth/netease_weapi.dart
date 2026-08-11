import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import '../builtin/builtin_search_helpers.dart';

/// 网易云 weapi 参数加密（AES-CBC + raw RSA）与登录态接口请求
///
/// 与网易云 web 端 / lx-music / listen1 的 weapi 实现一致：
/// 1. 明文 params（JSON）用固定 key `0CoJUm6Qyw8W8jud` + iv `0102030405060708`
///    AES-128-CBC（PKCS7 padding）加密 → base64
/// 2. 随机 16 字符 key 对该 base64 串再次 AES-128-CBC 加密 → base64（params）
/// 3. encSecKey = 随机 key 反转后 raw RSA（无 padding，网易公钥 modPow）→ 256 hex（128 字节）
/// 4. POST body：`{"params": <params>, "encSecKey": <encSecKey>}`
///
/// 覆盖接口：
/// - 播放 URL：/weapi/song/enhance/player/url/v1
/// - 账号 uid：/weapi/nuser/account/get
/// - 用户歌单列表：/weapi/user/playlist
/// - 歌单详情：/weapi/v6/playlist/detail
class NeteaseWeapi {
  static const _aesKey = '0CoJUm6Qyw8W8jud';
  static const _aesIv = '0102030405060708';

  static const _rsaModulus =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7'
      'b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280'
      '104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932'
      '575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b'
      '3ece0462db0a22b8e7';
  static const _rsaExponent = '010001';

  /// 生成随机 16 字符 key（hex 字符集；UTF-8 编码后恰为 16 字节，作 AES-128 key 与 RSA 输入）
  static String randomKey() {
    const chars = '0123456789abcdef';
    final rng = Random.secure();
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      sb.write(chars[rng.nextInt(chars.length)]);
    }
    return sb.toString();
  }

  /// AES-128-CBC 加密（PKCS7 padding，返回 base64）
  ///
  /// [key] 与 [iv] 均为 ASCII 字符串（如 `0CoJUm6Qyw8W8jud` / `0102030405060708`），
  /// UTF-8 编码后各为 16 字节。
  static String aesEncrypt(String plain, String key, String iv) {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final ivBytes = Uint8List.fromList(utf8.encode(iv));
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(keyBytes), ivBytes));

    final input = Uint8List.fromList(utf8.encode(plain));
    final padLen = 16 - (input.length % 16);
    final padded = Uint8List(input.length + padLen)..setAll(0, input);
    for (var i = input.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    final out = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      cipher.processBlock(padded, offset, out, offset);
      offset += 16;
    }
    return base64Encode(out);
  }

  /// raw RSA（无 padding）加密：key 反转后 modPow(网易公钥)，返回 256 hex（128 字节）
  ///
  /// 网易公钥为 1024 位，raw RSA 输出固定 128 字节 → 256 个 hex 字符。
  static String rsaEncrypt(String key) {
    final reversed = key.split('').reversed.join();
    final m = BigInt.parse(_toHex(utf8.encode(reversed)), radix: 16);
    final n = BigInt.parse(_rsaModulus, radix: 16);
    final e = BigInt.parse(_rsaExponent, radix: 16);
    return m.modPow(e, n).toRadixString(16).padLeft(256, '0');
  }

  /// 通用 weapi POST：加密参数并请求 [path]，返回解析后的 JSON Map
  ///
  /// [path] 以 `/weapi/...` 开头；已带的 query（如 `?uid=xxx`）保留，
  /// csrf_token 自动追加。网络失败 / 非 JSON 响应返回 null。
  static Future<Map<String, dynamic>?> weapiPost(
    Dio dio, {
    required String path,
    required Map<String, dynamic> params,
    String? cookie,
  }) async {
    try {
      final csrf = _extractCsrf(cookie ?? '');
      final fullParams = {...params, 'csrf_token': csrf};
      final key = randomKey();
      final paramsFirst = aesEncrypt(jsonEncode(fullParams), _aesKey, _aesIv);
      final paramsSecond = aesEncrypt(paramsFirst, key, _aesIv);
      final encSecKey = rsaEncrypt(key);
      final body = {'params': paramsSecond, 'encSecKey': encSecKey};
      final query =
          path.contains('?') ? '&csrf_token=$csrf' : '?csrf_token=$csrf';
      final resp = await dio.post<String>(
        'https://music.163.com$path$query',
        data: body,
        options: Options(
          headers: {
            // 与 NeteaseCloudMusicApi weapi 一致：完整浏览器 UA 降低风控拦截
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://music.163.com/',
            'Cookie': cookie ?? '',
          },
          contentType: 'application/x-www-form-urlencoded',
          // 响应可能是 text/plain，需手动解码（同 musicu.fcg 场景）
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final text = resp.data;
      if (text == null || text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 请求 VIP 高音质播放 URL（需登录 cookie，`MUSIC_U` 为会员关键）
  ///
  /// 成功返回可直接播放的 URL；失败/无可用 url 返回 null。
  static Future<String?> musicUrl(
    Dio dio, {
    required String songId,
    String? cookie,
    String quality = '320k',
  }) async {
    final params = <String, dynamic>{
      'ids': '[$songId]',
      // 与 NeteaseCloudMusicApi song_url_v1 一致：flac→lossless 无损、
      // 320k→exhigh 极高、128k→standard 标准
      'level': switch (quality) {
        'flac' => 'lossless',
        '320k' => 'exhigh',
        _ => 'standard',
      },
      // song_url_v1 固定参数（Mineradio 同款），缺省时部分歌曲会退化为试听
      'encodeType': 'flac',
    };
    final data = await weapiPost(
      dio,
      path: '/weapi/song/enhance/player/url/v1',
      params: params,
      cookie: cookie,
    );
    if (data == null) return null;
    final urls = data['data'] is List ? data['data'] as List : const [];
    for (final u in urls.whereType<Map>()) {
      final url = u['url']?.toString() ?? '';
      if (url.isEmpty) continue;
      // 探测可播性：weapi 可能返回失效/试听地址（404），先验证再返回
      final ok =
          await probeAudioUrl(dio, url, referer: 'https://music.163.com/');
      if (ok != null) return ok;
    }
    return null;
  }

  /// 获取当前登录账号的 uid（需登录 cookie）
  ///
  /// 请求 /weapi/nuser/account/get，返回 `profile.userId`；失败返回 null。
  static Future<String?> accountUid(
    Dio dio, {
    String? cookie,
  }) async {
    if (cookie == null || cookie.isEmpty) return null;
    final data = await weapiPost(
      dio,
      path: '/weapi/nuser/account/get',
      params: const {},
      cookie: cookie,
    );
    final profile = (data?['profile'] as Map?)?.cast<String, dynamic>();
    final uid = profile?['userId'];
    return uid?.toString();
  }

  /// 用户歌单列表（含「我喜欢的音乐」，specialType == 5）
  ///
  /// 请求 /weapi/user/playlist?uid=xxx，返回 playlist 数组（空数组表示失败）。
  static Future<List<Map<String, dynamic>>> userPlaylists(
    Dio dio, {
    required String uid,
    String? cookie,
    int limit = 100,
  }) async {
    if (cookie == null || cookie.isEmpty) return const [];
    final data = await weapiPost(
      dio,
      path: '/weapi/user/playlist?uid=$uid',
      params: {
        'uid': int.tryParse(uid) ?? uid,
        'limit': limit,
        'offset': 0,
      },
      cookie: cookie,
    );
    final list = (data?['playlist'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  /// 歌单详情（含歌曲列表）
  ///
  /// 请求 /weapi/v6/playlist/detail?id=xxx，返回 playlist 对象；失败返回 null。
  /// 注意：新版接口的 playlist.tracks 可能为空（只返回 trackIds），
  /// 完整歌曲需再调 [playlistTrackIds] + [songDetail]。
  static Future<Map<String, dynamic>?> playlistDetail(
    Dio dio, {
    required String playlistId,
    String? cookie,
    int n = 1000,
  }) async {
    if (cookie == null || cookie.isEmpty) return null;
    final data = await weapiPost(
      dio,
      path: '/weapi/v6/playlist/detail?id=$playlistId',
      params: {
        'id': int.tryParse(playlistId) ?? playlistId,
        'n': n,
        's': 8,
      },
      cookie: cookie,
    );
    final pl = data?['playlist'];
    if (pl is Map) return pl.cast<String, dynamic>();
    return null;
  }

  /// 歌单歌曲 id 列表（v6/playlist/detail 的 trackIds）
  ///
  /// 新版接口的 playlist.tracks 常为空，完整歌曲需先取 trackIds，
  /// 再用 [songDetail] 批量拉取详情。失败返回空数组。
  static Future<List<Map<String, dynamic>>> playlistTrackIds(
    Dio dio, {
    required String playlistId,
    String? cookie,
    int n = 100000,
  }) async {
    if (cookie == null || cookie.isEmpty) return const [];
    final data = await weapiPost(
      dio,
      path: '/weapi/v6/playlist/detail?id=$playlistId',
      params: {
        'id': int.tryParse(playlistId) ?? playlistId,
        'n': n,
        's': 8,
      },
      cookie: cookie,
    );
    final pl = data?['playlist'];
    if (pl is! Map) return const [];
    final ids = (pl['trackIds'] as List?) ?? const [];
    return ids
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  /// 批量歌曲详情（v3/song/detail，`c` 参数，每批 ≤500）
  ///
  /// 请求 /weapi/v3/song/detail，body 为 `{"c":"[{\"id\":1},{\"id\":2}]"}`；
  /// 返回 songs 数组；失败返回空数组。
  static Future<List<Map<String, dynamic>>> songDetail(
    Dio dio, {
    required List<String> ids,
    String? cookie,
  }) async {
    if (cookie == null || cookie.isEmpty || ids.isEmpty) return const [];
    const batchSize = 500;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += batchSize) {
      final end = i + batchSize < ids.length ? i + batchSize : ids.length;
      final batch = ids.sublist(i, end);
      final c = '[' +
          batch
              .map((id) => '{"id":${int.tryParse(id) ?? id}}')
              .join(',') +
          ']';
      final data = await weapiPost(
        dio,
        path: '/weapi/v3/song/detail',
        params: {'c': c},
        cookie: cookie,
      );
      final songs = data != null && data['songs'] is List
          ? data['songs'] as List
          : const [];
      result.addAll(
        songs.whereType<Map>().map((m) => m.cast<String, dynamic>()),
      );
    }
    return result;
  }

  static String _extractCsrf(String cookie) {
    final m = RegExp(r'__csrf=([^;]+)').firstMatch(cookie);
    return m?.group(1) ?? '';
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
