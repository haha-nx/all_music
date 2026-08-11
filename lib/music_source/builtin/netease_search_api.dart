import 'package:dio/dio.dart';

import '../auth/netease_weapi.dart';
import '../models/music_list.dart';
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

  /// http 封面 URL 转 https（Android 9+ 默认禁 cleartext，http 封面加载失败）
  String? _httpsUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
  }

  /// 是否已登录网易云：仅当 cookie 携带登录态关键键 MUSIC_U 才视为已登录
  /// （匿名 cookie 只有 NMTID/os 等，无法拉取歌单）
  @override
  bool get hasAccount {
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    return cookie.isNotEmpty && RegExp(r'(?:^|;)\s*MUSIC_U=').hasMatch(cookie);
  }

  /// 「我喜欢的音乐」：登录态下返回歌单卡片（固定单条）
  ///
  /// 通过 weapi 拉取账号 uid 与用户歌单列表，取 specialType == 5 的
  /// 「我喜欢的音乐」。未登录 / cookie 失效返回空列表。
  @override
  Future<List<MusicListInfo>> lists({
    int page = 1,
    int limit = 20,
  }) async {
    _lastError = null;
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty) return const [];

    final uid = await NeteaseWeapi.accountUid(_dio, cookie: cookie);
    if (uid == null || uid.isEmpty) {
      _lastError = '获取网易云账号信息失败（cookie 可能已失效）';
      return const [];
    }
    final playlists = await NeteaseWeapi.userPlaylists(
      _dio,
      uid: uid,
      cookie: cookie,
    );
    if (playlists.isEmpty) {
      _lastError = '获取网易云歌单失败（cookie 可能已失效）';
      return const [];
    }

    // specialType == 5 即「我喜欢的音乐」
    final liked = playlists.where((p) => p['specialType'] == 5).firstOrNull;
    if (liked == null) return const [];
    return [
      MusicListInfo(
        id: (liked['id'] ?? '').toString(),
        title: liked['name']?.toString() ?? '我喜欢的音乐',
        // coverImgUrl 常为 http://（Android cleartext 拦截），统一转 https
        picUrl: _httpsUrl(liked['coverImgUrl']?.toString()),
        songCount: liked['trackCount'] is num
            ? (liked['trackCount'] as num).toInt()
            : null,
        sourceId: sourceId,
        sourceKey: sourceKey,
      ),
    ];
  }

  /// 「我喜欢的音乐」歌曲列表
  ///
  /// v6/playlist/detail 的 playlist.tracks 在新版接口中可能为空，
  /// 为空时改用 trackIds → v3/song/detail 批量拉取完整歌曲。
  /// 支持分页（[page]×[limit]）：每次只拉一页，避免一次性全量
  /// 在 UI 线程解码大 JSON + 渲染大量封面导致卡死。
  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    _lastError = null;
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty) return const [];

    final detail = await NeteaseWeapi.playlistDetail(
      _dio,
      playlistId: listInfo.id,
      cookie: cookie,
    );
    if (detail == null) {
      _lastError = '获取网易云歌单详情失败（cookie 可能已失效）';
      return const [];
    }
    final tracksRaw = detail['tracks'] is List ? detail['tracks'] as List : const [];
    if (tracksRaw.isEmpty) {
      // 新版接口 tracks 为空：trackIds → song/detail 批量（按页切片）
      final trackIds = await NeteaseWeapi.playlistTrackIds(
        _dio,
        playlistId: listInfo.id,
        cookie: cookie,
      );
      final ids = trackIds
          .map((t) => (t['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .skip((page - 1) * limit)
          .take(limit)
          .toList();
      if (ids.isEmpty) return const [];
      final songs = await NeteaseWeapi.songDetail(_dio, ids: ids, cookie: cookie);
      if (songs.isEmpty) {
        _lastError = '获取网易云歌单歌曲失败（cookie 可能已失效）';
        return const [];
      }
      return _tracksFromRaw(songs);
    }
    // 快照 tracks 存在时按页切片
    final start = (page - 1) * limit;
    final slice = tracksRaw.skip(start).take(limit).toList();
    return _tracksFromRaw(slice);
  }

  /// 解析网易云歌曲原始条目（al/ar 字段类型防御）
  List<MusicTrack> _tracksFromRaw(List<dynamic> tracks) {
    final result = <MusicTrack>[];
    for (final item in tracks.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      // 防御畸形响应：al/ar 字段类型不对时按空处理
      final album = map['al'] is Map ? map['al'] as Map : null;
      result.add(MusicTrack(
        id: (map['id'] ?? '').toString(),
        title: (map['name'] ?? '').toString(),
        artist: joinNames(map['ar'] is List ? map['ar'] as List : null),
        album: album?['name']?.toString(),
        // 歌单快照的 al.picUrl 常为 http://（Android cleartext 拦截），统一转 https
        coverUrl: _httpsUrl(album?['picUrl']?.toString()),
        durationMs: map['dt'] is num ? (map['dt'] as num).toInt() : null,
        sourceId: sourceId,
        sourceKey: sourceKey,
      ));
    }
    return result;
  }

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
    final tracks = parseResponse(body);
    if (tracks.isEmpty) return tracks;
    // 搜索接口（/api/search/get/web）不返回 album.picUrl，封面缺失的歌曲
    // 用 song/detail 公开接口批量补全（匿名可用，无需登录）。
    return _fillMissingCovers(tracks);
  }

  /// 对封面缺失的搜索结果调 /api/song/detail 批量补全封面
  Future<List<MusicTrack>> _fillMissingCovers(List<MusicTrack> tracks) async {
    final missing = tracks
        .where((t) => t.coverUrl == null || t.coverUrl!.isEmpty)
        .toList();
    if (missing.isEmpty) return tracks;
    final ids = missing.map((t) => t.id).where((s) => s.isNotEmpty).toList();
    if (ids.isEmpty) return tracks;
    try {
      final idsJson = '[${ids.join(',')}]';
      final url =
          'https://music.163.com/api/song/detail/?ids=${Uri.encodeComponent(idsJson)}';
      final body = await fetchPlain(_dio, url, headers: _headers);
      final data = decodeJsonObject(body ?? '');
      final songs = (data?['songs'] as List?) ?? const [];
      final coverById = <String, String>{};
      for (final item in songs.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final al = m['album'];
        if (al is Map) {
          final pic = al['picUrl']?.toString();
          if (pic != null && pic.isNotEmpty) {
            coverById[m['id']?.toString() ?? ''] = _httpsUrl(pic)!;
          }
        }
      }
      if (coverById.isEmpty) return tracks;
      return [
        for (final t in tracks)
          (t.coverUrl == null || t.coverUrl!.isEmpty) &&
                  coverById.containsKey(t.id)
              ? MusicTrack(
                  id: t.id,
                  title: t.title,
                  artist: t.artist,
                  album: t.album,
                  coverUrl: coverById[t.id],
                  durationMs: t.durationMs,
                  sourceId: t.sourceId,
                  sourceKey: t.sourceKey,
                  lyricId: t.lyricId,
                  rawData: t.rawData,
                  mediaMid: t.mediaMid,
                )
              : t,
      ];
    } catch (_) {
      return tracks;
    }
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
        // 搜索接口的 album.picUrl 通常为 null，此处仅兜底转换；
        // 真正补全由 _fillMissingCovers（song/detail）完成。
        coverUrl: _httpsUrl(album?['picUrl']?.toString()),
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
    // ignore: avoid_print
    print('[网易云] musicUrl: id=$id quality=$quality '
        'cookie=${cookie.isNotEmpty ? '有(${cookie.length}字符)' : '无'} '
        'MUSIC_U=${RegExp(r'MUSIC_U=').hasMatch(cookie) ? '有' : '无'}');
    if (cookie.isNotEmpty) {
      final vipUrl = await NeteaseWeapi.musicUrl(_dio,
          songId: id, cookie: cookie, quality: quality);
      if (vipUrl != null) return vipUrl;
      // 诊断：weapi 拿不到 url（cookie 失效/无 VIP 权限）
      // ignore: avoid_print
      print('[网易云] weapi musicUrl 失败: id=$id quality=$quality '
          'MUSIC_U=${RegExp(r'MUSIC_U=').hasMatch(cookie) ? '有' : '无'}');
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

  /// 排行榜列表（官方公开接口，无需登录）：/api/toplist
  ///
  /// 返回官方榜单（飙升榜/新歌榜/热歌榜等），榜单详情即歌单（固定 id），
  /// 复用 [listDetail]（weapi playlist/detail + songDetail）。
  @override
  Future<List<MusicListInfo>> topLists({int limit = 30}) async {
    _lastError = null;
    try {
      final body = await fetchPlain(
        _dio,
        'https://music.163.com/api/toplist',
        headers: _headers,
      );
      if (body == null) {
        _lastError = '网易云榜单请求失败';
        return const [];
      }
      final data = decodeJsonObject(body);
      final list = (data?['list'] as List?) ?? const [];
      final result = <MusicListInfo>[];
      for (final item in list.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final id = m['id']?.toString();
        final name = m['name']?.toString();
        if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
        result.add(MusicListInfo(
          id: id,
          title: name,
          picUrl: _httpsUrl(m['coverImgUrl']?.toString()),
          songCount: null,
          sourceId: sourceId,
          sourceKey: sourceKey,
          isRank: true,
        ));
        if (result.length >= limit) break;
      }
      return result;
    } catch (_) {
      _lastError = '网易云榜单请求异常';
      return const [];
    }
  }

  /// 排行榜歌曲列表：网易云榜单即歌单，用**公开接口**（匿名可用）
  ///
  /// 公开 /api/v6/playlist/detail + /api/song/detail 无需登录，
  /// 与「我喜欢的音乐」（weapi 登录态）不同，保证未登录也能看榜单。
  @override
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    _lastError = null;
    try {
      final url =
          'https://music.163.com/api/v6/playlist/detail?id=${listInfo.id}';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) {
        _lastError = '获取网易云榜单详情失败';
        return const [];
      }
      final data = decodeJsonObject(body);
      final pl = data?['playlist'] as Map?;
      final tracksRaw = (pl?['tracks'] as List?) ?? const [];
      var items = tracksRaw.whereType<Map>().toList();
      if (items.isEmpty) {
        // 快照为空：trackIds → song/detail（公开接口）按页切片
        final ids = ((pl?['trackIds'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => m['id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .skip((page - 1) * limit)
            .take(limit)
            .toList();
        if (ids.isEmpty) return const [];
        final idsJson = '[${ids.join(',')}]';
        final detailUrl =
            'https://music.163.com/api/song/detail/?ids=${Uri.encodeComponent(idsJson)}';
        final detailBody = await fetchPlain(_dio, detailUrl, headers: _headers);
        final detailData = decodeJsonObject(detailBody ?? '');
        items =
            ((detailData?['songs'] as List?) ?? const []).whereType<Map>().toList();
      } else {
        final start = (page - 1) * limit;
        items = items.skip(start).take(limit).toList();
      }
      return _tracksFromRaw(items);
    } catch (_) {
      return const [];
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
