import '../core/lx_bridge.dart';
import '../models/music_track.dart';

/// 跨音源搜索聚合器
///
/// 并行搜索所有启用的音源，合并去重结果。
class SearchAggregator {
  /// 执行跨源搜索
  ///
  /// 并行搜索所有已就绪的引擎，合并结果并按 dedupeKey 去重。
  static Future<List<MusicTrack>> search(
    List<LxBridge> bridges,
    String keyword, {
    int limit = 20,
  }) async {
    if (bridges.isEmpty) return [];

    // 并行搜索所有源
    final futures = bridges.map((bridge) async {
      try {
        return await bridge.search(keyword, limit: limit);
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
        if (seen.add(track.dedupeKey)) {
          merged.add(track);
        }
      }
    }

    return merged;
  }

  /// 在单个引擎中搜索
  static Future<List<MusicTrack>> searchSingle(
    LxBridge bridge,
    String keyword, {
    int limit = 20,
  }) async {
    try {
      return await bridge.search(keyword, limit: limit);
    } catch (e) {
      return [];
    }
  }
}
