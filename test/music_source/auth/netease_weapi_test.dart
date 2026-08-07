import 'dart:convert';

import 'package:all_music/music_source/auth/netease_weapi.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(enc.isNotEmpty, isTrue);
      // base64 解码成功，且密文为 16 字节整数倍（PKCS7 padding）
      final bytes = base64Decode(enc);
      expect(bytes.length % 16, 0);
      expect(bytes.length, greaterThan(0));
    });

    test('rsaEncrypt output length is 256 hex chars (128 bytes)', () {
      final enc = NeteaseWeapi.rsaEncrypt(NeteaseWeapi.randomKey());
      expect(enc, hasLength(256));
      expect(RegExp(r'^[0-9a-f]{256}$').hasMatch(enc), isTrue);
    });
  });
}
