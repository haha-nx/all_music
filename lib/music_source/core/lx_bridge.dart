import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_js/flutter_js.dart';

import '../models/music_track.dart';
import '../models/source_definition.dart';
import 'lx_runtime.dart';

/// LX Music 脚本桥接器
///
/// 负责：
/// 1. 创建和管理 QuickJS 运行实例
/// 2. 注入 LX 运行时环境
/// 3. 执行用户源脚本
/// 4. 发现脚本声明的能力
/// 5. 提供搜索/播放URL/歌词等 API
///
/// 使用方式：
/// ```dart
/// final bridge = LxBridge(source, dio);
/// await bridge.init();
/// if (bridge.ready) {
///   final results = await bridge.search('关键词');
/// }
/// bridge.dispose();
/// ```
class LxBridge {
  final SourceDefinition _source;
  final Dio _dio;

  JavascriptRuntime? _runtime;
  bool _loaded = false;
  bool _initialized = false;
  String? _lastError;

  /// 脚本声明的能力
  Map<String, SourceCapability> _capabilities = {};

  /// 搜索结果缓存 — songId → 原始JS数据JSON
  /// 用于后续 getMusicUrl/getLyric 调用时提供完整上下文
  final Map<String, String> _searchCache = {};

  LxBridge(this._source, this._dio);

  // ── 状态 ──

  bool get ready => _loaded && _initialized;
  bool get isLoaded => _loaded;
  String? get lastError => _lastError;
  Map<String, SourceCapability> get capabilities => Map.unmodifiable(_capabilities);

  /// 搜索用的源key列表
  List<String> get searchKeys =>
      _capabilities.entries
          .where((e) => e.value.actions.contains('search'))
          .map((e) => e.key)
          .toList();

  // ── 初始化 ──

  /// 初始化引擎，加载并运行源脚本
  Future<bool> init() async {
    if (_loaded) return true;
    if (_source.scriptSource.isEmpty) {
      _lastError = '脚本内容为空';
      return false;
    }

    try {
      _runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: true);

      // 1. 注入 LX 运行时环境
      await _runtime!.evaluateAsync(LxRuntime.build());

      // 2. 设置 Dart ↔ JS 消息通道
      _setupChannels();

      // 3. 执行源脚本（包裹在 try-catch 中）
      final script = _wrapScript(_source.scriptSource);
      final result = await _runtime!.evaluateAsync(script,
          sourceUrl: 'source://${_source.id}');

      if (result.isError) {
        _lastError = '脚本语法错误: ${result.stringResult}';
        return false;
      }

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      if (resolved.isError) {
        _lastError = '脚本执行异常: ${resolved.stringResult}';
        return false;
      }

      _loaded = true;

      // 4. 等待脚本的 inited 事件（最多 3 秒）
      for (var i = 0; i < 30 && !_initialized; i++) {
        _runtime!.executePendingJob();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 5. 如果脚本未发送 inited，尝试自动发现能力
      if (!_initialized) {
        await _autoDiscover();
      }

      return _initialized;
    } catch (e) {
      _lastError = '引擎初始化失败: $e';
      return false;
    }
  }

  // ── Dart ↔ JS 消息通道 ──

  void _setupChannels() {
    // HTTP 请求通道
    _runtime!.onMessage('http', (dynamic args) async {
      try {
        final params = _parseArgs(args);
        final url = params['url'] as String;
        final method = (params['method'] as String?)?.toUpperCase() ?? 'GET';
        final headers = (params['headers'] as Map?)?.cast<String, String>() ?? {};
        final body = params['body'];

        final response = await _dio.request(
          url,
          data: body,
          options: Options(
            method: method,
            headers: headers,
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        return <String, dynamic>{
          'statusCode': response.statusCode,
          'statusMessage': response.statusMessage ?? '',
          'headers': response.headers.map,
          'body': response.data?.toString() ?? '',
        };
      } catch (e) {
        return <String, dynamic>{
          'statusCode': -1,
          'statusMessage': e.toString(),
          'headers': <String, List<String>>{},
          'body': '',
        };
      }
    });

    // LX 事件通道
    _runtime!.onMessage('lx', (dynamic args) async {
      try {
        final params = _parseArgs(args);
        final type = params['type'] as String?;

        if (type == 'inited') {
          _handleInited(params['data']);
        } else if (type == 'send') {
          final event = params['event'] as String?;
          if (event == 'inited') {
            _handleInited(params['data']);
          }
        }
        return {'ok': true};
      } catch (e) {
        return {'ok': false, 'error': e.toString()};
      }
    });

    // 日志通道
    _runtime!.onMessage('log', (dynamic args) async {
      // ignore: avoid_print
      print('[LX:${_source.name}] $args');
      return {'ok': true};
    });
  }

  void _handleInited(dynamic data) {
    if (data is! Map) return;

    final sourcesData = data['sources'];
    if (sourcesData is! Map) return;

    final caps = <String, SourceCapability>{};
    for (final entry in sourcesData.entries) {
      if (entry.value is Map) {
        caps[entry.key.toString()] = SourceCapability.fromJson(
          entry.key.toString(),
          entry.value as Map<String, dynamic>,
        );
      }
    }

    if (caps.isNotEmpty) {
      _capabilities = caps;
      _initialized = true;
    }
  }

  /// 自动发现：检测全局函数并注册
  Future<void> _autoDiscover() async {
    final result = _runtime!.evaluate(r'''
      (function() {
        var actions = [];
        if (typeof search === 'function' || typeof searchSong === 'function' || typeof searchMusic === 'function')
          actions.push('search');
        if (typeof getMusicUrl === 'function' || typeof handleGetMusicUrl === 'function')
          actions.push('musicUrl');
        if (typeof getLyric === 'function' || typeof handleGetMusicLyric === 'function')
          actions.push('lyric');
        if (typeof getPic === 'function')
          actions.push('pic');
        return JSON.stringify({ actions: actions, handlerCount: Object.keys(__requestHandlers || {}).length });
      })()
    ''');

    final info = jsonDecode(result.stringResult) as Map<String, dynamic>;
    final actions = (info['actions'] as List?)?.cast<String>() ?? [];
    final handlerCount = info['handlerCount'] as int? ?? 0;

    if (actions.isNotEmpty || handlerCount > 0) {
      _capabilities['_auto'] = SourceCapability(
        key: '_auto',
        name: _source.name,
        actions: actions.isNotEmpty ? actions : ['search'],
        qualitys: ['128k', '320k', 'flac'],
      );
      _initialized = true;
    }
  }

  // ── 搜索 ──

  /// 搜索歌曲
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceKey,
  }) async {
    if (!ready) return [];

    final keys = sourceKey != null ? [sourceKey] : searchKeys;
    if (keys.isEmpty) {
      _lastError = '音源不支持搜索';
      return [];
    }

    _searchCache.clear();
    final allTracks = <MusicTrack>[];

    for (final key in keys) {
      try {
        final tracks = await _searchInSource(key, keyword, page, limit);
        allTracks.addAll(tracks);
      } catch (e) {
        // ignore: avoid_print
        print('[LX:${_source.name}] 搜索 $key 失败: $e');
      }
    }

    return allTracks;
  }

  Future<List<MusicTrack>> _searchInSource(
    String sourceKey,
    String keyword,
    int page,
    int limit,
  ) async {
    final escapedKeyword = _escapeJs(keyword);
    final result = await _runtime!.evaluateAsync('''
      (async () => {
        try {
          var handler = __requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'];
          if (!handler) return JSON.stringify({ error: 'no handler' });

          var resp = await handler({
            source: '${_escapeJs(sourceKey)}',
            action: 'search',
            info: { keyword: '${_escapeJs(escapedKeyword)}', page: $page, limit: $limit }
          });

          // 标准化返回格式
          if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
          if (resp && resp.list) return JSON.stringify({ type: 'list', data: resp.list });
          if (resp && resp.data) return JSON.stringify({ type: 'list', data: resp.data });
          if (resp && resp.songs) return JSON.stringify({ type: 'list', data: resp.songs });
          return JSON.stringify({ type: 'list', data: resp || [] });
        } catch(e) {
          return JSON.stringify({ error: e.message || String(e) });
        }
      })()
    ''');

    _runtime!.executePendingJob();
    final resolved = await _runtime!.handlePromise(result);
    final data = jsonDecode(resolved.stringResult) as Map<String, dynamic>;

    if (data['error'] != null) return [];

    final items = data['data'];
    if (items is! List) return [];

    final tracks = <MusicTrack>[];
    for (final item in items) {
      if (item is! Map) continue;
      final track = _trackFromJs(item, sourceKey);
      _searchCache[track.id] = jsonEncode(item);
      tracks.add(track);
    }

    return tracks;
  }

  // ── 获取播放URL ──

  /// 获取歌曲播放URL
  Future<String?> getMusicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) async {
    if (!ready) return null;

    final sourceKey = track.sourceKey;
    final cap = _capabilities[sourceKey] ?? _capabilities.values.firstOrNull;
    final qualitys = cap?.qualitys ?? ['128k'];
    final q = qualitys.contains(quality) ? quality : qualitys.first;

    // 使用缓存的完整搜索结果
    final musicInfoJs = _searchCache[track.id] ??
        '{"id":"${_escapeJs(track.id)}","title":"${_escapeJs(track.title)}",'
            '"artist":"${_escapeJs(track.artist)}","sourceKey":"${_escapeJs(sourceKey)}"}';

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var handler = __requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'];
            if (!handler) return null;

            var musicInfo = JSON.parse('${_escapeJs(musicInfoJs)}');
            var resp = await handler({
              source: '${_escapeJs(sourceKey)}',
              action: 'musicUrl',
              info: { type: '${_escapeJs(q)}', musicInfo: musicInfo }
            });

            if (typeof resp === 'string') return resp;
            if (resp && resp.url) return resp.url;
            if (resp && resp.result) return resp.result;
            return null;
          } catch(e) { return null; }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final raw = resolved.stringResult;
      if (raw.isEmpty || raw == 'null') return null;

      // 尝试解析为JSON
      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        return (obj['url'] ?? obj['result'])?.toString();
      } catch (_) {
        return raw;
      }
    } catch (e) {
      return null;
    }
  }

  // ── 获取歌词 ──

  /// 获取歌词
  Future<String?> getLyric(MusicTrack track) async {
    if (!ready) return null;

    final sourceKey = track.sourceKey;
    final musicInfoJs = _searchCache[track.id] ??
        '{"id":"${_escapeJs(track.id)}","title":"${_escapeJs(track.title)}",'
            '"artist":"${_escapeJs(track.artist)}","sourceKey":"${_escapeJs(sourceKey)}"}';

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var handler = __requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'];
            if (!handler) return null;

            var musicInfo = JSON.parse('${_escapeJs(musicInfoJs)}');
            var resp = await handler({
              source: '${_escapeJs(sourceKey)}',
              action: 'lyric',
              info: { musicInfo: musicInfo }
            });

            if (typeof resp === 'string') return resp;
            if (resp && resp.lyric) return resp.lyric;
            if (resp && resp.lrc) return resp.lrc;
            return null;
          } catch(e) { return null; }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final raw = resolved.stringResult;
      if (raw.isEmpty || raw == 'null') return null;

      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        return (obj['lyric'] ?? obj['lrc'])?.toString();
      } catch (_) {
        return raw;
      }
    } catch (e) {
      return null;
    }
  }

  // ── 工具方法 ──

  /// 从 JS 对象解析 MusicTrack
  MusicTrack _trackFromJs(Map<dynamic, dynamic> item, String sourceKey) {
    return MusicTrack(
      id: (item['id'] ?? item['musicId'] ?? item['songmid'] ?? item['hash'] ?? '')?.toString() ?? '',
      title: (item['name'] ?? item['title'] ?? item['songname'] ?? item['SongName'] ?? '')?.toString() ?? '',
      artist: (item['artist'] ?? item['singer'] ?? item['author'] ?? item['SingerName'] ?? '')?.toString() ?? '',
      album: (item['album'] ?? item['albumname'] ?? item['AlbumName'])?.toString(),
      coverUrl: (item['albumCover'] ?? item['pic'] ?? item['img'] ?? item['cover'])?.toString(),
      durationMs: _parseDuration(item['duration']),
      sourceId: _source.id,
      sourceKey: sourceKey,
      lyricId: item['lyricId']?.toString(),
    );
  }

  int? _parseDuration(dynamic d) {
    if (d == null) return null;
    if (d is int) return d;
    if (d is double) return d.toInt();
    return int.tryParse(d.toString());
  }

  /// 包装脚本（添加兼容层和错误处理）
  String _wrapScript(String scriptSource) {
    return '''
try {
  (function() {
    // 保存并重置 module/exports（避免被前一次运行污染）
    var _savedModule = typeof module !== 'undefined' ? module : undefined;
    var _savedExports = typeof exports !== 'undefined' ? exports : undefined;

    // 执行源脚本
    $scriptSource

    // 兼容 module.exports 老格式
    if (!__initialized && typeof module !== 'undefined' && module.exports && typeof module.exports === 'object') {
      var exp = module.exports;
      var sources = {};
      var supportedActions = [];

      if (typeof exp.search === 'function') supportedActions.push('search');
      if (typeof exp.getMusicUrl === 'function' || typeof exp.handleGetMusicUrl === 'function') supportedActions.push('musicUrl');
      if (typeof exp.getLyric === 'function' || typeof exp.handleGetMusicLyric === 'function') supportedActions.push('lyric');
      if (typeof exp.getPic === 'function') supportedActions.push('pic');

      if (supportedActions.length > 0) {
        sources['_auto'] = {
          name: typeof exp.name === 'string' ? exp.name : '${_escapeJs(_source.name)}',
          type: 'music',
          actions: supportedActions,
          qualitys: ['128k', '320k', 'flac'],
        };

        __requestHandlers['_auto'] = function(info) {
          var action = info.action;
          var req = info.info || info;
          switch(action) {
            case 'search':
              return exp.search.length <= 1 ? exp.search(req) : exp.search(req.keyword, req.page, req.limit);
            case 'musicUrl':
              return typeof exp.handleGetMusicUrl === 'function' ? exp.handleGetMusicUrl(req) : exp.getMusicUrl(req, req.type || '128k');
            case 'lyric':
              return typeof exp.handleGetMusicLyric === 'function' ? exp.handleGetMusicLyric(req) : exp.getLyric(req);
            default:
              return Promise.reject('unsupported: ' + action);
          }
        };

        __sendInited({ sources: sources });
      }
    }
  })();
} catch(e) {
  __sendInited({ sources: {} });
  sendMessage('log', '[FATAL] ' + (e.message || String(e)));
}
''';
  }

  /// 解析消息参数（兼容 String/Map 两种格式）
  Map<String, dynamic> _parseArgs(dynamic args) {
    if (args is String) {
      try {
        return jsonDecode(args) as Map<String, dynamic>;
      } catch (_) {
        return {'value': args};
      }
    }
    if (args is Map<String, dynamic>) return args;
    return {};
  }

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  /// 释放资源
  void dispose() {
    _searchCache.clear();
    _runtime?.dispose();
    _runtime = null;
    _loaded = false;
    _initialized = false;
    _capabilities = {};
  }
}
