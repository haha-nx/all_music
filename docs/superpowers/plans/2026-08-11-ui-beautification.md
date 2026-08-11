# UI 美化 + flutter_screenutil 多端适配 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 先统一美化全 App 视觉风格（iOS 大圆角、按钮圆形化、登录界面美化），最后接入 flutter_screenutil 让整个项目在不同尺寸移动设备上显示一致。

**Architecture:** 分两阶段执行，顺序不可颠倒：
- **阶段一（美化）**：不引入任何适配库，纯视觉改造——提升圆角至 iOS 大圆角体系、按钮圆形/胶囊化、登录界面美化、统一各页骨架风格。播放页此阶段零改动。
- **阶段二（适配）**：接入 flutter_screenutil（基准 390×844），全项目（**含播放页**）尺寸机械替换为 `.w`/`.sp`，圆角写死不加后缀。桌面端（Windows/Linux/macOS/Web）降级 scale≈1 保持原尺寸。

**Tech Stack:** Flutter 3.41+ / Dart 3.12+，flutter_screenutil ^5.9.3，现有 Material 3 + Cupertino 转场 + GlassPanel 液态玻璃体系。

## Global Constraints

1. **播放页双阶段约束**（`lib/screens/player/player_screen.dart`）：
   - **阶段一（美化）**：禁止任何修改，`git diff` 中该文件必须为空。
   - **阶段二（适配）**：只允许机械追加 `.w`/`.sp` 后缀、以及因 `.w/.sp` 非 const 而必须的「去 const」，去 const 时不得改变任何数值本身。**禁止改动**：圆角值、颜色、图标、布局顺序/结构、按钮形状、动画参数、行高倍数（`height: 1.4/1.3`）。验收：该文件最终 diff 的每一行都只是原数值 + 后缀（或 const 关键字移除）。
2. **适配规则（阶段二，全项目）**：
   - 长度/宽度/边距/间距/SizedBox/Positioned 偏移 → `.w`（如 `EdgeInsets.all(16.w)`、`SizedBox(height: 60.w)`、滑块轨道 `height: 3.w`）
   - 文字 `fontSize` 与 `Icon size` → `.sp`（`Icon(...size: 20)` → `20.sp`）
   - **圆角不加任何后缀**（不用 `.r` 也不用 `.w`），保持写死数值（用户已确认）
   - 倍数/无量纲值（行高 `height: 1.4`、`strokeWidth`、`blur` 模糊、`spreadRadius`、`borderWidth`、`Border.all(width: 1)`）不加后缀
   - `Duration`、动画曲线、颜色、`BoxShape.circle` 不加后缀
3. **const 处理**：`.w`/`.sp` 是运行时扩展方法，不能用于 const 上下文。含待适配数值的 `const EdgeInsets(...)`/`const TextStyle(...)`/`const SizedBox(...)`/`static const double xxx = 16` 必须去 const（`static double get xxx => 16.w`）。不含待适配数值的 const（颜色、Duration、圆角、IconData、`StadiumBorder`）保留。
4. **iOS 大圆角体系（阶段一落地，圆角一律写死不参与缩放）**：
   - 小元素/缩略图/图标容器：8–12 → 提升到 12–14
   - 卡片（GlassPanel/GlassCard 默认、歌曲卡）：16 → 18–20
   - 独立面板/弹层顶部圆角：20 → 24；24 保持
   - 胶囊按钮：`BorderRadius.circular(20)` → `StadiumBorder()`（全圆）
   - 圆形导航/图标按钮：保持 `BoxShape.circle` 或高 borderRadius（≥ 尺寸/2）
5. **按钮圆形化（阶段一落地）**：IconButton 保持圆形；`GestureDetector`+`Container` 的矩形操作按钮（登录/退出/启用/清空等）改 `StadiumBorder()`；`TextButton` 类操作改 `FilledButton`/`OutlinedButton` + `StadiumBorder`。
6. **统一页面骨架（阶段一落地）**：各页面保持既有「圆形返回按钮（GlassPanel+IconButton）→ 大标题 → 卡片分组」结构，返回按钮外径统一；大标题 `fontSize: 34` 统一；卡片间距/边距沿用 `AppSizes.paddingH` 体系，不逐页发明新间距。
7. **登录界面**：`platform_login_screen.dart` 美化；AppBar 右上角「完成（已登录）」按钮统一红色主题色 `AppColors.primary`（红底白字、胶囊形）。
8. **桌面端**：仅移动端适配。桌面平台（`!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)`）designSize 取窗口当前逻辑尺寸，scale≈1，UI 保持原样。
9. 每完成一个任务 `git commit` 一次；`flutter analyze` 零新增 error。**阶段二 Task 10 之前，项目内不得出现任何 `.w`/`.sp` 调用。**

---

## 阶段一：界面美化（不依赖 screenutil）

### Task 1: 美化规范落地到公共组件

**Files:**
- Modify: `lib/widgets/liquid_bottom_bar.dart`
- Modify: `lib/widgets/song_context_menu.dart`
- 确认不改：`lib/widgets/glass_panel.dart`、`lib/widgets/glass_card.dart`（参数化组件，播放页显式传 `borderRadius`，默认值改动会影响未传参调用方——保持不动，圆角提升在各页面调用处落地）、`lib/widgets/album_art.dart`（尺寸由调用方传入，保持不动）

**Interfaces:**
- Produces: 全 App 共用的底部导航、歌曲菜单先完成圆角/按钮体系美化；播放页引用的 `GlassPanel` 零变化。

- [ ] **Step 1: liquid_bottom_bar.dart 按钮体系检查**

核对既有 `_CircleNavButton`（`BoxShape.circle` ✓）、`_PlayerCapsule` 播放/暂停圆钮（`BoxShape.circle` ✓）——已是圆形，无需改形状；圆角 `borderRadius: 30/28` 满足大圆角体系，保持。本文件阶段一无可改项，仅记录验收点（diff 为空或仅注释）。

- [ ] **Step 2: song_context_menu.dart 圆角与按钮**

按 Global Constraints 4/5 处理：弹层顶部 `Radius.circular(20)` → `24`；行内图标容器 `borderRadius: 8` → `12`；操作项若为矩形 Container 圆角 → `StadiumBorder()`；`borderRadius: 10` 的小按钮 → `12`。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/
git commit -m "style: 公共组件 iOS 大圆角与按钮圆形化"
```

---

### Task 2: 音乐库主页美化

**Files:**
- Modify: `lib/screens/library/library_screen.dart`

- [ ] **Step 1: 圆角提升（按 Global Constraints 4）**

依据既有圆角清单逐处调整（`library_screen.dart` 中 `borderRadius:` 出现于 78/90/176/211/281/287/288/325/327/388/439/450/465/490/538/549/602/629/635/640/687/696/710/734/747/772/781/792 行附近）：
- 卡片类 16 → 20（如 L176、L439、L538）
- 弹层/面板 20 → 24（如 L211、L629 顶部圆角、L687/734/772 的 `borderRadius: 24` 保持）
- 缩略图/小元素 12 → 14、8 → 12、6 → 12（如 L490、L602、L640 图标容器 `borderRadius: 8` → `12`，尺寸 40×40 保持比例）
- 播放/更多等操作按钮若为矩形 Container → `StadiumBorder()`

- [ ] **Step 2: 统一页面骨架**

核对返回按钮（圆形 GlassPanel+IconButton）与大标题 `fontSize: 34`，与其它页面一致；不一致处修正。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/screens/library/library_screen.dart
git commit -m "style: 音乐库主页 iOS 大圆角与按钮圆形化"
```

---

### Task 3: 搜索页美化

**Files:**
- Modify: `lib/screens/search/search_screen.dart`

- [ ] **Step 1: 圆角提升**

搜索框 `borderRadius: 14` → `20`（大圆角输入框）；卡片 16 → 20（L778）；结果图标容器 8 → 12（L337/L806）；标签/筛选项 `10/12` → `12/14`；底部面板顶部圆角 `20` → `24`；矩形操作按钮 → `StadiumBorder()`。

- [ ] **Step 2: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/screens/search/search_screen.dart
git commit -m "style: 搜索页 iOS 大圆角与按钮圆形化"
```

---

### Task 4: 收藏页美化

**Files:**
- Modify: `lib/screens/favorites/favorites_screen.dart`

- [ ] **Step 1: 圆角提升**

卡片 16 → 20（L99/L119）；图标容器 12 → 14、8 → 12（L57/L183）；面板 20 → 24（L34）；操作按钮（清空/播放全部）矩形 → `StadiumBorder()`。

- [ ] **Step 2: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/screens/favorites/favorites_screen.dart
git commit -m "style: 收藏页 iOS 大圆角与按钮圆形化"
```

---

### Task 5: 歌单页美化

**Files:**
- Modify: `lib/screens/playlist/playlist_screen.dart`

- [ ] **Step 1: 圆角提升**

卡片/面板 16 → 20（L107/L140/L243）；图标容器 12 → 14、8 → 12（L185/L316）；播放/收藏按钮若为矩形 Container → `StadiumBorder()`；封面头图圆角 14 → 16（L286 附近，配合大封面）。

- [ ] **Step 2: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/screens/playlist/playlist_screen.dart
git commit -m "style: 歌单页 iOS 大圆角与按钮圆形化"
```

---

### Task 6: 播放队列页美化（属于"其他界面"）

**Files:**
- Modify: `lib/screens/player/queue_screen.dart`

**注意**：`player_screen.dart` import 本文件但仅作独立页面打开，改本文件不影响播放页外观；播放页红线不受影响。

- [ ] **Step 1: 圆角提升**

面板顶部圆角 20 → 24（L35）；缩略图 14/8 → 16/12（L59/L66/L153/L165/L181）；关闭/操作按钮保持圆形或 → `StadiumBorder()`。

- [ ] **Step 2: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/screens/player/queue_screen.dart
git commit -m "style: 播放队列页 iOS 大圆角与按钮圆形化"
```

---

### Task 7: 设置页 + 账号中心美化

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`
- Modify: `lib/screens/settings/account_center_screen.dart`

- [ ] **Step 1: settings_screen.dart 圆角与按钮**

卡片 `borderRadius: AppSizes.cardBorderRadius`（16）→ 在 `config/constants.dart` 把 `cardBorderRadius` 目标值改为 20（见 Task 9 阶段二备注：仅圆角值调整，不涉及 `.w`）；弹层/面板 20 → 24（L29/L241）；音质选择项圆角 → 12；操作按钮矩形 → `StadiumBorder()`。

- [ ] **Step 2: account_center_screen.dart 圆角与按钮**

平台卡片 `borderRadius: 18` → `20`；说明卡片 16 → 20；平台图标容器 `borderRadius: 14` 保持（已是圆角方形）；`_buildActionButton`（L346-355）`BorderRadius.circular(20)` → `shape: StadiumBorder()`；VIP 徽标 8 → 10。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings/settings_screen.dart lib/screens/settings/account_center_screen.dart
git commit -m "style: 设置页/账号中心 iOS 大圆角，操作按钮胶囊化"
```

---

### Task 8: 登录界面美化 +「完成」按钮红色主题色

**Files:**
- Modify: `lib/screens/settings/platform_login_screen.dart`

**Interfaces:**
- Consumes: `AppColors.primary`（0xFFFA2D48 红色主题色）。

- [ ] **Step 1: 完成按钮统一红色主题色**

L153-182 的 `TextButton` 改为红色主题胶囊按钮（背景 `AppColors.primary`、白字、`StadiumBorder`），`onPressed` 内部逻辑（抓 cookie、校验、SnackBar、`Navigator.pop`）一字不改：

```dart
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: () async {
                // 原 onPressed 逻辑原样保留
                ...
              },
              child: const Text('完成（已登录）'),
            ),
          ),
        ],
```

- [ ] **Step 2: 登录界面整体美化**

`AppBar`：`centerTitle: true`，`title` 文字加 `TextStyle(fontSize: 17, fontWeight: FontWeight.w600)`，`backgroundColor: Colors.transparent`（配合深色主题）。加载占位 `CircularProgressIndicator` 与 WebView 业务逻辑不碰。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings/platform_login_screen.dart
git commit -m "style: 登录界面美化，「完成」按钮统一红色主题色"
```

---

### Task 9: 音源中心子界面美化（source_hub / source_test / list / list_detail / downloads）

**Files:**
- Modify: `lib/music_source/screens/source_hub_screen.dart`
- Modify: `lib/music_source/screens/source_test_screen.dart`
- Modify: `lib/music_source/screens/list_screen.dart`
- Modify: `lib/music_source/screens/list_detail_screen.dart`
- Modify: `lib/music_source/screens/downloads_screen.dart`

- [ ] **Step 1: 逐个文件圆角提升 + 按钮圆形化**

按 Global Constraints 4/5 处理，共性：
- 底部弹层顶部圆角 `Radius.circular(20)` → `24`（source_hub L101-102/L207-208、list L53/L76）
- 卡片 16 → 20（list L229/L234、list_detail L320/L323）
- 图标容器/标签 8 → 12、12 → 14（各文件 `borderRadius: 8/12` 处）
- 启用/停用/清空等矩形操作按钮 → `StadiumBorder()`
- downloads 进度容器圆角 8 → 12、列表缩略图 14 → 16

- [ ] **Step 2: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/music_source/screens/
git commit -m "style: 音源中心子界面 iOS 大圆角与按钮圆形化"
```

---

## 阶段二：接入 flutter_screenutil + 全项目尺寸适配

### Task 10: 接入 flutter_screenutil 并适配 AppSizes

**Files:**
- Modify: `pubspec.yaml`（dependencies 区）
- Modify: `lib/main.dart`
- Modify: `lib/config/constants.dart`

**Interfaces:**
- Produces: `ScreenUtilInit` 包裹 `MusicApp`，全局可用 `.w`/`.sp`；`AppSizes` 尺寸成员变 `static double get`（`.w` 适配），圆角成员（`borderRadius`/`cardBorderRadius`/`navBarRadius`）保持 `static const double` 原值。`AppColors` 不动。

- [ ] **Step 1: 添加依赖**

`pubspec.yaml` dependencies 区（`# Utilities` 分组下）：

```yaml
  # Screen adaptation (multi-device)
  flutter_screenutil: ^5.9.3
```

Run: `flutter pub get`
Expected: 成功，无版本冲突。

- [ ] **Step 2: main() 按平台计算 designSize 并接入**

`lib/main.dart`：加 `import 'package:flutter_screenutil/flutter_screenutil.dart';`，`runApp(...)` 替换为：

```dart
  // ScreenUtil 适配：移动端基准 390×844；桌面端 scale≈1（不放大）
  final binding = WidgetsFlutterBinding.instance; // ensureInitialized 已调用
  final isDesktop = !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  Size designSize = const Size(390, 844);
  if (isDesktop) {
    final view = binding.platformDispatcher.views.first;
    designSize = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
  }
  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => const MusicApp(),
      ),
    ),
  );
```

（`kIsWeb` 由 `package:flutter/foundation.dart` 提供；`Platform` 由现有 `dart:io` import 提供。）

- [ ] **Step 3: AppSizes 适配化**

`lib/config/constants.dart` 加 `import 'package:flutter_screenutil/flutter_screenutil.dart';`，`class AppSizes` 替换为：

```dart
/// 全局尺寸常量 — 移动端按 390x844 基准缩放（长宽 .w），圆角不缩放
class AppSizes {
  static double get barHeight => 64.w;
  static double get paddingH => 20.w;
  static double get paddingV => 16.w;
  static double get spacing => 8.w;
  static double get playPillHeight => 56.w;
  static double get albumArtSize => 48.w;
  static double get miniAlbumArtSize => 36.w;
  static const double borderRadius = 12; // 圆角不缩放
  static const double cardBorderRadius = 20; // 圆角不缩放（阶段一已把目标值提到 20）
  static const double navBarHeight = 60; // 若使用，改为 60.w；未使用的成员删除
  static const double navBarRadius = 28; // 圆角不缩放
  static double get navBarBottom => 16.w;
}
```

`AppColors` 保持 `static const` 原样，一行不改。

- [ ] **Step 4: 验证**

Run: `flutter analyze`
Expected: 报出引用了 `AppSizes` getter 的 const 上下文错误——这是预期信号，由后续各任务在自己的文件内去 const。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/config/constants.dart
git commit -m "feat: 接入 flutter_screenutil（移动端 390x844 适配，桌面端不缩放）"
```

---

### Task 11: 公共组件尺寸适配

**Files:**
- Modify: `lib/widgets/liquid_bottom_bar.dart`
- Modify: `lib/widgets/song_context_menu.dart`
- 确认不改：`glass_panel.dart`/`glass_card.dart`/`album_art.dart`（无内部写死尺寸，全部参数化；`album_art` 的 `size`/`borderRadius` 由调用方传入）

- [ ] **Step 1: liquid_bottom_bar.dart 适配**

加 screenutil import，按 Global Constraints 2/3：
- `EdgeInsets.symmetric(horizontal: 36, vertical: 24)` → `36.w/24.w`；`height: 60` → `60.w`；`SizedBox(width: 16)` → `16.w`
- `_CircleNavButton`：`width/height: 60` → `60.w`；`Icon size: 22` → `22.sp`；圆角 30 保持
- `_PlayerCapsule`：`height: 60` → `60.w`；`padding: horizontal: 10, vertical: 5` → `.w`；`AlbumArt size: 32` → `32.w`；`SizedBox(width: 10/6)` → `.w`；`fontSize: 12/10` → `.sp`；播放钮 `width/height: 34` → `34.w`、`Icon size: 20` → `20.sp`；圆角 28 保持
- `_EmptyCapsule`：`height: 60` → `60.w`；`fontSize: 11` → `11.sp`
- `PlayerCapsuleBar`：`EdgeInsets.fromLTRB(20, 0, 20, 16)` → `20.w/16.w`

- [ ] **Step 2: song_context_menu.dart 适配**

加 screenutil import；全部 `EdgeInsets`/`SizedBox`/`fontSize`/`Icon size` → `.w/.sp`；行高倍数、`Divider`、`borderWidth`、圆角保持。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/
git commit -m "feat: 公共组件 screenutil 尺寸适配"
```

---

### Task 12: 各界面尺寸适配（不含播放页）

**Files:**
- Modify: `lib/screens/library/library_screen.dart`
- Modify: `lib/screens/search/search_screen.dart`
- Modify: `lib/screens/favorites/favorites_screen.dart`
- Modify: `lib/screens/playlist/playlist_screen.dart`
- Modify: `lib/screens/player/queue_screen.dart`
- Modify: `lib/screens/settings/settings_screen.dart`
- Modify: `lib/screens/settings/account_center_screen.dart`
- Modify: `lib/screens/settings/platform_login_screen.dart`
- Modify: `lib/music_source/screens/source_hub_screen.dart`
- Modify: `lib/music_source/screens/source_test_screen.dart`
- Modify: `lib/music_source/screens/list_screen.dart`
- Modify: `lib/music_source/screens/list_detail_screen.dart`
- Modify: `lib/music_source/screens/downloads_screen.dart`

- [ ] **Step 1: 逐文件机械适配**

每个文件加 `import 'package:flutter_screenutil/flutter_screenutil.dart';`，按 Global Constraints 2/3 全文件处理：
- `EdgeInsets`/`SizedBox`/`Container width/height`/`Positioned` 偏移/滑块尺寸 → `.w`
- `fontSize` → `.sp`；`Icon size` → `.sp`（含 `AlbumArt(size: ...)` → `size: xxx.w`）
- `AppSizes` getter 引用处去 const（如 `const EdgeInsets.fromLTRB(AppSizes.paddingH, ...)` → 去掉 const）
- 圆角保持写死值（阶段一已定的新值），不加后缀
- 圆角、行高倍数、`blur`、`strokeWidth`、`borderWidth`、颜色、Duration 一律不动

改造顺序建议：先 `settings_screen.dart`/`account_center_screen.dart`（修复 Task 10 遗留的 const 编译错），再其余文件。每改完 2-3 个文件跑一次 `flutter analyze` 定位遗漏。

- [ ] **Step 2: 全量验证**

Run: `flutter analyze`
Expected: 0 error，0 新增 warning。

- [ ] **Step 3: Commit**

```bash
git add lib/screens/ lib/music_source/screens/
git commit -m "feat: 各界面 screenutil 尺寸适配（.w/.sp，圆角不缩放）"
```

---

### Task 13: 播放页仅尺寸适配（不美化）

**Files:**
- Modify: `lib/screens/player/player_screen.dart`

**红线（Global Constraints 1 阶段二）**：只允许数值后追加 `.w`/`.sp` 与必要「去 const」，不得改变任何数值本身、圆角、颜色、图标、布局结构、按钮形状、动画参数、行高倍数。

- [ ] **Step 1: 机械替换**

加 screenutil import。按以下清单逐行处理（行号基于当前文件）：
- `const Icon(...size: 20/32/18/36/24/28)` → 去 const，`size: xx.sp`（L68/L327/L363/L383/L797/L824/L854/L887/L923）
- `const SizedBox(width: 12/10/16/height: 12/4/16/...)` → 去 const，数值 `.w`（L69/L211/L223/L232/L241/L366/L386/L417/L439/L562/L959/L980）
- `const EdgeInsets.all(16)` → `EdgeInsets.all(16.w)`（L75/L969）；`const EdgeInsets.fromLTRB(28, 8, 28, 0)` → `28.w/8.w/28.w/0`（L411）；`EdgeInsets.symmetric(horizontal: 16, vertical: 10)` → `.w`（L912）；`EdgeInsets.symmetric(horizontal: 4)` → `4.w`（L590/L684）；`EdgeInsets.only(top: 3)` → `3.w`（L500）；含 `AppSizes.paddingH` 的 const（L192/L201/L218/L227/L236/L458）→ 去 const
- `fontSize: 14/32/22/15/12/13/16` 等 → `.sp`（L95/L106 的 `mainSize`/`trSize` 变量 → `(mainSize).sp`；L334/L370/L392/L442/L490/L504/L554/L566/L691/L698/L728/L765/L779/L930/L973）；行高 `height: 1.4/1.3` 保持
- 歌词行高 `rowH + _lyricsRowGap`（L480）——`rowH`/`_lyricsRowGap` 若由 `fontSize` 派生则天然适配，不改
- 滑块：`height: _isDraggingSeekBar ? 44 : 28` → `44.w/28.w`（L628）；`height: 8 : 3` → `8.w/3.w`（L635/L645）；`width/height: 22 : 14` → `22.w/14.w`（L659/L660）
- 播放按钮容器 `width: 64, height: 64` → `64.w`（L809-810）；`Icon size: 36` → `36.sp`（L817）
- 底部面板 `width: 36, height: 4`（L961-962，拖动指示条）→ `36.w/4.w`
- `Container(width: 1)`（L918，边框）保持（borderWidth 类）
- 圆角全部保持（L76/L804/L915/L952 的 `RoundedRectangleBorder(borderRadius: ...)` 与 `borderRadius: 30/20` 不动）

替换时若目标表达式已在非 const 上下文，直接加后缀即可；每处替换不得改变数值大小。

- [ ] **Step 2: 播放页 diff 自检**

Run: `git diff lib/screens/player/player_screen.dart`
人工逐行核对：每一行改动仅是「数值 + 后缀」或「const 关键字移除」，出现任何圆角值/颜色/布局/形状变化立即回退该行。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/screens/player/player_screen.dart
git commit -m "feat: 播放页仅 screenutil 尺寸适配（不美化）"
```

---

### Task 14: 全量验证与回归

**Files:**
- Verify: 全部改动文件

- [ ] **Step 1: 静态检查**

Run: `flutter analyze`
Expected: 0 error，0 新增 warning。

- [ ] **Step 2: 测试回归**

Run: `flutter test`
Expected: 全部通过。

- [ ] **Step 3: 播放页红线回归**

Run: `git log --oneline -3 -- lib/screens/player/player_screen.dart` 与 `git diff <阶段一结束commit> HEAD -- lib/screens/player/player_screen.dart`
Expected: 阶段一期间播放页无任何提交；阶段二仅 Task 13 一个「尺寸适配」提交，且其 diff 仅含 `.w/.sp` 追加与去 const。

- [ ] **Step 4: 全量 diff 复查**

Run: `git diff --stat <阶段一开始commit>`
人工复查：改动集中在计划列出的文件；无遗留 const 编译残留、无多余文件。

- [ ] **Step 5: 构建冒烟（可选，Android 耗时较长）**

Run: `flutter build apk --debug`
Expected: 构建成功。若环境不允许构建，以 analyze+test 为准并在提交说明中注明。

- [ ] **Step 6: Commit（如有遗漏修复）**

```bash
git add -A
git commit -m "chore: 全量回归修复"
```

---

## 验收清单（对照用户原始需求）

- [ ] 先美化后适配：阶段一（美化）不含任何 screenutil 代码；阶段二才导入 ScreenUtilInit
- [ ] 播放页不美化，但完成 `.w/.sp` 尺寸适配；其 diff 仅含数值后缀与去 const，无视觉改动
- [ ] 所有其他界面完成 iOS 大圆角提升 + 按钮圆形/胶囊化 + 尺寸适配
- [ ] 尺寸/间距 `.w`，文字/图标 `.sp`，圆角写死未加 `.r`
- [ ] 登录界面美化，「完成（已登录）」按钮为红色主题色（AppColors.primary）
- [ ] flutter_screenutil 已接入，移动端不同尺寸显示一致，桌面端不放大
- [ ] `flutter analyze` / `flutter test` 通过
