import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/models/playlist.dart';
import 'package:all_music/models/song.dart';
import 'package:all_music/models/source_type.dart';

void main() {
  final testSong1 = Song(
    id: 's1',
    name: 'Song One',
    artist: 'Artist A',
    source: SourceType.api,
  );

  final testSong2 = Song(
    id: 's2',
    name: 'Song Two',
    artist: 'Artist B',
    source: SourceType.api,
  );

  group('Playlist model', () {
    test('empty playlist has zero count and duration', () {
      final p = Playlist(
        id: 'pl-1',
        name: 'Empty',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(p.songCount, 0);
      expect(p.totalDuration, Duration.zero);
      expect(p.isMixed, isFalse);
    });

    test('songCount reflects songs list', () {
      final p = Playlist(
        id: 'pl-2',
        name: 'My Mix',
        songs: [testSong1, testSong2],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(p.songCount, 2);
    });

    test('isMixed detects multiple sources', () {
      final p = Playlist(
        id: 'pl-3',
        name: 'Mixed',
        songs: [testSong1, testSong2],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(p.isMixed, isTrue);
    });

    test('isMixed false for single source', () {
      final p = Playlist(
        id: 'pl-4',
        name: 'Same Source',
        songs: [testSong1, testSong1.copyWith(id: 's1b')],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(p.isMixed, isFalse);
    });

    test('copyWith updates fields correctly', () {
      final original = Playlist(
        id: 'pl-5',
        name: 'Original',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final renamed = original.copyWith(name: 'Renamed');
      expect(renamed.name, 'Renamed');
      expect(renamed.id, 'pl-5');
    });

    test('toMap and fromMap round-trip', () {
      final playlist = Playlist(
        id: 'pl-roundtrip',
        name: 'Test Playlist',
        songs: [testSong1],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 7, 13),
      );
      final map = playlist.toMap();
      final restored = Playlist.fromMap(map);
      expect(restored.id, playlist.id);
      expect(restored.name, playlist.name);
      expect(restored.songCount, playlist.songCount);
      expect(restored.type, playlist.type);
    });
  });
}
