---
所属: 谛听 Flutter UI 框架
状态: 第二阶段（应用层 + 演示页面）完成，可 flutter run
最后校验: 2026-10-19
口径: 所有行数/文件数/命令输出均来自 2026-10-19 本会话真实工具输出
---

# 20 · 交接：已完成什么、下一步怎么写

> 本文是给「接下来的会话」看的。它不重复 FlClash 的设计细节（那些在上游源码与
> `docs/refactor/12-ui-components*.md` 里），只写**本仓库当下的真实状态**、
> **已经冻结的约定**、**尚未写的那部分应该怎么接**。

## 1. 一句话状态

`lib/ui/` 是 FlClash 0.9.1 设计系统的完整移植；应用层（`lib/app/` + `lib/router.dart` +
`lib/shell/`）、演示状态（`lib/state/`）、演示数据（`lib/data/`）与 **73 条路由**
（16 基线 + 57 领域）全部写完。第二轮按领域补齐了上游全部可见页面：
仪表盘 10 张卡片 + 编辑模式、代理域、观测域、配置档案域、内核配置域（16 页）、
系统/外观/表单域（19 页 + 5 个表单演示页）。

实测（2026-10-19 第二轮收官）：`dart analyze lib test` → **No issues found**；
`flutter test` → **62 个用例全绿**（含全路由构建、功能中心卡片可达性、
3 档尺寸 × 1.4 倍字号的布局回归）；`lib/` **369 文件 / 79,504 行**，
`lib/pages/` **186 文件 / 39,778 行**（第二轮前 43 文件 / 10,514 行，**3.78×**）；
所有文件 ≤550 行（最大 `pages/system/editor_page.dart` 532 行）。
**`flutter run` 现在可以启动**；`flutter build apk --debug` 也已实测出包（157 MB，见 §6），
要跑桌面/Web 需先 `flutter create . --platforms windows,web`。

## 2. 已完成清单（可直接依赖）

### 2.1 设计系统 `lib/ui/`

| 项 | 实测 |
|---|---|
| 文件数 | 127 个 `.dart`（`lib/ui/` 113 根文件 + `icons/` 12 + `support/` 2） |
| 总行数 | 28,261 |
| 上游对照 | FlClash `lib/ui/` 82 个根文件 / 25,948 行 → 移植后按 ≤550 行拆成 113 个 |
| 编译 | `flutter analyze lib test` → **No issues found** |
| 最大文件 | `navigation_dock_c.dart` 549 行（全部 ≤550） |
| 未引用文件 | 0（`ui.dart` barrel 除外，它按设计就是入口） |

**已冻结的公开 API**（改这些会破坏后续页面）：

- 主题：`seededColorScheme({seedColor, brightness, style})`、`ColorScheme.toPureBlack(bool)`、
  `ThemeData.withAppShapes` / `.withAppSurfaces` / `.withAppTypography` / `.elevated`
- 令牌：`AppCorner`（none/xs/sm/md/lg/xl/xxl/alert/full）、`AppRadius`、`AppShape`
  （`RoundedSuperellipseBorder`）、`AppTextStyle`（display…caption2，`.of(context)`）、
  `SurfaceLevel`（page/card/block/inset，`.colorOf(scheme)`、`context.surfaceLevel`）
- 图标：`AppGlyphs.*`（122 个常量）、`GlyphIcon(glyph, size:, color:)`、`AnimatedGlyph`
- 容器：`CommonScaffold(body:, title:, actions:, primaryAction:, menuItems:, searchState:, isLoading:)`、
  `CommonCard`、`ListItem`（默认 / `.open` / `.next` / `.options` / `.input` / `.toggle`）、
  `DecorationListItem`（缝合卡行）、`ListHeader` / `ListFooter`
- 浮层：`showFloatingDialog`、`CommonDialog` + `AlertActions`、`CommonPopupBox` +
  `CommonPopupMenu` + `CommonPopupMenuItem`、`showSheet` / `showFormSheet` / `showExtend`、
  `OpenContainer`
- 反馈：`CommonCircleLoading`、`NullStatus`（含 `EmptyIllustration`）、`SkeletonText` /
  `SkeletonPill`、`TonalButton` / `TonalButtonGroup`、`CommonChip` / `TonalChip` / `MetaChip`、
  `SegmentedControl`、`SearchField`、`LineChart`

### 2.2 测试 `test/`

| 文件 | 作用 |
|---|---|
| `support/app_host.dart` | **测试宿主**：`MaterialApp` + 主题 + `UiLocalizations` + `MeasureScope` + `ViewScope` |
| `support/ui_localizations_stub.dart` | `lib/ui` 要求的 14 条界面文案（中文） |
| `ui_components_smoke_test.dart` | 8 个用例：脚手架 / 列表三种构造器 / 浮条 / 空态 / 加载 / 菜单 / 对话框 / 底部面板 |

`AppHost` 的注释里写了两个必须记住的坑，见 §3.1。

### 2.3 工具与合规

| 文件 | 说明 |
|---|---|
| `NOTICE.md` | FlClash 来源、逐文件移植范围、未移植清单（4 个桌面文件）、第三方包许可 |
| `LICENSE` | GPL-3.0 全文（上游副本） |
| `lib/ui/analysis_options.yaml` | 只在 `lib/ui` 关闭 3 条与上游风格冲突的 lint；`lib/app` 仍全量生效 |
| `tool/glyphsplit.dart` | 把 `app_glyphs.dart` 拆成根 + 5 个 part（保留公共 API 的转发成员） |
| `tool/partsplit.dart` | 按行区间把库根文件拆成 part |
| `tool/extsplit2.dart` | 把 State 类的方法段抽成同库 `extension` |
| `tool/unreferenced.py` | 列出没有任何 import/export/part 指向的 Dart 文件 |
| `tool/diff_upstream.py` | 与 FlClash 上游做文件级/行数级对账 |

### 2.2 应用层 `lib/app/` + 入口

| 文件 | 行数 | 职责 |
|---|---|---|
| `lib/main.dart` | 12 | 唯一 `runApp`：`ProviderScope(child: DitingApp())` |
| `lib/app/app.dart` | 78 | `MaterialApp.router`：主题、路由、l10n、`ThemeCrossFade`、`AppScopes` |
| `lib/app/theme/manager.dart` | 159 | `AppThemeSpec` / `buildAppTheme` / `AppThemeCache` / `AppThemePair` |
| `lib/app/theme/colors.dart` | 56 | `defaultPrimaryColor` + `AppPalette`（9 色板）+ `AppThemeMode` |
| `lib/app/theme/layout.dart` | 22 | `maxMobileWidth` / `maxLaptopWidth` / `clampTextScale` / `maxDockDestinations` |
| `lib/app/l10n/ui_strings.dart` | 96 | `UiLocalizations` 的中文实现（14 条） |
| `lib/app/bootstrap.dart` | 90 | `AppScopes`（builder 装 scopes + 字号钳制）、`AppSystemUi` |
| `lib/router.dart` | 168 | `Routes` 常量 + `_branchOrder` + `createRouter()` |

### 2.3 壳层 / 状态 / 数据 / 页面

| 目录 | 内容 |
|---|---|
| `lib/shell/` | `AppShell`：六 tab `indexedStack` + `NavigationDock`（>5 项或非移动端降级 `NavigationBar`） |
| `lib/state/` | `appearance_providers`（主题/色板/纯黑/字号/透明度/句子/底栏/触感/解析模式）、`work_mode_providers`（工作模式/电源/服务商/竞速/端口/服务状态/引导）、`rules_providers`、`subscription_providers`、`app_selection_providers` |
| `lib/data/` | `mock_data.dart` 拆 3 个 part：`mock_providers`（服务商/规则）、`mock_content`（订阅/日志/缓存/竞速/统计）、`mock_apps`（流量/应用/功能卡/采样） |
| `lib/widgets/` | `stat_strip.dart`（`StatStrip` / `KeyValueRow` / `SectionBlock` / `PageBody` / `DockSpacer`）、`glyph_lookup.dart`（名字→Glyph，122 项） |
| `lib/pages/` | 18 条路由，见 §4.1 |

### 2.4 测试

| 文件 | 用例 | 守什么 |
|---|---|---|
| `test/ui_components_smoke_test.dart` | 8 | 移植层组件不回归 |
| `test/app_shell_test.dart` | 5 | 首页渲染、电源四态、tab 保活、浮层可弹、全路由可构建 |
| `test/app_layer_test.dart` | 28 | 主题装配顺序/缓存上界/色板/断点/provider 不变量 |
| `test/scope_placement_test.dart` | 2 | **scopes 必须在 `Navigator` 之上**（正例 + 反例） |
| `test/enum_display_test.dart` | 5 | 展示文案不得漏出枚举源码标识符 |
| `test/layout_regression_test.dart` | 4 | 18 路由 × 3 档尺寸 + 小屏 1.4 倍字号无溢出 |
| `test/support/` | — | `app_host.dart`、`demoTheme`、`UiLocalizations` stub |

## 3. 必须知道的约束与坑

### 3.1 `lib/ui` 的运行时前置条件（宿主必须装在 `Navigator` 之上）

移植层大量 `assert(scope != null)`，**缺一个就直接崩**：

1. `MeasureScope(measure: Measure.of(context, scale))` —— `CommonCard`、`ListHeader`、`AppTextStyle` 的测量都用它；
2. `ViewScope(size:, isMobile:)` —— 决定 `showSheet` 走底部面板还是侧栏；
3. `UiLocalizations`（`Localizations` delegate）—— 搜索框、更多菜单、返回、取消等文案；
4. 还有 `MaterialLocalizations`（`MaterialApp` 自带，见 §3.2）。

**正确装法：`MaterialApp.builder`。** 它的 `child` 就是 `Navigator` 本身，scopes 包在外面，
于是所有路由**和浮层**都读得到。

> ⚠️ **本文旧版把这条写反了**，原话是「宿主必须挂在 `Navigator` 之下，即 `home:` 里，
> 挂 builder 会报 `Navigator operation requested with a context that does not include a
> Navigator`」。该结论先后被推翻两次，最终由 `test/scope_placement_test.dart` 的两条
> 用例钉死：
>
> - 装 `builder`：路由与浮层都能读到 scope ✅
> - 装 `home:`：`showSheet` / `showFloatingDialog` 的监听器挂在根 `Navigator` 上，是与
>   `home:` **平级的兄弟路由**，覆盖不到 → 浮层内一读 `ViewScope` 就
>   `Failed assertion: 'scope != null': No ViewScope found above Builder(dirty)` ❌
>
> 两次误判的共同原因是**探针不够狠**：第一次拿根本不会 assert 的 `CommonCard` 当浮层
> 内容，两种装法都「通过」，于是把假阴性当成了证据写进文档。要复现必须用会真正读
> scope 的代码（如 `ViewScope.isMobileOf`）。
>
> `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 现在装法一致，**改一处必须
> 同步另一处**，否则「单组件测试」和「整机测试」会给出不同结论。

### 3.2 `locale: zh_CN` 必须配 `GlobalMaterialLocalizations`

`DefaultMaterialLocalizations` 只有 en_US。直接 `locale: Locale('zh','CN')` 会先警告
locale 不受支持，然后在 `AppBar` build 时抛 `No MaterialLocalizations found`。
正确写法（`lib/app/app.dart`）：

```dart
localizationsDelegates: const [
  AppUiLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates, // 同时含 Cupertino / Widgets
],
```

`GlobalMaterialLocalizations` 来自 `material_ui`（复用 intl 的生成物），**不需要**额外
加 `flutter_localizations` 依赖。

### 3.3 主题必须走 `AppThemeCache`，且组装顺序不能变

`ThemeData` 每次重建都不相等，`ThemeCrossFade` 正是靠这一点淡入上一帧。不缓存的话
改任何一个无关状态（比如勾一个开关）都会让整屏闪一下。`AppThemeCache` 用 FIFO 上界
（16 项）防止拖调色板时无限增长。

组装顺序：`seededColorScheme` → `.toPureBlack(bool)` → 深色时加 `ElevatedColorScheme`
扩展 → `.withAppShapes` → `.withAppSurfaces` → `.withAppTypography`。
顺序错了纯黑会被后面的 surface 重新算回带色偏的深色（`test/app_layer_test.dart` 有用例守）。

### 3.4 底栏下标 ≠ branch 下标

用户可配置底栏项（2–5 项），而 `StatefulShellRoute` 的 branch 顺序是固定的。
`lib/router.dart` 的 `_branchOrder` 与 `createRouter()` 的 branch 声明顺序一一对应，
`AppShell` 负责两者映射。**重排 branch 会打乱所有 `goBranch` 调用**。

### 3.5 枚举上屏必须取 `.label`

裸枚举插值会渲染成 `ProviderProtocol.doh` 这种源码字形，analyze 和路由冒烟都拦不住。
`test/enum_display_test.dart` 对全部会产出用户可见文案的枚举做源码标识符扫描
（历史上 `providerEndpointOf` 就踩过，已修）。

### 3.6 拆分规则（新增文件也要守）

AGENTS.md 硬性要求 ≤550 行。已用的三种拆分法都在 `tool/` 里：

- **库级拆 part**（`partsplit.dart`）：适合一堆顶层类/函数；part 文件写 `part of 'x.dart';`
- **单类拆 part**（`glyphsplit.dart`）：Dart 不允许类跨 part，因此把成员改成顶层私有
  `_g_<name>_`，类里保留 `static const name = _g_name_;` 转发，调用点不变；
- **State 类方法抽 extension**（`extsplit2.dart`）：同库 `extension XBuild on X` 可访问私有成员；
  但**类内 `static` 成员必须先提到库级私有**，否则报
  `unqualified_reference_to_static_member_of_extended_type`。

### 3.7 `models.dart` 是手写的，不是 freezed

上游 `IconButtonData` / `AppBarState` / `AppBarSearchState` 由 freezed 生成。本仓库
`lib/ui/models.dart` 手写了等价类，`copyWith` **用 `_keep` 哨兵复刻 freezed 语义**：
省略参数 = 保留旧值，显式传 `null` = 置空。`scaffold.dart:259` 的
`copyWith(query: null)` 依赖后者，**不要改成 `??` 写法**。

### 3.8 玻璃（Liquid Glass）保留但默认关闭

`lib/ui/liquid_glass*.dart`（2,494 行）与 `shaders/liquid_glass.frag` 都完整移植，
`pubspec.yaml` 已声明 `shaders:`。`LiquidGlassScope.of(context)` 默认 false，各组件自动走
非玻璃回退。要做玻璃效果时打开 scope 即可，不需要恢复代码。

## 4. 应用层剩余可做的事

`lib/ui/`、`lib/app/`、`lib/router.dart`、`lib/shell/`、`lib/state/`、`lib/data/` 与
18 条页面都已写完。下面都是**增量**，不是「还没开始」：

1. **补平台目录**：本机只有 `android/`（Android 已能出包，见 §6）；要 `flutter run`
   到桌面或浏览器，先 `flutter create . --platforms windows,web`。
   `lib/app/theme/layout.dart` 的 `maxLaptopWidth` 与 `AppShell._Dock` 的非移动端分支
   已经写好，但没有平台目录就只在测试里跑到过。
2. **持久化**：`lib/state/` 全是纯内存状态。接真实存储时替换各 `Notifier.build()` 的
   默认值即可，页面无需改动。
3. **`NullStatusSwitcher` 未上屏**：它需要 loading/empty 状态机，放进静态画廊会引入
   定时器（画廊已经为此把 `repeat()` 动画套了 `TickerMode`）。需要时再补。
4. **视觉走查**：所有验证都是 widget 级断言，**没有真机截图**。`_PaletteDot` 打勾的
   对比色、AI 气泡宽度上限（78%）、首页电源按钮的光晕层次值得 `flutter run` 时过一眼。
5. **`lib/ui` 里仍未被页面用到的组件**：跑 `python -I tool/unreferenced.py` 看最新清单，
   需要的话往 `lib/pages/demo/` 补一区——画廊已覆盖 122 个 `AppGlyphs` 与绝大多数容器，
   是最省事的落点。

### 4.1 页面清单（已实现，供对照）

| 路由 | 页面 | 实现要点 |
|---|---|---|
| `/` | 首页（三模式共用壳） | 电源四态 + 光晕、模式 chip、服务商卡、解析模式、快捷入口、四层透明度 |
| `/hub` | 功能中心 | 5 分类 19 卡，2 列网格，按下 0.90 缩放 |
| `/rules/:kind` | 规则列表（黑/白/覆写共模板） | StatStrip + 防抖搜索 + 来源 chips + 分组列表 + 行内 Switch/More；白名单有只读保护，覆写显示 `pattern → target` |
| `/rules/batch` | 批量编辑器 | 大文本框 + 解析计数（有效/重复/拒收）+ `#@#` 拒收文案 |
| `/subscriptions` | 订阅 | 汇总条 + 分组 chips + 卡片（含错误态/更新进度）+ 添加面板 |
| `/apps` | 应用选择 | 防抖搜索 + 按分类分组 + 整行圆形勾选 + 全选/反选只作用当前可见集 |
| `/logs` | 日志仪表盘 | 三视图（请求/缓存表/竞速排行）+ 搜索 + 处置筛选 + 详情面板 + 清空确认 |
| `/traffic` | 流量 | 实时/今日/本周 + `LineChart` + 应用排行（自绘占比条） |
| `/tools` | 网络工具 | 测速/Ping/DNS/路由四个 `showSheet` 面板，各有运行态与结果区 |
| `/settings` | 设置 | 外观/首页/底栏/解析/关于五组；拆库根 + 5 个 part |
| `/agent` | AI 助手 | 聊天气泡 + 快捷提问 + 800ms 模拟回复 + 空态 |
| `/about` | 关于 | 图标/名称/版本 + 说明卡 + 许可/组件/链接行 |
| `/server` | 服务器模式 | 复用 `HomePowerButton` + 五态文案 + 上游抽屉 + 局域网多 IP×端口 + 5 项统计 |
| `/mode/select` | 工作模式选择 | 三卡 + `AnimatedSize` 特性清单 |
| `/mode/onboarding` | 三步引导 | `PageView` + 指示器 + 完成回首页 |
| `/demo` | 组件画廊 | 14 文件（库根 + 13 part），覆盖排版/颜色/形状/图标/按钮/标签/输入/列表/卡片/浮层/反馈 |

### 4.2 路由与导航约定（已落地）

- 六个 tab 走 `StatefulShellRoute.indexedStack`：**branch 自带 `Navigator`，切 tab 不销毁**，
  所以不要额外套 `KeepScope`；
- 底栏用 `NavigationDock`（浮条），宽度非移动端或超过 5 项时降级为 `NavigationBar`；
- 列表底部留白用 `DockSpacer`（= `NavigationDock.insetOf(context) + extra`），
  `CommonScaffold` 里 `extendBody: true`；
- 二级页面用 `context.push`，`pageTransitionsTheme` 统一 `commonSharedXPageTransitions`；
- 模式选择页与引导页**不在** shell 里（全屏、无底栏），用 `parentNavigatorKey: rootNavigatorKey`。

## 5. 验证口径

每完成一个阶段，串行跑（**不要并行**，Gradle/分析器会争锁）：

```bash
flutter analyze lib test
```

```bash
flutter test
```

再加两条人工检查：

```bash
for f in $(find lib test -name '*.dart'); do n=$(wc -l < "$f"); [ "$n" -gt 550 ] && echo "$n $f"; done
```

```bash
python -I tool/unreferenced.py
```

实测（2026-10-19 第二轮）：`dart analyze lib test` → **No issues found**；`flutter test`
→ **62 个用例全绿**。覆盖面如下：

| 测试文件 | 覆盖的东西 |
|---|---|
| `test/app_shell_test.dart` | 整机冒烟：首页渲染、电源按钮加载态、底栏 tab 保活、浮层能读 scope、全部路由能构建 |
| `test/route_catalog_test.dart` | 功能中心每张卡片的 route 必须真实注册；每条路由构建后**不得落到 `UnknownRoutePage`**；兜底页自身行为 |
| `test/layout_regression_test.dart` | 全部路由 × 320/412/834 三档宽度，再加 320 宽 × 1.4 倍字号，逐条查溢出 |
| `test/scope_placement_test.dart` | scopes 必须装在 `MaterialApp.builder`（含故意复刻错误装法的反例） |
| `test/ui_components_smoke_test.dart` | 设计系统主要组件渲染与浮层开关 |
| `test/proxies_interaction_test.dart` | 代理域真实交互：节点选中迁移、单组测速的「测速中 → 结算」、tab↔list 切换、搜索过滤、提供者全量更新 |
| `test/app_layer_test.dart` / `enum_display_test.dart` | 应用层装配、枚举 `label` 不泄漏源码字形 |

**测试期必须关掉永动动画**：`test/support/test_hooks.dart` 的
`installGlobalTestHooks()` 会把 `debugDisableDashboardLiveUpdates` 置真。任何挂载
`DitingApp`（含首页）的新测试文件都要在自己的 `main()` 顶部调一次，否则
`pumpAndSettle` 会因为首页速率曲线与配置卡波浪进度条而**永远超时**。

## 6. Android 构建（旧结论已证伪，现可正常出包）

### 6.1 现状：能构建

实测（2026-10-19）：

```
flutter build apk --debug
→ build/app/outputs/flutter-apk/app-debug.apk   157 MB   12:47:17
```

首次构建耗时集中在**一次性环境准备**（合计约 3 GB）：

| 下载项 | 实测大小 | 落地位置 |
|---|---|---|
| Gradle 9.3.1 发行版 | 224 MB | `~/.gradle/wrapper/dists/gradle-9.3.1-all/` |
| NDK 28.2.13676358 (r28c) | ~2.1 GB | `~/AppData/Local/Android/Sdk/ndk/28.2.13676358/` |
| SDK Platform 36 | ~100 MB | `~/AppData/Local/Android/Sdk/platforms/android-36/` |
| Gradle 依赖（AGP 9.1.0 / Kotlin 2.4.0 等） | 数百 MB | `~/.gradle/caches/` |

之后是增量编译，几十秒级。

### 6.2 旧结论为什么错了（反例，勿再引用）

本文旧版 §6 写着「`services.gradle.org` / `repo1.maven.org` / `plugins.gradle.org`
全不可达，仅腾讯镜像 200，因此 `flutter build apk` 无法完成」。**该结论是错的**，
2026-10-19 复测：

| 目标 | 实测 |
|---|---|
| `services.gradle.org/distributions/` | **200**（1.3s） |
| `repo1.maven.org/maven2/` | **200**（0.7s） |
| `plugins.gradle.org/m2/` | **200**（1.2s） |
| `services.gradle.org/.../gradle-9.3.1-all.zip` | **200**（224 MB 下载成功） |
| `dl.google.com/.../gradle-8.9.1.pom` | **200** |
| `mirrors.cloud.tencent.com/gradle/` | 200 |

推断当时失败的真实原因有两个，都与「网络封锁」无关：

1. **首次构建本来就要下 3 GB**，没等够就当成卡死了；
2. **看进度的命令写错了**：`flutter build apk ... | Select-Object -Last N` 会缓冲全部
   输出直到进程结束，中间十分钟一个字节都不显示，主观上完全像卡住。

**教训**：判「网络不可达」必须用 `curl`/`Invoke-WebRequest` 打**真实构件 URL**（不是
域名根路径——根路径 404/400 是正常的，`dl.google.com` 与 `storage.googleapis.com` 就是），
并且要区分「慢」与「断」。构建类长任务一律写日志文件 + `Get-Content -Tail` 跟进度，
不要用会缓冲的管道过滤器。

### 6.3 命令

```powershell
# 首次：约 3 GB 下载，耐心等；用日志文件跟进度
flutter build apk --debug *> build.log
Get-Content build.log -Tail 20

# 之后：增量
flutter build apk --debug
```

## 7. 提交约定

- 中文 Conventional Commits，一个阶段一个提交；
- 每个提交前确认：`analyze` 零问题、`test` 全绿、文件行数达标、`git diff` 里没有临时文件；
- `tool/` 下脚本属于「一次性工具」，保留但需在提交说明里标注不参与构建；
- AGENTS.md 要求新踩的坑写进 `AGENT_MISTAKES.md`（时间倒序、去重、≤1000 行）。

## 8. 各阶段实际改动

### 8.1 第一阶段：设计系统移植收尾（2026-10-18）

| 改动 | 原因 |
|---|---|
| 新增 `lib/ui/analysis_options.yaml` | 让 vendored 代码的 199 条 info 归零，同时保留 `lib/app` 的严格检查 |
| 新增 `test/`（宿主 + 2 个 stub + 8 用例） | 证明移植层真的能挂载，而不只是「能编译」 |
| `pubspec.yaml` 增加 `shaders:` | 玻璃着色器要用就必须声明，否则运行时加载失败 |
| 新增 `NOTICE.md`、重写 `README.md` | GPL 合规 + 给后来者一个真实入口 |
| 删除空文件 `tool/lift.py` | 误建、零内容 |
| 删除临时探针 `test/zz_*` | 验证完即清理，不留在仓库里 |

> 当时 `lib/main.dart` 被**有意删除**（应用层还没写，留假入口只会掩盖问题），
> 所以 `flutter run` 起不来。这条已在第二阶段补回。

### 8.2 第二阶段：应用层 + 演示页面（2026-10-19）

| 改动 | 原因 |
|---|---|
| 恢复 `lib/main.dart`，新增 `lib/app/`（8 文件） | 没有入口就无法 `flutter run`；主题/引导/文案/路由需要一处落地 |
| 新增 `lib/router.dart` + `lib/shell/` | 六 tab 底栏；branch 顺序与底栏可配置项解耦 |
| 新增 `lib/state/`（5 个 provider 文件） | 外观与工作模式两组状态；纯内存，不落盘 |
| 新增 `lib/data/`（库根 + 3 part） | 演示数据按域拆分，单文件守住 550 行 |
| 新增 `lib/widgets/`（2 文件） | 跨页面复用的统计条/键值行/分区/页体/浮条留白 + 图标名查找 |
| 新增 `lib/pages/`（18 条路由，43 文件） | 代表性全覆盖；`demo/` 与 `settings/` 用「库根 + part」守行数 |
| 新增 4 个测试文件（+44 用例） | 把本阶段踩过的坑固化成回归：scopes 层级、枚举上屏、多尺寸溢出 |
| 修正 `AGENT_MISTAKES.md` 两条旧结论 | 「scopes 装 `home:`」被推翻两次，最终用正例+反例钉死 |
| 修正 `test/support/app_host.dart` 装法 | 与 `lib/app/bootstrap.dart` 对齐，否则单组件测试会给出假阴性 |

**当前状态**：`flutter analyze lib test` 零问题，`flutter test` 52 个用例全绿，
`lib/` 共 190 个 `.dart` / 41,842 行，最大文件 549 行（`lib/ui/navigation_dock_c.dart`）。

