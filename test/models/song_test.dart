import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/models/song.dart';
import 'package:all_music/models/source_type.dart';

void main() {
  group('Song model', () {
    test('defaults and dedupeKey', () {
      final song = Song(
        id: '123',
        name: 'Fly Me to the Moon',
        artist: 'Frank Sinatra',
        source: SourceType.api,
      );
      expect(song.id, '123');
      expect(song.name, 'Fly Me to the Moon');
      expect(song.artist, 'Frank Sinatra');
      expect(song.dedupeKey, 'api:fly me to the moon:frank sinatra');
    });

    test('dedupeKey normalizes text', () {
      final song = Song(
        id: 'x',
        name: '  HELLO  World  ',
        artist: '  Adele  ',
        source: SourceType.api,
      );
      expect(song.dedupeKey, 'api:hello  world:adele');
    });

    test('copyWith preserves unchanged fields', () {
      final original = Song(
        id: '1',
        name: 'Yesterday',
        artist: 'The Beatles',
        album: 'Help!',
        source: SourceType.api,
      );
      final copy = original.copyWith(name: 'Tomorrow');
      expect(copy.name, 'Tomorrow');
      expect(copy.artist, 'The Beatles');
      expect(copy.album, 'Help!');
      expect(copy.id, '1');
    });

    test('toMap and fromMap round-trip', () {
      final song = Song(
        id: 'id-1',
        name: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        albumCover: 'https://example.com/cover.jpg',
        source: SourceType.api,
        sourceId: 'src-1',
      );
      final map = song.toMap();
      final restored = Song.fromMap(map);
      expect(restored.id, song.id);
      expect(restored.name, song.name);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.dedupeKey, song.dedupeKey);
      expect(restored.source, song.source);
    });

    test('source defaults work correctly', () {
      final local = Song(
        id: '/path/song.mp3',
        name: 'Local Track',
        artist: 'Unknown',
        source: SourceType.local,
      );
      expect(local.source, SourceType.local);

      final api = Song(
        id: '0',
        name: 'Online Track',
        artist: 'Artist',
        source: SourceType.api,
      );
      expect(api.source, SourceType.api);
    });
  });
}
