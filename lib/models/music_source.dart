import 'dart:convert';

/// 音源模型 — 表示一个导入的源脚本
///
/// 完全采用 LX Music 的源脚本架构，不再支持 REST API 模式。
/// 所有音源都是 JS 脚本，脚本通过 globalThis.lx API 与 App 通信。
class MusicSource {
  final String id;
  final String name;

  /// 脚本下载 URL（可选，用于在线更新的源）
  final String? scriptUrl;

  /// JS 源脚本完整内容
  final String scriptSource;

  /// 是否启用
  final bool enabled;

  /// 创建时间
  final DateTime createdAt;

  /// 脚本初始化时声明的源能力（JSON 字符串）
  /// 格式: { "kw": { "name": "酷我音乐", "type": "music", "actions": ["search","musicUrl","lyric"], "qualitys": ["128k","320k","flac"] } }
  final String? sourcesJson;

  /// 脚本元信息（从 @name/@version/@author/@description 解析）
  final String? version;
  final String? author;
  final String? description;

  const MusicSource({
    required this.id,
    required this.name,
    this.scriptUrl,
    required this.scriptSource,
    this.enabled = true,
    required this.createdAt,
    this.sourcesJson,
    this.version,
    this.author,
    this.description,
  });

  MusicSource copyWith({
    String? id,
    String? name,
    String? scriptUrl,
    String? scriptSource,
    bool? enabled,
    DateTime? createdAt,
    String? sourcesJson,
    String? version,
    String? author,
    String? description,
  }) {
    return MusicSource(
      id: id ?? this.id,
      name: name ?? this.name,
      scriptUrl: scriptUrl ?? this.scriptUrl,
      scriptSource: scriptSource ?? this.scriptSource,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      sourcesJson: sourcesJson ?? this.sourcesJson,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'script_url': scriptUrl,
    'script_source': scriptSource,
    'enabled': enabled ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'sources_json': sourcesJson,
    'version': version,
    'author': author,
    'description': description,
  };

  factory MusicSource.fromMap(Map<String, dynamic> m) {
    // v2→v3 兼容：旧版有 source_type/apiUrl 字段，新版已移除
    // 如果旧数据是 api 类型，忽略它（不再支持）
    final sourceType = m['source_type'] as String?;
    if (sourceType == 'api') {
      // 旧 REST API 源标记为禁用（不再支持，保留记录但无法使用）
      // 后续 UI 过滤时跳过
    }

    return MusicSource(
      id: m['id'] as String,
      name: m['name'] as String,
      scriptUrl: m['script_url'] as String?,
      scriptSource: m['script_source'] as String? ?? '',
      enabled: switch (m['enabled']) {
        int v => v == 1,
        bool b => b,
        _ => true,
      },
      createdAt: DateTime.parse(
        m['createdAt'] as String? ?? m['created_at'] as String,
      ),
      sourcesJson: m['sources_json'] as String?,
      version: m['version'] as String?,
      author: m['author'] as String?,
      description: m['description'] as String?,
    );
  }

  /// 解析 sourcesJson 为 Map
  Map<String, dynamic>? get parsedSources {
    if (sourcesJson == null || sourcesJson!.isEmpty) return null;
    try {
      return _parseJsonMap(sourcesJson!);
    } catch (_) {
      return null;
    }
  }

  /// 获取脚本支持的源 key 列表（如 ['kw', 'kg', 'tx']）
  List<String> get sourceKeys {
    final sources = parsedSources;
    if (sources == null) return [];
    return sources.keys.toList();
  }

  /// 获取指定源支持的动作列表
  List<String> getActions(String sourceKey) {
    final sources = parsedSources;
    if (sources == null) return [];
    final src = sources[sourceKey] as Map<String, dynamic>?;
    if (src == null) return [];
    return (src['actions'] as List?)?.cast<String>() ?? [];
  }

  /// 获取指定源支持的音质列表
  List<String> getQualitys(String sourceKey) {
    final sources = parsedSources;
    if (sources == null) return [];
    final src = sources[sourceKey] as Map<String, dynamic>?;
    if (src == null) return [];
    return (src['qualitys'] as List?)?.cast<String>() ?? [];
  }

  static Map<String, dynamic> _parseJsonMap(String json) {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
