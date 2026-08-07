import '../models/music_track.dart';

/// 单个内置平台的搜索 API 抽象
abstract class PlatformSearchApi {
  String get sourceId;
  String get sourceKey;
  String get sourceName;
  String? get lastError;

  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    SearchType type = SearchType.song,
  });

  Future<String?> musicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) async {
    return null;
  }

  Future<String?> lyric(MusicTrack track) async {
    return null;
  }
}
