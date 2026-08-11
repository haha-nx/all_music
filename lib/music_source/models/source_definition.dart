import 'music_list.dart';

/// 音源后端类型
enum SourceBackendType {
  /// JS 引擎（需 QuickJS/JSCore，适合复杂的 LX 脚本）
  js,

  /// 直接 HTTP 后端（用 Dart 直接调音乐平台 API，零依赖）
  /// 已无内置使用方，保留枚举值仅为兼容旧数据库记录
  direct,
}

/// 音源定义 —— 描述一个已导入的音乐源
///
/// 音源全部由用户导入：粘贴脚本或从 URL 下载（可删除、可禁用）
class SourceDefinition {
  final String id;
  final String name;
  final String? version;
  final String? author;
  final String? description;
  final String? homepage;

  /// JS 脚本源码（仅 backendType=js 时使用）
  final String scriptSource;

  /// 来源类型
  final SourceOrigin origin;

  /// 后端类型（js / direct）
  final SourceBackendType backendType;

  /// 是否启用
  final bool enabled;

  /// 创建时间
  final DateTime createdAt;

  /// 脚本声明的能力（sourceKey → SourceCapability）
  /// 由引擎初始化后填充
  final Map<String, SourceCapability> capabilities;

  const SourceDefinition({
    required this.id,
    required this.name,
    this.version,
    this.author,
    this.description,
    this.homepage,
    this.scriptSource = '',
    this.origin = SourceOrigin.user,
    this.backendType = SourceBackendType.js,
    this.enabled = true,
    required this.createdAt,
    this.capabilities = const {},
  });

  SourceDefinition copyWith({
    String? id,
    String? name,
    String? version,
    String? author,
    String? description,
    String? homepage,
    String? scriptSource,
    SourceOrigin? origin,
    SourceBackendType? backendType,
    bool? enabled,
    DateTime? createdAt,
    Map<String, SourceCapability>? capabilities,
  }) {
    return SourceDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      homepage: homepage ?? this.homepage,
      scriptSource: scriptSource ?? this.scriptSource,
      origin: origin ?? this.origin,
      backendType: backendType ?? this.backendType,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  /// 是否有搜索能力
  bool get canSearch =>
      capabilities.values.any((c) => c.actions.contains('search'));

  /// 是否有榜单能力（list / listDetail）
  bool get canList =>
      capabilities.values.any((c) => c.actions.contains('list'));

  /// 获取所有有搜索能力的源key
  List<String> get searchSourceKeys => capabilities.entries
      .where((e) => e.value.actions.contains('search'))
      .map((e) => e.key)
      .toList();

  /// 获取所有有榜单能力的源key
  List<String> get listSourceKeys => capabilities.entries
      .where((e) => e.value.actions.contains('list'))
      .map((e) => e.key)
      .toList();

  /// 获取支持的音乐品质列表（所有源的并集）
  List<String> get allQualitys {
    final qs = <String>{};
    for (final cap in capabilities.values) {
      qs.addAll(cap.qualitys);
    }
    if (qs.isEmpty) qs.add('128k');
    return qs.toList()..sort();
  }

  /// 从脚本头部注释解析元信息
  static Map<String, String?> parseMeta(String scriptSource) {
    final meta = <String, String?>{};
    final header =
        scriptSource.length > 3000 ? scriptSource.substring(0, 3000) : scriptSource;

    final patterns = {
      'name': r'@name\s+(.+)',
      'version': r'@version\s+(.+)',
      'author': r'@author\s+(.+)',
      'description': r'@description\s+(.+)',
      'homepage': r'@homepage\s+(.+)',
    };

    for (final entry in patterns.entries) {
      final match = RegExp(entry.value, multiLine: true).firstMatch(header);
      meta[entry.key] = match?.group(1)?.trim();
    }

    return meta;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      'homepage': homepage,
      'scriptSource': scriptSource,
      'origin': origin.name,
      'backendType': backendType.name,
      'enabled': enabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SourceDefinition.fromMap(Map<String, dynamic> map) {
    return SourceDefinition(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      version: map['version'] as String?,
      author: map['author'] as String?,
      description: map['description'] as String?,
      homepage: map['homepage'] as String?,
      scriptSource: map['scriptSource'] as String? ?? '',
      origin: SourceOrigin.values.firstWhere(
        (e) => e.name == map['origin'],
        orElse: () => SourceOrigin.user,
      ),
      backendType: SourceBackendType.values.firstWhere(
        (e) => e.name == map['backendType'],
        orElse: () => SourceBackendType.js,
      ),
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 音源来源（当前仅有用户导入）
enum SourceOrigin { builtin, user }

/// 单个子源的音源能力
class SourceCapability {
  /// 子源标识（如 wy, kg, kw）
  final String key;

  /// 显示名称
  final String name;

  /// 音源类型（music）
  final String type;

  /// 支持的动作（search, musicUrl, lyric, pic）
  final List<String> actions;

  /// 支持的音乐品质
  final List<String> qualitys;

  /// 支持的榜单类型（lx 标准 listTypes，如云音乐飙升榜/新歌榜）
  final List<ListTypeInfo> listTypes;

  const SourceCapability({
    required this.key,
    required this.name,
    this.type = 'music',
    required this.actions,
    this.qualitys = const ['128k'],
    this.listTypes = const [],
  });

  factory SourceCapability.fromJson(String key, Map<String, dynamic> json) {
    return SourceCapability(
      key: key,
      name: json['name']?.toString() ?? key,
      type: json['type']?.toString() ?? 'music',
      actions: (json['actions'] as List?)?.cast<String>() ?? [],
      qualitys: (json['qualitys'] as List?)?.cast<String>() ?? ['128k'],
      listTypes: (json['listTypes'] as List?)
              ?.whereType<Map>()
              .map((m) => ListTypeInfo.fromJson(m.cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }

  /// 是否有榜单能力
  bool get hasList => actions.contains('list');
}

/// 音源导入结果
class SourceImportResult {
  final bool success;
  final SourceDefinition? source;
  final String? error;

  const SourceImportResult._({
    required this.success,
    this.source,
    this.error,
  });

  factory SourceImportResult.ok(SourceDefinition source) =>
      SourceImportResult._(success: true, source: source);

  factory SourceImportResult.fail(String error) =>
      SourceImportResult._(success: false, error: error);
}
