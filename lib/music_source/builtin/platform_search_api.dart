import '../models/music_list.dart';
import '../models/music_track.dart';

/// 单个内置平台的搜索 API 抽象
abstract class PlatformSearchApi {
  String get sourceId;
  String get sourceKey;
  String get sourceName;
  String? get lastError;

  /// 是否已登录（有该平台的账号 cookie）
  ///
  /// 决定后端是否声明 list（歌单）能力：未登录不显示「我喜欢的音乐」。
  bool get hasAccount => false;

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

  /// 歌单列表（当前仅「我喜欢的音乐」），未登录返回空
  Future<List<MusicListInfo>> lists({
    int page = 1,
    int limit = 20,
  }) async {
    return const [];
  }

  /// 歌单详情（歌单内歌曲列表），未登录返回空
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    return const [];
  }

  /// 排行榜列表（官方接口，无需登录）；未实现返回空
  Future<List<MusicListInfo>> topLists({int limit = 30}) async {
    return const [];
  }

  /// 排行榜歌曲列表（官方接口，无需登录）；未实现返回空
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    return const [];
  }
}
