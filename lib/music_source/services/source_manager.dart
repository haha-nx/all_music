import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../builtin/builtin_platforms.dart';
import '../builtin/builtin_search_backend.dart';
import '../builtin/kugou_search_api.dart';
import '../builtin/kuwo_search_api.dart';
import '../builtin/migu_search_api.dart';
import '../builtin/netease_search_api.dart';
import '../builtin/platform_search_api.dart';
import '../builtin/tencent_search_api.dart';
import '../core/lx_bridge.dart';
import '../core/music_backend.dart';
import '../models/source_definition.dart';

const _uuid = Uuid();

/// 音源管理器
///
/// 负责：
/// - 音源的增删改查
/// - 引擎/后端生命周期
/// - 脚本导入验证
class SourceManager {
  final Dio _dio;

  /// 所有音源
  final List<SourceDefinition> sources = [];

  /// 后端实例缓存（sourceId → MusicBackend）
  final Map<String, MusicBackend> _backends = {};

  /// 变更回调
  void Function(List<SourceDefinition> sources)? onChanged;

  /// 登录态 cookie 提供回调（platformKey → cookie 串）
  final String? Function(String platformKey)? cookieProvider;

  /// QQ 音乐设备 guid 提供回调（platformKey → guid 串）
  final String? Function(String platformKey)? guidProvider;

  SourceManager(
    this._dio, {
    bool registerBuiltins = true,
    this.cookieProvider,
    this.guidProvider,
  }) {
    if (registerBuiltins) _registerBuiltins();
  }

  // ── 后端管理 ──

  /// 根据音源类型创建对应后端
  MusicBackend _createBackend(SourceDefinition source) {
    if (source.backendType == SourceBackendType.direct) {
      final platform =
          kBuiltinPlatforms.where((p) => p.id == source.id).firstOrNull;
      if (platform != null) {
        return BuiltinSearchBackend(
          platform: platform,
          sourceId: source.id,
          api: _createPlatformApi(platform),
        );
      }
    }
    return LxBridge(source, _dio);
  }

  /// 注册内置搜索平台
  void _registerBuiltins() {
    for (final platform in kBuiltinPlatforms) {
      if (sources.any((s) => s.id == platform.id)) continue;
      sources.add(SourceDefinition(
        id: platform.id,
        name: platform.name,
        backendType: SourceBackendType.direct,
        origin: SourceOrigin.builtin,
        enabled: true,
        createdAt: DateTime(2026, 1, 1),
      ));
    }
  }

  PlatformSearchApi _createPlatformApi(BuiltinPlatform platform) {
    switch (platform.sourceKey) {
      case 'wy':
        return NeteaseSearchApi(
            sourceId: platform.id, dio: _dio, cookieProvider: cookieProvider);
      case 'tx':
        return TencentSearchApi(
            sourceId: platform.id,
            dio: _dio,
            cookieProvider: cookieProvider,
            guidProvider: guidProvider);
      case 'kg':
        return KugouSearchApi(
            sourceId: platform.id, dio: _dio, cookieProvider: cookieProvider);
      case 'kw':
        return KuwoSearchApi(
            sourceId: platform.id, dio: _dio, cookieProvider: cookieProvider);
      case 'mg':
        return MiguSearchApi(
            sourceId: platform.id, dio: _dio, cookieProvider: cookieProvider);
      default:
        throw StateError('Unknown builtin platform: ${platform.sourceKey}');
    }
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

  /// 获取所有已就绪且支持榜单（脚本 list 或内置排行榜）的后端
  Future<List<MusicBackend>> getReadyListBridges() async {
    final backends = <MusicBackend>[];
    for (final source in sources) {
      if (!source.enabled) continue;
      final backend = await getBackend(source.id);
      if (backend != null && backend.ready && (backend.hasList || backend.hasTopList)) {
        backends.add(backend);
      }
    }
    return backends;
  }

  // ── 导入 ──

  /// 通过脚本内容导入
  Future<SourceImportResult> importFromScript(String scriptSource) async {
    final trimmed = scriptSource.trim();
    if (trimmed.isEmpty) {
      return SourceImportResult.fail('脚本内容为空');
    }
    if (_isHttpUrl(trimmed)) {
      return importFromUrl(trimmed);
    }
    return _importFromScriptContent(scriptSource);
  }

  Future<SourceImportResult> _importFromScriptContent(
    String scriptSource,
  ) async {
    if (scriptSource.trim().isEmpty) {
      return SourceImportResult.fail('脚本内容为空');
    }
    if (!_looksLikeSourceScript(scriptSource)) {
      return SourceImportResult.fail(
        '内容不是有效的 LX 音源脚本，请确认粘贴的是脚本内容而不是 URL',
      );
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
    final candidates = importUrlCandidates(url);

    String scriptSource = '';
    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        final response = await _dio.get(
          candidate,
          options: Options(
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
        );
        scriptSource = response.data?.toString() ?? '';
        if (scriptSource.trim().isEmpty) {
          errors.add('$candidate: 内容为空');
          continue;
        }
        break;
      } on DioException catch (e) {
        errors.add('$candidate: ${_formatDioError(e)}');
      } catch (e) {
        errors.add('$candidate: $e');
      }
    }

    if (scriptSource.trim().isEmpty) {
      return SourceImportResult.fail('下载失败: ${errors.join('；')}');
    }

    return _importFromScriptContent(scriptSource);
  }

  // ── 管理 ──

  /// 移除音源
  void removeSource(String id) {
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

  /// 规范化导入 URL：GitHub blob/raw 页面统一转为 raw.githubusercontent.com
  static String normalizeImportUrl(String url) {
    String normalized = url.trim();

    // 补全协议
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    final githubMatch = RegExp(
      r'^https?://github\.com/([^/]+)/([^/]+)/(?:blob|raw)/(.+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (githubMatch != null) {
      normalized =
          'https://raw.githubusercontent.com/${githubMatch.group(1)}/${githubMatch.group(2)}/${githubMatch.group(3)}';
    }

    return normalized;
  }

  /// 生成下载候选：原地址优先，GitHub 地址追加 jsDelivr 镜像。
  static List<String> importUrlCandidates(String url) {
    final normalized = normalizeImportUrl(url);
    final candidates = <String>[normalized];
    final mirror = _jsDelivrMirror(normalized);
    if (mirror != null && !candidates.contains(mirror)) {
      candidates.add(mirror);
    }
    return candidates;
  }

  static String? _jsDelivrMirror(String url) {
    final rawMatch = RegExp(
      r'^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$',
      caseSensitive: false,
    ).firstMatch(url);
    if (rawMatch == null) return null;

    final owner = rawMatch.group(1);
    final repo = rawMatch.group(2);
    final ref = rawMatch.group(3);
    final path = rawMatch.group(4);
    return 'https://cdn.jsdelivr.net/gh/$owner/$repo@$ref/$path';
  }

  static final RegExp _httpUrlPattern =
      RegExp(r'^https?://', caseSensitive: false);

  static bool _isHttpUrl(String text) => _httpUrlPattern.hasMatch(text);

  static bool _looksLikeSourceScript(String source) {
    if (source.length >= 1024) return true;
    final lower = source.toLowerCase();
    const markers = [
      '@name',
      'lx.',
      'lx-music',
      'module.exports',
      'sourceregister',
      'event_names',
      'httpfetch',
      'search',
      'musicurl',
      'function',
      '=>',
    ];
    return markers.any(lower.contains);
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
