import 'package:all_music/music_source/builtin/builtin_platforms.dart';
import 'package:all_music/music_source/builtin/builtin_search_backend.dart';
import 'package:all_music/music_source/builtin/platform_search_api.dart';
import 'package:all_music/music_source/models/music_list.dart';
import 'package:all_music/music_source/models/music_track.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可控的假平台 API：仅用于验证后端接线（hasList/listKeys/list/listDetail 委托）
class _FakeApi extends PlatformSearchApi {
  _FakeApi({required this.account});

  final bool account;

  @override
  String get sourceId => 'builtin_wy';
  @override
  String get sourceKey => 'wy';
  @override
  String get sourceName => '网易云音乐';
  @override
  String? get lastError => null;
  @override
  bool get hasAccount => account;

  @override
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    SearchType type = SearchType.song,
  }) async {
    return const [];
  }

  @override
  Future<List<MusicListInfo>> lists({
    int page = 1,
    int limit = 20,
  }) async {
    if (!account) return const [];
    return [
      const MusicListInfo(
        id: '111',
        title: '我喜欢的音乐',
        sourceId: 'builtin_wy',
        sourceKey: 'wy',
      )
    ];
  }

  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    return [
      MusicTrack(
        id: '186016',
        title: '晴天',
        artist: '周杰伦',
        sourceId: 'builtin_wy',
        sourceKey: 'wy',
      )
    ];
  }

  @override
  Future<List<MusicListInfo>> topLists({int limit = 30}) async {
    return [
      const MusicListInfo(
        id: '19723756',
        title: '飙升榜',
        sourceId: 'builtin_wy',
        sourceKey: 'wy',
        isRank: true,
      )
    ];
  }

  @override
  Future<List<MusicTrack>> topListDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
  }) async {
    return [
      MusicTrack(
        id: '3417947275',
        title: '交个朋友',
        artist: '歌手',
        sourceId: 'builtin_wy',
        sourceKey: 'wy',
      )
    ];
  }
}

BuiltinSearchBackend _backend(bool account) => BuiltinSearchBackend(
      platform: kBuiltinPlatforms.first, // 网易云
      sourceId: 'builtin_wy',
      api: _FakeApi(account: account),
    );

void main() {
  group('BuiltinSearchBackend 歌单/排行榜能力', () {
    test('hasList/listKeys/hasTopList 恒为 true（官方排行榜，无需登录）', () async {
      final backend = _backend(false);
      await backend.init();
      expect(backend.hasList, isTrue);
      expect(backend.hasTopList, isTrue);
      expect(backend.listKeys, ['wy']);

      final backendLoggedIn = _backend(true);
      await backendLoggedIn.init();
      expect(backendLoggedIn.hasList, isTrue);
      expect(backendLoggedIn.hasTopList, isTrue);
    });

    test('未登录：list() 返回空（平台 API 未登录返回空）', () async {
      final backend = _backend(false);
      await backend.init();
      expect(await backend.list(), isEmpty);
    });

    test('已登录：list/listDetail 委托成功（供我的歌单区域使用）', () async {
      final backend = _backend(true);
      await backend.init();

      final lists = await backend.list();
      expect(lists, hasLength(1));
      expect(lists.first.title, '我喜欢的音乐');

      final tracks = await backend.listDetail(lists.first);
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '186016');
    });

    test('topLists/topListDetail 委托成功（官方排行榜）', () async {
      final backend = _backend(false);
      await backend.init();

      final ranks = await backend.topLists();
      expect(ranks, hasLength(1));
      expect(ranks.first.title, '飙升榜');
      expect(ranks.first.isRank, isTrue);

      // 排行榜详情走 topListDetail（与「我喜欢的音乐」区分）
      final tracks = await backend.listDetail(ranks.first);
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '3417947275');
    });
  });
}
