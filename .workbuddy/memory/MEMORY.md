# 项目记忆 — All Music

## 架构决策

### 音源模块（2026-07-16 全新搭建，2026-07-20 修复后端，2026-08-03 移除内置源）
- 位置：`lib/music_source/`
- 旧音源代码已彻底删除，新模块是唯一音源管理路径
- 新模块采用分层架构：core → models → services → providers → screens
- **关键设计**：`MusicBackend` 抽象接口屏蔽后端差异
  - `LxBridge` — 复杂 LX 脚本（需 JS 引擎）
- **2026-08-03 起不再内置任何音源**：删除了 `netease_lx.js`/`qq_lx.js`/`kugou_lx.js` 脚本与 `NeteaseDirectBackend`，音源全部由用户导入（粘贴脚本或 URL）；启动时 `SourceListNotifier._init` 会过滤掉旧数据库中的 `builtin_*` 记录

### 已知问题：JS 引擎 Android 兼容性（已修复）
- ~~`flutter_js`~~ 在 Android 上需要 JavaScriptCore 的 `libjsc.so` 原生库 → **已替换为 `quickjs_engine`**
- **当前引擎**：`quickjs_engine ^0.1.1`（vendored 到 `local_plugins/quickjs_engine/`）
  - QuickJS-NG 原生库（`libquickjs_c_bridge_plugin.so`），**自带 .so、无需 libjsc.so**
  - 全平台统一 API，与 flutter_js 兼容
- **Vendored 原因**：两处需改源码才能在 Android 正常工作
  1. CMakeLists.txt 补 `-llog` 链接（NDK 27 不再隐式链接 liblog）
  2. `initChannelFunctions()` 的 `jsonDecode(message)` 加 try/catch 防 FormatException
- **修复后**：用户导入的 LX 脚本通过 QuickJS 引擎运行（`crypto-js.js` 仍随包分发供脚本签名用）

### 数据模型
- `SourceDefinition` — 音源定义（带 `backendType: js/direct` 字段）
- `SourceBackendType` — 枚举区分 JS 引擎与直接 HTTP 后端
- `MusicTrack` — 搜索结果模型
- `TrackAdapter` — 新旧模型转换器
- `MusicSource`（旧）— 仍作为 DB 持久化层，转换时填 `backendType`

### 状态管理（2026-08-03 合并为单一音源体系）
- Riverpod StateNotifierProvider
- `sourceListProvider`（唯一音源数据源，新版）— `lib/music_source/providers/music_source_provider.dart` 的 `SourceListNotifier`，从数据库加载用户导入音源并持久化变更，搜索/播放/榜单/设置/音源中心共用
- 旧 `lib/providers/source_provider.dart`（`sourceProvider`/`SourceNotifier`）已删除；`MusicSource` 仅作 DB DTO 保留（storage_service/database_helper 使用）
- `lib/utils/http_client.dart`（MusicHttpClient）因无引用一并删除
- `searchProvider`（主，`lib/providers/search_provider.dart`）— 走 `getReadyBridges()` 跨源聚合；music_source 里的重复 `searchProvider`/`SearchNotifier` 死代码已删除
- `downloadProvider` — 下载任务管理

### 音源现状（2026-08-03 起）
- 不再内置任何在线音源，全部由用户导入（设置 → 音源管理 / 音源中心）
- 旧数据库中的 `builtin_*` 记录会在启动时自动丢弃

### 路由入口
- `/source-hub` — 音源管理中心（设置 → 音源中心）
- `/source-test` — 音源测试工具
