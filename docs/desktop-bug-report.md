# 安卓端 Bug 记录

> 文件名沿用项目既定约定（`docs/desktop-bug-report.md`），内容为安卓客户端扫描结果，不包含桌面端问题。
>
> - 扫描基线：`main` @ `3a048c5`（含修复提交 `18319ed`）
> - 扫描范围：`Android/app/src/main/java/com/haoze/diting/` 与 `Android/tunnel/`
> - 记录原则：只记录问题，不修改代码；每条给出代码位置、触发路径和验证方式。存疑但未达到确认标准的事项统一放在文末“观察”。
> - 前一轮（基线 `6da118e`）的 A-001…A-010 已由 `18319ed` 修复并从本文档删除，本轮确认缺陷自 A-012 起编号（A-011 曾提交后于复核中撤回，编号不复用，避免与历史编号重复）。
> - 验证状态：本轮 Room 校验语义依据本机 Gradle 缓存中的 `room-runtime 2.7.0` 字节码（`TableInfoKt.equalsCommon`/`defaultValueEqualsCommon`/`RoomOpenHelper.onUpgrade`）与 KSP 生成代码（`app/build/generated/ksp/debug/.../AppDatabase_Impl.kt`）逐项核对。
> - 撤回复核：曾拟记录的「`isException` 迁移 DEFAULT 0 与实体 schema 漂移导致升级崩溃」（暂编 A-011，见提交 99c559d）经回读 `equalsCommon` 完整控制流后确认为**误报**：ENTITY(1)↔DATABASE(2) 方向的默认值比较仅在**实体侧默认值非空**时执行（偏移 106 `aload_2; ifnull 125` 判空跳过，`astore_2` 存的是接收者即期望/实体侧列），本例实体未声明 `@ColumnInfo(defaultValue)`，Room 容忍该漂移，迁移校验通过。关键旁证：同型的 `enabled DEFAULT 1` 漂移自 schema v2 起随每次发布共存而未有任何崩溃报告。该漂移作为规范卫生问题降级至 O-101。

## 汇总

| 编号 | 严重度 | 模块 | 问题 | 状态 |
| --- | --- | --- | --- | --- |
| A-012 | 中 | VPN IPv6 探测 | AUTO 模式的网关/路由检查是死代码：只要接口有 GUA 地址就启用 IPv6，与函数文档「地址 AND 路由」相反（normal 与 Express 两份拷贝同犯） | 待处理 |
| A-013 | 中 | 数据清理 | 「清理下载与临时缓存」删除 `filesDir/updates`，但更新安装包实际写入 `filesDir/app-update`，清理承诺落空且残留 APK 永久泄漏 | 待处理 |
| A-014 | 中高 | 流量统计保留 | `app_traffic_daily` 只被「DNS 日志保留天数」（默认 7）清理，专属的「流量保留 30 天」设置无任何清理消费者；降低日志保留会静默销毁数周流量历史 | 待处理 |
| A-015 | 中 | 流量实时速度 | Go 隧道模式（唯一生产路径）下每应用实时网速恒为 0：「按实时网速」排序与逐项 ↑/↓ 速度永不生效，而页面文案承诺展示 | 待处理 |
| A-016 | 中 | 数据清理 | 「清除自定义背景缓存」删除 `appearance_settings` 偏好文件中的键，但背景设置实际存于 `dns_vpn_prefs`，清理后背景设置原样保留并继续生效 | 待处理 |

---

## A-012 AUTO 模式的 IPv6 路由/网关检查是死代码，仅有 GUA 地址即启用 IPv6

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnTunnelManager.kt:114-136`（`hasPhysicalIpv6Support`）
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressTunnelManager.kt:169-186`（同一逻辑的 Express 拷贝，同样短路）
  - 调用方：`normal/DnsVpnService.kt:281`（`SystemSettingsStore.getIpv6Mode`）、`normal/DnsVpnTunnelManager.kt:151-154`（`Ipv6Mode.AUTO -> hasPhysicalIpv6Support(...)`）、`express/ExpressVpnService.kt:98`、`express/ExpressTunnelManager.kt:197-202`；默认值 `SystemSettingsStore.kt:14` `DEFAULT_IPV6_MODE = Ipv6Mode.AUTO`
- **问题**
  - 函数文档（`DnsVpnTunnelManager.kt:67-69`）声明探测「有效的公网 IPv6 地址 **和** 网关路由」；实现里路由检查 `hasIpv6Route` 恒不影响返回值：
    - `:114-127` 计算 `hasGlobalIpv6`（严格 2000::/3）；
    - `:128` `if (!hasGlobalIpv6) return@any false` —— 能走到 `:130` 的候选网络必有 `hasGlobalIpv6 == true`；
    - `:130-135` 计算 `hasIpv6Route`（v6 默认路由 / `hasGateway()` / prefixLength==0）；
    - `:136` `hasIpv6Route || hasGlobalIpv6` —— 右操作数恒真，整个表达式恒真，`hasIpv6Route` 是死代码。Express 拷贝 `ExpressTunnelManager.kt:180-186` 逐行相同。
- **用户可见影响**
  - 触发条件真实存在：SLAAC RA 下发前缀但默认路由 router-lifetime=0（或被 DHCPv6 覆盖失败）、以及只配了站点内 v6 前缀、出口 v6 网关缺失的企业网络 —— 这类网络接口上会有 GUA 地址但没有可用 v6 默认路由。
  - AUTO（默认档）在这种网络上返回 true 后，`establishVpnInterface` 添加 `addAddress(VPN_ADDRESS_V6,64)`、`addDnsServer(DNS_SERVER_V6)`、`allowFamily(AF_INET6)`（`:166-170`）并下发 `2000::/3`（bypassLan=true，`:187`）或 `::/0`（`:200`）路由。系统据此偏好 AAAA/IPv6，流量进 TUN 后物理侧无 v6 网关，表现为仅开启 VPN 时 IPv6 目的地黑洞/超时（双栈站点变慢或部分打不开），关闭 VPN 或切到 IPv6=禁用即恢复。
  - `DnsVpnNetworkMonitor.kt:69` 的 `scheduleIpv6AdaptationCheck` 也基于该探测做自适应，同样被短路结果误导。
- **复现/验证**
  1. JVM 单测方向：向 `hasPhysicalIpv6Support` 注入/构造含 `2000::/64` 链路地址、routes 仅有 IPv4 默认路由的 `LinkProperties`，断言应为 false；当前实现返回 true（`:136` 恒真）。
  2. 真机：路由器关闭 v6 前缀的默认路由（RA 里 router-lifetime=0 或只发前缀不发路由），手机获得 GUA；AUTO 档开启 VPN，`logcat | grep establishVpnInterface` 显示 `enableIpv6=true`；对比 v6-only 目标（如 `curl -6 https://[2606:4700:4700::1111]`）经 VPN 黑洞、直连正常。
- **备注**
  - 意图明显是让 `&&`（地址且有路由）或至少以 `hasIpv6Route` 为决定项；按函数文档修正即可。两份拷贝必须同步修复，或将探测抽成共用函数（`core/diagnostic/NetworkInfoProbe.kt:15` 已引用其语义注释）。
  - `hasIpv6Route` 中 `route.hasGateway()` 对 on-link 直写路由同样为 true 的宽松性属另一层语义问题，修正短路后建议一并复核（未单列）。

---

## A-013 「清理下载与临时缓存」删除的更新目录名与实际写入目录不一致，安装包残留无法清除

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:406-414` — `clearDownloadAndTempCache()` 第 1 步删除 `File(context.filesDir, "updates")`
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:52` — `updateDirectory = File(context.filesDir, UPDATE_DIRECTORY)`
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:167` — `const val UPDATE_DIRECTORY = "app-update"`；下载产物为 `app-update/update-<ver>.apk` 与 `.update-<ver>.apk.part`（`:75-76`）
  - UI 承诺文案：`normal/ui/DataCleanupScreen.kt:89` — 「清理下载与临时缓存 / 删除更新安装包、下载临时文件及应用临时缓存」；Express 侧 `express/ui/ExpressDataCleanupScreen.kt:150` 同文案，走同一函数（`:202`）
- **问题**
  - 清理函数删的是 `filesDir/updates`，而全仓库没有任何代码创建或写入 `updates` 目录（grep `File(context.filesDir, "updates")` 仅此一处命中）；真实 APK 目录 `filesDir/app-update` 从未被清理逻辑引用。
  - 同函数顺带调用的 `SystemSettingsStore.clearAppUpdateDownload(context)`（`:409`）会清掉记录安装包路径的偏好，即清理后 UI 连“已下载 vX”的入口都消失，但 `app-update/` 下的 APK（约 10–30 MB/版）仍留在内部存储，用户无任何途径删除。
  - `clearAllLocalData` 的 NORMAL/EXPRESS 全面清理分支（`:483`、`:450` 起）也复用该函数，同样漏删。
- **用户可见影响**
  - 用户在「数据清理」页点「清理下载与临时缓存」或执行全面清理并确认后，更新 APK 实际未被删除：磁盘占用不降；反复下载多个版本时残留累积。属于清理承诺与实现不一致的功能缺陷（非单纯低效）。
- **触发路径**
  1. 设置 → 检查更新 → 下载 vX APK（落盘 `filesDir/app-update/update-X.apk`）。
  2. 数据清理 → 清理下载与临时缓存 → 确认。
  3. 期望：`app-update/` 为空；实际：APK 仍在（`adb shell run-as com.haoze.diting ls -l files/app-update`），仅偏好记录被清。
- **复现/验证**
  1. 静态：对比 `DataCleanupManager.kt:408` 的 `"updates"` 与 `AppUpdateManager.kt:167` 的 `"app-update"`，并 grep 全仓确认 `"updates"` 无写入方。
  2. 真机/模拟器按上述 3 步取证；或 JVM 单测：Robolectric 下写入 `files/app-update/x.apk`，调用 `clearDownloadAndTempCache` 后断言文件仍存在（当前实现如此），修复后应断言被删除。
- **备注**
  - 修复方向：`clearDownloadAndTempCache` 应删除 `File(context.filesDir, AppUpdateManager.UPDATE_DIRECTORY)`（需把常量提为 public/internal），或至少两处目录都清；`UPDATE_DIRECTORY` 常量与清理路径应收敛到单一来源，避免再次漂移。

---

## A-014 应用流量历史被「DNS 日志保留天数」清理，专属「流量保留 30 天」设置无任何清理消费者

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/log/LogMaintenanceManager.kt:50-63` — `pruneExpiredLogs(database, retentionDays)` 在 `:62` 执行 `database.appTrafficDao().deleteOlderThan(cutoffDate)`，cutoff 由传入的 `retentionDays` 推导
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnDatabaseComponents.kt:119` — `LogMaintenance.start(scope, db) { activeLogRetentionDays() }`；`:125` 启动即 `pruneExpiredLogs(db, activeLogRetentionDays())`（全仓唯二驱动流量清理的调用）
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnRuntimeConfigManager.kt:70` — `activeLogRetentionDays = SystemSettingsStore.logRetentionDays(context)` → 键 `log_retention_days`（`SystemSettingsStore.kt:9,47-50`，默认 7、钳制 1..30）
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/SystemSettingsStore.kt:27,31,120-130` — `traffic_stats_retention_days`（默认 30、钳制 1..90）的 get/set
- **问题**
  - `app_traffic_daily` 表的删除路径全仓仅两处：`AppTrafficDao.deleteOlderThan`（`dao/AppTrafficDao.kt:87`）唯一被 `LogMaintenanceManager.kt:62` 调用，其 cutoff 永远来自 **日志** 保留键。`getTrafficStatsRetentionDays` 的消费者仅 `ui/transfer/ConfigExporter.kt:326`（导出配置）与 `PreferenceConfigImporter.kt:109`（导入回填），无任何清理逻辑读取；`setTrafficStatsRetentionDays` 也只有导入器一个调用点（无 UI 写入方）。
  - 结果：两个设置互不相干，流量历史的真实保留期 = `log_retention_days`（默认 7 天），而配置导出/导入却在往返一个从未生效的 30 天值。
- **用户可见影响**
  - 用户在「日志保留」里把保留调小（1–3 天，常规省空间操作）→ 每小时一次的 `MAINTENANCE_INTERVAL_MS` 周期（`LogMaintenanceManager.kt:24`）或服务启动即按 7/3/1 天 cutoff 删除 `app_traffic_daily`；「应用流量统计」的「本月/全部历史」视图（`normal/ui/AppTrafficStatsViewModel.kt:182-201` 按 30 天/全时段查询）只剩几天的数据，历史总量少报，且不可恢复。
  - 反向亦然：用户期望流量统计独立保留 30–90 天（键与默认值即此语义），实际随日志设置漂移。
- **触发路径**
  1. 正常使用 VPN 数天，`app_traffic_daily` 已有 >7 天记录。
  2. 设置 → 日志保留改为 1 天。
  3. 等待周期清理或重启 VPN 服务 → 打开「应用流量统计 → 本月」：只剩 1–2 天记录。
- **复现/验证**
  1. 静态：`grep -rn "appTrafficDao().deleteOlderThan"` 全仓仅 `LogMaintenanceManager.kt:62`；`grep -rn getTrafficStatsRetentionDays` 仅导出/导入两处。
  2. 单测方向：向 Room in-memory `AppDatabase` 插入 `day = today-10` 的 `app_traffic_daily` 行，以 `retentionDays=7` 调 `pruneExpiredLogs`，断言行被删（当前实现如此）；修复后应以流量专属保留期（`traffic_stats_retention_days`）推导其 cutoff，与日志 cutoff 分离。
- **备注**
  - 修复方向：`pruneExpiredLogs` 把 `appTrafficDao().deleteOlderThan` 的 cutoff 改为 `getTrafficStatsRetentionDays` 推导；或为流量清理单列周期任务。同时应提供该值的 UI 入口（当前无写入方）或在文档层面移除「独立 30 天」的暗示，避免导出往返幽灵配置。
  - Express 分支 `pruneExpiredLogs(dataSources, null, …)`（`ExpressTunnelManager.kt:283` 起）不含流量 DAO（Express 无 `AppTrafficDailyEntity`），本条仅影响 NORMAL 库。

---

## A-015 Go 隧道模式（唯一生产路径）下每应用实时网速恒为 0，排序与速度展示永不生效

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/traffic/TrafficStatsManager.kt:96-100` — `fun start(context, isGoTunnelActive)`；`:113-115` `if (!isGoTunnelActive) { startSamplingLoop(appContext) }`
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnService.kt:321` — 全仓唯一 `TrafficStatsManager.start` 调用点：`start(this, true)`（字面量 true；Express 侧从不调用它）
  - `TrafficStatsManager.kt:231-269` — `startSamplingLoop` 内 `:255` `speedEstimator.updateSingleAppSpeedEma(...)` 是全仓唯一写入每应用 EMA 的地方（`onAppIdle` 的 `decaySingleAppSpeed` 同在此循环）
  - `TrafficStatsManager.kt:167-206` — Go 路径 `onGoTrafficTick`：`recordAppTraffic`（`:285-297`，只加总字节/会话/DB 增量，不碰速度）与 `:200` `updateSpeedEma(totalTxDelta, totalRxDelta, …)`（只更新总量 EMA）
  - `core/traffic/TrafficSpeedEstimator.kt:15,20` — `appSpeedEma` 仅由 `updateSingleAppSpeedEma` 填充；`getAppSpeed` 读它
  - `TrafficStatsManager.kt:397-400,411-412` — `buildAppStatsList` 用 `getAppSpeed(pkg)` 生成 `currentTxSpeedBps/currentRxSpeedBps`，Go 模式下恒为 null → 0
  - 消费方：`normal/ui/AppTrafficStatsViewModel.kt:350` `REALTIME_SPEED -> sortedByDescending { it.currentTotalSpeedBps }`；`ui/traffic/AppTrafficRankItem.kt:122,152`（速度行仅 `>0` 时渲染）；`ui/traffic/TrafficAttributionDialog.kt:114` 文案承诺「本页面展示的各应用实时网速…」
- **问题**
  - 生产唯一入口 `start(this, true)` ⇒ `isGoTunnelActive` 恒 true ⇒ `startSamplingLoop` 永不运行 ⇒ `appSpeedEma` 永不被写入 ⇒ 每应用速度恒 0。Go 的 `onGoTrafficTick` 明明拿到逐 uid 的 `tx/rx` 增量（`:184-190`），却只喂总队列，丢弃了计算每应用 EMA 所需的数据。
  - `ensureGoDecayWatchdog`/`decayIdleSpeeds`（`:215-229`、`TrafficSpeedEstimator.kt:62-71`）只衰减已有的每应用 map，空 map 时无效。
  - 「按实时网速」是用户可选排序项（`AppTrafficStatsModels.kt:17`），排序键恒全 0 ⇒ 排序静默无操作；逐项 ↑/↓ 速度文本因 `>0` 门槛永不出现；说明页对「各应用实时网速」的承诺落空。总量仪表不受影响（`updateSpeedEma` 在 tick 路径有调用）。
- **触发路径**
  1. 启动 VPN（Go 隧道，即普通模式正常路径），让 2 个以上应用产生流量。
  2. 打开「应用流量统计」，切换排序为「按实时网速」：列表顺序与「总流量」排序一致（全 0 稳定排序不重排）；任何应用条目下都不出现速度行。
- **复现/验证**
  1. 静态：`grep -rn updateSingleAppSpeedEma` → 仅 `TrafficStatsManager.kt:255`（采样循环内部）；`grep -rn "TrafficStatsManager.start("` → 仅 `DnsVpnService.kt:321` 字面 `true`。
  2. 单测方向：以 `start(context, isGoTunnelActive = true)` 后调用 `onGoTrafficTick(json)`（两条 uid 增量），断言 `buildAppStatsList` 中 `currentTxSpeedBps > 0` ——当前实现返回 0，复现缺陷。
- **备注**
  - 修复方向：`onGoTrafficTick` 的循环内（`:188` 附近）对每个 `appInfo` 调用 `speedEstimator.updateSingleAppSpeedEma(appInfo.packageName, tx, rx, elapsedSeconds)`（`elapsedSeconds` 用同一 tick 间隔），并对无增量应用走 `decaySingleAppSpeed`；或让 UI 在 Go 模式下隐藏「实时网速」项。两种都要同步核对 `TrafficAttributionDialog` 文案。

---

## A-016 「清除自定义背景缓存」清空错误的偏好文件，背景设置与 URI 列表原样保留并继续生效

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:429-438` — `clearCustomBackground()`：先 `CustomBackgroundManager.clearActiveCache(context)`，再对 `context.getSharedPreferences("appearance_settings", …)` 执行 `remove("custom_background_enabled") / remove("custom_background_uri") / remove("custom_background_uris")`，最后 `onBackgroundSettingsChanged(context, false, null)`
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/AppearanceSettingsStore.kt:1`（package `com.haoze.diting.ui.settings`）+ `:23-25`（键定义）+ `:121,127,133,171`（读写全部走 `PREFS_NAME`）
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt:8` — `internal const val PREFS_NAME = "dns_vpn_prefs"`：即 `AppearanceSettingsStore` 与同包 `StartupSelfCheck.kt:22` 实际使用的偏好文件是 **dns_vpn_prefs**，全仓没有任何代码读写名为 `appearance_settings` 的偏好文件（该字符串只出现在清理器 `:431` 与导航路由常量 `AppNavigationRoutes.kt:56`，后者是页面路由名，与 SharedPreferences 无关）
  - UI 承诺：`normal/ui/DataCleanupScreen.kt:121` 与 `express/ui/ExpressDataCleanupScreen.kt:203` 的 `CUSTOM_BACKGROUND` 项 →「清除自定义背景缓存」
- **问题**
  - `remove` 打在空文件 `appearance_settings` 上，真实设置仍完整留在 `dns_vpn_prefs` 中。
  - `onBackgroundSettingsChanged(context, false, null)`（`ui/background/CustomBackgroundManager.kt:265-271`）只做 `clearActiveCache`（丢弃已解码位图），**不写回** `custom_background_enabled`；因此下一次 `applyWindowBackground`（`:278-280`）仍从 `AppearanceSettingsStore.isCustomBackgroundEnabled()` 读到 true，随即按原 URI 重新加载背景。
  - 与 A-013 同族：清理器对目标路径/键的引用与实现方各自硬编码字符串，无共享常量约束。
- **用户可见影响**
  - 用户点「清除自定义背景缓存」并确认后，当前会话中背景短暂消失（缓存被清），随后任意 Activity 创建/重建（切后台回前台、旋转、重进应用）背景即恢复；重启应用后背景完全如旧。设置页中的开关与图片列表也原样保留，用户感知「清理项无效」。
  - `clearAllLocalData` 的全量清理（NORMAL `:533` 与 EXPRESS `:484`）同样调用该函数，「全面数据清理」后自定义背景仍在。
- **触发路径**
  1. 外观设置 → 开启自定义背景并选择图片。
  2. 数据清理 → 清除自定义背景缓存 → 确认。
  3. 回到桌面再重新打开应用：期望恢复默认背景，实际自定义背景仍在。
- **复现/验证**
  1. 静态：`DataCleanupManager.kt:431` 的 `"appearance_settings"` 与 `SettingsPreferencesExtensions.kt:8` 的 `"dns_vpn_prefs"` 对比；grep 全仓确认无任何 store 以 `appearance_settings` 为名调用 `getSharedPreferences`。
  2. 真机：`run-as com.haoze.diting cat shared_prefs/dns_vpn_prefs.xml | grep custom_background` 在清理前后均含 `custom_background_enabled=true` 与 URI 列表（`appearance_settings.xml` 要么不存在、要么为空）。
  3. 单测方向：Robolectric 下 `AppearanceSettingsStore.setCustomBackground(ctx, true, "content://x")` → `DataCleanupManager.clearCustomBackground(ctx)` → 断言 `isCustomBackgroundEnabled(ctx)` 为 false；当前实现返回 true，复现缺陷。
- **备注**
  - 修复方向：`clearCustomBackground` 应改用 `context.getSharedPreferences(PREFS_NAME, …)`（或直接调用 `AppearanceSettingsStore.setCustomBackground(context, false, null)` / 新增 `AppearanceSettingsStore.clearCustomBackground`，把键名与文件名的来源收敛到 store 内部）；同时核对 `custom_background_uris`（列表键）一并清理。
  - 对照：同函数体内 `StartupSelfCheck.kt:52-61` 清理同名 JSON 键时用的就是 `PREFS_NAME`（`dns_vpn_prefs`），可见清理器此处属笔误而非设计。

---

## 观察（未达到确认缺陷标准，供后续验证）

### O-106 `StartupSelfCheck` 只消毒 NORMAL 偏好文件，Express/DNS_MODE 的同名键不覆盖
- `ui/settings/StartupSelfCheck.kt:22` 固定 `getSharedPreferences(PREFS_NAME)`（`SettingsPreferencesExtensions.kt:8` = `"dns_vpn_prefs"`）消毒 `dns_resolution_mode`/`preset_dns_service`/`bootstrap_custom_json`；而 `ResolutionSettingsStore.kt:107-121` 等实际经 `datasetPrefs` 按数据集分文件存储（`RuleDataset.kt:24-28`：NORMAL=dns_vpn_prefs，EXPRESS=diting_express_prefs，DNS_MODE=diting_dns_mode_prefs）。NORMAL 恰好同文件被覆盖，Express/DNS_MODE 的损坏值不会被清理。
- 未升级为缺陷：读取端本身安全（`getDnsResolutionMode` 对非法值 `?: SINGLE`，`getModeProviderIds` JSON 解析失败回落默认集），损坏值不致崩溃或错误行为，仅错过「修复落盘」的机会。确认方法：向 `diting_express_prefs` 注入非 JSON 的 `parallel_race_provider_ids`，跑自检后读回仍为损坏值（但功能已由 getter 兜底）。

### O-101 迁移 SQL 的 `DEFAULT` 与实体声明漂移（Room 容忍，非缺陷，仅规范卫生）
- `MIGRATION_1_2`/`DNS_RULES_MIGRATION_1_2` 建表带 `enabled INTEGER NOT NULL DEFAULT 1`（`AppDatabase.kt:56`、`DnsRulesDatabase.kt:49`，含 `cosmetic_rule_source` 的 `:66`/`:59`），`MIGRATION_2_3`/`EXPRESS_MIGRATION_1_2` 的 ALTER 带 `isException ... DEFAULT 0`（`AppDatabase.kt:79` 等）；而实体列均无 `@ColumnInfo(defaultValue)`（`CosmeticRuleEntity.kt:28-29`、`CosmeticRuleSourceEntity.kt:17`）。
- 曾疑为升级崩溃缺陷；回读 `room-runtime 2.7.0` 的 `TableInfoKt.equalsCommon` 后确认：ENTITY↔DATABASE 方向的默认值比较仅在**实体侧默认值非空**时才执行，实体侧为 null 即跳过，因此该漂移被 Room 容忍，校验通过。对照 `DnsCacheEntity.kt:25` 显式 `@ColumnInfo(defaultValue="0")` 的写法可知：若要消除漂移需给实体补对应 `defaultValue`，但当前不补亦不影响正确性。纯卫生项。

### O-102 `RuleOperationWorker.importCategorizedRules` 硬编码 `AppDatabase.getInstance`
- `RuleOperationWorker.kt:411` 取 `AppDatabase`，而 worker 其余部件按 `KEY_DATASET` 路由（`:145-151`）；`IMPORT_RULES`/`IMPORT_HOSTS_RULES` 的唯一入队点（`RuleManagementViewModel.kt:84,166`）未传 dataset（默认 NORMAL），当前不可达错位；若未来任何入口以 DNS_MODE/EXPRESS 入队这两类任务，URL/元素隐藏规则将写进普通模式库。设计耦合，暂列观察。

### O-103 `refreshRuntimeConfig` 失败分支提交的 `activeResolutionMode` 与 Go 侧不一致
- `normal/DnsVpnRuntimeConfigManager.kt:137-161`：`resolveDnsProviders` onFailure 时向 Go 回写 `providers=oldProviders` + `resolutionMode=activeResolutionMode(旧值)`（`:142`），但 Kotlin 随后仍提交 `activeResolutionMode=newResolutionMode`（`:153`）；成功分支对 `goSyncError != null` 会提前 `return@fold`（`:127`）保持两侧一致，失败分支不对称，可能留下「新档位 + 旧上游」组合显示在前台通知。
- 未升级为缺陷：`DnsVpnProviderResolver.resolveDnsProviders` 的兜底路径（`:71` `listOf(DnsProvider.loadSelected(context))`）实测难以抛错，未构造出确定性触发。确认方法：构造使 `resolveDnsProviders` 抛异常的配置（损坏的持久化上游设置），切换多上游档位后比对 Go 配置与 Kotlin 状态。

### O-104 start/stop 微秒级交错可能在 Kotlin 判定停止后遗留运行中的 Go TUN 栈
- `normal/GoInspectionTunnel.kt:91-99`：`start()` 在 `scope.launch(Dispatchers.IO){ engine.startFull(...) }` 后立即返回 true，不确认 `startFull` 已进入；若 `stop()`（`:101-107`，`engine.stop()`）在 IO 协程到达 Go `StartFull` 的 `e.mu.Lock()`（`tunnel/engine_full_tunnel.go:92`）之前执行，Stop 见 `running=false` 直接返回，随后 StartFull 置 `running=true` 并新建 done channel，无人再持有。
- 未升级原因：需要极快的 ACTION_STOP 或 IO 池饥饿才能命中，且 Kotlin 侧 `startJob?.cancel()` 若在 `startFull` 启动前生效可避免；无确定性触发。确认方法：start/stop 微压力测试轮询 `Engine.IsRunning()`。

### O-105 原生崩溃批量收集的文件名用写入时刻（ms），同毫秒可覆盖丢一份- `crash/CrashLogManager.kt:53-54`：`saveCrashReport` 文件名 `crash_<yyyyMMdd_HHmmss_SSS>.log` 取的是**写入时** `Date()`，非崩溃标识；`checkAndCollectNativeCrashes` 在 `:320-341` 一个紧循环里最多迭代 10 条历史 `REASON_CRASH_NATIVE` 逐一落盘。两次迭代落入同一毫秒时，`FileOutputStream(file)` 截断覆盖前一份，历史原生崩溃静默丢失（现象：导出报告数少于待收集条数）。
- 未升级为缺陷：每次迭代含 `fos.fd.sync()` 与 `pruneOldLogs` 的 `listFiles`+排序，真机通常 >1ms，需多条待收集原生崩溃且存储极快才命中。确认方法：预置两条同 `timestamp` 的 `ApplicationExitInfo`，观察只落一份文件。修复方向：文件名追加 `index`/`pid`/`exitInfo` 指纹或用存在即改名的去重。
- 附带（非缺陷）：`CrashLogManager.kt:256-257` 的 `contains(X) || contains(X)` 两侧操作数相同，为无害复制粘贴；原生头 `DITING NATIVE CRASH REPORT` 不含 Java 子串 `DITING CRASH REPORT`，类型判定仍正确。
