import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:all_music/providers/search_provider.dart';
import 'package:all_music/music_source/models/source_definition.dart';
import 'package:all_music/music_source/providers/music_source_provider.dart';

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
      final updated = state.copyWith(failedSources: ['Source A', 'Source B']);
      expect(updated.failedSources, ['Source A', 'Source B']);
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
          sourceListProvider.overrideWith(
              (ref) => SourceListNotifier(Dio())..state = []),
          searchProvider.overrideWith((ref) => SearchNotifier(ref)),
        ],
      );

      await container.read(searchProvider.notifier).search('test keyword');
      final state = container.read(searchProvider);
      expect(state.hasSearched, isTrue);
      expect(state.isLoading, isFalse);

      container.dispose();
    });

    test('search with only disabled sources', () async {
      final container = ProviderContainer(
        overrides: [
          sourceListProvider.overrideWith((ref) => SourceListNotifier(Dio())..state = [
            SourceDefinition(
              id: 's1',
              name: 'Disabled',
              scriptSource: '',
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

      container.dispose();
    });
  });
}
