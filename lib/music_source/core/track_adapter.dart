import '../../models/song.dart';
import '../../models/source_type.dart';
import '../models/music_track.dart';

/// 新 MusicTrack ↔ 现有 Song 模型适配器
///
/// 用于桥接新的音源模块和现有的播放器/UI。
class TrackAdapter {
  /// MusicTrack → Song（用于播放器）
  static Song toLegacySong(MusicTrack track) {
    return Song(
      id: track.id,
      source: SourceType.online,
      name: track.title,
      artist: track.artist,
      album: track.album,
      albumCover: track.coverUrl,
      duration: track.durationMs != null
          ? Duration(milliseconds: track.durationMs!)
          : null,
      lyricId: track.lyricId,
      sourceId: track.sourceId,
      sourceKey: track.sourceKey,
      rawData: track.rawData,
    );
  }

  /// Song → MusicTrack（反向转换）
  static MusicTrack fromLegacySong(Song song) {
    return MusicTrack(
      id: song.id,
      title: song.name,
      artist: song.artist,
      album: song.album,
      coverUrl: song.albumCover,
      durationMs: song.duration?.inMilliseconds,
      sourceId: song.sourceId ?? '',
      sourceKey: song.sourceKey ?? '',
      lyricId: song.lyricId,
      rawData: song.rawData,
    );
  }

  /// 批量转换
  static List<Song> toLegacySongs(List<MusicTrack> tracks) =>
      tracks.map(toLegacySong).toList();

  static List<MusicTrack> fromLegacySongs(List<Song> songs) =>
      songs.map(fromLegacySong).toList();
}
