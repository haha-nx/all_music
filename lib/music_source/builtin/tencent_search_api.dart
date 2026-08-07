import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// QQ 音乐搜索 API（web 搜索接口）
class TencentSearchApi extends PlatformSearchApi {
  @override
  final String sourceId;

  @override
  final String sourceKey = 'tx';

  @override
  final String sourceName = 'QQ音乐';

  final Dio _dio;
  String? _lastError;

  /// 登录态 cookie 提供回调：按平台 key（tx）返回 cookie 串，无登录态返回 null
  final String? Function(String platformKey)? cookieProvider;

  /// QQ 音乐客户端 guid 提供回调：按平台 key 返回 guid 串
  final String? Function(String platformKey)? guidProvider;

  TencentSearchApi({
    required this.sourceId,
    required Dio dio,
    this.cookieProvider,
    this.guidProvider,
    // ignore: prefer_initializing_formals — 字段私有 _dio 需公开参数名 dio
  }) : _dio = dio;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://y.qq.com/',
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
    final url =
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp'
        '?format=json&p=$page&n=$limit&w=${Uri.encodeComponent(keyword)}';
    final body = await fetchPlain(_dio, url, headers: _headers);
    if (body == null) {
      _lastError = 'QQ音乐搜索请求失败';
      return [];
    }
    return parseResponse(body);
  }

  List<MusicTrack> parseResponse(String rawBody) {
    final data = decodeJsonObject(rawBody);
    if (data == null || data['code'] != 0) {
      _lastError = 'QQ音乐返回数据异常';
      return [];
    }
    final song = (data['data'] as Map<String, dynamic>?)?['song']
        as Map<String, dynamic>?;
    final list = (song?['list'] as List?) ?? const [];
    final tracks = <MusicTrack>[];

    for (final item in list.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final albumMid = map['albummid']?.toString() ?? '';
      tracks.add(MusicTrack(
        id: (map['songmid'] ?? map['songid'] ?? '').toString(),
        title: (map['songname'] ?? '').toString(),
        artist: joinNames(map['singer'] as List?),
        album: map['albumname']?.toString(),
        coverUrl: albumMid.isEmpty
            ? null
            : 'https://y.gtimg.cn/music/photo_new/T002R300x300M000$albumMid.jpg',
        durationMs: secondsToMs(map['interval']),
        sourceId: sourceId,
        sourceKey: sourceKey,
      ));
    }
    return tracks;
  }

  /// 通过 musicu.fcg 获取播放 URL（需 QQ 音乐登录 cookie：uin + qqmusic_key）
  @override
  Future<String?> musicUrl(MusicTrack track, {String quality = '128k'}) async {
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty) return null;
    final uin = _extractUin(cookie);
    final guid = guidProvider?.call(sourceKey) ?? '';
    final songmid = track.id;
    if (uin.isEmpty || guid.isEmpty || songmid.isEmpty) return null;

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
      final data = resp.data;
      if (data is! Map) return null;
      final req0 = (data['req_0'] as Map?)?['data'] as Map?;
      if (req0 == null) return null;
      final sip = ((req0['sip'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      final midUrlInfo = ((req0['midurlinfo'] as List?) ?? const [])
          .whereType<Map>()
          .toList();
      final purl = midUrlInfo.isEmpty
          ? ''
          : (midUrlInfo.first['purl']?.toString() ?? '');
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
}
