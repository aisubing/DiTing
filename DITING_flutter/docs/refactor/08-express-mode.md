---
所属系列: DITING Android Flutter 重构功能图谱
章: 08
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测
---

# 08 极速模式（Express）全链路

> 分析基线 `main@dda2779`（v1.4.3）。包根 `Android/app/src/main/java/com/haoze/diting/express/`。
> 本域实测：**36 个 .kt 文件 / 7,893 行**（`find express -name "*.kt" | wc -l` = 36；`cat | wc -l` = 7,893）；另有 17 个 JVM 单测文件（`src/test/.../express/`，共 2,449 行）。
> 行号格式：`express/文件.kt:行`；跨包为相对 `com/haoze/diting/` 的全路径:行。

## 1. 概述：设计意图与边界

极速模式是**纯 Kotlin 的 DNS 窄路由 VPN**：不依赖 Go 引擎（`tunnel.aar`）、不做全隧道、不做 HTTPS MITM、不做流量统计。数据面只做一件事——把落入 TUN 的 **目标端口 53 的 UDP/TCP 包**在本机解析（含域名规则拦截、缓存、竞速/故障转移），其余流量在 OS 路由层根本不进 TUN。

- 工作模式枚举 `ui/mode/AppWorkMode.kt:36-43`：`EXPRESS(storageValue="express", minApiLevel=24, badge="极速")`；设备门槛在 `AppWorkMode.kt:48-61`：`minApi 24` **且必须 64 位**（`Process.is64Bit()` 或 `SUPPORTED_64_ABIS` 非空）。普通/服务器模式 minApi 29，普通模式走 Go 全隧道（`normal/DnsVpnService`），极速与之数据完全隔离（独立 Room 库 `diting_express`、独立 prefs `diting_express_prefs`、独立规则索引目录 `filesDir/rule-index/express/`，`data/RuleDataset.kt:24-28`、`core/rule/RuleIndexLayout.kt:44`）。
- 引擎设计目标：`engine/ExpressDnsEngine.kt:12-20` 声明执行序列对齐 `tunnel/engine_dns.go`，且「Fully JVM testable with zero android.* imports」——engine/codec/tcp/dns-utils/cache 全部零 Android 依赖，可在 JVM 单测直接驱动。
- 规模上限文件：`ExpressTunnelManager.kt`（538 行）、`engine/ExpressPacketCodec.kt`（572 行）、`dns/ExpressDnsMessageUtils.kt`（527 行）——均贴近 AGENTS.md 的 550 行红线；IPv6 判据被专门抽成 `ExpressIpv6Usability.kt`（23 行）以「逼近上限留余量」（该文件 KDoc :13 自述）。
- **没有 allowedApplications**：全仓 `grep allowApplication` 零命中；极速模式不筛选应用，仅 `addDisallowedApplication(自身)`（`ExpressTunnelManager.kt:232`）避免自解析死循环。

## 2. 启动与生命周期

### 2.1 Intent 动作表（`ExpressVpnIntents.kt:13-20`，8 个 ACTION 全列）

| 常量 | 字符串值 | 消费点（onStartCommand 分发） | 生产点 |
|---|---|---|---|
| ACTION_START | `com.haoze.diting.express.START_VPN` | **无 case 匹配**——落入 `ExpressVpnService.kt:81 else -> startVpn(intent)`（`startIntent()` :34 设置该 action） | `ExpressVpnController.start()` :100-101，经 `ContextCompat.startForegroundService`（`ExpressVpnController.kt:101`）；调用方 = `ExpressModeLauncher.kt:128,150`、`tile/DitingTileService.kt:140` |
| ACTION_STOP | `...express.STOP_VPN` | `ExpressVpnService.kt:69 → stopVpn()` | `ExpressVpnController.stop()` :111-112；`core/WorkModeLifecycleRegistry.kt` stopExpressMode lambda（action 字面值 :37） |
| ACTION_REFRESH_CONFIG | `...express.REFRESH_CONFIG` | :70 → `refreshConfig()` :181-185（重读解析模式 + 服务商 + 重建前台通知；**不重建 TUN**） | `ExpressVpnController.refreshConfig()` :123-127、`core/rule/RuntimeDnsSettingsRefresher.kt:45-56`（EXPRESS 分支）、`ExpressSettingsRefresher.kt:23`、通知文案保存 `ExpressNotificationSettingsScreen.kt:121` |
| ACTION_SYNC_RULES | `...express.SYNC_RULES` | :71 → `tunnelManager.syncRules(scope)` :474-480（刷新 block/allow 缓存 + invalidate DomainPolicy） | `ExpressVpnController.syncRules()` :129-133、`RuntimeDnsSettingsRefresher`（`ACTION_EXPRESS_SYNC_RULES`）、`ExpressSettingsRefresher.syncRulesIfRunning()` :34（**该方法仓内零调用者**，死代码） |
| ACTION_CLEAR_CACHE | `...express.CLEAR_CACHE` | :72 → `tunnelManager.clearCache()` :482-486（仅清内存 LRU；Room 清库在 Controller 侧 :137-138 `dao.clearAll()`） | `ExpressVpnController.clearCache()` :140、`data/cleanup/DataCleanupManager.kt:93` |
| ACTION_STATUS_CHANGED | `...express.STATUS_CHANGED` | 不由服务分发——**仅广播**（`statusBroadcastIntent()` :82-86），`ExpressVpnController.statusReceiver` :41-48 接收回填 StateFlow | `ExpressVpnController.onServiceStateChanged()` :170 |
| ACTION_REFRESH_FLOATING_LOG | `...express.REFRESH_FLOATING_LOG` | :73-75 → `floatingLogOverlay.refreshSettings()` | `ExpressVpnController.refreshFloatingLogOverlay()`；`WorkModeLifecycleRegistry.refreshFloatingLogOverlay()`（`core/WorkModeLifecycleRegistry.kt` EXPRESS 分支） |
| ACTION_FLOATING_LOG_APP_STATE | `...express.FLOATING_LOG_APP_STATE` | :76-80 → 写 `SystemSettingsStore.setMainActivityForeground` + `overlay.setAppInForeground` | `ExpressVpnController.updateFloatingLogAppState()` :158；MainActivity/SettingsRouteActivity/LogRouteActivity 前后台回调经 `ExpressModeLauncher.updateFloatingLogAppState`（`MainActivity.kt:214,232` 等） |

EXTRA 键共 8 个（`ExpressVpnIntents.kt:22-29`）：`vpn_running`、`refresh_reason`、`dns_name`、`dns_protocol`、`dns_host`、`dns_port`、`doh_url`、`app_foreground`。注意：**`EXTRA_REFRESH_REASON` 在 Express 侧写入后从未被读取**（对比普通模式 `normal/DnsVpnService.kt:136` 会读；Express `refreshConfig()` :181-185 忽略 intent 除服务商 extras 外的内容）。`ACTION_STATUS_CHANGED` 与 `EXTRA_RUNNING`/`EXTRA_REFRESH_REASON` 未列入 factory-only 对象——实际全部在 :22-29 定义。

`onStartCommand` 一律返回 `START_STICKY`（`ExpressVpnService.kt:83`，含 STOP 分支——由 `stopSelf()` 结束，粘性重启被 stopSelf 取消）。

### 2.2 VPN Builder 参数逐项（`express/ExpressTunnelManager.kt:198-246`）

| 项 | 值 | 行号 | 说明 |
|---|---|---|---|
| session | `R.string.app_name`（「谛听」） | :210 | |
| IPv4 地址 | `10.0.0.2/30` | :78, :211 | 常量实测 |
| IPv4 DNS | `10.0.0.1` | :79, :212 | `addDnsServer`——DNS 接管方式：让系统把解析写进 resolv，指向本 TUN 子网 |
| 路由 IPv4 | `10.0.0.0/30` + 22 个公共 DNS `/32` | :220, :221 | 22 = `PublicDnsHijackList.IPV4_HIJACK_ENTRIES.size`（实测 sed 计数 :21-56 = 22 条） |
| IPv6（条件） | 地址 `fd00:abcd::2/64`、DNS `fd00:abcd::1`、路由 `fd00:abcd::1/128` + 8 个 `/128` | :80-81, :224-228 | 仅 `enableIpv6` 时；IPv6 劫持 8 条（实测 :61-74 = 8） |
| 协议族 | `allowFamily(AF_INET)` 恒加；`AF_INET6` 条件加 | :213, :226 | **不 allowFamily 之外的族=仅 IP**，ICMP 等直接不进 TUN |
| MTU | **1400**（`VPN_MTU`） | :82, :214 | 普通模式同值不同引用点（`normal/DnsVpnTunnelManager.kt:191`） |
| blocking | `true` | :215 | 读线程 `inStream.read` 阻塞式 |
| 应用排除 | `addDisallowedApplication(自身包名)` try/catch | :232-234 | 无 allowApplication |
| establish 失败 | 记 Log、返回 null；服务侧 `PermissionDisclosureSettings.updateVpnGrant(false)` + stopForeground + stopSelf | :237-242；`ExpressVpnService.kt:102-109` | |

IPv6 使能判定（`Ipv6Mode` 三态，`ui/Ipv6Mode.kt:8-11`）：`ENABLED` 强制开、`DISABLED` 强制关、`AUTO`→`hasPhysicalIpv6Support()`（`ExpressTunnelManager.kt:127-193`）：遍历非 VPN 的物理网络（WIFI/CELLULAR/ETHERNET），要求同时存在 2000::/3 GUA（首字节 0x20..0x3f，:169-178）**和** IPv6 路由（默认/带网关/前缀 0，:181-186），判据收敛到 `ExpressIpv6Usability.isIpv6Usable = GUA && route`（`ExpressIpv6Usability.kt:21-22`）。`ExpressTunnelManager.kt:187-189` 注释自证：旧写法 `hasIpv6Route || hasGlobalIpv6` 恒真是死代码，已修。normal 侧有逐字相同的私有实现（`normal/DnsVpnTunnelManager.kt:346`），因包环不可复用（`ExpressIpv6Usability.kt:11-12` 自述）。

### 2.3 前台通知（`express/notification/ExpressNotificationBuilder.kt` + `ExpressVpnService.kt:152-179`）

- 渠道 `diting_express_vpn_channel`（:29），IMPORTANCE_LOW、无徽标/灯/震动（:40-45），`ensureChannel` 在 `onCreate()`（`ExpressVpnService.kt:57`）与每次 build（:59）。
- 通知 ID `NOTIFICATION_ID_EXPRESS_VPN = 2001`（:28）。
- Android 14+（UPSIDE_DOWN_CAKE）`startForeground(..., FOREGROUND_SERVICE_TYPE_SPECIAL_USE)`（`ExpressVpnService.kt:159-164`），失败回退无类型重试（:171-178）；Manifest 声明 `foregroundServiceType="specialUse"` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE=vpn`（`AndroidManifest.xml:45-55`）。
- 文案：用户自定义 `NotificationSettingsStore.getCustomRunningText` 优先（:61-66），否则 `formatStatusText`（:101-119）：多服务商→「极速模式运行中 · [模式名] N 个服务商」；单服务商→「极速模式运行中 · 名称」；空→前缀。**不含速率/流量**（与普通模式通知的差异化点，:20-22 KDoc）。点击→ MainActivity（SINGLE_TOP|CLEAR_TOP，:68-76）；Android 12+ `FOREGROUND_SERVICE_IMMEDIATE`（:94-96）。
- `updateForegroundNotification()` 在 startVpn 前（满足 FGS 时限，`ExpressVpnService.kt:99`）与数据面成功后（:145）各调一次。
- 停止清理：`stopForegroundCompat()`（:187-199）`STOP_FOREGROUND_REMOVE` + NotificationManagerCompat.cancel(2001)。

### 2.4 断链重连、崩溃恢复、保活

- **无自动重连逻辑**：极速模式没有链路监听器；TUN 读取异常即线程退出（`ExpressTunnelManager.kt:405-410`），`onRevoke()`（`ExpressVpnService.kt:213-219`）走正常停止并 `updateVpnGrant(false)`。网络变化不会触发重建。
- 崩溃恢复 = **状态自愈而非自动重启**：`ExpressVpnController.isRunning/initialize`（:59-89）以「持久化标志 `express_vpn_prefs.express_vpn_running` **AND** 进程内 `ExpressVpnService.isServiceAlive`」为真相；持久化 true 而服务已死（进程被杀/崩溃）→ 复位为 false，UI 不会显示假运行。`START_STICKY` 下系统可重建服务，`onStartCommand(null)` → `startVpn(null)`（:81 else 分支），服务商退化为 `DnsProvider.loadSelected(EXPRESS)`（:288，默认 `preset_alidns_dns` = 阿里云 223.5.5.5:53 明文，`core/dns/DnsProvider.kt:59-65`）。
- 冷启动义务：`onCreate` 里播种（开 DB、建 trie、同步 WorkManager）**必须在 IO 协程**，注释明示否则错过 Android 12+ FGS 时限（`ExpressVpnService.kt:58-64`）——对应 git 历史 `f3f9886 fix(android): 修复冷启动时前台服务超时崩溃`。
- **start/stop 竞态防护**：`ExpressLifecycleGuard`（43 行，纯 Kotlin）代际 token——`beginStart()` :25-29 取 token；`onStopRequested()` :32-35（stop 与 onDestroy 都调）使所有在途 start 失效；`canPublishRunning(token)` :38-40 只有 token==generation 且未停才允许发布 running。`ExpressVpnService.kt:130-135`：数据面加载规则期间被 stop → 丢弃隧道、关 pfd、不复活孤儿数据面（KDoc `ExpressLifecycleGuard.kt:4-16`）。
- 常驻监控：`VpnMonitorService` 的「未连接常驻通知」把极速一并计入——`VpnMonitorManager.isVpnRunning → VpnStateRegistry.isAnyVpnRunning`（`notification/VpnMonitorManager.kt:129`，`core/VpnStateRegistry.kt:19` 含 express lambda）；VPN 启停钩子 `onVpnStarted/onVpnStopped`（`ExpressVpnService.kt:147,209,232`；`ExpressVpnController.kt:166-168`）。模式切换时 `ExpressModeLauncher.switchToExpress` 先 `VpnMonitorManager.stop`（:48-52）。
- Tile 启动被拒的兜底：Android 12+ 后台 FGS 限制下 `start()` 返回 false → `DitingTileService.kt:140-147` 不点亮 tile 而拉 MainActivity。

### 2.5 组件互斥与冲突检测

- 模式互斥唯一入口：`ExpressModeLauncher.switchToExpress`（:33-68）→ `WorkModeLifecycleRegistry.stopOtherModes(EXPRESS)`（`core/WorkModeLifecycleRegistry.kt`：NORMAL 分支停 `normal.DnsVpnService`、SERVER 分支停 `server.backend.DnsModeService`）+ `VpnMonitorManager.stop`；反向切走时 `MainWorkModeCoordinator.kt:98-99` 调 `stopExpress`。三个 VpnService 并存由系统层保证（VpnService.prepare 单实例互斥），仓内**没有**第三方 VPN 冲突检测针对 express 的分支（VpnMonitorService 只监控自家状态）。
- 状态广播双发：`ExpressVpnController.onServiceStateChanged`（:162-177）同时发 `com.haoze.diting.express.STATUS_CHANGED`（自身接收者）与 legacy `com.haoze.diting.VPN_STATUS_CHANGED`（`VpnStateRegistry.ACTION_VPN_STATUS_CHANGED`），并 `QuickSettingsTileUpdater.requestTileUpdate`（:176）。
- `ExpressVpnService` 伴生 `protectSocket/protectDatagramSocket/protectFd`（:301-308）**仓内零调用者**（grep 双向：除定义外仅 `isServiceAlive` 被 Controller :62/:82/:107 使用）——transport 的 protect 全部经 `service.protect(...)` lambda 注入（`ExpressTunnelManager.kt:302,318-321`）。伴生三函数为死 API。

## 3. 数据通路（tun 读→解析→查询→缓存→调度→回写）

### 3.1 全链路逐跳（UDP 主路径）

| # | 跳 | 位置 | 细节 |
|---|---|---|---|
| 1 | TUN 读循环 | `ExpressTunnelManager.kt:402-459` | 专用 `Thread("ExpressTunReader")`、daemon；缓冲 `ByteArray(VPN_MTU+64)`=1464B（:403），复用单缓冲读取 |
| 2 | 包解析 | `:412 → engine/ExpressPacketCodec.kt:67-75` | 按版本号分发 IPv4(:77-99)/IPv6(:101-152)；分片包→Discard（:84-90 / :120-131）；非 UDP/TCP 丢弃（:194）；UDP 仅 dstPort==53 收（:171-175，`DNS_PORT=53` :15） |
| 3 | 起协程处理 | `ExpressTunnelManager.kt:414-431` | 每个 UDP 查询 `scope.launch(Dispatchers.IO)` 一个协程（**无并发上限**——serviceScope SupervisorJob+IO，:40） |
| 4 | 引擎解析 | `:417 → engine/ExpressDnsEngine.kt:76-160` | 见 3.3 |
| 5 | 组 UDP 响应包 | `ExpressTunnelManager.kt:418-426` | `buildUdpResponse`（codec :334-352）：src/dst IP 与端口互换、TTL/hoplimit 64、IP ID 自增 `AtomicInteger`（codec :31-33）、零分配伪首部校验和（:405-445） |
| 6 | 回写 | `:426 → writePacket :464-472` | `synchronized(writeLock)` 串行化 FileOutputStream.write；`!isRunning` 早退 |

TCP:53 路径：codec 解析出 `DnsTcpPacket`（:188-189）→ 读循环 `tcpChannel.trySend`（:433，**有界队列容量 256、DROP_OLDEST**，:76,106-109——注释明示防 TCP:53 flood 打爆堆）→ 单消费者协程 `tcpWorkerJob`（:377-389）交 `ExpressTcpDnsHandler.handlePacket`，逐个响应 writePacket。非 53 的 TCP → `buildTcpReset`（codec :201-265，RFC 793 语义：有 ACK 回 RST、SYN/FIN 计数进 respAck，窗口 0），保证应用快速失败而不是挂起。DiscardPacket 静默丢（:451-453）。

### 3.2 DNS-over-TCP 会话机（`engine/ExpressTcpDnsHandler.kt`）

- 状态：`SYN_RECEIVED/ESTABLISHED/CLOSED`（:26-30），连接表 `ConcurrentHashMap<ConnKey,...>`（:62，key=isIpv6+双侧 IP+端口，:32-38）。
- SYN→SYN-ACK（:76-98，本地 ISN 由 `nextIpId()<<16|0x1000` 生成——非密码学随机）；无连接的非首包→RST（:100-114）。
- ACK 覆盖判定用 `(clientAck-segEnd).toInt()>=0` 处理 32 位回绕（:121-129）；重复段回纯 ACK 不污染 rxBuffer（:135-146）；乱序（offset<0）也只回 ACK 要求期望 seq（:153-163）——**不重排、不缓存乱序段**，依赖客户端重传。
- 2 字节长度分帧循环（:169-222）：凑齐一帧→剥长度头→`engine.resolve`（:183）→重新加 2 字节长度→按 MSS=1300 分段（:190-218，末段 PSH|ACK）。
- 重传：`checkRetransmissions`（:256-276）由独立 500ms 定时器协程调用（`ExpressTunnelManager.kt:391-400`），超 1000ms 未确认重发、最多 3 次（:22-23）；`pruneInactive` 30s 清理（:278-282）。
- FIN：先处理完携带数据再 FIN-ACK 并删连接（:224-239）。自构 TCP 包（:284-343）窗口固定 65535。

### 3.3 引擎流水线（`engine/ExpressDnsEngine.kt:76-160`，五步）

1. **问题解析**：`ExpressDnsMessageUtils.extractQuestion`（:78；utils :48-64，要求 QDCOUNT==1、拒绝压缩指针 :468、读 DO/CD 位 :56,61）；失败→SERVFAIL（:79）。
2. **DDR 反制**（RFC 9462）：`_dns.resolver.arpa`/`*._dns.resolver.arpa`→NXDOMAIN（:85-92），阻断应用绕过规则自发现加密 DNS。
3. **域名规则**（:94-117）：仅 A/AAAA（`TYPE_A=1/TYPE_AAAA=28` :95）且 `isDomainRulesEnabledProvider()` 时执行；lambda 注入（`ExpressTunnelManager.kt:330-343`）→ `DomainPolicy.evaluate(domain, null)`（`core/rule/DomainPolicyEngine.kt:52-112`，7 级优先级：app-important block→global important→app allow→global allow→app block→global block→默认放行，LruCache 8192 :44,258）→ Block 时携带 `matchedRule` 与 `subscriptionIdOrNull()`（:336）。命中→`buildBlockedResponse(query, blockResponseModeProvider())`（:104 → utils :109-120，四模式 NXDOMAIN/NODATA/REFUSED/ZERO_ADDRESS，零地址 TTL=300s `BLOCK_RESPONSE_TTL_SECONDS` :19）。
4. **缓存查**（:119-131）：`cache.get` 命中→TTL 已按剩余改写→仅换回事务 ID（`withTransactionId` :127）→记 `cached=true, provider="cache"`。
5. **上游分发**（:133-148）：providers 空→IOException→SERVFAIL；`ExpressUpstreamDispatcher.dispatch`（见 §4）；异常→`upstream_failure: ...` 日志 + SERVFAIL（:146-147）。成功且非 TC→`cache.put`（:154-156）。
- 统计 `EngineStats`（:60-74）5 个 AtomicLong；**仓内除测试外无消费者**（UI 仪表盘读 Room 日志而非 stats——归 05 章）。
- 阻断→日志链完整引证：`ExpressTunnelManager.kt:349-366` dnsLogger lambda：blocked→LogResult.BLOCKED，`upstream_failure*`→ERROR，否则 PASSED；`msg="服务商 (Nms)"`；`scope.launch(IO){dnsLogger.log(...)}`（批量 50 条落库，`core/log/DnsLogger.kt:186`）。

### 3.4 线程/协程模型、队列、缓冲

- 线程：主线程只做 onStartCommand；1 个 TUN 读线程（Thread,daemon）；其余全部 `serviceScope = CoroutineScope(SupervisorJob()+Dispatchers.IO)`（`ExpressVpnService.kt:40`）协程：每 UDP 查询一协程（无界并发）、TCP 单消费者协程、500ms 重传协程、规则同步协程。
- 唯一有界队列 `tcpChannel`（256, DROP_OLDEST）；UDP 无队列——**背压完全靠 OS tun 缓冲 + 协程调度**；每查询读线程 `scope.launch` 后立即续读，无节流点。内存放大风险：突发大量慢查询时协程堆积在 IO 线程池（待定：无上限证据在真实 flood 下是否 OOM）。
- 写侧：`writeLock` 互斥串行（:96,465）；响应缓冲每次新建（`buildUdpResponse` 非 outBuffer 路径 copyOf，codec :349-351）——热路径每包 2-3 次数组分配。
- 停止清理 `stop()`（:500-537）：置 isRunning=false→取消两协程→**排空 tcpChannel**（:506）→关 in/out/pfd→interrupt 读线程→`ExpressDohTransport.releaseClients()`（:524，防 OkHttp 客户端经 protect lambda 泄漏服务图）→runBlocking flush 三个 logger + `bootstrapHealthEngine.close()`（:532-535 注释：不 close 每次启动泄漏一个静态监听器）。

## 4. 上游分发与劫持防护

### 4.1 服务商选择（`ExpressVpnService.resolveActiveProviders:237-289`）

优先级：intent 携带 `doh_url`→单自定义 DOH（id=`runtimeCustomProviderId(url)`）；`dns_host`（DOT/DNS）→单自定义；否则按 `ResolutionSettingsStore.getDnsResolutionMode(EXPRESS)`：SMART_PREDICTION/PARALLEL_RACE 取对应 ids 与 `loadRuntimeProviders` 交集（**≥2 个才生效**）、PRIMARY_BACKUP 取有序 ids（≥2）；全失败→`loadSelected(EXPRESS)` 单选。默认种子选择 `preset_alidns_dns`（`ExpressDefaultsSeeder.kt:72`）= 223.5.5.5:53 明文（`core/dns/DnsProvider.kt:59-65`）。

### 4.2 分发模式（`engine/ExpressUpstreamDispatcher.kt`）

- dispatch 四模式（:103-117）：SINGLE（:119-126，响应非法即抛）；PRIMARY_BACKUP（:128-142 顺序回退，保留最后异常）；PARALLEL_RACE→strategy=BRUTE_FORCE_PARALLEL、SMART_PREDICTION→strategy=SMART_PREDICTION（:114-115，仅决定 `RaceLogger` 记录的 strategy 标签——**竞速算法本身两模式无差别**：全量并发、先到先得、赢家取消兄弟并即时 close 其 socket，:149-226；`invokeOnCompletion` 里 CancellationException→`activeSocket.close()` :158-164）。`ui/RaceModeStrategy.kt:7-9` 实测 3 值，极速用到 2 个（PRIMARY_BACKUP 不经 race）。
- 有效性判定：`isUsableUpstreamResponse`（utils :222-226）= 是响应 + 事务 ID 匹配 + RCODE∈{NOERROR,NXDOMAIN}。
- Bootstrap：`resolveBootstrap`（:228-239）对 DOH 抽 URL host、DOT/DNS 用 host，交给 `bootstrapResolver`→`ExpressTunnelManager.resolveBootstrap:488-495`→`runBlocking { bootstrapSelector.resolveHost }`（`core/diagnostic/BootstrapSelector`，**dataset=EXPRESS** :298-304——注释 :294-296 记录历史缺陷：曾误读 NORMAL 配置）。
- 超时常量：`core/dns/DnsTimeoutConstants.kt:3` `DNS_UPSTREAM_TIMEOUT_MS = 5_000`，三 transport 全部默认引用它。

### 4.3 传输层（`express/transport/` 3 文件，与 core 的关系见 §5）

| 文件 | 协议 | 关键差异 vs core 版 |
|---|---|---|
| `ExpressPlainDnsTransport.kt`（127 行） | UDP:53→TC 截断则 TCP:53 重试（:49-53） | +EDNS0（OPT 追加，buffer 1232，:25,39-43）+多地址循环回退（:46-62）+`onSocketActive` 取消钩子（:74,98）；`MAX_DNS_PACKET_SIZE=65535`（:26） |
| `ExpressDotTransport.kt`（138 行） | TLS:853（port 默认 853 :31；`DnsProvider.DEFAULT_DOT_PORT=853`） | +EDNS0 +bootstrap 地址逐个尝试（:46-59） +响应长度校验 `1..65535`（:84-86） +可取消钩子（:115,124）；`endpointIdentificationAlgorithm="HTTPS"`+SNI（:126-129）与 core 一致 |
| `ExpressDohTransport.kt`（233 行） | HTTPS POST `application/dns-message`（:35,170-175） | 源自 `DnsLatencyTester` 的 DoH 逻辑但加 **客户端缓存**：`ClientKey(timeout,host,addresses,protector 身份)`→OkHttpClient map（:42-100，`MAX_CACHED_CLIENTS=16` 溢出驱逐 :131-136）；`releaseClients()` 供 VPN 停止时释放（:147-151）；`suspendCancellableCoroutine`+`invokeOnCancellation{cancel()}`（:191-208）；自定义 `ExpressProtectingSocketFactory` 全 5 个 createSocket 重载都 protect（:210-232）。core `DotTransport.kt`(121)/`PlainDnsTransport.kt`(98) 无缓存/无钩子 |

### 4.4 劫持防护（`engine/PublicDnsHijackList.kt`）

机制是**路由劫持**而非包内容替换：把这批公共 DNS IP 以 `/32`（IPv4，:221）与 `/128`（IPv6，:228）加进 allowed-IP 路由，应用硬编码向 8.8.8.8 等查询时包落入本 TUN，由本机引擎按规则解析后回包——即「命中条件」= 目的地址∈表 且 目的端口=53（codec :171,188）。实测表项：**IPv4 22 条**（Google 8.8.8.8/8.8.4.4、Cloudflare 1.1.1.1/1.0.0.1、Quad9 9.9.9.9/149.112.112.112、OpenDNS 208.67.222.220 两条、AliDNS 223.5.5.5/223.6.6.6、DNSPod 119.29.29.29、114DNS 两条、Baidu 180.76.76.76、Yandex 77.88.8.8/.1、AdGuard 94.140.14.14/.15、CleanBrowsing 两条、Neustar 64.6.64.6/.6——文件 :23-55）；**IPv6 8 条**（Google/Cloudflare/Quad9/AliDNS 各 2——:63-73）。KDoc :20 声称 "approx 22 items" 与实测一致。`isHijacked()`（:80）与 `ALL_HIJACK_IPS`（:78）及 `HijackEntry.provider/description` 字段在生产代码**零消费**（grep：主代码只引用 IPV4_HIJACK_IPS/IPV6_HIJACK_IPS；`isHijacked` 仅 `ExpressPacketCodecTest.kt:329-334` 使用）——元数据字段属演示性冗余。注意：`DNS_SERVER_V4=10.0.0.1` 同时经 `addDnsServer` 接管系统 DNS，与劫持表是两条独立路径。

## 5. 与共享层（core/*）的关系矩阵

### 5.1 express → core 消费（文件级，import 实测）

| core 文件 | 消费方（express 文件） | 用法 |
|---|---|---|
| `core/dns/DnsProvider.kt` | Service/Intents/Controller/Seeder/NotificationBuilder/Engine/Dispatcher/TunnelManager/HomeContent | 服务商模型+prefs 读写（loadSelected/loadRuntimeProviders/saveSelected，dataset=EXPRESS）；DEFAULT_DOT_PORT=853/DEFAULT_DNS_PORT=53（:50-51）；`runtimeCustomProviderId`（:451） |
| `core/dns/DnsProtocol.kt`（同文件） | Intents/Service/Dispatcher | 协议枚举 3 值 |
| `core/dns/DnsTimeoutConstants.kt` | 3 transports + Dispatcher | `DNS_UPSTREAM_TIMEOUT_MS=5000` 单点常量 |
| `core/rule/DomainPolicyEngine.kt`(DomainPolicy/DomainDecision) | `ExpressTunnelManager.kt:330-343` | **极速规则判定的唯一真身** |
| `core/rule/BlockListManager.kt` / `AllowListManager.kt` | TunnelManager:274-275（运行时）、Seeder:100-101（索引重建）、RequestLogScreen:305-307（加规则） | 共享实现，非平行 |
| `core/rule/RuleIndexLayout.kt` | TunnelManager:273、Seeder:97 | `filesDir/rule-index/express/`（:44） |
| `core/rule/BlockResponseMode.kt` | Engine/Utils/TunnelManager/Seeder | 4 拦截响应枚举 |
| `core/rule/DynamicBlockResponseConfig.kt` | ExpressDynamicBlockSupport | 仅用于 UI 文案判定（极速不消费机制本身） |
| `core/rule/DefaultWhitelistSeeder.kt` | Seeder:76-93 | 资产白名单播种（共享解析器，写 EXPRESS 库） |
| `core/rule/RewriteRuleManager.kt` | Seeder:102 | 仅索引重建（引擎不使用覆写；极速无 rewrite 路径） |
| `core/rule/SubscriptionAutoUpdateScheduler/Settings.kt` | Seeder:71,114 | WorkManager 订阅自动更新 |
| `core/cache/DnsCachePolicy.kt` | TunnelManager:280（provider lambda）、ExpressRoomDnsCache | `enabled`+`effectiveTtlSeconds`（:44-58） |
| `core/log/DnsLogger.kt` / `RaceLogger.kt` / `LogMaintenance.kt` | TunnelManager:281-293 | 共享批量日志器（BATCH_SIZE=50）与保留清理调度（retention=EXPRESS prefs） |
| `core/diagnostic/BootstrapHealthEngine/BootstrapSelector/BootstrapLogger.kt` | TunnelManager:283,297-304 | Bootstrap IP 健康选择，dataset=EXPRESS |
| `core/VpnStateRegistry.kt` / `core/WorkModeLifecycleRegistry.kt` | Controller:51-57（注册 lambda）、Launcher:42 | 跨模式互斥与状态 |
| `core/tile/QuickSettingsTileUpdater.kt` | Controller:176 | 状态变更后刷 tile |
| `core/dns/DotTransport.kt` / `PlainDnsTransport.kt` / `DnsLatencyTester.kt` / `core/cache/DnsCacheKey.kt` | **仅 import 注释引用，零实际调用**（grep 双向确认；如 `ExpressDohTransport.kt:3` import 后只出现在 :30 文档注释） | 死 import——重构清理项 |

### 5.2 express 自有平行实现 vs core 同名件（重构取舍关键）

| 平行对 | 差异点（实测逐条） |
|---|---|
| `express/dns/ExpressDnsMessageUtils.kt`(527) vs `core/dns/DnsMessageUtils.kt`(597) | ① express `buildQuery` 无 IDN 处理——core 有 `toAsciiQueryName/toWireLabels`（IDN.toASCII + 1..63 长度校验，core:140-159），express 直接 `split('.')+US_ASCII`（:81-83）——中文域名构查询时 express 会产出不合规 label；② express 新增 `hasOptRecord`+`ensureEdns0`（:377-428，core 无等价物）；③ express `buildNegativeResponse/buildRefusedResponse/buildZeroAddressResponse` 为 public（core 皆 private）——DDR 路径直接调 public buildNegativeResponse；④ RCODE 常量 express public / core private；⑤ `hasDnssecOk` 扫描范围不同：express 计 `anCount+nsCount`（:435），core 只计 `nsCount`（core:493）——查询报文正常 anCount=0 时等价，携带 answer 段时行为分叉（待定：现实客户端不发送）；⑥ express `extractQuestion` 等其余核心解析逻辑两实现逐字同构（本会话归一化 diff 证实，仅格式与上述差异）。**这是最大的一对「同义双写」，Flutter 侧必须收敛为一份** |
| `express/transport/Express{Plain,Dot,Doh}Transport` vs `core/dns/{PlainDnsTransport,DotTransport}` + `DnsLatencyTester` DoH 段 | express 版=core 版 + EDNS0 + 超时参数化 + `onSocketActive` 取消钩子 + bootstrap 多地址回退 +（DoH）客户端缓存与协程取消。功能上是严格超集；差异全部服务于竞速取消场景 |
| `express/cache/ExpressRoomDnsCache.kt`(165) vs `core/cache/DnsResponseCache.kt`(512) | ① express 单 LRU 500（`SimpleLruCache` :22-49，@Synchronized LinkedHashMap accessOrder）vs core 分片 LRU+`inFlight` single-flight 去重（core:36-39,78-92）+写合并批处理（pendingWrites/pendingHits + dbWriteMutex，core:43-59）；② express **put() 在查询协程里同步写 Room**（`updateMetadata`→0 行才 `insertIfAbsent`，:134-163——A-065 修复保 hitCount）vs core 攒批异步 flush；③ 命中取回：express `overwriteDnsPayloadTtl`（全部 RR 一律覆写剩余 TTL，codec :471-482）vs core `patchResponseTtl(offsets, remaining)` 按存储的 ttlOffsets 精确 patch；④ express 无 stale fallback、无 negative TTL 缓存（NXDOMAIN 在引擎层因 `isSuccessResponse`=NOERROR-only 不入库，engine:154）、无 `staleFallbackSeconds/negativeTtl*` 消费（这两字段只有 Go 快照与 core 缓存读——`normal/HttpsDnsConfigSnapshot.kt:65-66`、`server/backend/DnsServerEngine.kt:206-207`）；⑤ key 格式 `name#type#class#do#cd`（:65-70，分隔符 '#'）vs core `DnsCacheKey.storageKey` '|' 分隔（core/cache/DnsCacheKey.kt:28-38）——**同一 DnsCacheEntity/DnsCacheDao、同一张 dns_cache 表，但分属两个 DB 文件，key 风格并存**。⑥ `typealias ExpressRoomDnsCache`（TunnelManager:70）仅为命名遮蔽。 |
| `ExpressUpstreamDispatcher` vs Go 侧竞速 + `normal` 的 resolution 调度 | 极速在 Kotlin 重实现了 SINGLE/PRIMARY_BACKUP/两种 race（core Go 引擎有各自路径，`normal/GoInspectionTunnel.kt` 等消费 DnsResponseCache）；`DnsResolutionMode` 枚举共享（`ui/DnsResolutionMode.kt:14-18`，4 值实测） |
| `ExpressPacketCodec` vs 无（core 无等价物） | TUN 编解码为极速独有；普通模式该职责在 Go/tun2socks+gvisor |
| `ExpressDynamicBlockSupport.kt` | 不是平行实现而是**差异声明件**：KDoc :8-23 实测——动态升级（先 NODATA 后 NXDOMAIN）只存在于 Go 数据面 `tunnel/dns_config.go` dynamicBlockTracker；`isEscalationApplied(dataset)= dataset!=EXPRESS`（:32），极速规则屏据此把副标题改成「极速模式暂不执行动态升级…」（:50-51），消费者 `ExpressRuleControlScreen.kt:137-145`。设置存储仍可读可写但引擎不执行 |

### 5.3 其他共享件（非 core/）

`data/ExpressRulesDatabase`（18 实体、version 2、库名 `diting_express`，`data/ExpressRulesDatabase.kt:59-99`；迁移 EXPRESS_MIGRATION_1_2 仅 cosmetic_rule.isException :47-57）、`ui/floating/FloatingLogOverlayController(dataset=EXPRESS)`（极速悬浮日志读 express 库且无 HTTP 日志，:44-49）、`ui/settings/{AppRules,Resolution,DnsCache,System}SettingsStore` 全部带 `dataset=EXPRESS` 重载、`ui/transfer/ConfigExporter/Importer(EXPRESS)`。

（续篇：08-express-mode-2.md——配置适配全表、UI 逐屏清单、引证表、Flutter 注意、待定清单）
