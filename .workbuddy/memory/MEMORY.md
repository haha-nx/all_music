# All Music — 项目记忆

## 项目概述
Flutter 音乐 App，支持导入音源实现跨平台歌曲搜索/播放/歌单管理，所有数据本地存储（SQLite）。

## 技术栈
- **框架**: Flutter + Dart
- **状态管理**: Riverpod (StateNotifier)
- **路由**: go_router
- **音频**: just_audio (播放) + audio_service (后台/锁屏)
- **网络**: dio
- **存储**: sqflite (SQLite，6 张表)
- **UI**: liquid_glass_widgets (液态玻璃效果)
- **风格**: Apple Music 暗色主题

## 架构约定
- `models/` — 纯数据模型（Song, Playlist, MusicSource, Lyric, SourceType）
- `providers/` — Riverpod StateNotifier（PlayerNotifier, SearchNotifier, FavoritesNotifier, PlaylistNotifier, SourceNotifier）
- `services/` — 业务逻辑（StorageService, SourceApi, LocalScanner, AudioHandler）
- `screens/` — 页面（LibraryScreen, SearchScreen, PlayerScreen, FavoritesScreen, PlaylistScreen, SettingsScreen）
- `widgets/` — 可复用组件（GlassPanel, GlassCard, AlbumArt, LiquidBottomBar, SongContextMenu）
- `config/constants.dart` — AppColors/AppSizes 集中管理

## UI 约定
- 底部导航：液态玻璃三区布局（左：音乐库圆形按钮 | 中：播放胶囊 | 右：搜索圆形按钮）
- 颜色 API: 统一使用 `withValues(alpha:)`，禁用 `withOpacity()`
- 动画曲线: 默认 easeOutCubic / easeInOut
- 弹性滚动: `BouncingScrollPhysics`

## 数据库 Schema
- music_sources — 音源表
- songs — 歌曲缓存（复合主键 id + source_key）
- favorites — 收藏关联
- recently_played — 最近播放（上限 50 条自动清理）
- playlists — 歌单元信息
- playlist_songs — 歌单-歌曲关联（sort_order 保序）

## 当前状态 (2026-07-13)
- ✅ Phase 1：Bug 修复（WidgetRef、favorites 字符串、颜色 API、依赖清理）
- ✅ Phase 2：底部导航栏三区布局
- ✅ Phase 3：Fisher-Yates 随机播放 + 音源验证 + 搜索反馈 + 后台播放
- ✅ Phase 4：SQLite 迁移 + 本地音频扫描引擎
- ✅ Phase 5：Apple Music UI + 液态玻璃加强 + 歌词双语/逐字 + 转场动画
- ✅ Phase 6：单元测试（8 个测试文件）+ App 图标/启动画面/应用名称

## 已知限制
- PlayerNotifier 依赖 AudioPlayer 实例，纯单元测试受限，使用状态模型测试覆盖
- 音源导入需服务端实现约定的 API 格式（POST /search 返回 {songs: [...]}）
- 本地扫描需 Android 存储权限，iOS 暂未实现本地文件访问
