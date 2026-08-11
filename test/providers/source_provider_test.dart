import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/music_source/models/source_definition.dart';

void main() {
  final testSource = SourceDefinition(
    id: 'test-id',
    name: 'Test Source',
    scriptSource: '// test script',
    createdAt: DateTime.now(),
  );

  group('SourceImportResult', () {
    test('ok factory returns success', () {
      final result = SourceImportResult.ok(testSource);
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.source, testSource);
    });

    test('fail factory returns error', () {
      final result = SourceImportResult.fail('Connection refused');
      expect(result.success, isFalse);
      expect(result.error, 'Connection refused');
    });

    test('fail factory with empty string', () {
      final result = SourceImportResult.fail('');
      expect(result.success, isFalse);
      expect(result.error, '');
    });

    test('ok and fail are distinct', () {
      final ok = SourceImportResult.ok(testSource);
      final fail = SourceImportResult.fail('error');
      expect(ok.success, isNot(fail.success));
      expect(ok.error, isNot(fail.error));
    });
  });
}
