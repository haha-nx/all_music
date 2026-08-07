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
