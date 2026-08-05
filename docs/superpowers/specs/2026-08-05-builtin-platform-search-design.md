# 内置音乐平台搜索层（方案 A）设计

## 背景

当前 App 的所有搜索能力都依赖用户导入的 LX 音源脚本。很多常见的“独家音源 / 聚合 API / 野花野草”脚本只声明 `musicUrl`，不提供 `search`，因此导入成功但搜索为空。

本方案为 App 增加一层纯 Dart 实现的内置音乐平台搜索 SDK，让网易云、QQ、酷狗、酷我、咪咕 5 个平台开箱即搜；播放 URL 与歌词继续复用用户已导入的解析音源。

## 目标

- 启动后自动注册 5 个内置搜索源，无需导入脚本即可搜索。
- 搜索使用各平台公开 HTTP 接口，纯 Dart 实现，不依赖 JS 引擎、不打包第三方混淆脚本。
- 播放时沿用现有跨源降级链：先试内置后端（默认不支持取 URL），再回退到用户音源。
- 单平台失败不影响其他平台，全部失败时显示明确错误。

## 架构

### 新增目录 `lib/music_source/builtin/`

- `builtin_platforms.dart`：平台元数据，包含 `builtin_wy`、`builtin_tx`、`builtin_kg`、`builtin_kw`、`builtin_mg` 的 id、显示名、sourceKey。
- `platform_search_api.dart`：抽象接口，定义 `search(keyword, page, limit, type)`，以及可选的 `musicUrl` / `lyric`。
- 平台实现：
  - `netease_search_api.dart`
  - `tencent_search_api.dart`
  - `kugou_search_api.dart`
  - `kuwo_search_api.dart`
  - `migu_search_api.dart`
- `builtin_search_backend.dart`：实现现有 `MusicBackend` 接口，组合对应 `PlatformSearchApi`，声明 `search` 能力。

### 修改现有文件

- `lib/music_source/services/source_manager.dart`：
  - 构造函数增加 `registerBuiltins` 参数（默认 true），为测试提供关闭入口。
  - 启动时注册内置源（`origin: builtin`、`backendType: direct`、默认启用）。
  - `_createBackend` 对 direct 类型创建 `BuiltinSearchBackend`。
- `lib/music_source/providers/music_source_provider.dart`：
  - `_init` 加载用户源后保留内置源。
  - `_save` 跳过内置源，避免重复写库。
- `lib/providers/search_provider.dart`：
  - 只把 `searchKeys.isNotEmpty` 的后端交给聚合器。
  - 无可搜索源时提示“当前没有支持搜索的音源”。
- `lib/music_source/screens/source_hub_screen.dart`：
  - 内置源显示“内置”标签，不显示删除按钮。
- `lib/widgets/song_context_menu.dart`：
  - 下载取 URL 时沿用播放器的跨源降级链。
- `lib/providers/player_provider.dart`：
  - 取歌词时沿用跨源降级链。

## 平台接口

以下接口已在 2026-08-05 实测可返回 JSON：

| 平台 | 请求 |
| --- | --- |
| 网易云 | `https://music.163.com/api/search/get/web?csrf_token=&s=关键词&type=1&offset=0&limit=N` |
| QQ | `https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&p=1&n=N&w=关键词` |
| 酷狗 | `https://songsearch.kugou.com/song_search_v2?keyword=关键词&page=1&pagesize=N&platform=WebFilter` |
| 酷我 | `http://search.kuwo.cn/r.s?client=kt&all=关键词&pn=0&rn=N&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1` |
| 咪咕 | `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/search_all.do?isCopyright=1&isCorrect=1&pageNo=1&pageSize=N&searchSwitch={...}&sort=0&text=关键词` |

所有请求使用 `ResponseType.plain` + 手动 JSON 解析，区分“空结果”和“返回 HTML 被反爬拦截”。

## 数据流

用户输入关键词 → `SearchNotifier` 过滤出支持搜索的后端 → `SearchAggregator` 并行调用内置平台与用户源 → 平台响应映射为 `MusicTrack(sourceId: builtin_xxx, sourceKey: wy/kg/kw/tx/mg)` → 搜索结果页展示。

播放时 `_playSong` 先尝试 `song.sourceId` 对应的后端，失败后按现有逻辑回退到其他已启用音源。

## 错误处理

- 每个平台 API 捕获 `DioException` 与解析异常，写入 `lastError`。
- 单平台失败不中断其他平台。
- 搜索无结果时展示具体失败原因，而不是笼统的“搜索无结果”。

## 测试

- 每个平台用真实响应结构的固定 JSON 样本测试解析函数。
- `SourceManager` 测试内置源自动注册、后端 ready、`searchKeys` 正确。
- 更新现有 `SearchNotifier` 测试，使用 `registerBuiltins: false` 保持不联网。
- 最终运行 `flutter analyze` 与 `flutter test`。

## 范围外

- 不做 5 平台完整播放 URL 签名（方案 B）。
- 不重新打包六音脚本。
- 内置源不实现榜单、歌单、专辑/歌手搜索。
