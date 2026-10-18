```yaml
所属系列: DITING Android Flutter 重构功能图谱
章: 01（本篇 + 续篇 01-foundation-and-startup-2.md，互为引用）
最后校验: 2026-10-18
口径: main 源码 522 个 Kotlin 文件全部点名（实测 find app/src/main -name "*.kt" | wc -l = 522；test 99 个，合计 621）；数字均为本会话工具实测
```

# 01 基础设施、配置与工程构建

## 1. 概述

本章覆盖 DITING Android 应用的地基四层：**进程入口与生命周期**（`DitingApp`、`AppLocalizedActivity`）、**Activity 分发骨架**（`MainActivity`/`LogRouteActivity`/路由协调器）、**全局配置持久层**（8 个 SharedPreferences 容器、约 130 个键，无 DataStore）、**工程构建与打包**（AGP 9.2.1 / Gradle 9.4.1 / gomobile AAR / bat 脚本）。Flutter 重构时，这一章的内容一半会被框架运行时替代（Activity/Compose/Dispatcher 约定），一半必须逐键迁移语义（配置键、默认值、钳位区间、一次性迁移标志）。判定「保留语义」还是「删除实现」以本清单为准。

跨域锚点：崩溃域见 `crash/`（本章只盘点调用面，第 2.9 节）；Room 数据库域另章（本章仅记 `AppDatabase` version=3、`fallbackToDestructiveMigration(true)`：AppDatabase.kt:114,146-147）；三模式业务实现（express/normal/server）各另章，本章只记其在 Manifest/注册表/配置键上的投影。

## 2. 功能清单

### 2.1 DitingApp（Application 初始化链）
- **做什么**：进程级基础设施装配。`AndroidManifest.xml:20` 声明 `android:name=".DitingApp"`。
- **入口与触发**：进程创建时 `onCreate()`（DitingApp.kt:30）。
- **初始化顺序（严格，DitingApp.kt:30-111）**：
  1. `instance = this`（:32）——**实测零消费者**（双向 grep：定义 DitingApp.kt:24-27，全仓唯一其他提及是测试注释 TunnelDiagnosticsResolverTest.kt:16,177，非代码调用）。重构可删。
  2. `CrashCollector.appStartElapsedRealtime = SystemClock.elapsedRealtime()`（:34）供崩溃报告计算 App Uptime（CrashCollector.kt:34,76）。
  3. `CrashHandler.install(this)`（:37）注册全局 UncaughtExceptionHandler（CrashHandler.kt:114-126，`installed` 幂等）。
  4. `CrashBreadcrumbs.record("APP", ...)`（:38）。
  5. `CustomBackgroundManager.ensureLoaded(this)`（:42）**同步**预载背景图防冷启动白屏。
  6. 裸线程 `NativeCrashCollector` 调 `CrashLogManager.checkAndCollectNativeCrashes`（:46-48），API<30 直接返回（CrashLogManager.kt:369）。
  7. `TunnelDiagnosticsResolver.tunnelResolver = { ... DnsVpnService.resolveThroughTunnel }`（:55-59）——依赖注入钩，NetworkTools 经隧道解析的唯一接地点。
  8. 裸线程 `SubscriptionAutoUpdateSync` 调 `SubscriptionAutoUpdateScheduler.sync`（:62-64）。
  9. `registerActivityLifecycleCallbacks`（:68-110）：`onActivityPreCreated` 贴窗口背景；started 计数维护 `CrashHandler.isAppForeground`；resumed 写 `currentActivityName`；全程打 LIFECYCLE breadcrumb。
- **状态与副作用**：静态字段 3 个（instance/appStart/foreground 计数）、后台线程 2、全局异常 handler、生命周期回调注册。无 Prefs/DB 直接写入。
- `onTrimMemory`（:113-116）转发 `CustomBackgroundManager.onTrimMemory`。

### 2.2 AppLocalizedActivity（Activity 基类）
- **做什么**：全部 6 个业务 Activity（MainActivity、LogRouteActivity、SettingsRouteActivity、WorkModeActivity、ModeOnboardingActivity、DnsMainActivity——实测 `grep "class .* : AppLocalizedActivity"` 恰 6 处）的统一基类。
- **关键逻辑**：
  - `attachBaseContext` 用 `AppLanguageManager.wrap(newBase)` 覆写 locale（AppLocalizedActivity.kt:12-14）；wrap 逻辑：显式语言模式优先，SYSTEM 模式下中文系统→简中、否则英文（AppLanguageManager.kt:38-50）——即**应用只有 zh/en 两语言面**。
  - `onCreate` 先 `applyOrientationPolicy`：手机（sw<600dp）强制竖屏、平板放行（:33-36），再双保险 `ensureLoaded + applyWindowBackground`（:18-19）；`onResume` 重贴背景（:23-26）。
- **跨域引用**：平板判定委托 `util/DeviceScreenHelper`（见 2.7）。

### 2.3 MainActivity（首页与模式分发）
- **职责**：不含业务逻辑的编排壳，全部委托 4 个协调器（构造于 :48-74）：`MainStartupCoordinator`、`MainVpnController`、`MainWorkModeCoordinator`、`MainNavigationCoordinator`。
- **onCreate 流程（:76-192）**：记录语言模式快照 → `enableEdgeToEdge` → `performStartupChecks`（配置自检 + 崩溃自动导出提示 Toast）→ `applyRecentsPrivacySetting`（从最近任务隐藏，`task.setExcludeFromRecents`，RecentsPrivacyController.kt:7-11）→ `checkStartupOnboarding(intent)`：若需要跳引导则 `finish()` 自己并 return（:83-85）→ `setContent{}`：首启协议门（`SystemSettingsStore.isInitialAgreementAccepted` :89,118-131，拒绝即停 VPN + `finishAndRemoveTask`，MainStartupCoordinator.kt:61-68）→ 已选模式时渲染 `MainModeDispatcher`（:134-158）→ 权限披露弹窗 + 更新弹窗叠层（:163-180）。
- **intent/深链处理**：**Manifest 无任何 VIEW/SEND/deep-link intent-filter**（实测 grep `android:scheme`/`ACTION_VIEW` 于 Manifest = 0 命中）；MainActivity 的 `intent` 只承载三类自有 extra：`auto_start_vpn`（:241，生产方：VpnMonitorService.kt:121、ModeOnboardingActivity.kt:213、DitingTileService.kt:154）、`main_work_mode_changed`+`main_target_work_mode`（:242-243，生产方：WorkModeActivity.kt:93-94、ModeOnboardingActivity.kt:210-211）、QS_TILE_PREFERENCES 空处理器（见 5.2）。`onNewIntent`（:203-210）转发协调器并复用自动启 VPN 逻辑，extra 消费后即 `removeExtra`（MainWorkModeCoordinator.kt:77-78、MainVpnController.kt:63）实现一次性语义。
- **生命周期**：`onStart/onStop` 同步悬浮日志前后台标志（:212-215,231-235，Express 与 Normal 各一路）；`onResume` 检测语言变化即 `recreate()`（:219-224）；启动后 Express 模式在 onCreate 尾部直接 `ExpressModeLauncher.switchToExpress`（:188-190）。
- **状态与副作用**：`mutableStateOf` 三个刷新请求位；prefs 读写全经 store 对象；无直接 DB/文件写。

### 2.4 LogRouteActivity（日志域独立 Activity）
- **做什么**：日志/统计 7 条路由的宿主（:104-150 when 分发：DNS_LOGS、HTTP_REQUEST_LOGS、DNS_CACHE、RACE_STATS、BOOTSTRAP_STATS、SUBSCRIPTION_INTERCEPTION_STATS、PROVIDER_HEALTH、APP_TRAFFIC_STATS，默认 LOG_DASHBOARD）。
- **关键分支**：`dataset == EXPRESS` 时走 Express 专属 UI（ExpressRequestLogScreen/ExpressLogDashboardScreen），否则走 Normal UI 栈；`RequestSource` extra 决定 HTTPS/ALL 初始过滤（:115）。dataset 缺省回退按当前工作模式（:27-31）。
- **防重入**：`childLaunchInProgress` 单飞标志，`onResume` 复位（:19,73,82-84）。每路由一个 Activity 实例（launchMode=standard，Manifest:135），返回即 finish 露出下层——**注意**：路由级联可叠多个实例，重构为 Flutter Navigator 栈时对应 push/pop。
- **模式分发关系**：与 MainActivity 相同的 `updateFloatingLogAppState` onStart/onStop 协议（:66-79）。

### 2.5 AppSettings 门面
- **现状**：仅存 `performStartupSelfCheck` 一个转发（AppSettings.kt:20-22），KDoc 明言旧 pass-through 门面已拆除、调用方直用各 Store。**唯一消费者**：MainStartupCoordinator.kt:27。Flutter 重构时应删门面、直接迁移 `StartupSelfCheck` 逻辑（见 2.6）。

### 2.6 StartupSelfCheck（启动配置修复）
- **做什么**：主线程同步、一次性读改写 `dns_vpn_prefs`（StartupSelfCheck.kt:21-74）：①`dns_resolution_mode` 非法→重置 single；②`preset_dns_service` 非法→DNS；③④`bootstrap_custom_json`/`custom_background_uris` 非合法 JSONArray→删除（背景连带清 uri+enabled）；⑤`outbound_proxy_port` 越界 1..65535→7890。
- **缺口（实测）**：仅查 NORMAL 容器（`PREFS_NAME`，:22）；EXPRESS/DNS_MODE 同名键的损坏值不在自检范围——各 Store 的读侧 catch 兜底是第二道防线。**待定**：是否有意为之（无注释证据）。

### 2.7 util 包（10 文件全读，实测各文件行数 18–95）
| 文件 | 做什么 | 消费者（双向 grep） |
|---|---|---|
| Base64Codec.kt(90行) | 纯 Kotlin RFC4648 编解码，绕 minSdk24 无 `java.util.Base64` 且不开 desugaring；解码非法输入返回 null（:57-89） | 仅 KeyObfuscator + 自身测试。`internal` 可见性 |
| KeyObfuscator.kt(50行) | 3 组 8 字节 XOR 掩码 + Base64，防 API Key 明文入库；UTF-8 序列化（A-059 修复） | AgentApiSettingsStore.kt:332,336,359、AiProviderModels.kt、2 个测试。**注意：混淆非加密**，掩码硬编码于源码 |
| DateTimeUtils.kt(95行) | DST 安全的本地日首 `dayStartMillis`（±30h 探针定点迭代，:53-70，注释含 28.4%/5.45M 样本差分实测）；`statsRangeStartMillis` 按枚举 name 匹配 TODAY/SEVEN_DAYS（:85-89，**字符串名匹配，重命名枚举即静默失效**） | 主源码 5+ 文件引用 dayStringAt/statsRangeStartMillis 等 |
| DeviceScreenHelper.kt(48行) | sw600dp 判平板：全屏短边/density≥600（:22-32）；API30+ 用 `maximumWindowMetrics`，以下 `defaultDisplay.getRealMetrics`（:39-46） | 仅 AppLocalizedActivity:34 |
| KeysetPaginationHelper.kt(17行) | `forEachKeysetPage` 泛型键集分页（while 直到空页） | AllowRuleCacheLoader、BlockRuleCacheLoader、RewriteRuleManager |
| LatencyWindow.kt(32行) | DNS 测延迟量窗：未开表 elapsed=0（防 setup 失败伪装成快/慢） | DnsLatencyTester + 测试 |
| LatestRequestGate.kt(45行) | 最新请求闸门：`latest === request` **身份比较**（:37，A-051/A-096 修复注释明确禁止 `==`，data class 等值陷阱）；@Synchronized | RewriteListViewModel + 测试 |
| MetricFormatters.kt(52行) | bytes/speed/percent/ms 格式化（Locale.US）；`formatDuration` 硬编码中文「小时/分钟/秒」（:34-40，**不经 values-en**）、`formatDurationClock` 秒表式 | 各 2–7 文件引用（实测逐函数计数） |
| PersistableUriPermissions.kt(87行) | SAF 持久授权唯一收口：take 容错（:23-31）、release/releaseString（:37-55）、`releaseIfPersisted` 先查 `persistedUriPermissions` 再释放（:72-79，A-083：实体无「是否持久化授权」标志位的替代判据） | 4 UI/VM 文件：AddSubscriptionScreen、CustomBackgroundSettingsScreen、RuleManagementViewModel、SubscriptionViewModel |
| SafGrantDecisions.kt(70行) | 纯函数决策：releasesOnPick（取消→不释放；校验失败→释放新选；换文件→释放旧选，:22-43）、releasesOnRemove、mayRelease（仅本应用实际持有才放，:65-69） | 被 PersistableUriPermissions.kt:76 调用 + 2 UI 文件 + 测试 |

### 2.8 模式协调与注册表（main/ 包 + core/ 注册表）
- **MainStartupCoordinator.kt(73行)**：自检→崩溃提示→（协议已接受且已选模式时）更新检查（受 `disable_startup_update_check` 默认 **true=不检查** 门控 :41）、IO 协程内延迟 500ms（`DATABASE_WARMUP_DELAY_MS` :71）建通知渠道 + DB 预热 + 默认白名单 seeding；`onAutoStartVpn` 回调注入。
- **MainWorkModeCoordinator.kt(169行)**：`checkStartupOnboarding`（:38-65）三段门：老用户补记全部模式 onboarding 完成（:47-51 升级兼容）、未选模式→WorkModeActivity、未 onboarding→ModeOnboardingActivity；`switchWorkMode`（:83-117）先落 `WorkModeStore.setAppWorkMode` 再做前向模式清场（DNS→停 DnsModeService / EXPRESS→停 Express），目标 DNS 时停 VPN+监视器，EXPRESS 走 `ExpressModeLauncher.handleModeSelected`。`syncOnResume`（:149-168）按模式刷状态并广播 `VPN_STATUS_CHANGED`。
- **MainNavigationCoordinator.kt(81行)**：`registerForActivityResult` 消费 SettingsRouteActivity 回传 6 个 extra（runtime_dns/hide_from_recents/theme/background/bottom_bar/work_mode 变更，:34-55）；`settingsLaunchInProgress` 单飞。
- **MainVpnController.kt(166行)**：三 launcher 链（notification→prepareVpn→vpnPrepare），披露门控：VPN 未解释过先弹 `PermissionDisclosure.VPN`（:96-109）；`startVpnService/stopVpnService` 按 EXPRESS/NORMAL 分流（:151-165）。
- **MainModeDispatcher.kt(124行)**：`when(currentWorkMode)` → ExpressMainScreen / DnsModeHost / MainScreen，导航回调表全部携带 `RuleDataset`。
- **注册表模式（跨模块解耦核心，重构重点）**：
  - `core/VpnStateRegistry.kt(34行)`：3 个 @Volatile lambda 钩。默认实现直读 prefs `dns_vpn_prefs/vpn_running`、`express_vpn_prefs/express_vpn_running`（:10-19,25-30）；`DnsVpnService.init{}` 替换为服务实况（DnsVpnService.kt:455-465，实测 grep `setNormalRunningFlag\s*=` 仅 DnsVpnService.kt:464 一处重赋值）；`ExpressVpnController.init{}` 替换 express 钩（ExpressVpnController.kt:50-57）。广播 action `com.haoze.diting.VPN_STATUS_CHANGED`（:32）。
  - `core/WorkModeLifecycleRegistry.kt(85行)`：5 钩，默认实现用**字符串类名 Intent** 反射式指向服务（`setClassName(pkgName, "${pkgName}.normal.DnsVpnService")` 等，:12-54——Flutter/混淆安全的显式设计）；`stopNormalMode`/`updateNormalFloatingLogAppState` 被 DnsVpnService init 替换、`stopExpressMode` 被 ExpressVpnController 替换、`stopServerMode` 被 DnsModeManager.kt:50 替换。`stopOtherModes` 三模式互斥矩阵（:69-84）。注释 :43-47 记录一次「写了无人读的第二容器」回归修复。
  - `TunnelDiagnosticsResolver.tunnelResolver`：DitingApp 注入（2.1），未注入时 NetworkTools 报「VPN 未运行」（TunnelDiagnosticsResolver.kt:13,40）。
  - 其余回调钩（实测清单）：DnsCacheController.onClearGoCache、LogMaintenanceManager.activeComponentsClearBuffers、Allow/BlockListManager.onCacheChanged、SubscriptionManager.progressReporter、RequestLogRepository.activeFlusher、DnsVpnDatabaseComponents.onRulesReloaded。

### 2.9 崩溃前处理调用面（CrashBreadcrumbs）
- 环形缓冲 150 条、纯内存、无 I/O（CrashBreadcrumbs.kt:15-47）。
- **record 调用点实测 14 处**：DitingApp 8（APP×1+LIFECYCLE×7）、ExpressVpnService 3（:96,202,222）、DnsVpnService 3（:236,368,395）、CrashHandler 1（FATAL 收尾，CrashHandler.kt:38-42）。
- **读取面仅 2 处**：CrashCollector.kt:262,324 把 `formatAll()` 拼入报告。CrashHandler 捕获序列 = breadcrumb→minimal-report（同步 commit）→full-report→crash-bookkeeping，每步隔离失败不中断链（CrashHandler.kt:36-72 + `CrashCaptureSequence`）。

### 2.10 语言/本地化基础设施
- `res/values/strings.xml` 与 `values-en/strings.xml` 各 216 条 `<string>`（实测 grep -c）；`android:localeConfig="@xml/locales_config"`（Manifest:27，仅 zh/en）；`androidResources.localeFilters += [zh,en,zh-rCN]`（build.gradle.kts:88-90）。
- `ui/localization/LocalizationEngine.kt`：三级回退（资源 id 哈希名 `localized_text_<hash>` 缓存 → 静态词典 → 模式模板 → 原文），双 ConcurrentHashMap 缓存（:23,33）。重构含义：**运行期大量 UI 字符串不在 Compose 资源里而是硬编码中文 + 翻译表**，Flutter l10n 需要整体重设计（另域章处理，此处仅锚定）。

（配置键全量字典、构建打包、Manifest 全表、源码引证、Flutter 注意 → 见 [01-foundation-and-startup-2.md](01-foundation-and-startup-2.md)）
