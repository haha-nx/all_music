import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/music_source/builtin/tencent_search_api.dart';
import 'package:all_music/music_source/models/music_track.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ID3 开头的假音频字节（探测识别 ID3 magic）
final Uint8List _fakeMp3 = Uint8List.fromList([
  0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
]);

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._vkeyJson, {this.onRequest});
  final String _vkeyJson;
  final void Function(RequestOptions)? onRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    onRequest?.call(options);
    // POST = musicu.fcg 取 vkey；GET = 探测 CDN 音频
    if (options.method == 'POST') {
      return Future.value(ResponseBody.fromString(
        _vkeyJson,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ));
    }
    return Future.value(ResponseBody.fromBytes(
      _fakeMp3,
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    ));
  }

  @override
  void close({bool force = false}) {}
}

MusicTrack _track(String mid) => MusicTrack(
      id: mid,
      title: '晴天',
      artist: '周杰伦',
      sourceId: 'builtin_tx',
      sourceKey: 'tx',
    );

String _vkeyResp(String purl) => jsonEncode({
      'req_0': {
        'code': 0,
        'data': {
          'sip': ['https://ws.stream.qqmusic.qq.com/'],
          'midurlinfo': [
            {'purl': purl}
          ],
        }
      }
    });

void main() {
  test('tencent musicUrl builds request and parses purl', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _MockAdapter(
        _vkeyResp('M5000039MnYb0qxYhV.mp3?fromtag=0'),
        onRequest: (o) {
          if (o.method == 'POST') captured = o;
        },
      );

    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc; qm_keyst=xyz',
      guidProvider: (_) => '12345678',
    );

    final url = await api.musicUrl(_track('0039MnYb0qxYhV'));

    expect(
        url,
        'https://ws.stream.qqmusic.qq.com/'
        'M5000039MnYb0qxYhV.mp3?fromtag=0');
    expect(captured.uri.toString(),
        'https://u.y.qq.com/cgi-bin/musicu.fcg');
    // 请求携带完整 cookie
    expect(captured.headers['cookie'],
        'uin=12345; qqmusic_key=abc; qm_keyst=xyz');
    // 请求体包含 guid 与 uin
    final body = jsonDecode(captured.data as String) as Map<String, dynamic>;
    final req0 = body['req_0'] as Map;
    expect((req0['param'] as Map)['guid'], '12345678');
    expect((req0['param'] as Map)['uin'], '12345');
    // filename 多档候选（M500=128k / M800=320k），否则服务器返回 C400 试听
    expect((req0['param'] as Map)['filename'], [
      'M5000039MnYb0qxYhV.mp3',
      'M8000039MnYb0qxYhV.mp3'
    ]);
    // 登录态：与 Mineradio 一致 qm_keyst 优先作 authst，ct=19
    expect((body['comm'] as Map)['uin'], '12345');
    expect((body['comm'] as Map)['ct'], 19);
    expect((body['comm'] as Map)['authst'], 'xyz');
  });

  test('tencent musicUrl returns null when server gives C400 trial',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _MockAdapter(
          _vkeyResp('C4000039MnYb0qxYhV.m4a?fromtag=0'));
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      guidProvider: (_) => '12345678',
    );
    final url = await api.musicUrl(_track('0039MnYb0qxYhV'));
    // 试听链接不应返回（宁缺勿滥，避免 64k 前奏冒充原曲）
    expect(url, isNull);
  });

  test('tencent musicUrl returns null without cookie', () async {
    final dio = Dio();
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => '',
      guidProvider: (_) => '12345678',
    );
    final url = await api.musicUrl(_track('x'));
    expect(url, isNull);
  });

  test('tencent musicUrl regenerates non-8-digit guid', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _MockAdapter(
        _vkeyResp('M5000039MnYb0qxYhV.mp3?fromtag=0'),
        onRequest: (o) {
          if (o.method == 'POST') captured = o;
        },
      );
    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      // 旧版本持久化的时间戳格式 guid 会失效，应自动重生成 8 位数字
      guidProvider: (_) => '1786340479',
    );
    final url = await api.musicUrl(_track('0039MnYb0qxYhV'));
    expect(url, isNotNull);
    final body = jsonDecode(captured.data as String) as Map<String, dynamic>;
    final guid = ((body['req_0'] as Map)['param'] as Map)['guid'] as String;
    expect(guid.length, 8);
    expect(int.tryParse(guid), isNotNull);
  });

  test('tencent musicUrl returns null when purl is empty', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockAdapter(_vkeyResp(''));

    final api = TencentSearchApi(
      sourceId: 'builtin_tx',
      dio: dio,
      cookieProvider: (_) => 'uin=12345; qqmusic_key=abc',
      guidProvider: (_) => '12345678',
    );
    final url = await api.musicUrl(_track('0039MnYb0qxYhV'));
    expect(url, isNull);
  });
}
