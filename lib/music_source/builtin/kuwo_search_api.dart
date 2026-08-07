import 'package:dio/dio.dart';

import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// 酷我音乐搜索 API
class KuwoSearchApi extends PlatformSearchApi {
  @override
  final String sourceId;

  @override
  final String sourceKey = 'kw';

  @override
  final String sourceName = '酷我音乐';

  final Dio _dio;
  String? _lastError;

  /// 登录态 cookie 提供回调：按平台 key（kw）返回 cookie 串，无登录态返回 null
  final String? Function(String platformKey)? cookieProvider;

  KuwoSearchApi({
    required this.sourceId,
    required Dio dio,
    this.cookieProvider,
    // ignore: prefer_initializing_formals — 字段私有 _dio 需公开参数名 dio
  }) : _dio = dio;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  /// 有登录态时给基础 headers 追加 Cookie 头，无登录态时原样返回
  Map<String, String> _withCookie(Map<String, String> base) {
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    return cookie.isEmpty ? base : {...base, 'Cookie': cookie};
  }

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
    final url =
        'http://search.kuwo.cn/r.s'
        '?client=kt&all=${Uri.encodeComponent(keyword)}'
        '&pn=${page - 1}&rn=$limit&uid=794762570'
        '&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1'
        '&newver=1&ft=music&cluster=0&strategy=2012'
        '&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1';
    final body = await fetchPlain(_dio, url, headers: _withCookie(_headers));
    if (body == null) {
      _lastError = '酷我搜索请求失败';
      return [];
    }
    return parseResponse(body);
  }

  List<MusicTrack> parseResponse(String rawBody) {
    final data = decodeJsonObject(rawBody);
    if (data == null) {
      _lastError = '酷我返回数据异常';
      return [];
    }
    final list = (data['abslist'] as List?) ?? const [];
    final tracks = <MusicTrack>[];

    for (final item in list.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final rid = map['MUSICRID']?.toString() ?? '';
      final id = rid.startsWith('MUSIC_') ? rid.substring(6) : rid;
      tracks.add(MusicTrack(
        id: id,
        title: (map['SONGNAME'] ?? '').toString(),
        artist: (map['ARTIST'] ?? '').toString(),
        album: (map['ALBUM'] ?? '').toString(),
        coverUrl: _cover(map['web_albumpic_short']?.toString()),
        durationMs: secondsToMs(map['DURATION']),
        sourceId: sourceId,
        sourceKey: sourceKey,
      ));
    }
    return tracks;
  }

  String? _cover(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://img1.kuwo.cn$raw';
    return null;
  }
}
