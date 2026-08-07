import 'package:dio/dio.dart';

import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// 咪咕音乐搜索 API（旧版 app 接口，免签名）
class MiguSearchApi extends PlatformSearchApi {
  @override
  final String sourceId;

  @override
  final String sourceKey = 'mg';

  @override
  final String sourceName = '咪咕音乐';

  final Dio _dio;
  String? _lastError;

  /// 登录态 cookie 提供回调：按平台 key（mg）返回 cookie 串，无登录态返回 null
  final String? Function(String platformKey)? cookieProvider;

  MiguSearchApi({
    required this.sourceId,
    required Dio dio,
    this.cookieProvider,
    // ignore: prefer_initializing_formals — 字段私有 _dio 需公开参数名 dio
  }) : _dio = dio;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 11; MI 11) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
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
    final searchSwitch = Uri.encodeComponent(
      '{"song":1,"album":0,"singer":0,"tagSong":0,'
      '"mvSong":0,"songlist":0,"bestShow":1}',
    );
    final url =
        'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/search_all.do'
        '?isCopyright=1&isCorrect=1&pageNo=$page&pageSize=$limit'
        '&searchSwitch=$searchSwitch&sort=0'
        '&text=${Uri.encodeComponent(keyword)}';
    final body = await fetchPlain(_dio, url, headers: _withCookie(_headers));
    if (body == null) {
      _lastError = '咪咕搜索请求失败';
      return [];
    }
    return parseResponse(body);
  }

  List<MusicTrack> parseResponse(String rawBody) {
    final data = decodeJsonObject(rawBody);
    if (data == null || data['code'] != '000000') {
      _lastError = '咪咕返回数据异常';
      return [];
    }
    final songResult = data['songResultData'] as Map<String, dynamic>?;
    final groups = (songResult?['resultList'] as List?) ?? const [];
    final tracks = <MusicTrack>[];

    for (final group in groups.whereType<List>()) {
      for (final item in group.whereType<Map>()) {
        final map = item.cast<String, dynamic>();
        final img = _firstImg(map['imgItems'] as List?);
        tracks.add(MusicTrack(
          id: (map['songId'] ?? map['id'] ?? '').toString(),
          title: (map['songName'] ?? map['name'] ?? '').toString(),
          artist: joinNames(map['singers'] as List?),
          album: _firstAlbumName(map['albums'] as List?),
          coverUrl: img,
          sourceId: sourceId,
          sourceKey: sourceKey,
        ));
      }
    }
    return tracks;
  }

  String? _firstImg(List<dynamic>? items) {
    if (items == null || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map) return null;
    final raw = first['img']?.toString() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://d.musicapp.migu.cn$raw';
    return null;
  }

  String? _firstAlbumName(List<dynamic>? items) {
    if (items == null || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map) return null;
    final name = first['name']?.toString();
    return name == null || name.isEmpty ? null : name;
  }
}
