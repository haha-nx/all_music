import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:all_music/providers/search_provider.dart';
import 'package:all_music/providers/source_provider.dart';
import 'package:all_music/models/music_source.dart';

void main() {
  group('SearchState', () {
    test('default state is empty and idle', () {
      const state = SearchState();
      expect(state.results, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.hasSearched, isFalse);
      expect(state.failedSources, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      const state = SearchState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.hasSearched, isFalse);
      expect(updated.results, isEmpty);
    });

    test('copyWith with failedSources tracks correctly', () {
      const state = SearchState();
      final updated = state.copyWith(
        isLoading: false,
        hasSearched: true,
        failedSources: ['Source A', 'Source B'],
      );
      expect(updated.failedSources, hasLength(2));
      expect(updated.failedSources, contains('Source A'));
      expect(updated.hasSearched, isTrue);
    });

    test('copyWith clears failedSources when reset', () {
      final state = SearchState(failedSources: ['Old Source']);
      final reset = state.copyWith(failedSources: []);
      expect(reset.failedSources, isEmpty);
    });

    test('copyWith with error string works', () {
      final state = const SearchState().copyWith(
        error: 'Network timeout',
        hasSearched: true,
      );
      expect(state.error, 'Network timeout');
      expect(state.results, isEmpty);
    });
  });

  group('SearchNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer(
        overrides: [
          searchProvider.overrideWith((ref) => SearchNotifier(ref)),
        ],
      );
      final state = container.read(searchProvider);
      expect(state.results, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasSearched, isFalse);
      container.dispose();
    });

    test('clear resets to initial state', () {
      final container = ProviderContainer(
        overrides: [
          searchProvider.overrideWith((ref) => SearchNotifier(ref)),
        ],
      );

      // simulate a state change directly
      final notifier = container.read(searchProvider.notifier);
      notifier.state = SearchState(
        results: [],
        isLoading: false,
        hasSearched: true,
        failedSources: ['Source X'],
      );
      expect(notifier.state.hasSearched, isTrue);

      notifier.clear();
      expect(notifier.state.hasSearched, isFalse);
      expect(notifier.state.failedSources, isEmpty);

      container.dispose();
    });

    test('search sets hasSearched to true on empty sources', () async {
      final container = ProviderContainer(
        overrides: [
          sourceProvider.overrideWith((ref) => SourceNotifier()..state = []),
          searchProvider.overrideWith((ref) => SearchNotifier(ref)),
        ],
      );

      await container.read(searchProvider.notifier).search('test keyword');
      final state = container.read(searchProvider);
      expect(state.hasSearched, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.results, isEmpty);
      expect(state.failedSources, isEmpty);
      expect(state.error, isNull);

      container.dispose();
    });

    test('search with only disabled sources succeeds with empty results', () async {
      final container = ProviderContainer(
        overrides: [
          sourceProvider.overrideWith((ref) => SourceNotifier()..state = [
            MusicSource(
              id: 's1',
              name: 'Disabled',
              apiUrl: 'https://example.com',
              enabled: false,
              createdAt: DateTime.now(),
            ),
          ]),
          searchProvider.overrideWith((ref) => SearchNotifier(ref)),
        ],
      );

      await container.read(searchProvider.notifier).search('anything');
      final state = container.read(searchProvider);
      expect(state.hasSearched, isTrue);
      expect(state.results, isEmpty);

      container.dispose();
    });
  });
}
