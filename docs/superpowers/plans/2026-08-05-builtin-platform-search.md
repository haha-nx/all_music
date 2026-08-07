# 内置音乐平台搜索层实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 App 增加纯 Dart 内置搜索层，网易/QQ/酷狗/酷我/咪咕开箱即搜，播放继续复用用户音源。

**Architecture:** `SourceManager` 注册 5 个 direct 内置源；`BuiltinSearchBackend` 实现 `MusicBackend`，内部组合各平台 `PlatformSearchApi`；`SearchNotifier` 只调用支持搜索的后端。

**Tech Stack:** Flutter / Dart / Dio。

## Global Constraints

- 不修改用户已导入的音源数据。
- 内置源 id 使用 `builtin_wy/builtin_tx/builtin_kg/builtin_kw/builtin_mg`。
- 所有平台请求使用 `ResponseType.plain` + 手动 JSON 解析。
- 单平台失败只影响该平台。
- 默认 ASCII 注释；中文 UI 文案沿用项目现有风格。

---

### Task 1: 平台元数据与搜索 API 抽象

**Files:**
- Create: `lib/music_source/builtin/builtin_platforms.dart`
- Create: `lib/music_source/builtin/platform_search_api.dart`

**Interfaces:**
- Produces: `enum BuiltinPlatformId { wy, tx, kg, kw, mg }`
- Produces: `class BuiltinPlatform { final String id; final String name; final String sourceKey; const BuiltinPlatform(...) }`
- Produces: `const List<BuiltinPlatform> kBuiltinPlatforms`
- Produces: `abstract class PlatformSearchApi { String get sourceId; String get sourceKey; String get sourceName; String? get lastError; Future<List<MusicTrack>> search(String keyword, {int page = 1, int limit = 20, SearchType type = SearchType.song}); Future<String?> musicUrl(MusicTrack track, {String quality = '128k'}); Future<String?> lyric(MusicTrack track); }`

### Task 2: 五个平台搜索 API 实现

**Files:**
- Create: `lib/music_source/builtin/netease_search_api.dart`
- Create: `lib/music_source/builtin/tencent_search_api.dart`
- Create: `lib/music_source/builtin/kugou_search_api.dart`
- Create: `lib/music_source/builtin/kuwo_search_api.dart`
- Create: `lib/music_source/builtin/migu_search_api.dart`

每个实现包含：
- 构造参数：`required String sourceId`、`Dio dio`。
- `search` 构造请求 URL，`ResponseType.plain` 请求，手动 `jsonDecode`，失败写入 `_lastError`。
- 静态/实例解析函数 `_parse(String rawBody)` 使用固定字段映射：
  - netease：`result.songs`，字段 `id/name/duration/artists[].name/album.name/album.picUrl`。
  - tencent：`data.song.list`，字段 `songmid/songname/interval/albumname/albummid/singer[].name`，封面 `https://y.gtimg.cn/music/photo_new/T002R300x300M000{albummid}.jpg`。
  - kugou：`data.lists`，字段 `Audioid/SongName/Duration/AlbumName/Singers[].name/Image/AlbumImage`。
  - kuwo：`abslist`，字段 `MUSICRID/SONGNAME/ARTIST/ALBUM/DURATION/web_albumpic_short`。
  - migu：`songResultData.resultList`（嵌套 List），字段 `id/name/singers[].name/albums[].name/imgItems[0].img`。
- 非 `SearchType.song` 返回空列表。
- netease 额外实现 `musicUrl`（旧 `/api/song/enhance/player/url`）与 `lyric`（旧 `/api/song/lyric`）；其余平台返回 null。

### Task 3: BuiltinSearchBackend

**Files:**
- Create: `lib/music_source/builtin/builtin_search_backend.dart`

**Interfaces:**
- Consumes: `PlatformSearchApi`、`BuiltinPlatform`。
- Produces: `class BuiltinSearchBackend implements MusicBackend`，构造 `BuiltinSearchBackend(BuiltinPlatform platform, {required String sourceId, required PlatformSearchApi api})`。
- `capabilities` 声明 `actions: ['search']`，`qualitys: ['128k', '320k']`。
- `search` 委托 api，`getMusicUrl`/`getLyric` 委托 api，`list/listDetail/importList` 返回空。

### Task 4: SourceManager 注册内置源

**Files:**
- Modify: `lib/music_source/services/source_manager.dart`

- 构造函数：`SourceManager(this._dio, {bool registerBuiltins = true})`，为 true 时调用 `_registerBuiltins()`。
- `_registerBuiltins()` 为 5 个平台创建 `SourceDefinition(id: 'builtin_${key}', name: platform.name, backendType: SourceBackendType.direct, origin: SourceOrigin.builtin, enabled: true, createdAt: DateTime(2026, 1, 1))`。
- `_createBackend`：`backendType == SourceBackendType.direct` 时按 sourceKey 创建对应 `BuiltinSearchBackend`。

### Task 5: Provider 集成与持久化过滤

**Files:**
- Modify: `lib/music_source/providers/music_source_provider.dart`
- Modify: `lib/providers/search_provider.dart`

- `SourceListNotifier(Dio dio, {bool registerBuiltins = true})` 透传参数。
- `_save` 跳过 `origin == SourceOrigin.builtin`。
- `SearchNotifier.search` 过滤 `bridge.searchKeys.isNotEmpty`；为空时提示“当前没有支持搜索的音源”。

### Task 6: UI 与回退链

**Files:**
- Modify: `lib/music_source/screens/source_hub_screen.dart`
- Modify: `lib/widgets/song_context_menu.dart`
- Modify: `lib/providers/player_provider.dart`

- 音源中心：内置源显示“内置”标签，不显示删除按钮。
- 下载：`_download` 按“原 sourceId → 其他启用源”顺序尝试取 URL。
- 歌词：`fetchLyrics` 按同样顺序尝试取歌词。

### Task 7: 测试

**Files:**
- Create: `test/music_source/builtin_search_api_test.dart`
- Create: `test/music_source/source_manager_builtin_test.dart`
- Modify: `test/providers/search_provider_test.dart`

- 固定 JSON 样本解析测试覆盖 5 个平台。
- `SourceManager(registerBuiltins: true)` 内置源数量、后端 ready、searchKeys 断言。
- 现有 SearchNotifier 测试改为 `SourceListNotifier(Dio(), registerBuiltins: false)`。

### Task 8: 验证

- 运行 `flutter analyze`，预期 0 error。
- 运行 `flutter test`，预期全部通过。
- 提交实现。
