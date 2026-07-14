import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/providers/favorites_provider.dart';
import 'package:all_music/models/song.dart';
import 'package:all_music/models/source_type.dart';

Song _song(String id, String name) => Song(
      id: id,
      name: name,
      artist: 'Test Artist',
      source: SourceType.api,
    );

void main() {
  group('FavoritesState', () {
    test('default state has empty lists', () {
      const state = FavoritesState();
      expect(state.favorites, isEmpty);
      expect(state.recentlyPlayed, isEmpty);
    });

    test('maxRecent is 50', () {
      expect(FavoritesState.maxRecent, 50);
    });

    test('copyWith preserves unchanged fields', () {
      final favorites = [_song('1', 'Song 1')];
      final state = FavoritesState(favorites: favorites);
      final updated = state.copyWith(recentlyPlayed: [_song('2', 'Song 2')]);
      expect(updated.favorites, hasLength(1));
      expect(updated.recentlyPlayed, hasLength(1));
    });

    test('copyWith with null preserves favorites', () {
      final favorites = [_song('1', 'Song 1')];
      final state = FavoritesState(favorites: favorites);
      final updated = state.copyWith(recentlyPlayed: [_song('2', 'Song 2')]);
      expect(updated.favorites, equals(favorites));
    });
  });

  group('FavoritesNotifier pure logic', () {
    test('toggleFavorite adds song when not present', () {
      final notifier = FavoritesNotifier();
      final song = _song('add', 'Add Song');

      // Set state manually to skip async init
      notifier.state = const FavoritesState();
      notifier.toggleFavorite(song);

      expect(notifier.state.favorites, hasLength(1));
      expect(notifier.isFavorite(song), isTrue);
    });

    test('toggleFavorite removes song when present', () {
      final notifier = FavoritesNotifier();
      final song = _song('remove', 'Remove Song');

      notifier.state = FavoritesState(favorites: [song]);
      notifier.toggleFavorite(song);

      expect(notifier.state.favorites, isEmpty);
      expect(notifier.isFavorite(song), isFalse);
    });

    test('isFavorite returns false for absent song', () {
      final notifier = FavoritesNotifier();
      notifier.state = const FavoritesState();
      expect(notifier.isFavorite(_song('nope', 'Nope')), isFalse);
    });

    test('addToRecent pushes song to front', () {
      final notifier = FavoritesNotifier();
      final oldSong = _song('old', 'Old Song');
      final newSong = _song('new', 'New Song');

      notifier.state = FavoritesState(recentlyPlayed: [oldSong]);
      notifier.addToRecent(newSong);

      expect(notifier.state.recentlyPlayed, hasLength(2));
      expect(notifier.state.recentlyPlayed.first.id, 'new');
    });

    test('addToRecent de-duplicates and moves to front', () {
      final notifier = FavoritesNotifier();
      final song1 = _song('a', 'Song A');
      final song2 = _song('b', 'Song B');

      notifier.state = FavoritesState(recentlyPlayed: [song1, song2]);
      notifier.addToRecent(song2);

      expect(notifier.state.recentlyPlayed, hasLength(2));
      expect(notifier.state.recentlyPlayed.first.id, 'b');
    });

    test('addToRecent caps at maxRecent', () {
      final notifier = FavoritesNotifier();

      // Fill with maxRecent songs
      final many = List.generate(
        FavoritesState.maxRecent + 10,
        (i) => _song('$i', 'Song $i'),
      );
      notifier.state = FavoritesState(recentlyPlayed: many);

      // Add new one
      final newSong = _song('new', 'New Song');
      notifier.addToRecent(newSong);

      expect(
        notifier.state.recentlyPlayed.length,
        lessThanOrEqualTo(FavoritesState.maxRecent),
      );
      expect(notifier.state.recentlyPlayed.first.id, 'new');
    });

    test('clearRecent empties the list', () {
      final notifier = FavoritesNotifier();
      notifier.state = FavoritesState(
        recentlyPlayed: [_song('1', 'Song 1')],
      );
      notifier.clearRecent();
      expect(notifier.state.recentlyPlayed, isEmpty);
    });
  });
}
