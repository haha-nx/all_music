import '../core/music_backend.dart';
import '../models/music_track.dart';

/// 跨音源搜索聚合器
///
/// 并行搜索所有启用的音源，合并去重结果。
class SearchAggregator {
  /// 执行跨源搜索
  ///
  /// 并行搜索所有已就绪的后端，合并结果并按 dedupeKey 去重。
  static Future<List<MusicTrack>> search(
    List<MusicBackend> bridges,
    String keyword, {
    int limit = 20,
    SearchType type = SearchType.song,
  }) async {
    if (bridges.isEmpty) return [];

    // 并行搜索所有源
    final futures = bridges.map((bridge) async {
      try {
        return await bridge.search(keyword, limit: limit, type: type);
      } catch (e) {
        return <MusicTrack>[];
      }
    });

    final results = await Future.wait(futures);

    // 合并 + 去重
    final seen = <String>{};
    final merged = <MusicTrack>[];

    for (final tracks in results) {
      for (final track in tracks) {
        // 非单曲类型（专辑/歌手/歌单）按 id+title 去重
        final key = type == SearchType.song
            ? track.dedupeKey
            : '${track.sourceKey}:${track.id}:${track.title}'.toLowerCase();
        if (track.id.isNotEmpty && seen.add(key)) {
          merged.add(track);
        }
      }
    }

    return merged;
  }

  /// 在单个后端中搜索
  static Future<List<MusicTrack>> searchSingle(
    MusicBackend bridge,
    String keyword, {
    int limit = 20,
    SearchType type = SearchType.song,
  }) async {
    try {
      return await bridge.search(keyword, limit: limit, type: type);
    } catch (e) {
      return [];
    }
  }
}
