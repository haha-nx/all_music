import 'package:all_music/models/song.dart';
import 'package:all_music/models/source_type.dart';
import 'package:all_music/music_source/core/track_adapter.dart';
import 'package:all_music/music_source/models/music_track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawData =
      '{"id":"003cI52o4daJJL","songmid":"003cI52o4daJJL","name":"花海","singer":"周杰伦"}';

  group('TrackAdapter rawData round trip', () {
    test('MusicTrack -> Song preserves rawData', () {
      final track = MusicTrack(
        id: '003cI52o4daJJL',
        title: '花海',
        artist: '周杰伦',
        sourceId: 'lx',
        sourceKey: 'tx',
        rawData: rawData,
      );

      final song = TrackAdapter.toLegacySong(track);

      expect(song.rawData, rawData);
    });

    test('Song -> MusicTrack preserves rawData', () {
      final song = Song(
        id: '003cI52o4daJJL',
        source: SourceType.online,
        name: '花海',
        artist: '周杰伦',
        sourceId: 'lx',
        sourceKey: 'tx',
        rawData: rawData,
      );

      final track = TrackAdapter.fromLegacySong(song);

      expect(track.rawData, rawData);
    });

    test('Song toMap/fromMap preserves rawData', () {
      final song = Song(
        id: '003cI52o4daJJL',
        source: SourceType.online,
        name: '花海',
        artist: '周杰伦',
        sourceId: 'lx',
        sourceKey: 'tx',
        rawData: rawData,
      );

      final restored = Song.fromMap(song.toMap());

      expect(restored.rawData, rawData);
    });
  });
}
