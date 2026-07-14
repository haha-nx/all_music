import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_js/flutter_js.dart';
import '../models/song.dart';
import '../models/source_type.dart';
import '../models/music_source.dart';
import '../utils/http_client.dart';
import '../services/platform_api.dart';

/// LX Music 源脚本引擎
///
/// 使用 flutter_js (QuickJS) 在 App 内直接执行 JS 源脚本。
/// 桥接 httpFetch 使 JS 脚本可以发起 HTTP 请求。
class SourceEngine {
  final MusicSource _source;
  final PlatformApi _platformApi = PlatformApi();
  JavascriptRuntime? _runtime;
  bool _loaded = false;
  String? _lastError;
  Map<String, dynamic>? _diagnostics;
  final List<Map<String, dynamic>> _httpCallLog = [];

  SourceEngine(this._source);

  bool get isLoaded => _loaded;
  String? get lastError => _lastError;

  /// 运行时诊断信息（脚本加载后生成的全局变量 dump + HTTP 调用日志）
  Map<String, dynamic>? get diagnostics => _diagnostics;

  /// HTTP 请求调用日志（每次 httpFetch 调用都会记录）
  List<Map<String, dynamic>> get httpCallLog => List.unmodifiable(_httpCallLog);

  /// 初始化引擎并加载 JS 源脚本
  Future<bool> init() async {
    if (_loaded) return true;
    if (_source.scriptSource == null || _source.scriptSource!.isEmpty) {
      _lastError = '源脚本内容为空';
      return false;
    }

    try {
      _runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);
      _httpCallLog.clear();

      // 注入 LX Music 运行时环境
      await _injectRuntime();

      // 执行源脚本
      final JsEvalResult result = await _runtime!.evaluateAsync(
        _source.scriptSource!,
        sourceUrl: 'source://${_source.id}',
      );

      // 处理可能的 Promise 返回
      _runtime!.executePendingJob();
      await _runtime!.handlePromise(result);

      _loaded = true;
      _lastError = null;

      // 诊断：枚举所有全局变量，帮助发现混淆脚本中的实际函数名和 API 端点
      try {
        final diagResult = await _runtime!.evaluateAsync(r'''
          (() => {
            const items = [];
            for (const k in globalThis) {
              if (k === 'globalThis' || k === 'window' || k === 'self') continue;
              try {
                const v = globalThis[k];
                const t = typeof v;
                if (t === 'function') {
                  items.push({name: k, type: 'function'});
                } else if (t === 'string' && v.length < 500) {
                  items.push({name: k, type: 'string', preview: v});
                } else if (t === 'object' && v !== null && !Array.isArray(v)) {
                  const keys = Object.keys(v).filter(kk => typeof v[kk] === 'function');
                  if (keys.length > 0) {
                    items.push({name: k, type: 'object', methods: keys});
                  }
                }
              } catch(e) {}
            }
            return JSON.stringify(items);
          })()
        ''');
        _runtime!.executePendingJob();
        final diagResolved = await _runtime!.handlePromise(diagResult);
        final diagItems = jsonDecode(diagResolved.stringResult) as List;
        _diagnostics = {
          'globalVars': diagItems,
          'functionNames': diagItems
              .where((item) => item['type'] == 'function')
              .map((item) => item['name'])
              .toList(),
          'stringVars': diagItems
              .where((item) => item['type'] == 'string')
              .map((item) => {'name': item['name'], 'preview': item['preview']})
              .toList(),
          'httpCalls': _httpCallLog.toList(),
        };
        // 输出到调试控制台
        final funcNames = _diagnostics!['functionNames'] as List;
        final strVars = _diagnostics!['stringVars'] as List;
        // ignore: avoid_print
        print('═══════ JS 运行时诊断 ═══════');
        // ignore: avoid_print
        print('发现 ${funcNames.length} 个函数，${strVars.length} 个字符串变量');
        // ignore: avoid_print
        print('--- 函数列表（前30个） ---');
        for (final name in funcNames.take(30)) {
          // ignore: avoid_print
          print('  [func] $name');
        }
        // ignore: avoid_print
        print('--- 字符串变量 ---');
        for (final sv in strVars.take(20)) {
          // ignore: avoid_print
          print('  [str] ${sv['name']} = "${sv['preview']}"');
        }
        // ignore: avoid_print
        print('════════════════════════════');
      } catch (diagErr) {
        // ignore: avoid_print
        print('[诊断失败] $diagErr');
      }

      return true;
    } catch (e) {
      _lastError = 'JS 引擎初始化失败: $e';
      return false;
    }
  }

  /// 注入 LX Music 运行环境（httpFetch、MUSIC_SOURCE 等）
  Future<void> _injectRuntime() async {
    final dio = MusicHttpClient().dio;

    // 注入 httpFetch —— LX Music 源的网络请求接口
    _runtime!.onMessage('httpFetch', (dynamic args) async {
      try {
        final params = args as Map<String, dynamic>;
        final url = params['url'] as String;
        final method = (params['method'] as String?)?.toUpperCase() ?? 'GET';
        final headers =
            (params['headers'] as Map?)?.cast<String, String>() ?? {};
        final body = params['body'];

        final response = await dio.request(
          url,
          data: body,
          options: Options(
            method: method,
            headers: headers,
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
          ),
        );

        // 记录 HTTP 调用日志
        _httpCallLog.add({
          'url': url,
          'method': method,
          'statusCode': response.statusCode,
          'bodyLength': response.data?.toString().length ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        });

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

    // 基础 Web API polyfill + LX Music 运行时
    await _runtime!.evaluateAsync(r'''
      // ======== Web API polyfills ========

      // atob / btoa (Base64)
      if (typeof atob === 'undefined') {
        globalThis.atob = function(s) {
          const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
          let result = '';
          let i = 0;
          s = s.replace(/[^A-Za-z0-9+/=]/g, '');
          while (i < s.length) {
            const e = chars.indexOf(s[i++]);
            const n = chars.indexOf(s[i++]);
            const r = chars.indexOf(s[i++]);
            const o = chars.indexOf(s[i++]);
            result += String.fromCharCode((e << 2) | (n >> 4));
            if (r !== 64) result += String.fromCharCode(((n & 15) << 4) | (r >> 2));
            if (o !== 64) result += String.fromCharCode(((r & 3) << 6) | o);
          }
          return result;
        };
        globalThis.btoa = function(s) {
          const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
          let result = '';
          for (let i = 0; i < s.length; i += 3) {
            const a = s.charCodeAt(i);
            const b = s.charCodeAt(i + 1);
            const c = s.charCodeAt(i + 2);
            result += chars[a >> 2];
            result += chars[((a & 3) << 4) | ((b >> 4) & 15)];
            result += (i + 1 < s.length) ? chars[((b & 15) << 2) | ((c >> 6) & 3)] : '=';
            result += (i + 2 < s.length) ? chars[c & 63] : '=';
          }
          return result;
        };
      }

      // TextEncoder / TextDecoder
      if (typeof TextEncoder === 'undefined') {
        globalThis.TextEncoder = function() {};
        globalThis.TextEncoder.prototype.encode = function(s) {
          const arr = new Uint8Array(s.length);
          for (let i = 0; i < s.length; i++) arr[i] = s.charCodeAt(i) & 0xFF;
          return arr;
        };
        globalThis.TextDecoder = function() {};
        globalThis.TextDecoder.prototype.decode = function(arr) {
          let s = '';
          for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
          return s;
        };
      }

      // ======== LX Music 运行时 ========

      // httpFetch — 通过 Dart 桥接发起 HTTP 请求
      globalThis.httpFetch = async function(url, options) {
        options = options || {};
        if (options.headers) {
          for (const k in options.headers) {
            if (Array.isArray(options.headers[k])) {
              options.headers[k] = options.headers[k].join(', ');
            }
          }
        }
        const result = await sendMessage('httpFetch', JSON.stringify({
          url: url,
          method: options.method || 'GET',
          headers: options.headers || {},
          body: options.body || null,
        }));
        return {
          statusCode: result.statusCode,
          statusMessage: result.statusMessage,
          headers: result.headers || {},
          body: result.body || '',
          json: function() { return JSON.parse(result.body || '{}'); },
          text: function() { return result.body || ''; },
          arrayBuffer: function() { return new Uint8Array(0).buffer; },
        };
      };

      // console.log -> print
      if (typeof console === 'undefined') globalThis.console = {};
    ''');

    // 注意：不能用 evaluateAsync 做 await，必须在 JS 侧发起，这里用 sendMessage 机制
  }

  // ══════════════════════════════════════════════
  // 音乐源方法
  // ══════════════════════════════════════════════
  //
  // LX Music 源脚本有两种模式：
  //   A) 对象模式：MUSIC_SOURCE = { search(), getMusicUrl(), getLyric() }  — 老格式
  //   B) 全局模式：MUSIC_SOURCE = "平台标识", 函数在顶层 (handleGetMusicUrl 等)
  //
  // 两种都需检测，且要排除 String.prototype 上的 JS 原生方法误判。

  /// 搜索歌曲
  Future<List<Song>> search(
    String keyword, {
    int page = 1,
    int limit = 20,
  }) async {
    if (!_loaded || _runtime == null) return [];

    try {
      // 1. 尝试对象模式 MUSIC_SOURCE.search()
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            if (typeof MUSIC_SOURCE === 'object' && MUSIC_SOURCE !== null && typeof MUSIC_SOURCE.search === 'function') {
              const songs = await MUSIC_SOURCE.search("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            // 2. 尝试全局 search / searchSong / searchMusic 函数
            if (typeof search === 'function') {
              const songs = await search("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            if (typeof searchSong === 'function') {
              const songs = await searchSong("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            if (typeof searchMusic === 'function') {
              const songs = await searchMusic("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            // 尝试 LX Music 全局模式常用函数名
            if (typeof handleSearchMusic === 'function') {
              const songs = await handleSearchMusic("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            if (typeof handleSearch === 'function') {
              const songs = await handleSearch("${_escapeJs(keyword)}", $page, $limit);
              return JSON.stringify({_type: 'songs', data: songs || []});
            }
            // 动态尝试 globalThis 中所有包含 "search" 的函数
            const searchFuncs = [];
            for (const k in globalThis) {
              if (typeof globalThis[k] === 'function' && k.toLowerCase().indexOf('search') >= 0) {
                searchFuncs.push(k);
              }
            }
            for (const fn of searchFuncs) {
              try {
                const songs = await globalThis[fn]("${_escapeJs(keyword)}", $page, $limit);
                if (songs && Array.isArray(songs) && songs.length > 0) {
                  return JSON.stringify({_type: 'songs', data: songs});
                }
              } catch(e) {}
            }
            // 3. 尝试通过 API 服务器搜索
            const apiInfo = {};
            if (typeof API_URL === 'string') apiInfo.apiUrl = API_URL;
            if (typeof API_KEY === 'string') apiInfo.apiKey = API_KEY;
            if (typeof MUSIC_SOURCE === 'string') apiInfo.sourceId = MUSIC_SOURCE;
            // 也检查其他可能的 URL 变量名
            if (!apiInfo.apiUrl) {
              for (const k in globalThis) {
                if (typeof globalThis[k] === 'string' && k.toLowerCase().indexOf('url') >= 0 && globalThis[k].length > 5) {
                  apiInfo.apiUrl = globalThis[k];
                  break;
                }
              }
            }
            return JSON.stringify({_type: 'api', apiInfo: apiInfo});
          } catch(e) {
            return JSON.stringify({_type: 'error', _error: e.message || String(e)});
          }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final data = jsonDecode(resolved.stringResult) as Map<String, dynamic>;

      if (data['_type'] == 'songs') {
        final songs = data['data'];
        if (songs is List) {
          return songs.map((item) => _songFromJs(item)).toList();
        }
        return [];
      }

      if (data['_type'] == 'error') {
        _lastError = data['_error'] as String;
        return [];
      }

      // _type == 'api': 通过 API 服务器搜索
      if (data['_type'] == 'api') {
        final apiInfo = (data['apiInfo'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        );
        if (apiInfo != null && apiInfo['apiUrl'] != null) {
          final apiResults = await _searchViaApiServer(keyword, apiInfo, page, limit);
          if (apiResults.isNotEmpty) return apiResults;
        }
        // API 服务器失败或没有 URL，fall through 到平台直接搜索
      }
    } catch (e) {
      _lastError = '搜索失败: $e';
    }

    // 最终回退：直接对接酷狗搜索（绕过失效的 LX Music API 服务器）
    print('[SourceEngine] API 搜索失败，回退到酷狗直接搜索');
    return await _platformApi.searchKugou(
      keyword,
      page: page,
      limit: limit,
      sourceId: _source.id,
    );
  }

  /// 通过 API 服务器搜索（HTTP fallback，使用 Dio 直连）
  Future<List<Song>> _searchViaApiServer(
    String keyword,
    Map<String, String> apiInfo,
    int page,
    int limit,
  ) async {
    final apiUrl = apiInfo['apiUrl'];
    if (apiUrl == null || apiUrl.isEmpty) {
      _lastError = '未找到 API_URL';
      return [];
    }

    final sourceId = apiInfo['sourceId'] ?? '';
    final dio = MusicHttpClient().dio;
    final log = <String>[];

    /// 记录调试日志
    void aLog(String msg) {
      log.add(msg);
      // ignore: avoid_print
      print('[API] $msg');
    }

    aLog('开始搜索: keyword="$keyword", apiUrl=$apiUrl, sourceId=${sourceId.isNotEmpty ? sourceId : "(无)"}');

    // 尝试多种 LX Music API 请求格式
    final attempts = <_ApiAttempt>[
      // 格式 1: POST /song/search (lx-music源服务器标准格式)
      _ApiAttempt(
        'POST /song/search',
        () => dio.post(
          '$apiUrl/song/search',
          data: _buildSearchBody(keyword, sourceId, page, limit),
          options: Options(
            headers: _apiHeaders(apiInfo),
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      ),
      // 格式 2: GET /song/search
      _ApiAttempt(
        'GET /song/search',
        () => dio.get(
          '$apiUrl/song/search',
          queryParameters: _buildQueryParams(keyword, sourceId, page, limit),
          options: Options(
            headers: _apiHeaders(apiInfo),
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      ),
      // 格式 3: POST /search（不指定 source）
      _ApiAttempt(
        'POST /search (不带source)',
        () => dio.post(
          '$apiUrl/search',
          data: {'keyword': keyword, 'page': page, 'limit': limit},
          options: Options(
            headers: _apiHeaders(apiInfo),
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      ),
      // 格式 4: GET /search
      _ApiAttempt(
        'GET /search',
        () => dio.get(
          '$apiUrl/search',
          queryParameters: {'keyword': keyword, 'page': page.toString(), 'limit': limit.toString()},
          options: Options(
            headers: _apiHeaders(apiInfo),
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      ),
    ];

    for (final attempt in attempts) {
      try {
        aLog('尝试 ${attempt.label}...');
        final response = await attempt.request();
        final status = response.statusCode ?? 0;
        final body = response.data;
        aLog('  → HTTP $status, body length: ${body?.toString().length ?? 0}');

        if (status >= 200 && status < 300 && body != null) {
          final songs = _parseApiResponse(body);
          if (songs.isNotEmpty) {
            aLog('  ✓ 成功！找到 ${songs.length} 首歌');
            return songs;
          }
          aLog('  → 响应正常但无法解析出歌曲列表');
          // 打印响应前200字符用于调试
          final preview = body.toString().substring(0, body.toString().length.clamp(0, 200));
          aLog('  → 响应预览: $preview');
        } else if (status >= 400) {
          aLog('  → 服务器返回 $status');
        }
      } catch (e) {
        aLog('  → 网络错误: $e');
      }
    }

    _lastError = 'API 搜索全部失败:\n${log.join('\n')}';
    return [];
  }

  /// 构建 POST 请求体
  Map<String, dynamic> _buildSearchBody(String keyword, String sourceId, int page, int limit) {
    final body = <String, dynamic>{
      'keyword': keyword,
      'page': page,
      'limit': limit,
    };
    if (sourceId.isNotEmpty) {
      body['source'] = sourceId;
    }
    return body;
  }

  /// 构建 GET 请求参数
  Map<String, String> _buildQueryParams(String keyword, String sourceId, int page, int limit) {
    final params = <String, String>{
      'keyword': keyword,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (sourceId.isNotEmpty) {
      params['source'] = sourceId;
    }
    return params;
  }

  /// 构建 API 请求头
  Map<String, String> _apiHeaders(Map<String, String> apiInfo) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final apiKey = apiInfo['apiKey'];
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-Api-Key'] = apiKey;
    }
    return headers;
  }

  /// 解析 API 响应中的歌曲列表
  List<Song> _parseApiResponse(dynamic body) {
    try {
      Map<String, dynamic> data;
      if (body is String) {
        data = jsonDecode(body) as Map<String, dynamic>;
      } else if (body is Map) {
        data = Map<String, dynamic>.from(body);
      } else {
        return [];
      }

      List? list;
      // 嵌套路径 data.data.list
      if (data['data'] is Map) {
        list = (data['data'] as Map)['list'] as List?;
      }
      // data.list
      list ??= data['list'] as List?;
      // data.songs
      list ??= data['songs'] as List?;
      // 直接是数组
      if (list == null && data['body'] != null) {
        // 某些 API 返回 { body: [...] }
        if (data['body'] is List) list = data['body'] as List?;
      }

      if (list != null && list.isNotEmpty) {
        return list.map((item) => _songFromJs(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 获取播放 URL
  Future<String?> getMusicUrl(Song song, {String quality = '128k'}) async {
    if (!_loaded || _runtime == null) return null;

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            // 对象模式: MUSIC_SOURCE 是 Object
            if (typeof MUSIC_SOURCE === 'object' && MUSIC_SOURCE !== null) {
              if (typeof MUSIC_SOURCE.handleGetMusicUrl === 'function') {
                return await MUSIC_SOURCE.handleGetMusicUrl({
                  musicId: "${_escapeJs(song.id)}",
                  quality: "$quality",
                  source: "${_escapeJs(song.sourceId ?? '')}",
                });
              }
              if (typeof MUSIC_SOURCE.getMusicUrl === 'function') {
                return await MUSIC_SOURCE.getMusicUrl({
                  id: "${_escapeJs(song.id)}",
                  source: "${_escapeJs(song.sourceId ?? '')}",
                }, "$quality");
              }
            }
            // 全局模式: 顶层函数
            if (typeof handleGetMusicUrl === 'function') {
              return await handleGetMusicUrl({
                musicId: "${_escapeJs(song.id)}",
                quality: "$quality",
                source: "${_escapeJs(song.sourceId ?? '')}",
              });
            }
            if (typeof getMusicUrl === 'function') {
              return await getMusicUrl({
                id: "${_escapeJs(song.id)}",
                source: "${_escapeJs(song.sourceId ?? '')}",
              }, "$quality");
            }
            return null;
          } catch(e) {
            return null;
          }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final url = resolved.stringResult;
      if (url.isNotEmpty && url != 'null') return url;

      // 回退：酷狗直接获取
      if (PlatformApi.isKugouHash(song.id)) {
        final hash = PlatformApi.extractHash(song.id);
        return await _platformApi.getKugouUrl(hash);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取歌词
  Future<String?> getLyric(Song song) async {
    if (!_loaded || _runtime == null) return null;

    try {
      final result = await _runtime!.evaluateAsync('''
        (async () => {
          try {
            // 对象模式: MUSIC_SOURCE 是 Object
            if (typeof MUSIC_SOURCE === 'object' && MUSIC_SOURCE !== null) {
              if (typeof MUSIC_SOURCE.handleGetMusicLyric === 'function') {
                const lrc = await MUSIC_SOURCE.handleGetMusicLyric({
                  musicId: "${_escapeJs(song.id)}",
                  source: "${_escapeJs(song.sourceId ?? '')}",
                });
                if (typeof lrc === 'string') return lrc;
                if (lrc && lrc.lyric) return lrc.lyric;
                return null;
              }
              if (typeof MUSIC_SOURCE.getLyric === 'function') {
                return await MUSIC_SOURCE.getLyric({
                  id: "${_escapeJs(song.id)}",
                  source: "${_escapeJs(song.sourceId ?? '')}",
                });
              }
            }
            // 全局模式: 顶层函数
            if (typeof handleGetMusicLyric === 'function') {
              const lrc = await handleGetMusicLyric({
                musicId: "${_escapeJs(song.id)}",
                source: "${_escapeJs(song.sourceId ?? '')}",
              });
              if (typeof lrc === 'string') return lrc;
              if (lrc && lrc.lyric) return lrc.lyric;
              return null;
            }
            if (typeof getLyric === 'function') {
              return await getLyric({
                id: "${_escapeJs(song.id)}",
                source: "${_escapeJs(song.sourceId ?? '')}",
              });
            }
            return null;
          } catch(e) {
            return null;
          }
        })()
      ''');

      _runtime!.executePendingJob();
      final resolved = await _runtime!.handlePromise(result);
      final lrc = resolved.stringResult;
      if (lrc.isNotEmpty && lrc != 'null') return lrc;

      // 回退：酷狗直接获取歌词
      if (PlatformApi.isKugouHash(song.id)) {
        final hash = PlatformApi.extractHash(song.id);
        return await _platformApi.getKugouLyricRaw(hash);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 工具方法
  // ══════════════════════════════════════════════

  /// 从 JS 对象解析 Song
  Song _songFromJs(dynamic item) {
    final m = item as Map<String, dynamic>;
    return Song(
      id:
          m['id']?.toString() ??
          m['musicId']?.toString() ??
          m['songmid']?.toString() ??
          '',
      source: SourceType.api,
      name:
          m['name']?.toString() ??
          m['title']?.toString() ??
          m['songname']?.toString() ??
          '',
      artist:
          m['artist']?.toString() ??
          m['singer']?.toString() ??
          m['author']?.toString() ??
          '',
      album: m['album']?.toString() ?? m['albumname']?.toString(),
      albumCover:
          m['albumCover']?.toString() ??
          m['pic']?.toString() ??
          m['img']?.toString(),
      duration: m['duration'] != null
          ? Duration(milliseconds: _parseDuration(m['duration']))
          : null,
      sourceId: _source.id,
    );
  }

  int _parseDuration(dynamic d) {
    if (d is int) return d;
    if (d is double) return d.toInt();
    return int.tryParse(d.toString()) ?? 0;
  }

  /// 转义字符串中的 JS 特殊字符
  String _escapeJs(String s) {
    return s
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  /// 释放引擎资源
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _loaded = false;
  }
}

/// API 请求尝试
class _ApiAttempt {
  final String label;
  final Future<Response> Function() request;

  const _ApiAttempt(this.label, this.request);
}
