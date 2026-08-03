import 'dart:convert';

/// 搜索类型（lx-music 标准）
///
/// 对应音源脚本 search 动作的 type 参数：
/// - song: 单曲（默认）
/// - album: 专辑
/// - artist: 歌手
/// - playlist: 歌单
enum SearchType {
  song('song', '单曲'),
  album('album', '专辑'),
  artist('artist', '歌手'),
  playlist('playlist', '歌单');

  final String value;
  final String label;

  const SearchType(this.value, this.label);

  static SearchType fromValue(String? v) =>
      values.firstWhere((e) => e.value == v, orElse: () => SearchType.song);
}

/// 搜索结果中的音乐轨道信息
///
/// 这是从音源搜索返回的标准化歌曲信息，
/// 这是从音源搜索返回的标准化歌曲信息，
/// 可用于播放、下载、展示。
class MusicTrack {
  /// 歌曲唯一标识（由音源提供）
  final String id;

  /// 歌曲名称
  final String title;

  /// 艺术家
  final String artist;

  /// 专辑名
  final String? album;

  /// 封面图URL
  final String? coverUrl;

  /// 时长（毫秒）
  final int? durationMs;

  /// 所属音源ID
  final String sourceId;

  /// 子源标识（如 wy, kg, kw）
  final String sourceKey;

  /// 歌词ID
  final String? lyricId;

  /// 原始JS搜索结果（JSON字符串），用于获取播放URL/歌词时传递
  final String? rawData;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    this.durationMs,
    required this.sourceId,
    required this.sourceKey,
    this.lyricId,
    this.rawData,
  });

  /// 生成去重key
  String get dedupeKey => '$sourceKey:$title:$artist'.toLowerCase();

  /// 格式化时长
  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final totalSec = durationMs! ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'durationMs': durationMs,
      'sourceId': sourceId,
      'sourceKey': sourceKey,
      'lyricId': lyricId,
      'rawData': rawData,
    };
  }

  factory MusicTrack.fromMap(Map<String, dynamic> map) {
    return MusicTrack(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? '',
      album: map['album']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      durationMs: map['durationMs'] as int?,
      sourceId: map['sourceId']?.toString() ?? '',
      sourceKey: map['sourceKey']?.toString() ?? '',
      lyricId: map['lyricId']?.toString(),
      rawData: map['rawData']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MusicTrack.fromJson(String json) =>
      MusicTrack.fromMap(jsonDecode(json) as Map<String, dynamic>);
}

/// 搜索结果包装
class SearchResult {
  final List<MusicTrack> tracks;
  final int total;
  final String sourceId;
  final String? error;

  const SearchResult({
    required this.tracks,
    this.total = 0,
    required this.sourceId,
    this.error,
  });

  bool get hasError => error != null;
}

/// 音乐品质
enum MusicQuality {
  lq('128k', '标准'),
  hq('320k', '高品质'),
  flac('flac', '无损'),
  flac24bit('flac24bit', 'Hi-Res'),
  hires('hires', 'Hi-Res'),
  ;

  final String value;
  final String label;
  const MusicQuality(this.value, this.label);
}
