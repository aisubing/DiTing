---
所属系列: DITING Android Flutter 重构功能图谱
章: 03（续篇）
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测。本篇承接 03-navigation-and-main-ui.md §8
---

# 03 续 · Flutter 重构注意 + 待定清单

## 8.1 go_router 路由映射建议（仅确证语义层面）

**前提**：现结构没有 Navigation Compose，全部「路由」= `SettingsRouteActivity.EXTRA_ROUTE`（75 个消费常量）与 `LogRouteActivity.EXTRA_ROUTE`（9 个）两个字符串空间，外加 `Routes` 里 83 个常量中的 2 个死值。`createIntent` 的 7 个 typed extra 就是路由参数全集。

建议把两个 Activity 的字符串空间合并为**单一 route tree**，用 path 段区分域，用 query 参数承载现有 extra：

| Android 现状 | go_router 建议 | 理由（引证） |
|---|---|---|
| `MainActivity` + `when(workMode)` 三子树 | `ShellRoute` 的 home branch，**模式作为 state 而非 path**：`/` 内按 `workMode` provider 切换子 Widget | 模式不是导航位置而是全局状态；`MainModeDispatcher.kt:37` 的 `when` 语义 1:1 映射 |
| `SettingsRouteActivity(route=X, dataset=Y)` 自嵌套 | 顶层 `/settings/…` 全量展平为 GoRoute 树；`dataset` 提为 `StatefulShellRoute` 之上的共享 query，而非每层重复传 | `SettingsRouteActivity.kt:201-227` 的自嵌套本质就是栈 push；展平后天然由 Navigator 承担 |
| `LogRouteActivity(route=X)` 自嵌套 | `/logs/…` 子树（dashboard 为父，logs/cache/race/bootstrap/subscription/health/traffic 为子） | `LogRouteActivity.kt:104-150` 的 9 分支即 9 条 GoRoute |
| `WorkModeActivity` | `/mode/select`（`isFirstLaunch` → `extra` 保留为 `?first=1`） | 现返回语义是「CLEAR_TOP 回主页 + 带模式变更」= `context.go('/')`；`WorkModeActivity.kt:90-99` |
| `ModeOnboardingActivity` | `/mode/onboarding?mode=&first=` | 同上语义，`ModeOnboardingActivity.kt:203-219` |
| `DnsMainActivity` | **不映射**（残迹）；其通知 contentIntent 改指 `/` | `server/DnsMainActivity.kt:14-31`、`server/backend/DnsModeService.kt:307` |
| `WORK_MODE_SELECTION` / `USAGE_WIZARD` 两条「不渲染只转发」的路由 | 保留为**重定向路由** `redirect:` 到上面两条（或直接让设置页入口 `context.push` 目标） | 现实现是 onCreate 里 `start+finish`（`SettingsRouteActivity.kt:91-100, 207-214, 510-517`），三处重复代码，Flutter 侧收敛为一处 |
| `Routes.RULE_LIST/ALLOW_RULE_LIST/REWRITE_RULE_LIST/ADDRESS_*` 5 条无 UI 入口的路由 | 先确认是否仍需（本域未找到入口，见 §9 待定） | `SettingsRouteActivity.kt:383-387` |

**参数类型化**：现 extra 是 `String` + `runCatching{valueOf}` 回落（`SettingsRouteActivity.kt:48-73`），`EXTRA_RULE_DATASET` 缺省时**按当前模式回退**（`:56-63`）。Flutter 侧必须保留这个「缺省=当前模式」语义，否则 express/normal 共享同一条 route 时会读错库。

**返回语义差异**（必须分别实现）：`/settings/**` 的返回**要带 6 个变更位**（theme/background/bottomBar/workMode/runtimeDns/hideFromRecents）回主页触发刷新；`/logs/**` 的返回**不带任何东西**。前者可用 `context.pop(extra=…)` 或直接把 6 位改为**全局 provider 的脏标记**（更简洁）；后者无状态回传。

## 8.2 可合并 / 应合并的 Activity

| Activity | 判定 | 依据 |
|---|---|---|
| `SettingsRouteActivity` | **合并**为路由子树 | 它只是「按字符串渲染一个 composable」+ 一堆结果位转发；无生命周期独占逻辑（`onStart/onStop` 仅悬浮日志与下载取消，`:181-199`） |
| `LogRouteActivity` | **合并** | 同上，且比前者更弱（无结果回传） |
| `WorkModeActivity` | **可合并但保留转场语义** | 它存在的理由是全屏 morph 动画 + `CLEAR_TOP` 淡入淡出（`WorkModeExpansionTransition.kt:60-93`）；Flutter 里做 `PageRouteBuilder(fade)` 即可，不需要独立 Activity |
| `ModeOnboardingActivity` | **建议独立（可保留为单独 Navigator 或全屏 dialog route）** | 它有 4 个 `registerForActivityResult` launcher（`:68,74,80,89`）与系统设置回跳，Flutter 侧要对应 4 个 `await` 型通道；独立成页最省事 |
| `DnsMainActivity` | **删除**（仅删这个**入口 Activity 残迹**，不是服务器模式本体） | 纯转发（`server/DnsMainActivity.kt:15-25`，类注释 `:10-13` 自证 "Backward compatibility trampoline … DNS mode is now embedded natively inside MainActivity"），且 `createIntent` 返回的是 MainActivity 的 Intent，语义自相矛盾。**服务器模式 UI 本体是 `MainModeDispatcher` DNS 分支内嵌的 `server/ui/DnsModeHost.kt`（→ `DnsMainScreen`/`DnsMainViewModel`/`DnsModeManager`），保留**，详见 03 章主篇 §6.4 澄清与 11 章 |
| `.MainActivityCurrentIconAlias` | **保留**（Flutter 侧仍需在 AndroidManifest 留 activity-alias，用于动态图标切换） | `AndroidManifest.xml:163-177` |

**合并后的最大收益点**：现每次下钻设置页都要重建 `AppThemeSurface`——**5 个 setContent Activity 各自读一遍同样的 4 个外观值**（`MainActivity.kt:91-94`、`SettingsRouteActivity.kt:105-108`、`LogRouteActivity.kt:42-45`、`WorkModeActivity.kt:37-40`、`ModeOnboardingActivity.kt:112-115`），主题切换靠 3 套互不相同的刷新机制：MainActivity 的 3 个 `*RefreshRequested` 布尔 + `LaunchedEffect`、SettingsRouteActivity 的 `routeRefreshVersion` 作 `remember` key、LogRouteActivity/WorkModeActivity/ModeOnboardingActivity 完全「不刷新」。单 Navigator 下换成**一个 `ValueNotifier<AppearanceState>` + `AnimatedBuilder`**，一次性消除这三种不一致（LogRouteActivity 现读一次后不跟随主题变更，是真实的**行为缺陷**而非特性）。

## 8.3 跨模式 UI 复用面

- **首页 HOME 内容区**：`normal/ui/MainScreenContent.kt:105-347` 与 `express/ui/ExpressHomeContent.kt:120-359` 结构逐段同构（DataResetNoticeCard / PowerToggle / 句子 / 服务商 Crossfade / 两个 Dialog / endpoint 列表 / 模式按钮），差异只有 3 处：①状态源 `uiState.isRunning|isBusy`（MainViewModel）vs `ExpressVpnController.isRunning` 且 `isBusy=false` 硬编码 ②模式按钮 `enabled=!isBusy` 有无 ③`label` 动画 label 名。**这是最应该抽公共 widget 的一对**（Flutter：`HomeDashboard(resolutionSource, runningSource, busySource)`）。
- **主屏容器**：`MainScreen.kt` 与 `ExpressMainScreen.kt` 的 pager/alpha/BackHandler/reset/ON_RESUME 重读全部同构（对比 `:128-172` 与 `:108-142`），只有页枚举与页体不同。Flutter 侧一个 `MainShell` + 页 builder 表即可。
- **底栏**：三模式共用同一个 `FloatingNavigationBar`（server 传 `DnsNavTab`），复用面 100%；`FloatingBottomBarTabItem` 接口就是为它设计的（`ui/BottomBarDestination.kt:16-19`）。
- **功能中心**：normal 与 express 各一份实现（`FeatureHubScreen.kt` vs `ExpressFeatureHubScreen.kt`），**数据驱动的隐藏开关逻辑完全一致**（同一 `HiddenFeaturesStore` + 同一 `isVisible(feature)` 闭包 + 同一长按日志卡）。差异仅在候选集（26 vs 18）。Flutter 侧应为「一个 Category 数据源 + 模式白名单」，而非两份 UI。
- **模式分流屏清单**（11 对，均在 `SettingsRouteActivity`）：RULE_CONTROL / DATA_CLEANUP / CONFIG_TRANSFER / FOREGROUND_BACKGROUND / DNS_LOGS / HTTP_REQUEST_LOGS / NOTIFICATION_SETTINGS / BOTTOM_BAR_CUSTOMIZATION / HIDDEN_FEATURES（+ 可选 FEATURES 别名）——这些是**成对复制**的屏，重构时要逐对判定是「合并为参数化一屏」还是「保持两屏」。判据：文案是否含模式专有概念（如 express 通知设置无「网速显示」，`AppearanceSettingsScreen.kt:93-97`）。
- **`isExpress` 判据不统一**：SettingsRouteActivity 用 `WorkModeStore.getAppWorkMode(this)==EXPRESS`（`:327`），LogRouteActivity 用 `dataset==RuleDataset.EXPRESS`（`:103`）。Flutter 侧必须**统一为一个 `AppModeProvider`**，否则服务器模式（dataset=DNS_MODE）下会走 normal 分支（当前行为）。

## 8.4 Compose 状态 → Flutter 状态管理映射注意点

| Android 状态载体 | 语义 | Flutter 映射 | 注意点 |
|---|---|---|---|
| `MainViewModel`(AndroidViewModel, `MutableStateFlow`×7 + `BroadcastReceiver`) | 跨屏共享的运行态/服务商/解析模式/首页可见性 | 一个 app 级 `Provider/Listenable`，`BroadcastReceiver` → 平台事件通道（MethodChannel/EventChannel） | receiver 注册在 **application** 且 `RECEIVER_NOT_EXPORTED`，`onCleared` 注销（`ui/MainViewModel.kt:100-112, 229-232`）——迁移时事件订阅生命周期必须等价，否则模式切换后残留双订阅 |
| `ExpressVpnController.isRunning: StateFlow<Boolean>` | 极速运行态（服务侧推） | `ValueNotifier<bool>` 由平台通道驱动 | normal 与 express 的 running 走**两条完全不同的通道**（广播 vs StateFlow，`MainViewModel.kt:85-98` vs `ExpressHomeContent.kt:85`）；Flutter 侧应统一为一个 `ServiceStatusProvider`，内部按模式选源 |
| `MainWorkModeCoordinator` 的 3 个 `mutableStateOf/mutableLongStateOf`（currentWorkMode / hasSelectedWorkMode / resetToHomeTrigger） | Activity 持有但被三模式共享 | `AppModeController` 全局单例 | `resetToHomeTrigger` 用**时间戳当事件**（`:94`）——Flutter 里改用 `Stream`/回调，不要复制「用 long 值变化触发副作用」的写法 |
| `MainActivity` 的 `mainThemeRefreshRequested/backgroundRefreshRequested/bottomBarRefreshRequested`（`by mutableStateOf`） | Activity 结果驱动的单向刷新信号 | 直接由 provider 通知取代 | 三个信号最终都归结为「重读 prefs」，是 Activity 边界造成的额外机制；单 Navigator 下**整段可删** |
| 每个 Activity 独立读 `AppearanceSettingsStore` 的 4 值 | 冷启快照 | 一个 `AppearanceStore`（如 `SharedPreferences` + `ValueNotifier`） | 现在存在 4 份不同新鲜度的快照（LogRoute 永不刷新），迁移时是**修正点**不是保留点 |
| `remember`/`rememberSaveable` 局部 UI 态（如 `BatchAddRulesScreen` 的 `inputText`、`selectedMode`） | 配置变更保活 | Flutter 侧靠 `AutomaticKeepAlive`/widget 重建语义，但**输入文本**必须显式持久化到 controller | `rememberSaveable` 只用于 `inputText/selectedMode`（`:85-88`），`validationSummary` 用 `remember`（`:90`）——即「校验结果不跨配置变更」，这是有意的：重建后不自动弹结果框 |
| `DampedDragAnimation` + 6 类触感 + 重力传感器（`FloatingNavigationBar`） | 高保真交互 | 需自绘 `CustomPainter` + `Haptics` + `SensorService`（gravity） | `rememberDeviceTilt(enabled=isGlassActive)` 传感器**仅玻璃态且 resumed 时存活**（`:220`）；Flutter 侧对应 `accelerometerEventStream` 的订阅/取消时机，勿常驻 |
| `HiddenFeaturesStore.hiddenFeaturesFlow`（进程级 `@Volatile initialized` + 单例 MutableStateFlow） | 全局功能可见性集合 | app 级 provider | 该单例的 `init()` 幂等守卫 + 「UI 侧先 init 再取 flow」的模式在三处重复（`FeatureHubScreen.kt:133-136`、`ExpressFeatureHubScreen.kt:120-123`、两个 HiddenFeatures 屏），Flutter 侧改为构造注入 |
| `ModePermissionStore` / `WorkModeStore` / `SystemSettingsStore` / `AppearanceSettingsStore` 四个 SharedPreferences 门面 | 持久化 | 统一 `PreferencesRepository` | **文件名不连续**：`diting_settings`（模式）、`dns_vpn_prefs`（外观/系统/隐藏功能）、`mode_permission_preferences`（引导）、`recognition_members`（ETag）。迁移时若要合并文件，必须写一次性导入迁移并保留旧键名清单（外观键全在 `dns_vpn_prefs`，`ui/settings/SettingsPreferencesExtensions.kt:7`） |
| `PermissionDisclosure` 三态弹层 + 3 个 ActivityResult launcher（`MainVpnController.kt:35-59`） | 权限申请编排（含「先说明再申请」的 Rationale 门） | 平台通道 + `permission_handler` 类库，Rationale 标志仍存 prefs | `isVpnExplained` 与「暂不允许也置 explained」的语义必须保留（`MainVpnController.kt:133-149`），否则每次开服务都会重复弹说明 |

## 8.5 重构期不得丢失的行为细节（本域）

1. 协议未同意时**内容区被对话框完全替换**（不是叠加），且返回键 = 不同意并退出（`MainActivity.kt:118-131`、`MainActivityDialogs.kt:18`）。
2. 「不同意」要 `finishAndRemoveTask()` 并停 VPN + `VpnMonitorManager.stop`（`MainStartupCoordinator.kt:61-68`）。
3. `EXTRA_AUTO_START_VPN` 消费后**必须 remove**，防重复触发起服务（`MainVpnController.kt:63`）。
4. 首页电源按钮在「未选服务商」或「非单一模式且候选 <2」时禁用（`MainScreenContent.kt:129-131`）——这是解析模式合法性与 UI 的唯一耦合点。
5. 底栏数量边界 2/4 在**四处**各自校验（enum 常量、`parseJsonList`、`toJsonList`、两个自定义屏的 Toast）；Flutter 侧收敛为单一 `BottomBarConfig` 值对象。
6. express 底栏配置**写回的是 legacy 键**（`ExpressBottomBarCustomizationScreen.kt:73-78`），即 express/normal 共享 `bottom_bar_destinations` 一个键，靠 id 交集过滤。改 UI 时不能把两者拆成两个键，否则老用户配置丢。
7. 模式切换的展开动画**先写完库再通知宿主**（`WorkModeSelectionScreen.kt:80-82`），若在动画开始时写，会在动画期间被 MainActivity 的 `syncOnResume` 读到中间态。
8. `SettingsGuideHost` 用 `content()` **先渲染再叠对话框**（`SettingsGuide.kt:171`），即首次进入时底层屏已组合（会触发其 `init` 侧效应）——Flutter 侧若改成「先弹再进」要注意屏内一次性副作用（`NavigationSettledEffect`）的时机变化。
9. 批量导入 `URL` 归一化必须复用运行期同一 parser（`BatchRuleValidator.kt:157-165` 注释明确说明历史缺陷：存原文会让 Go matcher 匹配不上且重复添加不被识别）。
10. `RecentsPrivacyController` 的 `onResume` 重打（§6.3）不是冗余：新任务不会继承标志。

---

## 9. 待定清单（缺哪类证据）

| # | 事项 | 缺的证据 |
|---|---|---|
| 1 | `Routes.RULE_LIST` / `ALLOW_RULE_LIST` / `REWRITE_RULE_LIST` / `ADDRESS_RULE_LIST` / `ADDRESS_ALLOW_RULE_LIST` 五条路由的真实 UI 入口 | **已加验**：全 `src/main/java` grep `RULE_LIST` 仅命中 `AppNavigationRoutes.kt` 定义与 `SettingsRouteActivity` 的 when 分支 ⇒ 这 5 条路由**无任何导航调用者**，只可能被外部 intent 触达。需 04 章确认「规则列表」二级页是否已改由 `RULE_MANAGEMENT` 系分支承载 |
| 2 | `Routes.PROVIDER_HEALTH`（`LogRouteActivity.kt:124`）的入口 | **已加验**：全仓 grep `PROVIDER_HEALTH` 仅命中该 when 分支与 `core/diagnostic/ProviderHealthStore.kt` 的 prefs 键 ⇒ `ProviderHealthScreen` 在本版本**无可达导航入口**（死路由）。需确认是否为未完成功能或被移除入口的残迹（属 06/07 章诊断域） |
| 3 | `MainActivity` 的 `QS_TILE_PREFERENCES` filter 是有意还是缺实现 | 全仓零代码消费；需产品/作者确认「长按 Tile 期望行为」，或真机长按观察 |
| 4 | `Routes.MAIN`、`Routes.SUBSCRIPTION_HUB` 两个零引用常量 | **已加验**：全仓 grep 常量形式与字面量 `"subscription_hub"` 均只命中定义行（含 `src/main/res`）⇒ 判定为死常量，重构直接删除；仅余「外部模块经 HTTP/deeplink 传该串」这一不可静态排除面 |
| 5 | `ExpressWorkModeCard`（36 行，零调用者）与 `OptionalFeaturesScreen`（13 行，零调用者）是否可随重构删除 | 只做了包内 grep；需全仓（含 `res/xml`、反射）复核 + 确认无 third-party 模块引用 |
| 6 | `DnsModeHost` 注释「DNS mode lifecycle and status are managed inside DnsModeHost」与实际 `syncOnResume` 对 DNS 空分支之间，是否漏了状态回读 | 需真机观察服务器模式下从设置页返回主页时状态是否自恰（`DnsModeHost.kt:33-47` 有自愈，可能足够） |
| 7 | `LogRouteActivity` 主题一次性读取（不跟随变更刷新）是缺陷还是刻意 | 静态证据充分（`:42-45` 无触发器），但需产品确认「从日志页返回改主题再进日志页」的期望 |
| 8 | `SettingsRouteActivity` `CACHE_SETTINGS` 分支用 `requestedRuleDataset` 而非 `ruleDataset`（`:430`）是否等价 | 两者同 getter ⇒ 等价，但需确认无遗漏的第二处 dataset 变量歧义（建议列入 06 章设置体系全表复核） |
| 9 | 底栏玻璃态在 Android 12+ 深色壁纸下的 `luminance()<0.5` 判定是否覆盖所有预设暗板 | 需实机/截图对照 8 套 dark palette 的 `surface` 值（本文档未做像素级验证） |
| 10 | `AppWorkMode.isAvailable` 字段（三值全 true）是否预留给未来灰度 | 静态仅见声明与 `WorkModeCard` 使用 `isSupportedOnCurrentDevice()`，未见 `isAvailable` 消费点；需全仓 grep 确认 |
