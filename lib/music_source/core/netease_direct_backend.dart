import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/music_list.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import 'music_backend.dart';

/// 网易云音乐直接后端
///
/// 完全用 Dart HTTP 调用，**不依赖任何 JS 引擎**。
/// 作为 JS 引擎（quickjs_engine）之外、零依赖的兜底后端：
/// 当 JS 音源不可用或用户只想要网易云时，仍可直接搜索/播放/取歌词。
///
/// 支持：
/// - 搜索（/api/search/get/web）
/// - 播放 URL（/api/song/enhance/player/url）
/// - 歌词（/api/song/lyric）
class NeteaseDirectBackend implements MusicBackend {
  @override
  final String sourceId;

  final Dio _dio;

  bool _ready = false;

  String? _lastError;

  /// 网易云音源能力声明
  final Map<String, SourceCapability> _capabilities = {
    'wy': const SourceCapability(
      key: 'wy',
      name: '网易云音乐',
      type: 'music',
      actions: ['search', 'musicUrl', 'lyric'],
      qualitys: ['128k', '320k'],
    ),
  };

  NeteaseDirectBackend({
    required this.sourceId,
    required Dio dio,
  }) : _dio = dio;

  // ── 接口实现 ──

  @override
  bool get ready => _ready;

  @override
  bool get isLoaded => _ready;

  @override
  String? get lastError => _lastError;

  @override
  Map<String, SourceCapability> get capabilities =>
      Map.unmodifiable(_capabilities);

  @override
  List<String> get searchKeys => const ['wy'];

  @override
  List<String> get listKeys => const [];

  @override
  bool get hasList => false;

  @override
  Future<bool> init() async {
    // 直接后端无需异步初始化
    _ready = true;
    _lastError = null;
    return true;
  }

  // ── 搜索 ──

  @override
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceKey,
    SearchType type = SearchType.song,
  }) async {
    if (keyword.trim().isEmpty) return [];
    // 直接后端仅支持单曲搜索；专辑/歌手/歌单类型暂由 JS 音源提供
    if (type != SearchType.song) return [];

    try {
      final offset = (page - 1) * limit;
      final url =
          'https://music.163.com/api/search/get/web?csrf_token='
          '&s=${Uri.encodeComponent(keyword)}'
          '&type=1&offset=$offset&limit=$limit';

      // 关键：用 plain 而非 json，因为网易云经常返回 HTML（302→登录页）
      // 手动 decodeJSON 才能区分"真·空结果"和"被反爬拦截"
      final resp = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            'Referer': 'https://music.163.com',
            'Origin': 'https://music.163.com',
            // 手机端 UA，避免部分接口对桌面 UA 的额外校验
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (resp.statusCode != 200 || resp.data == null || resp.data!.trim().isEmpty) {
        _lastError = '搜索请求失败 (HTTP ${resp.statusCode ?? 0})';
        return [];
      }

      final rawBody = resp.data!;
      final data = _decodeJson(rawBody);
      if (data == null) {
        // 非 JSON → 大概率是被重定向到登录页（HTML）
        _lastError = 'API 返回非 JSON 数据（可能被反爬拦截）';
        return [];
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        // 有 code 字段说明 API 正常但无结果；没有 code 则可能是异常结构
        if (data.containsKey('code')) {
          return []; // 真的没搜到
        }
        _lastError = '搜索结果格式异常';
        return [];
      }

      final songs = (result['songs'] as List?) ?? [];
      if (songs.isEmpty) return [];

      return songs
          .whereType<Map>()
          .map((item) => _trackFromMap(item.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _lastError = '搜索网络错误: ${e.message}';
      return [];
    } catch (e) {
      _lastError = '搜索异常: $e';
      return [];
    }
  }

  // ── 歌曲详情 ──

  @override
  Future<MusicTrack?> getMusicInfo(
    MusicTrack track, {
    String? sourceKey,
  }) async {
    // 直接后端搜索结果已包含完整信息，直接返回
    return track;
  }

  // ── 榜单/歌单（直接后端暂不支持）──

  @override
  Future<List<MusicListInfo>> list({
    int page = 1,
    int limit = 20,
    String? sourceKey,
    String? listType,
  }) async {
    return [];
  }

  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
    String? sourceKey,
  }) async {
    return [];
  }

  @override
  Future<List<MusicTrack>> importList(
    String url, {
    String? sourceKey,
  }) async {
    return [];
  }

  // ── 播放URL ──

  @override
  Future<String?> getMusicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) async {
    try {
      final id = track.id;
      if (id.isEmpty) return null;

      // 网易云增强接口按 br 参数请求码率
      final br = quality == '320k' ? 320000 : 128000;
      final url =
          'https://music.163.com/api/song/enhance/player/url?id=$id&br=$br';

      final resp = await _dio.get<String>(
        url,
        options: Options(
          headers: const {
            'Referer': 'https://music.163.com',
            'Origin': 'https://music.163.com',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'application/json, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (resp.statusCode != 200 || resp.data == null || resp.data!.isEmpty) {
        return null;
      }

      final data = _decodeJson(resp.data!);
      if (data == null) return null;

      final list = (data['data'] as List?) ?? [];
      if (list.isEmpty) return null;

      final first = list.first as Map;
      final playUrl = first['url']?.toString();
      if (playUrl == null || playUrl.isEmpty) return null;

      return playUrl;
    } catch (_) {
      return null;
    }
  }

  // ── 歌词 ──

  @override
  Future<String?> getLyric(MusicTrack track) async {
    try {
      final id = track.id;
      if (id.isEmpty) return null;

      final url =
          'https://music.163.com/api/song/lyric?id=$id&lv=1&kv=1&tv=-1';
      final resp = await _dio.get<String>(
        url,
        options: Options(
          headers: const {
            'Referer': 'https://music.163.com',
            'Origin': 'https://music.163.com',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'application/json, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (resp.statusCode != 200 || resp.data == null || resp.data!.isEmpty) {
        return null;
      }

      final data = _decodeJson(resp.data!);
      if (data == null) return null;

      final lrc = data['lrc'] as Map?;
      return lrc?['lyric']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── 工具 ──

  /// 安全解析 JSON 响应体
  ///
  /// 网易云 API 在手机端经常返回 HTML（302→登录页）而非 JSON，
  /// 用 plain responseType + 手动 decode 才能区分这两种情况。
  Map<String, dynamic>? _decodeJson(String raw) {
    final trimmed = raw.trim();
    // 快速判断：JSON 对象一定以 { 开头
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  MusicTrack _trackFromMap(Map<String, dynamic> item) {
    final artists = (item['artists'] as List?) ?? [];
    final artistNames = artists
        .whereType<Map>()
        .map((a) => (a['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join('/');

    final album = item['album'] as Map?;
    final coverUrl = album?['picUrl']?.toString() ?? '';

    return MusicTrack(
      id: (item['id'] ?? '').toString(),
      title: (item['name'] ?? '').toString(),
      artist: artistNames,
      album: album?['name']?.toString() ?? '',
      coverUrl: coverUrl,
      durationMs: (item['duration'] is num)
          ? (item['duration'] as num).toInt()
          : null,
      sourceId: sourceId,
      sourceKey: 'wy',
    );
  }

  @override
  void dispose() {
    _ready = false;
  }
}
