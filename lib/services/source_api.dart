import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../models/source_type.dart';
import '../models/lyric.dart';
import '../providers/source_provider.dart';
import '../utils/http_client.dart';
import 'source_engine.dart';

/// 基于导入音源的 API 服务
///
/// 根据音源类型自动选择调用方式：
/// - MusicSourceType.api   → HTTP REST（Dio）
/// - MusicSourceType.script → JS 引擎（SourceEngine）
///
/// 音源服务器需实现标准接口：
/// - POST /search { keyword, limit } → { songs: [...] }
/// - POST /url { id, sourceId } → { url: "..." }
/// - POST /lyric { id, sourceId } → { lyric: "..." }
class SourceApi {
  final MusicSource source;
  late final Dio _dio;
  SourceEngine? _engine;

  SourceApi._(this.source) {
    _dio = MusicHttpClient().dio;
  }

  /// 异步工厂 — 对于 script 类型音源，会先初始化 JS 引擎
  static Future<SourceApi> create(MusicSource source, [Ref? ref]) async {
    final api = SourceApi._(source);
    if (source.sourceType == MusicSourceType.script && ref != null) {
      api._engine = await ref.read(sourceProvider.notifier).getEngine(source.id);
    }
    return api;
  }

  /// 构建请求头
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (source.token != null) 'Authorization': 'Bearer ${source.token}',
  };

  /// 搜索歌曲
  Future<List<Song>> search(String keyword, {int limit = 20}) async {
    if (_engine != null) {
      final results = await _engine!.search(keyword, limit: limit);
      // 如果 JS 引擎搜索返回空且有诊断信息，提供详细错误
      if (results.isEmpty && _engine!.lastError != null) {
        // 将诊断信息注入到 source 的上下文中，供 search_provider 使用
        final diag = _engine!.diagnostics;
        if (diag != null) {
          final funcNames = diag['functionNames'] as List? ?? [];
          final strVars = diag['stringVars'] as List? ?? [];
          final httpCalls = diag['httpCalls'] as List? ?? [];
          // ignore: avoid_print
          print('[SourceEngine 诊断] 源: ${source.name}');
          // ignore: avoid_print
          print('  错误: ${_engine!.lastError}');
          // ignore: avoid_print
          print('  全局函数 (${funcNames.length}): ${funcNames.take(20).join(", ")}');
          // ignore: avoid_print
          print('  字符串变量: ${strVars.map((s) => "${s['name']}=${s['preview']}").join(" | ")}');
          // ignore: avoid_print
          print('  HTTP 调用: ${httpCalls.map((c) => "${c['method']} ${c['url']} → ${c['statusCode']}").join(" | ")}');
        }
      }
      return results;
    }
    return _searchViaHttp(keyword, limit: limit);
  }

  /// 获取 JS 引擎的诊断信息（调试用）
  Map<String, dynamic>? get engineDiagnostics => _engine?.diagnostics;
  List<Map<String, dynamic>> get engineHttpLog => _engine?.httpCallLog ?? [];

  Future<List<Song>> _searchViaHttp(String keyword, {int limit = 20}) async {
    try {
      final response = await _dio.post(
        '${source.apiUrl}/search',
        data: {'keyword': keyword, 'limit': limit},
        options: Options(headers: _headers),
      );

      final data = response.data;
      if (data == null || data['songs'] == null) return [];

      return (data['songs'] as List).map((item) {
        return Song(
          id: item['id']?.toString() ?? '',
          source: SourceType.api,
          name: item['name'] ?? '',
          artist: item['artist'] ?? item['singer'] ?? '',
          album: item['album'] as String?,
          albumCover: item['albumCover'] ?? item['pic'] as String?,
          duration: item['duration'] != null
              ? Duration(milliseconds: item['duration'] as int)
              : null,
          sourceId: source.id,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取播放地址
  Future<String?> getSongUrl(Song song) async {
    if (_engine != null) {
      return _engine!.getMusicUrl(song);
    }
    return _getSongUrlViaHttp(song);
  }

  Future<String?> _getSongUrlViaHttp(Song song) async {
    try {
      final response = await _dio.post(
        '${source.apiUrl}/url',
        data: {'id': song.id, 'sourceId': song.sourceId},
        options: Options(headers: _headers),
      );

      final data = response.data;
      return data?['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// 获取歌词
  Future<Lyric?> getLyric(Song song) async {
    if (_engine != null) {
      final lrc = await _engine!.getLyric(song);
      if (lrc != null && lrc.isNotEmpty) {
        return Lyric.fromLrc(lrc, songId: song.id);
      }
      return null;
    }
    return _getLyricViaHttp(song);
  }

  Future<Lyric?> _getLyricViaHttp(Song song) async {
    try {
      final response = await _dio.post(
        '${source.apiUrl}/lyric',
        data: {'id': song.id, 'sourceId': song.sourceId},
        options: Options(headers: _headers),
      );

      final data = response.data;
      final lrc = data?['lyric'] as String?;
      if (lrc == null || lrc.isEmpty) return null;

      return Lyric.fromLrc(lrc, songId: song.id);
    } catch (e) {
      return null;
    }
  }
}
