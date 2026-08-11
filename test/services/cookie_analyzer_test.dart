import 'package:all_music/services/cookie_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cookie_analyzer', () {
    test('mergeCookies 合并多域并去重同名键（保留最后出现）', () {
      final merged = mergeCookies([
        'a=1; b=2',
        'b=3; c=4',
      ]);
      expect(merged.contains('a=1'), isTrue);
      expect(merged.contains('b=3'), isTrue);
      expect(merged.contains('b=2'), isFalse);
      expect(merged.contains('c=4'), isTrue);
    });

    test('mergeCookies 忽略空串与空 token', () {
      expect(mergeCookies(['', '  ', 'a=1']), 'a=1');
    });

    test('网易云缺 MUSIC_U 判定', () {
      expect(missingLoginKeys('wy', 'NMTID=abc; os=pc'), ['MUSIC_U']);
      expect(missingLoginKeys('wy', 'MUSIC_U=xyz; NMTID=abc'), isEmpty);
      expect(isValidLogin('wy', 'MUSIC_U=xyz'), isTrue);
      expect(isValidLogin('wy', 'NMTID=abc'), isFalse);
    });

    test('QQ 身份键与播放授权键', () {
      // 微信登录：wxuin + wxskey + wxopenid
      expect(
        isValidLogin('tx', 'wxuin=123; wxskey=abc; wxopenid=o1x2'),
        isTrue,
      );
      // QQ 号登录：uin + qqmusic_key
      expect(isValidLogin('tx', 'uin=456; qqmusic_key=def'), isTrue);
      // 有身份但缺播放授权键 → 不完整
      expect(missingLoginKeys('tx', 'uin=456'), isNotEmpty);
      // 完全无效
      expect(isValidLogin('tx', 'NMTID=abc'), isFalse);
    });
  });
}
