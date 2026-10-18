```yaml
所属系列: DITING Android Flutter 重构功能图谱
章: 05 续篇（接 05-traffic-log-system.md 第 4 节）
最后校验: 2026-10-18
口径: 同主篇；数字均为本会话工具实测
```

# 05 续篇：悬浮窗、通知、Tile、崩溃、更新、权限、导入导出、数据清理

## 4. 悬浮窗与通知

### 4.1 悬浮日志窗（ui/floating/ 6 文件）

- 文件：FloatingLogOverlayController / FloatingLogWindowType / FloatingLogMapper / FloatingLogModels / FloatingLogTheme / FloatingLogViewFactory。
- 窗口类型兼容（关键）：`FloatingLogWindowType.kt:16-22` 纯函数——`sdkInt>=26 → TYPE_APPLICATION_OVERLAY`，否则 legacy `TYPE_PHONE`；注释 :6-15 明示「minSdk24 设备上 OVERLAY 会 addView 失败，悬浮窗永远出不来」，该函数被所有构造 window params 处复用。
- 权限闸门：`FloatingLogOverlayController.kt:147` `Settings.canDrawOverlays` 不过则不建窗；触发点 ui/LogRetentionSettingsScreen.kt:125,147,156（跳 ACTION_MANAGE_OVERLAY_PERMISSION）。
- 结构：`ensureWindow()`（:160-180）建 LinearLayout 挂 48dp 悬浮球（createBallView :166-167），addView 失败 `runCatching` 回收并 Toast「悬浮窗日志启动失败」（:172-179）。
- 交互：拖拽 `installDragHandler`/`handleDrag`（:182-213，球点击=切换展开 toggleExpanded :215）；面板三档尺寸 `panelDimensions()`（:314-320）：0=小 290×360、1=中 330×430、2=大 360×520（dp），cyclePanelSize :251、名称「小/中/大」:322-326；尺寸持久化 coerceIn(0,2)（SystemSettingsStore.kt:72-83）。
- 内容刷新：`startRefreshing`（:342）循环 `delay(2_000)` 即 **2s 一拍**（:348-353，stopRefreshing :353）；数据源即 3.3 的 mapper（loadRecentLogs limit=30）。
- 生命周期：亮灭屏广播 registerScreenReceiver（:109-131）+ `setAppInForeground`（:90）+ `hideForCurrentBackground`（:288）决定可见性（syncVisibility :140）；`refreshSettings()`（:96）响应开关变更；destroy（:133）移除窗口。开关持久化 `floating_log_enabled`（SystemSettingsStore.kt:18,60-70，默认 false）。

### 4.2 通知渠道全表（notification/AppNotificationChannels.kt）

| 渠道常量 (:17-21) | id 字符串 | 用途 | 建渠道处 |
|---|---|---|---|
| CHANNEL_VPN_SERVICE | diting_vpn_service_channel | 普通模式常驻 | createAllChannels :58 |
| CHANNEL_VPN_MONITOR | diting_vpn_monitor_channel | 「VPN 未运行」提醒 | ensureMonitorChannel :35-45（LOW、无角标/灯/震）；createAllChannels :70 |
| CHANNEL_RULE_OPERATIONS | diting_rule_operations_channel | 规则操作结果 | :82 |
| CHANNEL_SUBSCRIPTION_AUTO_UPDATE | diting_subscription_auto_update_channel | 订阅自动更新 | :92 |
| CHANNEL_APP_UPDATE | diting_app_update_channel | 应用更新下载 | :102 |
| CHANNEL_EXPRESS_VPN | diting_express_vpn_channel | 极速常驻 | express/notification/ExpressNotificationBuilder.kt:29,34-38（独立 ensureChannel，**不在全表**）|

importance 实测：除 SUBSCRIPTION_AUTO_UPDATE = DEFAULT（:95）外全部 LOW（:38,61,73,85,105）；MONITOR 额外 setShowBadge(false)/关灯/关震（:41-43）。

createAllChannels 调用点：`MainStartupCoordinator.kt:48`（冷启动 IO 线程，runCatching 包裹）、`AppUpdateNotifier.init`（update/AppUpdateNotifier.kt:18）。

### 4.3 常驻通知构建器（两模式差异）

- 普通：`normal/notification/VpnNotificationBuilder.kt:23` object；`NOTIFICATION_ID_VPN_SERVICE=1001`（:25）；`build()`（:30-）用 CHANNEL_VPN_SERVICE（:77），状态文案合成 :90；调用点 `DnsVpnService.kt:188-206`（promoteToForeground 两处 startForeground，失败分支 :196/:201/:206）、`354-360`（运行中刷新）、:223 stop 时 cancel。
- 极速：`ExpressNotificationBuilder.kt:26` object；`NOTIFICATION_ID_EXPRESS_VPN=2001`（:28）、CHANNEL_EXPRESS_VPN（:29）；`build()` :54-79、默认状态文案 :121；调用点 `ExpressVpnService.kt:153-174`（startForeground 三失败分支同构 :161/:167/:174）、:197 cancel；`ExpressModeLauncher.kt:58` 预热渠道。
- 两模式差异：仅 id 段（1001/2001）与渠道不同，builder 结构几乎对称（各自 buildDefaultStatusText，普通 :90 / 极速 :121）——Flutter 侧可合一，但 id/渠道字符串须保留以免旧通知残留。
- 网速行：`VpnSpeedMonitor`（normal/notification/VpnSpeedMonitor.kt:38,54）复用 `formatTrafficSpeed` 渲染进通知内容。

### 4.4 VpnMonitorService —— 监控的是「本应用自己没连」（关键发现，纠偏任务书）

任务书问「如何检测第三方 VPN 冲突」——**实测不存在第三方 VPN 检测**。真实语义（VpnMonitorService.kt:20-23 KDoc）：VPN **未**运行时挂一个常驻「快速连接」通知。onCreate 只建本服务渠道（ensureMonitorChannel，:26-31）。

- 通知内容（:120-151）：标题 app_name、正文取自定义停止文案 `getCustomStoppedText`（空则 R.string.vpn_disconnected，:133-138）、addAction 播放键=同样 PendingIntent（EXTRA_AUTO_START_VPN，:120-145）、ONGOING/无时间戳/IMMEDIATE（:146-149）；id=1002（:155）；停止 action `STOP_MONITOR`（:156）+ `shouldStopNow()` 在提升后判停（:48-52）。
- startForeground 健壮性（:33-42,80-97）：Android 12+ 必须先成功 startForeground——先带 `specialUse` 类型尝试，失败 runCatching 退回无类型重载（:84→retry :95-97），仍失败**保持服务存活**避免 ANR 崩溃（:42 注释）。Manifest `foregroundServiceType=specialUse` + subtype "vpn_monitor"（AndroidManifest.xml:45-52）。
- 状态判定唯一来源：`VpnStateRegistry`（core/VpnStateRegistry.kt:10-22）——normal 读 `dns_vpn_prefs.vpn_running`、express 读 `express_vpn_prefs.express_vpn_running`（@Volatile lambda 可注入，跨组件解耦），**没有遍历 ConnectivityService 的第三方 VPN 探测**。
- 生命周期编排 `VpnMonitorManager.kt`：requestStart/requestStop 去抖（:54,78）、onPromoted/onStartFailed/onServiceDestroyed（:91-103）、sync（:148-）、stop（:176-194 cancel 通知）、isVpnRunning（:127）、onVpnStarted/onVpnStopped（:208,215）；DNS(服务器)模式或特定条件下不启动监控（:220 判定）。调用点实测：ExpressModeLauncher.kt:49,63、ExpressVpnController.kt:166,168、ExpressVpnService.kt:147,209,232、ExpressNotificationSettingsScreen.kt:77,124、MainStartupCoordinator.kt:58；持久开关 persistent_notification_enabled 默认 true（NotificationSettingsStore.kt:17,26-39）。

### 4.5 其他通知

- 更新：`AppUpdateNotifier.kt`——id=41018（:71）、CHANNEL_APP_UPDATE（:70）；showProgress 带百分比进度条 + totalBytes<=0 时 indeterminate（:21-41，文案 "pct% down/up"，formatAppUpdateBytes :75-85）；showCompleted AUTO_CANCEL（:43-56）；发送前 `NotificationPermissionHelper.hasPermission`（:60,22）。
- 权限判定：NotificationPermissionHelper.kt:21-25（API<33 直接 true，>=33 查 POST_NOTIFICATIONS 授权）；设置页跳转 openNotificationSettings（:40-）O+ 跳渠道页否则应用详情页（:55）。

## 5. QS Tile 与外部入口（tile/DitingTileService.kt）

- Manifest：`.tile.DitingTileService`，BIND_QUICK_SETTINGS_TILE，TOGGLEABLE_TILE=true（AndroidManifest.xml:69-81）；`MainActivity` 挂 QS_TILE_PREFERENCES（:95-92 区）。
- 三模式分发（关键）：`performTileAction`（:57-71）先查初始协议是否已同意（:59-62），然后 `WorkModeStore.getAppWorkMode` 路由——DNS→toggleDnsService、EXPRESS→toggleExpressVpnService、NORMAL→toggleVpnService（:66-70）。KDoc :64-65 明示「无视模式会在 DNS 服务运行时误启 VPN」。
- 锁屏防护：`onClick` 全程 `isLocked` 判定 + `unlockAndRun`（:43-55），openMainActivity 同（:175-179）。
- 各分支细节：DNS 启停含 ERROR 同步回滚（:73-89）；NORMAL/EXPRESS 未 prepare 时 openMainActivity(requestVpn=true)（:105-110,135-139），`startForegroundService` 用 runCatching 捕获 Android 12+ 从 tile 启 FGS 被拒并回退到应用内启动（:116-124,140-146）——**「tile 拒绝」是设计中的一等分支**。
- 外观：`updateTileState`（:182-197）state ACTIVE/INACTIVE、label 本地化、API33+ subtitle（:187）、contentDescription、icon dns_svgrepo_com（:191）、updateTile runCatching（:192-195）；`isCurrentModeServiceRunning`（:199-205）三源（DnsModeManager / ExpressVpnController / DnsVpnService）。
- 刷新通道：`DitingTileService.requestTileUpdate`（:213-215）委托 `core/tile/QuickSettingsTileUpdater.requestTileUpdate`（:18-）——实测 ComponentName **第二参须全限定类名**（:21-27 注释 + `ComponentName(packageName, TILE_SERVICE_CLASS)`），这是修复过的坑（原用简单名 tile 更新静默失效）。
- 状态回写：`DnsVpnStatusNotifier.sendStatusBroadcast`（DnsVpnService.kt:314 等）发 ACTION_VPN_STATUS_CHANGED（VpnStateRegistry.kt:32-33）→ tile/UI 监听刷新。

## 6. 崩溃收集（crash/ 12 文件）

文件：CrashHandler / CrashCollector / CrashLogManager / CrashBreadcrumbs / CrashCaptureSequence / CrashExportCompletion / TombstoneParser / TombstoneProtobufDecoder / TombstoneReportFormatter / TombstoneTextSanitizer / TombstoneModels / TombstoneWireReader。

- 安装点：`DitingApp.kt:37 CrashHandler.install(this)` → `Thread.setDefaultUncaughtExceptionHandler`（CrashHandler.kt:117-122）；uptime 基准 `CrashCollector.appStartElapsedRealtime`（DitingApp.kt:34）；面包屑 CrashBreadcrumbs（DitingApp.kt:38 起持续记录）。
- 两阶段 Java 报告（关键，CrashHandler.kt:22-100）：
  1. 崩溃线程先**最小报告**保命落盘——`collectMinimalReport`（CrashCollector.kt:287）→ `saveCrashReport`（:50-56；CrashLogManager.kt:107），理由见 CrashCaptureSequence.kt:6-8「collectReport 可能自身 OOM」；
  2. 成功后再 `collectReport`（:36）采**全量**，`replaceCrashReport`（:135）原地替换（CrashHandler.kt:75）——替换失败则另存（:78）；
  3. 无论成败：`onCrashOccurred`（:85）计连击；`exitProcess(2)`（:100）。
- 采集内容：`collectReport` 分段用 appendSection（CrashCollector.kt:413），含异常与栈（:189-196）、全线程栈（:213-215）、App Uptime（formatDuration :447）、内存/存储（formatBytes :454）、logcat 快照（captureLogcat :464）、原因链 getCauseChain :421、线程 id threadIdOf :433、进程名 :441。
- 连击自动备份：`MAX_CRASH_LOGS=8`（CrashLogManager.kt:26）、`CONSECUTIVE_THRESHOLD=3` + `CONSECUTIVE_EXPIRY_MS=24h`（:42-43），`shouldAutoExport(count,hasExported)`（:54-55），`nextConsecutiveCount`（:74）与水位 `waterlineAfterClear`（:92）均纯函数便于单测；自动导出文件名 `DITING-crash-auto-backup-$timestamp.txt`（:179），成功/手动导出共享「不再重复导」标志（:46-52,185-189,208）。
- 导出：`exportToDownloads`（:238）走 SAF，失败回退私有 Downloads（exportToPrivateDownloads :270）；pendingAutoExportNotice 消费式提醒（:220）。
- Native（tombstone）两路：
  - `checkAndCollectNativeCrashes`（CrashLogManager.kt:368）——**仅 API 30+（`< R` return :369）**，`getHistoricalProcessExitReasons(pkg,0,10)`（:373），只筛 `REASON_CRASH_NATIVE` 且 `timestamp > 水位`（:381），按时间正序逐条 `TombstoneParser.parse(exitInfo.traceInputStream)`（:388-391）→ `collectNativeCrashReport`（:394-398，CrashCollector.kt:335-，第 3 段 "Tombstone & Native Trace"，空则占位 :401）→ saveCrashReport（:400），每条落盘即推进水位（:402-407 注释：批量循环中途再崩不重复计）；DitingApp.kt:47 异步调用。
  - API<30 的普通导出路径另有 Q（29）闸门（:239）。
  - 解码器：TombstoneParser.kt:8 明示格式 = **tombstone.proto**（ApplicationExitInfo.traceInputStream API31+）；`TombstoneProtobufDecoder` 纯 Kotlin wire 解码（无 protobuf 运行时）：根字段 1 arch（arm64/x86/x86_64 :31-35）、2 buildFingerprint（:54）、3 revision（:55）、11 abortMessage（:62）、12 cause（:63）、15 threads（:64），**显式跳过 16 memory_dump/17 logcat/18**（:65）；signal 号 :97。TombstoneWireReader/TombstoneReportFormatter/TombstoneTextSanitizer 分层。
- 清除：`clearCrashLogs`（:433）+ getCrashLogFiles/Count（:287,295）+ generateExportContent（:302）；崩溃目录 `getCrashDir`（:95）。

## 7. 应用更新（update/ 5 文件 + 3 屏）

- 源：GitHub Releases API——`RELEASE_URL = "https://api.github.com/repos/haoze-evolluling/DITING/releases/latest"`（AppUpdateManager.kt:182）；解析 `parseLatestRelease(payload, currentVersion)`（:196-211，版本去 "v" 前缀 :211），比较在 Manager 内部（低则 null）。
- 检测触发：启动自动检查受开关控制且**默认关闭**——`isStartupUpdateCheckDisabled` 默认 true（SystemSettingsStore.kt:169-171），MainStartupCoordinator.kt:41-43 仅在开关放开时 `checkForUpdate(manual=false)`；手动入口 SettingsRouteActivity.kt:152（manual=true）。
- 下载：目标 `filesDir/app-update/update-{version}.apk`，临时 `.part` 原子改名（AppUpdateManager.kt:52,75-76）；进度节流 `AppUpdateProgressThrottle`（DEFAULT_MIN_BYTES=256KB、DEFAULT_MIN_INTERVAL_MS=250ms，:42-43）→ AppUpdateNotifier 通知（4.5）。
- 断点语义：成功记 `rememberAppUpdateDownload(path,version)`（:115→SystemSettingsStore.kt:155-160）；失败时 `shouldClearDownloadRecord(recorded,failed)`（:188-191 纯函数——**只有失败版本==记录版本才清**，防误删旧版可用 APK）；`refreshDownloadState` 校验本地文件+版本匹配（:146-157）。
- 安装：`installDownloadedUpdate`（:164-177）——版本一致性 check（:167）、文件非空 check（:169）、`FileProvider.getUriForFile(pkg.fileprovider)`（:170，Manifest:71-79 + res/xml/file_paths）、ACTION_VIEW + `application/vnd.android.package-archive` + GRANT_READ_URI（:171-173）。
- 目录契约：`AppUpdateDirectories.downloadDirectory = filesDir/app-update`（AppUpdateDirectories.kt:13-16）——KDoc :8-12 记录历史缺陷「数据清理曾硬编码 filesDir/updates，那个目录从未有过 APK，清理动作等于没清」。
- UI：AppUpdateHost（class，update/AppUpdateHost.kt:17；checkForUpdate :27 / downloadUpdate :56 / refreshDownloadState :120 / cancelActiveDownload :129）；AppUpdateDialog.kt:22、AppUpdateScreen.kt:22（AboutScreen.kt:111 / SponsorScreen.kt:34 / SponsorListScreen.kt:32 同域挂载，Sponsor 内容属 06 章）。
- 清理联动：DataCleanupManager.DOWNLOAD_CACHE 用同一目录常量（续篇 11 节）。

## 8. 权限矩阵

Manifest 13 项声明：AndroidManifest.xml:5-17（INTERNET、ACCESS_NETWORK_STATE、FOREGROUND_SERVICE、FOREGROUND_SERVICE_DATA_SYNC、FOREGROUND_SERVICE_SPECIAL_USE、POST_NOTIFICATIONS、REQUEST_INSTALL_PACKAGES、REQUEST_IGNORE_BATTERY_OPTIMIZATIONS、QUERY_ALL_PACKAGES、GET_INSTALLED_APPS、SYSTEM_ALERT_WINDOW、WAKE_LOCK、RECEIVE_BOOT_COMPLETED）。实测**无 `<queries>` 块、无 boot 权限用于本域**；`GET_INSTALLED_APPS` 为 Android 16 新权限声明。

AppPermission 枚举（permission/AppPermission.kt，分级 :27-29 REQUIRED/RECOMMENDED/OPTIONAL；项 :40-60+）：

| 权限/特殊访问 | 声明处 | 请求时机 | 拒绝后果 | 各模式依赖度 |
|---|---|---|---|---|
| VPN（VpnService.prepare，非 Manifest） | 系统弹窗 | 启动开关（DnsVpnService 编排）、Tile requestVpn 回主屏（Tile:105-110,135-139） | 无法启动隧道 | NORMAL 必需 / EXPRESS 必需 / DNS(服务器) 不需要 |
| POST_NOTIFICATIONS | Manifest:10 | API33+ 运行时；判定 NotificationPermissionHelper.kt:21-25；跳设置 :40-55 | 所有通知静默（更新进度等 canPost 先短路） | 三模式均推荐（常驻通知/更新提醒） |
| SYSTEM_ALERT_WINDOW（特殊访问） | Manifest:15 | 悬浮窗开关：LogRetentionSettingsScreen.kt:147-156 跳 ACTION_MANAGE_OVERLAY_PERMISSION；判定 AppPermission.kt:76 / Controller:147 | 悬浮日志窗不可用（其他不受影响） | 可选，三模式等 |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | Manifest:12 | 保活推荐；BatteryOptimizationHelper.kt:69（isIgnoringBatteryOptimizations）、:97 ACTION_REQUEST… | 后台被杀概率上升，统计断流 | 推荐，NORMAL/服务器模式强需 |
| QUERY_ALL_PACKAGES / GET_INSTALLED_APPS | Manifest:13-14 | 应用列表类功能；AppListPermissionHelper.kt:52 isGranted / :69 canQueryInstalledApps / :94,101 披露确认 | 应用选择/流量归因列表降级 | NORMAL（按应用规则+流量统计）强、EXPRESS 中、DNS 弱 |
| REQUEST_INSTALL_PACKAGES | Manifest:11 | 更新安装 ACTION_VIEW 触发系统授权 | 无法安装更新包 | 三模式等（仅更新时） |
| FGS 三型 / WAKE_LOCK / BOOT_COMPLETED | Manifest:7-9,16-17 | 安装即得 | 服务无法常驻/自启 | NORMAL specialUse、EXPRESS specialUse、服务器 specialUse（Manifest:19-52,146-153）、监控 specialUse；SystemForegroundService dataSync（:54-57，WorkManager） |

- 模式就绪：`ModeReadinessEvaluator.evaluate(context, mode)`（ModeReadinessState.kt:29-31，data class :9，getActiveRecommended :21）；UI ModeReadinessBanner.kt:54、ModePermissionWarningAction.kt:44（requestPermission :115）。
- 引导/去重持久化 `ModePermissionStore`（ModePermissionStore.kt:9）：三前缀键 `onboarding_completed_{mode}` `permission_explained_{perm}` `recommendation_dismissed_{perm}`（:11-13）；clearDismissedRecommendations 被 SystemSettingsStore.resetAllSettingsGuides 调用（SystemSettingsStore.kt:197-209，O-146 修复：此前「不再提醒」标志无任何复位路径）。

## 9. 配置导入导出（ui/transfer/ 10 文件 + Models/VM + 两屏）

- 文件清单：ConfigExporter / ConfigImporter / ConfigTransferParser / ProviderConfigImporter / NetworkFeatureConfigImporter / RuleConfigImporter / AppRuleConfigImporter / PreferenceConfigImporter /（第 10 个为 Import 会话辅助，均 ui/transfer/）+ ui/ConfigTransferModels.kt、ui/ConfigTransferViewModel.kt:35、normal/ui/ConfigTransferScreen.kt:73、express/ui/ExpressConfigTransferScreen.kt:75。
- 格式版本：`FORMAT_VERSION=10`、`MIN_SUPPORTED_FORMAT_VERSION=1`（ConfigTransferParser.kt:20-21）；根对象首两键 `formatVersion`、`exportedAt`（ConfigExporter.kt:33-34）。
- 根字段级（导出实测顺序）：providers[{name,protocol,url,host,port}]（:38-45）、selectedProvider{id,name,protocol,isPreset}（:49-54）、resolutionMode/presetDnsService/raceTestDomain（:55-57）、homeProviderVisibility{visibleProtocols,hiddenProviderRefs,visibleProviderRefs}（:74-79）、raceProviderRefs / smartPredictionProviderRefs / parallelRaceProviderRefs / primaryBackupProviderRefs[{id,name,protocol,isPreset}] / latencyTestProviderRefs（:85-101）、bootstrapEnabled/bootstrapIps[{name,ip,enabled}]/bootstrapPresetIds（Parser :88-95）、dnsCache{enabled,preset,mode,maxTtlSeconds,fixedTtlSeconds,minTtlEnabled,minTtlSeconds}（Parser :98-106）、系统设置含 trafficStatsRetentionDays 等（Exporter :334）；另有 rules/subscriptions/mirrorTemplates/应用名单/outboundProxy/httpInspection/appearance 等（Importer total 计数项 ConfigImporter.kt:25-34 即全集）。port 缺省按协议回退 53/853（Parser :46）。解析口径：全部 `opt*`（缺键不炸），版本<MIN 即拒（:29-30）。
- 导入策略：**逐段 merge 覆盖式**——按 dataset 拿 `RuleDatabases.forDataset`（ConfigImporter.kt:19），五段 import 顺序执行（providers→network→rules→appRules→preferences :52-56），进度回调 ConfigImportProgress（:23）；有新增自定义规则时触发 `RuntimeDnsSettingsRefresher.refreshRuleIndexesIfRunning`（:58-60）。极速侧导入前再过一遍 `sanitizeImportConfig`（ExpressConfigAdapter.kt:51-68：抹 5 个全隧道字段 + blockedAppsEnabled 对齐本地，防误改）。
- 恢复出厂：不在 transfer 而在数据清理（下节 ALL_DATA）。

## 10. 数据清理与保留（DataCleanupManager + 两屏）

- 执行体 `data/cleanup/DataCleanupManager.kt`（550 行）：clearRequestLogs（:49-65——**dataset 路由**：EXPRESS 清 expressDb.dnsLog/raceLog/bootstrapLog 三表 :56-58，否则 LogMaintenance.clearAllLogs 四表 :60）、clearTrafficStats（:67-73 双清内存+库）、clearCrashLogs（:78）、clearDnsCache（:85-99，express 清完调 ExpressSettingsRefresher.clearCacheIfRunning :93）、resetProviderWeights/resetBootstrapWeights（:103-111）、clearAllDomainRules（:118-，内部 clearDomainRulesData :195-203）等；`internal clearDomainRulesData` 复用。
- 普通屏 `normal/ui/DataCleanupScreen.kt:34`（参数 `dataset: RuleDataset = NORMAL` :39）：`CleanupAction` 私有枚举 :152，**实测 16 项分组**——组1 日志/流量/崩溃/缓存（:65-68）、组2 权重恢复×2（:73-74）、组3 域名规则/地址规则/订阅/应用名单（:79-82）、组4 出站代理/MITM CA/下载缓存/自定义背景（:87-90）、组5 新手引导复位/全部本地数据（:95-96）；确认框 ConfirmDialog :229（AppConfirmDialog），when 派发 :108-118+（LOG→clearRequestLogs(dataset) 等，**dataset 透传**）。
- 极速屏 `express/ui/ExpressDataCleanupScreen.kt:45`：独立 `ExpressCleanupAction`（public enum :231，含 title/message 双字段）——LOG/CRASH/CACHE/PROVIDER_WEIGHT/BOOTSTRAP_WEIGHT/DOMAIN_RULES/SUBSCRIPTIONS…（:78-136 渲染），**无流量统计项**（极速无源，2.4）。
- 与保留策略分工：定期清扫=LogMaintenance（3.2），一键清空=DataCleanupManager（引用即可，02 章有表级细节）。

## 11. 关键源码引证表（断言 → 路径:行，均本会话实测）

| 断言 | 引证 |
|---|---|
| 唯一生产启动传 isGoTunnelActive=true | normal/DnsVpnService.kt:321 |
| kernel 采样仅 !Go 时启用（现网不可达） | core/traffic/TrafficStatsManager.kt:122-124,130-132 |
| Go 回调注册→tick 入口 | normal/GoInspectionTunnel.kt:369-373；TrafficStatsManager.kt:184 |
| 写库节流 15s/1MB | core/traffic/TrafficDatabaseSyncer.kt:143-145；TrafficStatsManager.kt:297-306,317-319 |
| EMA α=0.3、间隔补偿 0.2s 下限、1s 看门狗 | TrafficSpeedEstimator.kt:120；TrafficStatsManager.kt:34,217-218,245 |
| 极速零流量采集 | grep express/ 无 TrafficStatsManager.（本会话）；ExpressConfigAdapter.kt:51-58 |
| 四路 logger 批量参数 | DnsLogger.kt:186-188；RaceLogger.kt:157-158；HttpRequestLogger.kt:108-109；BootstrapLogger.kt:102-103 |
| 四路 logger 生产写入点 | GoInspectionTunnel.kt:290,323,347；GoTunnelLogProcessor.kt:98；ExpressTunnelManager.kt:357；ExpressUpstreamDispatcher.kt:198,214 |
| 保留：默认 7/钳位 1-30；流量 30/1-90；0=关清扫 | SystemSettingsStore.kt:31-32,56,129；LogMaintenanceManager.kt:61,79,99 |
| 清扫 1h/首 30s | LogMaintenanceManager.kt:24-25,41-49,120 |
| 五渠道 + 极速渠道 | AppNotificationChannels.kt:17-21,58,70,82,92,102；ExpressNotificationBuilder.kt:29 |
| VpnMonitorService=未运行提醒（非第三方检测） | VpnMonitorService.kt:20-23,133-151；VpnStateRegistry.kt:10-22 |
| 通知 id 1001/1002/2001/41018 | VpnNotificationBuilder.kt:25；VpnMonitorService.kt:155；ExpressNotificationBuilder.kt:28；AppUpdateNotifier.kt:71 |
| tile 三模式分发 + 锁屏 | DitingTileService.kt:57-70,43-55 |
| ComponentName 全限定名坑 | core/tile/QuickSettingsTileUpdater.kt:21-27 |
| 两阶段崩溃报告 | CrashHandler.kt:50-78；CrashCollector.kt:287,36 |
| 3-in-24h 自动备份、上限 8 | CrashLogManager.kt:26,42-43,54-55,179 |
| tombstone API30+、字段 1-15、跳 16-18 | CrashLogManager.kt:369-373；TombstoneParser.kt:8；TombstoneProtobufDecoder.kt:31-65 |
| 更新源 URL、默认不自动检查 | AppUpdateManager.kt:182；SystemSettingsStore.kt:169-171；MainStartupCoordinator.kt:41-43 |
| 目录契约 app-update | AppUpdateDirectories.kt:13-16；AppUpdateManager.kt:52,75-76 |
| FileProvider 安装 | AppUpdateManager.kt:170；AndroidManifest.xml:71-79 |
| FORMAT_VERSION=10、根键 | ConfigTransferParser.kt:20-21,29；ConfigExporter.kt:33-34 |
| 悬浮窗窗型 26 分界、2s 刷新、三档面板 | FloatingLogWindowType.kt:16-22；FloatingLogOverlayController.kt:348,314-320 |
| 清理 16 项、dataset 路由 | DataCleanupScreen.kt:65-96,108-118；DataCleanupManager.kt:49-65 |

## 12. 「待定」清单

1. ~~express BootstrapLogger 是否死代码~~ **已定版**：经 BootstrapSelector.kt:27,117 注入并有 `logger?.log` 调用（ExpressTunnelManager.kt:301），非死代码。
2. ~~极速 dns_race_log 写入是否总开启~~ **已定版**：raceLogger 在 ExpressTunnelManager.kt:324 实参传给 dispatcher（:322 构造），ExpressUpstreamDispatcher 侧为可空默认（:38）但注入链完整。
3. DnsVpnService:188-206 三个 startForeground 分支的触发条件矩阵（specialUse 首试/回退/最终兜底）与 VpnMonitorService 同构逻辑（:80-97）是否共用工具——未见共用函数，疑重复实现。
4. tile「TOGGLEABLE_TILE + 服务器模式」组合在 Android 13+ 的状态回写延迟：DnsModeManager.status 冷启时序（Tile:79-88 注释承认轮询会误画）——需真机验证。
5. `getHistoricalProcessExitReasons` 第二参 0、上限 10（CrashLogManager.kt:373）对「pid 过滤=本进程全部」语义依赖真机回归。
6. ~~渠道 importance~~ **已定版**：全 LOW，唯 SUBSCRIPTION_AUTO_UPDATE DEFAULT（AppNotificationChannels.kt:38,61,73,85,105,95）。
7. 更新下载是否校验哈希/签名：AppUpdateManager 下载路径只见原子改名与进度（:75-115），**未见校验和**——是否依赖 APK 安装器自身签名校验，文档按「无独立校验」记录，待定复核。
8. `NotificationSettingsStore` 自定义文案键（CUSTOM_RUNNING/STOPPED）默认值与 UI 入口全表（本章只实测 STOPPED 消费 :133-138 与两默认布尔开关 :17-18）。
9. `ui/SponsorScreen/SponsorListScreen/AboutScreen` 与更新域仅入口级关联，内容域归 06/12 章——未展开。

## 13. Flutter 重构注意（仅本会话确证项）

- **通知**：`flutter_local_notifications`（渠道/进度/ongoing/action/角标策略全可映射）+ `android.app` FGS 通知需 `flutter_foreground_task` 或直接保留原生 Service 壳。须照搬：5+1 渠道 id 字符串与 LOW 档位、id 段 1001/1002/2001/41018、VpnMonitorService「未运行才提醒 + Android12+ startForeground 双试不死」时序、API33 权限预检模式。
- **悬浮窗**：现成 `system_alert_window` 类插件覆盖 addView/drag/TYPE 兼容（**26 分界逻辑必须由 plugin 原生侧保留**）；2s 轮询 + 亮灭屏/前后台三闸门是行为契约。
- **Tile**：`quick_settings_tile` 类插件可显示/刷新，但**三模式分发、prepare 回主屏、startForegroundService 被拒回退、ComponentName 全限定名**四点都在原生 TileService 语义内，建议保留 Kotlin 壳、Flutter 只做状态源。
- **更新**：Dio+`open_filex`/`install_plugin` 可平移，但 FileProvider authority `{pkg}.fileprovider` 与 REQUEST_INSTALL_PACKAGES 流程保留原生声明；「默认不自动检查 + 版本匹配才清记录」两语义照抄。
- **流量统计与 tombstone：必须原生**。Go 回调 JSON、UID 归因、EMA/看门狗、15s/1MB 节流、app_traffic_daily 表、以及 TombstoneProtobufDecoder（纯手工 wire 解码 + 跳 16-18 的体积策略）在 Flutter 插件生态无等价物，建议整体留在平台通道层，Dart 侧只读快照流。
- **日志写入器**：参数表（50/500ms、20/2s、10/500ms、20/2s、queue2000、0=关清扫、1..30 vs 1..90）是迁移验收清单——drift 重写时逐条对齐，表名/列名保持（导出格式 formatVersion=10 兼容依赖配置侧，不受影响）。
- **KernelTrafficSampler 删除候选**：生产不可达（2.1-3），Flutter 侧不必实现内核采样路径，除非重新设计「无 Go 隧道时」的采集需求——重构前向产品确认。
