import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

/// 网易云 weapi 参数加密（AES-CBC + raw RSA）与播放 URL 请求
///
/// 与网易云 web 端 / lx-music / listen1 的 weapi 实现一致：
/// 1. 明文 params（JSON）用固定 key `0CoJUm6Qyw8W8jud` + iv `0102030405060708`
///    AES-128-CBC（PKCS7 padding）加密 → base64
/// 2. 随机 16 字符 key 对该 base64 串再次 AES-128-CBC 加密 → base64（params）
/// 3. encSecKey = 随机 key 反转后 raw RSA（无 padding，网易公钥 modPow）→ 256 hex（128 字节）
/// 4. POST body：`{"params": <params>, "encSecKey": <encSecKey>}`
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

  /// 请求 VIP 高音质播放 URL（需登录 cookie，`MUSIC_U` 为会员关键）
  ///
  /// 成功返回可直接播放的 URL；失败/无可用 url 返回 null。
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
      final paramsSecond = aesEncrypt(paramsFirst, key, _aesIv);
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
      final data = (resp.data is Map) ? (resp.data as Map) : const {};
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

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
