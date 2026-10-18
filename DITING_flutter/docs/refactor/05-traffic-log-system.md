```yaml
所属系列: DITING Android Flutter 重构功能图谱
章: 05（本篇 + 续篇 05-traffic-log-system-2.md，互为引用）
最后校验: 2026-10-18
口径: 本域文件全部点名（core/traffic 7、ui/traffic 7、core/log 5、ui/dashboard 4、ui/floating 6、notification 5、tile 1、crash 12、update 5、permission 7、ui/transfer 10、normal/notification 2、express/notification 1，另含 retention/清理/导入导出相关散文件）；数字均为本会话工具实测
```

# 05 流量统计、日志体系与系统周边

## 1. 概述

本章覆盖八个互相咬合的子系统：**流量统计**（`core/traffic/` + `ui/traffic/`，按 UID 归因的应用级字节账本与 EMA 实时网速）、**日志体系**（`core/log/` 四路批量写入器 + `LogMaintenance` 保留清扫 + 双模式仪表盘/明细屏）、**悬浮日志窗**（`ui/floating/` 6 文件，TYPE_PHONE/OVERLAY 兼容）、**通知**（`notification/` 5 文件 + 两模式各自的常驻通知构建器 + `AppUpdateNotifier`）、**QS Tile**（`tile/` + `core/tile/QuickSettingsTileUpdater`）、**崩溃收集**（`crash/` 12 文件，Java 两阶段报告 + Native tombstone protobuf 解码）、**应用更新**（`update/` 5 文件 + 3 个设置屏）、**权限**（`permission/` 7 文件 + Manifest 13 权限）、**配置导入导出**（`ui/transfer/` 10 文件 + 两模式屏 + ViewModel/Models）。

Flutter 重构判定基调：通知渠道/常驻通知/Tile/悬浮窗/更新安装/权限跳转均为**系统能力**，Flutter 有对应插件但语义细节（渠道 importance、FGS 类型回退、tile 三模式分发、锁定屏 unlockAndRun）必须照搬；流量统计与 tombstone 解码**必须保留原生**（Go 回调 JSON→UID 归因→Room 日表，以及 ApplicationExitInfo protobuf 手工解码，插件生态无等价物）；日志四路写入器与保留清扫是纯 Kotlin+Room，可用 Dart+drift 等价重写但**参数与表结构不可改**（否则历史数据/导出格式失配）。

跨域锚点：Go 回调 `onLogMessage`/`setTrafficCallback` 的引擎侧归属见第 09/10 章；Room 表与 DAO 定义见第 02 章；`RuntimeDnsSettingsRefresher` 本体在 `core/rule/`（任务书写作 ui/，实测路径为 core/rule/RuntimeDnsSettingsRefresher.kt），本章只记其与日志保留的联动。

## 2. 流量统计

### 2.1 采集链逐跳（生产路径 = Go tick，实测唯一）

1. **数据源 API 不是 TrafficStats**：普通模式生产链路的唯一采集源是 Go 引擎定时回调。`GoInspectionTunnel.kt:369-373` 注册 `engine.setTrafficCallback`，其 `onTrafficStatsTick(jsonDeltas)`（:370-371）直接调 `TrafficStatsManager.onGoTrafficTick(jsonDeltas)`。JSON 为数组，每项 `{uid, tx, rx}`（解析体 `TrafficStatsManager.kt:192-212`）。
2. **启动闸门**：`DnsVpnService.kt:320-322`——`isAppTrafficStatsEnabled || isTrafficSpeedEnabled` 任一为真才 `TrafficStatsManager.start(this, true)`，**硬编码 `isGoTunnelActive=true`（实测全仓唯一生产调用点）**。
3. **内核采样路径生产不可达（关键发现）**：`TrafficStatsManager.start` 内 `if (!isGoTunnelActive) { kernelSampler.initBaseline(...) }`（:122-124）与 `if (!isGoTunnelActive) startSamplingLoop(...)`（:130-132）——由于唯一调用方传 `true`，`KernelTrafficSampler` 的采样循环（退避档 1s→3s→10s、灭屏下限 5s：`KernelTrafficSampler.kt:29-38,90-95`）与 `TrafficStats/TetheringStats` 内核读法在现网**从不执行**，仅剩测试可达。`onGoTrafficTick` 注释亦自证（`TrafficStatsManager.kt:220-223`「kernel sampler skipped while Go tunnel is active」）。
4. **UID→应用归因**：`appResolver.getOrResolveAppInfo(context, uid)`（:204；`TrafficAppResolver.kt:22-26` uid/package 双缓存 + 负缓存，`refreshAppList` 跳过自身包 :35）。系统应用分类走 `SystemAppClassifier.kt:51-56`（已知前缀表）与 :66（ApplicationInfo flags）。
5. **会话累加**：`recordAppTraffic`（:309-320）——会话总/单应用 AtomicLong + `dbSyncer.recordDelta`（`TrafficDatabaseSyncer.kt:47`），越过阈值即触发提前 flush（:317-319）。
6. **写库节流**：双条件——周期 15s（`startFlushLoop` :297-306，`BATCH_FLUSH_INTERVAL_MS=15_000`）或累计 1MB（`BATCH_FLUSH_THRESHOLD_BYTES=1024*1024`，`TrafficDatabaseSyncer.kt:143-145`；FLUSH_STOP_TIMEOUT_MS=500 :145）。`flushPendingDeltas`（:102-131）经 `AppDatabase.getInstance` 调 `appTrafficDao().upsertBatchDeltas(date, deltas, updatedAt)`（:120-125）——**只写普通模式主库**；极速模式无流量统计（见 2.4），故无第二库路径。
7. **日期翻转**：`isDateRolloverNeeded()` 在 tick 里惰性触发 `checkDateRollover`（:188-190；syncer :68-72 先 flush 再换日）。
8. **UI/DB 出口**：`publishSnapshot()` 到 `MutableStateFlow _uiSnapshot`（:62,127,135,161,226）→ `AppTrafficStatsViewModel.kt:29`（normal/ui/AppTrafficStatsScreen.kt:52 消费）；常驻通知网速由 `VpnSpeedMonitor` 读快照（2.3）。

### 2.2 指标口径（实时网速）

- EMA 平滑：`TrafficSpeedEstimator.kt`，`EMA_ALPHA=0.3`（:120）；总量 `updateSpeedEma`（:22-33）、单应用 `updateAppSpeedsForTick`（:52）/`updateSingleAppSpeedEma`（:36-42）、空闲衰减 `decayIdleSpeeds`（:88）/`decaySingleAppSpeed`（:75）。
- tick 间隔补偿：`elapsedSeconds = max(0.2, (now-lastTick)/1000.0)`，首拍 1.0（`TrafficStatsManager.kt:217-218`）——聚合灭屏拍（如 10s 一拍）不失真。
- Go 模式衰减看门狗：`ensureGoDecayWatchdog`（:239-253），仅在有非零速度且亮屏时按 `GO_DECAY_WATCHDOG_INTERVAL_MS=1_000`（:34,245）每秒衰减并广播快照，归零/灭屏自退——空闲零唤醒。
- `setScreenInteractive`（:170）由 `DnsVpnService` 电源广播接线（register :323 powerOptimizer）。

### 2.3 日表与消费方

- 表 `app_traffic_daily`（`data/entity/AppTrafficDailyEntity.kt:8`），列 date(yyyy-MM-dd)/package_name/app_name/tx_bytes/rx_bytes/updated_at（:16-21，累计字节）。DAO：`data/dao/AppTrafficDao.kt`（upsertBatchDeltas、deleteOlderThan）。
- 消费方：`ui/traffic/` 7 文件——TrafficGaugeCard.kt:38（总仪表盘）、AppTrafficDetailDialog.kt:36、TrafficAttributionDialog.kt:27（归因说明）、TrafficFilterBar/TrafficSessionClock/AppTrafficRankItem/AppTrafficStatsModels；`normal/ui/AppTrafficStatsScreen.kt:52` + ViewModel:29；常驻通知网速（VpnSpeedMonitor.kt:38,54）；设置项开关与隐藏系统应用（SystemSettingsStore.kt:109-143）。
- 保留：`pruneExpiredTrafficStats`（LogMaintenanceManager.kt:78-84）按 `trafficCutoffDate`（:87-88，yyyy-MM-dd 字符串比较）调 `deleteOlderThan`；天数默认 30、钳位 1..90（SystemSettingsStore.kt:32,126-131）；接线点 `DnsVpnDatabaseComponents.kt:126,137`（provider 现读设置值）。
- 清除：`TrafficStatsManager.clearAllTrafficStats`（:321 区域）+ `LogMaintenance.clearAllTrafficStats`（:163），由 DataCleanupManager 双调（4. 节续篇）。

### 2.4 模式差异（实测）

- **极速(express)**：`grep TrafficStatsManager. express/` **零命中**——极速模式完全不采集流量统计。导入配置时 `ExpressConfigAdapter.sanitizeImportConfig`（express/config/ExpressConfigAdapter.kt:51-58）把 `bypassLanEnabled/appTrafficStatsEnabled/trafficStatsRetentionDays/trafficStatsHideSystemApps/trafficSpeedEnabled` 5 字段置 null，禁止落库。
- **服务器(server)**：本域文件内无任何 server 侧引用（无 VPN 隧道，无统计源）。
- **普通(normal)**：全部生产路径所在地。

## 3. 日志体系

### 3.1 四路 Room 日志写入器（参数全实测）

| 写入器 | BATCH_SIZE | FLUSH 周期 | 额外上限 | 模式闸门 | 表 | 生产写入调用点 |
|---|---|---|---|---|---|---|
| DnsLogger (core/log/DnsLogger.kt) | 50 (:186) | 500ms (:187) | MAX_PENDING_QUEUE=2000（超限 takeLast 丢弃 :67-77） | modeProvider+isLoggable (:22,30-31) | dns_log (DnsLogEntity.kt:15) | normal: GoTunnelLogProcessor.kt:98 logBatch（批过滤 :72）；express: ExpressTunnelManager.kt:357 log（构造 :281 带 dnsLogModeProvider） |
| RaceLogger (RaceLogger.kt) | 20 (:157) | 2000ms (:158) | — | 无 | dns_race_log (RaceLogEntity.kt:12) | normal: GoInspectionTunnel.kt:290（scope.launch 内，含 selected/winner 富化 :297-300）；express: ExpressUpstreamDispatcher.kt:198,214（可选注入 :38） |
| HttpRequestLogger (HttpRequestLogger.kt) | 10 (:108) | 500ms (:109) | — | 构造传 modeProvider（DnsVpnDatabaseComponents.kt:99） | http_request_log (HttpRequestLogEntity.kt:8) | normal: GoInspectionTunnel.kt:347（subscriptionId 解析 :346→GoTunnelLogProcessor.kt:102-124）；express: 无 HTTP 表 |
| BootstrapLogger (core/diagnostic/BootstrapLogger.kt) | 20 (:102) | 2000ms (:103) | — | 无 | bootstrap_log (BootstrapLogEntity.kt:8) | normal: GoInspectionTunnel.kt:323（同拍喂 bootstrapHealthEngine.recordResult :322）；express: BootstrapSelector.kt:117 `logger?.log`（logger 注入 ExpressTunnelManager.kt:301，可空默认 BootstrapSelector.kt:27） |

- 结果语义：`LogResult` = PASSED/REWRITTEN/BLOCKED/ERROR（DnsLogResult.kt:3-8）；`DnsLogMode` = ALL/BLOCKED_AND_ERRORS/OFF（ui/DnsLogMode.kt:3-6），按 dataset 分仓存储（SystemSettingsStore.kt:35-46，KEY "dns_log_mode"），非法值回退 ALL（:9-10）。
- 归属：Go→Kotlin 的 `processLogBatch(json)` 入口在 `GoTunnelLogProcessor.kt:24`，outcome 字符串→枚举映射 :143，上游 TTL 提取 :163；Kotlin↔Go 桥契约见 09 章。
- 清空：`clearAll()` 由各 flush 持有方统一接线（normal: DnsVpnDatabaseComponents.kt:105-109 先 flush 后 clear；LogMaintenance.clearAllLogs :149）。

### 3.2 保留与清理（TTL 逐项实测）

- 清扫节律：`LogMaintenance`（object，core/log/LogMaintenanceManager.kt:23）——首跑 30s 延迟、此后每 1h（INITIAL_DELAY_MS :25、MAINTENANCE_INTERVAL_MS :24；两个 start 循环 :34-49、:113-125）。
- DNS 日志保留天数：默认 7（SystemSettingsStore.kt:31），setter 钳位 `coerceIn(1,30)`（:56）；cutoff = nowMillis − days·DAY_MS（DAY_MS :26；pruneExpiredLogs :60-72 同时清 dns/race/bootstrap/http 四 DAO；`retentionDays<=0` 直接 return :61,79,99——**0=关闭清理而非立即清空**）。Express 变体 :94-110（`httpRequestLogDao` 可空，注释 :91-92 明示极速库无 HTTP 表）。
- 流量保留天数：默认 30、钳位 1..90（:32,129）——**与日志侧 1..30 不对称**。
- UI：`LogRetentionSettingsScreen.kt:57`，日志模式单选 + 保留天数单选（选项恰为 `listOf(1, 7, 30)` :54、渲染 :216-225）；流量统计开关/保留/隐藏系统应用同页；悬浮窗开关在此页做 `canDrawOverlays` 预检与跳设置（:125,147,156）。
- 生效时序修复：`LogRetentionSettingsActions.applyRetentionDays`（ui/LogRetentionSettingsActions.kt:21-30）固定三步 updateState→persist→notifyRuntime；KDoc :3-13 记录历史缺陷（改保留天数不通知运行引擎则下一轮清扫仍用旧值）。runtime 通知经 `core/rule/RuntimeDnsSettingsRefresher.kt`（VpnStateRegistry 闸门 :46,57,83,93,122,132）。

### 3.3 展示层

- 仪表盘：`normal/ui/ModernLogDashboardScreen.kt:49` + `ui/ModernLogDashboardViewModel.kt:119`；公共组件 `ui/dashboard/` 4 文件（DashboardLogLabels / ModernLogDashboardComponents / ModernLogDashboardFormatters / ModernLogDashboardModeViews）。
- 明细列表：`normal/ui/RequestLogScreen.kt:92`、`express/ui/ExpressRequestLogScreen.kt:82`（卡片 :331）、`express/ui/ExpressLogDashboardScreen.kt:50`；分页 VM `ui/RequestLogViewModel.kt:33`，行模型 `ui/RequestLogItem.kt`。
- 悬浮窗复用同源映射：`FloatingLogMapper.kt` fromDnsLog :20 / fromHttpLog :70 / dnsType :124 / loadRecentLogs(limit=30) :136-147（batch 取回后再 `take(limit)` 截断 :143-147）。

### 3.4 崩溃日志（文件形态，详见第 6 节/续篇）

崩溃不入库：`crash/` 12 文件写**私有目录文本报告**，`MAX_CRASH_LOGS=8` 滚动（CrashLogManager.kt:26）；表内无 crash 行。
