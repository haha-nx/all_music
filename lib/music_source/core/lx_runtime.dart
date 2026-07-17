/// LX Music 脚本运行时环境
///
/// 提供 QuickJS 中运行 LX Music 源脚本所需的一切：
/// - Web API polyfills (atob, btoa, TextEncoder, etc.)
/// - CryptoJS 兼容层 (MD5)
/// - globalThis.lx API (send/on/request/utils)
/// - httpFetch 桥接（JS → Dart Dio）
///
/// 这是一个纯 JS 字符串构建器，不包含任何业务逻辑。
class LxRuntime {
  LxRuntime._();

  /// 构建完整的 JS 运行时注入脚本
  ///
  /// 包含所有 polyfills 和 lx API。
  /// 此脚本在用户源脚本之前执行。
  static String build() {
    return [
      _polyfills,
      _cryptoJs,
      _lxApi,
      _httpFetch,
      _console,
      _fetchPolyfill,
      _urlPolyfill,
    ].join('\n\n');
  }

  // ═══════════════════════════════════════════
  // Polyfills
  // ═══════════════════════════════════════════

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

// Promise
if (typeof Promise === 'undefined')
  globalThis.Promise = function(fn) { fn(function() {}, function() {}); };
''';

  // ═══════════════════════════════════════════
  // CryptoJS
  // ═══════════════════════════════════════════

  static const String _cryptoJs = r'''
// ── CryptoJS 兼容层 ──
if (typeof CryptoJS === 'undefined') {
  globalThis.CryptoJS = (function() {
    function md5_ff(a,b,c,d,x,s,t){const n=a+(b&c|~b&d)+x+t;return((n<<s)|(n>>>(32-s)))+b}
    function md5_gg(a,b,c,d,x,s,t){const n=a+(b&d|c&~d)+x+t;return((n<<s)|(n>>>(32-s)))+b}
    function md5_hh(a,b,c,d,x,s,t){const n=a+(b^c^d)+x+t;return((n<<s)|(n>>>(32-s)))+b}
    function md5_ii(a,b,c,d,x,s,t){const n=a+(c^(b|~d))+x+t;return((n<<s)|(n>>>(32-s)))+b}
    function toHex(n){let s='';for(let i=0;i<4;i++)s+=('0'+((n>>>(i*8))&0xff).toString(16)).slice(-2);return s}
    function md5(str){
      const bytes=[];for(let i=0;i<str.length;i++)bytes.push(str.charCodeAt(i)&0xff);
      const blen=bytes.length;bytes.push(0x80);while(bytes.length%64!==56)bytes.push(0);
      const bitLen=blen*8;for(let i=0;i<8;i++)bytes.push((bitLen>>>(i*8))&0xff);
      let a=0x67452301,b=0xefcdab89,c=0x98badcfe,d=0x10325476;
      for(let bi=0;bi<bytes.length;bi+=64){
        const M=[];for(let j=0;j<16;j++)M[j]=bytes[bi+j*4]|(bytes[bi+j*4+1]<<8)|(bytes[bi+j*4+2]<<16)|(bytes[bi+j*4+3]<<24);
        let aa=a,bb=b,cc=c,dd=d;
        a=md5_ff(a,b,c,d,M[0],7,0xd76aa478);d=md5_ff(d,a,b,c,M[1],12,0xe8c7b756);c=md5_ff(c,d,a,b,M[2],17,0x242070db);b=md5_ff(b,c,d,a,M[3],22,0xc1bdceee);
        a=md5_ff(a,b,c,d,M[4],7,0xf57c0faf);d=md5_ff(d,a,b,c,M[5],12,0x4787c62a);c=md5_ff(c,d,a,b,M[6],17,0xa8304613);b=md5_ff(b,c,d,a,M[7],22,0xfd469501);
        a=md5_ff(a,b,c,d,M[8],7,0x698098d8);d=md5_ff(d,a,b,c,M[9],12,0x8b44f7af);c=md5_ff(c,d,a,b,M[10],17,0xffff5bb1);b=md5_ff(b,c,d,a,M[11],22,0x895cd7be);
        a=md5_ff(a,b,c,d,M[12],7,0x6b901122);d=md5_ff(d,a,b,c,M[13],12,0xfd987193);c=md5_ff(c,d,a,b,M[14],17,0xa679438e);b=md5_ff(b,c,d,a,M[15],22,0x49b40821);
        a=md5_gg(a,b,c,d,M[1],5,0xf61e2562);d=md5_gg(d,a,b,c,M[6],9,0xc040b340);c=md5_gg(c,d,a,b,M[11],14,0x265e5a51);b=md5_gg(b,c,d,a,M[0],20,0xe9b6c7aa);
        a=md5_gg(a,b,c,d,M[5],5,0xd62f105d);d=md5_gg(d,a,b,c,M[10],9,0x2441453);c=md5_gg(c,d,a,b,M[15],14,0xd8a1e681);b=md5_gg(b,c,d,a,M[4],20,0xe7d3fbc8);
        a=md5_gg(a,b,c,d,M[9],5,0x21e1cde6);d=md5_gg(d,a,b,c,M[14],9,0xc33707d6);c=md5_gg(c,d,a,b,M[3],14,0xf4d50d87);b=md5_gg(b,c,d,a,M[8],20,0x455a14ed);
        a=md5_gg(a,b,c,d,M[13],5,0xa9e3e905);d=md5_gg(d,a,b,c,M[2],9,0xfcefa3f8);c=md5_gg(c,d,a,b,M[7],14,0x676f02d9);b=md5_gg(b,c,d,a,M[12],20,0x8d2a4c8a);
        a=md5_hh(a,b,c,d,M[5],4,0xfffa3942);d=md5_hh(d,a,b,c,M[8],11,0x8771f681);c=md5_hh(c,d,a,b,M[11],16,0x6d9d6122);b=md5_hh(b,c,d,a,M[14],23,0xfde5380c);
        a=md5_hh(a,b,c,d,M[1],4,0xa4beea44);d=md5_hh(d,a,b,c,M[4],11,0x4bdecfa9);c=md5_hh(c,d,a,b,M[7],16,0xf6bb4b60);b=md5_hh(b,c,d,a,M[10],23,0xbebfbc70);
        a=md5_hh(a,b,c,d,M[13],4,0x289b7ec6);d=md5_hh(d,a,b,c,M[0],11,0xeaa127fa);c=md5_hh(c,d,a,b,M[3],16,0xd4ef3085);b=md5_hh(b,c,d,a,M[6],23,0x4881d05);
        a=md5_hh(a,b,c,d,M[9],4,0xd9d4d039);d=md5_hh(d,a,b,c,M[12],11,0xe6db99e5);c=md5_hh(c,d,a,b,M[15],16,0x1fa27cf8);b=md5_hh(b,c,d,a,M[2],23,0xc4ac5665);
        a=md5_ii(a,b,c,d,M[0],6,0xf4292244);d=md5_ii(d,a,b,c,M[7],10,0x432aff97);c=md5_ii(c,d,a,b,M[14],15,0xab9423a7);b=md5_ii(b,c,d,a,M[5],21,0xfc93a039);
        a=md5_ii(a,b,c,d,M[12],6,0x655b59c3);d=md5_ii(d,a,b,c,M[3],10,0x8f0ccc92);c=md5_ii(c,d,a,b,M[10],15,0xffeff47d);b=md5_ii(b,c,d,a,M[1],21,0x85845dd1);
        a=md5_ii(a,b,c,d,M[8],6,0x6fa87e4f);d=md5_ii(d,a,b,c,M[15],10,0xfe2ce6e0);c=md5_ii(c,d,a,b,M[6],15,0xa3014314);b=md5_ii(b,c,d,a,M[13],21,0x4e0811a1);
        a=md5_ii(a,b,c,d,M[4],6,0xf7537e82);d=md5_ii(d,a,b,c,M[11],10,0xbd3af235);c=md5_ii(c,d,a,b,M[2],15,0x2ad7d2bb);b=md5_ii(b,c,d,a,M[9],21,0xeb86d391);
        a=(a+aa)>>>0;b=(b+bb)>>>0;c=(c+cc)>>>0;d=(d+dd)>>>0;
      }
      return toHex(a)+toHex(b)+toHex(c)+toHex(d);
    }
    function wordArrayFromUtf8(str){
      const wa=[],fn={sigBytes:str.length,toString:function(){let s='';for(let i=0;i<wa.length;i++)s+=toHex(wa[i]);return s}};
      fn.words=[];for(let i=0;i<str.length;i+=4){let w=0;for(let j=0;j<4&&i+j<str.length;j++)w|=(str.charCodeAt(i+j)&0xff)<<(j*8);fn.words.push(w>>>0)}
      return fn;
    }
    var _encUtf8={parse:function(s){return wordArrayFromUtf8(String(s))},stringify:function(wa){let s='';for(let i=0;i<wa.words.length;i++){var w=wa.words[i];s+=String.fromCharCode(w&0xff,(w>>8)&0xff,(w>>16)&0xff,(w>>24)&0xff)}return s.replace(/\0+$/,'')}};
    return {
      MD5:function(msg){return{toString:function(){return md5(String(msg))}}},
      enc:{Utf8:_encUtf8,Base64:{stringify:function(wa){return globalThis.btoa(_encUtf8.stringify(wa))}}},
      lib:{WordArray:{create:function(str){return _encUtf8.parse(str)}}},
      algo:{MD5:{create:function(){return{update:function(){},finalize:function(msg){return{toString:function(){return md5(String(msg))}}}}}}},
      AES:{encrypt:function(msg,key,cfg){return{toString:function(){return''}}},decrypt:function(cipher,key,cfg){return{toString:_encUtf8,words:[]}}},
      mode:{ECB:0},pad:{Pkcs7:0}
    };
  })();
}
if (typeof md5 === 'undefined') globalThis.md5 = function(msg) { return CryptoJS.MD5(String(msg)).toString(); };
if (typeof MD5 === 'undefined') globalThis.MD5 = globalThis.md5;
''';

  // ═══════════════════════════════════════════
  // LX Music API
  // ═══════════════════════════════════════════

  static const String _lxApi = r'''
// ── globalThis.lx — LX Music 源脚本桥接 API ──

// 内部状态
var __requestHandlers = {};
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
    version: '2.0',
    env: 'mobile',
    currentScriptInfo: {},

    // lx.send(eventName, data) — 脚本主动通知 App
    send: function(eventName, data) {
      if (eventName === globalThis.lx.EVENT_NAMES.inited) {
        __initialized = true;
      }
      sendMessage('lx', JSON.stringify({ type: 'send', event: eventName, data: data }));
    },

    // lx.on(eventName, handler) — 注册事件处理器
    on: function(eventName, handler) {
      if (eventName === globalThis.lx.EVENT_NAMES.request) {
        __requestHandlers['_global'] = handler;
      }
    },

    // lx.request(url, options, callback) — HTTP 请求
    request: function(url, options, callback) {
      var opts = options || {};
      if (typeof url === 'object') { opts = url; url = opts.url || ''; }
      var method = opts.method || 'GET';
      var headers = opts.headers || {};
      var body = opts.body || opts.data || null;

      // 展开数组值headers
      for (var k in headers) {
        if (Array.isArray(headers[k])) headers[k] = headers[k].join(', ');
      }

      var promise = new Promise(function(resolve, reject) {
        httpFetch(url, { method: method, headers: headers, body: body })
          .then(function(result) {
            var err = result.statusCode < 0 ? result.statusMessage : null;
            var rawBody = result.body || '';
            var parsedBody = rawBody;
            if (typeof rawBody === 'string' && rawBody.length > 0) {
              try { parsedBody = JSON.parse(rawBody); } catch(e) {}
            }
            var resp = { statusCode: result.statusCode, headers: result.headers || {}, body: parsedBody };
            resolve(resp);
            if (callback) { try { callback(err, resp); } catch(e) {} }
          })
          .catch(function(e) {
            reject(e);
            if (callback) { try { callback(e, null); } catch(err) {} }
          });
      });

      return function() {}; // cancel stub
    },

    // lx.utils — 工具函数
    utils: {
      atob: function(s) { return globalThis.atob ? globalThis.atob(s) : s; },
      btoa: function(s) { return globalThis.btoa ? globalThis.btoa(s) : s; },
      crypto: {
        md5: function(str) { return md5(String(str)); },
      },
    },

    sources: {},
  };
}
''';

  // ═══════════════════════════════════════════
  // httpFetch bridge
  // ═══════════════════════════════════════════

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
  // ═══════════════════════════════════════════

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
  // ═══════════════════════════════════════════

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
  // ═══════════════════════════════════════════

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
