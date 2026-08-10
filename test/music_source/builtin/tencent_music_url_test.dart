import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/music_source/builtin/tencent_search_api.dart';
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

void main() {
  test('tencent musicUrl builds request and parses purl', () async {
    late RequestOptions captured;
    final dio = Dio()..httpClientAdapter = _MockAdapter((options) async {
      captured = options;
      return ResponseBody.fromString(
        jsonEncode({
          'req_0': {
            'code': 0,
            'data': {
              'sip': ['https://ws.stream.qqmusic.qq.com/'],
              'midurlinfo': [
                {'purl': 'M5000039MnYb0qxYhV.m4a?fromtag=0'}
              ],
            }
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc; qm_keyst=xyz',
      guidProvider: (_) => '1234567890',
    );

    final url = await api.musicUrl(
      MusicTrack(
        id: '0039MnYb0qxYhV',
        title: '晴天',
        artist: '周杰伦',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ),
    );

    expect(
        url, 'https://ws.stream.qqmusic.qq.com/M5000039MnYb0qxYhV.m4a?fromtag=0');
    expect(captured.uri.toString(),
        'https://u.y.qq.com/cgi-bin/musicu.fcg');
    // 请求携带完整 cookie
    expect(captured.headers['cookie'],
        'uin=12345; qqmusic_key=abc; qm_keyst=xyz');
    // 请求体包含 guid 与 uin
    final body = jsonDecode(captured.data as String) as Map<String, dynamic>;
    final req0 = body['req_0'] as Map;
    expect((req0['param'] as Map)['guid'], '1234567890');
    expect((req0['param'] as Map)['uin'], '12345');
    // filename 必须携带（M500=128k），否则服务器返回 C400 试听
    expect((req0['param'] as Map)['filename'], ['M5000039MnYb0qxYhV.m4a']);
    expect((body['comm'] as Map)['uin'], '12345');
  });

  test('tencent musicUrl returns null when server gives C400 trial',
      () async {
    final dio = Dio()..httpClientAdapter = _MockAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'req_0': {
            'code': 0,
            'data': {
              'sip': ['https://ws.stream.qqmusic.qq.com/'],
              'midurlinfo': [
                {'purl': 'C4000039MnYb0qxYhV.m4a?fromtag=0'}
              ],
            }
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      guidProvider: (_) => '1234567890',
    );
    final url = await api.musicUrl(
      MusicTrack(
        id: '0039MnYb0qxYhV',
        title: '晴天',
        artist: '周杰伦',
        sourceId: 'builtin_tx',
        sourceKey: 'tx',
      ),
    );
    // 试听链接不应返回（宁缺勿滥，避免 64k 前奏冒充原曲）
    expect(url, isNull);
  });

  test('tencent musicUrl returns null without cookie', () async {
    final dio = Dio();
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => '',
      guidProvider: (_) => '1234567890',
    );
    final url = await api.musicUrl(MusicTrack(
        id: 'x', title: 't', artist: 'a', sourceId: 'builtin_tx',
        sourceKey: 'tx'));
    expect(url, isNull);
  });

  test('tencent musicUrl returns null without guid', () async {
    final dio = Dio();
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      guidProvider: (_) => '',
    );
    final url = await api.musicUrl(MusicTrack(
        id: 'x', title: 't', artist: 'a', sourceId: 'builtin_tx',
        sourceKey: 'tx'));
    expect(url, isNull);
  });

  test('tencent musicUrl returns null when purl is empty', () async {
    final dio = Dio()..httpClientAdapter = _MockAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'req_0': {
            'code': 0,
            'data': {
              'sip': ['https://ws.stream.qqmusic.qq.com/'],
              'midurlinfo': [
                {'purl': ''}
              ],
            }
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      guidProvider: (_) => '1234567890',
    );
    final url = await api.musicUrl(MusicTrack(
        id: '0039MnYb0qxYhV', title: '晴天', artist: '周杰伦',
        sourceId: 'builtin_tx', sourceKey: 'tx'));
    expect(url, isNull);
  });
}
