import 'song.dart';

/// 歌单类型
enum PlaylistType {
  custom,   // 用户自建
}

/// 歌单模型
class Playlist {
  final String id;
  final String name;
  final String? coverUrl;
  final PlaylistType type;
  final List<Song> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.type = PlaylistType.custom,
    this.songs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// 歌曲数量
  int get songCount => songs.length;

  /// 总时长
  Duration get totalDuration =>
      songs.fold(Duration.zero, (sum, s) => sum + (s.duration ?? Duration.zero));

  /// 是否包含来自多个音源的歌曲（混编歌单）
  bool get isMixed {
    if (songs.isEmpty) return false;
    final sources = songs.map((s) => s.source).toSet();
    return sources.length > 1;
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? coverUrl,
    PlaylistType? type,
    List<Song>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      type: type ?? this.type,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'coverUrl': coverUrl,
    'type': type.name,
    'songs': songs.map((s) => s.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Playlist.fromMap(Map<String, dynamic> m) => Playlist(
    id: m['id'] as String,
    name: m['name'] as String,
    coverUrl: m['coverUrl'] as String?,
    type: PlaylistType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => PlaylistType.custom,
    ),
    songs: m['songs'] != null
        ? (m['songs'] as List)
            .map((s) => Song.fromMap(s as Map<String, dynamic>))
            .toList()
        : const [],
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );
}
