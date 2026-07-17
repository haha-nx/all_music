import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/music_source.dart';
import '../music_source/core/lx_bridge.dart';
import '../music_source/models/source_definition.dart';
import '../music_source/services/source_manager.dart';
import '../services/storage_service.dart';
import '../utils/http_client.dart';

/// 音源导入验证结果
class ImportResult {
  final bool success;
  final String? error;
  final MusicSource? source;

  const ImportResult._({required this.success, this.error, this.source});

  factory ImportResult.ok(MusicSource source) => ImportResult._(success: true, source: source);
  factory ImportResult.fail(String error) => ImportResult._(success: false, error: error);
}

/// 音源状态管理
///
/// 内部使用全新的 SourceManager + LxBridge 引擎，
/// 对外暴露旧的 MusicSource 模型以保持兼容。
class SourceNotifier extends StateNotifier<List<MusicSource>> {
  late final SourceManager _manager;
  final Dio _dio;

  /// 内置音源 ID 集合
  final Set<String> _builtInIds = {};

  SourceNotifier(this._dio) : super([]) {
    _manager = SourceManager(_dio);
    _manager.onChanged = (_) => _syncFromManager();
    _init();
  }

  Future<void> _init() async {
    try {
      // 从数据库加载现有音源
      final saved = await storageService.loadSources();
      state = saved.where((s) => s.scriptSource.isNotEmpty).toList();

      // 初始化新 SourceManager
      for (final source in state) {
        _manager.sources.add(_toDefinition(source));
      }

      // 加载内置六音示例源
      await _ensureBuiltinSources();
    } catch (e) {
      print('SourceNotifier._init error: $e');
      await _ensureBuiltinSources();
    }
  }

  Future<void> _ensureBuiltinSources() async {
    // 从 assets 加载六音脚本
    String? sixyinScript;
    try {
      sixyinScript = await _loadBuiltinScript();
    } catch (e) {
      print('SourceNotifier: 内置脚本加载失败: $e');
    }

    if (sixyinScript == null || sixyinScript.isEmpty) return;

    final trimScript = sixyinScript.trim();
    final meta = SourceDefinition.parseMeta(sixyinScript);
    final builtinId = 'builtin_sixyin';

    // 已存在则跳过
    if (state.any((s) => s.id == builtinId)) return;

    // 如果有同内容的源，也跳过
    final existingByContent = state.where(
      (s) => s.scriptSource.trim() == trimScript,
    );
    if (existingByContent.isNotEmpty) return;

    // 创建内置音源（旧模型）
    final musicSource = MusicSource(
      id: builtinId,
      name: '六音音源（示例）',
      scriptSource: sixyinScript,
      version: meta['version'],
      author: meta['author'],
      description: meta['description'] ?? '多平台聚合音乐源',
      enabled: true,
      createdAt: DateTime.now(),
    );

    state = [...state, musicSource];
    _builtInIds.add(builtinId);
    _manager.sources.add(_toDefinition(musicSource));
    await _save();
  }

  Future<String?> _loadBuiltinScript() async {
    try {
      return await rootBundle.loadString('assets/scripts/sixyin_latest.js');
    } catch (e) {
      return null;
    }
  }

  /// SourceDefinition → MusicSource 转换
  MusicSource _toMusicSource(SourceDefinition def) {
    return MusicSource(
      id: def.id,
      name: def.name,
      scriptSource: def.scriptSource,
      scriptUrl: def.homepage,
      version: def.version,
      author: def.author,
      description: def.description,
      enabled: def.enabled,
      createdAt: def.createdAt,
    );
  }

  /// MusicSource → SourceDefinition 转换
  SourceDefinition _toDefinition(MusicSource ms) {
    return SourceDefinition(
      id: ms.id,
      name: ms.name,
      scriptSource: ms.scriptSource,
      version: ms.version,
      author: ms.author,
      description: ms.description,
      homepage: ms.scriptUrl,
      enabled: ms.enabled,
      createdAt: ms.createdAt,
      origin: _builtInIds.contains(ms.id) ? SourceOrigin.builtin : SourceOrigin.user,
    );
  }

  /// 同步 SourceManager → state
  void _syncFromManager() {
    state = _manager.sources.map(_toMusicSource).toList();
    _save();
  }

  // ── 公共 API（兼容旧接口） ──

  /// 暴露内部 SourceManager（供 search_provider 等使用）
  SourceManager get manager => _manager;

  /// 获取 JS 引擎（通过新的 LxBridge）
  Future<LxBridge?> getEngine(String sourceId) async {
    return _manager.getBridge(sourceId);
  }

  /// 解析脚本头部的元信息
  Map<String, String?> parseScriptMeta(String scriptSource) {
    return SourceDefinition.parseMeta(scriptSource);
  }

  /// 通过粘贴脚本内容导入
  Future<ImportResult> importFromScript(String scriptSource) async {
    final result = await _manager.importFromScript(scriptSource);
    if (result.success && result.source != null) {
      return ImportResult.ok(_toMusicSource(result.source!));
    }
    return ImportResult.fail(result.error ?? '导入失败');
  }

  /// 通过 URL 下载并导入
  Future<ImportResult> importFromUrl(String url) async {
    final result = await _manager.importFromUrl(url);
    if (result.success && result.source != null) {
      return ImportResult.ok(_toMusicSource(result.source!));
    }
    return ImportResult.fail(result.error ?? '导入失败');
  }

  /// 更新音源
  void updateSource(MusicSource updated) {
    final idx = _manager.sources.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      _manager.sources[idx] = _toDefinition(updated);
      _syncFromManager();
    }
  }

  /// 移除音源
  void removeSource(String id) {
    _manager.removeSource(id);
  }

  /// 切换启用
  void toggleEnabled(String id) {
    _manager.toggleEnabled(id);
  }

  /// 获取所有启用的音源
  List<MusicSource> get enabledSources =>
      state.where((s) => s.enabled).toList();

  Future<void> _save() async => storageService.saveSources(state);

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}

final sourceProvider = StateNotifierProvider<SourceNotifier, List<MusicSource>>((ref) {
  final dio = MusicHttpClient().dio;
  return SourceNotifier(dio);
});
