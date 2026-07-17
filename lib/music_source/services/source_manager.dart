import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../core/lx_bridge.dart';
import '../models/source_definition.dart';

const _uuid = Uuid();

/// 音源管理器
///
/// 负责：
/// - 音源的增删改查
/// - 内置音源管理
/// - 引擎生命周期
/// - 脚本导入验证
class SourceManager {
  final Dio _dio;

  /// 所有音源
  final List<SourceDefinition> sources = [];

  /// 引擎缓存（sourceId → LxBridge）
  final Map<String, LxBridge> _bridges = {};

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

  // ── 引擎管理 ──

  /// 获取或创建音源的引擎实例
  Future<LxBridge?> getBridge(String sourceId) async {
    // 已有可用引擎
    if (_bridges.containsKey(sourceId)) {
      final bridge = _bridges[sourceId]!;
      if (!bridge.isLoaded) {
        final ok = await bridge.init();
        if (!ok) {
          bridge.dispose();
          _bridges.remove(sourceId);
          return null;
        }
      }
      return bridge;
    }

    // 查找源
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return null;

    // 创建并初始化
    final bridge = LxBridge(source, _dio);
    final ok = await bridge.init();
    if (!ok) {
      bridge.dispose();
      return null;
    }

    // 更新 capabilities
    if (bridge.capabilities.isNotEmpty && source.capabilities.isEmpty) {
      final idx = sources.indexWhere((s) => s.id == source.id);
      if (idx >= 0) {
        sources[idx] = source.copyWith(
          capabilities: Map.from(bridge.capabilities),
        );
        onChanged?.call(List.unmodifiable(sources));
      }
    }

    _bridges[sourceId] = bridge;
    return bridge;
  }

  /// 获取所有已就绪的引擎
  Future<List<LxBridge>> getReadyBridges() async {
    final bridges = <LxBridge>[];
    for (final source in sources) {
      if (!source.enabled) continue;
      final bridge = await getBridge(source.id);
      if (bridge != null && bridge.ready) {
        bridges.add(bridge);
      }
    }
    return bridges;
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

    // 验证脚本
    final tempSource = SourceDefinition(
      id: _uuid.v4(),
      name: name,
      version: meta['version'],
      author: meta['author'],
      description: meta['description'],
      homepage: meta['homepage'],
      scriptSource: scriptSource,
      origin: SourceOrigin.user,
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
    _bridges[saved.id] = bridge;
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
    _bridges[id]?.dispose();
    _bridges.remove(id);
    sources.removeWhere((s) => s.id == id);
    onChanged?.call(List.unmodifiable(sources));
  }

  /// 切换启用状态
  void toggleEnabled(String id) {
    final idx = sources.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    sources[idx] = sources[idx].copyWith(enabled: !sources[idx].enabled);

    // 禁用时释放引擎
    if (!sources[idx].enabled) {
      _bridges[id]?.dispose();
      _bridges.remove(id);
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
    for (final bridge in _bridges.values) {
      bridge.dispose();
    }
    _bridges.clear();
    sources.clear();
  }
}
