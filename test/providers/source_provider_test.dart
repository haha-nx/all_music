import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/providers/source_provider.dart';

void main() {
  group('ImportResult', () {
    test('ok factory returns success', () {
      final result = ImportResult.ok();
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('fail factory returns error', () {
      final result = ImportResult.fail('Connection refused');
      expect(result.success, isFalse);
      expect(result.error, 'Connection refused');
    });

    test('fail factory with empty string', () {
      final result = ImportResult.fail('');
      expect(result.success, isFalse);
      expect(result.error, '');
    });

    test('ok and fail are distinct', () {
      final ok = ImportResult.ok();
      final fail = ImportResult.fail('error');
      expect(ok.success, isNot(fail.success));
      expect(ok.error, isNot(fail.error));
    });
  });
}
