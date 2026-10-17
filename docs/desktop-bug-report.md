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
| A-017 | 中 | Go 引擎生命周期 | `dnsCache` 清理协程无停止路径，且 CA 管理器每次调用新建一个 `Engine` 且从不 `Stop()`：每次证书校验/导出泄漏一个后台 ticker 协程与全套缓存内存 | 待处理 |
| A-018 | 中高 | Go 引擎并发 | `SetBlockResponseType`/`SetDomainChecker` 等 setter 不加锁写 `Engine` 字段，服务中的查询协程同样不加锁读；`e.mu` 不构成 happens-before → 数据竞争（可撕裂接口值/读到旧响应类型） | 待处理 |
| A-019 | 中 | Go DNS | UDP 上游响应从不检查 TC（截断）位、无 TCP 重试，截断响应被原样转发且写入缓存，客户端 TCP 重试命中同一份截断缓存，高记录数域名在 TTL 内持续返回残缺答案 | 待处理 |
| A-020 | 高 | DNS 模式总开关 | 「启用域名过滤」在 DNS 模式完全失效：standalone 服务路径从不读取 `filterDNS`，且 `DnsQueryFilter` 的策略提供器硬编码恒真，关闭开关后 LAN 查询仍被拦截 | 待处理 |
| A-021 | 高 | DNS 模式生命周期 | ACTION_STOP 与启动协程竞态：`engine.start()` 阻塞段无取消点，销毁后仍回填 `dnsServerEngine` 并置 RUNNING → 孤儿引擎继续占端口应答，UI 显示停止，再启动报「端口可能被占用」直至杀进程 | 待处理 |
| A-022 | 中高 | DNS 模式端口 | `loadConfig` 每次读取都把 5353/5354 强制改写为 1053（非一次性迁移），验证器与 UI 却允许保存 5353；重启或切换开关后端静默漂移并持久化 1053 | 待处理 |
| A-023 | 中 | DNS 模式动态拦截 | DNS 模式 `applyDnsConfig` 的 JSON 从未包含 `dynamicResponse` 键，Go 侧零值即禁用：动态拦截策略在该模式是死功能，UI 副标题却宣称生效 | 待处理 |
| A-024 | 中 | DNS 模式启动窗口 | STARTING 窗口内的配置/上游修改被丢弃：引擎用启动瞬间的快照绑定，`refreshEngineIfRunning` 只认 RUNNING，完成后不再回读 | 待处理 |
| A-025 | 高 | 配置导入 | 未勾选「禁止联网名单」导出的备份再导入，会把本地已开启的禁止联网总开关静默关闭（`optBoolean` 缺省 false + 不等即写） | 待处理 |
| A-026 | 中高 | 配置导出 | 出站代理用户名/密码在加密存储的前提下被解密后明文写入导出 JSON，凭据随备份文件外泄 | 待处理 |
| A-027 | 中 | 配置往返 | `latencyTestProviderRefs` 被导出、被解析进 DTO，但任何导入器都不应用它：测速节点选择迁移后静默丢失 | 待处理 |
| A-028 | 中 | 批量添加 | 批量导入丢弃 `appInverted`（分类模型无字段、校验/提交硬编码 false），`~app=` 排除规则的 enforcement 方向被反转 | 待处理 |
| A-029 | 中 | 批量添加 | 批量 URL 规则绕过 `GoUrlRuleManager.parse` 归一化直接存原文：含查询串/大小写主机的批量规则永不匹配或产生重复行 | 待处理 |
| A-030 | 中 | 规则导入 | `CategorizedRuleStreamImporter` 的 `kind` 参数从未参与过滤，`typeSkipped` 无任何写入点：类型不符文件被六表全量摄入，「没有${kind}规则，请确认导入类型」分支永不可达 | 待处理 |
| A-031 | 中 | 规则缓存 | `AllowRuleCache.reloadCustomRules` 仅按 pattern 去重订阅 special 规则（模型缺 `source`），与自定义同 pattern 的订阅修饰规则在每次白名单编辑后被逐出活动缓存，至下次全量 reload 才恢复 | 待处理 |
| A-032 | 高 | AI 密钥存储 | API 24/25（Express 模式唯一可达设备）上 `KeyObfuscator` 调 `java.util.Base64`（API 26+，未开 desugaring）→ 保存/查看 AI 密钥必崩 `NoClassDefFoundError` | 待处理 |
| A-033 | 中高 | QS 磁贴 | 磁贴启停 VPN/DNS 服务不走 `unlockAndRun`，安全锁屏下可直接启停服务与局域网 DNS 服务器（仅打开主界面路径做了锁检查） | 待处理 |
| A-034 | 中 | 通知渠道 | 「规则导入与更新」存在两个同名 channel：注册表 `diting_rule_operations_channel` 只被死代码 `RuleUpdateNotifier` 引用，实际通知走 Worker 硬编码的 `rule_operations`；系统设置出现两条同名通道，静音可能落错通道 | 待处理 |
| A-035 | 中 | 配置导入 | 通知栏自定义文案要求运行/停止两条**都**非空才写入：只填一条（UI 明示合法）导出后导入，已填的一条也静默丢失；且「清空文案」永远无法经导入传播 | 待处理 |
| A-036 | 低 | 通知设置入口 | `openNotificationSettings` 用 API 26+ 的 `ACTION_APP_NOTIFICATION_SETTINGS` 且 `runCatching` 吞异常：Android 7.x（Express 模式 minSdk 24 可达）点「系统通知权限」毫无反应 | 待处理 |
| A-037 | 低 | 应用内语言 | 磁贴标签/常驻监控通知/规则渠道名用未包装 context 的 `getString`（跟随系统语言），同屏其它文案走 `localizedText`（应用内语言）：中英混杂 | 待处理 |

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
  - 仅影响建立时刻：`hasPhysicalIpv6Support` 只在 `establishVpnInterface`（`Ipv6Mode.AUTO` 分支）调用一次，会话期间物理网络变化不会重新评估（`DnsVpnNetworkMonitor.scheduleIpv6AdaptationCheck` 只回调 `onNetworkChanged`，而该回调在 `DnsVpnService.kt:57` 构造时未赋值即为 null）。因此错误的 IPv6 启用状态在整个 VPN 会话内保持，直至重连。
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

## A-017 `dnsCache` 清理协程无停止路径 + CA 管理器按调用新建 `Engine`，每次证书校验泄漏一个常驻 goroutine 与缓存对象图

- **位置**
  - `Android/tunnel/dns_cache_policy.go:95-108` — `startCleaner()` 启动 `go func(){ for { select { case <-c.stopCleaner: …; case now := <-ticker.C: c.cleanupExpired(now) } } }()`（30s ticker），唯一退出通道是 `c.stopCleaner`
  - `Android/tunnel/dns_cache.go:66` — `newDNSCache()` 内即调用 `cache.startCleaner()`；`:101` `func (c *dnsCache) close()` 关闭 `stopCleaner`，**但全仓 `close()` 的调用方只有 `dns_cache_test.go`（5 处），生产代码零调用**
  - `Android/tunnel/engine.go:120-134` — `NewEngine()` 固定 `dnsCache: newDNSCache(...)`；`Stop()`（`:209-329`）逐项拆解 interceptor/router/tunFile/flowOutbound/standalone servers/blooms/logAggregator/trafficTracker/policyEngine —— **没有 `dnsCache` 一行**（逐行 grep 确认）
  - `Android/app/src/main/java/com/haoze/diting/core/cert/GoInspectionCaManager.kt:18-24` — `certificatePem()` 每次调用 `val engine = Engine()`，只 `startStackMitm`/`stopStackMitm`，从不调 `engine.stop()`；`fingerprintSha256`/`isInstalled`/`exportCertificateToUri` 全部经由它
  - `Android/tunnel/engine_mitm.go:44-49` — `StopStackMitm()` 仅置空 `stackCertMgr`/`stackMitmFilter` 两字段，无任何缓存/协程回收
- **机制**
  - 每构造一个 `Engine`（含仅取一次证书 PEM 的临时 Engine），其 `dnsCache` 的 cleaner goroutine 就永久存活：`select` 只在 `stopCleaner` 关闭时退出，而生产路径无人能关闭它；goroutine 引用 → `dnsCache`（64 个分片 map、flight map、entry 对象）永远不可 GC。
  - `Engine.Stop()` 也不回收，意味着**即使是正常跑完的 VPN 会话**，每启动一次也滞留一个 cleaner goroutine + 缓存对象图（Go 绑定对象本身可被 GC，但 goroutine 持有 `stopCleaner`/`ticker.C` 通道与 `c`，整个 `dnsCache` 逃逸于 GC）。
  - CA 场景放大：`isInstalled` 的调用面 —— `normal/DnsVpnTunnelManager.kt:58-64`（`verifyHttpsInspectionCertificateAsync`，VPN 启动/配置刷新时异步校验证书）、`CaCertificateSettingsScreen.kt` 的界面状态检查与导出/指纹路径。每次调用 = 一个 `newDNSCache` = 一个永不退出的 goroutine + 每 30 秒一次的空转唤醒。
- **用户可见影响**
  - 长时间保持 VPN 运行、频繁进入证书设置页/触发证书校验的设备：goroutine 数与常驻内存随调用次数线性增长（每千次约 1000 个空转 timer goroutine）；30s 周期唤醒对功耗有轻微持续影响。单进程寿命内不至于 OOM，但属于「可验证的无界泄漏」。
- **触发路径**
  1. 打开 CA 证书设置页并反复点「检查是否已安装」N 次（或反复重启 VPN）。
  2. 观察 Go 侧运行时统计。
- **复现/验证**
  1. 静态：`grep -rn "dnsCache" tunnel/engine.go` 确认 `Stop()` 无 `dnsCache` 回收；`grep -rn "\.close()" tunnel/*.go`（排除 _test）无 dnsCache 命中。
  2. 运行取证：在 Go 单测或临时调试构建里循环调用 `NewEngine()` N 次后 `runtime.NumGoroutine()` 断言增量 ≈ N（当前实现如此）；修复方向：`Engine.Stop()` 调用 `e.dnsCache.close()`，`GoInspectionCaManager.certificatePem` 复用单例引擎或改用不建缓存的轻量入口（`startStackMitm` 本身并不使用 `dnsCache`）。
- **备注**：修复必须同时处理「Stop 不回收」与「CA 管理器按调用 new Engine」两处；只改其一仍留另一半泄漏面。

---

## A-018 引擎 setter 与查询协程对同一字段均不加锁：`e.mu` 不建立 happens-before，构成数据竞争

- **位置**
  - 写侧（无锁）：`Android/tunnel/engine_config.go:47-49` `SetDomainChecker`（`e.domainChecker = checker`）、`:273-287` `SetFirewallChecker`/`SetAppResolver`/`SetAppUidResolver`/`SetLogCallback` 全部裸赋值；`:385-387` `SetBlockResponseType`（`e.responseType = ParseResponseType(responseType)`）
  - 写侧（持锁对照，证明字段语义上属于 `e.mu` 域）：`Android/tunnel/dns_config.go:133-136` — `applyDNSConfig` 写同一 `e.responseType` 时是 `e.mu.Lock()` … `Unlock()`
  - 读侧：`Android/tunnel/engine_dns.go:260`、`:280` `switch e.responseType`（查询处理协程内，**无锁**）；`engine_standalone.go:247-249` 的读在 `e.mu.Lock()` 内（有锁侧）。接口字段两侧均无锁：`e.domainChecker` 写于 `engine_config.go:47-49`（无锁），读于 `engine_standalone.go:158-159`、`:176-177` 与 `engine_dns.go:106-107`（均无锁）——这是可撕裂 2 字接口值的最实证的一对。
  - 字段声明：`Android/tunnel/engine.go:45` — `responseType ResponseType`（普通 int，非 atomic）；接口字段同为普通字段
  - 并发运行时可达性：`Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:95-105` — `syncRules()` 在引擎**已服务**期间调用 `engine.setRewriteRules(...)`、`engine.setBlockResponseType(...)`；触发源 `DnsModeService.kt:159-171`（`ACTION_REFRESH` → `refreshDnsEngine()` → `syncRules()`）：用户在 DNS 模式运行中改一条规则即命中
- **机制**
  - Go 内存模型：`responseType` 的无锁写（`SetBlockResponseType`）与无锁读（engine_dns 两处）之间没有任何同步边；同时它与 `ApplyDNSConfig`/`Start` 的持锁写互相竞争（一方不持锁即破坏互斥语义），`e.mu` 对该字段不构成 happens-before。接口字段（双 2 字：类型指针+数据指针）写读两侧均无锁，可能观察到不配对的两半，一旦发生即调度进错误的 Kotlin 回调对象或崩溃；至少 `go test -race` 会判 UB。
  - 与 Express/VPN 启动路径不同：那条链路 setter 都在 `startFull` 之前完成（`GoInspectionTunnel.kt:91-99` 先 `configureEngine` 后 launch），不构成竞争；本条的竞争窗口在 **DNS 模式运行中刷新**（`syncRules` 与 serve goroutine 并发）与 `DnsServerEngine.applyDnsConfig`（`:214` `engine.applyDNSConfig(json)` 运行中调用）。
- **用户可见影响**
  - 概率性、非确定：表现为 DNS 模式改规则/改封锁响应类型瞬间偶发错误响应类型（如设 NXDOMAIN 却回 0.0.0.0）、回调串线或（接口撕裂时）进程崩溃。静态上这是对共享字段的未同步并发读写，属必须修的缺陷类别。
- **复现/验证**
  1. `cd Android/tunnel && go test -race ./...` 配一个并发压测：一个 goroutine 循环 `SetBlockResponseType`，另一路查询流量（本机 `go1.27.2` 可跑；现有测试不覆盖该并发，当前套件绿不代表安全）。
  2. 静态核对：`e.responseType` 的全部读点（engine_dns.go:260/280、engine_standalone.go:248）与 `SetBlockResponseType` 写点（engine_config.go:385）均不在 `e.mu` 临界区。
- **备注**
  - 修复方向：把 `responseType` 改为 `atomic.Int32`（或全部读写统一进 `e.mu`）；`domainChecker` 等接口字段统一 `atomic.Value`/带锁 getter 快照（项目经验教训「长生命周期对象不得按值捕获会被热替换的字段」同源）。`SetBlockResponseType` 至少应像 `dns_config.go:133` 一样持锁。

---

## A-019 UDP 上游截断（TC=1）响应既不重试 TCP 也不拒缓存：客户端 TCP 重试命中同一截断缓存，残缺答案在 TTL 内固化

- **位置**
  - `Android/tunnel/resolver_plain.go:70-107` — `queryPlainContext` UDP 读 `buf := make([]byte, 4096)`，`return buf[:n]` 前无任何 TC 检查/转 TCP；全包 `grep Truncated` 零命中（非 _test）
  - 对照组（证明并非无人手滑）：`Android/app/src/main/java/com/haoze/diting/express/transport/ExpressPlainDnsTransport.kt:48-52`（Kotlin Express 路径）**有**截断转 TCP 逻辑 `if (ExpressDnsMessageUtils.isTruncatedResponse(response)) { queryTcp(...) }` —— 同功能在 Go 主 VPN 路径缺失
  - `Android/tunnel/dns_cache.go:242-278` — `putMsg` 仅按 rcode/answer 数/TTL 决定入库，从不看 `respMsg.Truncated`；`dns_cache_flight.go:74-79` 把原样响应喂进 `put`
  - `Android/tunnel/engine_standalone.go:295-304` — 命中缓存后 `w.Write(cachedResp)` 原样回给客户端（含 TC=1）
- **机制**
  1. 上游对大应答（多记录 CDN、DNSSEC、长 TXT）置 TC=1 截断 UDP 返回（默认 512B 截断，Go 查询未带 EDNS0 bufsize —— 全包 `grep Edns0` 零命中）。
  2. 引擎不重试 TCP，把截断响应返回客户端并缓存。
  3. 解析器客户端（Android bionic/Chrome）见 TC=1 按 RFC 5966 走 **TCP** 重查同一问题 → `serveDNS`（TCP 也进同一函数）→ `dnsCache.getFast` 命中刚存的**截断 UDP 报文** → 回写残缺答案，且 TCP 通道本可拿全量也被截断缓存短路。
  4. TTL 内每次查询（UDP 直接命中缓存、TCP 命中截断缓存）都拿不到完整记录集。
- **用户可见影响**
  - 记录数多的域名（大型 CDN 轮换、DNSSEC 签名区）在 VPN/DNS 模式下间歇性解析不全：连接变慢（客户端耗尽残缺列表后重查）、多栈偏好下 IPv6 记录恰好被截掉时回退 v4 甚至失败。日志表现为同一域名反复「解析成功但连接异常」。
- **触发路径**
  1. VPN 或 DNS 模式运行，上游选普通 53 端口 UDP。
  2. 查询一个应答 >512B 且上游未启 EDNS0 的域名（如部分 DNSSEC 签名域的 ANY/TXT，或多记录 CDN 域）。
  3. `dig +tcp @<手机> <域名>` 与 `dig +udp` 对比：TCP 本应拿全量，实际两者都返回同一份 TC=1 截断结果。
- **复现/验证**
  1. 静态：resolver_plain.go 无 TC 分支、无 `queryPlainTCPContext` 的截断后调用（`:47` 那处调用是显式 `forceTCP` 策略路径，非 TC 触发）；`putMsg`/`getFast` 路径无 `Truncated` 判断。
  2. 运行：`go test` 构造 TC=1 假上游，断言 (a) resolver 应转 TCP 重查（当前不转）；(b) `putMsg` 应拒收截断报文（当前入库）。
- **备注**
  - 修复方向（任一即可断链，建议双做）：`queryPlainContext` 读包后 `msg.Header.Truncated` 为真时走 `queryPlainTCPContext`；`putMsg` 对 `respMsg.Truncated` 直接返回 false 不缓存。Express Kotlin 侧已有正确实现可作语义参照。

---

## A-020 DNS 模式「启用域名过滤」总开关完全失效：standalone 路径从不读取 `filterDNS`，快照 `filterEnabled` 恒真

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:69,88,130`（`engine.setFilterDNS(config.adBlockEnabled)`，值经 `engine_config.go:67` `e.filterDNS.Store(enabled)` 存入 Go）
  - `Android/tunnel/engine_standalone.go` — 全文件 `grep -c filterDNS` = **0**：standalone 的 `serveDNS`（`:147`）在 `policyEngine.isActive() && hasRules()` 时直接评估拦截，从不查询 `e.filterDNS`
  - 对照 VPN 路径确实有闸门：`Android/tunnel/engine_dns.go:83-86` `if !e.filterDNS.Load() { e.handleForward(...) }`
  - 两道后备闸门同时失效：
    - 快照 `filterEnabled`：`core/rule/DomainPolicyEngine.kt:120` `root.put("filterEnabled", isEnabledProvider())`；而 DNS 模式构造点 `server/backend/DnsQueryFilter.kt:57` `DomainPolicy(allowListManager, blockListManager)` **未传提供器**，落入默认值 `DomainPolicyEngine.kt:41` `{ true }`（对照普通模式 `normal/DnsVpnDatabaseComponents.kt:93` 传 `{ isDomainRulesEnabled() }`）→ Go `policy_snapshot.go:147` `if s == nil || !s.filterEnabled` 永不触发
    - Kotlin `DomainChecker` 回调（`DnsServerEngine.kt:106-134`）调用同一恒真策略
  - UI 承诺：`normal/ui/RuleControlScreen.kt:126-128`（DNS dataset 经 `server/ui/DnsSettingsScreen.kt:89` 进入）关闭时显示「已关闭恶意域名过滤，查询将直接放行」；`ui/settings/RuleSettingsAccess.kt:23,30-33` 读写 `DnsModeConfig.adBlockEnabled`
- **问题**：DNS 模式下把总开关拨到关，prefs、StateFlow、Go `filterDNS` 三层都正确置了关，但第四层（真正做拦截决策的 standalone 评估路径）不看任何一层开关，规则继续拦截。
- **用户可见影响**：局域网客户端经手机 DNS 解析被拦截域名仍返回 NXDOMAIN/REFUSED/0.0.0.0，与 UI 明示的「直接放行」相反；用户无法在不删规则的前提下临时停用过滤。
- **触发路径**：DNS 模式添加 `||example.org^` → 运行 → 规则控制关闭「启用域名过滤」→ LAN 客户端 `dig @手机 example.org` → 仍被拦截。
- **复现/验证**：静态核对上述 grep 计数；或给 `DnsServerEngine` 增加断言：`adBlockEnabled=false` 时 `buildRuleSnapshotJson()` 的 `filterEnabled` 应为 false（当前恒 true）。
- **备注**：修复需两处任选其一并保持 VPN/DNS 语义一致——`DnsQueryFilter` 构造 `DomainPolicy` 时传入 `{ DnsModeManager.config.value.adBlockEnabled }`（走快照闸门），或 Go `serveDNS` 增加 `e.filterDNS.Load()` 检查（与 `engine_dns.go:83` 对齐）。

---

## A-021 DNS 模式停止/启动竞态：`engine.start()` 无取消点，销毁后回填引擎并置 RUNNING，孤儿引擎霸占端口直到进程死亡

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModeService.kt:111-152` — `startDnsEngine()` 协程：`:117` `loadRules(filter)`（挂起点）→ `:139` `engine.start()`（阻塞 bind，**无挂起点**）→ `:140` `dnsServerEngine = engine` → `:143` `DnsModeManager.onServiceStarted()`
  - `:89-99` `onDestroy()`：`startJob?.cancel()`、`stopDnsEngine()`（`:187-190`，此时 `dnsServerEngine` 仍为 null——仅在 `:140` 赋值）、`onServiceStopped()`
  - `server/backend/DnsModeManager.kt:88-103` `stopService()` 仅拦截 STOPPED/STOPPING，**STARTING 状态可以停止**；`:115-118` `onServiceStarted()` 无条件置 RUNNING；`:130-135` `onServiceError()` 无条件覆盖状态
  - 停止入口：通知「停止」按钮（`DnsModeService.kt:262-270` `ACTION_STOP` PendingIntent → `onStartCommand:52-55` `stopSelf()`）或模式切换（`core/WorkModeLifecycleRegistry` → `DnsModeManager.stopService`）
  - 端口占用错误面：`DnsModeService.kt:146-150` `start()` 失败 → ERROR「DNS 服务启动失败，监听端口可能被占用」；Go bind 失败点 `tunnel/engine_standalone.go:444-451`
- **机制**（两条交错均有实证）
  1. **孤儿引擎**：取消是协作式的；协程在 `:139` 的 gomobile 阻塞调用内，`cancel()` 无效，恢复执行后把引擎赋给**已销毁服务实例**的字段并置 RUNNING。此后：LAN 查询照常应答（端口仍被持有），UI 已显示停止；再点启动 → 新 `Engine` bind 同端口失败 → 永久 ERROR，直至杀进程。
  2. **停止被误报为失败**：取消落在 `:117` `loadRules` 挂起点时，`runCatching`（`:182-185`）会把 `CancellationException` 一并吞掉 → `loadRules` 返回 false → `:118` `onServiceError("DNS 规则加载失败，请重试")`，且 `onServiceError` 无条件覆盖 `onDestroy` 刚设的 STOPPED——用户主动停止却看到红色失败卡片。
- **触发路径**：导入大订阅（`reloadSync` 耗时数秒）→ DNS 模式点启动 → 加载期间点通知「停止」（或切换工作模式）→ 观察：UI 停止但 `adb shell ss -ulpn | grep 1053` 仍有 socket；重新点启动报端口占用。
- **复现/验证**：`:139` 之后加 `currentCoroutineContext().isActive` 检查即可消除交错 1；`loadRules` 改为 `runCatching` 前单独放行 `CancellationException`（`if (e is CancellationException) throw e`）消除交错 2。
- **备注**：`refreshDnsEngine()`（`:159-174`）同样在 `loadRules` 后直接取 `dnsServerEngine`，服务销毁竞态同型，修复时一并覆盖。

---

## A-022 DNS 模式端口 5353/5354 在每次 `loadConfig` 被强制改写为 1053（迁移逻辑常驻化），与验证器/UI 承诺矛盾且会持久化

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModePreferences.kt:41-42` — `val rawPort = prefs.getInt(KEY_LOCAL_PORT, 1053); val port = if (rawPort == 5353 || rawPort == 5354) 1053 else rawPort`（无任何一次性迁移标志守护；同文件 `:46-51` 的 `logQueries` 迁移恰恰示范了正确写法——用 `KEY_LOG_QUERIES_MIGRATED` 只迁一次）
  - `server/model/DnsListenPortValidator.kt:10-17` — 允许 1024–65535 全区间（含 5353/5354）；`server/ui/DnsPortEditDialog.kt:35-41` 校验通过即原样保存；测试 `app/src/test/.../DnsModeTest.kt:310` 断言 `validate("5353")` 通过
  - 全仓 `grep 5353` 除测试外仅此一处：UI 没有任何「5353/5354 不可用」提示
  - 持久化路径：`ui/settings/RuleSettingsAccess.kt:30-33` 以 `loadConfig().copy(...)` 重建整份配置 → `DnsModeManager.updateConfig`（`server/backend/DnsModeManager.kt:196-200`）→ `DnsModePreferences.saveConfig`（`:65-69`）把改写后的 1053 **写回 prefs**；随后 `refreshEngineIfRunning` → `DnsServerEngine.updateConfig` `:73-77` 检出 `portChanged` → `stop(); start()` 实际改绑
- **问题**：本应只作用于历史安装的一次性迁移每次读取都执行；用户显式选择 5353 合法且可保存，但 (a) 拨动「启用域名过滤」等任何经 `RuleSettingsAccess` 全量重建配置的写操作，(b) 每次重启/START_STICKY 重建（`DnsModeService.kt:46` → `DnsModeManager.initialize` → `loadConfig`），端口都会静默变为 1053，且 (a) 还会把 1053 持久化，用户选择被销毁。
- **用户可见影响**：手动把 LAN 设备 DNS 指到手机:5353 的用户，在重启手机或切换过滤开关后解析全部超时（服务已在 1053）；设置页此后显示的也是 1053。
- **触发路径**：端口设为 5353 → 运行 → 规则控制拨一次总开关 → `adb shell ss -ulpn` 见监听 1053，prefs `local_listen_port`=1053。
- **复现/验证**：单测：`saveConfig(port=5353)` 后 `loadConfig().localListenPort` 应为 5353，当前返回 1053；或按上述真机步骤。
- **备注**：修复方向——迁移加一次性标志（仿 `KEY_LOG_QUERIES_MIGRATED`），或从验证器同步禁掉 5353/5354 并在迁移后清除；两处必须口径一致。

---

## A-023 DNS 模式动态拦截策略从未下发：`applyDnsConfig` JSON 缺 `dynamicResponse` 键，Go 零值即禁用

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:165-211` — `applyDnsConfig()` 仅写 `mode/blockResponse/cache/providers/bootstrap`，**无 `dynamicResponse`**
  - 对照普通模式有该键：`normal/HttpsDnsConfigSnapshot.kt:51-55`
  - Go 侧解析：`tunnel/dns_config.go:36` `DynamicResponse dynamicBlockConfig json:"dynamicResponse"`，`:110` `DisallowUnknownFields()`（键名不可能拼错，是根本没发）；缺省 → 零值 → `Enabled=false` → `dns_config.go:58-60` `responseFor` 恒返回静态响应；`engine_standalone.go:251` 的调用因此永远是直通
  - 存储与 UI 全链路都在：`server/backend/DnsRuleSettings.kt:37`（prefs 读取）→ `ui/settings/RuleSettingsAccess.kt:67-74` → `normal/ui/RuleControlScreen.kt:170-177` 副标题「动态策略：先 NODATA，高频请求后 NXDOMAIN」→ `ui/BlockResponseSettingsScreen.kt:52-55` 保存并 `refreshIfRunning`
  - `server/backend` 内 `dynamicBlockResponseConfig` 除 `RuleSettingsAccess` 外零读取（grep 实证）
- **问题**：用户在 DNS 模式开启动态拦截并设定阈值/窗口/时长，全部持久化成功，但引擎侧永远收不到，拦截响应始终静态。
- **用户可见影响**：UI 明示「动态策略」生效中，实际被拦截域名永远按固定 NXDOMAIN/0.0.0.0 应答，高频查询不再升级 NODATA→NXDOMAIN；功能是死的。
- **触发路径**：DNS 模式 → 规则控制 → 拦截响应 → 开动态、阈值 2 → LAN 客户端连续 >2 次查询被拦截域名 → 应答与阈值无关。
- **复现/验证**：在 `applyDnsConfig` 打印 JSON：无 `dynamicResponse`；或 Go 单测以该 JSON 调 `ApplyDNSConfig`，断言 `e.dynamicResponse.Enabled == false`。
- **备注**：`updateConfig` 的变更检测（`DnsServerEngine.kt:66-72`）也忽略动态配置，即使补发 JSON 还需把 `DnsRuleSettings.dynamicBlockResponseConfig` 纳入 `applyDnsConfig` 与变更触发。

---

## A-024 DNS 模式 STARTING 窗口内的配置/上游修改被丢弃：引擎以启动瞬间快照绑定，RUNNING 前的一切编辑不重放

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModeService.kt:111-114` — 协程开头一次性捕获 `config`/`upstream`；`:117` 挂起于 `loadRules`（大规则库时可达秒级）；`:125-137` 用**捕获值**构造 `DnsServerEngine`；`:139` bind
  - `server/backend/DnsModeManager.kt:137-142`（`selectUpstream`）/`:196-200`（`updateConfig`）→ `:202-208` `refreshEngineIfRunning`：`if (!_status.value.isRunning) return` — STARTING 不算 running，**不下发 ACTION_REFRESH**
  - `:115-118` `onServiceStarted()` 置 RUNNING 后没有任何重读 StateFlow/补发刷新的代码（`DnsModeService.kt:141-145` 直接结束）
- **问题**：启动加载期间在主线程改上游（如 Cloudflare → 自建 DoH）或改缓存预设/端口：`DnsModeManager` 的 StateFlow 与 prefs 已更新、UI 立即显示新选项，但引擎用旧快照 bind；RUNNING 后无人再对账。
- **用户可见影响**：服务器以旧上游解析（LAN 客户端拿到旧 DNS 的应答），设置页显示新上游——直到下一次任意设置变更（触发 ACTION_REFRESH）或重启服务才自愈；端口同窗修改还会出现 UI 显示 1053 实际监听旧端口。
- **触发路径**：导入数万条规则 → 点启动（进入 STARTING 转圈）→ 立即在服务器设置切换上游 → 启动完成 → `dig` 验证仍走旧上游。
- **复现/验证**：单测方向：以可延迟的 fake `reloadSync` 断言在 STARTING 中 `updateConfig` 后 `dnsServerEngine.config` 未变；或真机 logcat `applyDNSConfig provider id`。
- **备注**：修复可与 A-021 一并进行：`onServiceStarted()` 后比对 StateFlow 现值与引擎持有值，不一致则补发 `refreshDnsEngine()`；或把「捕获」改为 bind 前一刻重读。

---

## A-025 导入未勾选「禁止联网名单」的备份会静默关闭本机禁止联网总开关（缺省 false + 不等即写）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:272-276` — `blockedAppsEnabled` 仅在 `selection.blockedApps` 勾选时写出
  - `ui/transfer/ConfigTransferParser.kt:236` — `root.optBoolean("blockedAppsEnabled", false)`：键缺失 → `false`
  - `ui/transfer/TransferConfigDto.kt:38` — `val blockedAppsEnabled: Boolean = false`（非空，缺失与关闭不可区分）
  - `ui/transfer/AppRuleConfigImporter.kt:59-64` — `if (isBlockedAppsEnabled(context) != config.blockedAppsEnabled) setBlockedAppsEnabled(...)`：不等即写 → 本机开(→文件缺省关) 时被关闭
  - 同族对照（作者明知该模式的反证）：`ConfigTransferParser.kt:277-279,291` `domainRulesEnabled/addressRulesEnabled/encryptedDnsBlockingEnabled/allowEditDefaultWhitelist` 全部按 `if (root.has(...)) … else null` 解析为**可空**，缺失=不改；`AppRuleConfigImporter.kt:109` `appAllowlistEnabled` 亦只做 truthy 开启不做关闭。`blockedAppsEnabled` 是唯一「硬 false 缺省 + 不等即写」的主开关。
  - 旁证：`express/config/ExpressConfigAdapter.kt:60-66` 注释明确「为避免改动用户既有的禁止联网偏好」而在 Express 侧对齐本地状态——NORMAL/DNS_MODE 导入路径没有这层防护。
- **用户可见影响**：用户刻意不勾选「禁止联网名单」做部分备份（`ui/transfer/ConfigTransferScreen.kt:226` 的正常选择）→ 在已开启禁止联网的设备上导入 → 总开关被静默关掉：名单还在，但所有被禁应用恢复联网；家长控制/管控语义直接失效。摘要仅显示一行「开关 -> 已禁用」的良性文案。
- **触发路径**：A 机开启禁止联网并加入若干应用 → 备份页取消勾选「禁止联网名单」→ 导出 JSON（确认文件无 `blockedAppsEnabled` 键）→ 导入该文件 → `AppRulesSettingsStore.isBlockedAppsEnabled` 变 false。
- **复现/验证**：Robolectric 单测：预置 `setBlockedAppsEnabled(true)`，导入 `{"formatVersion":9}` 最小文件，断言仍为 true（当前实现为 false）。
- **备注**：修复方向：解析改 `if (root.has(...)) … else null` + DTO 改 `Boolean?` + 导入器 null 时跳过；与兄弟开关口径统一。

---

## A-026 出站代理用户名/密码被解密后明文写入导出 JSON（加密存储承诺被导出环节降级）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/OutboundProxySettingsStore.kt:61-62,169-188` — 落盘经 `encryptProxySecret`（AES/GCM）刻意加密
  - `:44-45` — `getOutboundProxyConfig` 返回**解密后**的 username/password（并缓存明文 `cachedConfig`）
  - `ui/transfer/ConfigExporter.kt:131-140` — 导出直接 `put("username", proxyConfig.username)`、`put("password", proxyConfig.password)`，无掩码/无警告区分
  - `ui/transfer/ConfigTransferScreen.kt:266-268` — 仅提示「包含个人自定义设置，请妥善保管」，未说明凭据为明文
  - 往返本身正确（`NetworkFeatureConfigImporter.kt:87-98` 导入时重新加密），问题只在导出面
- **用户可见影响**：备份 `.json` 经微信/网盘/云备份流转时，任何拿到文件的人可直接读出代理账号密码——与「密钥加密存储」的设计承诺相悖；这是本模块中唯一把受保护秘密落到可分享介质的路径。
- **触发路径**：配置带认证的 SOCKS5/HTTP 出站代理 → 备份与迁移 → 勾选「出站代理」导出 → 打开 JSON 见 `"password": "<明文>"`。
- **复现/验证**：设置代理密码后导出，比对 JSON 值与 `getOutboundProxyConfig().password`（明文）而非 prefs 密文。
- **备注**：属安全缺陷而非功能缺陷；修复至少应 (a) 导出时显著警示含凭据、(b) 提供不含机密的导出选项，或 (c) 用用户口令对导出文件内凭据字段再信封加密。

---

## A-027 `latencyTestProviderRefs` 导出与解析齐备，但任何导入器都不应用：测速节点选择迁移后静默丢失

- **位置**
  - 写：`Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:96` `root.put("latencyTestProviderRefs", serializeProviderIds(ResolutionSettingsStore.getLatencyTestProviderIds(context, dataset)))`
  - 读：`ui/transfer/ConfigTransferParser.kt:83` 解析、`:348` 装入 DTO；`TransferConfigDto.kt:22` 字段存在
  - 消费缺失：`ui/transfer/ProviderConfigImporter.kt:57-125` 仅应用 selected/race/smartPrediction/parallelRace/primaryBackup 五族；全仓 grep `latencyTestProviderRefs` 无任何 importer 命中；写入 API `ResolutionSettingsStore.setLatencyTestProviderIds`（`ui/settings/ResolutionSettingsStore.kt:82`）在 transfer 包零调用
  - 该值真实在用：`ui/RaceModeSettingsViewModel.kt:114` 读取回显、`:145` 用户修改后保存
- **用户可见影响**：用户在测速设置选定的节点被写进备份、用户看得到它在文件里，导入后设置回到默认——「迁移不可靠」，且无错误提示。
- **触发路径**：选测速节点 → 导出 → 清数据/新机导入 → 重开测速设置：选择为空。
- **复现/验证**：导入含 `latencyTestProviderRefs: ["a","b"]` 的文件，比对 `getLatencyTestProviderIds` 前后不变（当前行为）。

---

## A-028 批量添加丢弃 `appInverted`：`~app=` 排除规则被反转为「仅这些应用」拦截，且与既有倒置规则产生重复行

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/batch/BatchRuleModels.kt` — `ClassifiedLine.Domain` 字段集为 pattern/isAllow/rawLine/appScope/important/isWildcard/denyallow/isRegex/dnsType，**无 appInverted**
  - `ui/batch/BatchRuleClassifier.kt:318-329,345-356,366-379` — 三个域规则分支构造 `ClassifiedLine.Domain(...)` 时均不传递 `parsed.appInverted`（`AdblockRuleLineParser.kt:70-95` 已解析出该值）
  - `ui/batch/BatchRuleValidator.kt:104` — 批内去重键 `"$prefix:pattern:important:appScope:dnsType:denyallow:isRegex"` 不含 appInverted；`:116,125` 存在性检查 `idByPattern(appInverted = false)`；`:293,315` 提交实体硬编码 `appInverted = false`
  - 对照单条路径保留：`ui/BlacklistViewModel.kt:396` `appInverted = ... parsed.appInverted`；UI 徽章 `normal/ui/AppRuleComponents.kt:248`；传输路径保留：`ConfigExporter.kt:201,213` 写出、`RuleConfigImporter.kt:138,165` 按 rawLine 重推导
  - 唯一索引含 appInverted：`data/entity/BlockRuleEntity.kt:20` → 强制 false 同时改变**存储身份**与**求值语义**（`BlockRuleMatcher.findInSpecialRules:216-224` 依据 appInverted 决定「除…之外」还是「仅…」）
- **用户可见影响**：批量粘贴 `||example.com^$app=~com.android.chrome`（除 Chrome 外都拦）→ 提交后规则变成「仅拦 Chrome」，方向反转；若已有真倒置规则，还会因 `idByPattern(false)` 查不到而**再插一条反语义行**；批内两条仅 `~` 不同的行第二条被误报「已存在」丢弃。
- **触发路径**：黑名单 → 批量添加 → 粘贴 `$app=~` 行 → 完成 → 列表详情查看：无 `~` 徽章、语义翻转。
- **复现/验证**：单测 `BatchRuleValidator` 提交后读回 `BlockRuleEntity.appInverted`，rawLine 含 `app=~` 时期望 true、实际 false。
- **备注**：修复需给 `ClassifiedLine.Domain` 补 `appInverted` 字段并贯通分类/去重键/存在性检查/提交四处；与 A-029 同一文件可一并处理。

---

## A-029 批量 URL 规则绕过归一化直接入库：大小写主机/查询串/默认端口导致永不匹配或重复行

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/batch/BatchRuleClassifier.kt:88-97` — 显式 `http(s)://` 行仅 `isValidUrl` 宽松校验（`BatchRewriteParser.kt:68-72`：前缀+长度+无空格），`urlPattern = cleaned` **原文**入批
  - `ui/batch/BatchRuleValidator.kt:330-354` — 提交 `GoUrlRuleEntity(pattern = item.urlPattern, ...)` 直接写库
  - 对照单条路径：`core/rule/GoUrlRuleManager.kt:14-21` `addRule` → `parse`（`:41-53`：scheme/host 小写、剥离 `:80/:443`、拒绝 `*`/`$`/userInfo/fragment、保留 rawPath）；`ui/BlacklistViewModel.kt:368`、`RuleConfigImporter.kt:232` 都走这条
  - 匹配端归一化：`tunnel/engine_request_filter.go:32` 规则串 `strings.ToLower(TrimSpace(Pattern))`、`:44,53` 实际请求按 `scheme://host+path`（**无查询段**）拼串比较
- **机制/影响**（三个后果，均可静态推断）
  1. 含查询串的批量规则（`https://a.com/x?y=1`）：Go 匹配串永不含 `?y=1` → **规则永不命中**，而列表显示与「成功导入 N 条」提示都声称已添加；单条路径同输入会拒绝或归一。
  2. 大写主机：Go 只小写规则串（`:32`），`HTTPS://A.COM/x` 批量入库后被小写化能匹配，但与对话框存储的 `https://a.com/x` 在唯一索引 `(pattern,kind)`（`GoUrlRuleEntity.kt:10`，存原文）下成为**两行重复**；批内去重 `idByPattern(raw)`（Validator `:171`）查询原文形态，与已存归形态互不可见。
  3. 显式默认端口 `https://a.com:443/x` 批量保留、单条剥除 → 同类分裂。
- **触发路径**：对话框添加 `https://a.com/x` → 批量添加 `HTTPS://a.com/x` → 地址规则列表出现两条同义规则；批量添加 `https://a.com/x?y=1` → 规则显示存在但请求永不拦截。
- **复现/验证**：单测对 `GoUrlRuleDao`：批量与单条各插一次同一 URL，`enabledRules()` 返回 2 行（当前实现）。
- **备注**：修复：Batch 提交前过 `GoUrlRuleManager.parse`，parse 失败的行按「无效」归类而不是原文入库（顺带把 `?query` 明确化为拒绝理由文案）。

---

## A-030 规则导入器 `kind` 参数从不参与过滤，`typeSkipped` 无写入点：类型不符文件被全类别摄入，专用报错分支永不可达

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/CategorizedRuleStreamImporter.kt:63` — `kind: String` 入参；函数体内 `kind` 无任何读取（`:127/:150` 的 `GoUrlRuleKind` 为无关常量）
  - `:89` — `var typeSkipped = 0` 声明；`:254` `if (parsedRules == 0) onEmpty(typeSkipped > 0)`、`:270` `typeSkippedCount = typeSkipped` 两处读取；全文件（含 `importTwoPass`）**没有写入点**（grep 实证）
  - `:199-252` — block/allow/rewrite/urlBlock/urlAllow/cosmetic 六类无条件收集、无条件 flush
  - `data/entity/SubscriptionEntity.kt:52-64` — `SubscriptionKind` 仅 DOMAIN/HOSTS 两值；hosts 类订阅有专用路径 `countHostsRules`/`importHostsRules`（`RuleOperationWorker.kt:355-365`，`HostsAndDnsmqParser` 只解析 hosts 行），该路径**正确**按类型过滤
  - 依赖不可达分支的调用方：`core/rule/RuleOperationWorker.kt:433-440` 与 `core/rule/SubscriptionManager.kt:270-278` 的 `onEmpty(typeMismatchOnly)` 均抛「文件中没有${displayName(kind)}，请确认导入类型是否正确」
- **机制/影响**：以 `kind=DOMAIN`（黑白名单）身份添加/导入一个纯 hosts 文件时，hosts 行被解析为 rewrite 规则**原样入库**并计入订阅规则数（删除/停用订阅会连带清掉这些 rewrite，`SubscriptionRuleStorage.removeRulesBySource` 全表清理，无孤儿）；反之域名文件以 HOSTS 订阅导入走 `importHostsRules`，`countHostsRules` 恒 0 触发的是通用的「没有可导入的有效规则」，也不是类型提示。两个用户后果：(1) 选错类型没有任何纠错提示，内容直接污染另一类规则集；(2) 代码里明确写好的「请确认导入类型」错误分支是死代码，测试即使覆盖 `onEmpty` 也只测到 false 分支。
- **触发路径**：添加订阅 → 类型选「黑白名单规则」→ 粘贴 `127.0.0.1 localhost` 类 hosts 文件 → 导入成功且「改写规则」列表新增条目。
- **复现/验证**：单测：`import(kind=DOMAIN)` 输入纯 hosts 行，期望 `rewriteCount == 0` 且 `typeSkippedCount > 0`、`onEmpty(true)`；实际 rewrite 全部入库、`onEmpty` 不触发。
- **备注**：修复方向：按 `kind` 跳过不匹配类别并计入 `typeSkipped`（同时确认产品预期是「报错拒导」还是「静默忽略」）；`parsedRules` 应只统计匹配类别，令 `onEmpty(typeMismatchOnly=true)` 可达。

---

## A-031 `AllowRuleCache.reloadCustomRules` 仅按 pattern 保活订阅 special 规则：与自定义同 pattern 的订阅修饰规则在每次白名单编辑后被逐出活动缓存

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/AllowRuleCache.kt:142` — `val subSpecial = state.specialRules.filter { sub -> !result.specialRules.any { it.pattern == sub.pattern } }`（比较仅 `pattern`）
  - `core/rule/AllowRuleModels.kt:41-50` — `ExportedSpecialAllowRule` 字段：pattern/important/appScope/appInverted/isWildcard/denyallow/isRegex/dnsType，**无 `source`**；对照 block 侧 `BlockRuleModels.kt:59-69` 有 `source`
  - `core/rule/BlockRuleCache.kt:184` — 块侧孪生用 `state.specialRules.filter { it.source.startsWith("sub_") }`（来源判定，pattern 冲突不误删）
  - 触发面（每次单条白名单变更都会调用）：`core/rule/AllowListManager.kt:195-196`（`syncCachedPattern` → `cache.reloadCustomRules(dao)`）；调用方含 `ui/WhitelistViewModel.kt:479,551,553`、`ui/batch/BatchRuleValidator.kt:326`、`normal/DnsVpnRuleSyncManager.kt:56`
  - `AllowRuleCacheLoader.kt:193` — 全量 `load` 的 `specialRules = customResult.specialRules + subSpecialRules` 正常合并：被逐出的规则在下次全量 reload 自动恢复，缺陷仅存于 `reloadCustomRules` 增量路径
  - 消费点：`core/rule/AllowRuleMatcher.findInSpecialRules:168-212` ← `findAppMatch:31`/`findGlobalMatch:52` ← `DomainPolicyEngine.evaluateInternal:88,94`（Go 回调线程实际命中）
- **机制/影响**：自定义 special `||ex.com^$denyallow=ok.com` 与订阅 special `||ex.com^$app=com.foo` 同 pattern 不同修饰。用户改动任意白名单条目 → `reloadCustomRules` 重拉 custom special → 订阅 special 因 pattern 相同被过滤丢弃 → 该订阅规则的 `$app` 放行作用在快照/回调匹配中消失（其 denyallow/appScope 差异不被考虑），误拦依赖该例外的域名；直到下次全量 reload 才自愈。块侧以 `source` 判定不受影响——缺陷是该文件特有的近似复制。
- **触发路径**：订阅含 `||ex.com^$app=com.foo`（special）→ 手动添加 `||ex.com^$denyallow=ok.com` → 随便编辑另一条白名单 → com.foo 对 ex.com 的放行不再命中（`adb` 日志/快照 JSON 中 `specialAllow` 少一条）。
- **复现/验证**：单测：state 预置两条同 pattern 特殊规则（一 useradd 一 sub_），调 `reloadCustomRules`（loader 只返回 useradd 那条），断言 `state.specialRules` 仍含 sub 条目；当前实现删除。
- **备注**：修复方向：给 `ExportedSpecialAllowRule` 补 `source` 与块侧对齐（推荐），或去重键改全字段比较。

---

## A-032 Android 7.0/7.1（API 24/25）上配置/查看 AI 密钥必崩：`KeyObfuscator` 使用 `java.util.Base64`（API 26+）且未启用 core library desugaring

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/util/KeyObfuscator.kt:27`（`java.util.Base64.getEncoder()`）、`:33`（`getDecoder()`）
  - `Android/app/build.gradle.kts:79` — `minSdk = 24`；全文件及 `gradle/libs.versions.toml` 无 `coreLibraryDesugaringEnabled`/`desugar_jdk_libs`（grep 实证，plugins 仅 AGP+Compose+KSP）
  - 本机 SDK 取证：`%LOCALAPPDATA%/Android/Sdk/platforms/android-36.1/data/api-versions.xml` — `<class name="java/util/Base64" since="26"`
  - 异常传播：`:37` `catch (_: Exception)` 拦不住 `NoClassDefFoundError`（是 Error）；`seal` 无任何 try
  - 调用链：`ui/settings/AgentApiSettingsStore.kt:332`（`open`/revealApiKey）、`:336`（`seal`/sealApiKey）、`:359`+`performInitialMigration`（`:350`，迁移时 seal 非空明文旧键）；`ui/settings/AiProviderManageScreen.kt:212`（reveal）、`:252,263`（save→seal）
  - 可达性：`ui/mode/AppWorkMode.kt:25,34,43` — NORMAL/DNS 模式 `minApiLevel=29`，**EXPRESS=24**：API 24/25 设备唯一可用模式即 Express；`express/ui/ExpressMainScreen.kt:249` → `LogRouteActivity.kt:120` DNS_CACHE → `ui/DnsCacheScreen.kt:150` AI 分析入口无模式门槛 → `:272` `Routes.AGENT_API_SETTINGS` → `SettingsRouteActivity.kt:396-397` AI 设置/管理页
  - 内部先例（证明是失误而非平台要求）：`ui/settings/OutboundProxySettingsStore.kt:6,175,182` 同类需求用的正是 API 1 即有的 `android.util.Base64`
  - 测试遮蔽：`app/src/test/.../AiProviderTest.kt` 在 JVM 上跑 `seal/open`（桌面 JVM 有 `java.util.Base64`）恒绿
- **机制/影响**：`java.util.Base64` 在 API 24/25 运行时不存在，首次**真实调用**（非空密钥的 seal/open）抛 `NoClassDefFoundError` → 直达全局 `CrashHandler`（`crash/CrashHandler.kt` 处理 Throwable）→ 进程崩溃并留崩溃报告。空白输入短路（`:22,31`）只推迟不避免：用户「输入 API Key 并保存」或「点开显示已保存密钥」即触发。
- **触发路径**：Android 7 设备 → 启动（强制 Express 模式）→ DNS 缓存页 → AI 分析设置 → AI 供应商管理 → 填入任意 Key → 保存 → 应用崩溃。
- **复现/验证**：API 24/25 模拟器走上述路径必现；静态取证三件套已齐（`since=26` × `minSdk=24` × 无 desugaring）。修复任选：改用 `android.util.Base64`（对齐 OutboundProxySettingsStore，**注意** `android.util.Base64` 默认换行需 `NO_WRAP`），或开启 `coreLibraryDesugaring`。
- **备注**：修复后请给 JVM 单测加 `Base64` 类来源断言不可行（JVM 恒有），应以 Android Lint 规则/NewApi 检查防回归（该处本应被 lint `NewApi` 标出——检查 CI 是否关闭了 lint 或 `Kotlin/未标注 API level` 检测未覆盖 `util/`）。

---

## A-033 QS 磁贴的启停操作绕过设备认证：锁屏上可直接启停 VPN/DNS 服务，仅打开主界面路径做了锁检查

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:41-56` — `onClick()` 按当前工作模式直接分发 `toggleDnsService()`/`toggleExpressVpnService()`/`toggleVpnService()`，全程无 `isLocked`/`unlockAndRun`
  - 对照同文件 `:155-159`（`openMainActivity`）：`if (isLocked) { unlockAndRun(launchAction) } else { launchAction.run() }` —— 作者知道并实现了认证要求，toggle 路径遗漏
  - 启停实体：`:58-69`（`DnsModeManager.startService/stopService`）、`:71-105`（`:96-98` `ContextCompat.startForegroundService(this, DnsVpnService.startIntent(this))`，`VpnService.prepare` 已授权时直接拉起）、`:107-127`（Express 同型）
  - `toggleVpnService:85` 的 `VpnService.prepare(this)` 只防「首次系统授权」，已授权后锁屏直启；磁贴未设置 `Tile.isSecure`
- **机制/影响**：快捷设置面板默认在安全锁屏上可用（下拉两次即可达）。他人捡起锁屏手机即可：关闭 VPN（静默解除全部域名过滤/应用管控——家长控制场景直接失守）；或反向开启服务器模式 DNS 服务，把锁屏设备变成局域网 1053 DNS 服务器对外应答。操作本身应在解锁后才被允许，属可见的越权控制面。磁贴状态与真实状态一致性不是问题，问题是未经认证就能改变。
- **触发路径**：设置锁屏密码 → 锁屏 → 下拉打开快捷设置 → 点「谛听」磁贴 → VPN/服务直接切换（无需解锁）。
- **复现/验证**：真机两步即证；静态：`grep -n "unlockAndRun\|isLocked" tile/DitingTileService.kt` 仅命中 `openMainActivity`（`:155-156`）。
- **备注**：修复方向：三个 toggle 与 `onClick` 分发整体包进 `unlockAndRun`（锁屏时先认证再执行），或磁贴设 `isSecure=true`（API 29+）使点击直接跳解锁。Express/NORMAL/DNS 三模式同修。

---

## A-034 「规则导入与更新」通知渠道重复注册：注册表 channel 是幽灵（仅死代码引用），实际通知走 Worker 硬编码的另一个 id

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/notification/AppNotificationChannels.kt:18` `const val CHANNEL_RULE_OPERATIONS = "diting_rule_operations_channel"`；`:56-63` 创建该渠道（名称 `R.string.rule_update_channel`）；注册表由 `main/MainStartupCoordinator.kt:48` 每次启动调用
  - `core/rule/RuleOperationWorker.kt:566` `const val CHANNEL_ID = "rule_operations"`（另一个 id）；`:556-563` worker 自建同名渠道；`:141` 每次 `doWork` 调 `createNotificationChannel()`；实际通知全部发往 `"rule_operations"`（`:525`、`:536`）
  - 唯一引用注册表 id 的 `core/rule/RuleUpdateNotifier.kt:62` —— 该类全仓无实例化点（grep `RuleUpdateNotifier` 仅命中其声明 `:17`），死代码
  - 两条渠道共用同一显示名：`res/values/strings.xml:195` 「规则导入与更新」（注册表 `:58` 与 worker `:560` 都取这个串）
- **机制/影响**：系统「设置→应用→通知」里出现**两条同名**「规则导入与更新」渠道（id 不同、名字相同），用户无法分辨哪条真实生效。通知面板长按实际通知选「静音/不再显示此类通知」时按通知所属渠道静音——若用户从渠道列表操作，极易静音到幽灵渠道：规则导入通知照旧弹出且再也关不掉（以为已关），或反过来真实渠道被关而设置页显示「已关闭」的却是没在用的那条。渠道级偏好（声音/横幅/免打扰联动）永久分裂。
- **触发路径**：任一订阅更新（`RuleOperationScheduler.enqueue` → worker `:141` 自建渠道）+ 应用启动（注册表创建幽灵渠道）→ 打开系统通知设置可见两条同名渠道。
- **复现/验证**：静态 grep 上述四处即闭环；单测断言 `RuleOperationWorker` 的通知 channel id 与注册表一致（当前必失败）。修复：worker 改用 `AppNotificationChannels.CHANNEL_RULE_OPERATIONS` 并删除自建逻辑，或至少删除 `RuleUpdateNotifier` 死代码并把 worker 硬编码串并入注册表；注意旧 id 渠道在升级后需 `deleteNotificationChannel("rule_operations")` 清理，否则同名幽灵反转。
- **备注**：同文件其余四个渠道（VPN 服务/监控/订阅自动更新/应用更新）经查通知端均正确使用注册表常量，唯规则渠道分裂。

---

## A-035 通知栏自定义文案导入要求两条**都**非空才写入：只填一条（UI 明示合法）时该条也静默丢失

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/transfer/PreferenceConfigImporter.kt:115-117` — `if (sys.customRunningNotificationText != null && sys.customStoppedNotificationText != null) { setCustomTexts(...) }`
  - `ui/transfer/ConfigTransferParser.kt:331-332` — `obj.optString(..., "").takeIf { it.isNotEmpty() }`：文件里的**空串**被解析为 `null`
  - `ui/transfer/ConfigExporter.kt:332-333` — 两键无条件 `put`（空串照写）
  - 「空=用默认」是产品语义：`notification/NotificationSettingsStore.kt:59-71`（kdoc 明写 empty means default）；UI 承诺：`normal/ui/NotificationSettingsScreen.kt:146`、`express/ui/ExpressNotificationSettingsScreen.kt:138` 「两项内容均可留空；留空后对应通知栏会使用默认状态文案」
  - `NotificationSettingsStore.setCustomTexts`（`:76-81`）是两键一起写的原子接口（无单写入口），但导入器可以在 null 侧传 `""` 恢复默认
- **机制/影响**：用户按 UI 指引只填「运行文案」、停止留空 → 导出文件 `{"customRunningNotificationText":"我的DNS","customStoppedNotificationText":""}` → 解析后前者有值、后者 null → `&&` 判定整条不执行 → 换机/重装导入后**已填的文案也没恢复**（回到空/默认），且无任何提示。次生：想通过导入「清空某条文案」永远不可能（清空=空串=null=跳过写入）。与同文件兄弟字段的正确写法对照：`sys.*?.let { ... }` 逐字段可空跳过（`:101-114`），唯独这两条文案被捆成对。
- **触发路径**：通知设置→只填运行文案→确定→导出配置→（重装/新机）导入→回通知设置：两条均为空；比对导出 JSON 可见文案明明在文件里。
- **复现/验证**：JVM 单测：DTO 置 `customRunning="X", customStopped=null`，调导入，断言 `getCustomRunningText` == "X"（当前实现返回 ""）。修复：逐字段写入（null 侧传当前本地值或空串恢复默认），解析端区分「键缺失」与「空串」。
- **备注**：修复时注意与 `takeIf{isNotEmpty()}` 的缺省语义联动：若要支持「导入清空」，解析应改 `if (obj.has(...)) obj.getString(...) else null`（键在即取值，空串合法）。

---

## A-036 Android 7.x 上「系统通知权限」入口点击无反应：`ACTION_APP_NOTIFICATION_SETTINGS`（API 26+）缺失且异常被 `runCatching` 吞掉

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/notification/NotificationPermissionHelper.kt:34-40` — `Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)` + `putExtra(Settings.EXTRA_APP_PACKAGE, ...)` + `runCatching { context.startActivity(intent) }`（无成功判定、无回退）
  - SDK 取证：`api-versions.xml`（android-36.1）`ACTION_APP_NOTIFICATION_SETTINGS since=26`、`EXTRA_APP_PACKAGE since=26`（本次复核本机文件确认）
  - 可达性：`ui/mode/AppWorkMode.kt:43` EXPRESS `minApiLevel = 24`，`build.gradle.kts:79` `minSdk = 24` —— API 24/25 设备唯一可用模式（Express）的设置页就有该入口：`express/ui/ExpressNotificationSettingsScreen.kt:149`；NORMAL 侧 `normal/ui/NotificationSettingsScreen.kt:157`（该模式 minSdk 29 不触发，但共用同一 helper）
- **机制/影响**：Android 7.0/7.1 系统无 Activity 响应此 action → `ActivityNotFoundException`（属 Exception）→ `runCatching` 静默吞掉 → 点击「系统通知权限」毫无反应：不跳转、不报错。用户被告知前往系统设置管理通知（副标题文案）却找不到路，且无任何提示该设备不支持跳转；`hasPermission`（`:20-28`）在 <33 恒真显示「已授予」，入口仍渲染可点。
- **触发路径**：Android 7.x 真机/模拟器（API 24–25）→ 极速模式 → 通知设置 → 点「系统通知权限」→ 无响应。
- **复现/验证**：真机即现；Robolectric：SDK=25 下调用后断言 `shadowOf(context).getNextStartedActivity() == null`（startActivity 抛出）且无 toast/回退。修复方向：`SDK_INT >= O` 走原 intent，否则回退 `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`（API 1+，`Uri.fromParts("package", pkg, null)`），或 <26 直接隐藏该入口。
- **备注**：与 A-032 同属「Express 模式把 minSdk 24 设备带进只在 API 26+ 成立的假设」一族，修复时建议对 Express 可达面做一次 NewApi 全扫。

---

## A-037 磁贴标签、监控常驻通知与规则/更新渠道名跟随**系统**语言，同屏其它文本走应用内语言：中英混杂

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:165` `tile.label = getString(R.string.quick_settings_tile_label)` vs 紧邻 `:166` `val stateText = localizedText(this, if (running) "已开启" else "已关闭")` —— 同一函数两种语言源
  - `notification/VpnMonitorService.kt:119,124,127` — `getString(R.string.vpn_disconnected / app_name / vpn_start)`（标题、正文、按钮三处）
  - `notification/AppNotificationChannels.kt:58,78` — `context.getString(R.string.rule_update_channel / app_update_channel)` 而同一注册表其余渠道（`:34,37,46,49,61,68,71,81`）用 `localizedText(context, ...)`
  - 语言源分叉的根：应用内语言独立于系统（`ui/AppLanguageManager.kt:22-36` 存 `dns_vpn_prefs`，`wrap()` `:38-50` 造 wrapper context）；`localizedText(context, …)`（`ui/LocalizedTextHelper.kt:28-35`）经 wrap 生效，而 Service/TileService 未包装 base context，`getString` 直接读系统 locale
  - 双语资源真实存在：`res/values/strings.xml:3` 「谛听」/`res/values-en/strings.xml:4` "DITING"；`rule_update_channel` 中文「规则导入与更新」/英文 "Rule import and updates"（`:195/:196`）
  - 正确先例：同为 Service 的 `server/backend/DnsModeService.kt:273-286,297-300` 全部用 `localizedText(this, ...)`；`core/rule/RuleOperationWorker.kt:560` 恰又用裸 `getString`（同文件内不一）
- **机制/影响**：用户在应用内把语言设为 English（系统仍 zh-CN）后：QS 磁贴一行内标签「谛听」（应 DITING）+ 副标题「已开启」被译成英文——中英混杂；VPN 停止时的常驻监控通知整条中文（标题应用名、正文「未连接」、按钮「开启」），与其下方应用内生成的其它通知语言不一致；系统通知设置里「规则导入与更新」「应用更新」两条渠道名不随应用语言切换。
- **触发路径**：设置→语言→English（保持系统中文）→ 下拉看磁贴；停止 VPN 看监控通知；打开系统通知渠道列表。
- **复现/验证**：静态即证（同函数混用两种 API）；真机改语言后磁贴 label 仍「谛听」而 subtitle 为 "On"/"Off" 对应译文。修复方向：Service/Tile 侧统一 `localizedText(context, ...)` 或 `AppLanguageManager.wrap(this).getString(...)`；渠道名注意仅创建时生效，修复后对已存在渠道无效（需版本化渠道 id 或接受旧装机不刷新）。
- **备注**：注意 `AppLanguageManager.wrap` 在 SYSTEM 模式下把非中文系统 locale 归一为 ENGLISH（`:39-46`），对显式系统跟随场景与资源限定符行为等价，不构成额外偏差。

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

### O-107 Kotlin 显示缓存把真实 TTL=0 的应答当「未知 TTL」落库，缓存统计页出现幽灵条目
- `core/cache/DnsResponseCache.kt:150` — `rawTtl = if (upstreamTtl > 0L) upstreamTtl else currentPolicy.maxTtlSeconds.coerceAtLeast(300L)`，随后 `effectiveTtlSeconds` 与 `expiresAt = now + effectiveTtl*1000`（`:166`）：`recordResolved(upstreamTtl = 0)` 的分支把上游**明确的 0 TTL**（`DnsCachePolicy.kt:37` FOLLOW 模式本应原样取 0，`:33` `effectiveTtlSeconds` 对 `<=0` 返回 0）与「没带 TTL」混为一谈，最终写入一条 `expiresAt≈now+maxTTL/300s` 的行。
- 触发链已核到底：Go `engine_dns.go:393-397` 对 `extractMinTTL` 返回 `(0, true)` 的应答置 `respTTL=0`；`log_aggregator.go:28` `json:"ttl,omitempty"` 使 TTL=0 在 JSON 中缺省；`normal/GoTunnelLogProcessor.kt:41` `optLong("ttl", 0L)` 读回 0，`:90` 调 `recordResolved(upstreamTtl = 0)`。Go 自身拒缓存该应答（`dns_cache.go` `effectiveTTL<=0 → return false`，每次查询都重新解析），Kotlin 行却长期「未过期」。
- 影响面有限（故列观察）：`DnsResponseCache.resolve/get/put/materialize` 已确认为死代码（全仓仅 `warmUp`/`recordCacheHit`/`recordResolved`/`clear`/`updatePolicy` 被调用），该行只进「DNS 缓存」展示/计数（`countUnexpired` 等），不改变实际解析。确认方法：FOLLOW 策略下 `recordResolved(name, type, "1.2.3.4", upstreamTtl = 0)`，断言 `getUnexpired` 不含该键（当前实现含）。修复方向：`recordResolved` 增加「TTL 缺失」与「TTL=0」的区分（如 Go 侧去掉 omitempty 或 Kotlin 用 `-1` 表示缺失）。

### O-108 共享 UID 应用在流量归因中坍缩为单一包名（Android 固有限制 + 主动截断）
- `core/traffic/TrafficAppResolver.kt:40` — `appInfoByUid[uid] = info` 对 `getInstalledApplications` 中同 UID 的多包**后写覆盖**；`:54` 对 `getPackagesForUid()` 结果取 `.firstOrNull()` 主动截断；Go 模式按 uid 归因（`:49`、调用点 `:186`）。
- 属 Android per-UID 统计的固有限制，且截断是显式选择；无多包共享 UID 的真实对照环境未验证，暂列观察。确认方法：安装一对共享 `android:sharedUserId` 的应用，制造流量后核对归因包名是否稳定取到「预期主包」。

### O-109 busybox/toybox `ping6` 若输出 `hoplimit=` 则逐项应答解析为空
- `core/diagnostic/NetworkPingTool.kt:248` — `REPLY_REGEX` 要求字面 `ttl=(\d+)`；注释（`:246-247`）已意识到 busybox 用 `seq=`（正则已兼容），但未覆盖 IPv6 常见的 `hoplimit=` 写法。若真机 `ping6` 打印 `hoplimit` 而非 `ttl`，逐序列应答列表为空，UI 显示「超时或无响应」（`:131-133`），而发送/接收/丢包/RTT 汇总仍解析正常（`:122-128`、`LOSS/TRANSMITTED/RECEIVED_REGEX`）。
- 未升级原因：需要一台 `ping -6` 实际输出 `hoplimit=` 的设备取证；toybox 现代版本多以 `ttl=` 统一输出。确认方法：`adb shell ping6 -c 2 <v6>` 观察应答行关键字。

### O-105 原生崩溃批量收集的文件名用写入时刻（ms），同毫秒可覆盖丢一份
- `crash/CrashLogManager.kt:53-54`：`saveCrashReport` 文件名 `crash_<yyyyMMdd_HHmmss_SSS>.log` 取的是**写入时** `Date()`，非崩溃标识；`checkAndCollectNativeCrashes` 在 `:320-341` 一个紧循环里最多迭代 10 条历史 `REASON_CRASH_NATIVE` 逐一落盘。两次迭代落入同一毫秒时，`FileOutputStream(file)` 截断覆盖前一份，历史原生崩溃静默丢失（现象：导出报告数少于待收集条数）。
- 未升级为缺陷：每次迭代含 `fos.fd.sync()` 与 `pruneOldLogs` 的 `listFiles`+排序，真机通常 >1ms，需多条待收集原生崩溃且存储极快才命中。确认方法：预置两条同 `timestamp` 的 `ApplicationExitInfo`，观察只落一份文件。修复方向：文件名追加 `index`/`pid`/`exitInfo` 指纹或用存在即改名的去重。
- 附带（非缺陷）：`CrashLogManager.kt:256-257` 的 `contains(X) || contains(X)` 两侧操作数相同，为无害复制粘贴；原生头 `DITING NATIVE CRASH REPORT` 不含 Java 子串 `DITING CRASH REPORT`，类型判定仍正确。

### O-110 后台停 VPN 时常驻监控通知可能静默不再出现（API 34+ FGS 后台启动限制）
- `normal/DnsVpnService.kt:381-383` `stopVpn()` 先 `stopForegroundCompat()` 再 `VpnMonitorManager.onVpnStopped(this)`；`notification/VpnMonitorManager.kt:41-45` 用 `ContextCompat.startForegroundService(...)` 拉起，异常仅 `Log.w` 吞掉。若此时应用整体处于后台（网络监控触发的自动停止、系统回收），Android 14+ 可能对 `startForegroundService` 抛 `ForegroundServiceStartNotAllowedException` → 常驻提醒消失，直到用户下次打开 App（`main/MainWorkModeCoordinator.kt` 的 sync）才恢复。同族路径 `express/ExpressVpnService.kt:193-196`。
- 未升级原因：前台点「停止」时应用可见、不触发限制，需后台停止场景 + logcat 抓到该异常才能定性。确认方法：API 34+ 真机让网络监控在后台触发 `stopVpn()`，看 logcat 是否出现 `ForegroundServiceStartNotAllowedException` 且 1002 通知消失。

### O-111 多个 MainActivity PendingIntent 共用 requestCode 0，extras 理论上互相覆盖
- `tile/DitingTileService.kt:139-144`（MainActivity + `EXTRA_AUTO_START_VPN`，code 0）、`normal/notification/VpnNotificationBuilder.kt:70-75`、`express/notification/ExpressNotificationBuilder.kt:71-76`、`core/rule/SubscriptionAutoUpdateScheduler.kt:249-253`（MainActivity，code 0，无该 extra）；`Intent.filterEquals` 不比较 extras/flags → `FLAG_UPDATE_CURRENT` 下后建者覆盖前者 extras。
- 未升级为缺陷：回读 `main/MainVpnController.kt:61-77`，auto-start 在 VPN 已运行时幂等（`DnsModeManager.startService` 见 RUNNING/STARTING 早退 `server/backend/DnsModeManager.kt:76`），未构造出可观察的错误结局。确认方法：运行时 dump 两个 PendingIntent 的 `isEquals` 并观察点「订阅更新完成」通知是否意外触发 VPN 启动。

### O-112 DNS 模式启动失败后磁贴短暂停留 ACTIVE（乐观更新无失败回滚）
- `tile/DitingTileService.kt:63-67` `toggleDnsService` 启动分支乐观 `updateTileState(running = true)`；`server/backend/DnsModeManager.kt:79-85` `startService` 走 catch 置 ERROR 时不发 `requestTileUpdate`（对照成功路径 `DnsModeService.kt:144`、停止路径 `:97` 均主动刷新）。ERROR 后磁贴仍显示 ACTIVE，直至下次面板打开 `onStartListening`（`:36-39`）自愈。与已修复的「DNS 启动重绘顺序」部分重叠，且自愈窗口短，列观察。

### O-113 `BatteryOptimizationHelper` 的 200ms 防抖缓存无任何读取方（死但无害）
- `permission/BatteryOptimizationHelper.kt:54-65`：缓存分支仅在 `forceRefresh=false` 时读取；全仓调用点（`permission/AppPermission.kt:139`、本文件 `:130/:207/:213`）均用默认 `forceRefresh=true`（grep `isGranted(` 实证无显式 false 调用），`cachedIsIgnored` 只写不读；且各变更点都先 `invalidateCache()`。每次走真实 Binder 查询，功能正确，仅防抖设计落空。确认方法：`grep "forceRefresh = false\|isGranted(.*, false)"` 无命中（当前）。
