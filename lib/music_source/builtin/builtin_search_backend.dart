import '../core/music_backend.dart';
import '../models/music_list.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import 'builtin_platforms.dart';
import 'platform_search_api.dart';

/// 内置平台搜索后端
///
/// 实现现有 [MusicBackend] 接口，声明 search 能力与官方排行榜能力
/// （topLists/topListDetail，无需登录）；「我喜欢的音乐」委托给平台 API，
/// 由 accountPlaylistsProvider 按登录态过滤展示。
/// 播放 URL / 歌词委托给平台 API；未登录平台返回空（播放器已改为严格同源，
/// 取不到本平台地址即明确报错，不再跨源降级）。
class BuiltinSearchBackend implements MusicBackend {
  final BuiltinPlatform platform;
  final PlatformSearchApi api;
  bool _ready = false;

  BuiltinSearchBackend({
    required this.platform,
    required this.sourceId,
    required this.api,
  });

  @override
  final String sourceId;

  @override
  bool get ready => _ready;

  @override
  bool get isLoaded => _ready;

  @override
  String? get lastError => api.lastError;

  @override
  Map<String, SourceCapability> get capabilities => {
        platform.sourceKey: SourceCapability(
          key: platform.sourceKey,
          name: platform.name,
          type: 'music',
          actions: const ['search'],
          qualitys: const ['128k', '320k'],
        ),
      };

  @override
  List<String> get searchKeys => [platform.sourceKey];

  /// 内置平台榜单能力：排行榜页（/lists）直接走官方接口，无需登录
  @override
  List<String> get listKeys => [platform.sourceKey];

  @override
  bool get hasList => true;

  /// 支持官方排行榜（网易云 /api/toplist、QQ fcg_myqq_toplist）
  @override
  bool get hasTopList => true;

  @override
  Future<bool> init() async {
    _ready = true;
    return true;
  }

  @override
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceKey,
    SearchType type = SearchType.song,
  }) {
    return api.search(keyword, page: page, limit: limit, type: type);
  }

  @override
  Future<MusicTrack?> getMusicInfo(
    MusicTrack track, {
    String? sourceKey,
  }) async {
    return track;
  }

  @override
  Future<String?> getMusicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) {
    return api.musicUrl(track, quality: quality);
  }

  @override
  Future<String?> getLyric(MusicTrack track) {
    return api.lyric(track);
  }

  @override
  Future<List<MusicListInfo>> list({
    int page = 1,
    int limit = 20,
    String? sourceKey,
    String? listType,
  }) async {
    return api.lists(page: page, limit: limit);
  }

  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
    String? sourceKey,
  }) {
    // 官方排行榜详情与「我喜欢的音乐」详情走不同接口
    if (listInfo.isRank) {
      return api.topListDetail(listInfo, page: page, limit: limit);
    }
    return api.listDetail(listInfo, page: page, limit: limit);
  }

  @override
  Future<List<MusicListInfo>> topLists({int limit = 30}) {
    return api.topLists(limit: limit);
  }

  @override
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) {
    return api.topListDetail(listInfo, page: page, limit: limit);
  }

  @override
  Future<List<MusicTrack>> importList(
    String url, {
    String? sourceKey,
  }) async {
    return [];
  }

  @override
  void dispose() {
    _ready = false;
  }
}
