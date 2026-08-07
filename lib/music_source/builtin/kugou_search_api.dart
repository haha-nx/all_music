import 'package:dio/dio.dart';

import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// 酷狗音乐搜索 API
class KugouSearchApi extends PlatformSearchApi {
  @override
  final String sourceId;

  @override
  final String sourceKey = 'kg';

  @override
  final String sourceName = '酷狗音乐';

  final Dio _dio;
  String? _lastError;

  /// 登录态 cookie 提供回调：按平台 key（kg）返回 cookie 串，无登录态返回 null
  final String? Function(String platformKey)? cookieProvider;

  KugouSearchApi({
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
        'https://songsearch.kugou.com/song_search_v2'
        '?keyword=${Uri.encodeComponent(keyword)}'
        '&page=$page&pagesize=$limit&userid=0&clientver='
        '&platform=WebFilter&filter=2&iscorrection=1'
        '&privilege_filter=0&area_code=1';
    final body = await fetchPlain(_dio, url, headers: _withCookie(_headers));
    if (body == null) {
      _lastError = '酷狗搜索请求失败';
      return [];
    }
    return parseResponse(body);
  }

  List<MusicTrack> parseResponse(String rawBody) {
    final data = decodeJsonObject(rawBody);
    if (data == null || data['error_code'] != 0) {
      _lastError = '酷狗返回数据异常';
      return [];
    }
    final lists =
        (data['data'] as Map<String, dynamic>?)?['lists'] as List? ??
            const [];
    final tracks = <MusicTrack>[];

    for (final item in lists.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final cover = (map['Image'] ?? map['AlbumImage'])?.toString();
      tracks.add(MusicTrack(
        id: (map['Audioid'] ?? map['ID'] ?? '').toString(),
        title: (map['SongName'] ?? map['FileName'] ?? '').toString(),
        artist: joinNames(map['Singers'] as List?),
        album: map['AlbumName']?.toString(),
        coverUrl: cover == null || cover.isEmpty ? null : cover,
        durationMs: secondsToMs(map['Duration']),
        sourceId: sourceId,
        sourceKey: sourceKey,
      ));
    }
    return tracks;
  }
}
