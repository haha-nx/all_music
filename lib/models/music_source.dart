/// 音源类型
enum MusicSourceType {
  /// REST API 服务端
  api,

  /// JavaScript 源脚本（LX Music 格式）
  script;
}

/// 音源模型 — 表示一个导入的在线音源
class MusicSource {
  final String id;
  final String name;
  final String apiUrl;     // API 地址 或 JS 源 URL
  final String? token;
  final bool enabled;
  final DateTime createdAt;

  /// 音源类型（api 或 script），默认 api 向后兼容
  final MusicSourceType sourceType;

  /// JS 源脚本内容（仅 sourceType == script 时有效）
  final String? scriptSource;

  const MusicSource({
    required this.id,
    required this.name,
    required this.apiUrl,
    this.token,
    this.enabled = true,
    required this.createdAt,
    this.sourceType = MusicSourceType.api,
    this.scriptSource,
  });

  MusicSource copyWith({
    String? id,
    String? name,
    String? apiUrl,
    String? token,
    bool? enabled,
    DateTime? createdAt,
    MusicSourceType? sourceType,
    String? scriptSource,
  }) {
    return MusicSource(
      id: id ?? this.id,
      name: name ?? this.name,
      apiUrl: apiUrl ?? this.apiUrl,
      token: token ?? this.token,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      sourceType: sourceType ?? this.sourceType,
      scriptSource: scriptSource ?? this.scriptSource,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'apiUrl': apiUrl,
    'token': token,
    'enabled': enabled ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'source_type': sourceType.name,
    'script_source': scriptSource,
  };

  factory MusicSource.fromMap(Map<String, dynamic> m) {
    final typeStr = m['source_type'] as String?;
    return MusicSource(
      id: m['id'] as String,
      name: m['name'] as String,
      apiUrl: m['apiUrl'] as String? ?? m['api_url'] as String,
      token: m['token'] as String?,
      enabled: switch (m['enabled']) {
        int v => v == 1,
        bool b => b,
        _ => true,
      },
      createdAt: DateTime.parse(m['createdAt'] as String? ?? m['created_at'] as String),
      sourceType: typeStr != null ? MusicSourceType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => MusicSourceType.api,
      ) : MusicSourceType.api,
      scriptSource: m['script_source'] as String?,
    );
  }
}
