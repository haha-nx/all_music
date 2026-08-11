import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/music_source/builtin/tencent_search_api.dart';
import 'package:all_music/music_source/models/music_list.dart';
import 'package:all_music/music_source/models/music_track.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> data) => ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

TencentSearchApi _api(Dio dio, {String cookie = 'uin=12345; qqmusic_key=abc'}) =>
    TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => cookie,
      guidProvider: (_) => '1234567890',
    );

void main() {
  group('qq 我喜欢的音乐（musicu.fcg CgiGetDiss）', () {
    test('lists 返回「我喜欢的音乐」卡片并探测歌曲数', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          captured = options;
          return _json({
            'code': 0,
            'req_0': {
              'code': 0,
              'data': {'total_song_num': 42, 'songlist': []}
            }
          });
        });

      final lists = await _api(dio).lists();
      expect(lists, hasLength(1));
      expect(lists.first.id, kQqLikedPlaylistId);
      expect(lists.first.title, '我喜欢的音乐');
      expect(lists.first.songCount, 42);
      expect(lists.first.picUrl, kQqLikedCoverUrl);
      expect(lists.first.sourceKey, 'tx');

      // 请求必须走 CgiGetDiss + dirid=201（我喜欢的音乐）
      final body = jsonDecode(captured.data as String) as Map<String, dynamic>;
      final param =
          ((body['req_0'] as Map)['param'] as Map).cast<String, dynamic>();
      expect((body['req_0'] as Map)['module'], 'music.srfDissInfo.DissInfo');
      expect((body['req_0'] as Map)['method'], 'CgiGetDiss');
      expect(param['dirid'], 201);
      expect(param['disstid'], 0);
      expect(captured.headers['cookie'], 'uin=12345; qqmusic_key=abc');
    });

    test('listDetail 解析歌单歌曲（singer/albummid/interval）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return _json({
            'code': 0,
            'req_0': {
              'code': 0,
              'data': {
                'total_song_num': 2,
                'songlist': [
                  {
                    'songid': 123,
                    'songmid': '0039MnYb0qxYhV',
                    'name': '晴天',
                    'singer': [
                      {'id': 4558, 'name': '周杰伦'}
                    ],
                    'albummid': '000MkMni19ClKG',
                    'albumname': '叶惠美',
                    'interval': 269,
                  }
                ],
              }
            }
          });
        });

      final tracks = await _api(dio).listDetail(const MusicListInfo(
        id: kQqLikedPlaylistId,
        title: '我喜欢的音乐',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ));
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '0039MnYb0qxYhV');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.album, '叶惠美');
      expect(tracks.first.durationMs, 269000);
      expect(
        tracks.first.coverUrl,
        'https://y.gtimg.cn/music/photo_new/T002R300x300M000000MkMni19ClKG.jpg',
      );
      expect(tracks.first.sourceKey, 'tx');
    });

    test('track_info 嵌套结构也能解析（含 album.mid 封面）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return _json({
            'code': 0,
            'req_0': {
              'code': 0,
              'data': {
                'songlist': [
                  {
                    'songid': 456,
                    'track_info': {
                      'mid': '0039MnYb0qxYhV',
                      'name': '七里香',
                      'singer': [
                        {'name': '周杰伦'}
                      ],
                      'album': {'mid': '000MkMni19ClKG', 'name': '七里香'},
                      'interval': 300,
                    }
                  }
                ],
              }
            }
          });
        });

      final tracks = await _api(dio).listDetail(const MusicListInfo(
        id: kQqLikedPlaylistId,
        title: 'x',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ));
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '0039MnYb0qxYhV');
      expect(tracks.first.title, '七里香');
      expect(tracks.first.album, '七里香');
      expect(tracks.first.durationMs, 300000);
      // 嵌套 album.mid 也应解析出封面
      expect(
        tracks.first.coverUrl,
        'https://y.gtimg.cn/music/photo_new/T002R300x300M000000MkMni19ClKG.jpg',
      );
    });

    test('lyric 获取歌词（fcg_query_lyric_new 明文 LRC）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.host, 'c.y.qq.com');
          expect(options.uri.path, '/lyric/fcgi-bin/fcg_query_lyric_new.fcg');
          return _json({
            'retcode': 0,
            'lyric': '[00:00.00]晴天 - 周杰伦\n[00:02.25]词：周杰伦',
          });
        });

      final lyric = await _api(dio).lyric(const MusicTrack(
        id: '0039MnYb0qxYhV',
        title: '晴天',
        artist: '周杰伦',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ));
      expect(lyric, contains('[00:00.00]'));
      expect(lyric, contains('晴天'));
    });

    test('lyric 兼容 base64 编码歌词', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          // 模拟部分 UA 下返回 base64（即使 nobase64=1 也兜底）
          final plain = '[00:00.00]七里香 - 周杰伦';
          final encoded =
              base64Encode(utf8.encode(plain));
          return _json({'retcode': 0, 'lyric': encoded});
        });

      final lyric = await _api(dio).lyric(const MusicTrack(
        id: '0039MnYb0qxYhV',
        title: '七里香',
        artist: '周杰伦',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ));
      expect(lyric, contains('七里香'));
    });

    test('topLists 解析官方榜单（fcg_myqq_toplist）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/v8/fcg-bin/fcg_myqq_toplist.fcg');
          return _json({
            'code': 0,
            'data': {
              'topList': [
                {
                  'id': 4,
                  'topTitle': '巅峰榜·流行指数',
                  'picUrl': 'http://y.gtimg.cn/music/photo_new/T003R300x300M0000044lmxc3u1H5g.jpg',
                  'listenCount': 7953220,
                },
                {'id': 26, 'topTitle': '巅峰榜·热歌', 'listenCount': 19600000},
              ],
            },
          });
        });

      final lists = await _api(dio).topLists(limit: 30);
      expect(lists, hasLength(2));
      expect(lists.first.id, '4');
      expect(lists.first.title, '巅峰榜·流行指数');
      expect(
        lists.first.picUrl,
        'https://y.gtimg.cn/music/photo_new/T003R300x300M0000044lmxc3u1H5g.jpg',
      );
      expect(lists.first.songCount, 7953220);
      expect(lists.first.isRank, isTrue);
    });

    test('topListDetail 解析榜单歌曲（songlist[].data 嵌套）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/v8/fcg-bin/fcg_v8_toplist_cp.fcg');
          return _json({
            'code': 0,
            'songlist': [
              {
                'data': {
                  'songmid': '0019tNGN1TJbLT',
                  'songname': '游向陆地的鱼',
                  'singer': [
                    {'name': '梓渝'}
                  ],
                  'albummid': '0035Y3b01o1BsG',
                  'albumname': '梓渝',
                  'interval': 279,
                }
              }
            ],
          });
        });

      final tracks = await _api(dio).topListDetail(
        const MusicListInfo(
          id: '4',
          title: '巅峰榜·流行指数',
          sourceId: 'builtin_tx',
          sourceKey: 'tx',
          isRank: true,
        ),
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '0019tNGN1TJbLT');
      expect(tracks.first.title, '游向陆地的鱼');
      expect(tracks.first.artist, '梓渝');
      expect(tracks.first.album, '梓渝');
      expect(tracks.first.durationMs, 279000);
      expect(
        tracks.first.coverUrl,
        'https://y.gtimg.cn/music/photo_new/T002R300x300M0000035Y3b01o1BsG.jpg',
      );
    });

    test('cookie 无 uin 视为未登录', () async {
      final dio = Dio();
      final api = _api(dio, cookie: 'qqmusic_key=abc');
      expect(api.hasAccount, isFalse);
      expect(await api.lists(), isEmpty);
    });

    test('未登录时 lists/listDetail 返回空', () async {
      final dio = Dio();
      final api = _api(dio, cookie: '');
      expect(api.hasAccount, isFalse);
      expect(await api.lists(), isEmpty);
      expect(
        await api.listDetail(const MusicListInfo(
          id: kQqLikedPlaylistId,
          title: 'x',
          sourceId: 'builtin_tx',
          sourceKey: 'tx',
        )),
        isEmpty,
      );
    });
  });
}
