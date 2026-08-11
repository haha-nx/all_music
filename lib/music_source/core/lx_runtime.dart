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
// ── 真实异步定时器 ──
// 与官方 lx-music-mobile 一致（原生定时器），避免同步假定时器导致的
// 死循环（如混淆脚本的 setInterval 自检递归）与语义错误。
var __timerSeq = 0;
var __timerMap = {};
function __scheduleTimer(id, ms, interval) {
  try { sendMessage('timer', JSON.stringify({ id: id, ms: ms, interval: interval })); } catch (e) {}
}
if (typeof setTimeout === 'undefined') {
  globalThis.setTimeout = function(fn, ms) {
    var id = ++__timerSeq;
    __timerMap[id] = { fn: fn, interval: false };
    __scheduleTimer(id, (typeof ms === 'number' && ms > 0) ? ms : 0, false);
    return id;
  };
  globalThis.clearTimeout = function(id) { delete __timerMap[id]; };
}
if (typeof setInterval === 'undefined') {
  globalThis.setInterval = function(fn, ms) {
    var id = ++__timerSeq;
    __timerMap[id] = { fn: fn, interval: true };
    __scheduleTimer(id, (typeof ms === 'number' && ms > 0) ? ms : 0, true);
    return id;
  };
  globalThis.clearInterval = function(id) { delete __timerMap[id]; };
}
// Dart 侧 Future.delayed 到期后调用
globalThis.__timerFire = function(id) {
  var t = __timerMap[id];
  if (!t) return;
  if (t.interval) {
    try { t.fn(); } catch (e) { if (typeof console !== 'undefined' && console.error) console.error(e); }
    __scheduleTimer(id, t.ms, true);
  } else {
    delete __timerMap[id];
    try { t.fn(); } catch (e) { if (typeof console !== 'undefined' && console.error) console.error(e); }
  }
};

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

// 脚本头元信息（@name/@version/@description 等），由 Dart 侧在源脚本执行前注入
var __scriptInfo = {};

// ── 字节工具（utils.buffer 的辅助实现）──
function __bytesToString(bytes, enc) {
  enc = enc || 'utf8';
  if (enc === 'base64') {
    var bin = '';
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return (typeof btoa === 'function') ? btoa(bin) : bin;
  }
  if (enc === 'hex') {
    var hex = '';
    for (var i = 0; i < bytes.length; i++) {
      var h = bytes[i].toString(16);
      hex += (bytes[i] < 16 ? '0' : '') + h;
    }
    return hex;
  }
  var s = '';
  for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return s;
}

function __stringToBytes(str, enc) {
  enc = enc || 'utf8';
  if (enc === 'base64') {
    var bin = (typeof atob === 'function') ? atob(String(str)) : String(str);
    var b1 = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) b1[i] = bin.charCodeAt(i) & 0xFF;
    return b1;
  }
  if (enc === 'hex') {
    var s = String(str);
    var b2 = new Uint8Array(Math.floor(s.length / 2));
    for (var j = 0; j < b2.length; j++) b2[j] = parseInt(s.substr(j * 2, 2), 16) & 0xFF;
    return b2;
  }
  var b3 = new Uint8Array(String(str).length);
  for (var k = 0; k < b3.length; k++) b3[k] = String(str).charCodeAt(k) & 0xFF;
  return b3;
}

// BigInt 模幂（RSA 用）
function __modPow(base, exp, mod) {
  var result = 1n;
  base = base % mod;
  while (exp > 0n) {
    if (exp & 1n) result = (result * base) % mod;
    base = (base * base) % mod;
    exp >>= 1n;
  }
  return result;
}

function __bigIntFromBytes(bytes) {
  var hex = __bytesToString(bytes, 'hex');
  return BigInt('0x' + (hex || '0'));
}

function __bytesFromBigInt(v, len) {
  var hex = v.toString(16);
  while (hex.length < len * 2) hex = '0' + hex;
  return __stringToBytes(hex, 'hex');
}

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
    currentScriptInfo: __scriptInfo,
    sources: {},

    // 兼容双签名：lx.send(eventName, data) 或 lx.send({ type/log/... })
    // 与官方契约一致：返回 Promise
    send: function(eventName, data) {
      var ev, dt;
      if (eventName !== null && typeof eventName === 'object') {
        ev = eventName.type || eventName.event || (eventName.log ? 'log' : 'object');
        dt = eventName;
      } else {
        ev = eventName; dt = data;
      }
      if (ev === 'inited') {
        __sendInited(dt);
        return Promise.resolve();
      }
      return Promise.resolve(sendMessage('lx', JSON.stringify({ type: 'send', event: ev, data: dt })));
    },

    on: function(eventName, handler) {
      if (eventName === globalThis.lx.EVENT_NAMES.request) {
        __requestHandlers['_global'] = handler;
      }
      return Promise.resolve();
    },

    // lx.request(url, options, callback) — 与官方 lx-music-mobile 契约一致：
    //   - 第三参 callback(err, {statusCode,statusMessage,headers,body}, body)
    //   - 返回 abort 函数；同时附加 then/catch/finally 兼容 Promise 用法
    //   - body 自动 JSON.parse（失败保留原字符串），binary 选项跳过解析
    request: function(url, options, callback) {
      var opts = options || {};
      if (typeof url === 'object') { opts = url; url = opts.url || ''; }
      if (opts === null || typeof opts !== 'object') opts = {};
      if (typeof callback !== 'function' && typeof opts.callback === 'function') {
        callback = opts.callback;
      }
      var method = opts.method || 'GET';
      var headers = opts.headers || {};
      var body = opts.body || opts.data || null;

      // 官方契约：options.form = {k:v} → application/x-www-form-urlencoded
      if (opts.form && typeof opts.form === 'object') {
        var parts = [];
        for (var fk in opts.form) {
          if (opts.form[fk] !== undefined && opts.form[fk] !== null) {
            parts.push(encodeURIComponent(fk) + '=' + encodeURIComponent(opts.form[fk]));
          }
        }
        body = parts.join('&');
        if (!headers['Content-Type']) {
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      }

      for (var k in headers) {
        if (Array.isArray(headers[k])) headers[k] = headers[k].join(', ');
      }

      var promise = httpFetch(url, { method: method, headers: headers, body: body })
        .then(function(result) {
          var rawBody = result.body;
          var parsed = rawBody;
          if (typeof rawBody === 'string' && rawBody !== '' && !opts.binary) {
            try { parsed = JSON.parse(rawBody); } catch (e) { parsed = rawBody; }
          }
          var response = {
            statusCode: result.statusCode,
            statusMessage: result.statusMessage || '',
            headers: result.headers || {},
            body: parsed,
          };
          // Log non-2xx responses for debugging
          if (response.statusCode > 0 && (response.statusCode < 200 || response.statusCode >= 300)) {
            console.error('[lx.request] ' + method + ' ' + url + ' => ' + response.statusCode + ' body=' + String(parsed).substring(0, 200));
          }
          if (typeof callback === 'function') {
            try { callback(null, response, parsed); } catch (e) { console.error('[lx.request callback]', e); }
          }
          return response;
        }, function(err) {
          if (typeof callback === 'function') {
            try { callback(err, null, null); } catch (e) { console.error('[lx.request callback]', e); }
            return { statusCode: -1, statusMessage: String((err && err.message) || err), headers: {}, body: null };
          }
          throw err;
        });

      // 官方契约返回 abort 函数；附加 then/catch/finally 兼容 Promise 风格
      var abort = function() {};
      abort.then = promise.then.bind(promise);
      abort.catch = promise.catch.bind(promise);
      if (promise.finally) abort.finally = promise.finally.bind(promise);
      return abort;
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

      // 字节缓冲（lx 标准：utils.buffer.from / toBuffer / bufToString）
      buffer: {
        from: function(data, encoding) {
          var bytes = (data instanceof Uint8Array)
            ? data
            : __stringToBytes(data, encoding);
          bytes.toString = function(enc) { return __bytesToString(bytes, enc); };
          return bytes;
        },
        toBuffer: function(data) {
          if (data instanceof Uint8Array) {
            data.toString = function(enc) { return __bytesToString(data, enc); };
            return data;
          }
          return globalThis.lx.utils.buffer.from(data);
        },
        // 洛雪系源（六音等）依赖的扩展方法：字节 → 字符串
        bufToString: function(buf, encoding) {
          if (!buf) return '';
          if (typeof buf.toString === 'function' && !(buf instanceof Uint8Array)) {
            return buf.toString(encoding);
          }
          return __bytesToString(buf, encoding);
        },
      },

      crypto: {
        md5: function(str) {
          return (typeof CryptoJS !== 'undefined' && CryptoJS.MD5)
            ? CryptoJS.MD5(String(str)).toString()
            : String(str);
        },

        // AES 加密：key/iv 为 base64，返回 base64；有 iv 走 CBC，否则 ECB
        aesEncrypt: function(str, key, iv) {
          if (typeof CryptoJS === 'undefined' || !CryptoJS.AES) return '';
          try {
            var k = CryptoJS.enc.Base64.parse(key || '');
            var opt = { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 };
            if (iv) {
              opt.iv = CryptoJS.enc.Base64.parse(iv);
              opt.mode = CryptoJS.mode.CBC;
            }
            return CryptoJS.AES.encrypt(String(str), k, opt).toString();
          } catch (e) { return ''; }
        },

        // AES 解密：key/iv 为 base64，密文为 base64，返回 utf8 明文
        aesDecrypt: function(str, key, iv) {
          if (typeof CryptoJS === 'undefined' || !CryptoJS.AES) return '';
          try {
            var k = CryptoJS.enc.Base64.parse(key || '');
            var opt = { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 };
            if (iv) {
              opt.iv = CryptoJS.enc.Base64.parse(iv);
              opt.mode = CryptoJS.mode.CBC;
            }
            return CryptoJS.AES.decrypt(String(str), k, opt)
                .toString(CryptoJS.enc.Utf8);
          } catch (e) { return ''; }
        },

        // RSA 加密（PKCS#1 v1.5）：modulus/exponent 为 base64，返回 base64
        rsaEncrypt: function(str, modulus, exponent) {
          try {
            var nBytes = __stringToBytes(modulus, 'base64');
            var eBytes = __stringToBytes(exponent, 'base64');
            if (nBytes.length === 0 || eBytes.length === 0) return '';
            var n = __bigIntFromBytes(nBytes);
            var e = __bigIntFromBytes(eBytes);
            var k = nBytes.length;

            var msg = __stringToBytes(str, 'utf8');
            if (msg.length > k - 11) return '';

            // EB = 00 02 PS 00 M
            var psLen = k - msg.length - 3;
            var eb = new Uint8Array(k);
            eb[0] = 0x00; eb[1] = 0x02;
            for (var i = 0; i < psLen; i++) eb[2 + i] = 1 + Math.floor(Math.random() * 255);
            eb[2 + psLen] = 0x00;
            for (var j = 0; j < msg.length; j++) eb[3 + psLen + j] = msg[j];

            var m = __bigIntFromBytes(eb);
            var c = __modPow(m, e, n);
            return __bytesToString(__bytesFromBigInt(c, k), 'base64');
          } catch (e) { return ''; }
        },

        // RC4 加密：返回 hex
        rc4: function(str, key) {
          if (typeof CryptoJS === 'undefined' || !CryptoJS.RC4) return '';
          try {
            return CryptoJS.RC4.encrypt(String(str), String(key))
                .ciphertext.toString(CryptoJS.enc.Hex);
          } catch (e) { return ''; }
        },

        // 随机字节（len 字节，返回带 toString 的 Uint8Array）
        randomBytes: function(len) {
          var bytes = new Uint8Array(len);
          for (var i = 0; i < len; i++) bytes[i] = Math.floor(Math.random() * 256);
          bytes.toString = function(enc) { return __bytesToString(bytes, enc); };
          return bytes;
        },

        // 随机 hex（len 字节）
        getRandom: function(len) {
          var hex = '';
          for (var i = 0; i < len; i++) {
            var b = Math.floor(Math.random() * 256).toString(16);
            hex += (b.length < 2 ? '0' : '') + b;
          }
          return hex;
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
// ------ httpFetch --- JS -> Dart HTTP bridge ------
// Avoid returning a Dart Future across the QuickJS channel: the vendored
// quickjs_engine Future -> Promise bridge segfaults on Android. Instead the
// Dart side returns a request id synchronously and later calls
// __httpResolve/__httpReject to settle the JS Promise.
var __httpSeq = 0;
var __httpPending = {};

globalThis.__httpRequest = function(url, options) {
  var id = ++__httpSeq;
  options = options || {};
  var resolveFn;
  var requestPromise = new Promise(function(resolve) { resolveFn = resolve; });
  __httpPending[id] = { resolve: resolveFn };

  var reply;
  try {
    reply = sendMessage('http', JSON.stringify({
      id: id,
      url: url,
      method: options.method || 'GET',
      headers: options.headers || {},
      body: options.body || options.data || null,
    }));
  } catch (e) {
    reply = { statusCode: -1, statusMessage: (e && e.message) || String(e), body: '' };
  }

  // Parse string replies early: sendMessage may return a JSON string to
  // avoid the complex _dartToJs Map-to-JSObject conversion in the native
  // bridge callback (multiple nested FFI calls that can SIGSEGV on Android).
  if (typeof reply === 'string') {
    try {
      reply = JSON.parse(reply);
    } catch (e) {
      reply = { statusCode: -1, statusMessage: (e && e.message) || String(e), body: reply };
    }
  }

  if (reply && reply.pending === true) {
    return requestPromise;
  }

  delete __httpPending[id];
  resolveFn(reply || { statusCode: -1, statusMessage: 'no reply', body: '' });
  return requestPromise;
};

globalThis.__httpResolve = function(id, resultJson) {
  var pending = __httpPending[id];
  if (!pending) return;
  delete __httpPending[id];
  var result = resultJson;
  if (typeof resultJson === 'string') {
    try {
      result = JSON.parse(resultJson);
    } catch (e) {
      result = { statusCode: -1, statusMessage: (e && e.message) || String(e), body: resultJson };
    }
  }
  pending.resolve(result || { statusCode: -1, statusMessage: 'empty reply', body: '' });
};

globalThis.__httpReject = function(id, errorJson) {
  var pending = __httpPending[id];
  if (!pending) return;
  delete __httpPending[id];
  var result = (typeof errorJson === 'string')
    ? { statusCode: -1, statusMessage: errorJson, body: '' }
    : (errorJson || { statusCode: -1, statusMessage: 'http error', body: '' });
  pending.resolve(result);
};

globalThis.httpFetch = async function(url, options) {
  options = options || {};
  if (options.headers) {
    for (const k in options.headers) {
      if (Array.isArray(options.headers[k]))
        options.headers[k] = options.headers[k].join(', ');
    }
  }
  var rawResult = await __httpRequest(url, {
    method: options.method || 'GET',
    headers: options.headers || {},
    body: options.body || options.data || null,
  });
  var result;
  if (typeof rawResult === 'string') {
    try { result = JSON.parse(rawResult); } catch(e) { result = { statusCode: -1, body: rawResult }; }
  } else {
    result = rawResult || {};
  }
  // Log failed HTTP requests for debugging (helps trace 'Error: failed')
  if (result.statusCode > 0 && (result.statusCode < 200 || result.statusCode >= 300)) {
    console.error('[httpFetch] ' + (options.method || 'GET') + ' ' + url + ' => ' + result.statusCode + ' body=' + (result.body || '').substring(0, 200));
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
