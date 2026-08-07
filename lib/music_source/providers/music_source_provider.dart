import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/music_source.dart';
import '../../providers/account_center_provider.dart';
import '../../services/storage_service.dart';
import '../core/lx_bridge.dart';
import '../core/music_backend.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import '../services/download_manager.dart';
import '../services/source_manager.dart';

/// 全局 Dio 实例
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));
  // Strip trailing semicolons from content-type headers to prevent
  // http_parser MediaType.parse FormatException warnings (e.g. 'text/plain; charset=utf-8;')
  dio.interceptors.add(InterceptorsWrapper(
    onResponse: (response, handler) {
      final ct = response.headers.value('content-type');
      if (ct != null && ct.endsWith(';')) {
        response.headers.remove('content-type', ct);
        response.headers.add('content-type', ct.replaceAll(RegExp(r';\s*$'), ''));
      }
      handler.next(response);
    },
  ));
  return dio;
});
// ═══════════════════════════════════════
// Source Provider（唯一音源数据源）
// ═══════════════════════════════════════

/// 音源引擎就绪状态
enum SourceReadyState { loading, ready, error }

/// 音源列表状态
///
/// 全局唯一的音源数据源，搜索/播放/榜单/设置/音源中心共用，
/// 从数据库加载用户导入的音源并持久化变更。
final sourceListProvider =
    StateNotifierProvider<SourceListNotifier, List<SourceDefinition>>((ref) {
  final dio = ref.watch(_dioProvider);
  final account = ref.watch(accountCenterProvider);
  return SourceListNotifier(
    dio,
    cookieProvider: (key) => account[key]?.cookie ?? '',
    guidProvider: (key) => account[key]?.guid ?? '',
  );
});

class SourceListNotifier extends StateNotifier<List<SourceDefinition>> {
  final SourceManager _manager;

  SourceReadyState _readyState = SourceReadyState.loading;
  String? _readyError;

  SourceListNotifier(
    Dio dio, {
    bool registerBuiltins = true,
    String? Function(String platformKey)? cookieProvider,
    String? Function(String platformKey)? guidProvider,
  }) : _manager = SourceManager(
          dio,
          registerBuiltins: registerBuiltins,
          cookieProvider: cookieProvider,
          guidProvider: guidProvider,
        ),
        super([]) {
    _manager.onChanged = (sources) {
      state = sources;
      _save();
    };
    _init();
  }

  SourceReadyState get readyState => _readyState;
  String? get readyError => _readyError;

  bool get isEngineReady =>
      _readyState == SourceReadyState.ready &&
      _manager.sources.any((s) => s.enabled);

  Future<void> _init() async {
    try {
      // 从数据库加载用户导入的音源
      // 丢弃旧版内置音源（builtin_*）与空脚本记录
      final saved = await storageService.loadSources();
      final valid = saved
          .where((s) => !s.id.startsWith('builtin_') && s.scriptSource.isNotEmpty)
          .toList();

      for (final ms in valid) {
        if (!_manager.sources.any((s) => s.id == ms.id)) {
          _manager.sources.add(_toDefinition(ms));
        }
      }
      state = List.unmodifiable(_manager.sources);

      // 预初始化已启用音源的 JS 引擎（搜索时无需等待）
      await _preInitEngines();

      _readyState = SourceReadyState.ready;
    } catch (e) {
      print('SourceListNotifier._init error: $e');
      _readyState = SourceReadyState.error;
      _readyError = e.toString();
    }
  }

  /// 预初始化所有已启用音源的 JS 引擎
  Future<void> _preInitEngines() async {
    for (final source in _manager.sources) {
      if (!source.enabled) continue;
      try {
        await _manager.getBackend(source.id);
      } catch (e) {
        print('[SourceListNotifier] 初始化异常: ${source.name} — $e');
      }
    }
  }

  SourceManager get manager => _manager;

  /// 启用的音源
  List<SourceDefinition> get enabledSources =>
      _manager.sources.where((s) => s.enabled).toList();

  /// 获取音源后端（JS 引擎）
  Future<LxBridge?> getBridge(String sourceId) =>
      _manager.getBridge(sourceId);

  /// 获取音源后端（任意类型）
  Future<MusicBackend?> getBackend(String sourceId) =>
      _manager.getBackend(sourceId);

  /// 解析脚本元信息
  Map<String, String?> parseScriptMeta(String scriptSource) =>
      SourceDefinition.parseMeta(scriptSource);

  /// 导入脚本
  Future<SourceImportResult> importScript(String script) =>
      _manager.importFromScript(script);

  /// 从URL导入
  Future<SourceImportResult> importFromUrl(String url) =>
      _manager.importFromUrl(url);

  /// 移除音源
  void remove(String id) => _manager.removeSource(id);

  /// 切换启用
  void toggle(String id) => _manager.toggleEnabled(id);

  Future<void> _save() async {
    await storageService.saveSources(
      _manager.sources
          .where((s) => s.origin != SourceOrigin.builtin)
          .map(_toMusicSource)
          .toList(),
    );
  }

  // ── 模型转换（DB DTO ↔ SourceDefinition） ──

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

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════
// Download Provider
// ═══════════════════════════════════════

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  final dio = ref.watch(_dioProvider);
  return DownloadNotifier(dio);
});

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final DownloadManager _manager;

  DownloadNotifier(Dio dio)
      : _manager = DownloadManager(dio),
        super([]) {
    _manager.onChanged = (tasks) => state = tasks;
  }

  DownloadManager get manager => _manager;

  void addAndStart(MusicTrack track, String url, {String quality = '128k'}) {
    final task = _manager.addTask(track, url, quality: quality);
    _manager.startDownload(task);
  }

  void cancel(DownloadTask task) => _manager.cancelDownload(task);
  void remove(DownloadTask task) => _manager.removeTask(task);
  void clearCompleted() => _manager.clearCompleted();
}
