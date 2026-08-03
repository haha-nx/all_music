import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/music_source.dart';
import '../music_source/core/lx_bridge.dart';
import '../music_source/core/music_backend.dart';
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

/// 音源就绪状态
enum SourceReadyState { loading, ready, error }

/// 音源状态管理
class SourceNotifier extends StateNotifier<List<MusicSource>> {
  late final SourceManager _manager;
  final Dio _dio;

  /// 引擎就绪状态
  SourceReadyState _readyState = SourceReadyState.loading;
  String? _readyError;

  SourceReadyState get readyState => _readyState;
  String? get readyError => _readyError;

  bool get isEngineReady =>
      _readyState == SourceReadyState.ready && _manager.sources.any((s) => s.enabled);

  SourceNotifier(this._dio) : super([]) {
    _manager = SourceManager(_dio);
    _manager.onChanged = (_) => _syncFromManager();
    _init();
  }

  Future<void> _init() async {
    try {
      // 从数据库加载用户导入的音源
      // 丢弃旧版内置音源（builtin_*，含已废弃的六音源）与空脚本记录
      final saved = await storageService.loadSources();
      final validSources = saved
          .where((s) => !s.id.startsWith('builtin_') && s.scriptSource.isNotEmpty)
          .toList();

      state = List.from(validSources);
      for (final source in validSources) {
        // 幂等：manager 中已存在则跳过，避免重复项
        if (!_manager.sources.any((d) => d.id == source.id)) {
          _manager.sources.add(_toDefinition(source));
        }
      }

      // 预初始化用户音源引擎（让搜索时无需等待）
      await _preInitEngines();

      _readyState = SourceReadyState.ready;
    } catch (e) {
      print('SourceNotifier._init error: $e');
      _readyState = SourceReadyState.error;
      _readyError = e.toString();
    }
  }

  /// 预初始化所有已启用音源的JS引擎
  Future<void> _preInitEngines() async {
    final sourcesToInit = List<MusicSource>.from(state);
    if (sourcesToInit.isEmpty) {
      print('[SourceNotifier] 没有音源需要初始化');
      return;
    }

    for (final source in sourcesToInit) {
      if (!source.enabled) continue;
      try {
        final backend = await _manager.getBackend(source.id);
        if (backend != null && backend.ready) {
          print('[SourceNotifier] JS 引擎就绪: ${source.name} '
              '(子源: ${backend.searchKeys.join(", ")})');
        } else {
          final err = backend?.lastError;
          print('[SourceNotifier] 初始化失败: ${source.name}'
              '${err != null ? " — $err" : ""}');
        }
      } catch (e) {
        print('[SourceNotifier] 初始化异常: ${source.name} — $e');
      }
    }
  }

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

  SourceDefinition _toDefinition(MusicSource ms) {
    return SourceDefinition(
      id: ms.id,
      name: ms.name,
      scriptSource: ms.scriptSource,
      version: ms.version,
      author: ms.author,
      description: ms.description,
      homepage: ms.scriptUrl,
      // 用户导入的脚本统一走 JS 引擎
      backendType: SourceBackendType.js,
      enabled: ms.enabled,
      createdAt: ms.createdAt,
      origin: SourceOrigin.user,
    );
  }

  void _syncFromManager() {
    state = _manager.sources.map(_toMusicSource).toList();
    _save();
  }

  // ── 公共 API ──

  SourceManager get manager => _manager;

  Future<LxBridge?> getEngine(String sourceId) async {
    final b = await _manager.getBackend(sourceId);
    if (b is LxBridge) return b;
    return null;
  }

  /// 获取任意类型后端（JS 引擎 或 直接后端）
  Future<MusicBackend?> getBackend(String sourceId) async {
    return _manager.getBackend(sourceId);
  }

  Map<String, String?> parseScriptMeta(String scriptSource) {
    return SourceDefinition.parseMeta(scriptSource);
  }

  Future<ImportResult> importFromScript(String scriptSource) async {
    final result = await _manager.importFromScript(scriptSource);
    if (result.success && result.source != null) {
      return ImportResult.ok(_toMusicSource(result.source!));
    }
    return ImportResult.fail(result.error ?? '导入失败');
  }

  Future<ImportResult> importFromUrl(String url) async {
    final result = await _manager.importFromUrl(url);
    if (result.success && result.source != null) {
      return ImportResult.ok(_toMusicSource(result.source!));
    }
    return ImportResult.fail(result.error ?? '导入失败');
  }

  void updateSource(MusicSource updated) {
    final idx = _manager.sources.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      _manager.sources[idx] = _toDefinition(updated);
      _syncFromManager();
    }
  }

  void removeSource(String id) {
    _manager.removeSource(id);
  }

  void toggleEnabled(String id) {
    _manager.toggleEnabled(id);
  }

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
