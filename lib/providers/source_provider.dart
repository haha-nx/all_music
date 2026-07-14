import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../models/music_source.dart';
import '../services/source_engine.dart';
import '../services/storage_service.dart';
import '../utils/http_client.dart';

const _uuid = Uuid();

/// 音源导入验证结果
class ImportResult {
  final bool success;
  final String? error;

  const ImportResult._({required this.success, this.error});

  factory ImportResult.ok() => const ImportResult._(success: true);
  factory ImportResult.fail(String error) => ImportResult._(success: false, error: error);
}

/// 音源状态管理（SQLite 持久化）
class SourceNotifier extends StateNotifier<List<MusicSource>> {
  /// JS 脚本源引擎缓存（sourceId → SourceEngine）
  final Map<String, SourceEngine> _engines = {};

  SourceNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = await storageService.loadSources();
    } catch (e) {
      // ignore: avoid_print
      print('SourceNotifier._init error: $e');
    }
  }

  /// 获取指定音源的 JS 引擎实例（仅 script 类型）
  /// 确保引擎已初始化后才返回
  Future<SourceEngine?> getEngine(String sourceId) async {
    if (_engines.containsKey(sourceId)) {
      final engine = _engines[sourceId]!;
      if (!engine.isLoaded) {
        await engine.init();
      }
      return engine.isLoaded ? engine : null;
    }

    final source = state.where((s) => s.id == sourceId).firstOrNull;
    if (source == null || source.sourceType != MusicSourceType.script) return null;

    final engine = SourceEngine(source);
    final ok = await engine.init();
    if (!ok) {
      engine.dispose();
      return null;
    }

    _engines[sourceId] = engine;
    return engine;
  }

  /// 添加 REST API 音源
  void addSource(String name, String apiUrl, {String? token}) {
    final source = MusicSource(
      id: _uuid.v4(),
      name: name,
      apiUrl: apiUrl,
      token: token,
      sourceType: MusicSourceType.api,
      createdAt: DateTime.now(),
    );
    state = [...state, source];
    _save();
  }

  /// 添加 JS 脚本音源
  void _addScriptSource(String name, String url, String scriptSource) {
    final source = MusicSource(
      id: _uuid.v4(),
      name: name,
      apiUrl: url,
      sourceType: MusicSourceType.script,
      scriptSource: scriptSource,
      createdAt: DateTime.now(),
    );
    state = [...state, source];
    _save();
  }

  /// 通过 URL 自动检测并导入音源
  ///
  /// - .js 结尾 → JS 脚本源（下载 + 引擎验证）
  /// - 其他 → REST API 源（GET 可达 + POST /search 探活）
  Future<ImportResult> importFromUrl(String name, String url, {String? token}) async {
    // 修正 URL 格式
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    // 移除尾随斜杠
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    // 自动检测 JS 源脚本（以 .js 结尾）
    if (normalizedUrl.toLowerCase().endsWith('.js')) {
      return _importScript(name, normalizedUrl);
    }

    return _importApi(name, normalizedUrl, token: token);
  }

  /// 导入 JS 脚本源
  Future<ImportResult> _importScript(String name, String url) async {
    final dio = MusicHttpClient().dio;

    // 步骤 1：下载 JS 源码
    String scriptSource;
    try {
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      scriptSource = response.data?.toString() ?? '';
      if (scriptSource.isEmpty) {
        return ImportResult.fail('下载的脚本内容为空');
      }
    } on DioException catch (e) {
      return ImportResult.fail('下载脚本失败：${e.message}');
    } catch (e) {
      return ImportResult.fail('下载脚本失败：$e');
    }

    // 步骤 2：创建临时引擎验证脚本
    final tempSource = MusicSource(
      id: _uuid.v4(),
      name: name,
      apiUrl: url,
      sourceType: MusicSourceType.script,
      scriptSource: scriptSource,
      createdAt: DateTime.now(),
    );

    final engine = SourceEngine(tempSource);
    final ok = await engine.init();

    if (!ok) {
      engine.dispose();
      return ImportResult.fail('脚本语法错误或执行失败：${engine.lastError}');
    }

    // 验证通过，保存到数据库
    _addScriptSource(name, url, scriptSource);

    // —— 重要：用正式 source 创建新引擎并初始化 ——
    // 临时引擎的 source.id 和正式的不一样，必须用正式 source 重建
    engine.dispose();
    final newSource = state.last; // 刚添加的
    final newEngine = SourceEngine(newSource);
    await newEngine.init();
    _engines[newSource.id] = newEngine;

    return ImportResult.ok();
  }

  /// 导入 REST API 音源
  Future<ImportResult> _importApi(String name, String normalizedUrl, {String? token}) async {
    final dio = MusicHttpClient().dio;

    try {
      // 步骤 1：检查服务器可达性
      await dio.get(
        normalizedUrl,
        options: Options(
          headers: _buildHeaders(token),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } catch (e) {
      return ImportResult.fail('无法连接到服务器，请检查 URL 是否正确');
    }

    // 步骤 2：验证 API 兼容性（发送测试搜索）
    try {
      final response = await dio.post(
        '$normalizedUrl/search',
        data: {'keyword': '__test__', 'limit': 1},
        options: Options(
          headers: _buildHeaders(token),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final data = response.data;
      if (data == null || data is! Map) {
        return ImportResult.fail('API 返回格式不正确，需要 JSON 对象');
      }
      if (!data.containsKey('songs')) {
        return ImportResult.fail('API 缺少 "songs" 字段，格式不兼容');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ImportResult.fail('服务器未实现 /search 接口（404）');
      }
      return ImportResult.fail('API 探活失败：${e.message}');
    } catch (e) {
      return ImportResult.fail('未知错误：$e');
    }

    // 验证通过，保存
    addSource(name, normalizedUrl, token: token);
    return ImportResult.ok();
  }

  Map<String, String> _buildHeaders(String? token) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  /// 更新音源（同步清理引擎缓存）
  void updateSource(MusicSource updated) {
    if (state.any((s) => s.id == updated.id && s.sourceType != updated.sourceType)) {
      _engines.remove(updated.id);
    }
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
    _save();
  }

  /// 移除音源（同时释放引擎）
  void removeSource(String id) {
    _engines[id]?.dispose();
    _engines.remove(id);
    state = state.where((s) => s.id != id).toList();
    _save();
  }

  /// 切换启用/禁用
  void toggleEnabled(String id) {
    state = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(enabled: !s.enabled)
        else
          s,
    ];
    _save();
  }

  /// 获取所有启用的音源
  List<MusicSource> get enabledSources =>
      state.where((s) => s.enabled).toList();

  Future<void> _save() async => storageService.saveSources(state);

  @override
  void dispose() {
    for (final engine in _engines.values) {
      engine.dispose();
    }
    _engines.clear();
    super.dispose();
  }
}

final sourceProvider = StateNotifierProvider<SourceNotifier, List<MusicSource>>((ref) {
  return SourceNotifier();
});
