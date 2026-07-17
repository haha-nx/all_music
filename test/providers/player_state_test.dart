import 'package:flutter_test/flutter_test.dart';
import 'package:all_music/providers/player_provider.dart';
import 'package:all_music/models/song.dart';
import 'package:all_music/models/lyric.dart';
import 'package:all_music/models/source_type.dart';

void main() {
  group('PlayerState', () {
    test('default state is idle', () {
      const state = PlayerState();
      expect(state.currentSong, isNull);
      expect(state.isPlaying, isFalse);
      expect(state.shuffleMode, isFalse);
      expect(state.repeatMode, MusicRepeatMode.off);
      expect(state.queue, isEmpty);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.lyricLines, isEmpty);
      expect(state.currentLyricIndex, 0);
      expect(state.showLyrics, isFalse);
    });

    test('copyWith updates single field', () {
      const state = PlayerState();
      final updated = state.copyWith(isPlaying: true);
      expect(updated.isPlaying, isTrue);
      expect(updated.currentSong, isNull); // unchanged
    });

    test('copyWith updates multiple fields', () {
      const state = PlayerState();
      final updated = state.copyWith(
        isPlaying: true,
        position: Duration(seconds: 30),
        shuffleMode: true,
      );
      expect(updated.isPlaying, isTrue);
      expect(updated.position, const Duration(seconds: 30));
      expect(updated.shuffleMode, isTrue);
      expect(updated.repeatMode, MusicRepeatMode.off); // unchanged
    });

    test('copyWith sets isPlaying to true', () {
      final song = Song(
        id: 'test',
        name: 'Test',
        artist: 'Tester',
        source: SourceType.online,
      );
      final state = PlayerState(currentSong: song);
      expect(state.currentSong, isNotNull);

      final playing = state.copyWith(isPlaying: true);
      expect(playing.isPlaying, isTrue);
      expect(playing.currentSong, song); // preserved
    });
  });

  group('MusicRepeatMode', () {
    test('values enum is defined', () {
      expect(MusicRepeatMode.values, hasLength(3));
      expect(MusicRepeatMode.values, contains(MusicRepeatMode.off));
      expect(MusicRepeatMode.values, contains(MusicRepeatMode.all));
      expect(MusicRepeatMode.values, contains(MusicRepeatMode.one));
    });
  });

  group('Lyric integration', () {
    test('currentLyricIndex defaults to 0', () {
      const state = PlayerState();
      expect(state.currentLyricIndex, 0);
    });

    test('lyricLines starts empty', () {
      const state = PlayerState();
      expect(state.lyricLines, isEmpty);
    });

    test('state with lyrics preserves lines', () {
      final lines = [
        LyricLine(time: Duration.zero, text: 'Hello'),
        LyricLine(time: const Duration(seconds: 5), text: 'World'),
      ];
      final state = const PlayerState().copyWith(
        lyricLines: lines,
        currentLyricIndex: 1,
      );
      expect(state.lyricLines, hasLength(2));
      expect(state.currentLyricIndex, 1);
    });
  });
}
