import 'source_type.dart';

/// 统一歌曲模型 — 跨平台通用
class Song {
  final String id;
  final SourceType source;
  final String name;
  final String artist;
  final String? album;
  final String? albumCover;
  final Duration? duration;
  final String? lyricId;

  /// 音源 ID，用于关联到对应的 MusicSource
  final String? sourceId;

  /// 脚本内的源 key（如 kw/kg/tx/wy/mg 等）
  /// 由源脚本在搜索结果中提供，用于区分同一脚本的不同平台
  final String? sourceKey;

  /// 搜索结果的完整原始 JS 数据（JSON），用于获取播放 URL/歌词时回传脚本
  final String? rawData;

  const Song({
    required this.id,
    required this.source,
    required this.name,
    required this.artist,
    this.album,
    this.albumCover,
    this.duration,
    this.lyricId,
    this.sourceId,
    this.sourceKey,
    this.rawData,
  });

  /// 跨平台去重 key：同名同歌手视为同一首歌
  String get dedupeKey =>
      '${source.key}:${name.toLowerCase().trim()}:${artist.toLowerCase().trim()}';

  /// 显示用的来源标签
  String get sourceLabel => source.label;

  Song copyWith({
    String? id,
    SourceType? source,
    String? name,
    String? artist,
    String? album,
    String? albumCover,
    Duration? duration,
    String? lyricId,
    String? sourceId,
    String? sourceKey,
    String? rawData,
  }) {
    return Song(
      id: id ?? this.id,
      source: source ?? this.source,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumCover: albumCover ?? this.albumCover,
      duration: duration ?? this.duration,
      lyricId: lyricId ?? this.lyricId,
      sourceId: sourceId ?? this.sourceId,
      sourceKey: sourceKey ?? this.sourceKey,
      rawData: rawData ?? this.rawData,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source.key,
    'name': name,
    'artist': artist,
    'album': album,
    'albumCover': albumCover,
    'duration': duration?.inMilliseconds,
    'lyricId': lyricId,
    'sourceId': sourceId,
    'sourceKey': sourceKey,
    'rawData': rawData,
  };

  factory Song.fromMap(Map<String, dynamic> m) => Song(
    id: m['id'] as String,
    source: SourceType.fromKey(m['source'] as String),
    name: m['name'] as String,
    artist: m['artist'] as String,
    album: m['album'] as String?,
    albumCover: m['albumCover'] as String?,
    duration: m['duration'] != null
        ? Duration(milliseconds: m['duration'] as int)
        : null,
    lyricId: m['lyricId'] as String?,
    sourceId: m['sourceId'] as String?,
    sourceKey: m['sourceKey'] as String?,
    rawData: m['rawData'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          dedupeKey == other.dedupeKey;

  @override
  int get hashCode => dedupeKey.hashCode;

  @override
  String toString() => 'Song($sourceLabel - $name - $artist)';
}
