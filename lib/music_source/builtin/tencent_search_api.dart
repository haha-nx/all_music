import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../models/music_list.dart';
import '../models/music_track.dart';
import 'builtin_search_helpers.dart';
import 'platform_search_api.dart';

/// 「我喜欢的音乐」歌单固定 id（Mineradio 同款约定）
const String kQqLikedPlaylistId = 'liked';

/// 「我喜欢的音乐」默认封面（y.qq.com 官方喜爱封面）
const String kQqLikedCoverUrl =
    'https://y.gtimg.cn/mediastyle/global/img/cover_like.png';

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

  /// 是否已登录 QQ 音乐（cookie 含 uin 才算有效登录态）
  @override
  bool get hasAccount {
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    return cookie.isNotEmpty && _extractUin(cookie).isNotEmpty;
  }

  /// 通用 musicu.fcg POST（登录态接口统一走这里）
  /// 通用 musicu.fcg POST（登录态接口统一走这里）
  ///
  /// 服务器响应 Content-Type 是 `text/plain`，dio 默认 transform 不会
  /// 自动 decode JSON，必须用 ResponseType.plain + 手动 jsonDecode。
  Future<Map<String, dynamic>?> _musicuFcgPost(
    Map<String, dynamic> payload, {
    required String cookie,
  }) async {
    try {
      final resp = await _dio.post<String>(
        'https://u.y.qq.com/cgi-bin/musicu.fcg',
        data: jsonEncode(payload),
        options: Options(
          headers: {..._headers, 'Cookie': cookie},
          contentType: 'application/json',
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

  /// 拉取「我喜欢的音乐」（musicu.fcg CgiGetDiss，dirid=201）
  ///
  /// 请求结构与 Mineradio 一致：comm 仅 ct/cv，登录态由 Cookie 头携带。
  Future<({List<MusicTrack> tracks, int? totalSongNum})> _cgiGetDiss(
    String cookie, {
    int songBegin = 0,
    int songNum = 50,
  }) async {
    final payload = {
      'comm': {'ct': 24, 'cv': 0},
      'req_0': {
        'module': 'music.srfDissInfo.DissInfo',
        'method': 'CgiGetDiss',
        'param': {
          'disstid': 0,
          'dirid': 201, // 201 = 我喜欢的音乐
          'tag': 1,
          'song_begin': songBegin,
          'song_num': songNum,
          'userinfo': 1,
          'orderlist': 1,
        },
      },
    };
    final data = await _musicuFcgPost(payload, cookie: cookie);
    if (data == null) {
      // ignore: avoid_print
      print('[QQ歌单] CgiGetDiss 请求失败（网络或响应异常）');
      return (tracks: <MusicTrack>[], totalSongNum: null);
    }
    final req0 = (data['req_0'] as Map?)?.cast<String, dynamic>();
    final block = (req0?['data'] as Map?)?.cast<String, dynamic>();
    if (block == null) {
      // ignore: avoid_print
      print('[QQ歌单] CgiGetDiss 响应异常: code=${data['code']} '
          'req0.code=${req0?['code']} msg=${data['msg'] ?? data['message'] ?? ''}');
      return (tracks: <MusicTrack>[], totalSongNum: null);
    }

    final total = block['total_song_num'];
    final rawTracks = (block['songlist'] as List?) ?? const [];
    final tracks = <MusicTrack>[];
    for (final item in rawTracks.whereType<Map>()) {
      final track = _parseQqSong(item);
      if (track != null) tracks.add(track);
    }
    return (tracks: tracks, totalSongNum: total is num ? total.toInt() : null);
  }

  /// 解析 musicu.fcg 歌单歌曲条目
  ///
  /// 兼容 songlist 直出与 track_info / songInfo / song 嵌套结构。
  MusicTrack? _parseQqSong(dynamic raw) {
    final map = (raw as Map).cast<String, dynamic>();
    Map<String, dynamic> t = map;
    for (final key in const ['track_info', 'songInfo', 'songinfo', 'song']) {
      final nested = map[key];
      if (nested is Map) {
        t = nested.cast<String, dynamic>();
        break;
      }
    }
    final name = (t['name'] ?? t['songname'] ?? '').toString();
    final mid = (t['songmid'] ?? t['mid'] ?? map['songmid'] ?? '').toString();
    final songid = (t['songid'] ?? map['songid'] ?? '').toString();
    final id = mid.isNotEmpty ? mid : songid;
    if (id.isEmpty || name.isEmpty) return null;

    final singerRaw = t['singer'] ?? t['singers'];
    final singerList = singerRaw is List ? singerRaw : null;
    // 封面 mid：优先 albummid，其次嵌套 album.mid（CgiGetDiss 的
    // track_info 结构里封面 mid 在 album.mid，缺失会导致歌单无封面）
    final album = t['album'];
    String albumMid = (t['albummid'] ?? '').toString();
    if (albumMid.isEmpty && album is Map) {
      albumMid = (album['mid'] ?? '').toString();
    }
    // CDN 文件名用 file.media_mid（与 songmid 可能不同），取不到时兑底用 songmid
    String? mediaMid;
    final file = t['file'];
    if (file is Map) {
      final mm = file['media_mid']?.toString() ?? file['mediaMid']?.toString();
      if (mm != null && mm.isNotEmpty) mediaMid = mm;
    }
    if (mediaMid == null) {
      final mm = t['media_mid']?.toString() ?? t['mediaMid']?.toString();
      if (mm != null && mm.isNotEmpty) mediaMid = mm;
    }
    String? albumName;
    if (t['albumname'] != null) {
      albumName = t['albumname'].toString();
    } else if (album is Map) {
      albumName = album['name']?.toString();
    }
    return MusicTrack(
      id: id,
      title: name,
      artist: joinNames(singerList),
      album: (albumName == null || albumName.isEmpty) ? null : albumName,
      coverUrl: albumMid.isEmpty
          ? null
          : 'https://y.gtimg.cn/music/photo_new/T002R300x300M000$albumMid.jpg',
      durationMs: secondsToMs(t['interval']),
      sourceId: sourceId,
      sourceKey: sourceKey,
      mediaMid: mediaMid,
    );
  }

  /// 「我喜欢的音乐」：登录态下返回歌单卡片（固定单条，歌曲数轻量探测）
  @override
  Future<List<MusicListInfo>> lists({int page = 1, int limit = 20}) async {
    _lastError = null;
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty || _extractUin(cookie).isEmpty) return const [];

    // 探测总数（song_num=1），失败则数量未知
    int? count;
    try {
      final probe = await _cgiGetDiss(cookie, songBegin: 0, songNum: 1);
      count = probe.totalSongNum;
    } catch (_) {}
    return [
      MusicListInfo(
        id: kQqLikedPlaylistId,
        title: '我喜欢的音乐',
        picUrl: kQqLikedCoverUrl,
        songCount: count,
        sourceId: sourceId,
        sourceKey: sourceKey,
      ),
    ];
  }

  /// 「我喜欢的音乐」歌曲列表（CgiGetDiss 分页拉取，按 [limit] 截取）
  ///
  /// song_num 过大可能被服务端截断，且一次性全量拉取会让 UI 线程
  /// 解码大 JSON + 渲染大量封面导致卡死，故按 limit（默认 50）截取。
  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    _lastError = null;
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty || _extractUin(cookie).isEmpty) return const [];
    final pageSize = limit.clamp(1, 1000);
    final result = await _cgiGetDiss(
      cookie,
      songBegin: (page - 1) * pageSize,
      songNum: pageSize,
    );
    return result.tracks;
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
    final song =
        (data['data'] as Map<String, dynamic>?)?['song']
            as Map<String, dynamic>?;
    final list = (song?['list'] as List?) ?? const [];
    final tracks = <MusicTrack>[];

    for (final item in list.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final albumMid = map['albummid']?.toString() ?? '';
      // CDN 文件名用 file.media_mid（与 songmid 可能不同），取不到时回落 songmid
      String? mediaMid;
      final file = map['file'];
      if (file is Map) {
        final mm = file['media_mid']?.toString() ?? file['mediaMid']?.toString();
        if (mm != null && mm.isNotEmpty) mediaMid = mm;
      }
      if (mediaMid == null) {
        final mm = map['media_mid']?.toString();
        if (mm != null && mm.isNotEmpty) mediaMid = mm;
      }
      tracks.add(
        MusicTrack(
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
          mediaMid: mediaMid,
        ),
      );
    }
    return tracks;
  }

  /// 通过 musicu.fcg 获取播放 URL（需 QQ 音乐登录 cookie：uin + qqmusic_key）
  ///
  /// 与 Mineradio 的 handleQQSongUrl 一致：把 qqmusic_key 作为 comm.authst
  /// 传给服务器识别会员身份（否则返回 C400 试听），有 key 时 ct 用 19。
  @override
  Future<String?> musicUrl(MusicTrack track, {String quality = '128k'}) async {
    final cookie = cookieProvider?.call(sourceKey) ?? '';
    if (cookie.isEmpty) {
      // ignore: avoid_print
      print('[QQ音乐] musicUrl 未登录（cookie 为空）');
      return null;
    }
    final (uin, uinKey) = _extractUinWithKey(cookie);
    final (musicKey, keyName) = _extractMusicKeyWithKey(cookie);
    // guid 必须为 8 位数字（CgiGetVkey 的 vkey 与 guid 绑定）；
    // 旧版本持久化的时间戳格式 guid（如 1786340479）会导致 vkey 无效
    var guid = guidProvider?.call(sourceKey) ?? '';
    if (guid.length != 8 || int.tryParse(guid) == null) {
      guid = (10000000 + Random().nextInt(90000000)).toString();
    }
    final songmid = track.id;
    // CDN 文件名用 media_mid（与 songmid 可能不同，如搁浅 songmid=001Bbywq2gicae
    // 而媒体文件是 004UlK9x0jeuow）——文件名错会 CDN -46628 file not exist。
    // 搜索接口不返回 media_mid，取不到时用 songmid 换（fcg_play_single_song 匿名可用）。
    var fileId = track.mediaMid?.isNotEmpty == true ? track.mediaMid! : '';
    if (fileId.isEmpty) {
      final resolved = await _resolveMediaMid(songmid);
      if (resolved != null && resolved.isNotEmpty) fileId = resolved;
    }
    if (fileId.isEmpty) fileId = songmid;
    if (uin.isEmpty || guid.isEmpty || songmid.isEmpty) {
      // ignore: avoid_print
      print('[QQ音乐] musicUrl 参数缺失: uin=${uin.isNotEmpty} '
          'guid=${guid.isNotEmpty} songmid=${songmid.isNotEmpty}');
      return null;
    }
    // ignore: avoid_print
    print('[QQ音乐] musicUrl: songmid=$songmid '
        'fileId=$fileId(${track.mediaMid?.isNotEmpty == true ? 'mediaMid' : 'songmid兜底'}) '
        'uin=$uin($uinKey) '
        'musicKey=${musicKey.isEmpty ? '无' : musicKey}($keyName) '
        'quality=$quality');
    // 诊断：cookie 键名列表（不打值），确认 qm_keyst/qqmusic_key 是否存在
    // ignore: avoid_print
    print('[QQ音乐] cookie 键: '
        '${RegExp('(?:^|;)\\s*([a-zA-Z0-9_]+)=').allMatches(cookie).map((m) => m.group(1)).toSet().join(',')}');

    // 音质 → 文件名前缀候选（一次请求多档，服务器逐档返回 purl，
    // 有会员时返回 M800/F000 完整原曲；匿名只会给 C400 试听）
    final prefixes = switch (quality) {
      'flac' => const ['F000', 'M800'],
      '320k' => const ['M800', 'M500'],
      _ => const ['M500', 'M800'],
    };
    // 后缀必须与 Mineradio 一致：M500/M800 是 .mp3，F000 是 .flac，
    // 写错后缀（如 .m4a）服务器会返回无效 purl（404）
    final filenames = [
      for (final p in prefixes) '$p$fileId.${p == 'F000' ? 'flac' : 'mp3'}',
    ];

    final req = {
      'req_0': {
        'module': 'vkey.GetVkeyServer',
        'method': 'CgiGetVkey',
        'param': {
          'guid': guid,
          'songmid': [for (final _ in filenames) songmid],
          'songtype': [for (final _ in filenames) 0],
          'uin': uin,
          'loginflag': 1,
          'filename': filenames,
          'platform': '20',
        },
      },
      'comm': {
        'uin': uin,
        'format': 'json',
        // 有 qqmusic_key 时 ct=19（登录态）并携带 authst，否则匿名 ct=24
        'ct': musicKey.isNotEmpty ? 19 : 24,
        'cv': 0,
        if (musicKey.isNotEmpty) 'authst': musicKey,
      },
    };
    try {
      final data = await _musicuFcgPost(req, cookie: cookie);
      if (data == null) return null;
      final req0 = (data['req_0'] as Map?)?['data'] as Map?;
      if (req0 == null) {
        // ignore: avoid_print
        print('[QQ音乐] CgiGetVkey 响应异常: code=${data['code']} '
            'body=${jsonEncode(data).length > 160 ? jsonEncode(data).substring(0, 160) : jsonEncode(data)}');
        return null;
      }
      final sip = ((req0['sip'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      final midUrlInfo = ((req0['midurlinfo'] as List?) ?? const [])
          .whereType<Map>()
          .toList();
      // 诊断：打印服务器返回的 purl 原文（判断 vkey/purl 是否完整、文件名是否对）
      // ignore: avoid_print
      print('[QQ音乐] CgiGetVkey 响应: sip=${sip.length} '
          'purl=${midUrlInfo.map((m) {
        final p = m['purl']?.toString() ?? '';
        return p.length > 260 ? '${p.substring(0, 260)}...' : p;
      }).join(' | ')}');
      // 收集候选 URL：每个非 C400 的 purl × 每个 sip（CDN）
      // C400 = 64k 试听（未识别会员），直接排除
      final candidates = <String>[];
      for (final m in midUrlInfo) {
        final purl = m['purl']?.toString() ?? '';
        if (purl.isEmpty || purl.split('?').first.contains('C400')) continue;
        // 标准 QQ 播放 URL 带 fromtag，缺失时补上（部分 CDN 依赖它）
        final effective = purl.contains('fromtag=')
            ? purl
            : '$purl${purl.contains('?') ? '&' : '?'}fromtag=0';
        for (final s in sip) {
          candidates.add(s + effective);
          // sip 是 http 时补 https 变体：部分 CDN http 404 但 https 可播
          if (s.startsWith('http://')) {
            candidates.add('https://${s.substring(7)}$effective');
          }
        }
      }
      if (candidates.isEmpty) {
        // ignore: avoid_print
        print('[QQ音乐] CgiGetVkey 无可用候选: '
            'uin=${uin.isNotEmpty ? '有' : '无'} '
            'musicKey=${musicKey.isNotEmpty ? '有' : '无'} '
            'C400=${midUrlInfo.any((m) => (m['purl']?.toString() ?? '').contains('C400'))}');
        return null;
      }
      // 逐个探测可播性：sip[0]+purl 可能 404（CDN 失效/权限不足），
      // 只有 Range 请求返回 200/206 且前 8KB 是音频内容才算可用
      // ignore: avoid_print
      print('[QQ音乐] CgiGetVkey 候选 ${candidates.length} 个: '
          '${candidates.map((c) => c.length > 120 ? '${c.substring(0, 120)}...' : c).join(' || ')}');
      for (final candidate in candidates) {
        final ok = await probeAudioUrl(_dio, candidate,
            referer: 'https://y.qq.com/');
        if (ok != null) {
          // ignore: avoid_print
          print('[QQ音乐] 探测通过: '
              '${candidate.length > 60 ? candidate.substring(0, 60) : candidate}...');
          return ok;
        }
      }
      // ignore: avoid_print
      print('[QQ音乐] 全部候选探测失败（404/超时/非音频），无法播放');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取歌词（fcg_query_lyric_new 匿名可用，nobase64=1 直出 LRC 文本）
  ///
  /// 与 Mineradio 的 handleQQLyric legacy 分支一致；返回文本可能为
  /// base64 编码（部分 UA 下），[nobase64]=1 时通常为明文，仍做兼容解码。
  @override
  Future<String?> lyric(MusicTrack track) async {
    try {
      final mid = track.id;
      if (mid.isEmpty) return null;
      final url =
          'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg'
          '?songmid=$mid&songtype=0&format=json&nobase64=1&g_tk=5381'
          '&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8'
          '&notice=0&platform=yqq.json&needNewCode=0';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) return null;
      final data = decodeJsonObject(body);
      if (data == null || data['retcode'] != 0) return null;
      var text = data['lyric']?.toString() ?? '';
      if (text.isEmpty) text = data['tlyric']?.toString() ?? '';
      if (text.isEmpty) return null;
      return _decodeLyricText(text);
    } catch (_) {
      return null;
    }
  }

  /// 解码 QQ 歌词文本：去除 HTML 实体，兼容 base64 编码
  static String _decodeLyricText(String text) {
    var raw = text.trim();
    if (raw.isEmpty) return '';
    for (final e in const {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
    }.entries) {
      raw = raw.replaceAll(e.key, e.value);
    }
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    final looksBase64 = compact.length >= 8 &&
        compact.length % 4 == 0 &&
        RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(compact) &&
        !raw.trimLeft().startsWith('[');
    if (looksBase64) {
      try {
        final decoded = utf8.decode(base64Decode(compact));
        if (decoded.contains('[') ||
            RegExp(r'[\u4e00-\u9fa5]').hasMatch(decoded)) {
          raw = decoded.replaceFirst(RegExp(r'^\uFEFF'), '');
        }
      } catch (_) {}
    }
    return raw.replaceAll('\r\n', '\n').trim();
  }

  /// http 封面 URL 转 https（Android 9+ 默认禁 cleartext，http 封面加载失败）
  String? _httpsUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
  }

  /// 排行榜列表（官方公开接口，无需登录）：fcg_myqq_toplist
  ///
  /// 返回巅峰榜/飙升榜等官方榜单（id、topTitle、picUrl、listenCount）。
  @override
  Future<List<MusicListInfo>> topLists({int limit = 30}) async {
    _lastError = null;
    try {
      final url = 'https://c.y.qq.com/v8/fcg-bin/fcg_myqq_toplist.fcg'
          '?format=json&uin=0&g_tk=5381';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) {
        _lastError = 'QQ音乐榜单请求失败';
        return const [];
      }
      final data = decodeJsonObject(body);
      final list =
          ((data?['data'] as Map?)?['topList'] as List?) ?? const [];
      final result = <MusicListInfo>[];
      for (final item in list.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final id = m['id']?.toString();
        final title = m['topTitle']?.toString();
        if (id == null || id.isEmpty || title == null || title.isEmpty) {
          continue;
        }
        result.add(MusicListInfo(
          id: id,
          title: title,
          picUrl: _httpsUrl(m['picUrl']?.toString()),
          songCount:
              m['listenCount'] is num ? (m['listenCount'] as num).toInt() : null,
          sourceId: sourceId,
          sourceKey: sourceKey,
          isRank: true,
        ));
        if (result.length >= limit) break;
      }
      return result;
    } catch (_) {
      _lastError = 'QQ音乐榜单请求异常';
      return const [];
    }
  }

  /// 排行榜歌曲列表（官方公开接口，无需登录）：fcg_v8_toplist_cp
  ///
  /// songlist[].data 结构与歌单歌曲一致（songmid/albummid/interval），
  /// 复用 [_parseQqSong] 解析；分页用 song_begin/song_num。
  @override
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    _lastError = null;
    try {
      final begin = (page - 1) * limit;
      final url = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg'
          '?format=json&topid=${listInfo.id}&page=detail&type=top&tpl=3'
          '&song_begin=$begin&song_num=$limit';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) {
        _lastError = 'QQ音乐榜单详情请求失败';
        return const [];
      }
      final data = decodeJsonObject(body);
      if (data == null || data['code'] != 0) return const [];
      final list = (data['songlist'] as List?) ?? const [];
      final tracks = <MusicTrack>[];
      for (final item in list.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final track = _parseQqSong(m['data'] ?? m);
        if (track != null) tracks.add(track);
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// 从 cookie 提取 uin（优先级：uin → qqmusic_uin → wxuin → p_uin）
  (String, String) _extractUinWithKey(String cookie) {
    for (final key in const ['uin', 'qqmusic_uin', 'wxuin', 'p_uin']) {
      final m = RegExp('(?:^|;)\\s*$key=([^;]+)').firstMatch(cookie);
      if (m != null) return (m.group(1) ?? '', key);
    }
    return ('', '');
  }

  String _extractUin(String cookie) => _extractUinWithKey(cookie).$1;

  /// 用 songmid 换 media_mid（CDN 文件名用）。
  ///
  /// 搜索接口（client_search_cp）不返回 file.media_mid，而 CDN 文件名
  /// 必须用 media_mid；fcg_play_single_song.fcg 匿名可用，返回完整详情。
  Future<String?> _resolveMediaMid(String songmid) async {
    try {
      final url = 'https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg'
          '?songmid=$songmid&format=json';
      final body = await fetchPlain(_dio, url, headers: _headers);
      if (body == null) return null;
      final data = decodeJsonObject(body);
      final list = data?['data'];
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          final f = first['file'];
          if (f is Map) {
            final mm =
                f['media_mid']?.toString() ?? f['mediaMid']?.toString();
            if (mm != null && mm.isNotEmpty) return mm;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从 cookie 提取播放授权 key，返回 [值, 来源键名]。
  ///
  /// 与 Mineradio `qqCookiePlaybackKey` 一致：qm_keyst 优先（新版登录的
  /// musickey），其次 qqmusic_key（旧版网页登录），music_key/wxskey 兑底。
  /// 注意：不要按登录形态（uin/wxuin）选 key——y.qq.com 网页播放器实际
  /// 使用的就是 qm_keyst，选错会拿到低权限 key 导致 vkey 无效（CDN 404）。
  (String, String) _extractMusicKeyWithKey(String cookie) {
    final map = <String, String>{};
    for (final m in RegExp('(?:^|;)\\s*([a-zA-Z0-9_]+)=([^;]+)')
        .allMatches(cookie)) {
      map[m.group(1) ?? ''] = m.group(2) ?? '';
    }
    for (final key in const [
      'qm_keyst',
      'qqmusic_key',
      'music_key',
      'wxskey'
    ]) {
      final v = map[key];
      if (v != null && v.isNotEmpty) return (v, key);
    }
    return ('', '');
  }
}
