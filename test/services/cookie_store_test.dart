import 'package:all_music/providers/account_center_provider.dart';
import 'package:all_music/services/cookie_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountCredential serialization', () {
    test('toJson/fromJson round-trip', () {
      final cred = AccountCredential(
        platformKey: 'tx',
        cookie: 'uin=123; qqmusic_key=abc',
        guid: 'g1',
        loggedInAt: DateTime(2026, 8, 7, 12, 0, 0),
      );
      final restored = AccountCredential.fromJson(cred.toJson());
      expect(restored.platformKey, 'tx');
      expect(restored.cookie, 'uin=123; qqmusic_key=abc');
      expect(restored.guid, 'g1');
      expect(restored.loggedInAt, DateTime(2026, 8, 7, 12, 0, 0));
      expect(restored.isLoggedIn, isTrue);
    });

    test('fromJson tolerates empty cookie', () {
      final cred = AccountCredential.fromJson({
        'platformKey': 'wy',
        'cookie': '',
        'loggedInAt': '2026-08-07T12:00:00.000',
      });
      expect(cred.isLoggedIn, isFalse);
    });

    test('fromJson tolerates missing fields', () {
      final cred = AccountCredential.fromJson({'platformKey': 'kg'});
      expect(cred.cookie, '');
      expect(cred.guid, isNull);
      expect(cred.loggedInAt, isA<DateTime>());
    });
  });

  group('AccountCenterNotifier guid generation', () {
    test('generateGuid returns 10-digit string', () {
      final guid = AccountCenterNotifier.generateGuid();
      expect(guid, hasLength(10));
      expect(int.tryParse(guid), isNotNull);
    });

    test('generateGuid is stable length across calls', () {
      for (var i = 0; i < 20; i++) {
        expect(AccountCenterNotifier.generateGuid(), hasLength(10));
      }
    });
  });
}
