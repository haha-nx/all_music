/// LX Music 脚本运行时环境
///
/// 提供 QuickJS 中运行 LX Music 源脚本所需的一切：
/// - Web API polyfills (atob, btoa, TextEncoder, etc.)
/// - CryptoJS（从 assets 加载真实库 —— 供音源做 AES/RSA 签名，如网易云 weapi）
/// - globalThis.lx API (send/on/request/sourceRegister/utils)
/// - httpFetch 桥接（JS → Dart Dio）
///
/// 这是一个 JS 字符串构建器，不包含任何业务逻辑。
import 'package:flutter/services.dart' show rootBundle;

class LxRuntime {
  LxRuntime._();

  /// 构建完整的 JS 运行时注入脚本（需异步加载 CryptoJS 资源）
  ///
  /// 执行顺序：polyfills → CryptoJS（真实库）→ normalize → lx API → httpFetch ...
  static Future<String> build() async {
    final cryptoJs = await rootBundle.loadString('assets/scripts/crypto-js.js');
    return [
      _polyfills,
      cryptoJs,
      _normalizeCryptoJs,
      _lxApi,
      _httpFetch,
      _console,
      _fetchPolyfill,
      _urlPolyfill,
    ].join('\n\n');
  }

  // ═══════════════════════════════════════════
  // Polyfills
  // ═════════════════════════════════════════

  static const String _polyfills = r'''
// ── Web API polyfills ──
if (typeof window === 'undefined') globalThis.window = globalThis;
if (typeof self === 'undefined') globalThis.self = globalThis;
if (typeof navigator === 'undefined')
  globalThis.navigator = { userAgent: 'Mozilla/5.0 (Linux; Android 10) Chrome/120' };
if (typeof module === 'undefined') globalThis.module = { exports: {} };
if (typeof exports === 'undefined') globalThis.exports = globalThis.module.exports;
if (typeof global === 'undefined') globalThis.global = globalThis;
if (typeof __dirname === 'undefined') globalThis.__dirname = '/';
if (typeof __filename === 'undefined') globalThis.__filename = 'source.js';

if (typeof process === 'undefined') {
  globalThis.process = {
    env: {}, version: '', platform: 'android', argv: [],
    cwd: function() { return '/'; },
    nextTick: function(fn) { Promise.resolve().then(fn); },
  };
}
if (typeof require === 'undefined') {
  globalThis.require = function(name) { return {}; };
}
if (typeof Buffer === 'undefined') {
  globalThis.Buffer = {
    from: function(arr) { return new Uint8Array(arr); },
    alloc: function(size) { return new Uint8Array(size); },
    isBuffer: function() { return false; },
  };
}
if (typeof setTimeout === 'undefined') {
  globalThis.setTimeout = function(fn, ms) { fn(); return 0; };
  globalThis.clearTimeout = function() {};
}
if (typeof setInterval === 'undefined') {
  globalThis.setInterval = function(fn, ms) { fn(); return 0; };
  globalThis.clearInterval = function() {};
}

// atob / btoa
if (typeof atob === 'undefined') {
  globalThis.atob = function(s) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
    let result = '', i = 0;
    s = s.replace(/[^A-Za-z0-9+/=]/g, '');
    while (i < s.length) {
      const e = chars.indexOf(s[i++]), n = chars.indexOf(s[i++]),
            r = chars.indexOf(s[i++]), o = chars.indexOf(s[i++]);
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
      const a = s.charCodeAt(i), b = s.charCodeAt(i + 1), c = s.charCodeAt(i + 2);
      result += chars[a >> 2] + chars[((a & 3) << 4) | ((b >> 4) & 15)];
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

if (typeof Promise === 'undefined')
  globalThis.Promise = function(fn) { fn(function() {}, function() {}); };
''';

  // ═══════════════════════════════════════════
  // CryptoJS normalize
  // ═════════════════════════════════════════

  /// CryptoJS 是 UMD 包：在定义了 module/exports 的环境（如 QuickJS polyfill）里
  /// 会走 CommonJS 分支，把库挂到 module.exports 而非全局。这里归位到 globalThis.CryptoJS。
  static const String _normalizeCryptoJs = r'''
if (typeof globalThis.CryptoJS === 'undefined') {
  globalThis.CryptoJS = (typeof module !== 'undefined' && module.exports)
    ? module.exports
    : (typeof CryptoJS !== 'undefined' ? CryptoJS : {});
}
// crypto-js 的 UMD 把库挂到了 module.exports。若不重置，后续源脚本若也用
// module.exports 导出（如标准 LX 源 await 写法），会被误判为「音源导出对象」。
// 这里在已捕获 CryptoJS 到 globalThis 后，把 module/exports 还原为空对象。
if (typeof globalThis.module !== 'undefined') globalThis.module = { exports: {} };
if (typeof globalThis.exports !== 'undefined') globalThis.exports = globalThis.module.exports;
''';

  // ═══════════════════════════════════════════
  // LX Music API
  // ═════════════════════════════════════════

  static const String _lxApi = r'''
// ── globalThis.lx — LX Music 源脚本桥接 API ──

var __requestHandlers = {};
var __lxSources = {};
var __initialized = false;

function __sendInited(data) {
  if (__initialized) return;
  __initialized = true;
  sendMessage('lx', JSON.stringify({ type: 'inited', data: data }));
}

if (typeof globalThis.lx === 'undefined') {
  globalThis.lx = {
    EVENT_NAMES: {
      inited: 'inited',
      request: 'request',
      updateAlert: 'updateAlert',
    },
    version: '2.0.0',
    env: 'mobile',
    currentScriptInfo: {},
    sources: {},

    // 兼容双签名：lx.send(eventName, data) 或 lx.send({ type/log/... })
    send: function(eventName, data) {
      var ev, dt;
      if (eventName !== null && typeof eventName === 'object') {
        ev = eventName.type || eventName.event || (eventName.log ? 'log' : 'object');
        dt = eventName;
      } else {
        ev = eventName; dt = data;
      }
      sendMessage('lx', JSON.stringify({ type: 'send', event: ev, data: dt }));
    },

    on: function(eventName, handler) {
      if (eventName === globalThis.lx.EVENT_NAMES.request) {
        __requestHandlers['_global'] = handler;
      }
    },

    // lx.request(url, options) — HTTP 请求，返回 Promise<{statusCode,headers,body}>
    request: function(url, options) {
      var opts = options || {};
      if (typeof url === 'object') { opts = url; url = opts.url || ''; }
      var method = opts.method || 'GET';
      var headers = opts.headers || {};
      var body = opts.body || opts.data || null;

      for (var k in headers) {
        if (Array.isArray(headers[k])) headers[k] = headers[k].join(', ');
      }

      return new Promise(function(resolve, reject) {
        httpFetch(url, { method: method, headers: headers, body: body })
          .then(function(result) {
            var rawBody = result.body || '';
            var parsedBody = rawBody;
            if (typeof rawBody === 'string' && rawBody.length > 0) {
              try { parsedBody = JSON.parse(rawBody); } catch (e) {}
            }
            resolve({ statusCode: result.statusCode, headers: result.headers || {}, body: parsedBody });
            // callback 兼容（旧风格）
            var cb = opts.callback;
            if (typeof cb === 'function') {
              try { cb(result.statusCode < 0 ? result.statusMessage : null, { statusCode: result.statusCode, body: parsedBody }); } catch (e) {}
            }
          })
          .catch(function(e) { reject(e); });
      });
    },

    // 标准 LX 音源注册入口（新版契约）
    sourceRegister: function(source) {
      if (!source) return;
      __lxSources[source.name] = source;
      var actions = [];
      if (source.music) {
        if (typeof source.music.search === 'function') actions.push('search');
        if (typeof source.music.musicUrl === 'function') actions.push('musicUrl');
        if (typeof source.music.lyric === 'function') actions.push('lyric');
        if (typeof source.music.getMusicInfo === 'function') actions.push('getMusicInfo');
        if (typeof source.music.list === 'function') actions.push('list');
        if (typeof source.music.listDetail === 'function') actions.push('listDetail');
        if (typeof source.music.importList === 'function') actions.push('importList');
      }
      sendMessage('lx', JSON.stringify({
        type: 'sourceRegister',
        data: {
          name: source.name,
          type: source.type || 'music',
          actions: actions,
          hasMusic: !!source.music,
          listTypes: (source.listTypes || []).map(function(t) {
            return typeof t === 'string' ? { name: t, type: t } : { name: t.name, type: t.type };
          }),
        },
      }));
    },

    utils: {
      atob: function(s) { return globalThis.atob ? globalThis.atob(s) : s; },
      btoa: function(s) { return globalThis.btoa ? globalThis.btoa(s) : s; },
      crypto: {
        md5: function(str) {
          return (typeof CryptoJS !== 'undefined' && CryptoJS.MD5)
            ? CryptoJS.MD5(String(str)).toString()
            : String(str);
        },
      },
    },
  };
}
''';

  // ═══════════════════════════════════════════
  // httpFetch bridge
  // ═════════════════════════════════════════

  static const String _httpFetch = r'''
// ── httpFetch — JS → Dart HTTP 桥接 ──
globalThis.httpFetch = async function(url, options) {
  options = options || {};
  if (options.headers) {
    for (const k in options.headers) {
      if (Array.isArray(options.headers[k]))
        options.headers[k] = options.headers[k].join(', ');
    }
  }
  var rawResult = await sendMessage('http', JSON.stringify({
    url: url,
    method: options.method || 'GET',
    headers: options.headers || {},
    body: options.body || options.data || null,
  }));

  var result;
  if (typeof rawResult === 'string') {
    try { result = JSON.parse(rawResult); } catch(e) { result = { statusCode: -1, body: rawResult }; }
  } else {
    result = rawResult || {};
  }

  return {
    statusCode: result.statusCode || -1,
    statusMessage: result.statusMessage || '',
    headers: result.headers || {},
    body: result.body || '',
    json: function() { return JSON.parse(result.body || '{}'); },
    text: function() { return result.body || ''; },
    arrayBuffer: function() { return new Uint8Array(0).buffer; },
  };
};
''';

  // ═══════════════════════════════════════════
  // Console
  // ═════════════════════════════════════════

  static const String _console = r'''
// ── console — 转发到 Dart ──
if (typeof console === 'undefined') {
  function __fmt(args) {
    var parts = [];
    for (var i = 0; i < args.length; i++) {
      try { parts.push(typeof args[i] === 'object' ? JSON.stringify(args[i]) : String(args[i])); }
      catch(e) { parts.push(String(args[i])); }
    }
    return parts.join(' ');
  }
  globalThis.console = {
    log: function() { sendMessage('log', __fmt(arguments)); },
    error: function() { sendMessage('log', '[ERR] ' + __fmt(arguments)); },
    warn: function() { sendMessage('log', '[WRN] ' + __fmt(arguments)); },
    info: function() { sendMessage('log', '[INF] ' + __fmt(arguments)); },
    debug: function() { sendMessage('log', '[DBG] ' + __fmt(arguments)); },
  };
}
''';

  // ═══════════════════════════════════════════
  // Fetch polyfill
  // ═════════════════════════════════════════

  static const String _fetchPolyfill = r'''
// ── fetch API polyfill ──
if (typeof fetch === 'undefined') {
  globalThis.fetch = function(url, options) {
    return httpFetch(url, {
      method: (options && options.method) || 'GET',
      headers: (options && options.headers) || {},
      body: (options && options.body) || null,
    }).then(function(resp) {
      return {
        ok: resp.statusCode >= 200 && resp.statusCode < 300,
        status: resp.statusCode,
        statusText: resp.statusMessage || '',
        headers: resp.headers || {},
        text: function() { return Promise.resolve(resp.body || ''); },
        json: function() {
          try { return Promise.resolve(JSON.parse(resp.body || '{}')); }
          catch(e) { return Promise.reject(e); }
        },
        arrayBuffer: function() { return Promise.resolve(new Uint8Array(0).buffer); },
      };
    });
  };
}
''';

  // ═══════════════════════════════════════════
  // URL polyfill
  // ═════════════════════════════════════════

  static const String _urlPolyfill = r'''
// ── URL polyfill ──
if (typeof URL === 'undefined') {
  globalThis.URL = function(url, base) {
    this.href = url; this.origin = ''; this.protocol = '';
    this.host = ''; this.pathname = ''; this.search = ''; this.hash = '';
    try {
      if (url.indexOf('//') >= 0) {
        var parts = url.split('://');
        this.protocol = parts[0] + ':';
        var rest = parts[1] || '';
        var slashIdx = rest.indexOf('/');
        if (slashIdx >= 0) {
          this.host = rest.substring(0, slashIdx);
          this.pathname = rest.substring(slashIdx);
        } else {
          this.host = rest;
          this.pathname = '/';
        }
        this.origin = this.protocol + '//' + this.host;
      }
    } catch(e) {}
  };
}
''';
}
