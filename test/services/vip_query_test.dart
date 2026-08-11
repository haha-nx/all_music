import 'dart:convert';
import 'dart:typed_data';

import 'package:all_music/services/vip_query.dart';
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

void main() {
  group('网易云 VIP 查询', () {
    test('黑胶VIP（vipType=11）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          expect(options.uri.path, '/weapi/nuser/account/get');
          return _json({
            'profile': {'userId': 123456, 'vipType': 11},
          });
        });
      final status = await queryNeteaseVip(dio, cookie: 'MUSIC_U=xxx');
      expect(status, isNotNull);
      expect(status!.isVip, isTrue);
      expect(status.label, '黑胶VIP');
    });

    test('普通用户（vipType=0）', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return _json({
            'profile': {'userId': 123456, 'vipType': 0},
          });
        });
      final status = await queryNeteaseVip(dio, cookie: 'MUSIC_U=xxx');
      expect(status, isNotNull);
      expect(status!.isVip, isFalse);
      expect(status.label, '普通用户');
    });

    test('无 cookie 返回 null', () async {
      final dio = Dio();
      expect(await queryNeteaseVip(dio, cookie: ''), isNull);
    });
  });

  group('QQ 音乐 VIP 查询', () {
    test('豪华绿钻（VipQueryServer req_1.data）', () async {
      late String capturedBody;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          capturedBody = options.data as String;
          expect(options.uri.host, 'u.y.qq.com');
          return _json({
            'code': 0,
            'req_1': {
              'code': 0,
              'data': {
                'uin': '12345',
                'isvip': 1,
                'musicviptype': 1,
                'musicviplevel': 7,
                'musicvipexpiretime': 4102444800,
              },
            },
          });
        });

      final status = await queryQqVip(dio,
          cookie: 'uin=12345; qm_keyst=key');
      expect(status, isNotNull);
      expect(status!.isVip, isTrue);
      expect(status.label, '豪华绿钻 Lv7');
      expect(status.expireText, isNotNull);
      // authst 携带播放授权 key（qm_keyst）
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      final comm = (body['comm'] as Map).cast<String, dynamic>();
      expect(comm['authst'], 'key');
      expect((body['req_1'] as Map)['module'], 'userInfo.VipQueryServer');
    });

    test('非会员', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options) async {
          return _json({
            'code': 0,
            'req_1': {
              'code': 0,
              'data': {'uin': '12345', 'isvip': 0, 'musicviptype': 0},
            },
          });
        });
      final status =
          await queryQqVip(dio, cookie: 'uin=12345; qqmusic_key=key');
      expect(status, isNotNull);
      expect(status!.isVip, isFalse);
    });

    test('无 uin 返回 null', () async {
      final dio = Dio();
      expect(
        await queryQqVip(dio, cookie: 'qm_keyst=key'),
        isNull,
      );
    });
  });
}
