/// 榜单类型信息（lx-music 标准：源脚本通过 listTypes 声明支持的榜单）
///
/// 例：{ name: '云音乐飙升榜', type: 'cloudrank' }
class ListTypeInfo {
  final String name;
  final String type;

  const ListTypeInfo({required this.name, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type};

  factory ListTypeInfo.fromJson(Map<String, dynamic> json) {
    return ListTypeInfo(
      name: json['name']?.toString() ?? json['type']?.toString() ?? '未知榜单',
      type: json['type']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}

/// 榜单/歌单条目（lx-music 标准 `list` 动作的返回值）
///
/// 对应 JS 侧的榜单对象：
/// { id, name, pic, source, ... }（排行榜）
/// { id, name, pic, songCount, ... }（歌单）
class MusicListInfo {
  /// 榜单唯一 ID（由音源提供）
  final String id;

  /// 榜单名称
  final String title;

  /// 封面图 URL
  final String? picUrl;

  /// 歌曲数量（可选）
  final int? songCount;

  /// 所属音源 ID（SourceDefinition.id）
  final String sourceId;

  /// 子源标识（如 wy, kg, kw）
  final String sourceKey;

  /// 原始 JS 数据（JSON 字符串），用于 listDetail 调用时传递完整上下文
  final String? rawData;

  /// 是否为官方排行榜（内置源 topLists 产出；true 时详情走 topListDetail）
  final bool isRank;

  const MusicListInfo({
    required this.id,
    required this.title,
    this.picUrl,
    this.songCount,
    required this.sourceId,
    required this.sourceKey,
    this.rawData,
    this.isRank = false,
  });

  /// 格式化数量
  String get countText {
    if (songCount == null) return '-- 首';
    if (songCount! >= 10000) {
      return '${(songCount! / 10000).toStringAsFixed(1)} 万首';
    }
    return '$songCount 首';
  }
}
