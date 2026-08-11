// _GNU_SOURCE 使 glibc 暴露 pthread_getattr_np（Linux 桌面测试用）。
// Android bionic 默认即暴露该符号，无需该宏；用 #ifndef 避免重复定义告警。
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "quickjs/quickjs.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
// pthread_getattr_np 仅 Android(bionic) / Linux(glibc) 支持；
// macOS/iOS 用 pthread_get_stacksize_np（此处不处理，降级为不钳制）。
#if defined(__ANDROID__) || defined(__linux__)
#include <pthread.h>
#endif
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#ifdef _MSC_VER
#include <intrin.h>
#endif
#endif
#ifdef __ANDROID__
#include <android/log.h>
#else
#define __android_log_print(a, b, c, d)
#endif

#ifdef _MSC_VER
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

int QUICKJS_RUNTIME_DEBUG_ENABLED = 0;

int ONE_VALUE = 0;

// Dart FFI channel callbacks run on the same native thread as the enclosing
// JS evaluation. While one is active, JS_UpdateStackTop must not move
// stack_top deeper: doing so would keep expanding QuickJS's stack budget on
// every re-entrant FFI call and eventually let JS recursion smash the real
// thread stack before QuickJS can throw a catchable StackOverflow.
static thread_local bool qjs_in_dart_channel = false;

static void qjs_update_stack_top(JSRuntime *rt)
{
    if (!qjs_in_dart_channel)
        JS_UpdateStackTop(rt);
}

struct QjsChannelScope
{
    QjsChannelScope() { qjs_in_dart_channel = true; }
    ~QjsChannelScope() { qjs_in_dart_channel = false; }
};

// 前置声明：JS→Dart channel 回调进入前的栈余量守卫（定义见下方 js_module_loader 之前）。
// 在 JS 深递归中调用 channel 时，FFI 回调（channelDispacher → _dartToJs/_jsToDart）
// 会叠加原生栈帧，可能越过线程 guard page SIGSEGV；守卫在进入 Dart 前兜底，
// 剩余栈不足时抛可捕获的 JS RangeError。
// 注意：static 函数声明/定义都放在 extern "C" 块内，避免 MSVC C2732 链接规范冲突。

extern "C"
{
    // JS→Dart channel 回调进入前的栈余量守卫（定义见下方 js_module_loader 之前）。
    static bool qjs_ensure_channel_stack(JSContext *ctx);

    DLLEXPORT int doReturnOne()
    {
        ONE_VALUE += 3;
        return ONE_VALUE;
    }
    DLLEXPORT JSRuntime *JS_NewRuntimeDartBridge(void)
    {
        JSRuntime *runtime = JS_NewRuntime();
        JS_SetGCThreshold(runtime, (size_t)-1); // disable GC - to prevent GC disallocate variables
                                                // yet in use in the Dart side
        JS_SetMemoryLimit(runtime, 0x4000000);  // 64 Mo
        //JS_SetMemoryLimit(runtime, -1); is the default
        return runtime;
    }

#define QUICKJS_CHANNEL_CONSOLELOG 0;
#define QUICKJS_CHANNEL_SETTIMEOUT 1;
#define QUICKJS_CHANNEL_SENDNATIVE 2;

    typedef JSValue *(*ChannelFunc)(const JSContext *ctx, const char *channel, const char *message);
    struct channel
    {
        char *name;
        JSContext *ctx;
        ChannelFunc func;
        int assigned;
    };

    struct channel channel_functions[10] = {/*{"cat", cat_func}, {"dog", dog_func}, {NULL, NULL}*/
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0},
                                            {NULL, NULL, 0}};

    // where cat_func is declared int cat_func(const char **args);.
    // You can search the list with

    int contextsLength = 0;

    static JSValue CChannelFunction(JSContext *ctx, JSValueConst this_val,
                                    int argc, JSValueConst *argv)
    {
        // 栈守卫：旧桥（JS_NewContextDartBridge）的 channel 入口同样可能
        // 在 JS 深递归中被调用，先检查剩余栈空间再进入 Dart。
        if (!qjs_ensure_channel_stack(ctx))
            return JS_EXCEPTION;
        const char *channelName = JS_ToCString(ctx, argv[0]);
        const char *message = JS_ToCString(ctx, argv[1]);

        JSValue jsResult = JS_NULL;
        // while(cur->ctx) {
        //     //if(!strcmp(cur->name, channelName)) {
        //     if (cur->ctx == ctx && cur->assigned == 1) {
        //         JS_Eval(ctx, "console.log('Aqui no CChannelFunction3');", 40,"arquivo.js",0);
        //         result = cur->func(channelName, message);
        //         JS_Eval(ctx, "console.log('Aqui no CChannelFunction4');", 40,"arquivo.js",0);
        //         jsResult = JS_NewString(ctx, result);
        //         JS_Eval(ctx, "console.log('Aqui no CChannelFunction5');", 40,"arquivo.js",0);
        //     }
        // }

        int idxChannel = 0;
        if (strcmp("SendNative", channelName) == 0)
        {
            idxChannel = QUICKJS_CHANNEL_SENDNATIVE;
        }
        else if (strcmp("ConsoleLog", channelName) == 0)
        {
            idxChannel = QUICKJS_CHANNEL_CONSOLELOG;
        }
        if (strcmp("SetTimeout", channelName) == 0)
        {
            idxChannel = QUICKJS_CHANNEL_SETTIMEOUT;
        }

        if (channel_functions[idxChannel].assigned == 1)
        {
            ChannelFunc funcCaller = channel_functions[idxChannel].func;

            if (funcCaller != nullptr)
            {
                jsResult = *funcCaller(ctx, channelName, message);
            }
            else
            {
                jsResult = JS_NewString(ctx, "No function found");
            }
        }

        return jsResult;
    }

    JSValue stringifyFn;

    DLLEXPORT JSContext *JS_NewContextDartBridge(
        JSRuntime *rt,
        ChannelFunc consoleLogChannelFunction,
        ChannelFunc setTimeoutChannelFunction,
        ChannelFunc sendNativeChannelFunction)
    {
        JSContext *ctx;
        ctx = JS_NewContext(rt);

        // create the QuickJS Function passing the CChannelFunction ;
        // register the function jsBridgeFunction into the global object
        JSValue globalObject = JS_GetGlobalObject(ctx);

        stringifyFn = JS_Eval(
            ctx,
            "function simpleStringify(obj) { return JSON.stringify(obj);}simpleStringify;",
            strlen("function simpleStringify(obj) { return JSON.stringify(obj);}"),
            "f1.js",
            0);

        JS_SetPropertyStr(
            ctx,
            globalObject,
            "FLUTTER_JS_NATIVE_BRIDGE_sendMessage",
            JS_NewCFunction(ctx, CChannelFunction, "FLUTTER_JS_NATIVE_BRIDGE_sendMessage", 2));

        if (consoleLogChannelFunction)
        {
            channel_functions[0].func = consoleLogChannelFunction;
            channel_functions[0].ctx = ctx;
            channel_functions[0].name = (char *)"ConsoleLog";
            channel_functions[0].assigned = 1;

            channel_functions[1].func = setTimeoutChannelFunction;
            channel_functions[1].ctx = ctx;
            channel_functions[1].name = (char *)"SetTimeout";
            channel_functions[1].assigned = 1;

            // store in the function register the dartChannelFunction passed
            channel_functions[2].func = sendNativeChannelFunction;
            channel_functions[2].ctx = ctx;
            channel_functions[2].name = (char *)"SendNative";
            channel_functions[2].assigned = 1;

            contextsLength = 3;
        }

        // JS_FreeValue(ctx, globalObject);

        // JS_FreeValue(ctx, stringifyFn);

        // returns the generated context
        return ctx;
    }

    DLLEXPORT JSValue *copyToHeap(JSValueConst value)
    {
        auto *result = static_cast<JSValue *>(malloc(sizeof(JSValueConst)));
        if (result)
        {
            memcpy(result, &value, sizeof(JSValueConst));
        }
        return result;
    }
    DLLEXPORT const void *JSEvalWrapper(JSContext *ctx, const char *input, size_t input_len,
                                        const char *filename, int eval_flags,
                                        int *errors, JSValue *result, char **stringResult)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        qjs_update_stack_top(rt);

        // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "Before Eval: %p", result);
        result = new JSValue(JS_Eval(ctx, input, input_len, filename, eval_flags));
        // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "After Eval: %p", result);
        *errors = 0;

        if (JS_IsException(*result) == 1)
        {
            // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "Inside is exception: %p", result);
            JS_FreeValue(ctx, *result);
            *errors = 1;
            * result = JS_GetException(ctx);
            *stringResult = (char *)JS_ToCString(ctx, *result);
            // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "After get  exception: %p", result);
            return nullptr;
        }
        // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "Before string result: %p", stringResult);
        *stringResult = (char *)JS_ToCString(ctx, *result);
        // __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "After string result: %p", stringResult);
        return nullptr;
    }

    DLLEXPORT void *JS_GetNullValue(JSContext *ctx, JSValue *result)
    {
        result = copyToHeap(JS_Eval(
            ctx,
            "null",
            4,
            "f1.js",
            0));
        return nullptr;
    }


    DLLEXPORT int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
    {
        return JS_IsFunction(ctx, *val);
    }

    // used in method callFunction in quickjs_method_bindings
    DLLEXPORT int callJsFunction1Arg(JSContext *ctx, JSValueConst *function, JSValueConst *object, JSValueConst *result, char **stringResult)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        qjs_update_stack_top(rt);
        JSValue globalObject = JS_GetGlobalObject(ctx);
        // JSValue function = JS_GetPropertyStr(ctx, globalObject, functionName);

        result = copyToHeap(JS_Call(ctx, *function, globalObject, 1, object));

        int successOperation = 1;

        if (JS_IsException(*result) == 1)
        {
            successOperation = 0;
            result = copyToHeap(JS_GetException(ctx));
        }
        *stringResult = (char *)JS_ToCString(ctx, *result);
        return successOperation;
    }

    DLLEXPORT int getTypeTag(JSValue *jsValue)
    {
        if (jsValue)
        {
            return JS_VALUE_GET_TAG(*jsValue);
        }
        else
        {
            return JS_TAG_NULL;
        }
    }

    DLLEXPORT int JS_IsArrayDartWrapper(JSContext *_unused_ctx, JSValueConst *val)
    {
        return JS_IsArray(*val);
    }

    DLLEXPORT int JS_JSONStringifyDartWrapper(
        JSContext *ctx,
        JSValue *obj, JSValueConst *result, char **stringResult)
    {
        if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
        {
            __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper %p", result);
        }
        JSValue globalObject = JS_GetGlobalObject(ctx);
        if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
        {
            __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper2 %p", result);
        }
        if (JS_IsUndefined(*obj) == 1)
        {
            if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
            {
                __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper3 %p", result);
            }
            *stringResult = (char *)"undefined";
            return 0;
        }
        else if (JS_IsNull(*obj) == 1)
        {
            if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
            {
                __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper4 %p", result);
            }
            *stringResult = (char *)"null";
            return 0;
        }
        else
        {
            if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
            {
                __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper5 %p", result);
            }
            result = copyToHeap(JS_Call(ctx, stringifyFn, globalObject, 1, obj));
            *stringResult = (char *)JS_ToCString(ctx, *result);
            if (QUICKJS_RUNTIME_DEBUG_ENABLED == 1)
            {
                __android_log_print(ANDROID_LOG_DEBUG, "LOG_TAG", "JS_JSONStringifyDartWrapper6 %p", result);
            }
            return 1;
        }
    }

    enum JSChannelType
    {
        JSChannelType_METHON = 0,
        JSChannelType_MODULE = 1,
        JSChannelType_PROMISE_TRACK = 2,
        JSChannelType_FREE_OBJECT = 3,
    };

    typedef void *JSChannel(JSContext *ctx, size_t type, void *argv);

    DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
    {
        return new JSValue(JS_Throw(ctx, JS_DupValue(ctx, *obj)));
    }

    DLLEXPORT JSValue *jsEXCEPTION()
    {
        return new JSValue(JS_EXCEPTION);
    }

    DLLEXPORT JSValue *jsUNDEFINED()
    {
        return new JSValue(JS_UNDEFINED);
    }

    DLLEXPORT JSValue *jsNULL()
    {
        return new JSValue(JS_NULL);
    }

    // 返回当前线程剩余栈空间（字节）。无法探测时返回 SIZE_MAX（视为充足，不拦截）。
    static size_t qjs_get_stack_remaining(void)
    {
#if defined(__ANDROID__) || defined(__linux__)
        pthread_attr_t attr;
        if (pthread_getattr_np(pthread_self(), &attr) != 0)
            return SIZE_MAX;
        void *stack_addr = NULL;
        size_t stack_size = 0;
        int rc = pthread_attr_getstack(&attr, &stack_addr, &stack_size);
        pthread_attr_destroy(&attr);
        if (rc != 0 || stack_size == 0)
            return SIZE_MAX;
        // x86_64 / ARM64 栈向下生长：sp 应位于 [stack_addr, stack_addr + stack_size)
        uintptr_t sp = (uintptr_t)__builtin_frame_address(0);
        uintptr_t bottom = (uintptr_t)stack_addr;
        uintptr_t top = bottom + stack_size;
        if (sp <= bottom || sp >= top)
            return SIZE_MAX; // 探测异常/栈已用尽：fail-open 放行，避免误伤
        return sp - bottom; // 剩余空间 = sp 到栈底（低地址方向）
#elif defined(_WIN32)
        // 用 TEB 的 StackLimit/StackBase 获取当前线程栈范围（不依赖 _WIN32_WINNT）。
        // 栈向下生长：StackLimit 是低地址（栈底），StackBase 是高地址（栈顶）。
        NT_TIB *tib = (NT_TIB *)NtCurrentTeb();
        uintptr_t bottom = (uintptr_t)tib->StackLimit;
        uintptr_t top = (uintptr_t)tib->StackBase;
        uintptr_t sp;
#ifdef _MSC_VER
        sp = (uintptr_t)_AddressOfReturnAddress();
#else
        sp = (uintptr_t)__builtin_frame_address(0);
#endif
        if (sp <= bottom || sp >= top)
            return SIZE_MAX; // 探测异常/栈已用尽：fail-open 放行
        return sp - bottom; // 剩余空间 = sp 到栈底（低地址方向）
#else
        // macOS/iOS：暂不探测，不拦截。
        return SIZE_MAX;
#endif
    }

    // JS→Dart channel 回调进入前的栈余量守卫。
    // 至少保留 512KB 给 Dart/FFI 回调自身（channelDispacher、_dartToJs/_jsToDart、
    // print/jsonEncode 等）使用，防止在 JS 深递归的栈底上再叠加 Dart 帧越界。
#define QJS_CHANNEL_STACK_GUARD (512 * 1024)
    //
    // 洛雪系音源脚本在深递归（自解密 VM）中调用 sendMessage/console.log/httpFetch：
    // QuickJS 的 js_check_stack_overflow 只约束 JS 层递归；进入 Dart 回调后，
    // FFI 桥（channelDispacher → _dartToJs/_jsToDart）的栈帧叠加在已经很深的
    // 原生栈上，这部分不受 JS 栈限制保护，可能越过线程 guard page 直接 SIGSEGV
    // （播放 musicUrl 时闪退即此路径：初始化时递归较浅会抛可 catch 的 RangeError，
    //  播放时递归更深 + channel 叠加 → 原生栈溢出）。
    // 这里在进入 Dart 前兜底：剩余栈不足时抛可捕获的 JS RangeError，让 JS 侧
    // try/catch（getMusicUrl 的 catch → 返回 null → 播放器降级为「暂无可用播放源」）
    // 处理，而不是让进程崩溃。
    static bool qjs_ensure_channel_stack(JSContext *ctx)
    {
        size_t remaining = qjs_get_stack_remaining();
        if (remaining != SIZE_MAX && remaining < QJS_CHANNEL_STACK_GUARD)
        {
            JS_ThrowRangeError(ctx, "stack overflow");
            return false;
        }
        return true;
    }

    // 不抛异常的守卫变体：用于 void 回调（如 js_promise_rejection_tracker），
    // 栈不足时直接返回 false，由调用方跳过 Dart 上报——不能在 void 回调里
    // 抛异常（会悬挂在 ctx 上，污染后续 JS API 调用），也不应在调用方
    // 手动清理异常（JS_GetException 会把异常状态标记为已处理但语义混乱）。
    static bool qjs_channel_stack_ok(void)
    {
        size_t remaining = qjs_get_stack_remaining();
        return remaining == SIZE_MAX || remaining >= QJS_CHANNEL_STACK_GUARD;
    }

    JSModuleDef *js_module_loader(
        JSContext *ctx,
        const char *module_name, void *opaque)
    {
        if (!qjs_ensure_channel_stack(ctx))
            return NULL;
        JSRuntime *rt = JS_GetRuntime(ctx);
        JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
        QjsChannelScope channel_scope;
        const char *str = (char *)channel(ctx, JSChannelType_MODULE, (void *)module_name);
        if (str == 0)
            return NULL;
        JSValue func_val = JS_Eval(ctx, str, strlen(str), module_name, JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
        if (JS_IsException(func_val))
            return NULL;
        /* the module is already referenced, so we must free it */
        JSModuleDef *m = (JSModuleDef *)JS_VALUE_GET_PTR(func_val);
        JS_FreeValue(ctx, func_val);
        return m;
    }

    JSValue js_channel(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValue *func_data)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
        void *data[4];
        data[0] = &this_val;
        data[1] = &argc;
        data[2] = argv;
        data[3] = func_data;
        // 栈守卫：JS 深递归中调用 sendMessage/console.log 等 channel 时，
        // 若剩余栈空间不足则抛 JS RangeError（可被 JS try/catch 捕获），
        // 避免 FFI 回调（_dartToJs/_jsToDart）叠加原生栈越界 SIGSEGV。
        if (!qjs_ensure_channel_stack(ctx))
            return JS_EXCEPTION;
        QjsChannelScope channel_scope;
        JSValue result = *(JSValue *)channel(ctx, JSChannelType_METHON, data);
        return result;
    }

    void js_promise_rejection_tracker(JSContext *ctx, JSValueConst promise,
                                      JSValueConst reason,
                                      bool is_handled, void *opaque)
    {
        if (is_handled)
            return;
        // 栈守卫：rejection 回调同样可能发生在 JS 深栈上，栈不足时
        // 跳过 Dart 上报（仅丢失一条 rejection 日志），避免叠加越界。
        // 注意：这里是 void 回调，不能用抛异常的守卫（异常会悬挂在 ctx
        // 上污染后续 JS 交互），故用不抛异常的 qjs_channel_stack_ok。
        if (!qjs_channel_stack_ok())
            return;
        JSRuntime *rt = JS_GetRuntime(ctx);
        JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
        QjsChannelScope channel_scope;
        channel(ctx, JSChannelType_PROMISE_TRACK, &reason);
    }

    DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel)
    {
        JSRuntime *rt = JS_NewRuntime();
        JS_SetRuntimeOpaque(rt, (void *)channel);
        JS_SetHostPromiseRejectionTracker(rt, js_promise_rejection_tracker, nullptr);
        JS_SetModuleLoaderFunc(rt, nullptr, js_module_loader, nullptr);
        return rt;
    }

    DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
    {
        JSClassID QJSClassId = 0;
        JSRuntime *rt = JS_GetRuntime(ctx);
        JS_NewClassID(rt, &QJSClassId);
        if (!JS_IsRegisteredClass(rt, QJSClassId))
        {
            JSClassDef def{
                name,
                // destructor
                [](JSRuntime *rt, JSValue obj) noexcept {
                    JSClassID classid = JS_GetClassID(obj);
                    void *opaque = JS_GetOpaque(obj, classid);
                    JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
                    if (channel == nullptr)
                        return;
                    QjsChannelScope channel_scope;
                    channel((JSContext *)rt, JSChannelType_FREE_OBJECT, opaque);
                }};
            int e = JS_NewClass(rt, QJSClassId, &def);
            if (e < 0)
            {
                JS_ThrowInternalError(ctx, "Cant register class %s", name);
                return 0;
            }
        }
        return QJSClassId;
    }

    DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
    {
        return JS_GetOpaque(*obj, classid);
    }

    DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
    {
        auto jsobj = new JSValue(JS_NewObjectClass(ctx, QJSClassId));
        if (JS_IsException(*jsobj))
            return jsobj;
        JS_SetOpaque(*jsobj, opaque);
        return jsobj;
    }
    // 返回当前线程的栈大小（字节）。无法确定时返回 0。
    //
    // 用于把 QuickJS 的 JS 栈限制钳制在实际原生线程栈以内：若 JS 栈
    // (stack_size) 大于等于实际线程栈，QuickJS 计算的 stack_limit =
    // stack_top - stack_size 会落到线程 guard page 之下，使
    // js_check_stack_overflow 永不触发，深度递归会越过 guard page 直接
    // SIGSEGV（Android 主线程栈通常仅数 MB，而 Dart 侧默认请求 8 MB）。
    static size_t qjs_get_thread_stack_size(void)
    {
#if defined(__ANDROID__) || defined(__linux__)
        pthread_attr_t attr;
        if (pthread_getattr_np(pthread_self(), &attr) != 0)
            return 0;
        void *stack_addr = NULL;
        size_t stack_size = 0;
        int rc = pthread_attr_getstack(&attr, &stack_addr, &stack_size);
        pthread_attr_destroy(&attr);
        if (rc != 0 || stack_size == 0)
            return 0;
        return stack_size;
#else
        // macOS/iOS/Windows：暂不探测，返回 0 表示不钳制（行为同旧版）。
        return 0;
#endif
    }

    DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
    {
        // 钳制 JS 栈限制为 min(请求值, 实际线程栈 - 安全余量)。
        // 安全余量预留给 FFI 回调（channelDispacher → _dartToJs / _jsToDart，
        // 可能递归转换嵌套 Map/List）、native bridge 栈帧与 Dart VM 栈帧，
        // 确保 QuickJS 能在触及线程 guard page 前及时抛出可被 catch 的
        // StackOverflow JS 异常，而非让进程 SIGSEGV 闪退。
        // 注：1MB 余量对「独家音源」等深度混淆脚本偏大——它们 URL 签名/解密
        // 的递归在 7MB JS 栈下仍会溢出（表现为播放时 sign=fail 无法播放）。
        // 收紧到 512KB 给 JS 更多空间；channel 入口的 qjs_ensure_channel_stack
        // 守卫（QJS_CHANNEL_STACK_GUARD=512KB）已在进入 Dart 前兜底 FFI 叠加，
        // 因此调小此余量不会再导致 SIGSEGV。
        size_t requested = stack_size;
        size_t thread_stack = qjs_get_thread_stack_size();
        const size_t kSafetyMargin = 512 * 1024; // 512 KB
        if (thread_stack > kSafetyMargin) {
            size_t safe = thread_stack - kSafetyMargin;
            if (stack_size == 0 || stack_size > safe)
                stack_size = safe;
        }
        JS_SetMaxStackSize(rt, stack_size);
        // 记录钳制前后值，便于诊断 Android 上 JS 栈不足导致的播放失败。
#if defined(__ANDROID__)
        __android_log_print(ANDROID_LOG_INFO, "QuickJSBridge",
                            "jsSetMaxStackSize: requested=%zu thread_stack=%zu clamped=%zu",
                            requested, thread_stack, stack_size);
#endif
    }

    DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit)
    {
        JS_SetMemoryLimit(rt, limit);
    }

    DLLEXPORT void jsFreeRuntime(JSRuntime *rt)
    {
        JS_SetRuntimeOpaque(rt, nullptr);
        JS_FreeRuntime(rt);
    }

    DLLEXPORT JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
    {
        return new JSValue(JS_NewCFunctionData(ctx, js_channel, 0, 0, 1, funcData));
    }

    DLLEXPORT JSContext *jsNewContext(JSRuntime *rt)
    {
        JSContext *ctx = JS_NewContext(rt);
        return ctx;
    }

    DLLEXPORT void jsFreeContext(JSContext *ctx)
    {
        JS_FreeContext(ctx);
    }

    DLLEXPORT JSRuntime *jsGetRuntime(JSContext *ctx)
    {
        return JS_GetRuntime(ctx);
    }

    DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int32_t eval_flags)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        qjs_update_stack_top(rt);
        JSValue *ret = new JSValue(JS_Eval(ctx, input, input_len, filename, eval_flags));
        return ret;
    }

    DLLEXPORT int32_t jsValueGetTag(JSValue *val)
    {
        return JS_VALUE_GET_TAG(*val);
    }

    DLLEXPORT void *jsValueGetPtr(JSValue *val)
    {
        return JS_VALUE_GET_PTR(*val);
    }

    DLLEXPORT int32_t jsTagIsFloat64(int32_t tag)
    {
        return JS_TAG_IS_FLOAT64(tag);
    }

    DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int32_t val)
    {
        return new JSValue(JS_NewBool(ctx, val));
    }

    DLLEXPORT JSValue *jsNewInt64(JSContext *ctx, int64_t val)
    {
        return new JSValue(JS_NewInt64(ctx, val));
    }

    DLLEXPORT JSValue *jsNewFloat64(JSContext *ctx, double val)
    {
        return new JSValue(JS_NewFloat64(ctx, val));
    }

    DLLEXPORT JSValue *jsNewString(JSContext *ctx, const char *str)
    {
        return new JSValue(JS_NewString(ctx, str));
    }

    DLLEXPORT JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
    {
        return new JSValue(JS_NewArrayBufferCopy(ctx, buf, len));
    }

    DLLEXPORT JSValue *jsNewArray(JSContext *ctx)
    {
        return new JSValue(JS_NewArray(ctx));
    }

    DLLEXPORT JSValue *jsNewObject(JSContext *ctx)
    {
        return new JSValue(JS_NewObject(ctx));
    }

    DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v, int32_t free)
    {
        JS_FreeValue(ctx, *v);
        if (free)
            delete v;
    }

    DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v, int32_t free)
    {
        JS_FreeValueRT(rt, *v);
        if (free)
            delete v;
    }

    DLLEXPORT JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
    {
        return new JSValue(JS_DupValue(ctx, *v));
    }

    DLLEXPORT JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
    {
        return new JSValue(JS_DupValueRT(rt, *v));
    }

    DLLEXPORT int32_t jsToBool(JSContext *ctx, JSValueConst *val)
    {
        return JS_ToBool(ctx, *val);
    }

    DLLEXPORT int64_t jsToInt64(JSContext *ctx, JSValueConst *val)
    {
        int64_t p;
        JS_ToInt64(ctx, &p, *val);
        return p;
    }

    DLLEXPORT double jsToFloat64(JSContext *ctx, JSValueConst *val)
    {
        double p;
        JS_ToFloat64(ctx, &p, *val);
        return p;
    }

    DLLEXPORT const char *jsToCString(JSContext *ctx, JSValueConst *val)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        qjs_update_stack_top(rt);
        const char *ret = JS_ToCString(ctx, *val);
        return ret;
    }

    DLLEXPORT void jsFreeCString(JSContext *ctx, const char *ptr)
    {
        return JS_FreeCString(ctx, ptr);
    }

    DLLEXPORT uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
    {
        return JS_GetArrayBuffer(ctx, psize, *obj);
    }

    DLLEXPORT int32_t jsIsPromise(JSContext *_unused_ctx, JSValueConst *val)
    {
        return JS_IsPromise(*val);
    }

    DLLEXPORT int32_t jsIsArray(JSContext *_unused_ctx, JSValueConst *val)
    {
        return JS_IsArray(*val);
    }

    DLLEXPORT int32_t jsIsError(JSContext *_unused_ctx, JSValueConst *val)
    {
        return JS_IsError(*val);
    }

    DLLEXPORT JSValue *jsNewError(JSContext *ctx)
    {
        return new JSValue(JS_NewError(ctx));
    }

    DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
                                     JSAtom prop)
    {
        return new JSValue(JS_GetProperty(ctx, *this_obj, prop));
    }

    DLLEXPORT int32_t jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
                                            JSAtom prop, JSValue *val, int32_t flags)
    {
        return JS_DefinePropertyValue(ctx, *this_obj, prop, *val, flags);
    }

    DLLEXPORT void jsFreeAtom(JSContext *ctx, JSAtom v)
    {
        JS_FreeAtom(ctx, v);
    }

    DLLEXPORT JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
    {
        return JS_ValueToAtom(ctx, *val);
    }

    DLLEXPORT JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
    {
        return new JSValue(JS_AtomToValue(ctx, val));
    }

    DLLEXPORT int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
                                            uint32_t *plen, JSValueConst *obj, int32_t flags)
    {
        return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
    }

    DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i)
    {
        return ptab[i].atom;
    }

    DLLEXPORT uint32_t sizeOfJSValue()
    {
        return sizeof(JSValue);
    }

    DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val)
    {
        list[i] = *val;
    }

    DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
                              int32_t argc, JSValueConst *argv)
    {
        JSRuntime *rt = JS_GetRuntime(ctx);
        qjs_update_stack_top(rt);
        JSValue *ret = new JSValue(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
        return ret;
    }

    DLLEXPORT int32_t jsIsException(JSValueConst *val)
    {
        return JS_IsException(*val);
    }

    DLLEXPORT JSValue *jsGetException(JSContext *ctx)
    {
        return new JSValue(JS_GetException(ctx));
    }

    DLLEXPORT int32_t jsExecutePendingJob(JSRuntime *rt)
    {
        qjs_update_stack_top(rt);
        JSContext *ctx;
        int ret = JS_ExecutePendingJob(rt, &ctx);
        return ret;
    }

    DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
    {
        return new JSValue(JS_NewPromiseCapability(ctx, resolving_funcs));
    }

    DLLEXPORT void jsFree(JSContext *ctx, void *ptab)
    {
        js_free(ctx, ptab);
    }
}

