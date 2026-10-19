---
所属: 谛听 Flutter UI 框架
状态: 第二轮流式并行开发约定（写代码前必读）
最后校验: 2026-10-19
---

# 22 · 第二轮并行开发约定

> 本文件只解决一件事：**多路并行改同一个 Flutter 工程时，怎么保证互不踩脚**。
> 设计规范看 `docs/refactor/`，覆盖清单看 `21-ui-coverage-ledger.md`。

## 1. 铁律

1. **只改 UI**。不接网络、不接数据库、不接 VPN、不写平台通道。所有交互用本地
   state 或 `Future.delayed` 模拟即可。
2. **不改 `lib/ui/`**。它是已冻结的上游移植层，改它会破坏所有页面。确需能力缺口
   时在自己页面里组合，不要动 `lib/ui/`。
3. **不改别人的文件**。文件归属见 §3；需要别人文件里的东西时，自己复制一份私有
   实现，或找 Lead 协调。
4. **不改 `lib/router.dart`**。它由 Lead 维护，已预先展开六个领域路由函数。你只填
   自己那个 `lib/routes/<domain>_routes.dart` 的函数体。
5. **不改 `lib/app/`、`lib/shell/`、`lib/widgets/`、`test/`**。
6. **每个文件 ≤550 行**（AGENTS.md）。超了拆 `library` + `part` 或拆成多个文件。
7. **不写死业务数据在页面里**。数据统一放自己的 `lib/data/mock_<domain>.dart`。

## 2. 中文与风格

- 所有界面文案中文；枚举若要上屏必须显式取 `.label`，**禁止直接插值枚举**
  （`'$enumValue'` 会显示源码标识符，见 AGENT_MISTAKES）。
- 单引号、尾逗号、`child:` 放最后（与 `lib/ui` 风格一致）。
- 注释只在「代码说不出来」的地方写：上游对应位置、非显然约束、易踩的坑。
  **不要**逐行复述代码、不要写「我刚改了什么」。

## 3. 文件归属（硬边界）

| 归属 | 文件 |
|---|---|
| Lead | `lib/router.dart`、`lib/app/**`、`lib/shell/**`、`lib/widgets/**`、`lib/data/mock_data.dart`、`test/**`、`docs/**` |
| 每条流 | `lib/pages/<你的领域>/**`、`lib/data/mock_<你的领域>.dart`、`lib/state/<你的领域>_providers.dart`、`lib/routes/<你的领域>_routes.dart` |

领域目录名：`home`（含 `dashboard/`）、`proxies`、`observability`、`profiles`、
`config`、`appearance`、`system`、`forms`。

## 4. 路由怎么加

`lib/router.dart` 已经这样写：

```dart
routes: [
  StatefulShellRoute.indexedStack(...),   // 六个底栏 tab
  ...dashboardRoutes(),
  ...proxiesRoutes(),
  ...observabilityRoutes(),
  ...profilesRoutes(),
  ...configRoutes(),
  ...systemRoutes(),
]
```

你只需在自己的 `<domain>_routes.dart` 里让函数返回真实路由：

```dart
List<RouteBase> proxiesRoutes() => [
  GoRoute(
    path: ProxiesPaths.proxies,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ProxiesPage(),
  ),
];
```

`ProxiesPaths` 的常量名已在脚手架里定好，**不要改名**（Lead 的功能中心卡片
引用它们）。要加新路由就往自己的 `Paths` 类里加常量 + 在这里加一条。

## 5. 设计系统用法速查（全部来自 `package:diting/ui/ui.dart`）

```dart
// 页面骨架
CommonScaffold(
  title: '标题',
  iconActions: [IconButtonData(glyph: AppGlyphs.refresh, tooltip: '刷新', onPressed: ...)],
  menuItems: [CommonPopupMenuItem(label: '设置', glyph: AppGlyphs.sliders, onPressed: ...)],
  primaryAction: IconButtonData(...),      // 顶栏主按钮（不是 Widget！）
  confirmationAction: IconButtonData(...), // 表单确认
  searchState: AppBarSearchState(onSearch: (v) {}),
  isLoading: false,
  body: ...,
)

// 滚动正文：自动带底栏留白
PageBody(children: [...])                   // lib/widgets/stat_strip.dart

// 分组：标题 + 行 + 脚注
generateSection(title: '分组', footer: '说明', actions: [IconButtonData(...)], items: [...])

// 行（7 种构造器）
ListItem(title: Text('x'), subtitle: Text('y'), leading: GlyphIcon(...), trailing: ..., onTap: ...)
ListItem.open(title: ..., widget: 子页面)      // 展开成子页
ListItem.next(title: ..., widget: 子页面)      // 推入子页
ListItem.options<T>(title:, options:, value:, textBuilder:, onChanged:)
ListItem.input(title:, dialogTitle:, value:, onChanged:, validator:, maxLength:)
ListItem.checkbox(title:, value:, onChanged:)
ListItem.toggle(title:, value:, onChanged:)    // onChanged 传 null = 禁用

// 容器
CommonCard(child: ...)                       // 卡片
StatStrip(stats: [StatItem(label:, value:, unit:, color:)])
KeyValueRow(label:, value:, monospace: true)
SectionBlock(title:, child:, footer:)
ListHeader(title:) / ListFooter(text:)

// 浮层
showSheet<void>(context: context, builder: (_) => ...)          // 底部弹层
showFormSheet<String>(context: context, builder: (_) => ...)     // 表单弹层
showExtend<void>(context: context, builder: (_) => ...)          // 扩展弹层
showSnapSheet<void>(context: context, builder: (_) => ...)       // 吸附弹层
showFloatingDialog<bool>(context: context, child: CommonDialog(...))
showModalSideSheet<void>(context: context, builder: (_) => ...)  // 侧边抽屉

// 反馈
CommonCircleLoading()
NullStatus(illustration: NullStatusIllustration.proxies, message: '暂无代理')
SegmentedControl<T>(segments: [(value, '标签')], value:, onChanged:)
SearchField(...) / TonalChip(label:, onPressed:) / CommonChip(...)
SkeletonText() / SkeletonPill()

// 图标
GlyphIcon(AppGlyphs.xxx, size: 20, color: ...)   // 122 个常量
AnimatedGlyph(...)

// 主题取值
context.colorScheme.primary / .onSurface / .onSurfaceVariant / .error
context.colorScheme.success / .warning            // 见 lib/ui/extension
SurfaceLevel.card.colorOf(context.colorScheme)    // 卡片底色
SurfaceLevel.page.colorOf(context.colorScheme)    // 页面底色
SurfaceLevel.block.colorOf(context.colorScheme)   // 块底色
context.raisedSurfaceLevel.colorOf(context.colorScheme)
AppTextStyle.subheadline.of(context)              // display…caption2
context.listTitleStyle / context.listSubtitleStyle / context.listCaptionStyle
AppShape.md / AppShape.lg（超椭圆，**不要**用 RoundedRectangleBorder/ClipRRect）
```

### 5.1 已定好的状态入口

```dart
// 工作模式与电源（lib/state/work_mode_providers.dart）
ref.watch(workModeProvider)            // AppWorkMode.normal / server / express
ref.watch(powerProvider)               // PowerState
ref.watch(selectedProviderProvider)    // String（服务商 id）
ref.watch(serviceStatsProvider)        // ServiceStats
ref.watch(serverStatusProvider)        // ServerStatus
mockProviders / mockServiceStats       // lib/data/mock_data.dart

// 外观（lib/state/appearance_providers.dart）
themeModeProvider / paletteProvider / pureBlackProvider / textScaleProvider
homeOpacityProvider / homeSentenceProvider / bottomBarProvider / hapticProvider
resolutionModeProvider                 // ResolutionMode
AppPalette / AppThemeMode              // lib/app/theme/colors.dart
```

## 6. 自测口径（并行期）

> 并行期**不要**跑 `flutter test`（别人文件可能正半成品，会把你的结果染红）。
> Lead 在合并后统一跑。

```bash
dart analyze lib/pages/<你的领域> lib/data/mock_<领域>.dart lib/routes/<领域>_routes.dart
# 期望：No issues found
```

只报自己路径下的问题；发现别人路径下的报错**不要去修**，记下来交给 Lead。

## 7. 提交

并行期**不要** `git commit`（会互相把对方半成品提交进去）。Lead 合并后统一提交。

## 8. 交付时必须报告

1. 新增文件清单 + 每个文件行数；
2. 已实现的上游页面对应关系（上游文件:行 → 你的文件）；
3. 有意简化 / 无法复刻的部分及原因；
4. `dart analyze` 的自测输出原文。
