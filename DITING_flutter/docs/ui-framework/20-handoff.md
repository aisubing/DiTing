---
所属: 谛听 Flutter UI 框架
状态: 第四阶段（数据接线）完成，待 arm64 真机复核
最后校验: 2026-10-20
口径: 所有行数/文件数/命令输出均来自 2026-10-20 本会话真实工具输出
---

# 20 · 交接：已完成什么、下一步怎么写

> 本文是给「接下来的会话」看的。它不重复 DITING 的设计细节（那些在上游源码与
> `docs/refactor/12-ui-components*.md` 里），只写**本仓库当下的真实状态**、
> **已经冻结的约定**、**尚未写的那部分应该怎么接**。

## 1. 一句话状态

`lib/ui/` 是 DITING 1.4.3 设计系统的完整移植（第五轮**零改动**）；应用层（`lib/app/` +
`lib/router.dart` + `lib/routes/` + `lib/shell/`）、状态（`lib/state/`）、数据兼容层
（`lib/data/prefs` + `lib/data/db` + `lib/data/vpn`）与 **77 条路由**全部落地。

**第五轮（2026-10-21）改变了范围口径**：不再问「Flutter 侧还能做什么」，而是
**旧版存在的界面必须保留、旧版不存在的一律移除**，同时完整沿用 `lib/ui` 的视觉体系。
结果是删除 22 条 FlClash 路由（代理域、配置档案域、12 个内核配置页、DNS 查询页、
`/apps`、`/agent`、`/error`、`/theme/preview`、`/access`、`/backup`、`/disclaimer`），
补齐 20 余处旧版有而本仓缺失的界面。完整判定表见
[`../refactor/15-legacy-parity-audit.md`](../refactor/15-legacy-parity-audit.md)。

第三阶段已把**设置域的持久化接回旧版 SharedPreferences**：服务商管理（18 preset +
自定义增删改）、三种解析模式的候选列表与主备顺序、首页服务显示过滤、缓存三档 preset
（覆写 9 个 `dns_cache_*_v2` 键）、拦截响应 + 动态拦截参数、规则总控 4 个开关、引导解析
（含 `bootstrap_log` 24 小时聚合）、禁止联网 / 排除应用 / HTTPS 检查三份应用名单，
以及日志仪表盘的真实数据与当日统计口径。

实测（2026-10-21 第五轮，全部为本会话工具输出）：`flutter analyze` → **No issues found**；
`flutter test` → **302 个用例全绿**；`flutter build apk --debug` 与 Kotlin 侧
`compileDebugKotlin` 均通过。所有 Dart 与 Kotlin 文件均 ≤550 行。

**第四轮已接真实数据源**：流量（`app_traffic_daily`）、请求（`http_request_log`）、
DNS 查询（`dns_log`）、应用清单（`PackageManager`）、订阅（4 张订阅表）、
应用独立规则（`app_allowlist_rules_json`）、出站代理（AndroidKeyStore + 通道）、
HTTPS/CA（`AndroidCAStore` 实查）、网络工具（原生 ping/traceroute/DNS/测速）、
功能中心隐藏项（`hidden_features_set`）。

**第五轮补齐的原生能力**（此前整块缺失，全部在本次会话验证过 Kotlin 可编译）：

| 通道 | 能力 | 补回前 |
|---|---|---|
| `com.haoze.diting/dns_latency` | `probe`：真实 DoH / DoT / 明文查询测速 | **测速功能完全没有** |
| `com.haoze.diting/platform` | 后台隐藏 / 电池优化 / 崩溃日志计数与清空 / 导出文本 | 后台隐藏缺失；崩溃日志写死为 3 |
| `com.haoze.diting/dns_server` | `clearCache` | 页面只能显示「尚未接入」 |
| `com.haoze.diting/diagnostics` | `lookupDns` 增加 `server` 参数 | 「自定义 DNS 服务器」模式丢失 |
| 通知栏四键 | `notification_settings_prefs` 的常驻/速率/自定义文案 | 前台服务读不到用户设置 |

**仍为演示数据（1.4.3 根本没有对应后端）**：连接页、资源页。两者按用户要求保留，
在 `/developer` 有入口，页脚明确标注「不属于旧版 1.4.3 的界面」。
逐条原因见 [`21-ui-coverage-ledger.md`](21-ui-coverage-ledger.md) §15–§16。

## 2. 已完成清单（可直接依赖）

### 2.1 设计系统 `lib/ui/`

| 项 | 实测 |
|---|---|
| 文件数 | 127 个 `.dart`（`lib/ui/` 113 根文件 + `icons/` 12 + `support/` 2） |
| 总行数 | 28,261 |
| 上游对照 | DITING `lib/ui/` 82 个根文件 / 25,948 行 → 移植后按 ≤550 行拆成 113 个 |
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
| `NOTICE.md` | DITING 来源、逐文件移植范围、未移植清单（4 个桌面文件）、第三方包许可 |
| `LICENSE` | GPL-3.0 全文（上游副本） |
| `lib/ui/analysis_options.yaml` | 只在 `lib/ui` 关闭 3 条与上游风格冲突的 lint；`lib/app` 仍全量生效 |
| `tool/glyphsplit.dart` | 把 `app_glyphs.dart` 拆成根 + 5 个 part（保留公共 API 的转发成员） |
| `tool/partsplit.dart` | 按行区间把库根文件拆成 part |
| `tool/extsplit2.dart` | 把 State 类的方法段抽成同库 `extension` |
| `tool/unreferenced.py` | 列出没有任何 import/export/part 指向的 Dart 文件 |
| `tool/diff_upstream.py` | 与 DITING 上游做文件级/行数级对账 |

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
| `lib/routes/` | 按域拆分的 `GoRoute` 声明：`dashboard` / `hub` / `observability` / `profiles` / `config` / `system` / `proxies` + `routes.dart` 汇总，共 **85 条** |
| `lib/state/` | `appearance_providers`（主题/色板/纯黑/字号/透明度/句子/底栏/触感）、`work_mode_providers`（工作模式/电源/端口/服务状态/引导）、`provider_catalog_providers`（目录/选中/可见性/竞速候选）、`rules_providers`、`log_providers`（日志/缓存/竞速聚合，含 `dnsLogRevisionProvider`）、`server_status_providers` |
| `lib/data/prefs/` | `legacy_prefs_store`（原生桥 + 内存桩）、`legacy_settings`（库根 + 外观/网络）、`legacy_settings_dns`（DNS 域访问器，part）、`legacy_settings_provider`（`legacySettingsRevisionProvider`） |
| `lib/data/db/` | `legacy_database`（只读打开旧 Room 库）、`rule_repository`、`dns_log_repository`、`dns_cache_repository`、`race_log_repository`、`bootstrap_log_repository` |
| `lib/data/vpn/` | `dns_config_builder`（引擎配置 JSON）、`provider_store`（`user_providers_json` 增删改）、`cache_presets`（三档 preset）、`block_response_settings`、`vpn_bridge` |
| `lib/data/mock_*.dart` | 仍未接线的演示数据（3 个 part），消费方清单见 `21-ui-coverage-ledger.md` §14 |
| `lib/widgets/` | `stat_strip.dart`（`StatStrip` / `KeyValueRow` / `SectionBlock` / `PageBody` / `DockSpacer`）、`glyph_lookup.dart`（名字→Glyph，122 项） |
| `lib/pages/` | 206 文件 / 45,369 行，路由清单见 `21-ui-coverage-ledger.md` §11 |

### 2.4 测试

| 文件 | 用例 | 守什么 |
|---|---|---|
| `test/legacy_settings_test.dart` | 15 | 旧版 11 个容器的键名/默认值/读写往返 |
| `test/provider_catalog_test.dart` | 20 | 服务商目录与选中的**落盘契约**（增删改、三模式 id 列表、主备顺序、可见性过滤、删除时的引用清洗） |
| `test/vpn_config_test.dart` | 10 | 引擎配置 JSON 组装（服务商、缓存策略、拦截响应、Bootstrap） |
| `test/dns_log_stats_test.dart` | 6 | 日志当日聚合口径（四桶互斥、命中率分母、平均延迟窗口、空样本） |
| `test/app_shell_test.dart` | 6 | 首页渲染、电源四态、tab 保活、浮层可弹、解析服务商选择 |
| `test/app_layer_test.dart` | 30 | 主题装配顺序/缓存上界/色板/断点/provider 不变量 |
| `test/scope_placement_test.dart` | 2 | **scopes 必须在 `Navigator` 之上**（正例 + 反例） |
| `test/enum_display_test.dart` | 5 | 展示文案不得漏出枚举源码标识符（现按真实服务商目录校验） |
| `test/layout_regression_test.dart` | 2 | 全部路由 × 320/412/834 三档宽度 + 1.4 倍字号无溢出 |
| `test/route_catalog_test.dart` | 4 | 每条路由真实注册，不得落到 `UnknownRoutePage` |
| `test/express_mode_test.dart` / `server_mode_test.dart` | 7 / 9 | 极速与服务器模式的启停、prefs 容器隔离 |
| `test/rule_repository_test.dart` | 11 | 旧版规则表 SQL（模式、来源、级联删除） |
| `test/engine_stats_test.dart` | 4 | 原生 stats → `ServiceStats` 映射 |
| `test/ui_components_smoke_test.dart` / `proxies_interaction_test.dart` / `feature_hub_migration_test.dart` | 9 / 6 / 4 | 设计系统组件、代理域交互、功能中心迁移 |
| `test/support/` | — | `app_host.dart`、`test_hooks.dart`、`UiLocalizations` stub、两个 Fake 控制器 |

## 3. 必须知道的约束与坑

### 3.1 `lib/ui` 的运行时前置条件（宿主必须装在 `Navigator` 之上）

移植层大量 `assert(scope != null)`，**缺一个就直接崩**：

1. `MeasureScope(measure: Measure.of(context, scale))` —— `CommonCard`、`ListHeader`、`AppTextStyle` 的测量都用它；
2. `ViewScope(size:, isMobile:)` —— 决定 `showSheet` 走底部面板还是侧栏；
3. `UiLocalizations`（`Localizations` delegate）—— 搜索框、更多菜单、返回、取消等文案；
4. 还有 `MaterialLocalizations`（`MaterialApp` 自带，见 §3.2）。

**正确装法：`MaterialApp.builder`。** 它的 `child` 就是 `Navigator` 本身，scopes 包在外面，
于是所有路由**和浮层**都读得到。

> ⚠️ **本文旧版把这条写反了**（原话是「必须挂在 `Navigator` 之下，即 `home:` 里」）。
> 该结论被 `test/scope_placement_test.dart` 钉死为错：装 `home:` 时 `showSheet` /
> `showFloatingDialog` 的监听器挂在根 `Navigator` 上，是与 `home:` **平级的兄弟路由**，
> 覆盖不到 → 浮层内一读 `ViewScope` 就 `Failed assertion: 'scope != null'`。
>
> 两次误判的共同原因是**探针不够狠**：拿根本不会 assert 的 `CommonCard` 当浮层内容，
> 两种装法都「通过」，把假阴性当成了证据。要复现必须用真正读 scope 的代码
> （如 `ViewScope.isMobileOf`）。
>
> `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 装法一致，**改一处必须同步
> 另一处**，否则「单组件测试」和「整机测试」会给出不同结论。

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

## 4. 剩余可做的事

`lib/ui/`、`lib/app/`、`lib/routes/`、`lib/shell/`、`lib/state/` 与设置域的数据层都已接真实
持久化；第五轮又把界面集合收敛到旧版范围。下面都是**增量**，按优先级排列：

1. **真机回归**（最高优先）：第五轮只在 `flutter analyze` / `flutter test` / Kotlin
   `compileDebugKotlin` 层面验证，**没有上真机**。要重点看的四处：DNS 测速的真实耗时、
   自定义 DNS 服务器查询、通知栏自定义文案、后台隐藏是否真的从最近任务消失。
   模拟器必须用 `-PtunnelAar=libs/tunnel-debug.aar` 才有可加载的 `libgojni.so`。
2. **arm64 真机复核 UID 归因**：`ConnectivityManager.getConnectionOwnerUid` 的参数方向是
   按 Go 侧 `resolveFlowUID` 的实参顺序推导的（Go 把 `id.appIP` 传第一位），模拟器上已
   产出正确包名，arm64 真机（25102RKBEC）未测。
3. **服务器模式的两处引擎缺口**：`EngineStats.snapshot()` 不返回 latency（概览页固定显示
   `-- ms`）；`engine.clearDNSCache()` 已接出通道但未在真机验证。
4. **`/resources` 与 `/connections` 的最终归属**：两者旧版无对应界面、用户要求保留，
   目前挂在 `/developer` 下。若将来要「做得像真的」，需要新的 Go 导出 API；
   在那之前页脚的「不属于旧版界面」标注不能摘。
5. **补平台目录**：本机只有 `android/`；要 `flutter run` 到桌面或浏览器，先
   `flutter create . --platforms windows,web`。

### 4.1 页面清单

**已废弃**。第五轮删除 22 条路由、新增 20 余处界面后，任何手写页面清单都会立刻过期。
以代码为权威：

| 权威来源 | 内容 |
|---|---|
| `lib/routes/*.dart` | 各领域 `Paths` 常量 + `xxxRoutes()` 路由表 |
| `lib/router.dart` | `Routes` 顶层常量 + `_branchOrder` 六个 branch |
| `test/route_catalog_test.dart` | 逐条 build 验活的两张表 |
| `docs/refactor/15-legacy-parity-audit.md` | 每条路由与旧版的对应关系、保留项落点、删除理由 |

### 4.2 路由与导航约定（已落地）

- 六个 tab 走 `StatefulShellRoute.indexedStack`：**branch 自带 `Navigator`，切 tab 不销毁**，
  所以不要额外套 `KeepScope`；
- 底栏用 `NavigationDock`（浮条），非移动端宽度或超过 `maxDockDestinations`（=**4**，
  对齐旧版 `BottomBarDestination.MAX`）时降级为 `NavigationBar`；
- 列表底部留白用 `DockSpacer`（= `NavigationDock.insetOf(context) + extra`），
  `CommonScaffold` 里 `extendBody: true`；
- 二级页面用 `context.push`，`pageTransitionsTheme` 统一 `commonSharedXPageTransitions`；
- 模式选择页与引导页**不在** shell 里（全屏、无底栏），用 `parentNavigatorKey: rootNavigatorKey`；
- `branchIndexOf` 按**最长前缀**匹配（`/` 是任何路径的前缀，第一版用
  `indexWhere(location.startsWith)` 恒返回 0，见 `AGENT_MISTAKES.md`）。


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

实测（2026-10-20 第三阶段）：`flutter analyze lib test` → **No issues found**；`flutter test`
→ **153 个用例全绿**（22 个文件）。覆盖面如下：

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

实测（2026-10-19，`flutter build apk --debug` → 157 MB APK，12:47 完成）。首次构建
耗时集中在**一次性环境准备**（合计约 3 GB）：Gradle 9.3.1 发行版 224 MB、NDK
28.2.13676358 约 2.1 GB、SDK Platform 36 约 100 MB、Gradle 依赖数百 MB。之后是
增量编译，几十秒级。

### 6.2 旧结论为什么错了（反例，勿再引用）

本文旧版 §6 曾写「`services.gradle.org` / `repo1.maven.org` / `plugins.gradle.org`
全不可达，因此 `flutter build apk` 无法完成」。**该结论是错的**，2026-10-19 复测全部
200（含 224 MB 的 `gradle-9.3.1-all.zip` 实际下载成功）。

真实原因有两个，都与网络封锁无关：

1. **首次构建本来就要下 3 GB**，没等够就当成卡死了；
2. **看进度的命令写错了**：`flutter build apk ... | Select-Object -Last N` 会缓冲全部
   输出直到进程结束，中间十分钟一个字节都不显示，主观上完全像卡住。

**教训**：判「网络不可达」必须用 `curl` / `Invoke-WebRequest` 打**真实构件 URL**
（不是域名根路径——根路径 404/400 是正常的，`dl.google.com` 与
`storage.googleapis.com` 就是），并且要区分「慢」与「断」。构建类长任务一律写日志
文件 + `Get-Content -Tail` 跟进度，不要用会缓冲的管道过滤器。

### 6.3 命令

```powershell
# 首次：约 3 GB 下载，耐心等；用日志文件跟进度
flutter build apk --debug *> build.log
Get-Content build.log -Tail 20

# 之后：增量
flutter build apk --debug
```

### 6.4 Kotlin 侧单独编译

改原生代码后不必等完整 APK（几分钟），用：

```powershell
cd android; .\gradlew.bat compileDebugKotlin --console=plain -q
```

失败时去掉 `-q` 看 `^e:` 行。第五轮靠这一步抓到过三次 Kotlin 编译错——
其中一次是编辑工具把两行合成一行（`InetAddress.getByName(spec.host)        DatagramSocket()`），
`-q` 模式下 grep `^e:` 能立刻定位到行号。


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

### 8.3 第三阶段：设置项接回旧版 SharedPreferences（2026-10-20）

| 改动 | 原因 |
|---|---|
| 新增 `lib/data/prefs/legacy_settings_dns.dart` | `legacy_settings.dart` 逼近 550 行，DNS 域访问器拆成同库 `extension`（part），调用点不变 |
| 新增 `lib/data/vpn/provider_store.dart` | `user_providers_json` 的解析/增删改，含旧版丢弃规则（协议未知、DoH 非 https、host/port 非法）与删除后的引用清洗 |
| 新增 `lib/data/vpn/cache_presets.dart` | 三档 preset 各自覆写 9 个 `dns_cache_*_v2` 键；旧安装无 preset 键时用 `fromPolicy` 反推 |
| 新增 `lib/data/vpn/block_response_settings.dart` | 拦截响应模式 + 动态拦截四键，含 2–100 / 10–300 / 60–3600 夹取 |
| 新增 `lib/state/provider_catalog_providers.dart` | 目录 / 选中 / 可见性 / 竞速候选四个 provider，全部读写 prefs |
| 新增 `lib/data/db/bootstrap_log_repository.dart` | 24 小时 `bootstrap_log` 聚合，替换页面上的假样本 |
| `legacy_settings_provider` 增加 `legacySettingsRevisionProvider` | `SharedPreferences` 不可观察，写盘后自增让所有读方失效重建 |
| 首页 / 解析模式 / 服务商管理 / 可见性 / 缓存 / 拦截响应 / 规则总控 / 引导解析 / 三份应用名单 | 从 mock 常量改为读写旧版键 |
| 新增 `test/provider_catalog_test.dart`（20 用例） | 把落盘契约钉死：键名、JSON 形状、主备顺序、引用清洗、可见性规则 |
| 修 `enum_display_test` / `express_mode_test` / `app_shell_test` | 换数据源后旧断言失效：预设服务商在三组里同名、`excluded_app_packages` 属全局容器 |
| 日志页补 `LogAction.failed` | `DnsLogResult` 是四值，`ERROR` 原先落进 `_` 分支被显示成「放行」，语义相反 |
| 仪表盘统计改读 `dns_log` 当日聚合 | 引擎 `stats` 是会话计数，重启隧道即归零；「今日」只能来自落库表 |

## 9. 设置域持久化对照表（写代码前先查这张表）

| 设置 | 容器 | 键 |
|---|---|---|
| 解析服务商目录 | `dns_vpn_prefs` | `user_providers_json`（只存自定义；18 个 preset 在代码里） |
| 当前服务商 | `dns_vpn_prefs` | `selected_provider_id`（默认 `preset_alidns_dns`） |
| 三种解析模式候选 | `dns_vpn_prefs` | `smart_prediction_provider_ids` / `parallel_race_provider_ids` / `primary_backup_provider_ids`（JSON 数组，主备保序） |
| 首页服务显示过滤 | `dns_vpn_prefs` | `home_visible_protocols` / `home_hidden_provider_ids` / `home_visible_provider_ids` |
| 缓存 | `dns_vpn_prefs` | `dns_cache_preset_v3` + 9 个 `dns_cache_*_v2` |
| 拦截响应 | `dns_vpn_prefs` | `block_response_mode` + `dynamic_block_response_enabled` / `dynamic_block_request_threshold` / `dynamic_block_window_seconds` / `dynamic_block_nxdomain_duration_seconds` |
| 规则总控 | `dns_vpn_prefs`（全局） | `domain_rules_enabled` / `http3_inspection_enabled` / `encrypted_dns_blocking_enabled` / `address_rules_enabled` |
| 引导解析 | `dns_vpn_prefs` | `bootstrap_enabled` / `bootstrap_preset_ids` / `bootstrap_custom_json` |
| 三份应用名单 | `dns_vpn_prefs`（**全局，不进极速容器**） | `blocked_app_packages` / `excluded_app_packages` / `http_inspection_app_packages` |
| 极速模式 DNS 键 | `diting_express_prefs` | 键名同上，容器不同（`RuleDataset.EXPRESS`） |
| 极速运行标志 | `express_vpn_prefs` | `express_vpn_running` |

**第五轮新增的键**（全部照抄旧版容器与键名，实现见
`lib/data/prefs/legacy_settings_parity.dart`）：

| 设置 | 容器 | 键 | 默认 |
|---|---|---|---|
| 日志模式 | 数据集容器 | `dns_log_mode`（`all` / `blocked_and_errors` / `off`） | `all` |
| 日志保留天数 | `dns_vpn_prefs` | `log_retention_days`（1–30） | 7 |
| 悬浮日志窗 | `dns_vpn_prefs` | `floating_log_enabled` | false |
| 后台隐藏 | `dns_vpn_prefs` | `hide_from_recents_enabled` | false |
| 绕过局域网 | `dns_vpn_prefs` | `bypass_lan_enabled` | true |
| IPv6 模式 | 数据集容器 | `ipv6_mode`（`auto`/`disable`/`prefer`） | `auto` |
| 语言 | `dns_vpn_prefs` | `app_language_mode` | `system` |
| 首启须知 | `dns_vpn_prefs` | `initial_agreement_accepted` | false |
| 启动检查更新 | `dns_vpn_prefs` | `disable_startup_update_check` | **true**（默认不检查） |
| 软件背景 | `dns_vpn_prefs` | `custom_background_enabled` / `_uri` / `_uris` | false / null / [] |
| 首页 DNS 详情透明度 | `dns_vpn_prefs` | `home_dns_detail_opacity` | 1.0 |
| **通知栏四键** | **`notification_settings_prefs`** | `persistent` / `speed` / `custom_running_text` / `custom_stopped_text` | true / false / '' / '' |

> **通知栏四键的容器是独立的 `notification_settings_prefs`**，不是 `dns_vpn_prefs`。
> 写错容器界面上看不出任何区别，但前台服务读的是前者——通知栏行为不会变。
> `settings_catalog_test.dart` 专门断言了这一点。

四条硬约定：

1. 写入后必须 `bump()` `legacySettingsRevisionProvider`，否则其他页面读到旧值；
2. 数值夹取写在 setter（`LegacySettings`），不要只依赖控件；
3. 三份应用名单互斥：加入一份要从未选中的另两份删除；
4. **键名与容器逐字照抄旧版**：写错一个字母，设置照样存、界面照样显示，只有
   升级/降级后才丢设置——渲染测试抓不到这一类缺陷，只有 `settings_catalog_test.dart` 能抓。

## 10. 统计口径与接线现状

### 10.1 日志仪表盘四个数字

全部来自 `DnsLogRepository.dailyStats()` 对 `dns_log` 的**当日**扫描（`timestamp >= 今日零点`）：

| 指标 | 来源 | 备注 |
|---|---|---|
| 今日查询 | 当日行数 | 含 BLOCKED / ERROR |
| 缓存命中 | `cached = 1` 的行数 | 只在 PASSED/REWRITTEN 桶内统计 |
| 已拦截 | `result = 'BLOCKED'` | 上游返回拦截（`upstream_dns`）也记在该列 |
| 平均延迟 | 当日 `elapsed=NNms` 的均值 | 无样本显示 `—`，不显示 `0ms` |

命中率分母取 `passed + error`，对齐 Go `dns_cache.go` 的 `hitRatio = totalHits/(totalHits+totalMisses)`。

### 10.2 已知口径差异（不是缺陷，勿「修」）

1. **stale 命中**：stale-while-revalidate 命中在日志里是 `cached=1`，引擎计入 `staleHits`
   而非 `totalHits`，所以 DB 口径命中率会略高于引擎 `hitRatio`；
2. **竞速排行**：`RaceLogDao.winnerStats` 只统计 `success = 1 AND winnerProviderId IS NOT NULL`
   的胜出，失败数来自整表汇总；单服务商模式也会写记录，排行不区分模式；
3. **缓存表**：Go 缓存纯内存，无枚举接口；`dns_cache` 表是 1.4.3 的快照，升级后为空属正常。

### 10.3 原生接线现状（2026-10-20 第四轮实机验证 + 第五轮补充）

第四轮把此前「只写盘未读」的配置全部接进了引擎入参。下表是接线后的真实状态：

| 键 | 进入 Go 的路径 | 结论 |
|---|---|---|
| `blocked_app_packages` | `VpnStartRequest.blockedPackages` → UID → `Engine.setBlockedUIDs(csv)` | **已接通**（普通模式；极速窄路由无 firewall 阶段，显式不传） |
| `excluded_app_packages` | `Builder.addDisallowedApplication` | **已接通**（TUN 层，引擎本就不需要这份名单） |
| `http_inspection_app_packages` | → UID → `Engine.setMitmAllowedUIDs(csv)` | **已接通**（仅普通模式；关闭时写空 CSV 清残留） |
| `https_inspection_ready` | 门控 `inspectionEnabled`：`ready && enabled && packages 非空` | **已接通** |
| 出站代理 | AES-GCM `OutboundProxyStore` → `outboundProxy` JSON → `Engine.configureOutboundProxy` | **已接通**（未启用或校验失败时传空串，回落直连） |
| `app_allowlist_rules_json` | `encodeRuleSnapshot(appAllowlist:)` → `Engine.applyRuleSnapshot` | **已接通**（普通模式） |
| 流量 / HTTP 日志 | `setTrafficCallback` / `setHttpLogCallback` / `setUIDResolver` / `setAppUidResolver` | **已接通**（`EngineDataPlane`） |

**实机数据面证据**（2026-10-20，`emulator-5554` x86_64 / API 34）：

```
dns_log            : 38 行（packageName 由 NULL 变为真实包名 → UID 归因链路生效）
app_traffic_daily  : 2 行（由 0 行变为真实字节数 → setTrafficCallback 生效）
dns_race_log       : 22 行
```

流量页 UI 与库内数字逐项吻合（954.6 KB 下行 / 99.2 KB 上行 / 2 个应用），隧道重启后
数值继续累加，说明 flush 正常。

**仍未接线（如实登记）**：

1. `http_request_log` 为 0 行 —— 只在 MITM 真正拦截流量时才产生，模拟器未装 CA 到
   信任库。代码路径已注册（`attachHttp`），属「等用户装证书」而非缺陷；
2. `http_request_log.blockSubscriptionId` 写 NULL：旧版用 Kotlin 规则缓存反查订阅 id，
   本移植没有那套缓存；填错比留空更坏，Dart 侧按「未知」处理。

**仍需真机（arm64）复核**：`ConnectivityManager.getConnectionOwnerUid` 的参数方向是按
Go 侧 `resolveFlowUID` 的实参顺序推导的（Go 把 `id.appIP` 传第一位），模拟器上已产出
正确包名，但 arm64 真机（25102RKBEC）本轮未测。

> **口径更正**：此前本文写「仓库无 Go 源码，只能从 `tunnel-debug-sources.jar` 确认导出
> 方法」——这是错的。`Android/tunnel/` 下有 **85 个 `.go` 文件**，完整数据面都在仓库里。
> 第四轮的接线结论都是从 Go 源码反向确认的，例如：
> - `traffic_tracker.go:208 tick()` 只在 `len(deltas) > 0` 时才回调，且 `RecordTx/RecordRx`
>   对 `uid <= 0` 直接 return —— UID 解析失败会导致流量表**静默为空**；
> - `engine_full_tunnel.go:372/401` 的 `WrapClientConn(conn, uid)` 在 `uid <= 0` 时原样
>   返回连接（不计数），与上一条同源；
> - `engine_config.go:358 ConfigureOutboundProxy` 把 `parseOutboundProxyConfig` 的错误
>   **当字符串返回**，调用方不检查就会「静默不生效」——据此修掉了 `port` 写成字符串导致
>   `json.Unmarshal` 失败的缺陷。
