---
所属: 谛听 Flutter UI 框架
状态: 第一阶段（设计系统移植）完成，应用层未开始
最后校验: 2026-10-18
口径: 所有行数/文件数/命令输出均来自 2026-10-18 本会话真实工具输出
---

# 20 · 交接：已完成什么、下一步怎么写

> 本文是给「接下来的会话」看的。它不重复 FlClash 的设计细节（那些在上游源码与
> `docs/refactor/12-ui-components*.md` 里），只写**本仓库当下的真实状态**、
> **已经冻结的约定**、**尚未写的那部分应该怎么接**。

## 1. 一句话状态

`lib/ui/` 是 FlClash 0.9.1 设计系统的完整移植，`flutter analyze` 零问题、8 个烟测全绿、
所有文件 ≤550 行；**但工程还没有入口 `lib/main.dart`**，`flutter run` 目前不能启动。
下一步是写应用层（主题管理器 + 引导 + 路由 + 演示页面）。

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

## 3. 必须知道的约束与坑

### 3.1 `lib/ui` 的三个运行时前置条件

移植层大量 `assert(scope != null)`，**缺一个就直接崩**：

1. `MeasureScope(measure: Measure.of(context, scale))` —— `CommonCard`、`ListHeader`、`AppTextStyle` 的测量都用它；
2. `ViewScope(size:, isMobile:)` —— 决定 `showSheet` 走底部面板还是侧栏；
3. `UiLocalizations`（`Localizations` delegate）—— 搜索框、更多菜单、返回、取消等文案；
4. 还有 `MaterialLocalizations`（`MaterialApp` 自带）。

**宿主必须挂在 `Navigator` 之下**（即 `MaterialApp.home:` 里，而不是 `MaterialApp.builder:`
里）。挂在 builder 里看起来能跑，但 `CommonPopupBox` / `showFloatingDialog` / `showSheet`
会报 `Navigator operation requested with a context that does not include a Navigator`。
`test/support/app_host.dart` 已经按正确层级写好，应用层照抄即可。

### 3.2 拆分规则（新增文件也要守）

AGENTS.md 硬性要求 ≤550 行。已用的三种拆分法都在 `tool/` 里：

- **库级拆 part**（`partsplit.dart`）：适合一堆顶层类/函数；part 文件写 `part of 'x.dart';`
- **单类拆 part**（`glyphsplit.dart`）：Dart 不允许类跨 part，因此把成员改成顶层私有
  `_g_<name>_`，类里保留 `static const name = _g_name_;` 转发，调用点不变；
- **State 类方法抽 extension**（`extsplit2.dart`）：同库 `extension XBuild on X` 可访问私有成员；
  但**类内 `static` 成员必须先提到库级私有**，否则报
  `unqualified_reference_to_static_member_of_extended_type`。

### 3.3 `models.dart` 是手写的，不是 freezed

上游 `IconButtonData` / `AppBarState` / `AppBarSearchState` 由 freezed 生成。本仓库
`lib/ui/models.dart` 手写了等价类，`copyWith` **用 `_keep` 哨兵复刻 freezed 语义**：
省略参数 = 保留旧值，显式传 `null` = 置空。`scaffold.dart:259` 的
`copyWith(query: null)` 依赖后者，**不要改成 `??` 写法**。

### 3.4 玻璃（Liquid Glass）保留但默认关闭

`lib/ui/liquid_glass*.dart`（2,494 行）与 `shaders/liquid_glass.frag` 都完整移植，
`pubspec.yaml` 已声明 `shaders:`。`LiquidGlassScope.of(context)` 默认 false，各组件自动走
非玻璃回退。要做玻璃效果时打开 scope 即可，不需要恢复代码。

## 4. 还没写的部分

### 4.1 应用层骨架（按此顺序写）

```
lib/main.dart                 runApp(ProviderScope(child: DitingApp()))
lib/app/app.dart              MaterialApp：theme/darkTheme = watchAppTheme，builder = ThemeCrossFade
lib/app/theme/manager.dart    watchAppTheme(brightness) —— 复刻上游组装链
lib/app/theme/colors.dart     defaultPrimaryColor(0xFF007AFF) + 8 个 Apple 系统色
lib/app/l10n/ui_strings.dart  UiLocalizations 的中文实现（从 test/support 的 stub 提升）
lib/app/bootstrap.dart        MeasureScope + ViewScope + MediaQuery(textScaler 0.8–1.4) + SystemUiOverlayStyle
lib/state/demo_providers.dart Riverpod：工作模式、开关状态、主题模式、种子色、文本缩放、选中项
lib/data/mock_data.dart       域名/规则/订阅/日志/流量/应用列表
lib/router.dart               go_router 路由树
```

`watchAppTheme` 的**组装顺序不能变**（上游 `lib/manager/theme_manager.dart`）：

```dart
ThemeData(
  useMaterial3: true,
  pageTransitionsTheme: …commonSharedXPageTransitions（lib/ui/navigator.dart）,
  actionIconTheme: …back/close 用 GlyphIcon,
  colorScheme: seededColorScheme(seedColor:, brightness:, style:)
      .toPureBlack(pureBlack),
  fontFamily: …,
  fontFamilyFallback: appFontFamilyFallback（lib/ui/font.dart）,
  extensions: [if (dark) ElevatedColorScheme(plainDark ?? scheme.elevated)],
).withAppShapes.withAppSurfaces.withAppTypography
```

注意：**`ThemeData` 每次重建都不相等**，`ThemeCrossFade` 正是靠这一点淡入上一帧。
上游用 `_appThemes` 缓存 `(inputs, theme)` 避免无意义重建，本仓库应照抄该缓存，
否则改一个无关状态就会闪一下。

移动端尺寸常量（上游 `lib/common/layout.dart` + `constant.dart`，需要重新声明）：

| 常量 | 值 | 用途 |
|---|---|---|
| `maxMobileWidth` | 600 | `width <= 600` → mobile（浮条 + PageView 布局） |
| `maxLaptopWidth` | 840 | 其后为 desktop；Android 用不到，但 `isMobile` 判定要一致 |
| `maxTextScale` | 1.4 | 文本缩放上限 |
| `minTextScale` | 0.8 | 文本缩放下限 |

### 4.2 演示页面清单

参照 `docs/refactor/` 的功能图谱，按「代表性全覆盖」取舍。每页都用
`CommonScaffold` + `NullStatus` + `CommonCard`/`ListItem` 三件套，数据全部来自
`lib/data/mock_data.dart`。

| 路由 | 页面 | 必做要点 | 规格出处 |
|---|---|---|---|
| `/` | 首页（三模式共用一个壳） | 电源开关状态机、模式 chip、服务商选择卡、首页句子、底栏 | 03 §3 |
| `/hub` | 功能中心 | 7 分类 / 28 卡，2 列网格，按下 0.90 缩放 | 03 §3.4 |
| `/rules/:kind` | 规则列表（黑/白/覆写共模板） | 统计卡 + 搜索 + 过滤 chips + 批量编辑入口 | 04 |
| `/rules/batch` | 批量编辑器 | 行号槽 + 等宽字体 + 结果三带对话框 | 04 |
| `/subscriptions` | 订阅 | 分组 chips + 进度卡 + 行内操作菜单 + 添加表单 | 04 |
| `/apps` | 应用选择 | 搜索 + 三态全选 + `ListItem` 复选列表 | 04 |
| `/logs` | 日志仪表盘 | 概览卡 → 请求日志 / DNS 缓存 / 竞速排行 | 05 |
| `/traffic` | 流量 | 环形仪表 + 实时速率 + 应用排行 + 详情弹窗 | 05 |
| `/settings` | 设置树 | `DecorationListItem` 缝合卡、深色三选一、9 色板、五条透明度滑杆、底栏自定义（实时预览） | 06 |
| `/tools` | 网络工具 | 4 页 PageView（测速/Ping/DNS/路由）+ 分段控件 + 统计带 | 06 |
| `/agent` | AI Agent | 状态卡 + 脱敏 key + 温度滑杆 + 分析结果 sheet（手写 Markdown 渲染） | 06 |
| `/about` | 关于 | Hero logo + 版本 + 检查更新 + 链接行 | 06 |
| `/server` | 服务器模式 | 5 态状态卡 + 上游列表 + 局域网接入 + 服务统计 | 03 §3.3 / 11 |
| `/mode/select` | 工作模式选择 | 三卡 + 1000ms emphasized 全屏 morph | 03 §4.6 |
| `/mode/onboarding` | 三步引导 | 3 段进度条 + 水平滑入 + 权限二态按钮 | 03 §4.7 |
| `/demo` | 组件画廊 | 所有按钮/输入/chip/加载/空态/弹层逐一演示 | —— |

### 4.3 路由与导航约定

- `go_router` 的 `ShellRoute` 承载底栏：`NavigationDock`（浮条，62dp，`insetOf(context)` 给
  列表底部留白）或降级为 `NavigationBar`；
- 每个 tab 用 `KeepScope` 保活（上游 `lib/ui/keep_scope.dart`），切 tab 不重建；
- 二级页面用普通 push，`pageTransitionsTheme` 已统一为 `commonSharedXPageTransitions`；
- 模式切换页与引导页**不要**放进 ShellRoute（它们要全屏，没有底栏）。

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

`unreferenced.py` 只应输出 `lib/ui/ui.dart`（barrel）以及将来可能的 `lib/main.dart`。

## 6. Android 构建为什么现在跑不通（环境问题，非工程问题）

实测（2026-10-18）：

| 目标 | 结果 |
|---|---|
| `services.gradle.org` | **不可达**（curl 超时） |
| `repo1.maven.org` / `plugins.gradle.org` | **不可达** |
| `mirrors.cloud.tencent.com` | 200 |

`flutter create` 生成的 `android/gradle/wrapper/gradle-wrapper.properties` 指向
`services.gradle.org/distributions/gradle-9.3.1-all.zip`，本机缓存里没有该版本；
本地已有 `~/.gradle/wrapper/dists/gradle-9.4.1-bin`（原 Android 工程用的腾讯镜像版本），
但 Flutter 的 gradle 插件又需要 `org.gradle.kotlin.kotlin-dsl:6.5.2`，离线缓存里也没有。

**结论**：`flutter build apk` 需要能访问 Google Maven + Gradle Plugin Portal 的网络。
恢复网络后按下面顺序验证（源码定稿后再做，见 AGENT_MISTAKES 铁律 6）：

```bash
yes | flutter doctor --android-licenses
```

```bash
flutter build apk --debug
```

本次已尝试并如实记录：许可证已在本会话接受（`All SDK package licenses accepted`），
但构建仍卡在依赖下载。可选做法（需要用户决定）：把 wrapper 与 `settings.gradle.kts`
的仓库指向腾讯镜像 —— 这会改变工程配置，因此**没有**擅自修改。

## 7. 提交约定

- 中文 Conventional Commits，一个阶段一个提交；
- 每个提交前确认：`analyze` 零问题、`test` 全绿、文件行数达标、`git diff` 里没有临时文件；
- `tool/` 下脚本属于「一次性工具」，保留但需在提交说明里标注不参与构建；
- AGENTS.md 要求新踩的坑写进 `AGENT_MISTAKES.md`（时间倒序、去重、≤1000 行）。

## 8. 本次收尾实际改动

| 改动 | 原因 |
|---|---|
| 新增 `lib/ui/analysis_options.yaml` | 让 vendored 代码的 199 条 info 归零，同时保留 `lib/app` 的严格检查 |
| 新增 `test/`（宿主 + 2 个 stub + 8 用例） | 证明移植层真的能挂载，而不只是「能编译」 |
| `pubspec.yaml` 增加 `shaders:` | 玻璃着色器要用就必须声明，否则运行时加载失败 |
| 新增 `NOTICE.md`、重写 `README.md` | GPL 合规 + 给后来者一个真实入口 |
| 删除空文件 `tool/lift.py` | 误建、零内容 |
| 删除临时探针 `lib/main.dart`、`test/zz_*` | 验证完即清理，不留在仓库里 |

> 注意：`lib/main.dart` 被删除后工程**无法 `flutter run`**。这是已知的、有意的状态：
> 应用层还没写，留一个假入口只会掩盖问题。写 §4.1 的第一个文件时补回。
