import 'package:dio/dio.dart';

import '../auth/netease_weapi.dart';
import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// 网易云搜索 API（纯 Dart 直连）
class NeteaseSearchApi extends PlatformSearchApi {
  @override
  final String sourceId;

  @override
  final String sourceKey = 'wy';

  @override
  final String sourceName = '网易云音乐';

  final Dio _dio;
  String? _lastError;

  /// 登录态 cookie 提供回调：按平台 key（wy）返回 cookie 串，无登录态返回 null
  final String? Function(String platformKey)? cookieProvider;

  NeteaseSearchApi({
    required this.sourceId,
    required this._dio,
    this.cookieProvider,
  });

  static const _headers = {
    'Referer': 'https://music.163.com',
    'Origin': 'https://music.163.com',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  @override
  String? get lastError => _lastError;

  @override
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    SearchType type = SearchType.song,
  }) async {
    _lastError = null;
    if (keyword.trim().isEmpty || type != SearchType.song) return [];

    final offset = (page - 1) * limit;
    final url =
        'https://music.163.com/api/search/get/web?csrf_token='
        '&s=${Uri.encodeComponent(keyword)}'
        '&type=1&offset=$offset&limit=$limit';
    final body = await fetchPlain(_dio, url, headers: _headers);
    if (body == null) {
      _lastError = '网易云搜索请求失败';
      return [];
    }
    return parseResponse(body);
  }

  /// 解析搜索响应，供单测直接使用
  List<MusicTrack> parseResponse(String rawBody) {
    final data = decodeJsonObject(rawBody);
    if (data == null) {
      _lastError = '网易云返回非 JSON 数据（可能被反爬拦截）';
      return [];
    }
    final result = data['result'] as Map<String, dynamic>?;
    final songs = (result?['songs'] as List?) ?? const [];
    final tracks = <MusicTrack>[];

    for (final item in songs.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final album = map['album'] as Map?;
      tracks.add(MusicTrack(
        id: (map['id'] ?? '').toString(),
        title: (map['name'] ?? '').toString(),
        artist: joinNames(map['artists'] as List?),
        album: album?['name']?.toString(),
        coverUrl: album?['picUrl']?.toString(),
        durationMs:
            map['duration'] is num ? (map['duration'] as num).toInt() : null,
        sourceId: sourceId,
        sourceKey: sourceKey,
      ));
    }
    return tracks;
  }

  @override
  Future<String?> musicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) async {
    final id = track.id;
    if (id.isEmpty) return null;
    // 优先：登录态 weapi 高音质（VIP 会员）
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isNotEmpty) {
      final vipUrl = await NeteaseWeapi.musicUrl(_dio,
          songId: id, cookie: cookie, quality: quality);
      if (vipUrl != null) return vipUrl;
    }
    // 降级：outer/url 免费 128k（现有逻辑不变）
    try {
      // 用 outer/url 试听接口（返回完整 128k MP3，不受版权 VIP 限制）。
      // 旧接口 enhance/player/url 已失效（返回 400 参数错误），不可再用。
      // 该接口对可用歌曲返回 302 → m*.music.126.net 音频地址。
      final url =
          'https://music.163.com/song/media/outer/url?id=$id.mp3';
      final resp = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: _headers,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          followRedirects: false,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (resp.statusCode == 302 || resp.statusCode == 301) {
        final location = resp.headers.value('location');
        if (location != null && location.isNotEmpty) return location;
      }
      // 某些情况直接返回 200 音频流（无重定向），原 URL 亦可播放。
      if (resp.statusCode == 200 && !resp.data.toString().contains('<html')) {
        return url;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> lyric(MusicTrack track) async {
    try {
      final id = track.id;
      if (id.isEmpty) return null;
      final url =
          'https://music.163.com/api/song/lyric?id=$id&lv=1&kv=1&tv=-1';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) return null;
      final data = decodeJsonObject(body);
      if (data == null) return null;
      final lrc = data['lrc'] as Map?;
      return lrc?['lyric']?.toString();
    } catch (_) {
      return null;
    }
  }
}
