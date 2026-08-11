import '../models/music_list.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';

/// 音源后端抽象接口
///
/// 屏蔽 JS 引擎与直接 HTTP 调用两种实现方式的差异。
/// 覆盖 lx-music 标准音源 API：
/// - search（搜索，支持 song/album/artist/playlist 类型）
/// - getMusicInfo（歌曲详情补全）
/// - getMusicUrl（播放 URL）
/// - getMusicLyric（歌词）
/// - list（榜单/排行榜）
/// - listDetail（榜单详情）
/// - importList（歌单导入）
abstract class MusicBackend {
  /// 唯一 ID（对应 SourceDefinition.id）
  String get sourceId;

  /// 后端是否就绪
  bool get ready;

  /// 是否已加载
  bool get isLoaded;

  /// 最后一次错误
  String? get lastError;

  /// 子源能力
  Map<String, SourceCapability> get capabilities;

  /// 拥有搜索能力的子源 key 列表
  List<String> get searchKeys;

  /// 拥有榜单能力的子源 key 列表
  List<String> get listKeys;

  /// 是否支持榜单
  bool get hasList;

  /// 是否支持内置排行榜（官方 API，不依赖第三方音源脚本）
  bool get hasTopList => false;

  /// 内置排行榜列表（官方 API；脚本源返回空，走 [list]）
  Future<List<MusicListInfo>> topLists({int limit = 30}) async => const [];

  /// 内置排行榜歌曲列表（官方 API）
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async => const [];

  /// 初始化（加载脚本 / 注册路由）
  Future<bool> init();

  /// 搜索（lx 标准：search(query, page, type, limit)）
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceKey,
    SearchType type = SearchType.song,
  });

  /// 获取歌曲详情（补全专辑/封面等信息，lx 标准 getMusicInfo）
  Future<MusicTrack?> getMusicInfo(
    MusicTrack track, {
    String? sourceKey,
  });

  /// 获取播放 URL
  Future<String?> getMusicUrl(
    MusicTrack track, {
    String quality = '128k',
  });

  /// 获取歌词
  Future<String?> getLyric(MusicTrack track);

  /// 获取榜单/排行榜列表（lx 标准 list）
  Future<List<MusicListInfo>> list({
    int page = 1,
    int limit = 20,
    String? sourceKey,
    String? listType,
  });

  /// 获取榜单详情（lx 标准 listDetail）
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
    String? sourceKey,
  });

  /// 导入歌单（lx 标准 importList，部分音源支持）
  Future<List<MusicTrack>> importList(
    String url, {
    String? sourceKey,
  });

  /// 释放资源
  void dispose();
}
