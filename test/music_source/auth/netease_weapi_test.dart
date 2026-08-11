import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/music_source/auth/netease_weapi.dart';
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
  group('NeteaseWeapi crypto', () {
    test('randomKey returns 16 hex chars', () {
      final key = NeteaseWeapi.randomKey();
      expect(key, hasLength(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(key), isTrue);
    });

    test('aesEncrypt produces valid base64 of full blocks', () {
      final enc = NeteaseWeapi.aesEncrypt(
          '{"ids":"[1]"}', '0CoJUm6Qyw8W8jud', '0102030405060708');
      expect(enc, isNotEmpty);
      // base64 解码后应为 16 字节整数倍（AES 块）
      final bytes = base64Decode(enc);
      expect(bytes.length % 16, 0);
    });

    test('rsaEncrypt output length is 256 hex chars (128 bytes)', () {
      final enc = NeteaseWeapi.rsaEncrypt(NeteaseWeapi.randomKey());
      expect(enc, hasLength(256));
      expect(RegExp(r'^[0-9a-f]{256}$').hasMatch(enc), isTrue);
    });
  });

  group('NeteaseWeapi musicUrl', () {
    test('请求 v1 接口并解析 url（含可播性探测）', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          if (options.method == 'POST') {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'code': 200,
                'data': [
                  {
                    'id': 186016,
                    'url': 'https://m701.music.126.net/full.mp3',
                    'br': 320000,
                  }
                ]
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType]
              },
            );
          }
          // Range 探测请求 → 返回 MP3 音频字节（ID3 头）
          return ResponseBody.fromBytes(
            Uint8List.fromList(const [0x49, 0x44, 0x33, 0x04, 0x00, 0x00]),
            206,
            headers: {Headers.contentTypeHeader: ['audio/mpeg']},
          );
        });

      final url = await NeteaseWeapi.musicUrl(
        dio,
        songId: '186016',
        cookie: 'MUSIC_U=abc; __csrf=xyz',
        quality: '320k',
      );
      expect(url, 'https://m701.music.126.net/full.mp3');
      expect(captured.uri.path, '/weapi/song/enhance/player/url/v1');
      // 登录态 cookie 随请求携带
      expect(captured.headers['cookie'], 'MUSIC_U=abc; __csrf=xyz');
      // body 为 weapi 加密格式（params/encSecKey）
      final body = captured.data as Map<String, dynamic>;
      expect(body['params'], isA<String>());
      expect(body['encSecKey'], isA<String>());
    });

    test('探测失败（非音频响应）时返回 null', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          if (options.method == 'POST') {
            return ResponseBody.fromString(
              jsonEncode({
                'code': 200,
                'data': [
                  {
                    'id': 186016,
                    'url': 'https://m701.music.126.net/full.mp3',
                  }
                ]
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType]
              },
            );
          }
          // 探测返回 404 → 不可播
          return ResponseBody.fromString('not found', 404);
        });
      final url = await NeteaseWeapi.musicUrl(
        dio,
        songId: '186016',
        cookie: 'MUSIC_U=abc',
        quality: '320k',
      );
      expect(url, isNull);
    });

    test('无 url 返回 null（试听/无权限时 data[0].url 为空）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {'id': 186016, 'url': null}
              ]
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        });
      final url = await NeteaseWeapi.musicUrl(
        dio,
        songId: '186016',
        cookie: 'MUSIC_U=abc',
        quality: '320k',
      );
      expect(url, isNull);
    });
  });
}
