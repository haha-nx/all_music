import 'dart:convert';

import 'package:dio/dio.dart';

/// 用 plain 模式请求，返回响应体；失败或非 200 返回 null
Future<String?> fetchPlain(
  Dio dio,
  String url, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    final resp = await dio.get<String>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.plain,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: timeout,
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    if (resp.statusCode != 200 ||
        resp.data == null ||
        resp.data!.trim().isEmpty) {
      return null;
    }
    return resp.data;
  } on DioException {
    return null;
  }
}

/// 安全解析 JSON 对象；HTML/非 JSON 返回 null
Map<String, dynamic>? decodeJsonObject(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// 从 List<Map> 中取 name 字段并拼接
String joinNames(List<dynamic>? items, {String key = 'name'}) {
  if (items == null) return '';
  return items
      .whereType<Map>()
      .map((m) => (m[key] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .join('/');
}

/// 秒转毫秒
int? secondsToMs(dynamic seconds) {
  if (seconds == null) return null;
  final num? v = seconds is num ? seconds : num.tryParse(seconds.toString());
  return v == null ? null : (v * 1000).round();
}

/// 统一浏览器 UA（QQ/网易 CDN 会拒绝非浏览器 UA 的音频请求，返回 404）
const String kBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

String _shortUrl(String url, [int max = 80]) =>
    url.length > max ? '${url.substring(0, max)}...' : url;

bool _looksLikeAudio(List<int> bytes) {
  // ID3 (mp3)
  if (bytes.length >= 3 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    return true;
  }
  // fLaC
  if (bytes.length >= 4 &&
      bytes[0] == 0x66 &&
      bytes[1] == 0x4C &&
      bytes[2] == 0x61 &&
      bytes[3] == 0x43) {
    return true;
  }
  // OggS
  if (bytes.length >= 4 &&
      bytes[0] == 0x4F &&
      bytes[1] == 0x67 &&
      bytes[2] == 0x67 &&
      bytes[3] == 0x53) {
    return true;
  }
  // MPEG 帧头（0xFF 0xEx）
  final scan = bytes.length > 2048 ? 2048 : bytes.length;
  for (var i = 0; i < scan - 1; i++) {
    if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
      return true;
    }
  }
  return false;
}

/// 探测音频 URL 是否可播：Range 请求前 8KB，检查状态码与音频 magic
///
/// 播放 URL（musicu.fcg / weapi）可能因 CDN 失效、会员权限返回 404，
/// 直接交给播放器会 Source error 且无法换源。这里先验证：
/// 状态码 200/206 且前 8KB 含音频特征（ID3 / fLaC / OggS / MPEG 帧头）。
/// 可播返回原 url，否则返回 null。
Future<String?> probeAudioUrl(Dio dio, String url, {String? referer}) async {
  // 依次尝试：Range GET → 无 Range GET（部分 CDN 拒 Range 或返回 416）
  for (final useRange in const [true, false]) {
    try {
      final resp = await dio.get<List<int>>(
        url,
        options: Options(
          headers: {
            if (useRange) 'Range': 'bytes=0-8191',
            // QQ/网易 CDN 拒绝非浏览器 UA，探测必须带浏览器 UA
            'User-Agent': kBrowserUserAgent,
            if (referer != null) 'Referer': referer,
          },
          responseType: ResponseType.bytes,
          followRedirects: true,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final status = resp.statusCode ?? 0;
      final bytes = resp.data;
      if (bytes != null && bytes.isNotEmpty && _looksLikeAudio(bytes)) {
        return url;
      }
      // ignore: avoid_print
      print('[探测] 失败: ${_shortUrl(url)} status=$status '
          'bytes=${bytes?.length ?? 0} ${useRange ? 'Range' : '无Range'}');
    } catch (e) {
      // ignore: avoid_print
      print('[探测] 异常: ${_shortUrl(url)} ${useRange ? 'Range' : '无Range'} $e');
    }
  }
  return null;
}
