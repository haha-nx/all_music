import 'package:all_music/models/song.dart';
import 'package:all_music/models/source_type.dart';
import '../utils/http_client.dart';

/// 直接对接音乐平台公开 API（不依赖 LX Music 源服务器）
class PlatformApi {
  final _dio = MusicHttpClient().dio;

  // ---------------------------------------------------------------------------
  // 酷狗 (Kugou)
  // ---------------------------------------------------------------------------

  /// 酷狗搜索
  Future<List<Song>> searchKugou(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceId,
  }) async {
    try {
      final resp = await _dio.get(
        'http://mobilecdn.kugou.com/api/v3/search/song',
        queryParameters: {
          'format': 'json',
          'keyword': keyword,
          'page': page,
          'pagesize': limit,
          'showtype': 1,
        },
      );
      final data = resp.data;
      if (data == null || data['status'] != 1) return [];

      final info = (data['data'] as Map?)?.let((d) => d['info'] as List?) ?? [];
      return info.map((item) {
        final m = item as Map;
        final hash = m['hash'] as String? ?? '';
        return Song(
          id: 'kg_$hash',
          source: SourceType.api,
          name: (m['songname'] as String?) ?? '',
          artist: (m['singername'] as String?) ?? '',
          album: m['album_name'] as String?,
          albumCover: null, // 搜索 API 不返回封面，播放时通过 getSongInfo 获取
          duration: m['duration'] is int
              ? Duration(seconds: m['duration'] as int)
              : null,
          lyricId: hash,
          sourceId: sourceId,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取酷狗播放链接
  Future<String?> getKugouUrl(String hash) async {
    try {
      final resp = await _dio.get(
        'http://m.kugou.com/app/i/getSongInfo.php',
        queryParameters: {'hash': hash, 'cmd': 'playInfo'},
      );
      final data = resp.data;
      if (data == null || data['status'] != 1) return null;
      return data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 获取酷狗歌词（LRC 格式原始文本）
  Future<String?> getKugouLyricRaw(String hash) async {
    try {
      final resp = await _dio.get(
        'http://m.kugou.com/app/i/krc.php',
        queryParameters: {'hash': hash, 'cmd': '100', 'timelength': '999999'},
      );
      final body = resp.data?.toString() ?? '';
      return body.isEmpty ? null : body;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  /// 判断 ID 是否为酷狗 hash（32 位 hex）
  static bool isKugouHash(String id) {
    final cleanId = id.replaceFirst(RegExp(r'^kg_'), '');
    return RegExp(r'^[a-f0-9]{32}$').hasMatch(cleanId);
  }

  /// 从 kg_xxx 格式 ID 中提取 hash
  static String extractHash(String id) {
    return id.replaceFirst(RegExp(r'^kg_'), '');
  }
}

/// 扩展方法
extension _MapLet<K, V> on Map<K, V>? {
  R? let<R>(R Function(Map<K, V> map) fn) {
    if (this == null) return null;
    return fn(this!);
  }
}
