---
所属系列: DITING Android Flutter 重构功能图谱
章: 03
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测
基线: main @ dda2779, v1.4.3 / versionCode 10403
---

# 03 导航骨架 · 首页主屏 · 工作模式 · 个性化

## 1. 概述（实测骨架）

| 指标 | 实测值 | 来源 |
|---|---|---|
| Manifest 声明 Activity | 6 个 + 1 个 activity-alias | `AndroidManifest.xml:95-177` |
| 其中承载 Compose 的 Activity | 5（`MainActivity`/`SettingsRouteActivity`/`LogRouteActivity`/`WorkModeActivity`/`ModeOnboardingActivity`）；`DnsMainActivity` 纯转发不 setContent | 各文件 onCreate |
| 路由字符串常量总数 | 83 | `ui/AppNavigationRoutes.kt` `grep -c 'const val'` |
| 本域实际消费的常量 | 81（仅 `MAIN`、`SUBSCRIPTION_HUB` 零引用） | 集合差集实测 |
| `SettingsRouteActivity` when 分支消费的 Routes 常量 | 75（63 个以 `->` 开分支 + 12 个多标签续行） | `SettingsRouteActivity.kt:328-519` |
| `SettingsRouteActivity` when 分支组数 | 63 组（含 `else -> SettingsScreen` 兜底，`:518`）；`SettingsGuideHost` 包裹 17 处 | 同上 + `grep -c "SettingsGuideHost(" SettingsRouteActivity.kt` = 17 |
| `LogRouteActivity` when 分支消费的 Routes 常量 | 9（+ `else` 兜底） | `LogRouteActivity.kt:104-150` |
| `MainModeDispatcher` 引用的 Routes 常量 | 29 | `main/MainModeDispatcher.kt` |
| 首页（normal）底栏候选页 | 6 | `ui/BottomBarDestination.kt:31-72` |
| 首页（express）底栏候选页 | 4 | `express/ui/ExpressNavigation.kt:21-55` |
| 服务器模式底栏页 | 3（固定，不可自定义） | `server/ui/navigation/DnsNavigation.kt:10-21` |
| 工作模式 | 3（NORMAL / DNS=服务器 / EXPRESS） | `ui/mode/AppWorkMode.kt:20-46` |
| 引导步骤 | 3 步 × 3 模式 | `onboarding/ModeOnboardingScreen.kt:76` |
| 主题色板风格 | 9 枚举值，实际 8 套预设板 × 明/暗 = 16 份 `M3ColorPalette` | `ui/theme/AppTheme.kt:18-40` |
| `ui/theme/` 文件数 | 11（AppTheme / AppTypography / M3ColorPalette + 8 个 Preset*Palette） | 目录实测 |
| 隐藏功能项 / 分类 | 27 项 / 7 类；极速模式白名单 18 项 | `ui/settings/HiddenFeaturesStore.kt`、`express/ui/ExpressHiddenFeaturesScreen.kt:38-66` |
| 设置页首次进入说明（SettingsGuide） | 16 个顶层 + 1 个二级（domain_rules_step2）；英文文案分支 16 | `ui/SettingsGuide.kt:114-152` |
| 批量规则分类器分支 | 9 条主分支（注释 1…9） | `ui/batch/BatchRuleClassifier.kt:84-429` |
| `PermissionDisclosure` 枚举 | 3（VPN / NOTIFICATION / BATTERY_OPTIMIZATION） | `ui/MainActivityDialogs.kt:7-11` |
| `AppPermission` 枚举 | 5 | `permission/AppPermission.kt:35-64` |
| QS Tile 深链 | 1 个 intent-filter（`QS_TILE_PREFERENCES`）+ 1 个外部 scheme（`mqqapi://`） | 见 §6 |

**骨架结论**：本应用是「单主 Activity + 3 个卫星 Activity」的伪导航结构。MainActivity 内**没有** `NavHost`/`NavController`/`composable()`——三模式通过 `when` 直接切换 Compose 子树；所有二级页面走 `SettingsRouteActivity` / `LogRouteActivity` 两个「路由 Activity」，每层子页面 = 再启动一个同名 Activity（`registerForActivityResult(StartActivityForResult)` 自嵌套——**不是**已废弃的 `Activity.startActivityForResult` API；顶层由 `MainNavigationCoordinator:28-57` 注册、下钻由 `SettingsRouteActivity:82` 注册的 `childActivityLauncher.launch(...)` 发起，见 §2.1）。Flutter 重构时这套结构应完全收敛到 `go_router`，但**语义面**（模式即路由、返回栈即 Activity 栈、跨 Activity 布尔回传）必须逐条保留。

---

## 2. 导航总图

### 2.1 Activity 拓扑与返回栈语义

```
MainActivity (activity-alias .MainActivityCurrentIconAlias 挂 MAIN/LAUNCHER)
 │  setContent 内 when(WorkMode): ExpressMainScreen | DnsModeHost | MainScreen
 │
 ├─ 带结果启动：MainNavigationCoordinator 的 registerForActivityResult(StartActivityForResult)
 │      (:28-57) → settingsLauncher.launch(...) → SettingsRouteActivity(route=…, dataset=…)
 │        └─ 自嵌套：openRoute() 经 childActivityLauncher(:82 同样注册 StartActivityForResult)
 │           .launch(createIntent(本 Activity, 新 route))  (:217-226)
 │           （childLaunchInProgress 布尔闸门防重入，:77/:215-216）
 ├─ startActivity          → LogRouteActivity(route=…)
 │        └─ 自嵌套：openRoute() → startActivity(LogRouteActivity)（无结果回传，:81-85）
 ├─ startActivity          → WorkModeActivity（模式选择）→ CLEAR_TOP 回 MainActivity
 └─ startActivity          → ModeOnboardingActivity（三步向导）→ CLEAR_TOP 回 MainActivity

DnsMainActivity (launchMode=singleTask)  ← 唯一入口：DnsModeService 前台通知 contentIntent
    └─ onCreate 立刻转发 MainActivity（CLEAR_TOP|SINGLE_TOP）并 finish
```

- **Activity 数（Manifest）**：`MainActivity:96`、`SettingsRouteActivity:107`、`WorkModeActivity:115`、`ModeOnboardingActivity:123`、`LogRouteActivity:131`、`server.DnsMainActivity:139`、alias `.MainActivityCurrentIconAlias:164`。除 MainActivity 外全部 `exported="false"`、`launchMode` 除 DnsMainActivity 为 `singleTask` 外全为 `standard`。
- **返回栈语义**：设置子页是**独立 Activity 栈帧**，`onBack = ::finishSettings`（`SettingsRouteActivity.kt:229-232`）→ `setResult(RESULT_OK, resultData)` + `finish()`。因此每下一层，系统返回栈深 +1，MainActivity 到最深层设置页最多可同时存在 N 个 SettingsRouteActivity 实例（N = 下钻层数）。
- **主题/背景变更广播链**：`SettingsRouteActivity` 的 `resultData` 累积 6 个布尔位（`EXTRA_RUNTIME_DNS_CHANGED` / `EXTRA_THEME_CHANGED` / `EXTRA_BACKGROUND_CHANGED` / `EXTRA_BOTTOM_BAR_CHANGED` / `EXTRA_WORK_MODE_CHANGED` / `EXTRA_HIDE_FROM_RECENTS`），子 Activity 结果由 `mergeResult()`（`:241-255`）逐位或入并向上传播，最终 MainActivity 的 `settingsLauncher`（`main/MainNavigationCoordinator.kt:28-57`）按位触发刷新。同时 `mergeResult` 末尾 `routeRefreshVersion++`（`:254`）强制本页 `remember(routeRefreshVersion)` 重新读取 4 个外观值（`:105-108`）。
- **语言变更**：`MainActivity.onResume` 与 `SettingsRouteActivity.onResume` 都比较 `languageModeAtCreate` 并 `recreate()`（`MainActivity.kt:219-224`、`SettingsRouteActivity.kt:186-193`）。`SettingsRouteActivity.applyLanguage()` 先 `setMode` 再 `recreate()`（`:176-179`）。
- **横竖屏策略**（全 Activity 统一，基类）：手机锁竖屏、平板自由旋转 → `AppLocalizedActivity.applyOrientationPolicy()`，`DeviceScreenHelper.isTabletDevice()` 为假时 `SCREEN_ORIENTATION_PORTRAIT`（`AppLocalizedActivity.kt:33-36`）。基类 `attachBaseContext` 用 `AppLanguageManager.wrap()` 注入语言（`:12-14`）。
- **悬浮日志前后台同步**：**3 个** Activity（MainActivity、SettingsRouteActivity、LogRouteActivity）在 `onStart/onStop` 调 `ExpressModeLauncher.updateFloatingLogAppState(ctx, true/false)`（`MainActivity.kt:214,232`、`SettingsRouteActivity.kt:183,196`、`LogRouteActivity.kt:68,77`）；`WorkModeActivity`/`ModeOnboardingActivity`/`DnsMainActivity` 均不调（grep 实测仅这 3 处）。

### 2.2 模式路由表（同一功能在三模式下的落点）

| 功能 | NORMAL | EXPRESS | DNS(服务器) | 分流实现 |
|---|---|---|---|---|
| 首页宿主 | `normal/ui/MainScreen.kt` | `express/ui/ExpressMainScreen.kt` | `server/ui/DnsModeHost.kt`（内嵌，无 Activity） | `main/MainModeDispatcher.kt:37-122` `when(currentWorkMode)` |
| 首页内容区 | `MainContent`（MainScreenContent.kt） | `ExpressHomeContent` | `DnsHomeScreen` | 各自 `when` 分支 |
| 底栏可选页 | 6 选 2–4 | 4 选 2–4（legacy 映射） | 3 固定 | `AppearanceSettingsStore.getBottomBarDestinations` / `ExpressBottomBarDestination.getDestinations` |
| 日志仪表盘页 | `ModernLogDashboardScreen` | `ExpressLogDashboardScreen` | 无（该模式不进 pager） | `MainScreen.kt:289` / `ExpressMainScreen.kt:246` |
| 规则控制屏 | `RuleControlScreen` | `ExpressRuleControlScreen` | 走 `DnsSettingsScreen`→`openRuleRoute(RULE_CONTROL)`，仍落到 SettingsRouteActivity 的非 express 分支 | `SettingsRouteActivity.kt:334-357` `isExpress` |
| 数据清理 | `DataCleanupScreen` | `ExpressDataCleanupScreen` | — | `:401-408` |
| 备份与迁移 | `ConfigTransferScreen` | `ExpressConfigTransferScreen` | — | `:412-414` |
| 前后台行为 | `ForegroundBackgroundSettingsScreen` | `ExpressForegroundBackgroundSettingsScreen` | — | `:432-438` |
| 请求日志 | `RequestLogScreen` | `ExpressRequestLogScreen` | — | `:444-457`（Settings 路由）**与** `LogRouteActivity.kt:106-119`（Log 路由，按 dataset 判） |
| 通知设置 | `NotificationSettingsScreen` | `ExpressNotificationSettingsScreen` | — | `:496` |
| 底栏自定义 | `BottomBarCustomizationScreen` | `ExpressBottomBarCustomizationScreen` | — | `:487-491` |
| 隐藏功能管理 | `HiddenFeaturesScreen`（27 项全列） | `ExpressHiddenFeaturesScreen`（18 项白名单） | — | `:508-509` |
| 覆写名单 | `RewriteListScreen` 可达 | 功能中心无入口，但路由仍可达（`REWRITELIST_MANAGEMENT`/`REWRITE_RULE_LIST`） | `openRuleRoute(REWRITELIST_MANAGEMENT)` | `:371-376, 385` |
| 应用流量统计 | `AppTrafficStatsScreen`（底栏页 + 设置路由） | 物理排除 | — | `MainScreen.kt:303`、`:107` |
| 网络诊断 | `NetworkToolsScreen`（底栏页 + 路由） | 物理排除 | — | `MainScreen.kt:310` |
| 模式切换入口 | TopAppBar `SwapHoriz` IconButton | 同 | HOME 页 + SETTINGS 页两处 | `MainScreen.kt:200-207`、`ExpressMainScreen.kt:168-175`、`DnsMainScreen.kt:134-141`、`DnsSettingsScreen.kt:202-208` |
| 权限警告图标 | `ModePermissionWarningAction(NORMAL)` | `(EXPRESS)` | `(DNS)`（仅 HOME tab） | `MainScreen.kt:199`、`ExpressMainScreen.kt:167`、`DnsMainScreen.kt:133` |

`isExpress` 判定**不是**用 Intent 里的 `dataset`，而是每次现场读 `WorkModeStore.getAppWorkMode(this)`（`SettingsRouteActivity.kt:327`）——所以 `dataset` 与模式不一致时，屏选择跟模式走、数据源跟 dataset 走。

### 2.3 路由清单表 · SettingsRouteActivity（75 条）

参数键定义于 `SettingsRouteActivity.kt:524-534, 556-559`；`createIntent(context, route, ruleScope, ruleKind, title, requestSource, dataset, batchTarget)`（`:536-554`）。
`EXTRA_RULE_DATASET` 缺省时按当前模式回退 EXPRESS/NORMAL（`:56-63`）。

| 路由常量 | 值(字符串) | 读取的参数 | 目标屏（模式分流） | 入口 | 文件:行 |
|---|---|---|---|---|---|
| SETTINGS | settings | — | `SettingsScreen` | 首页底栏 SETTINGS 页；default 兜底 | `:329`, `:518` |
| LANGUAGE_SETTINGS | language_settings | — | `LanguageSettingsScreen` | SettingsScreen 内 `main(Routes.LANGUAGE_SETTINGS)` 条目 | `:330` |
| RULE_MANAGEMENT / RULE_CONTROL / DOMAIN_RULE_MANAGEMENT / ADDRESS_RULE_MANAGEMENT | 4 个别名 | dataset | 包裹 `SettingsGuideHost(DOMAIN_RULES)`；express→`ExpressRuleControlScreen`，否则 `RuleControlScreen` | 功能中心「规则控制」；服务器 `DnsSettingsScreen` 规则控制 | `:331-357` |
| APP_RULE_MANAGEMENT | app_rule_management | — | `SettingsGuideHost(APP_ALLOWLIST){AppRuleManagementScreen}` | 功能中心「应用独立规则」 | `:358` |
| WHITELIST_MANAGEMENT | whitelist_management | dataset | `WhitelistScreen`（含批量入口 `BATCH_ADD_RULES`+`WHITELIST`） | 功能中心「白名单」；服务器模式 | `:359-364` |
| BLACKLIST_MANAGEMENT | blacklist_management | dataset | `BlacklistScreen`（批量 → `BatchRuleTarget.BLACKLIST`） | 功能中心「黑名单」；服务器 | `:365-370` |
| REWRITELIST_MANAGEMENT | rewritelist_management | dataset | `RewriteListScreen`（批量 → `REWRITE`） | 功能中心「覆写名单」；服务器 Hosts 覆写 | `:371-376` |
| BATCH_ADD_RULES | batch_add_rules | `EXTRA_BATCH_RULE_TARGET`（默认 BLACKLIST）、dataset | `BatchAddRulesScreen` | 上三屏 `onNavigateToBatchAdd()` | `:377-382` |
| RULE_LIST | rule_list | ruleKind(默认 BLOCK)、ruleScope(默认 DNS)、dataset | `RuleListScreen` | — **无导航调用点**（全仓 grep `RULE_LIST` 仅命中定义+本 when 分支）| `:383` |
| ALLOW_RULE_LIST | allow_rule_list | ruleKind(默认 ALLOW) | `RuleListScreen` | 同上：无调用点 | `:384` |
| REWRITE_RULE_LIST | rewrite_rule_list | dataset | `RewriteListScreen` | 同上：无调用点 | `:385` |
| ADDRESS_RULE_LIST | address_rule_list | 固定 URL_BLOCK + DNS | `RuleListScreen` | 同上：无调用点 | `:386` |
| ADDRESS_ALLOW_RULE_LIST | address_allow_rule_list | 固定 URL_ALLOW + DNS | `RuleListScreen` | 同上：无调用点 | `:387` |
| EXCLUDED_APPS | excluded_apps | — | `SettingsGuideHost(EXCLUDED_APPS){ExcludedAppsScreen}` | 仅功能中心「排除应用」（**不在** SettingsScreen 的 6 条目内） | `:388` |
| OUTBOUND_PROXY_SETTINGS | outbound_proxy_settings | — | `OutboundProxySettingsScreen`；子选择结果经 `EXTRA_OUTBOUND_PROXY_APP_*` 回传并覆盖 `selectedAppOverride` | 功能中心「出站代理」 | `:389-393`, `:79`, `:234-239` |
| OUTBOUND_PROXY_APP_SELECTION | outbound_proxy_app_selection | — | `OutboundProxyAppsScreen` → `finishOutboundProxyAppSelection(pkg)` | 上一屏 `onSelectApp` | `:394` |
| BLOCK_RESPONSE_SETTINGS | block_response_settings | dataset | `BlockResponseSettingsScreen` | 规则控制屏 | `:395` |
| AGENT_API_SETTINGS | agent_api_settings | — | `AgentApiSettingsScreen(onNavigate)` | 功能中心「AI 分析」；日志页 AI 按钮 `startActivity` | `:396`；`ModernLogDashboardScreen.kt:202`、`RequestLogScreen.kt:338`、`DnsCacheScreen.kt:272` |
| AI_PROVIDER_MANAGEMENT / AGENT_API_CREDENTIALS / AGENT_API_PRESETS | 3 别名 | — | `AiProviderManageScreen` | AgentApiSettingsScreen | `:397-399` |
| AGENT_API_PARAMS | agent_api_params | — | `AgentApiParamsScreen` | 同上 | `:400` |
| DATA_CLEANUP | data_cleanup | `EXTRA_TITLE`（默认 `ScreenDestinations.dataCleanup.title`） | `SettingsGuideHost(DATA_CLEANUP)`；express→`ExpressDataCleanupScreen` | 功能中心「数据清理」 | `:401-408` |
| CONFIG_TRANSFER / CONFIG_IMPORT_EXPORT / RULE_EXPORT / RULE_IMPORT | 4 别名 | — | `SettingsGuideHost(CONFIG_TRANSFER)`；express→`ExpressConfigTransferScreen` 否则 `ConfigTransferScreen`，标题硬编码"备份与迁移" | 功能中心「备份与迁移」 | `:409-414` |
| PROVIDER_MANAGEMENT | provider_management | dataset | `SettingsGuideHost(PROVIDER_MANAGEMENT){ProviderManagementScreen}` | 功能中心；首页「管理服务…」 | `:415` |
| HOME_PROVIDER_VISIBILITY | home_provider_visibility | dataset | `SettingsGuideHost(SERVICE_DISPLAY){HomeProviderVisibilityScreen}` | 功能中心「服务显示」；首页「服务显示…」 | `:416` |
| BLOCKED_APPS / BLOCKED_APPS_SELECTION | 2 别名 | — | `SettingsGuideHost(BLOCKED_APPS){BlockedAppsScreen}`（Selection 落到同一屏） | 功能中心「禁止联网应用」 | `:417-418` |
| APP_ALLOWLIST / APP_ALLOWLIST_SELECTION | 2 别名 | — | `SettingsGuideHost(APP_ALLOWLIST){AppRuleManagementScreen}`（与 APP_RULE_MANAGEMENT 同屏不同 guide） | 功能中心 | `:419-420` |
| BOOTSTRAP_SETTINGS | bootstrap_settings | dataset | `SettingsGuideHost(BOOTSTRAP){BootstrapSettingsScreen}` | 功能中心 | `:421` |
| NETWORK_TOOLS | network_tools | — | `SettingsGuideHost(NETWORK_TOOLS){NetworkToolsScreen}` | normal 底栏页 + 功能中心 | `:422` |
| RACE_MODE_PROVIDERS | race_mode_providers | dataset | `SettingsGuideHost(RESOLUTION_MODE){ResolutionModeHomeScreen(onOpenMode=mode.route)}` | 首页模式按钮；功能中心「解析模式」 | `:423-425` |
| RESOLUTION_SINGLE/SMART/PARALLEL/BACKUP | 4 条 | dataset | `ResolutionModeConfigScreen(DnsResolutionMode.X, …)`；映射扩展 `:563-569` | 上一屏 4 张卡 | `:426-429` |
| CACHE_SETTINGS | cache_settings | dataset（读两遍，见下） | `SettingsGuideHost(CACHE){CacheSettingsScreen}` | 功能中心 | `:430` |
| LOG_RETENTION_SETTINGS | log_retention_settings | dataset | `SettingsGuideHost(LOG_MODE){LogRetentionSettingsScreen}` | 功能中心「日志」卡片**长按** | `:431` |
| FOREGROUND_BACKGROUND_SETTINGS | foreground_background_settings | — | 模式分流两屏 | SettingsScreen（`ScreenDestinations.foregroundBackgroundSettings`） | `:432-438` |
| HTTP_INSPECTION_SETTINGS | http_inspection_settings | — | `SettingsGuideHost(HTTP_INSPECTION){HttpInspectionSettingsScreen}` 三回调→DNS_LOGS(HTTPS)/HTTP_INSPECTION_APPS/CA_CERTIFICATE_SETTINGS | 功能中心 | `:439` |
| CA_CERTIFICATE_GUIDE | ca_certificate_guide | — | `CaCertificateGuideScreen` | 上一屏 | `:440` |
| CA_CERTIFICATE_SETTINGS | ca_certificate_settings | — | `CaCertificateSettingsScreen(→GUIDE)` | 功能中心链路 | `:441` |
| HTTP_INSPECTION_APPS | http_inspection_apps | — | `HttpInspectionAppsScreen` | 功能中心链路 | `:442` |
| DNS_LOGS / HTTP_REQUEST_LOGS | 2 条 | `EXTRA_REQUEST_SOURCE` | express→`ExpressRequestLogScreen`；否则 `RequestLogScreen(initialSource = 参数 ?: route==HTTP_REQUEST_LOGS ? HTTPS : ALL)` | 仪表盘页卡片；HTTPS 检查屏 | `:443-457` |
| SUBSCRIPTION_MANAGEMENT | subscription_management | ruleScope(默认 DNS)、dataset | `SubscriptionScreen(→ADD_SUBSCRIPTION)` | 规则控制屏 | `:458-464` |
| SUBSCRIPTION_AUTO_UPDATE_INTERVAL | … | dataset | `SubscriptionAutoUpdateIntervalScreen` | 同上 | `:465` |
| ADD_SUBSCRIPTION | add_subscription | ruleScope、dataset | `AddSubscriptionScreen` | 同上 | `:466-471` |
| ABOUT | about | — | `AboutScreen(onBack,"应用信息")` | 功能中心「应用信息」 | `:472` |
| APP_UPDATE | app_update | — | `AppUpdateScreen(appUpdateState, …)`；同路由额外叠挂 `AppUpdateDialog`（`:160-171`） | 功能中心「更新与支持」 | `:473`, `:160-171` |
| APPEARANCE_SETTINGS | appearance_settings | — | `SettingsGuideHost(APPEARANCE){AppearanceSettingsScreen}` 7 个导航回调 | 功能中心「外观设置」 | `:474-486` |
| BOTTOM_BAR_CUSTOMIZATION | bottom_bar_customization | — | express→`ExpressBottomBarCustomizationScreen` 否则 `BottomBarCustomizationScreen`，均传 `::recordBottomBarChanged` | 外观设置 | `:487-491` |
| DAY_NIGHT_MODE | day_night_mode | — | `DayNightModeScreen(onThemeModeChanged)` | 外观设置 | `:492` |
| THEME_COLOR_SETTINGS | theme_color_settings | — | `ThemeColorSettingsScreen(onThemeColorStyleChanged)` | 外观设置 | `:493` |
| HOME_COMPONENT_OPACITY | home_component_opacity | — | `HomeComponentOpacityScreen` | 外观设置 | `:494` |
| HOME_SENTENCE_SETTINGS | home_sentence_settings | — | `HomeSentenceSettingsScreen` | 外观设置 | `:495` |
| NOTIFICATION_SETTINGS | notification_settings | — | express/normal 分流 | 外观设置 | `:496` |
| CUSTOM_BACKGROUND_SETTINGS | custom_background_settings | — | `CustomBackgroundSettingsScreen(onCustomBackgroundChanged)` | 外观设置 | `:497` |
| MIRROR_TEMPLATES | mirror_templates | dataset | `MirrorTemplateScreen(→MIRROR_FORMAT_GUIDE)` | 规则控制屏 | `:498-502` |
| MIRROR_FORMAT_GUIDE | mirror_format_guide | — | `MirrorFormatGuideScreen` | 上一屏 | `:503` |
| SPONSOR / SPONSOR_LIST / CO_BUILDER_LIST | 3 条 | — | `SponsorScreen` / `SponsorListScreen` / `CoBuilderListScreen` | 功能中心「关于软件」类 | `:504-506` |
| APP_TRAFFIC_STATS | app_traffic_stats | — | `AppTrafficStatsScreen` | 功能中心；normal 底栏页 | `:507` |
| OPTIONAL_FEATURES / HIDDEN_FEATURES | 2 别名 | — | express→`ExpressHiddenFeaturesScreen` 否则 `HiddenFeaturesScreen` | 功能中心（固定常驻） | `:508-509` |
| WORK_MODE_SELECTION | work_mode_selection | — | **不在本 Activity 渲染**：`WorkModeActivity.start(...)` + `finish()` | `ScreenDestinations.workModeSelection` | `:91-95`(onCreate)、`:207-210`(openRoute)、`:510-513`(when) |
| USAGE_WIZARD | usage_wizard | — | **不渲染**：`ModeOnboardingActivity.start(this, 当前模式)` + `finish()` | `ScreenDestinations.usageWizard` | `:96-100`、`:211-214`、`:514-517` |

> `EXTRA_RULE_SCOPE`/`EXTRA_RULE_KIND`/`EXTRA_TITLE` 三键定义在 companion 底部（`:556-559`），getter 在 `:48-73`。`CacheSettingsScreen` 一行内**误用** `requestedRuleDataset` 而非已解构的 `ruleDataset`（`:430`），二者当前等价（都源自同一 getter），但属可读性缺陷。

### 2.4 路由清单表 · LogRouteActivity（9 条）

参数：`EXTRA_ROUTE`(`log_route`, 默认 LOG_DASHBOARD)、`EXTRA_DATASET`(`log_dataset`, 缺省按模式回退)、`EXTRA_REQUEST_SOURCE`(`log_request_source`)。分流判据是 **dataset == EXPRESS**（`:103`），与 SettingsRouteActivity 用「当前模式」不同——这是一个真实的语义差异，服务器模式 `dataset=DNS_MODE` 时此处会走 normal 分支。

| 路由 | 目标屏 | 入口 | 行 |
|---|---|---|---|
| DNS_LOGS / HTTP_REQUEST_LOGS | express→`ExpressRequestLogScreen`；否则 `RequestLogScreen(initialSource)` | 仪表盘「请求日志」卡 | `:105-119` |
| DNS_CACHE | `DnsCacheScreen(dataset)` | 仪表盘 | `:120` |
| RACE_STATS | `RaceStatsScreen(dataset)` | 仪表盘 | `:121` |
| BOOTSTRAP_STATS | `BootstrapStatsScreen(dataset)` | 仪表盘 | `:122` |
| SUBSCRIPTION_INTERCEPTION_STATS | `SubscriptionInterceptionStatsScreen(dataset)` | 仪表盘 | `:123` |
| PROVIDER_HEALTH | `ProviderHealthScreen(dataset)` | — **无导航调用点**（全仓 grep 仅命中本分支）| `:124` |
| APP_TRAFFIC_STATS | `normal.ui.AppTrafficStatsScreen`（无 dataset 参数） | normal 仪表盘（`onNavigateToTrafficStats`） | `:125` |
| else（LOG_DASHBOARD 等） | express→`ExpressLogDashboardScreen` / 否则 `ModernLogDashboardScreen` | 底栏「日志仪表盘」页 / 首页 | `:126-149` |

`LogRouteActivity.openRoute` 用 `startActivity`（非 ForResult），**不回传任何变更位**；`childLaunchInProgress` 在 `onResume` 复位（`:71-74`）。

### 2.5 SettingsScreen 的固定入口清单（`ScreenDestinations.mainEntries`）

`ui/SettingsSearchCatalog.kt:36-51` 共定义 **14** 个 `SettingsDestination`（10 个 `main()` + 4 个 `child()`），但 **`all` 列表只登记 6 个**：`cacheSettings`、`logRetentionSettings`、`foregroundBackgroundSettings`、`workModeSelection`、`languageSettings`、`usageWizard`；`mainEntries = all.filter{ mainSection != null }` → **SettingsScreen 实际只渲染这 6 行**（按 `SettingsSection` 6 值分组，`ui/SettingsScreen.kt:48-67`，`onClick = onNavigateToRoute(destination.route)`，`:63`）。
**未被 `all` 收录、因此不会出现在 SettingsScreen 的 8 条**：`raceModeProviders`、`outboundProxy`、`dataCleanup`、`agentApiSettings`（4 个 main）+ `resolutionSingle/Smart/Parallel/Backup`（4 个 child）。其中 4 个 main 仅被当作**标题常量**复用（`SettingsRouteActivity.kt:402/430/431/432/436` 读 `.title`），路由本身由功能中心/首页承载；4 个 child 只服务 `DnsResolutionMode.route` 扩展映射的语义命名。**init 的两条 `require` 校验也只覆盖 `all`**（`:55-61`），故这 8 条不受「必须一级或有父路由」约束。
`languageSettings` 行在 `SettingsScreen` 里被特殊处理，标题/副标题走 `stringResource` 而非 `localizedText`（`SettingsScreen.kt:60-61`）。
`SettingsSection` 6 值：WORK_MODE(0)/PERFORMANCE(1)/BEHAVIOR(2)/APPEARANCE(3)/DATA(4)/OTHER(5)——**APPEARANCE 段没有任何条目登记**，即设置页里「外观」分组恒空、由功能中心承载。

---

## 3. 主屏逐组件（normal / express / server 三态）

### 3.1 首页 pager 与底栏容器（共用结构）

| 组件 | normal (`MainScreen.kt`) | express (`ExpressMainScreen.kt`) | server (`DnsMainScreen.kt`) |
|---|---|---|---|
| 容器 | `HorizontalPager(beyondViewportPageCount=(n-1).coerceAtLeast(1))` `:177-183` | 同 `:145-151` | 同，`tabs=DnsNavTab.entries` `:152-159` |
| 页来源 | `bottomBarItems = AppearanceSettingsStore.getBottomBarDestinations` `:119-121` | `ExpressBottomBarDestination.getDestinations` `:99-101` | 固定枚举 |
| 顶栏 | HOME/FEATURE_HUB 用 `Scaffold+TopAppBar`（transparent container）`:186-209`；其余页 `showBackIcon=false` | 同；标题 "谛听 · 极速" `:164` | 单一 Scaffold，标题随 currentTab 变 `:111-121` |
| 底栏 | `FloatingNavigationBar(selectedPage, onPageSelected, items=bottomBarItems, pagerProgress=…)` `:336-364` | 同 `:278-298` | 同，`items=tabs` `:210-215` |
| 切页动画 | pageAlpha 淡出90ms→scrollToPage→淡入150ms，`finally snapTo(1)` `:341-354` | 同 `:283-291` | 同 `:77-96` |
| 返回键 | `BackHandler(currentPage!=0)` → `animateScrollToPage(0, 280ms)` `:165-172` | 同 `:138-142` | 同 `:98-105` |
| 重置到首页 | `LaunchedEffect(resetToHomeTrigger) { if(>0 && page!=0) scrollToPage(0) }` `:135-139` | 同 `:115-119` | 同 `:71-75` |
| 页项数收缩保护 | `LaunchedEffect(size) { if(currentPage>=size) scrollToPage(0) }` `:141-145` | 同 | 无（固定 3） |
| 底栏配置回读 | `LaunchedEffect(bottomBarRefreshRequested)` + `DisposableEffect(ON_RESUME)` 双路 `:128-156` | 同 `:108-136` | — |
| 重复点当前页 | 若当前页是 LOG_DASHBOARD → `logDashboardRefreshTrigger++` `:357-359` | 同 `:292-294` | — |

`resetToHomeTrigger` = `System.currentTimeMillis()`，由 `MainWorkModeCoordinator.switchWorkMode()` 写入（`MainWorkModeCoordinator.kt:94`），MainActivity 透传（`MainActivity.kt:154`）。

### 3.2 首页 HOME 页组件逐项（normal `MainScreenContent.kt` / express `ExpressHomeContent.kt`）

两屏结构**几乎逐行同构**（复制而非复用），差异仅在状态源。

| 组件 | 显示条件 | 数据来源 | 动作链 | 状态机 |
|---|---|---|---|---|
| `DataResetNoticeCard` | `showDataResetNotice`（`SystemSettingsStore.isDataResetNoticePending`，ON_RESUME 重读）| MainActivity 侧无；由 pager 层算出后传参 | `onDismiss` → `SystemSettingsStore.dismissDataResetNotice` + 本地置 false | 出现/消失，AnimatedVisibility 180ms |
| `PowerToggleButton` | 恒显，外层 `Box.alpha(powerButtonOpacity)` | normal: `uiState.isRunning/isBusy`（MainViewModel）；express: `ExpressVpnController.isRunning` StateFlow + `isBusy=false` 硬编码 | normal: `onToggle{ onToggle(uiState.isRunning) }` → `MainVpnController.onToggleVpn` → (API33+ 缺通知权限) 通知申请 → `prepareVpn()` → `VpnService.prepare` → `startVpnService()` → `DnsVpnService.startIntent` startForegroundService；express → `ExpressModeLauncher.toggle` | 三态 busy/running/stopped；`enabled = !isBusy && selectedProvider!=null && (SINGLE || raceIds.size>=2)` |
| 首页句子 `Text` | `homeSentence.isNotEmpty()`；running/stopped 二选一 | `AppearanceSettingsStore.getHomeSentenceRunning/Stopped` | 无（纯展示），`alpha(poemOpacity)` | — |
| 解析服务选择框（单选态） | `resolutionMode == SINGLE`（Crossfade 160ms 切两套 OutlinedTextField）| `viewModel.selectedProvider` | `clickable` → `showProviderDialog=true` → `ProviderSelectionDialog`；`MANAGE_PROVIDER_ID`→服务商管理；`PROVIDER_VISIBILITY_ID`→服务显示；其他→`viewModel.selectProvider(id)` → 持久化 + `refreshRuntimeConfigIfRunning("main_provider_changed")` | `alpha(providerSelectorOpacity)` |
| 解析服务选择框（多路态） | `resolutionMode != SINGLE` | `raceProviderIds` ∩ `providers` → `raceProviderSummary` | `ModeProviderSelectionDialog.onProviderToggled` → `viewModel.toggleModeProvider(mode,id)` → 按模式写 SMART/PARALLEL/PRIMARY_BACKUP 名单 → 若当前模式==该模式则 `refreshRuntimeConfigIfRunning` | 同上 |
| `ProviderEndpointList` | `resolutionMode != SINGLE` | `raceProviders` | 无 | `alpha(dnsDetailOpacity)` |
| 单服务 endpoint 文本 | else 分支 + `selectedProvider != null` | `provider.endpointLabel()` | 无 | 同上 |
| 模式按钮 `Button` | 恒显 | `resolutionMode.displayName` | `onNavigateToRaceModeSettings` → `Routes.RACE_MODE_PROVIDERS` | 非 SINGLE 时底色 primaryContainer（200ms 色动画）；normal 额外 `enabled=!isBusy`，express **无** enabled |

`displayProviders` 组装规则（两屏同）：①若选中服务被隐藏则置顶补回 ②可见服务列表 ③"管理服务…" ④"服务显示…"（`MainScreenContent.kt:161-168`、`ExpressHomeContent.kt:176-183`）。

### 3.3 服务器模式 HOME 页（`server/ui/DnsHomeScreen.kt`）

LazyColumn 6 个 item：①`PowerToggleButton(busyLabel="启动中", runningLabel="停止")` + 5 态状态文案（RUNNING/STARTING/STOPPING/ERROR/STOPPED，`:50-56`）+ ERROR 时 errorReason 红字 ②「当前上游」`SettingsNavigationItem` → `onNavigateToServers`（切到底栏第 2 页，非 Activity）③「局域网接入」多 IP×端口展示（`NetworkInfoProbe.probe().ipv4Addresses` + `DnsListenPortValidator.formatEndpoints`，不可用时提示"未连接 Wi-Fi 或未分配 IP"）④「服务状态」5 项统计（queryCount/cacheHitCount/blockedCount/latency/uptime）⑤底部说明文本。`DnsModeHost` 在 ON_RESUME 若 `DnsModePreferences.isServiceActive && status==STOPPED` 自动重启服务（`DnsModeHost.kt:33-47`）。
服务器 SETTINGS 页 5 组：缓存设置/规则控制/本地监听端口 + 黑/白/Hosts 覆写 + 重置运行统计 + 忽略电池优化 + 使用向导/重新选择工作模式（`DnsSettingsScreen.kt:62-212`），规则类跳 `SettingsRouteActivity.createIntent(…, dataset=RuleDataset.DNS_MODE)`（`:51-55`）。
两个对话框挂在 `DnsMainScreen`：重置统计确认 `AppConfirmDialog` `:219-231`、`DnsPortEditDialog` `:233-241`。

### 3.4 功能中心（FeatureHub）入口全集

normal 7 类共 **28** 张候选卡片（27 个受 `HiddenFeature` 门控 + 1 张固定「隐藏功能管理」），`FeatureHubScreen.kt:141-285` 实测 `add(` 28 行；express 5 类共 **19** 张（18 个门控 + 1 固定），`ExpressFeatureHubScreen.kt:128-230` 实测 `add(` 19 行。门控集合与 `EXPRESS_SUPPORTED_FEATURES`（18 项，`ExpressHiddenFeaturesScreen.kt:38-66`）**完全一致**（集合差为空）。**唯一带长按的卡片是「日志」**：`onClick=onNavigateToLogs`、`onLongClick` = 标记已读 `SettingsGuides.HOME_LOG_LONG_PRESS_ID` + `onNavigateToLogRetentionSettings()`（`FeatureHubScreen.kt:240-252` / express `:185-197`），提示文案由 `R.string.feature_hub_long_press_hint` 渲染在同一位置且自身也挂 `combinedClickable`（`:398-412`）。
「隐藏功能管理」卡片**固定常驻、不受 HiddenFeature 开关控制**（normal `:229`、express `:174`）。空分类被过滤：`visibleCategories = categories.filter { it.items.isNotEmpty() }`（normal `:287-289`）——即整类可被全隐藏。
卡片本体：2 列 `LazyVerticalGrid`，高 84dp，`SettingsCornerShape`，按下缩放 0.90f（spring NoBouncy / 回弹 damping 0.38）。

### 3.5 MainActivity 层对话框（3 个，互斥顺序）

| 对话框 | 显示条件 | 动作 | 行 |
|---|---|---|---|
| `InitialAgreementDialog` | `!SystemSettingsStore.isInitialAgreementAccepted` | accept → 写标志 + `workModeCoordinator.onAgreementAccepted`；decline → 清 disclosure + `MainStartupCoordinator.declineInitialAgreement`（停 VPN、`VpnMonitorManager.stop`、`finishAndRemoveTask`）；`BackHandler(enabled=true)` 拦截返回键 = decline | `MainActivity.kt:118-131`, `MainActivityDialogs.kt:13-32` |
| `PermissionDisclosureDialog` | `vpnController.permissionDisclosure != null`（三枚举值各一套文案） | continue/dismiss 各按 disclosure 分派：VPN→`setVpnExplained(true)`+`prepareVpn()`；NOTIFICATION→申请或放行；BATTERY→`setDismissed`/`requestPermission` | `MainActivity.kt:163-169`, `:111-149` |
| `AppUpdateDialog` | `appUpdateHost.state.availableUpdate != null && dismissedVersion != update.version` | dismiss 记版本；download → `AppUpdateHost.downloadUpdate()`；`onStop` 取消在途下载 | `MainActivity.kt:171-180`, `:233` |

三者都渲染在同一个 `AppThemeSurface` 内，顺序为：协议（替换主页内容）→ 底栏 pager → disclosure 叠加 → update 叠加。

---

## 4. 工作模式体系

### 4.1 三模式定义（`ui/mode/AppWorkMode.kt`）

| 枚举 | storageValue | title | badge | summary | minApi | icon |
|---|---|---|---|---|---|---|
| NORMAL | `normal` | 普通模式 | 推荐 | 全量域名解析、黑白名单、HTTPS 检查、网络管控 | 29 | Layers |
| DNS | `dns` | 服务器模式 | 轻量 | 纯 DNS 代理与解析加速、低功耗 | 29 | Dns |
| EXPRESS | `express` | 极速模式 | 极速 | 纯 Kotlin、DNS 加速与规则过滤、Android 7+ (64位) | 24 | Bolt |

`isSupportedOnCurrentDevice()`（`:48-61`）：先比 `SDK_INT<minApiLevel`；EXPRESS 额外要求 64 位（M+ 用 `Process.is64Bit()`，否则查 `SUPPORTED_64_BIT_ABIS`），`runCatching…getOrDefault(false)`。`fromStorageValue` 未知值 → **NORMAL**（`:64-66`）。三模式 `isAvailable` 全 true（字段当前不参与门控）。
不支持时的 UI：卡片 alpha 0.45 + 点击弹 Toast（极速→「仅支持 64 位设备且需 Android 7+」；其他→「仅支持 Android 10 (API 29) 及以上」），`WorkModeComponents.kt:128-145`。

### 4.2 持久化（`ui/mode/WorkModeStore.kt`，42 行）

SharedPreferences 文件名 **`diting_settings`**（`:6`，与 `ui.settings` 包内的 `dns_vpn_prefs` 是**两个不同的文件**）。4 个键 + 1 个 reset：
`app_work_mode`(String storageValue)、`work_mode_initial_selected`(Boolean)；`resetWorkModeSelection()` 同时移除两键（`:35-41`）。

`ModePermissionStore`（`permission/ModePermissionStore.kt`）用第三个文件 **`mode_permission_preferences`**，前缀键 `onboarding_completed_<storageValue>`、`permission_explained_*`、`recommendation_dismissed_<PERMISSION.name>`。

### 4.3 启动决策表（MainActivity.onCreate）

```
1 AppSettings.performStartupSelfCheck + CrashLogManager.consumePendingAutoExportNotice   [MainStartupCoordinator:26-31]
2 applyRecentsPrivacySetting()                                                          [MainActivity:237-238]
3 checkStartupOnboarding(intent):                                                       [MainWorkModeCoordinator:38-65]
    currentWorkMode/hasSelectedWorkMode ← WorkModeStore
    若 老用户(已同意协议 && 已选模式) 但 该模式引导未完成 → 一次性把三模式全部标记为已完成（迁移补偿 :47-51）
    handleWorkModeChangeIntent(intent)  ← 处理来自 WorkMode/Onboarding 的 CLEAR_TOP 回跳
    若 已同意协议 且 未选模式            → WorkModeActivity(isFirstLaunch=true) + finish()      返回 false
    若 已同意协议 且 该模式引导未完成     → ModeOnboardingActivity(当前模式, isFirstLaunch=true) + finish() 返回 false
    否则 true
4 setContent: !协议 → InitialAgreementDialog；协议 && hasSelectedWorkMode → MainModeDispatcher
5 onCreate 末尾（setContent 之后）：协议 && 已选模式 → initializeAcceptedExperience()
    且 若模式==EXPRESS 额外 ExpressModeLauncher.switchToExpress(...)                     [MainActivity:184-191]
```

`initializeAcceptedExperience` 幂等（`acceptedExperienceInitialized` 布尔守卫，`MainStartupCoordinator.kt:39`）：启动更新检查（可被 `isStartupUpdateCheckDisabled` 关）→ IO 协程建通知渠道 + `delay(500ms)` 后预热 Room 并 `DefaultWhitelistSeeder.ensureInitialized` → `onAutoStartVpn()` → `VpnMonitorManager.sync`。

### 4.4 模式切换流程与副作用（`MainWorkModeCoordinator.switchWorkMode:83-117`）

```
setAppWorkMode + setWorkModeSelected(true) + hasSelectedWorkMode/currentWorkMode = 新模式
resetToHomeTrigger = currentTimeMillis()          // 三模式首页都回第 0 页
互斥清理（只在「离开」时做，不在新模式里做）：
  离开 DNS   且 新≠DNS → DnsModeManager.stopService
  离开 EXPRESS 且 新≠EXPRESS → ExpressModeLauncher.stopExpress
若新模式引导未完成 → ModeOnboardingActivity.start(mode) 后 return（副作用中止）
新模式 == DNS     → onStop()（停 VPN） + VpnMonitorManager.stop
新模式 == EXPRESS → ExpressModeLauncher.handleModeSelected{ onInitializeAccepted() }
新模式 == NORMAL  → onInitializeAccepted()
```

`ExpressModeLauncher.switchToExpress`（`express/ExpressModeLauncher.kt:33-68`）自身也做一次互斥清理：`WorkModeLifecycleRegistry.stopOtherModes(ctx, EXPRESS)`（停 normal+server）+ `VpnMonitorManager.stop` + 写 WorkModeStore + 建通知渠道（含 `ExpressNotificationBuilder.ensureChannel`）+ IO 协程 `ExpressDefaultsSeeder.ensureInitialized` → `ExpressVpnController.initialize` → `VpnMonitorManager.sync` → 主线程回调。**该函数内部又写了一次 WorkModeStore**，与 coordinator 的写入重复（幂等，但两处写入点在 Flutter 侧要合并为单一状态源）。

三模式互斥的通用注册表：`core/WorkModeLifecycleRegistry.stopOtherModes(ctx, active)`（`:69-84`），按 active 调 `stopNormalMode/stopServerMode/stopExpressMode` 三个可替换 lambda（`:12-40`，lambda 默认用 `Intent().setClassName(pkg, "…Service")` 反射式构造）。

### 4.5 onResume/onNewIntent 同步

`syncOnNewIntent`：先处理 WORK_MODE_CHANGED intent，再从 Store 重读两值（`MainNavigationCoordinator` 无关，`MainWorkModeCoordinator.kt:138-147`）。
`syncOnResume`（`:149-168`）三分支：DNS 无操作（注释「lifecycle and status are managed inside DnsModeHost」）；EXPRESS 手工发一条包内广播 `ACTION_VPN_STATUS_CHANGED` + `EXTRA_VPN_RUNNING`（legacy 桥，让 normal 侧的接收器也收到状态）；NORMAL 走 `onRefreshStatus()`。三模式共尾部 `VpnMonitorManager.sync(activity)`。

### 4.6 WorkModeActivity 的选择 + 展开动画时序

- `WorkModeSelectionScreen`（`:47-168`）：`isFirstLaunch` 决定外壳是 `Scaffold`（首启，无返回栏）还是 `SettingsScaffold("模式切换")`；卡片列表 = `AppWorkMode.entries` 顺序（NORMAL, DNS, EXPRESS），缝隙堆叠圆角（首末 28dp、内侧 4dp），`isSelected` 仅在**非首启**时按 `mode == currentMode` 点亮（`:210`）。
- 点击 → `triggerTransition`：`transitionAnim.animateTo(1f, tween(1000ms, MaterialEmphasizedDecelerate))` → 完成后**依次**调 `onModeSelected(mode)` 与 `onTransitionFinished()`（`:70-83`）。期间 baseContentAlpha = `(1 - progress*2.5)`，即前 40% 动画里原列表淡出。
- 展开层 `WorkModeExpansionOverlay`（`WorkModeExpansionTransition.kt:99-252`）：位置矩形 lerp(卡片→全屏)、圆角恒 28dp、颜色 lerp(surfaceContainerHigh→surface)、双层内容相位淡入淡出（cardAlpha=1-p/0.35，revealAlpha=(p-0.35)/0.45），揭示层显示模式图标 + 「正在进入...」。
- `BackHandler(enabled = transitioningMode != null)` 空实现 → 动画期间禁用返回（`:63-65`）。
- Activity 层（`WorkModeActivity.kt:59-88`）：`onModeSelected` **立即**写 Store（此时动画才完成）；`onTransitionFinished` 若首启或新模式引导未完成 → 转 `ModeOnboardingActivity`，否则 `returnToMainActivity(mode)` = `CLEAR_TOP|SINGLE_TOP` + `EXTRA_WORK_MODE_CHANGED` + `EXTRA_TARGET_WORK_MODE` + `overrideFadeTransition()` + `finish()`。
- 转场工具三函数（`WorkModeExpansionTransition.kt:60-93`）：`disableWindowTransitions`（API34+ 用 `overrideActivityTransition`，否则 `overridePendingTransition`）、`overrideFadeTransition`、`overrideOpenFadeTransition`。`DnsMainActivity` 用前者，WorkMode/Onboarding 用后两者。

### 4.7 引导（`onboarding/` 4 文件，1203 行）

三步固定流程（`ModeOnboardingScreen.kt:76 totalSteps=3`），`AnimatedContent` 水平滑入（±width/3 + fade，方向按前进/后退判定 `:291-298`），顶部 3 段进度条（当前 primary / 已过 0.4 alpha / 未至 surfaceContainerHighest `:248-264`）。

| 步骤 | 内容 | 每模式配置（`ModeOnboardingRegistry.getConfig`） |
|---|---|---|
| 0 特性 | `OnboardingFeatureStep`，3 张 feature 卡（44dp 图标容器 + 标题 + 描述） | NORMAL: 全隧道 Go 栈接管 / 全功能规则过滤分流 / 可选 HTTPS 检查<br>EXPRESS: 纯 Kotlin 窄路由 / 4 种上游调度策略 / 64 分片 LRU + 规则<br>DNS: 局域网 0.0.0.0:$port 监听 / 不占 VPN 槽位 / 共享规则库与缓存 |
| 1 权限 | `OnboardingPermissionStep`：逐条 44dp 图标 + 等级徽章（REQUIRED=errorContainer / 其他=secondaryContainer）+「已就绪/授权」二态按钮；DNS 模式顶部额外插 `DnsListenPortValidator.noVpnDisclaimer(port)` 提示卡 | NORMAL: VPN + NOTIFICATION + PACKAGE_QUERY + BATTERY（4）<br>EXPRESS: VPN + NOTIFICATION + BATTERY（3）<br>DNS: NOTIFICATION + BATTERY（2） |
| 2 上手 | `OnboardingGuideStep`：3 条 tip 卡；DNS 模式额外顶部「本机局域网服务接入信息」卡（IP:端口列表 + 复制按钮写剪贴板 + `accessInstruction(port)` + `unusablePortWarning` 红字） | 三模式各 3 条，文案见 `ModeOnboardingSteps.kt:98-114/147-163/195-211` |

底部按钮状态机（`ModeOnboardingScreen.kt:126-231`）：步骤 <2 → [（步骤>0 才有）上一步] + [下一步]；步骤 ==2 → 满宽「开始并使用」(→`onComplete(true)`) + 一行 [上一步][进入主页](→`onComplete(false)`)；顶栏右上「跳过引导」恒在 → `onSkip`。
Activity 侧（`ModeOnboardingActivity.kt:203-219`）：`finishAndReturnToMain(startService)` **无条件** `setOnboardingCompleted(targetMode,true)` + `setAppWorkMode` + `setWorkModeSelected(true)`，然后 CLEAR_TOP 回 MainActivity 带 `EXTRA_WORK_MODE_CHANGED`/`EXTRA_TARGET_WORK_MODE`，`startService` 为真时再带 `EXTRA_AUTO_START_VPN`。
权限申请分派（`:159-201`）4 个 launcher（`vpnLauncher:68`、`notificationLauncher:74`、`genericSettingsLauncher:80`、`appListPermissionLauncher:89`，实测 `grep -c registerForActivityResult` = 4）；`appListRequestAttempted` 一次性标志决定 PACKAGE_QUERY 走 `RequestPermission` 还是回落系统设置（`:192-199`）。
状态存储：`ModePermissionStore`（§4.2），MainActivity 首启用协议时会对三个模式**批量补写** true（`MainWorkModeCoordinator.kt:47-51`）——即老版本升级用户不再看到引导。

---

## 5. 个性化（主题 / 色板 / 字体 / 透明度 / 底栏）

### 5.1 生效机制

`AppThemeSurface(themeMode, colorStyle, backgroundEnabled, backgroundUri)`（`ui/AppThemeSurface.kt:26-105`）→ `DITINGTheme(darkTheme, colorStyle, transparentBackground)` → `MaterialTheme(colorScheme, Typography)`。
- darkTheme 解析：SYSTEM→`isSystemInDarkTheme()`、LIGHT→false、DARK→true（`:70-74`）。
- colorScheme：`colorStyle==SYSTEM && SDK>=S` → `dynamicDark/LightColorScheme(context)`；否则 `palette(dark).toColorScheme(dark)`（`ui/theme/AppTheme.kt:60-65`）。
- 自定义背景时 `background=Color.Transparent` + `Surface(color=Transparent)` + 全幅 `Image(Crop)` + 黑色遮罩（dark 0.34f / light 0.16f）（`:76-99`）。背景位图由 `ui/background/CustomBackgroundManager` 单例缓存，`backgroundUpdateFlow: StateFlow<Long>` 驱动所有页面同步刷新（`:39-68`）。
- **每个 Activity 各自读一次 4 个外观值**：MainActivity 带刷新触发器（`:91-109`）、SettingsRouteActivity 带 `routeRefreshVersion` key（`:105-108`）、LogRouteActivity 只在 remember 里读一次（`:42-45`，无热更新）、WorkModeActivity / ModeOnboardingActivity 同样一次性读（`WorkModeActivity.kt:37-40`、`ModeOnboardingActivity.kt:112-115`）。

### 5.2 选项全集

| 维度 | 可选值（storageValue → 显示名） | 设置屏 | 键（文件 `dns_vpn_prefs`） |
|---|---|---|---|
| 日夜模式（3） | system 跟随系统 / light 浅色模式 / dark 深色模式 | `DayNightModeScreen`（`SettingsRadioItem` 单选，3 项） | `app_theme_mode` |
| 主题色（9） | system 跟随系统、purple 鸢尾紫、blue 睡莲蓝、cyan 池水青、green 柳叶绿、orange 暮光赭、red 罂粟红、pink 暮霞粉、**indigo 麦穗金（枚举名 GOLD，storageValue 是 "indigo"）** | `ThemeColorSettingsScreen`（9 行 + 圆形色样，选中打勾） | `theme_color_style` |
| 首页透明度（5 项 + 1 全局） | 0.1–1.0 连续，`Slider(steps=8)`，`valueRange=0.1f..1f` | `HomeComponentOpacityScreen`（分组：交互组件 3 项 / 文字 2 项） | `home_power_button_opacity`、`home_provider_selector_opacity`、`home_mode_button_opacity`、`home_poem_opacity`、`home_dns_detail_opacity`；回退链 `home_component_opacity`（未单独设置时继承全局，`AppearanceSettingsStore.kt:67-71`） |
| 首页句子（2 条） | 任意文本，可留空（留空即不显示）；默认「谛听万象，明察清浊」/「收耳静眠，归于无声」 | `HomeSentenceSettingsScreen`（两个 OutlinedTextField + 「确定」一次写两键后 onBack） | `home_sentence_running`、`home_sentence_stopped` |
| 自定义背景 | 多壁纸图库（JSONArray `custom_background_uris`）+ 当前选用（`custom_background_uri`）+ 开关（`custom_background_enabled`）；开关生效需「当前 URI ∈ 图库」（`isCustomBackgroundEnabled:120-124`） | `CustomBackgroundSettingsScreen`（`OpenDocument` 选择器 + 3 列缩略图 + 长按删除确认，删除时释放 SAF 持久授权 `SafGrantDecisions.releasesOnRemove`） | 同上 |
| 底栏（normal 6 选 2–4 / express 4 选 2–4） | `["home","feature_hub","log_dashboard","app_traffic_stats","network_tools","settings"]`；JSON 数组字符串，解析失败/少于 2 项回落 `[home,feature_hub,log_dashboard]` | `BottomBarCustomizationScreen`（normal，含实时预览卡）/ `ExpressBottomBarCustomizationScreen`（express，无预览卡） | `bottom_bar_destinations` |
| 底栏触感 | 布尔，默认 **true** | `AppearanceSettingsScreen` 内 `SettingsSwitchItem` | `bottom_bar_haptic_enabled` |

外观设置主页（`ui/AppearanceSettingsScreen.kt:51-128`）3 组 7 项：界面显示（日夜 / 主题色 / 首页透明度 / 底栏自定义）、首页内容（首页句子 / 通知栏设置，副标题文案按当前模式区分是否含「网速显示」`:93-97`）、背景与动效（软件背景 / 底栏触感反馈）。

**字体体系**：`ui/theme/AppTypography.kt` 全文 17 行，仅覆盖 `bodyLarge`（Default 字体族 / Normal / 16sp / lineHeight 24sp / letterSpacing 0.5sp），其余 14 个 M3 role 用 Material3 默认值。**没有**任何字体选择、字号缩放或自定义字体文件的用户选项。各屏大量以 `.copy()` 局部覆写（如 WorkModeCard 的 bodySmall 11sp/15sp）。

### 5.3 底栏组件语义（`FloatingNavigationBar.kt` 493 行）

- 玻璃态仅在 **light** 且 `isGlassEnabled` 时启用：`isGlassActive = isGlassEnabled && surface.luminance() >= 0.5f`（`:119-120`）；深色下退化为不透明 surfaceContainer（浅色 0.58f alpha）。
- 尺寸：nav 段宽 2→204dp / 3→276dp / 4→340dp，高 64dp，指示器 56dp，`tabsCount` 强制 `coerceIn(2,4)`。
- 交互全集（类注释 `:84-109` 逐条列明）：1:1 跟手拖拽（`DampedDragAnimation`，pressedScale 78/56）、整条胶囊橡皮筋（`rubberBandPx=4dp`，`EaseOut` 变换）、速度驱动的挤压拉伸（`scaleX /= 1-velocity*0.75` clamp ±0.2，`scaleY *= 1-velocity*0.25`）、松手吸附最近页、点击按触点选页、跨界震动（`onDragSlideTick`）、越界撞击震动（`onDragBoundaryBump`）、切页震动（`onTabSwitchClick`）、当前页重复点击回弹（`pulseRebound`）、重力感应高光（`rememberDeviceTilt(enabled=isGlassActive)`，两处 specular 各 -45°/+90°）。
- pager 协调：传入 `pagerProgress` 时走 `snapshotFlow` 跟随；由本条发起的切页会置 `isPagerCatchUpPending` 并设 800ms 超时兜底（`:86-89, 186-195, 369-373`），避免指示器被拉回手指离开的页。
- 无障碍：每个 tab `semantics { role=Tab; selected; onClick(label) }`（`FloatingBottomBarTab.kt:45-49`），图标/文字双份叠绘按 `weight()` 交叉 alpha。
- `isGlassEnabled` 仅预览卡传 true（`BottomBarCustomizationScreen.kt:526-531`）；预览按容器宽度等比缩放（最小 0.7f）。

### 5.4 电源按钮（`ui/PowerToggleButton.kt` 156 行）

三态由 `isBusy`/`isRunning` 决定；四组色 + 三组尺寸同步 250ms `animateColorAsState/animateDpAsState`：glow 128/108dp、halo 148/124dp（非运行透明）、button 92/84dp、container primary/surface、content onPrimary/primary。`isBusy` 时以 42dp `CircularProgressIndicator(4dp)` 替换图标。触感：停止时 `REJECT`(R+) 否则 `CONFIRM`，低版本回落 `KEYBOARD_TAP`，带 `FLAG_IGNORE_VIEW_SETTING`。三个 label 参数可覆写（服务器模式传「启动中/停止/开启」）。`enabled=false` → 整体 alpha 0.5。

---

## 6. 附属功能

### 6.1 批量添加规则（`ui/batch/` 7 文件，1989 行）

- **分类器** `BatchRuleClassifier.classify(raw, mode, dataset)` 返回 `List<ClassifiedLine>`（5 个子类 + Ignored），分支按**源码注释编号 1–9（含 2b）共 10 段**，另有最前置的 Ignored 判定，合计 11 段（`ui/batch/BatchRuleClassifier.kt:89-428`，注释行号 `:96/117/135/156/189/224/259/327/353/379`）：
  - 前置：空行 / `#` / `!` / `[…]` → Ignored（`:89-94`，并 `trimStart('﻿')` 去 BOM）
  - **1** `## #@# #?# #$#` 元素隐藏；非 NORMAL 数据集先由 `cosmeticRuleRejection(dataset)` 拒绝（`:96-115`）
  - **2** 显式 `http(s)://` 与 `@@http(s)://` URL；`dataset==DNS_MODE` 拒绝（`:117-133`）
  - **2b** AdGuard/ABP 的 `||domain/path^`、`||*/api/ad^` urlBlock / urlAllow；`DNS_MODE` 拒绝（`:135-153`）
  - **3** `$dnsrewrite=`（无 rewrite 时回落 blockRules）（`:156-187`）
  - **4** dnsmasq `address=/`、`server=/`（block/rewrite/invalid 三出口）（`:189-222`）
  - **5** `->`/`=>`/`=` 显式映射，**先剥 `$modifier` 尾**再判；且 `@@`/`||` 开头不走此段（`:224-257`）
  - **6** 多 token：首 token 是 IP → sinkhole 集合内判屏蔽、否则逐域名转覆写；次 token 是 IP → 反向 hosts（`:259-325`）
  - **7** `@@` 显式白名单 / **8** `||` 显式黑名单 / **9** 裸域名按 `mode` 归白或黑（`:327-428`）
- **两处已修的词法陷阱**（务必保留判据）：`modifierSectionStart()` 只有 `$` 后跟字母或 `~` 才算修饰段起点，避免正则 `/ads\.example\.com$/` 的锚 `$` 被当分隔符（`:60-65`）；`ensureCaret()` 把 `^` 插到修饰段**之前**，避免 `||a.com^$~app=x^` 让 `appScope` 读成 `"x^"`（`:66-82`）。
- **识别模式**（`BatchRecognitionMode` 3 值）AUTO / WHITELIST_FIRST / BLACKLIST_FIRST，`fromTarget()`：WHITELIST→WHITELIST_FIRST、BLACKLIST→BLACKLIST_FIRST、其余→AUTO。屏幕顶部 3 个 `FilterChip` 可现场改（`BatchAddRulesScreen.kt:153-167`）。
- **校验器** `BatchRuleValidator.validate`：逐行分类 → 五类分派，输入内去重靠 `seenKeys`（Domain key = `block|allow:pattern:important:appScope:appInverted:dnsType:denyallow:isRegex`；Url key 先过 `goUrlRuleManager.parse` 归一化；Cosmetic key = `cosmetic:domain:selector:isException`；Rewrite key = `rewrite:domain:targetType:targetValue`），再查 DAO `idByPattern/idByKey`；覆写额外互斥：同域名已存在 IP 覆写则 CNAME 判 Invalid（反之亦然，`BatchRuleValidator.kt:246-253`）。
- **提交** `commitDetailed` 六段：block 域名（`insertAllForSource(…,"useradd")` + `blockListManager.syncCachedPattern`）、allow 域名（`SOURCE_USER`）、URL block/allow（逐条 `insertForSource`，返回值计数）、cosmetic（`compileScopedCss()` + `syncHttpsRequestRulesIfRunning`）、rewrite（`insertAllForSource` + `refreshCache(rebuildSubscriptionIndex=false)`）、最后 `RuntimeDnsSettingsRefresher.refreshRuleIndexesIfRunning(refreshBlock/Allow/Rewrite, dataset)`。`committableCosmeticItems` 是 dataset 守卫（CSS 编译器只绑 NORMAL 库，`BatchRuleEntities.kt:79-96`）。
- **屏幕**：编辑器为自绘 IDE 风（`CodeEditorLayout` 自定义 `Layout`：gutter Canvas 行号 + 1px 分隔线 + `BasicTextField`，Monospace 13sp/lineHeight 22sp，行号按 `TextLayoutResult` 逐**视觉行**回溯逻辑行并做 ±100px 视口裁剪）；顶栏两个 IconButton（粘贴 `LocalClipboard.getClipEntry` 并归一 CRLF→LF、清空）；底部状态条「共 N 行 \| M 字符」+「导入」按钮（校验中显 spinner）。占位文案按 dataset 分两套（`:425-429`）。
- **结果对话框** `BatchAddResultDialog`：三段指标带（有效/重复/无效 + 竖分隔线）、三种类别徽章（黑名单 error / 白名单 primary / 覆写 tertiary）、可折叠「查看异常规则明细」180dp 高滚动、`validCount==0` 时只有「返回修改」、否则「确认导入 (N条)」+「取消」。确认后 `commitDetailed` → Toast「成功导入 N 条规则 (黑名单 x，白名单 y，覆写 z)」→ `onBack()`。
- **实体映射** 5 个 `toXxxEntity` 扩展（`BatchRuleEntities.kt:21-77`），可脱离 Context 单测；`appScope/appInverted` 必须落到列（历史丢字段缺陷的回归点）。

### 6.2 云控名单（`ui/Recognition*` 4 文件）

- 数据源：`https://raw.githubusercontent.com/haoze-evolluling/DITING/main/recognition_members.json`（`RecognitionMembersRepository.kt:23-24`），头像 `…/avatars/`（`RecognitionAvatarRepository.kt:22-23`）。
- 刷新协议：`If-None-Match`/`ETag`（`preferences "recognition_members"."etag"`），304 → 返回 null（**只有真变更才落盘**）；上限 256 KiB（`contentLength` 与实读双校验），`AtomicFile` 写 `filesDir/recognition_members.json`；`Mutex` 串行刷新。
- 校验：必须有非 null `version`；`sponsors`+`coBuilders` 两个数组；成员 name 去空白非空、`avatarFileName` 必须匹配 `[a-z0-9_]+_avatar\.jpg`；名单内 name 唯一、头像名唯一。默认致谢语两类各一条。
- 头像：`loadAvatar` 先查本地有效图（`isValidImage` 用 `inJustDecodeBounds`），再 `downloadMutex` 双检后下载到临时文件（上限 1 MiB）+ `AtomicFile` 原子替换；`decodeScaled` 在 IO 线程按 2 的幂 `inSampleSize` 降采样 + `RGB_565`，按 `(path,size,targetPx)` 进程级缓存。
- UI：`SponsorListScreen`（刷新 + 排序切换 `asReversed()`，两个 action）与 `CoBuilderListScreen`（仅刷新）共用 `RecognitionList`/`RecognitionListItem`（48dp 圆头像，头像未到时文字左缩进 0dp→60dp 动画）。失败 Toast「名单更新失败：…」。

### 6.3 最近任务隐私（`ui/RecentsPrivacyController.kt` 全文 12 行）

`apply(activity, hide)` 遍历 `ActivityManager.appTasks` 逐个 `runCatching { task.setExcludeFromRecents(hide) }`。
调用点 3 处：`MainActivity.onCreate` + `onResume`（`:81, 227`，读 `SystemSettingsStore.isHideFromRecentsEnabled`）、`MainActivity.applyRecentsPrivacySetting`、`SettingsRouteActivity.applyRecentsPrivacy`（`:287-288`，由前后台行为屏回调）+ `MainNavigationCoordinator` 收到 `EXTRA_HIDE_FROM_RECENTS` 时再 apply 一次（`:37-42`）。
**语义注意**：这是「对已存在任务设标志」，不是设置 Activity 属性——新任务不受影响，故每次 onResume 都要重打一遍。Flutter 侧需等价机制（`android:excludeFromRecents` 无法动态改，须保留平台通道调用 ActivityManager）。

### 6.4 QS Tile 与外部跳转

- Tile 服务 `.tile.DitingTileService`（Manifest `:81-93`，`TOGGLEABLE_TILE=true`，图标 `dns_svgrepo_com`）。`onClick` 全程包在 `isLocked → unlockAndRun{}` 内（`:43-55`）。`performTileAction`：未同意协议 → `openMainActivity(requestVpn=true)`；否则按当前模式三选一（DNS→`DnsModeManager.toggle`；EXPRESS→`ExpressVpnController`；NORMAL→`DnsVpnService`），`VpnService.prepare!=null` 或前台服务启动被拒 → 回落 `openMainActivity(requestVpn=true)`（`:57-147`）。
- `openMainActivity` 用 `startActivityAndCollapse`（API34+ 传 `PendingIntent.getActivity`，低版本传 Intent，`:149-180`），flags `NEW_TASK|CLEAR_TOP` + `EXTRA_AUTO_START_VPN`。该 extra 由 `MainVpnController.handleAutoStartIfNeeded` 消费并**立即 remove**（`MainVpnController.kt:61-77`）：DNS 模式直接 `DnsModeManager.startService`；否则若未在跑，按需在 API33+ 先申请 POST_NOTIFICATIONS，再 `prepareVpn()`。
- Tile 状态回推：`core/tile/QuickSettingsTileUpdater.requestTileUpdate` 用 `ComponentName(pkg, "com.haoze.diting.tile.DitingTileService")`（注意第二参已是全限定名，注释 `:20-24` 记录了一次双重前缀的历史缺陷）。调用方 4 处：`ExpressVpnController:176`、`normal/DnsVpnStatusNotifier:24`、`server/backend/DnsModeService:109,177`。
- `MainActivity` 声明了 `android.service.quicksettings.action.QS_TILE_PREFERENCES` intent-filter（Manifest `:101-103`），但**全仓无任何代码读取该 action**（`grep -rn QS_TILE_PREFERENCES` 仅命中 Manifest）→ Tile 长按设置当前落到 MainActivity 且无差异化行为。**待定**：是否为有意（等价于打开主页）还是缺实现，需产品确认。
- 全仓**没有** `android.intent.action.VIEW` 的 `<intent-filter>`/`<data>` 深链（grep 实测零命中），Manifest 中 MainActivity 也只有 QS_TILE_PREFERENCES 一个 filter（LAUNCHER 在 alias 上）。外部跳转仅有 3 处「出向」intent：QQ 群 `mqqapi://card/show_pslcard?…uin=1078502371…`（`SettingsRouteActivity.joinQqGroup:290-301`，失败 Toast「未检测到 QQ，请搜索群号 1078502371 加入」）、GitHub 仓库（`AboutScreen.kt:124`）、赞助 README `https://github.com/haoze-evolluling/DITING#sponsorship`（`SponsorScreen.kt:31,41`）。
- `DnsMainActivity` 唯一入口是 `DnsModeService.buildForegroundNotification` 的 contentIntent（`server/backend/DnsModeService.kt:307`）；`SettingsRouteActivity.kt:28` import 了它但**函数体内未使用**（无用 import）。其 `companion.createIntent(context)` 返回的其实是 **MainActivity** 的 Intent（`:28-31`），命名误导。类注释自证「Backward compatibility trampoline activity that forwards to MainActivity. DNS mode is now embedded natively inside MainActivity as part of the Single-Activity architecture」（`server/DnsMainActivity.kt:10-13`）。
  **重要澄清（防重构者误读）**：删 `DnsMainActivity` 这个**入口 Activity 残迹**，与服务器模式功能本身**无关**——服务器模式（AppWorkMode.DNS）的 UI 本体是 `MainModeDispatcher` 的 `AppWorkMode.DNS` 分支内嵌的 `server/ui/DnsModeHost.kt`（渲染 `DnsMainScreen`，走 `DnsMainViewModel`/`DnsModeManager`），其生命周期与状态在 MainActivity 内自管（本文 §3.3）。服务本体属 11 章域，不可因本残迹判定「服务器模式可删」。

### 6.5 其他

- `MainActivity.EXTRA_*` 三键：`auto_start_vpn`、`main_work_mode_changed`、`main_target_work_mode`（`MainActivity.kt:241-243`）。
- `NavigationSettledEffect`（首帧 RESUMED 后只跑一次，`rememberSaveable`）与 `OnResumed`（每次 RESUMED 都跑，靠 `addObserver` 对已 RESUMED owner 回放 ON_RESUME 覆盖懒组成的 pager 页）两个工具（`ui/NavigationSettledEffect.kt`），首页服务可见性屏用前者、日志仪表盘用后者语义（`HomeProviderVisibilityScreen.kt:54-56`）。

---

## 7. 关键源码引证表

路径均相对 `C:\Users\leehaoze\DITING\Android\app\src\main\`。

| 结论 | 引证 |
|---|---|
| MainActivity 无 NavHost，三模式 `when` 直切子树 | `java/com/haoze/diting/MainActivity.kt:133-160`；`java/com/haoze/diting/main/MainModeDispatcher.kt:37-122` |
| 设置子页 = 同名 Activity 自嵌套（每层 +1 栈帧） | `SettingsRouteActivity.kt:201-227`（`openRoute` → `childActivityLauncher.launch(createIntent(…))`） |
| 6 个布尔变更位向 MainActivity 传播 | `SettingsRouteActivity.kt:241-285`；`main/MainNavigationCoordinator.kt:28-57` |
| 日志路由不回传、按 dataset 而非模式分流 | `LogRouteActivity.kt:81-85, 103-149` vs `SettingsRouteActivity.kt:327` |
| 协议未同意时替换整个主页内容且锁返回键 | `MainActivity.kt:118-131`；`ui/MainActivityDialogs.kt:18` |
| 模式写入双点（coordinator + ExpressModeLauncher） | `main/MainWorkModeCoordinator.kt:90-92`；`express/ExpressModeLauncher.kt:54-55` |
| 切模式副作用矩阵（离开才停 / 进入才起） | `main/MainWorkModeCoordinator.kt:96-116`；`core/WorkModeLifecycleRegistry.kt:69-84` |
| 三模式首页 resetToHomeTrigger 一致回第 0 页 | `main/MainWorkModeCoordinator.kt:94` → `normal/ui/MainScreen.kt:135-139`、`express/ui/ExpressMainScreen.kt:115-119`、`server/ui/DnsMainScreen.kt:71-75` |
| 老用户升级批量补写三模式引导完成 | `main/MainWorkModeCoordinator.kt:47-51` |
| WorkModeActivity 选择即写库、动画结束才回调 | `ui/mode/WorkModeActivity.kt:69-83`；`ui/mode/WorkModeSelectionScreen.kt:67-85` |
| CLEAR_TOP 回 MainActivity 携带模式 | `ui/mode/WorkModeActivity.kt:90-99`；`onboarding/ModeOnboardingActivity.kt:203-219` |
| 底栏数量 2–4、宽度 204/276/340dp、玻璃仅浅色 | `ui/BottomBarDestination.kt:75-77`；`ui/FloatingNavigationBar.kt:119-144` |
| express 底栏经 legacy 枚举映射共享同一存储键 | `express/ui/ExpressNavigation.kt:67-83`；`express/ui/ExpressBottomBarCustomizationScreen.kt:73-78` |
| 首页 5 路透明度 + 全局回退链 | `ui/settings/AppearanceSettingsStore.kt:67-98`；`normal/ui/MainScreenContent.kt:74-78,125,192,330` |
| 主题 SYSTEM 在 12+ 走 Monet，GOLD 的 storageValue 是 "indigo" | `ui/theme/AppTheme.kt:24-32, 60-65` |
| 字体仅覆写 bodyLarge 一项 | `ui/theme/AppTypography.kt:9-17` |
| 自定义背景开关要求 URI 仍在图库内 | `ui/settings/AppearanceSettingsStore.kt:120-124`；`ui/CustomBackgroundSettingsScreen.kt:154-160` |
| 电源按钮 enabled 依赖服务与解析模式选满 | `normal/ui/MainScreenContent.kt:129-131`；`express/ui/ExpressHomeContent.kt:144-146` |
| express 首页 isBusy 恒 false（无过渡态） | `express/ui/ExpressHomeContent.kt:85,143` |
| 引导三步 × 三模式，权限清单 4/3/2 | `onboarding/ModeOnboardingModels.kt:90-95, 140-144, 189-192`；`onboarding/ModeOnboardingScreen.kt:76, 301-315` |
| 服务器模式无 VPN 且 ON_RESUME 自愈重启 | `server/ui/DnsModeHost.kt:33-47`；`main/MainVpnController.kt:64-67, 80` |
| RecentsPrivacy 逐 task 设标志、每次 onResume 重打 | `ui/RecentsPrivacyController.kt:7-11`；`MainActivity.kt:227, 237-238` |
| Tile 按当前模式三选一 + 锁屏 unlockAndRun | `tile/DitingTileService.kt:43-71, 149-180` |
| `QS_TILE_PREFERENCES` 有 filter 无代码消费者 | `AndroidManifest.xml:101-103`（grep 全仓仅此一处） |
| 无任何 VIEW/data 深链 | `AndroidManifest.xml` 全文 grep `action.VIEW`/`<data` 零命中 |
| 批量分类器 9 分支 + 两处词法守卫 | `ui/batch/BatchRuleClassifier.kt:60-82, 84-429` |
| 批量 URL 归一化复用 GoUrlRuleManager.parse | `ui/batch/BatchRuleValidator.kt:157-192` |
| 覆写 IP/CNAME 同域互斥 | `ui/batch/BatchRuleValidator.kt:246-253` |
| cosmetic 仅 NORMAL 数据集可提交 | `ui/batch/BatchRuleEntities.kt:79-96` |
| 云控名单 ETag 304 短路 + 256KiB 双校验 | `ui/RecognitionMembersRepository.kt:44-64` |
| 头像降采样 IO 解码 + 进程级缓存 | `ui/RecognitionAvatarRepository.kt:57-88` |
| SettingsGuide 一次进入一次弹、按 id 记已读 | `ui/SettingsGuide.kt:154-236` |
| DnsMainActivity 是纯转发残迹（仅入口 Activity；服务器模式 UI 本体在 `DnsModeHost` 内嵌，不可随之删除） | `server/DnsMainActivity.kt:10-31`（类注释自证 trampoline）；`server/backend/DnsModeService.kt:307`；`main/MainModeDispatcher.kt:71-78` |
| ExpressWorkModeCard / OptionalFeaturesScreen 零调用者 | `express/ui/ExpressWorkModeCard.kt:21`、`normal/ui/OptionalFeaturesScreen.kt:9`（各自 grep 仅命中定义行） |
| Routes.MAIN / SUBSCRIPTION_HUB 零引用 | `ui/AppNavigationRoutes.kt:4, 19`（差集实测） |

---

> §8「Flutter 重构注意」见续篇 **`03-navigation-and-main-ui-2.md`**（同编号分篇，含 go_router 映射表、可合并 Activity 判定、跨模式 UI 复用面、Compose 状态→Flutter 状态映射）。

