import '../core/music_backend.dart';
import '../models/music_list.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import 'builtin_platforms.dart';
import 'platform_search_api.dart';

/// 内置平台搜索后端
///
/// 实现现有 [MusicBackend] 接口，声明 search 能力；
/// 播放 URL / 歌词默认委托给平台 API（仅网易云实现直连兜底），
/// 其余返回 null 以触发播放器的跨源降级链。
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

  @override
  List<String> get listKeys => const [];

  @override
  bool get hasList => false;

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

  @override
  void dispose() {
    _ready = false;
  }
}
