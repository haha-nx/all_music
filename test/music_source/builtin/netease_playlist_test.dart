import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/music_source/builtin/netease_search_api.dart';
import 'package:all_music/music_source/models/music_list.dart';
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

NeteaseSearchApi _api(Dio dio, {String cookie = ''}) => NeteaseSearchApi(
      sourceId: 'builtin_wy',
      dio: dio,
      cookieProvider: (_) => cookie,
    );

void main() {
  group('netease 我喜欢的音乐（weapi 登录态）', () {
    test('lists 返回「我喜欢的音乐」卡片（specialType==5）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          final path = options.uri.path;
          if (path == '/weapi/nuser/account/get') {
            return _json({'profile': {'userId': 123456}});
          }
          if (path == '/weapi/user/playlist') {
            return _json({
              'playlist': [
                {
                  'id': 111,
                  'name': '我喜欢的音乐',
                  'specialType': 5,
                  'trackCount': 88,
                  'coverImgUrl': 'https://p1.music.126.net/liked.jpg',
                },
                {
                  'id': 222,
                  'name': '我的普通歌单',
                  'specialType': 0,
                  'trackCount': 3,
                },
              ]
            });
          }
          return _json({});
        });

      final lists = await _api(dio, cookie: 'MUSIC_U=xxx').lists();
      expect(lists, hasLength(1));
      expect(lists.first.id, '111');
      expect(lists.first.title, '我喜欢的音乐');
      expect(lists.first.songCount, 88);
      expect(lists.first.picUrl, 'https://p1.music.126.net/liked.jpg');
      expect(lists.first.sourceKey, 'wy');
    });

    test('listDetail 解析歌单歌曲', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/weapi/v6/playlist/detail');
          return _json({
            'playlist': {
              'tracks': [
                {
                  'id': 186016,
                  'name': '晴天',
                  'ar': [
                    {'name': '周杰伦'},
                    {'name': '杨瑞代'},
                  ],
                  'al': {
                    'name': '叶惠美',
                    'picUrl': 'https://p1.music.126.net/cover.jpg',
                  },
                  'dt': 269000,
                }
              ]
            }
          });
        });

      final tracks = await _api(dio, cookie: 'MUSIC_U=xxx').listDetail(
        const MusicListInfo(
          id: '111',
          title: '我喜欢的音乐',
          sourceId: 'builtin_wy',
          sourceKey: 'wy',
        ),
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.id, '186016');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦/杨瑞代');
      expect(tracks.first.album, '叶惠美');
      expect(tracks.first.coverUrl, 'https://p1.music.126.net/cover.jpg');
      expect(tracks.first.durationMs, 269000);
    });

    test('listDetail 歌单快照 http 封面统一转 https（Android cleartext 拦截）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return _json({
            'playlist': {
              'tracks': [
                {
                  'id': 186016,
                  'name': '晴天',
                  'ar': [
                    {'name': '周杰伦'}
                  ],
                  'al': {
                    'name': '叶惠美',
                    'picUrl': 'http://p1.music.126.net/cover.jpg',
                  },
                  'dt': 269000,
                }
              ]
            }
          });
        });

      final tracks = await _api(dio, cookie: 'MUSIC_U=xxx').listDetail(
        const MusicListInfo(
          id: '111',
          title: '我喜欢的音乐',
          sourceId: 'builtin_wy',
          sourceKey: 'wy',
        ),
      );
      expect(tracks.first.coverUrl, 'https://p1.music.126.net/cover.jpg');
    });

    test('lists 歌单封面 http 转 https', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          final path = options.uri.path;
          if (path == '/weapi/nuser/account/get') {
            return _json({'profile': {'userId': 123456}});
          }
          if (path == '/weapi/user/playlist') {
            return _json({
              'playlist': [
                {
                  'id': 111,
                  'name': '我喜欢的音乐',
                  'specialType': 5,
                  'trackCount': 88,
                  'coverImgUrl': 'http://p1.music.126.net/liked.jpg',
                },
              ]
            });
          }
          return _json({});
        });

      final lists = await _api(dio, cookie: 'MUSIC_U=xxx').lists();
      expect(lists.first.picUrl, 'https://p1.music.126.net/liked.jpg');
    });

    test('search 封面缺失时用 song/detail 批量补全并转 https', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          if (options.uri.path == '/api/search/get/web') {
            return _json({
              'result': {
                'songs': [
                  {
                    'id': 186016,
                    'name': '晴天',
                    'artists': [
                      {'name': '周杰伦'}
                    ],
                    'album': {'name': '叶惠美'},
                  },
                  {
                    'id': 186017,
                    'name': '三年二班',
                    'artists': [
                      {'name': '周杰伦'}
                    ],
                    'album': {
                      'name': '叶惠美',
                      'picUrl': 'http://p1.music.126.net/has.jpg',
                    },
                  },
                ]
              }
            });
          }
          if (options.uri.path == '/api/song/detail/') {
            return _json({
              'songs': [
                {
                  'id': 186016,
                  'album': {
                    'name': '叶惠美',
                    'picUrl': 'http://p1.music.126.net/filled.jpg',
                  },
                },
              ]
            });
          }
          return _json({});
        });

      final tracks = await _api(dio).search('晴天');
      expect(tracks, hasLength(2));
      // 缺封面的补全
      expect(tracks[0].coverUrl, 'https://p1.music.126.net/filled.jpg');
      // 已有封面仅转 https，不再被覆盖
      expect(tracks[1].coverUrl, 'https://p1.music.126.net/has.jpg');
    });

    test('topLists 解析官方榜单（/api/toplist）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/api/toplist');
          return _json({
            'code': 200,
            'list': [
              {
                'id': 19723756,
                'name': '飙升榜',
                'coverImgUrl': 'http://p2.music.126.net/a.jpg',
                'updateFrequency': '刚刚更新',
              },
              {'id': 3779629, 'name': '新歌榜'},
            ],
          });
        });

      final lists = await _api(dio).topLists(limit: 30);
      expect(lists, hasLength(2));
      expect(lists.first.id, '19723756');
      expect(lists.first.title, '飙升榜');
      expect(lists.first.picUrl, 'https://p2.music.126.net/a.jpg');
      expect(lists.first.sourceKey, 'wy');
      expect(lists.first.isRank, isTrue);
    });

    test('topListDetail 用公开接口解析榜单歌曲（匿名可用）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/api/v6/playlist/detail');
          return _json({
            'code': 200,
            'playlist': {
              'tracks': [
                {
                  'id': 186016,
                  'name': '晴天',
                  'ar': [
                    {'name': '周杰伦'}
                  ],
                  'al': {
                    'name': '叶惠美',
                    'picUrl': 'http://p1.music.126.net/cover.jpg',
                  },
                  'dt': 269000,
                },
              ],
            },
          });
        });

      // 无需 cookie（匿名）
      final tracks = await _api(dio).topListDetail(
        const MusicListInfo(
          id: '19723756',
          title: '飙升榜',
          sourceId: 'builtin_wy',
          sourceKey: 'wy',
          isRank: true,
        ),
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.title, '晴天');
      expect(tracks.first.coverUrl, 'https://p1.music.126.net/cover.jpg');
    });

    test('listDetail 在 v6 detail tracks 为空时走 trackIds→song/detail 流程',
        () async {
      var v6Calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          final path = options.uri.path;
          if (path == '/weapi/v6/playlist/detail') {
            v6Calls++;
            if (v6Calls == 1) {
              // 详情接口 playlist.tracks 为空（只返回 trackIds）
              return _json({
                'playlist': {'tracks': []}
              });
            }
            // trackIds 查询（n=100000）
            return _json({
              'playlist': {
                'trackIds': [
                  {'id': 186016},
                  {'id': 186017},
                ]
              }
            });
          }
          if (path == '/weapi/v3/song/detail') {
            return _json({
              'songs': [
                {
                  'id': 186016,
                  'name': '晴天',
                  'ar': [
                    {'name': '周杰伦'}
                  ],
                  'al': {'name': '叶惠美'},
                  'dt': 269000,
                },
                {
                  'id': 186017,
                  'name': '七里香',
                  'ar': [
                    {'name': '周杰伦'}
                  ],
                  'al': {'name': '七里香'},
                  'dt': 300000,
                },
              ]
            });
          }
          return _json({});
        });

      final tracks = await _api(dio, cookie: 'MUSIC_U=xxx').listDetail(
        const MusicListInfo(
          id: '111',
          title: '我喜欢的音乐',
          sourceId: 'builtin_wy',
          sourceKey: 'wy',
        ),
      );
      expect(tracks, hasLength(2));
      expect(tracks.first.id, '186016');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.durationMs, 269000);
      expect(v6Calls, 2); // 详情 + trackIds 两次
    });

    test('未登录时 lists/listDetail 返回空', () async {
      final dio = Dio();
      final api = _api(dio); // 无 cookie
      expect(await api.lists(), isEmpty);
      expect(
        await api.listDetail(const MusicListInfo(
          id: '111',
          title: 'x',
          sourceId: 'builtin_wy',
          sourceKey: 'wy',
        )),
        isEmpty,
      );
      expect(api.hasAccount, isFalse);
    });
  });
}
