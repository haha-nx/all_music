import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

import '../models/music_list.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import 'lx_runtime.dart';
import 'music_backend.dart';

/// LX Music 脚本桥接器
///
/// 负责：
/// 1. 创建和管理 QuickJS 运行实例
/// 2. 注入 LX 运行时环境（含真实 CryptoJS）
/// 3. 执行用户源脚本
/// 4. 发现脚本声明的能力（支持两种契约）
///    - 新版：lx.sourceRegister({ music:{search,musicUrl,lyric} })
///    - 旧版：lx.on('request', handler) + lx.send('inited', {sources})
/// 5. 提供搜索/播放URL/歌词等 API
///
/// 使用示例：
/// ```dart
/// final bridge = LxBridge(source, dio);
/// await bridge.init();
/// if (bridge.ready) {
///   final results = await bridge.search('关键词');
/// }
/// bridge.dispose();
/// ```
class LxBridge implements MusicBackend {
  final SourceDefinition _source;
  final Dio _dio;

  JavascriptRuntime? _runtime;
  bool _loaded = false;
  bool _initialized = false;
  String? _lastError;

  /// 脚本声明的能力（sourceKey → SourceCapability）
  Map<String, SourceCapability> _capabilities = {};

  /// 搜索结果缓存 — songId → 原始JS数据JSON
  /// 用于后续 getMusicUrl/getLyric 调用时提供完整上下文
  final Map<String, String> _searchCache = {};

  LxBridge(this._source, this._dio);

  // ── 状态 ──

  @override
  String get sourceId => _source.id;

  @override
  bool get ready => _loaded && _initialized;

  @override
  bool get isLoaded => _loaded;

  @override
  String? get lastError => _lastError;

  @override
  Map<String, SourceCapability> get capabilities => Map.unmodifiable(_capabilities);

  /// 搜索用的源key列表
  @override
  List<String> get searchKeys =>
      _capabilities.entries
          .where((e) => e.value.actions.contains('search'))
          .map((e) => e.key)
          .toList();

  /// 榜单用的源key列表
  @override
  List<String> get listKeys =>
      _capabilities.entries
          .where((e) => e.value.hasList)
          .map((e) => e.key)
          .toList();

  /// 是否支持榜单
  @override
  bool get hasList => listKeys.isNotEmpty;

  // ── 初始化 ──

  /// 初始化引擎，加载并运行源脚本
  @override
  Future<bool> init() async {
    if (_loaded) return true;
    if (_source.scriptSource.isEmpty) {
      _lastError = '脚本内容为空';
      return false;
    }

    try {
      // quickjs_engine：自带 QuickJS-NG 原生库，无需 libjsc.so（修复 Android 崩溃）
      // xhr: false —— 不启用引擎内置的 fetch 服务器，HTTP 走我们自己的
      // sendMessage('http') 通道（Dio 实现），避免冗余且更易控。
      _runtime = getJavascriptRuntime(xhr: false);

      // 0. 先注册消息通道（必须在任何 JS evaluate 之前！
      //     否则 LxRuntime 里定义的函数如果触发了 sendMessage → 无 handler → 异常）
      _setupChannels();

      // 1. 注入 LX 运行时环境（polyfills / 真实 CryptoJS / lx API / httpFetch）
      //    LxRuntime.build() 现在是 async（需加载 CryptoJS 资源）
      print('[LXBridge] 注入 LX 运行时环境...');
      final runtimeScript = await LxRuntime.build();
      final runtimeResult = await _runtime!.evaluateAsync(runtimeScript);
      if (runtimeResult.isError) {
        _lastError = '运行时注入失败: ${runtimeResult.stringResult}';
        print('[LXBridge] 运行时注入失败: ${runtimeResult.stringResult}');
        return false;
      }
      print('[LXBridge] 运行时环境注入成功');

      // 1.5 注入脚本头元信息到 lx.currentScriptInfo
      //    标准 LX 源脚本会读取 name/description/version 等做校验（如六音源）
      final meta = SourceDefinition.parseMeta(_source.scriptSource);
      if (meta.isNotEmpty) {
        try {
          final inject = jsonEncode(meta);
          await _runtime!.evaluate(
              'Object.assign(__scriptInfo, $inject); true');
        } catch (e) {
          print('[LXBridge] currentScriptInfo 注入失败: $e');
        }
      }

      // 2. 执行源脚本
      final script = _wrapScript(_source.scriptSource);
      print('[LXBridge] 开始执行脚本 ${_source.name} (${_source.scriptSource.length} 字节)...');

      final result = await _runtime!.evaluateAsync(script,
          sourceUrl: 'source://${_source.id}');

      if (result.isError) {
        _lastError = '脚本语法错误: ${result.stringResult}';
        print('[LXBridge] 脚本语法错误: ${result.stringResult}');
        return false;
      }

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      if (resolved.isError) {
        _lastError = '脚本执行异常: ${resolved.stringResult}';
        print('[LXBridge] 脚本执行异常: ${resolved.stringResult}');
        return false;
      }

      _loaded = true;
      print('[LXBridge] 脚本加载完成，等待 inited / sourceRegister 事件...');

      // 3. 等待脚本的就绪事件（最多 15 秒）
      for (var i = 0; i < 150 && !_initialized; i++) {
        _runtime!.executePendingJob();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 4. 如果脚本未发送就绪事件，尝试自动发现能力（旧契约兜底）
      if (!_initialized) {
        print('[LXBridge] 未收到就绪事件，尝试自动发现...');
        await _autoDiscover();
      }

      if (_initialized) {
        print('[LXBridge] 引擎就绪: ${_source.name} '
            '(子源: ${_capabilities.keys.join(", ")})');
      } else {
        print('[LXBridge] 引擎初始化超时: ${_source.name}');
        _lastError = '初始化超时（15秒），脚本可能不兼容或格式不正确';
      }

      return _initialized;
    } catch (e) {
      _lastError = '引擎初始化失败: $e';
      print('[LXBridge] 引擎初始化异常: $e');
      return false;
    }
  }

  // ── Dart ↔ JS 消息通道 ──

  void _setupChannels() {
    // HTTP 请求通道
    _runtime!.onMessage('http', (dynamic args) async {
      try {
        final params = _parseArgs(args);
        final url = params['url'] as String? ?? '';
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
            // 关键：脚本顶层常会 await httpFetch 检查更新/加载配置，
            // 若请求无限挂起会导致引擎初始化超时。必须设置短超时快速失败。
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        // 返回简单结构，避免复杂嵌套 Map 导致 _dartToJs 问题
        return <String, dynamic>{
          'statusCode': response.statusCode ?? 0,
          'statusMessage': response.statusMessage ?? '',
          'body': response.data?.toString() ?? '',
          // 不传 headers.map（Map<String,List<String>> 可能导致序列化问题）
        };
      } catch (e) {
        print('[LXBridge:http] 请求异常: $e');
        return <String, dynamic>{
          'statusCode': -1,
          'statusMessage': e.toString(),
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
          } else if (event == 'sourceRegister') {
            _handleSourceRegister(params['data']);
          }
        } else if (type == 'sourceRegister') {
          _handleSourceRegister(params['data']);
        }
        return {'ok': true};
      } catch (e) {
        print('[LXBridge:lx] 事件处理异常: $e');
        return <String, dynamic>{'ok': false, 'error': '$e'};
      }
    });

    // 日志通道
    _runtime!.onMessage('log', (dynamic args) async {
      // ignore: avoid_print
      print('[LX:${_source.name}] $args');
      return <String, dynamic>{'ok': true};
    });
  }

  /// 旧契约：lx.send('inited', { sources: {...} })
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

  /// 新契约：lx.sourceRegister({ name, type, music:{search,musicUrl,lyric,...} })
  /// 真实函数对象已存入 JS 全局 __lxSources[name]，这里只登记能力并标记就绪。
  void _handleSourceRegister(dynamic data) {
    if (data is! Map) return;

    final name = data['name']?.toString() ?? _source.name;
    final type = data['type']?.toString() ?? 'music';
    final actions = (data['actions'] as List?)?.cast<String>() ?? [];
    final hasMusic = data['hasMusic'] == true;

    if (!hasMusic && actions.isEmpty) return;

    final qualitys = <String>['128k', '320k', 'flac'];
    final listTypes = _parseListTypes(data['listTypes']);
    _capabilities[name] = SourceCapability(
      key: name,
      name: name,
      type: type,
      actions: actions.isNotEmpty
          ? actions
          : ['search', 'musicUrl', 'lyric', 'getMusicInfo', 'list', 'listDetail'],
      qualitys: qualitys,
      listTypes: listTypes,
    );
    _initialized = true;
    print('[LXBridge] 收到 sourceRegister: $name '
        '(actions: ${actions.join(", ")}, listTypes: ${listTypes.map((t) => t.name).join("/")})');
  }

  /// 解析 listTypes 声明（数组 of {name, type}）
  List<ListTypeInfo> _parseListTypes(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ListTypeInfo>[];
    for (final item in raw.whereType<Map>()) {
      result.add(ListTypeInfo.fromJson(item.cast<String, dynamic>()));
    }
    return result;
  }

  /// 自动发现：检测全局函数并注册（旧契约兜底）
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
        if (typeof getMusicInfo === 'function')
          actions.push('getMusicInfo');
        if (typeof list === 'function' || typeof getList === 'function')
          actions.push('list');
        if (typeof listDetail === 'function' || typeof getListDetail === 'function')
          actions.push('listDetail');
        if (typeof importList === 'function')
          actions.push('importList');
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
  @override
  Future<List<MusicTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
    String? sourceKey,
    SearchType type = SearchType.song,
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
        final tracks = await _searchInSource(key, keyword, page, limit, type);
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
    SearchType type,
  ) async {
    final result = await _runtime!.evaluateAsync('''
      (async () => {
        try {
          // ── 新契约：lx.sourceRegister({ music:{search,...} }) ──
          var src = (typeof globalThis.__lxSources !== 'undefined')
            ? globalThis.__lxSources['${_escapeJs(sourceKey)}'] : null;
          if (src && src.music && typeof src.music.search === 'function') {
            var list = await src.music.search({
              keyword: '${_escapeJs(keyword)}',
              page: $page,
              limit: $limit,
              type: '${type.value}'
            });
            if (!Array.isArray(list)) list = [];
            return JSON.stringify({ type: 'list', data: list });
          }

          // ── 旧契约：lx.on('request', handler) ──
          var handler = (typeof __requestHandlers !== 'undefined')
            ? (__requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'])
            : null;
          if (handler) {
            var resp = await handler({
              source: '${_escapeJs(sourceKey)}',
              action: 'search',
              info: { keyword: '${_escapeJs(keyword)}', page: $page, limit: $limit, type: '${type.value}' }
            });
            if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
            if (resp && resp.list) return JSON.stringify({ type: 'list', data: resp.list });
            if (resp && resp.data) return JSON.stringify({ type: 'list', data: resp.data });
            if (resp && resp.songs) return JSON.stringify({ type: 'list', data: resp.songs });
            return JSON.stringify({ type: 'list', data: resp || [] });
          }

          return JSON.stringify({ error: 'no search handler for ' + '${_escapeJs(sourceKey)}' });
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
  @override
  Future<String?> getMusicUrl(
    MusicTrack track, {
    String quality = '128k',
  }) async {
    if (!ready) return null;

    final sourceKey = track.sourceKey;
    final cap = _capabilities[sourceKey] ?? _capabilities.values.firstOrNull;
    final qualitys = cap?.qualitys ?? ['128k'];
    final q = qualitys.contains(quality) ? quality : qualitys.first;

    // 使用缓存的完整搜索结果 / rawData 构造 song 对象
    final songJs = _songJson(track);

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var song = JSON.parse('${_escapeJs(songJs)}');

            // ── 新契约 ──
            var src = (typeof globalThis.__lxSources !== 'undefined')
              ? globalThis.__lxSources['${_escapeJs(sourceKey)}'] : null;
            if (src && src.music && typeof src.music.musicUrl === 'function') {
              var url = await src.music.musicUrl(song, '${_escapeJs(q)}');
              return (url && String(url).length > 0) ? String(url) : null;
            }

            // ── 旧契约 ──
            var handler = (typeof __requestHandlers !== 'undefined')
              ? (__requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'])
              : null;
            if (handler) {
              var resp = await handler({
                source: '${_escapeJs(sourceKey)}',
                action: 'musicUrl',
                info: { type: '${_escapeJs(q)}', musicInfo: song }
              });
              if (typeof resp === 'string') return resp;
              if (resp && resp.url) return resp.url;
              if (resp && resp.result) return resp.result;
              return null;
            }
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
  @override
  Future<String?> getLyric(MusicTrack track) async {
    if (!ready) return null;

    final sourceKey = track.sourceKey;
    final songJs = _songJson(track);

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var song = JSON.parse('${_escapeJs(songJs)}');

            // ── 新契约 ──
            var src = (typeof globalThis.__lxSources !== 'undefined')
              ? globalThis.__lxSources['${_escapeJs(sourceKey)}'] : null;
            if (src && src.music && typeof src.music.lyric === 'function') {
              var lrc = await src.music.lyric(song);
              return (lrc && String(lrc).length > 0) ? String(lrc) : null;
            }

            // ── 旧契约 ──
            var handler = (typeof __requestHandlers !== 'undefined')
              ? (__requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'])
              : null;
            if (handler) {
              var resp = await handler({
                source: '${_escapeJs(sourceKey)}',
                action: 'lyric',
                info: { musicInfo: song }
              });
              if (typeof resp === 'string') return resp;
              if (resp && resp.lyric) return resp.lyric;
              if (resp && resp.lrc) return resp.lrc;
              return null;
            }
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

  // ── 歌曲详情 ──

  /// 获取歌曲详情（补全专辑/封面等信息）
  @override
  Future<MusicTrack?> getMusicInfo(
    MusicTrack track, {
    String? sourceKey,
  }) async {
    if (!ready) return null;

    final key = sourceKey ?? track.sourceKey;
    final songJs = _songJson(track);

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var song = JSON.parse('${_escapeJs(songJs)}');

            // ── 新契约 ──
            var src = (typeof globalThis.__lxSources !== 'undefined')
              ? globalThis.__lxSources['${_escapeJs(key)}'] : null;
            if (src && src.music && typeof src.music.getMusicInfo === 'function') {
              var info = await src.music.getMusicInfo(song);
              return (info && typeof info === 'object')
                ? JSON.stringify(info) : null;
            }

            // ── 旧契约 ──
            var handler = (typeof __requestHandlers !== 'undefined')
              ? (__requestHandlers['${_escapeJs(key)}'] || __requestHandlers['_global'])
              : null;
            if (handler) {
              var resp = await handler({
                source: '${_escapeJs(key)}',
                action: 'getMusicInfo',
                info: { musicInfo: song }
              });
              if (resp && typeof resp === 'object') return JSON.stringify(resp);
              if (resp && resp.musicInfo) return JSON.stringify(resp.musicInfo);
              return null;
            }
            return null;
          } catch(e) { return null; }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final raw = resolved.stringResult;
      if (raw.isEmpty || raw == 'null') return null;

      final obj = jsonDecode(raw);
      if (obj is! Map) return null;
      return _trackFromJs(obj, key, rawData: raw);
    } catch (e) {
      return null;
    }
  }

  // ── 榜单/排行榜 ──

  /// 获取榜单列表（lx 标准 list）
  @override
  Future<List<MusicListInfo>> list({
    int page = 1,
    int limit = 20,
    String? sourceKey,
    String? listType,
  }) async {
    if (!ready) return [];

    final keys = sourceKey != null ? [sourceKey] : listKeys;
    if (keys.isEmpty) return [];

    final all = <MusicListInfo>[];
    for (final key in keys) {
      try {
        final items = await _listInSource(key, page, limit, listType);
        all.addAll(items);
      } catch (e) {
        // ignore: avoid_print
        print('[LX:${_source.name}] 榜单 $key 失败: $e');
      }
    }
    return all;
  }

  Future<List<MusicListInfo>> _listInSource(
    String sourceKey,
    int page,
    int limit,
    String? listType,
  ) async {
    final result = await _runtime!.evaluateAsync('''
      (async () => {
        try {
          // ── 新契约：src.music.list({page, limit, type}) ──
          var src = (typeof globalThis.__lxSources !== 'undefined')
            ? globalThis.__lxSources['${_escapeJs(sourceKey)}'] : null;
          if (src && src.music && typeof src.music.list === 'function') {
            var list = await src.music.list({
              page: $page,
              limit: $limit,
              type: '${_escapeJs(listType ?? '')}'
            });
            if (list && Array.isArray(list.list)) return JSON.stringify({ type: 'list', data: list.list });
            if (Array.isArray(list)) return JSON.stringify({ type: 'list', data: list });
            return JSON.stringify({ type: 'list', data: [] });
          }

          // ── 旧契约 ──
          var handler = (typeof __requestHandlers !== 'undefined')
            ? (__requestHandlers['${_escapeJs(sourceKey)}'] || __requestHandlers['_global'])
            : null;
          if (handler) {
            var resp = await handler({
              source: '${_escapeJs(sourceKey)}',
              action: 'list',
              info: { page: $page, limit: $limit, type: '${_escapeJs(listType ?? '')}' }
            });
            if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
            if (resp && Array.isArray(resp.list)) return JSON.stringify({ type: 'list', data: resp.list });
            if (resp && Array.isArray(resp.data)) return JSON.stringify({ type: 'list', data: resp.data });
            return JSON.stringify({ type: 'list', data: [] });
          }
          return JSON.stringify({ type: 'list', data: [] });
        } catch(e) {
          return JSON.stringify({ type: 'list', data: [] });
        }
      })()
    ''');

    _runtime!.executePendingJob();
    final resolved = await _runtime!.handlePromise(result);
    final data = jsonDecode(resolved.stringResult) as Map<String, dynamic>;
    final items = data['data'];
    if (items is! List) return [];

    return items.whereType<Map>().map((item) {
      final map = item.cast<String, dynamic>();
      return _listFromJs(map, sourceKey);
    }).toList();
  }

  /// 获取榜单详情（lx 标准 listDetail）
  @override
  Future<List<MusicTrack>> listDetail(
    MusicListInfo listInfo, {
    int page = 1,
    int limit = 50,
    String? sourceKey,
  }) async {
    if (!ready) return [];

    final key = sourceKey ?? listInfo.sourceKey;
    final listJs = listInfo.rawData ?? jsonEncode({
      'id': listInfo.id,
      'name': listInfo.title,
      'pic': listInfo.picUrl,
      'source': listInfo.sourceId,
    });

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            var listInfo = JSON.parse('${_escapeJs(listJs)}');

            // ── 新契约 ──
            var src = (typeof globalThis.__lxSources !== 'undefined')
              ? globalThis.__lxSources['${_escapeJs(key)}'] : null;
            if (src && src.music && typeof src.music.listDetail === 'function') {
              var resp = await src.music.listDetail(listInfo, { page: $page, limit: $limit });
              if (resp && Array.isArray(resp.list)) return JSON.stringify({ type: 'list', data: resp.list });
              if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
              return JSON.stringify({ type: 'list', data: [] });
            }

            // ── 旧契约 ──
            var handler = (typeof __requestHandlers !== 'undefined')
              ? (__requestHandlers['${_escapeJs(key)}'] || __requestHandlers['_global'])
              : null;
            if (handler) {
              var resp = await handler({
                source: '${_escapeJs(key)}',
                action: 'listDetail',
                info: { listInfo: listInfo, page: $page, limit: $limit }
              });
              if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
              if (resp && Array.isArray(resp.list)) return JSON.stringify({ type: 'list', data: resp.list });
              if (resp && Array.isArray(resp.data)) return JSON.stringify({ type: 'list', data: resp.data });
              return JSON.stringify({ type: 'list', data: [] });
            }
            return JSON.stringify({ type: 'list', data: [] });
          } catch(e) {
            return JSON.stringify({ type: 'list', data: [] });
          }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final data = jsonDecode(resolved.stringResult) as Map<String, dynamic>;
      final items = data['data'];
      if (items is! List) return [];

      final tracks = <MusicTrack>[];
      for (final item in items.whereType<Map>()) {
        final track = _trackFromJs(item, key);
        if (track.id.isNotEmpty) {
          _searchCache[track.id] = jsonEncode(item.cast<String, dynamic>());
          tracks.add(track);
        }
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  /// 导入歌单（lx 标准 importList，部分音源支持）
  @override
  Future<List<MusicTrack>> importList(
    String url, {
    String? sourceKey,
  }) async {
    if (!ready) return [];

    final keys = sourceKey != null ? [sourceKey] : listKeys;
    if (keys.isEmpty) return [];

    final all = <MusicTrack>[];
    for (final key in keys) {
      try {
        final result = await _runtime!.evaluateAsync('''
          (async () => {
            try {
              // ── 新契约：src.music.importList({url}) ──
              var src = (typeof globalThis.__lxSources !== 'undefined')
                ? globalThis.__lxSources['${_escapeJs(key)}'] : null;
              if (src && src.music && typeof src.music.importList === 'function') {
                var list = await src.music.importList({ url: '${_escapeJs(url)}' });
                if (Array.isArray(list)) return JSON.stringify({ type: 'list', data: list });
                if (list && Array.isArray(list.list)) return JSON.stringify({ type: 'list', data: list.list });
                if (list && Array.isArray(list.songs)) return JSON.stringify({ type: 'list', data: list.songs });
                return JSON.stringify({ type: 'list', data: [] });
              }

              // ── 旧契约 ──
              var handler = (typeof __requestHandlers !== 'undefined')
                ? (__requestHandlers['${_escapeJs(key)}'] || __requestHandlers['_global'])
                : null;
              if (handler) {
                var resp = await handler({
                  source: '${_escapeJs(key)}',
                  action: 'importList',
                  info: { url: '${_escapeJs(url)}' }
                });
                if (Array.isArray(resp)) return JSON.stringify({ type: 'list', data: resp });
                if (resp && Array.isArray(resp.list)) return JSON.stringify({ type: 'list', data: resp.list });
                if (resp && Array.isArray(resp.songs)) return JSON.stringify({ type: 'list', data: resp.songs });
                return JSON.stringify({ type: 'list', data: [] });
              }
              return JSON.stringify({ type: 'list', data: [] });
            } catch(e) {
              return JSON.stringify({ type: 'list', data: [] });
            }
          })()
        ''');

        _runtime!.executePendingJob();
        final resolved = await _runtime!.handlePromise(result);
        final data = jsonDecode(resolved.stringResult) as Map<String, dynamic>;
        final items = data['data'];
        if (items is! List) continue;

        for (final item in items.whereType<Map>()) {
          final track = _trackFromJs(item, key);
          if (track.id.isNotEmpty) {
            _searchCache[track.id] = jsonEncode(item.cast<String, dynamic>());
            all.add(track);
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[LX:${_source.name}] 导入歌单 $key 失败: $e');
      }
    }
    return all;
  }

  // ── 工具方法 ──

  /// 从 JS 对象解析 MusicTrack（保留原始数据用于后续播放URL/歌词）
  ///
  /// 支持三类形状：
  /// - 单曲：{ id, name, singer, ... }
  /// - 专辑/歌单：{ id, name, picUrl, ... }（无播放能力，仅用于展示/详情）
  MusicTrack _trackFromJs(Map<dynamic, dynamic> item, String sourceKey,
      {String? rawData}) {
    final map = item.cast<String, dynamic>();

    // 专辑搜索：网易云格式 { album: { id, name, picUrl }, artist: { name } }
    final albumObj = map['album'];
    if (albumObj is Map) {
      final albumMap = albumObj.cast<String, dynamic>();
      final artistName = _artistName(map['artist']);
      return MusicTrack(
        id: (albumMap['id'] ?? map['id'] ?? '').toString(),
        title: (albumMap['name'] ?? map['name'] ?? '').toString(),
        artist: artistName,
        album: albumMap['name']?.toString(),
        coverUrl:
            (albumMap['picUrl'] ?? albumMap['pic'] ?? map['picUrl'])?.toString(),
        sourceId: _source.id,
        sourceKey: sourceKey,
        rawData: rawData ?? jsonEncode(map),
      );
    }

    return MusicTrack(
      id: (map['id'] ?? map['musicId'] ?? map['songmid'] ?? map['hash'] ?? '')?.toString() ?? '',
      title: (map['name'] ?? map['title'] ?? map['songname'] ?? map['SongName'] ?? '')?.toString() ?? '',
      artist: _artistName(map['artist'] ?? map['singer'] ?? map['author'] ?? map['SingerName']),
      album: (map['album'] ?? map['albumname'] ?? map['AlbumName'])?.toString(),
      coverUrl: (map['albumCover'] ?? map['pic'] ?? map['img'] ?? map['cover'] ?? map['album_pic'] ?? map['picUrl'])?.toString(),
      durationMs: _parseSongDuration(map),
      sourceId: _source.id,
      sourceKey: sourceKey,
      lyricId: map['lyricId']?.toString(),
      rawData: rawData ?? jsonEncode(map),
    );
  }

  /// 从 artist/singer 字段提取歌手名（兼容 String / Map{name} / List<Map{name}>）
  String _artistName(dynamic artist) {
    if (artist == null) return '';
    if (artist is String) return artist;
    if (artist is Map) return (artist['name'] ?? '').toString();
    if (artist is List) {
      return artist
          .whereType<Map>()
          .map((a) => (a['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .join('/');
    }
    return artist.toString();
  }

  /// 时长解析：duration 为毫秒，interval 为秒（lx 标准）
  int? _parseSongDuration(Map<String, dynamic> map) {
    final d = map['duration'];
    if (d != null) return _parseDuration(d);
    final itv = map['interval'];
    if (itv != null) {
      final sec = _parseDuration(itv);
      if (sec != null) return sec * 1000;
    }
    return null;
  }

  /// 从 JS 对象解析榜单/歌单条目（lx 标准 list 返回值）
  MusicListInfo _listFromJs(Map<String, dynamic> map, String sourceKey) {
    return MusicListInfo(
      id: (map['id'] ?? map['listId'] ?? map['disstid'] ?? '')?.toString() ?? '',
      title: (map['name'] ?? map['title'] ?? map['listName'] ?? map['dissname'] ?? '')?.toString() ?? '',
      picUrl: (map['pic'] ?? map['picUrl'] ?? map['cover'] ?? map['coverImgUrl'] ?? map['imgUrl'])?.toString(),
      songCount: _parseDuration(map['songCount'] ?? map['count'] ?? map['musicNum'] ?? map['songnum']),
      sourceId: _source.id,
      sourceKey: sourceKey,
      rawData: jsonEncode(map),
    );
  }

  /// 构造传给 JS 的 song 对象 JSON
  /// 优先用搜索时保存的原始数据（字段最完整），否则用 track 字段兜底
  String _songJson(MusicTrack track) {
    if (track.rawData != null && track.rawData!.isNotEmpty) {
      return track.rawData!;
    }
    return jsonEncode({
      'id': track.id,
      'name': track.title,
      'singer': track.artist,
      'album': track.album,
      'album_pic': track.coverUrl,
      'source': track.sourceId,
    });
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
    // 执行源脚本
    $scriptSource

    // 兼容 module.exports 老格式（module 已在运行时注入后重置为空对象）
    if (!__initialized && typeof module !== 'undefined' && module.exports && typeof module.exports === 'object') {
      var exp = module.exports;
      // 排除 CryptoJS 之类被误挂到 module.exports 的库
      if (exp && (exp.MD5 || exp.AES || exp.enc)) return;
      var supportedActions = [];

      if (typeof exp.search === 'function') supportedActions.push('search');
      if (typeof exp.getMusicUrl === 'function' || typeof exp.handleGetMusicUrl === 'function') supportedActions.push('musicUrl');
      if (typeof exp.getLyric === 'function' || typeof exp.handleGetMusicLyric === 'function') supportedActions.push('lyric');
      if (typeof exp.getPic === 'function') supportedActions.push('pic');
      if (typeof exp.getMusicInfo === 'function') supportedActions.push('getMusicInfo');
      if (typeof exp.list === 'function' || typeof exp.getList === 'function') supportedActions.push('list');
      if (typeof exp.listDetail === 'function' || typeof exp.getListDetail === 'function') supportedActions.push('listDetail');
      if (typeof exp.importList === 'function') supportedActions.push('importList');

      if (supportedActions.length > 0) {
        var sources = {};
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
            case 'getMusicInfo':
              return typeof exp.getMusicInfo === 'function' ? exp.getMusicInfo(req.musicInfo || req) : Promise.reject('unsupported');
            case 'list':
              return typeof exp.getList === 'function' ? exp.getList(req.page, req.type, req.limit) : exp.list(req.page, req.type, req.limit);
            case 'listDetail':
              return typeof exp.getListDetail === 'function' ? exp.getListDetail(req.listInfo, req.page, req.limit) : exp.listDetail(req.listInfo, req.page, req.limit);
            case 'importList':
              return typeof exp.importList === 'function' ? exp.importList(req.url || req.listInfo || req) : Promise.reject('unsupported');
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
    // quickjs_engine 的 sendMessage 通道会先 jsonDecode 一次再传给 handler
    if (args is String) {
      if (args.trim().isEmpty) return {};
      try {
        final decoded = jsonDecode(args);
        if (decoded is Map) return decoded.cast<String, dynamic>();
        return {'_raw': decoded};
      } catch (e) {
        return {'value': args};
      }
    }
    if (args is Map<String, dynamic>) return args;
    if (args is Map) {
      final result = <String, dynamic>{};
      for (final entry in args.entries) {
        result[entry.key.toString()] = entry.value;
      }
      return result;
    }
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
  @override
  void dispose() {
    _searchCache.clear();
    _runtime?.dispose();
    _runtime = null;
    _loaded = false;
    _initialized = false;
    _capabilities = {};
  }
}
