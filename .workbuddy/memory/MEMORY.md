# 项目记忆 — All Music

## 架构决策

### 音源模块（2026-07-16 全新搭建）
- 位置：`lib/music_source/`
- 旧音源代码（`lib/services/source_engine.dart` 等）保持不变，新旧并行
- 新模块采用分层架构：core → models → services → providers → screens
- JS运行时使用 flutter_js (QuickJS)，通过消息通道与Dart Dio桥接
- LX Music源脚本兼容：lx.send/lx.on 事件模型 + module.exports 老格式
- 内置源通过 `assets/scripts/sixyin_latest.js` 分发，首次启动加载

### 数据模型
- `SourceDefinition` — 音源定义（替代旧 MusicSource）
- `MusicTrack` — 搜索结果模型（替代旧 Song 在搜索层的使用）
- `TrackAdapter` — 新旧模型转换器，桥接播放器

### 状态管理
- Riverpod StateNotifierProvider
- `sourceListProvider` 管理音源列表
- `searchProvider` 管理搜索结果
- `downloadProvider` 管理下载任务

## 第一阶段：内置示例源
- 六音音源（builtin_sixyin）作为内置源测试
- 通过 `/source-test` 路由访问测试工具

## 第二阶段计划（待实施）
- 将导入功能从测试转为正式
- 用户通过粘贴/URL自行导入音源
- 替换旧版音源管理
