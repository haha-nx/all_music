import 'package:all_music/music_source/services/source_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceManager builtin sources', () {
    test('registers 5 builtin platforms with search backends', () async {
      final manager = SourceManager(Dio(), registerBuiltins: true);
      final ids = manager.sources.map((s) => s.id).toList();
      expect(
        ids,
        containsAll([
          'builtin_wy',
          'builtin_tx',
          'builtin_kg',
          'builtin_kw',
          'builtin_mg',
        ]),
      );

      final backend = await manager.getBackend('builtin_wy');
      expect(backend, isNotNull);
      expect(backend!.ready, isTrue);
      expect(backend.searchKeys, contains('wy'));
      expect(backend.capabilities['wy']?.actions, contains('search'));
    });

    test('registerBuiltins false keeps sources empty', () {
      final manager = SourceManager(Dio(), registerBuiltins: false);
      expect(manager.sources, isEmpty);
    });
  });
}
