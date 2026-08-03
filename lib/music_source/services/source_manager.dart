import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../core/lx_bridge.dart';
import '../core/music_backend.dart';
import '../core/netease_direct_backend.dart';
import '../models/source_definition.dart';

const _uuid = Uuid();

/// 音源管理器
///
/// 负责：
/// - 音源的增删改查
/// - 内置音源管理
/// - 引擎/后端生命周期
/// - 脚本导入验证
class SourceManager {
  final Dio _dio;

  /// 所有音源
  final List<SourceDefinition> sources = [];

  /// 后端实例缓存（sourceId → MusicBackend）
  final Map<String, MusicBackend> _backends = {};

  /// 内置音源ID集合
  final Set<String> _builtinIds = {};

  /// 变更回调
  void Function(List<SourceDefinition> sources)? onChanged;

  SourceManager(this._dio);

  // ── 内置音源 ──

  /// 初始化内置音源
  void initBuiltin(List<SourceDefinition> builtins) {
    for (final source in builtins) {
      _builtinIds.add(source.id);
      if (!sources.any((s) => s.id == source.id)) {
        sources.add(source.copyWith(enabled: true));
      }
    }
    onChanged?.call(List.unmodifiable(sources));
  }

  // ── 后端管理 ──

  /// 根据音源类型创建对应后端
  MusicBackend _createBackend(SourceDefinition source) {
    if (source.backendType == SourceBackendType.direct) {
      // 直接后端：使用平台专用实现
      if (source.id == 'builtin_netease') {
        return NeteaseDirectBackend(sourceId: source.id, dio: _dio);
      }
      // 未知直接后端 — 降级为占位（不应出现）
      return NeteaseDirectBackend(sourceId: source.id, dio: _dio);
    }
    // JS 后端
    return LxBridge(source, _dio);
  }

  /// 获取或创建音源的后端实例
  Future<MusicBackend?> getBackend(String sourceId) async {
    // 已有可用后端
    if (_backends.containsKey(sourceId)) {
      final backend = _backends[sourceId]!;
      if (!backend.isLoaded) {
        final ok = await backend.init();
        if (!ok) {
          backend.dispose();
          _backends.remove(sourceId);
          return null;
        }
      }
      return backend;
    }

    // 查找源
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return null;

    // 创建并初始化
    final backend = _createBackend(source);
    final ok = await backend.init();
    if (!ok) {
      backend.dispose();
      return null;
    }

    // 更新 capabilities
    if (backend.capabilities.isNotEmpty && source.capabilities.isEmpty) {
      final idx = sources.indexWhere((s) => s.id == source.id);
      if (idx >= 0) {
        sources[idx] = source.copyWith(
          capabilities: Map.from(backend.capabilities),
        );
        onChanged?.call(List.unmodifiable(sources));
      }
    }

    _backends[sourceId] = backend;
    return backend;
  }

  /// 兼容旧 API — 返回 LxBridge? (实际是 MusicBackend)
  /// 已废弃，请使用 getBackend
  @Deprecated('使用 getBackend')
  Future<LxBridge?> getBridge(String sourceId) async {
    final b = await getBackend(sourceId);
    if (b is LxBridge) return b;
    return null;
  }

  /// 获取所有已就绪的后端
  Future<List<MusicBackend>> getReadyBridges() async {
    final backends = <MusicBackend>[];
    for (final source in sources) {
      if (!source.enabled) continue;
      final backend = await getBackend(source.id);
      if (backend != null && backend.ready) {
        backends.add(backend);
      }
    }
    return backends;
  }

  /// 获取所有已就绪且支持榜单的后端
  Future<List<MusicBackend>> getReadyListBridges() async {
    final backends = <MusicBackend>[];
    for (final source in sources) {
      if (!source.enabled) continue;
      final backend = await getBackend(source.id);
      if (backend != null && backend.ready && backend.hasList) {
        backends.add(backend);
      }
    }
    return backends;
  }

  // ── 导入 ──

  /// 通过脚本内容导入
  Future<SourceImportResult> importFromScript(String scriptSource) async {
    if (scriptSource.trim().isEmpty) {
      return SourceImportResult.fail('脚本内容为空');
    }

    // 重复检测
    final existing = sources.where(
      (s) => s.scriptSource.trim() == scriptSource.trim(),
    );
    if (existing.isNotEmpty) {
      return SourceImportResult.fail('该脚本已导入（${existing.first.name}）');
    }

    // 解析元信息
    final meta = SourceDefinition.parseMeta(scriptSource);
    final name = meta['name'] ?? '未命名音源';

    // 验证脚本（创建临时源 + LxBridge）
    final tempSource = SourceDefinition(
      id: _uuid.v4(),
      name: name,
      version: meta['version'],
      author: meta['author'],
      description: meta['description'],
      homepage: meta['homepage'],
      scriptSource: scriptSource,
      origin: SourceOrigin.user,
      backendType: SourceBackendType.js,
      enabled: true,
      createdAt: DateTime.now(),
    );

    final bridge = LxBridge(tempSource, _dio);
    final ok = await bridge.init();

    if (!ok) {
      bridge.dispose();
      return SourceImportResult.fail('脚本加载失败: ${bridge.lastError}');
    }

    if (bridge.capabilities.isEmpty) {
      bridge.dispose();
      return SourceImportResult.fail(
        '脚本未声明任何音源能力。\n'
        '可能原因：\n'
        '1. 脚本不是 LX Music 格式\n'
        '2. 脚本做了环境检测\n'
        '3. 脚本执行出错',
      );
    }

    // 保存
    final saved = tempSource.copyWith(
      capabilities: Map.from(bridge.capabilities),
    );
    sources.add(saved);
    _backends[saved.id] = bridge;
    onChanged?.call(List.unmodifiable(sources));

    return SourceImportResult.ok(saved);
  }

  /// 通过URL导入
  Future<SourceImportResult> importFromUrl(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    // 下载脚本
    String scriptSource;
    try {
      final response = await _dio.get(
        normalizedUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      scriptSource = response.data?.toString() ?? '';
      if (scriptSource.isEmpty) {
        return SourceImportResult.fail('下载内容为空');
      }
    } on DioException catch (e) {
      return SourceImportResult.fail(_formatDioError(e));
    } catch (e) {
      return SourceImportResult.fail('下载失败: $e');
    }

    return importFromScript(scriptSource);
  }

  // ── 管理 ──

  /// 移除音源（内置音源只禁用）
  void removeSource(String id) {
    if (_builtinIds.contains(id)) {
      toggleEnabled(id);
      return;
    }
    _backends[id]?.dispose();
    _backends.remove(id);
    sources.removeWhere((s) => s.id == id);
    onChanged?.call(List.unmodifiable(sources));
  }

  /// 切换启用状态
  void toggleEnabled(String id) {
    final idx = sources.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    sources[idx] = sources[idx].copyWith(enabled: !sources[idx].enabled);

    // 禁用时释放后端
    if (!sources[idx].enabled) {
      _backends[id]?.dispose();
      _backends.remove(id);
    }

    onChanged?.call(List.unmodifiable(sources));
  }

  /// 获取启用的音源
  List<SourceDefinition> get enabledSources =>
      sources.where((s) => s.enabled).toList();

  // ── 工具 ──

  String _normalizeUrl(String url) {
    String normalized = url.trim();

    // 补全协议
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    // GitHub blob → raw
    final blobMatch = RegExp(
      r'^https?://github\.com/([^/]+)/([^/]+)/blob/(.+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (blobMatch != null) {
      normalized =
          'https://raw.githubusercontent.com/${blobMatch.group(1)}/${blobMatch.group(2)}/${blobMatch.group(3)}';
    }

    return normalized;
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '下载超时，脚本较大或网络较慢';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 404) return '脚本不存在（404）';
        if (status == 403) return '服务器拒绝访问（403）';
        return '服务器错误：HTTP $status';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      default:
        return '下载失败: ${e.message}';
    }
  }

  /// 释放所有资源
  void dispose() {
    for (final backend in _backends.values) {
      backend.dispose();
    }
    _backends.clear();
    sources.clear();
  }
}
