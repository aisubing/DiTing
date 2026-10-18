---
所属系列: DITING Android Flutter 重构功能图谱
章: 09
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测
---

# 09 普通模式（Normal）— VPN 服务与 Go AAR 编排

> 基线 `main@dda2779`（v1.4.3）。包根 `Android/app/src/main/java/com/haoze/diting/normal/`。
> 本域实测规模：`normal/*.kt` **16 文件 2,796 行** + `normal/notification/` 2 文件 195 行 + `core/cert/GoInspectionCaManager.kt` 64 行 = **3,055 行**（`wc -l` 实测合计）；`normal/ui/` **24 个 .kt / 6,430 行**。
> Go 引擎本体归第 10 章（见第 10 章）。Go 绑定接口面由本会话 `javap tunnel.Engine`（`Android/app/libs/tunnel.aar` → classes.jar）实测，见 §3。
> 行号：`normal/文件.kt:行`；跨包给相对 `com/haoze/diting/` 全路径。

## 1. 概述：Kotlin 编排层 + Go 数据面

普通模式 = **一个 `VpnService` 全隧道 + Go 用户态网络栈**。分工严格：

- **Kotlin 侧（本域）**：权限/前台服务/通知、`VpnService.Builder` 参数、设置读取、规则与日志的 Room 读写、UID↔包名反查、把一切「策略」翻译成 JSON/CSV 推给 Go。
- **Go 侧（第 10 章）**：持有 tun fd、读写 IP 包、DNS 解析与竞速、域名 trie/bloom 决策、MITM 解密、UID 拦截、流量计数。

分层证据：`GoInspectionTunnel` 是唯一持有 `tunnel.Engine` 的类（`GoInspectionTunnel.kt:70 private val engine = Engine()`）；`DnsVpnTunnelManager`（417 行）只管 Builder + Engine 生命周期 + CA 就绪判定；`DnsVpnService`（560 行）只管动作分发与前台化。`DnsVpnService.kt` 的 560 行**已越过** AGENTS.md 的 550 行上限（本域唯一越线文件，见 §9）。

工作模式门：`ui/mode/AppWorkMode.kt:20-25` `NORMAL(minApiLevel = 29)`（极速 24，:43），且 `isSupportedOnCurrentDevice()` :48-61 要求 64 位 ABI。

## 2. 启动全序列（用户点开关 → tun 工作）

```
PowerToggleButton(normal/ui/MainScreenContent.kt:126-132, onToggle 形参 :58)
  → normal/ui/MainScreen.kt:218 onToggle = { onToggle(uiState.isRunning) }
  → main/MainModeDispatcher.kt:80-81 MainScreen(onToggle = onToggleVpn)
  → MainActivity.kt:138 onToggleVpn = { isRunning -> vpnController.onToggleVpn(isRunning) }
  （另有 ui/MainViewModel.kt:203 toggleVpn() 走 WorkModeLifecycleRegistry.start/stopNormalMode(:219/221)
    ——实测全仓（含 test）零调用者，见 §9 架构债）
  main/MainVpnController.kt:79 onToggleVpn
    :80 DNS 模式直接 return；:81-83 EXPRESS→ExpressModeLauncher；:87-90 TIRAMISU 先要 POST_NOTIFICATIONS
    :92 prepareVpn()；:96-97 VpnService.prepare(activity)（:99-106 需同意则走披露页 `permissionDisclosure = VPN`）
    :151 startVpnService() → :155 ContextCompat.startForegroundService(DnsVpnService.startIntent(activity))
DnsVpnService.onStartCommand (:116)
  :176 promoteToForeground()          ← 注释明确：Android12+ 未在 onStartCommand 提前景会 ForegroundServiceDidNotStartInTimeException
    :188 VpnNotificationBuilder.build → :194-202 startForeground(ID=1001, SPECIAL_USE)，失败降级为无 type 重试（:206）
  :177 startVpn(intent)
    :228 已有 vpnInterface → 只发状态广播返回（幂等）
    :233 DnsVpnStatusNotifier.setRunningFlag(true)
    :235-238 activeResolutionMode / DnsVpnProviderResolver.resolveDnsProviders（Intent 临时覆盖优先，见 §4.2）
    :240-242 inspectionConfigured/Requested（见 §6）
    :244 verifyHttpsInspectionCertificateAsync(异步真查 AndroidCAStore，不一致则重启隧道)
    :246-255 blockedPackages / appAllowlistRules 读设置
    :256-268 outboundProxyConfig 校验失败 → 置 error、清标志、stopForegroundCompat、stopSelf 直接退出
    :276 tunnelManager.establishVpnInterface(...)  ← Builder 段，见 §2.1
    :292-293 bootstrap 配置刷新
    :294 tunnelManager.startTunnel(...)            ← Go 段，见 §2.2
    :320-322 TrafficStatsManager.start(this, true)（仅当流量统计或通知速率开启）
    :323 powerOptimizer.register()
    :326 refreshForegroundNotification()
    :327 speedMonitor.start(...)
    :332 floatingLogOverlay.setVpnRunning(true)
    :333 VpnMonitorManager.onVpnStarted(this)  → 停掉常驻「未连接」通知服务
    :334 sendStatusBroadcast(true)
    :335 networkMonitor.start()
    :337-342 serviceScope.launch { rulesInitializationJob.join(); pushRuleSnapshot() }  ← 规则全量快照在规则加载完后补推
```

### 2.1 `establishVpnInterface`（`DnsVpnTunnelManager.kt:172-250`）逐项

| Builder 调用 | 行 | 值/条件 |
|---|---|---|
| `setSession` | :187 | `R.string.app_name` |
| `addAddress` | :188 | `10.0.0.2 /30`（常量 :358） |
| `addDnsServer` | :189 | `10.0.0.1`（:359） |
| `allowFamily(AF_INET)` | :190 | 恒开 |
| `setMtu` | :191 | **1400**（:362；与 Go 侧 `defaultTunMTU=1400` 一致，`Android/tunnel/engine_full_tunnel.go:19`） |
| `setBlocking(true)` | :192 | Go 侧按阻塞读 fd |
| IPv6 三件套 | :194-198 | `addAddress(fd00:abcd::2,64)`+`addDnsServer(fd00:abcd::1)`+`allowFamily(AF_INET6)`，条件 `enableIpv6` |
| 绕过局域网路由 | :200-224 | `IPV4_BYPASS_LAN_ROUTES`（:364-415，**50 条** CIDR）+ `10.0.0.1/32` + `2000::/3` + `fd00:abcd::1/128` |
| 全隧道路由 | :226-229 | 否则 `addRoute("0.0.0.0",0)`；IPv6 时 `addRoute("::",0)` |
| 排除应用 | :232-239 | `excludedPackages + 自身包名 + proxyPackage` → `addDisallowedApplication`（无 `allowApplication`） |
| `establish()` | :241-246 | 异常吞掉返回 null |

IPv6 决策（`enableIpv6`，:179-183）：`ENABLED`→true、`DISABLED`→false、`AUTO`→`hasPhysicalIpv6Support()`。后者（:100-167）遍历物理网络（排除 `TRANSPORT_VPN`，:108；排除接口名 `tun*`/`vpn*`，:138），要求 **GUA `2000::/3`**（首字节 `0x20..0x3f`，:150）且存在 IPv6 路由（:158-163），最后 `isIpv6Usable()`（:346-347）＝两条件与。**注意**：`addAddress(VPN_ADDRESS_V6, 64)`（:195）与 `DnsVpnService.kt:40` 类 KDoc 声称的 `/128` 不一致（实现是 64）——待定项。

绕过局域网路由的正确性由 `src/test/.../DnsVpnTunnelManagerBypassRoutesTest.kt` 兜底：断言 50 条路由的补集恰好是 `0/8,10/8,127/8,169.254/16,172.16/12,192.168/16,224/3`（即「除这些外全部进 TUN」），并校验无重叠。

### 2.2 `startTunnel` → Go（`DnsVpnTunnelManager.kt:255-314`）

`GoInspectionTunnel(...)` 构造（:275-305）注入 22 个参数：`context/vpnService/scope`、`dnsConfig = HttpsDnsConfigSnapshot.create(...)`（:279）、`inspectionEnabled`、三类应用名单（`selectedPackages/blockedPackages/appAllowlistRules`）、`dnsPolicy/allowListManager/cnameRewriteRuleManager/goUrlRuleManager`、四个 logger + `bootstrapHealthEngine` + `dnsCache`、`filterHttp3`（:302 读 `isHttp3InspectionEnabled`）、`blockEncryptedDns`（:303）、`outboundProxyConfig`、`ruleIndexDirectory`（默认 `File(filesDir,"rule-index")`，GoInspectionTunnel.kt:68）。

`GoInspectionTunnel.start(tunFileDescriptor: Int)`（`GoInspectionTunnel.kt:91-99`）：
1. `configureEngine(selectedPackages)`（**同步**，必须在 startFull 前把所有回调/规则装好，:199-374）；
2. `scope.launch(Dispatchers.IO) { engine.startFull(fd.toLong(), SocketProtector { vpnService.protect(fd.toInt()) }) }`（:93-97）——**tun fd 以 `Int` 传 long**，Go 侧直接 `os.NewFile(uintptr(fd), "tun")` 读；
3. `protect()` 语义经 gomobile 回调 `SocketProtector` 回到 Kotlin，`vpnService.protect(fd)` 让 Go 的上游 socket 不落入自身 tun（防环路）。
4. fd 生命周期：`disconnectVpnInterface()`（:328-336）**先 `engine.releaseTun()` 再 `pfd.close()`**——顺序错误会让 Go 读已关 fd。

`startFull` 返回 `Boolean` 只反映「是否成功提交协程 + configureEngine 未抛」（`getOrDefault(false)`），**不代表 Go 真的跑起来了**：Go 内部 `if e.running { return }` 早退（`engine_full_tunnel.go:178-182`），Kotlin 无从得知。→ 待定。

## 3. Kotlin ↔ Go 桥接 API 全清单

`javap tunnel.Engine` 实测：**54 个 native 方法名**（另有 `Engine()`/`Engine(int)` 两构造器 + Seq 代理/Object 方法）。用「本域调用集」对「54 全集」做 set 差集（脚本实测：33 in 54）→ **33 个被本域（normal + core/cert，含反射调用的 `getDNSCacheStats`）消费**，21 个本域不调用，其中 4 个（`startStandalone/stopStandalone/setBlockResponseType/setLogCallback`）由 server 模式使用（第 11 章），余 **17 个全仓零消费**（见下表尾）。

| Go 方法 | 调用文件:行 | 触发时机 | 参数格式 | 备注 |
|---|---|---|---|---|
| `startFull(long, SocketProtector)` | GoInspectionTunnel.kt:94 | startTunnel | fd + 回调 | 唯一启动入口（`start(long,..)` 零调用） |
| `stop()` | :105 | stop | — | 释放 dnsCache/栈 |
| `stopStackMitm()` | :106 / GoInspectionCaManager.kt:26 | stop / 读 CA 后 teardown | — | 释叶证书 |
| `releaseTun()` | :110 | disconnectVpnInterface | — | 必须早于 pfd.close |
| `clearDNSCache()` | :115 | 规则重载 / bootstrap 重置回调 | — | 见 §5 |
| `getDNSCacheStats()` | :118-120（**反射** `javaClass.getMethod`） | 无调用者 | — | 见 §9 死代码 |
| `resetBootstrapStats()` | :124 | `onBootstrapHealthReset`（DnsVpnService.kt:103） | — | |
| `setTickIntervalMs(long)` | :135 | 屏幕状态变更 | 1000/10000 | DnsVpnPowerOptimizer.kt:60-62 |
| `resolveDomain(String, boolean)` | :157 | 诊断（DitingApp.kt:57→resolveThroughTunnel） | 域名 | 返回 JSON |
| `applyDNSConfig(String)` | :190 | syncDnsConfig（启动 + 热更新） | §3.1 JSON | throws Exception |
| `configureOutboundProxy(String)` | :200 | configureEngine 首步 | `OutboundProxyConfig.toNativeJson()`（ui/OutboundProxyConfig.kt:35-42：enabled/protocol/host/port/username/password） | 返回错误串，`require(isBlank)` 否则 start 失败（:201） |
| `setOutboundProxyStatusCallback` | :202 | configureEngine | — | → DnsVpnService.kt:74 |
| `setDomainChecker` | :226 | configureEngine | — | 8 方法回调，§3.2 |
| `setFilterDNS(true)` | :260 | configureEngine | 恒 true | 注释 :255-259：DNS 过滤与 MITM **强制耦合** |
| `setBatchLogCallback` | :261 | configureEngine | — | §6.4 |
| `setRaceLogCallback` | :269 | configureEngine | — | 13 参，见 §3.3 |
| `setBootstrapLogCallback` | :310 | configureEngine | — | 8 参 |
| `setHttpLogCallback` | :336 | configureEngine | — | §6.4 |
| `setUIDResolver` | :358 | configureEngine | — | CachedConnectionOwnerUidResolver |
| `setAppUidResolver` | :359 | configureEngine | — | CachedAppPackageResolver |
| `setUseTcpStack(true)` | :360 | configureEngine | 恒 true | |
| `setBlockedUIDs(String)` | :361 | configureEngine | CSV `123,456`（`packageUid` joinToString(","）） | 禁止联网 |
| `startStackMitm(String)` | :364 | 仅 inspectionEnabled | `filesDir/go-mitm` 绝对路径 | **返回 CA PEM**（Go engine_mitm.go:21 返回 `GetCACertPEM()`） |
| `setMitmAllowedUIDs(String)` | :365 | 仅 inspectionEnabled | CSV UID | 检查应用名单 |
| `setFilterHttp3(boolean)` | :367 | configureEngine | — | QUIC |
| `setBlockEncryptedDns(boolean)` | :368 | configureEngine | — | 阻断 TCP 853 |
| `setTrafficCallback` | :369 | configureEngine | — | → TrafficStatsManager.onGoTrafficTick |
| `applyRuleSnapshot(String)` | GoTunnelRuleManager.kt:45 | pushRuleSnapshot | §5 JSON | 返回错误串 |
| `setExtraPassthroughSuffixes(String)` | :70 | updatePassthroughRules | **换行分隔**域名 | 旁路 |
| `setRewriteRules(String)` | :95 | updateRewriteMap | JSON `{"a.com":["1.2.3.4"],"b.com":"cname.tld"}` | ipRewrites + cnameRedirects 合并 |
| `setRequestRules(String)` | :101,:107 / GoInspectionTunnel:222 | updateRequestRules | JSON 数组 `[{"pattern":"https://h/p","kind":"block/allow"}]`（GoUrlRuleManager.kt:35-39） | 非 MITM 时推空串 |
| `setCosmeticRules(String)` | :114,:120 | updateCosmeticRules | JSON `{globalHide:[],globalException:[],domains:{d:{hide:[],exception:[]}}}`（CosmeticRuleManager.kt:34-70） | |
| `setAppAllowlist(String)` | :135 | syncAppAllowlist | JSON `{"10123":["||x.com^"]}` **key=UID 字符串** | |
| `getMitmCACert(String)` | **未调用** | — | — | CA PEM 实际来自 `startStackMitm` 返回值 |

**完全未消费的 Engine 方法（17，逐项 grep 实测「仅命中定义行/零命中」）**：`start(long,SocketProtector)`、`setAppResolver`、`setFirewallChecker`、`setOutboundAdapter`、`setDNS`、`setTries`、`setImportantTries`、`clearMitmBlacklist`、`setHttpsBypassRules`、`getMitmCACert`、`getRouter`、`getStats`、`isDomainBlocked`、`isDomainBlockedForApp`、`isMitmActive`、`isRunning`、`isUsingTcpStack`。构造器 `Engine(int)` 亦无调用者。`LogCallback` 接口仅 server 模式用。与 AGENT_MISTAKES 铁律 2 记录一致（legacy `Engine.Start`/`SetTries` 零生产调用者）。

### 3.1 `applyDNSConfig` JSON（`normal/HttpsDnsConfigSnapshot.kt:48-90`）
```json
{"mode":"single|smart_prediction|parallel_race|primary_backup",
 "blockResponse":"NXDOMAIN|NODATA|REFUSED|CUSTOM_IP",
 "dynamicResponse":{"enabled":bool,"requestThreshold":n,"windowSeconds":n,"nxDomainDurationSeconds":n},
 "cache":{"enabled":b,"mode":s,"maxTtlSeconds":n,"fixedTtlSeconds":n,"minTtlEnabled":b,"minTtlSeconds":n,
          "staleFallbackEnabled":b,"staleFallbackSeconds":n,"negativeTtlEnabled":b,"negativeTtlSeconds":n},
 "providers":[{"id":..,"protocol":"PLAIN|DOH|DOT","server":"host:port|''","url":..}],
 "bootstrap":{"enabled":b,"ips":[{"id":..,"name":..,"ip":..}]}}
```
`mode.storageValue`（ui/DnsResolutionMode.kt:15-18）与 Go 解析值（`Android/tunnel/dns_config.go:94-100`）**逐字相符**。`SINGLE` 时快照只保留 `providers.first()`（:34）；`require(providers.isNotEmpty())`（:33）。`BlockResponseMode.ZERO_ADDRESS → "CUSTOM_IP"`（:107）与枚举名不同。

### 3.2 `DomainChecker` 8 个回调（`GoInspectionTunnel.kt:226-254`）
`checkDomain(domain,appName)`→命中规则串或 `""`；放行且**显式允许**返回 `"__ALLOW__"`（:230），无规则返回 `""`。`hasCustomRule/hasCustomRuleForApp` 返回 `Long`：`1`=屏蔽、`0`=显式放行、`-1`=无自定义规则（:238-241,249-253）。所有分支走 `DomainPolicy.evaluate`（core/rule/DomainPolicyEngine.kt:51-104，7 级优先矩阵 + LruCache 8192）。

### 3.3 UID 反查（`normal/GoInspectionResolvers.kt` 全文 32 行）
`resolveUID(protocol,localIP,localPort,remoteIP,remotePort)`→`UidPackageCache.resolveUid`（core/diagnostic/UidPackageCache.kt:120-152）→ `ConnectivityManager.getConnectionOwnerUid`，双层缓存：正例 TTL **10s**、负例 **2s**（:188-189）。`packageForUid`→`resolvePackageForUid`（:157）。gomobile 的 long/int 转换全在此文件（:19-25,31）。

## 4. 配置热更新管线

### 4.1 设置键 → 生效路径全表（每对均 grep 实测）
| 设置变更 | 发出 intent（文件:行） | `onStartCommand` 分支 | 重算段 | 最终 Go API |
|---|---|---|---|---|
| DNS 服务商增删改/选中 | `RuntimeDnsSettingsRefresher.refreshIfRunning`（core/rule/RuntimeDnsSettingsRefresher.kt:56-66），触发点 ProviderManagementViewModel.kt:73,100,128,140 | :135 `ACTION_REFRESH_RUNTIME_CONFIG` | `refreshRuntimeConfig`（DnsVpnRuntimeConfigManager.kt:81） | `applyDNSConfig` + `applyRuleSnapshot` |
| 解析模式/竞速成员 | RaceModeSettingsViewModel.kt:183,210,233,283,294 | 同上 | 同上 | `applyDNSConfig` |
| 缓存策略 | CacheSettingsScreen.kt:65,76（经 `onRuntimeDnsSettingsChanged`→SettingsRouteActivity.kt:128 或 MainActivity.kt:64-67 的 `onRefreshRuntimeDns`） | 同上 | 同上 + `dnsCache.updatePolicy`（:123,169） | `applyDNSConfig` |
| 屏蔽响应模式/动态响应 | BlockResponseSettingsScreen.kt:54,77 | 同上 | 同上 | `applyDNSConfig` |
| Bootstrap 开关/IP | BootstrapSettingsViewModel.kt:76,84,100,115 | 同上 | 同上 | `applyDNSConfig` |
| 域名规则总开关 | RuleControlScreen.kt:139,233 / HttpInspectionSettingsScreen.kt:236 | 同上 | `activeDomainRulesEnabled` + 快照重算 | `applyDNSConfig`+`applyRuleSnapshot` |
| 单条黑名单/白名单 | AppRuleViewModel.kt:369,377,426,433,453,458,483,488；RuleListViewModel.kt:147,151,175,179；Blacklist/WhitelistViewModel:247/271/250/278；RequestLogScreen.kt:319；DnsCacheScreen.kt:247；AgentAnalysisSheet.kt:332,349 | :144 `ACTION_SYNC_RULE` | `DnsVpnRuleSyncManager.scheduleRuleSync`（debounce） | `applyRuleSnapshot` |
| 批量导入/订阅更新/清洗 | `refreshRuleIndexesIfRunning`（DefaultWhitelistSeeder.kt:58；SubscriptionViewModel.kt:491；SubscriptionAutoUpdateEngine.kt:236；RuleOperationWorker.kt:225；BatchRuleValidator.kt:347；DataCleanupManager:142,184,231,255,301,344；RewriteListViewModel:352；RuleManagementViewModel:98；BlacklistViewModel:470；WhitelistViewModel:496） | :154 `ACTION_REFRESH_RULE_INDEXES` | `refreshCache(forceRebuild)` 各管理器 | `applyRuleSnapshot`(+`setExtraPassthroughSuffixes`/`setRewriteRules`) |
| HTTPS URL 规则/地址规则开关 | `syncHttpsRequestRulesIfRunning`（AppRuleViewModel:212,234；RuleListViewModel:140,168；BlacklistViewModel:483；WhitelistViewModel:509；RewriteListViewModel:357；SubscriptionViewModel:493；BatchRuleValidator:331；SubscriptionAutoUpdateEngine:245；DataCleanupManager:254,351；HttpInspectionSettingsScreen.kt:172） | :166 `ACTION_SYNC_HTTPS_REQUEST_RULES` | `updateRewriteRules()` 全套 | `setRewriteRules`/`setRequestRules`/`setCosmeticRules`/`setExtraPassthroughSuffixes`/`applyRuleSnapshot` |
| 排除应用 / 禁止联网 / 检查应用 / 旁路 LAN / 出站代理开关 | `refreshAppExclusionsIfRunning`（ExcludedAppsScreen.kt:49、BlockedAppsScreen.kt:55、HttpInspectionAppsScreen.kt:44、HttpInspectionSettingsScreen.kt:124,194,211,237、OutboundProxySettingsScreen.kt:103,204、AppRuleViewModel.kt:99,321、ConfigTransferViewModel.kt:140、CaCertificateSettingsScreen.kt:80、DataCleanupManager:385,394,404、RuleControlScreen.kt:232） | :133 `ACTION_REFRESH_APP_EXCLUSIONS` | `configManager.refreshAppExclusions`（:204）→ **`onRestartVpn()`** | 全量重建 Builder + `startFull`（addDisallowedApplication 无法热改） |
| 应用域名放行名单（app allowlist） | `refreshAppAllowlistIfRunning`（AppRuleViewModel.kt:333,342,351,372,382；ConfigTransferViewModel.kt:143；DataCleanupManager:395） | :134 `ACTION_REFRESH_APP_ALLOWLIST` | `refreshAppAllowlist`（:217） | `setAppAllowlist`（**不重建隧道**） |
| 通知速率/文案 | DnsVpnService.refreshNotification（NotificationSettingsScreen.kt:94,131） | :119 `ACTION_REFRESH_NOTIFICATION` | 起停 speedMonitor | 无（仅通知） |
| 悬浮日志设置/前后台 | :138 / :139 | — | FloatingLogOverlay | 无 |

关键区分：**排除应用类变更 = 重建整条 VPN（`restartVpnLocked` DnsVpnService.kt:345-349 = stopInspectionDataPlane + disconnectVpnInterface + startVpn）**；allowlist 类 = 仅一次 `setAppAllowlist`。UI 提示语也据此写（ExcludedAppsScreen.kt:51「DNS VPN 正在重连」）。

### 4.2 `RuntimeConfigCommitPolicy`（`normal/RuntimeConfigCommitPolicy.kt` 全文 33 行）
判定纯函数 `committedResolutionMode(current, requested, applied) = if (applied) requested else current`（:31-32）。用点 `DnsVpnRuntimeConfigManager.kt:127-131`：`applied = goSyncError == null`。理由（KDoc :4-21，O-103）：`activeResolutionMode` 是「对引擎在跑什么」的声明，供应商解析失败分支（:144-173）会用**旧 providers** 重新 sync（即旧模式），此时提交新模式会让通知/UI 撒谎。失败分支显式**不写** `activeResolutionMode`（注释 :159-163）。成功路径顺序：`syncDnsConfig`+`pushRuleSnapshot`（:105-114）→ 提交 cache/block/bootstrap（:117-123）→ 提交 mode（:127）→ 若 error 则只刷通知并 return（:132-136）→ 才提交 providers（:137）。

`Intent` 临时 provider 覆盖：`DnsVpnIntentFactory.startIntent(context, provider)`（:42-58）可塞 `EXTRA_DOH_URL/EXTRA_DNS_PROTOCOL/HOST/PORT/NAME`，`DnsVpnProviderResolver.resolveDnsProviders`（:21-52）优先取 Intent（id 走 `runtimeCustomProviderId`），无则按模式取多 providers（`size>=2` 才生效，:63,68），兜底 `loadSelected`（:71）。**实测生产调用点均不传 provider**（MainVpnController.kt:155、DitingTileService.kt:117、OutboundProxySettingsScreen.kt:101）→ 该参数仅测试/未来用途。

## 5. 规则同步链（DB → mmap trie → snapshot JSON → Go）

```
Room DB（blockRuleDao/allowRuleDao/rewriteRuleDao）
  BlockListManager/AllowListManager/RewriteRuleManager（DnsVpnDatabaseComponents.kt:91-93 构造，注入 File(filesDir,"rule-index")）
    refreshCache() → 写 mmap 产物 + 内存兜底 map
    RuleIndexLayout（core/rule/RuleIndexLayout.kt）路径契约：
      filesDir/rule-index/domain/block.trie          ← blockIndex
      filesDir/rule-index/domain/block.important.trie ← blockImportantIndex
      filesDir/rule-index/domain/allow.trie
      filesDir/rule-index/domain/allow.important.trie
      filesDir/rule-index/hosts/rewrite.trie
      （极速模式另在 filesDir/rule-index/express/，rootDirectory :44）
  DomainPolicy.buildRuleSnapshotJson(ruleIndexDirectory)（core/rule/DomainPolicyEngine.kt:118-255）
    仅当 trie 存在且 length>0 才写路径键（:123-145）；否则退回全量数组
    JSON: filterEnabled / blockTriePath / importantBlockTriePath / allowTriePath / importantAllowTriePath
          / globalAllow / globalBlock / globalImportant
          / appRules{pkg:{allow,block,important}}
          / invertedBlock[] / invertedAllow[] {pattern,source,important,excludedApps}
          / specialBlock[] / specialAllow[] {pattern,source,important,appScope,appInverted,isWildcard,denyallow,isRegex,dnsType}
          / disabledRules[]
  GoTunnelRuleManager.pushRuleSnapshot()（:41-53，Dispatchers.IO）→ engine.applyRuleSnapshot(json)
  Go 侧 policyEngine.snapshot（Android/tunnel/policy_engine.go:58-75 字段一一对应；LoadMmapTrie engine_rules.go:55,71，domain_trie.go 只读 mmap）
```

`importantAllowTriePath` 注释（DomainPolicyEngine.kt:137-141）指出：订阅的 important allow 规则**只存在于该 index**，`AllowRuleCache` 导出兜底列表时会丢弃它们——漏传即静默丢失。这是路径契约的硬约束，Flutter 侧必须同样「按布局生成路径，不手写文件名」。

初始化时序：`DnsVpnDatabaseComponents.initialize`（:77-156）在 `onCreate` 里跑，`rulesInitializationJob`（:142-151）并发刷三类缓存→`domainPolicy.invalidateCache()`→`onRulesReloaded`（DnsVpnService.kt:106-113 → `updateRewriteRules()` + `clearDnsCache()`）。`startVpn` 末尾再 `join()` 后补一次 `pushRuleSnapshot`（:337-342）。`blockListManager.onCacheChanged / allowListManager.onCacheChanged → domainPolicy.invalidateCache()`（:95-96）。

增量同步：`DnsVpnRuleSyncManager.scheduleRuleSync`（:25-65）用 `pendingRuleSyncs` map + 单 Job 循环 debounce；只接受 `ruleType ∈ {block, allow}` 且 pattern 非空（:35）；每轮 `refreshMutex.withLock` 内 `syncCachedPattern` 后 `pushRuleSnapshot`（:54-58）。`refreshRuleIndexes`（:70-96）按 `refreshBlock/Allow/Rewrite` 三 flag 分别 `refreshCache(forceRebuild=true)`，allow 侧顺带 `updatePassthroughRules`（:88），rewrite 侧顺带 `updateRewriteRules`（:91），末尾统一 `pushRuleSnapshot`（:93）。

## 6. MITM / HTTPS 检查

### 6.1 启用条件（三与门，`DnsVpnService.kt:240-242`）
```kotlin
inspectionConfigured = isHttpInspectionEnabled && getHttpInspectionAppPackages().isNotEmpty()
inspectionRequested  = inspectionConfigured && isHttpsInspectionCertificateInstalled(this)  // 读缓存位 https_inspection_ready && backend=="go-v1"
```
`AppRulesSettingsStore.isHttpsInspectionReady`（ui/settings/AppRulesSettingsStore.kt:246-251）双条件（ready + `GO_CA_BACKEND="go-v1"` :40），防止旧后端残留。`inspectionRequested` 才进 `GoInspectionTunnel(inspectionEnabled=…)` → `startStackMitm` + `setMitmAllowedUIDs`（GoInspectionTunnel.kt:363-366）。
证书真查在 `DnsVpnTunnelManager.kt:73-93`（异步 IO 查 `AndroidCAStore`）；与缓存位不一致 → `shouldRestartForCertificateStateMismatch`（:353-356，纯异或）→ `restartForCertificateMismatch`（DnsVpnRuntimeConfigManager.kt:192-202，加 `refreshMutex` 后 `restartVpnLocked`）。查不到 CA 还会**反向关掉开关**（`setHttpInspectionEnabled(false)` :83）。

### 6.2 CA 生命周期（`core/cert/GoInspectionCaManager.kt` 全文 64 行）
- 目录 `filesDir/go-mitm`（:16，`mkdirs()`）。
- `certificatePem`（:18-29）：**临时 Engine** `startStackMitm(dir)` 的返回值即 PEM，随后 `stopStackMitm()` + `stop()`；KDoc :19-21 明确不 teardown 会每次调用泄漏一个 cleaner goroutine。**注意：CA 内容并非来自 `getMitmCACert`**——Go `StartStackMitm` 自己 `return certMgr.GetCACertPEM()`（engine_mitm.go:21），Kotlin 直接消费返回值。
- `isInstalled`（:33-40）：`AndroidCAStore` 里 `user:` 前缀别名逐个 SHA-256 指纹比对期望指纹；指纹格式 `%02X` 冒号分隔（:60-62）。
- `reset`（:48-52）：只删 `ca.crt/ca.key/mitm_blacklist.txt`。
- UI（`normal/ui/CaCertificateSettingsScreen.kt`）：导出用 `CreateDocument("application/x-x509-ca-cert")`（:130-134）+ `exportCertificateToUri`（GoInspectionCaManager.kt:42-46），随后跳 `ACTION_SECURITY_SETTINGS`（:117），返回后 `securitySettingsLauncher` 自动重验（:84-95）；`applyCertificateReadiness`（:74-82）未就绪即关开关并 `refreshAppExclusionsIfRunning`。指南屏 `CaCertificateGuideScreen.kt`（205 行）为纯静态文案（各机型路径 :92,:111 + 安全提示 :124）。重置确认 :225-251。

### 6.3 旁路名单与规则门
- `setExtraPassthroughSuffixes`（GoTunnelRuleManager.kt:64-73）＝ `DefaultWhitelistSeeder.parseAssetWhitelist(context).map{first}`（assets **`https_passthrough.txt`**，core/rule/DefaultWhitelistSeeder.kt:119-140，支持 `#`/`//` 分类头）+ `AppRulesSettingsStore.getHttpsBypassRules`（KEY_HTTPS_BYPASS_RULES，:231-244），`\n` 连接。
  **`setHttpsBypassRules`（Engine 的 Go API）零 Kotlin 调用**；`AppRulesSettingsStore.setHttpsBypassRules`（:239）也无任何调用点 → 自定义 HTTPS 旁路当前无 UI 写入口，仅导出/导入与清空（:449 remove）会碰。→ 待定。
- 三层门（updateRewriteMap，:82-97）：`isDomainRulesEnabled` 决定 ipRewrites；`inspectionEnabled && isAddressRulesEnabled` 决定 cnameRedirects；两者合并进同一 JSON，ipRewrite 先写（CNAME 只在 key 不存在时补，:92）。
- `updateRequestRules`（:99-110）与 `updateCosmeticRules`（:112-123）**未通过门就推空串**（清空 Go 侧），避免旧规则残留。
- 双向耦合 UI：开 MITM 而域名规则关 → `DomainRulesLinkageKind.ENABLE_BOTH` 弹确认（HttpInspectionSettingsScreen.kt:118-120,227-241）；关域名规则而 MITM 开 → `DISABLE_BOTH`（RuleControlScreen.kt:134-136,225-238）。

### 6.4 QUIC / 加密 DNS / 日志回调链
- QUIC：`filterHttp3` 读 `isHttp3InspectionEnabled`（KEY :27）→ `setFilterHttp3`（:367）。语义「阻断 QUIC 促回退 TCP」（UI subtitle :187）。
- DoT：`blockEncryptedDns` → `setBlockEncryptedDns`（:368），阻断 TCP 853。
- **两者都是构造参数**（DnsVpnTunnelManager.kt:302-303），其变更走 `refreshAppExclusionsIfRunning` → **整隧道重建**，而非单独 setter。
- DNS 日志：`setBatchLogCallback`(GoInspectionTunnel.kt:261-268) → `GoTunnelLogProcessor.processLogBatch`（:24-100）。JSON 短键（:32-42）`d/b/t/r/a/i/k/e/c/ts/ttl`。分类（:44-49）`e非空→ERROR`、`k.startsWith("rewrite=")→REWRITTEN`、`b→BLOCKED`、否则 PASSED。屏蔽来源归因（:55-60）用 `dnsPolicy.evaluate` 补 `app rule`/`global rule` 标签，订阅 ID 优先取 `decision.source`，退回从 `k` 里解析 `sub_<id>`（:117-124）。写库经 `DnsLogger.logBatch`（批量 50 条，core/log/DnsLogger.kt:186）；仅 `dnsLogger.isLoggable(result)` 才入库（:72）。
- **TTL 契约（O-107）**：`upstreamTtlFrom`（:163-164）**区分「无 ttl 键」与「ttl=0」**，前者/后者都回 `TTL_UNKNOWN`，但只在 `has("ttl")` 时用 `optLong`——Go 侧 `json:"ttl,omitempty"` 会删 0，故 Kotlin 必须用 `has` 判定（注释 :155-162）。
- HTTP 日志：`setHttpLogCallback`（:336-357）5 参（package/authority/protocol/outcome/matchedRule）→ `outcome.toHttpRequestOutcome()`（:143-153，8 个显式串 + else ALLOWED）→ `resolveHttpBlockSubscriptionId` → `httpRequestLogger.log`。
- 竞速/Bootstrap：`setRaceLogCallback`（:269-309）用 `dnsConfig.providers.associateBy{it.id}` 把 Go 的 provider id 映射回名字（:287-289）；`setBootstrapLogCallback`（:310-335）同时喂 `bootstrapHealthEngine.recordResult` 与 `bootstrapLogger.log`。
- 流量：`setTrafficCallback` → `TrafficStatsManager.onGoTrafficTick(jsonDeltas)`（core/traffic/TrafficStatsManager.kt:184-215，JSON 数组 `[{uid,tx,rx}]`）。

## 7. 前台通知 / 保活 / 省电 / 网络变化

- **前台**：`promoteToForeground()`（DnsVpnService.kt:187-211）在 `onStartCommand` **最先**执行（注释 :171-176 说明原因）；Android 14+ 带 `FOREGROUND_SERVICE_TYPE_SPECIAL_USE`，失败退回无 type（:206）。通知 ID 1001（VpnNotificationBuilder.kt:25），`FOREGROUND_SERVICE_IMMEDIATE`、`setOngoing`、`BigTextStyle`、`setOnlyAlertOnce`（:83-86）。Manifest：`android:foregroundServiceType="specialUse"` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE=vpn` + `BIND_VPN_SERVICE` + intent-filter `android.net.VpnService`（AndroidManifest.xml:31-42）。
- **通知内容**：主文本优先级 = 代理错误 > 代理连接中 > 自定义文案 > 默认（VpnNotificationBuilder.kt:39-54）；默认文案按 provider 数分支（:95-106）；速率后缀 `↑ x ↓ y`（:57-63,112-119）。刷新条件 `vpnInterface != null`（DnsVpnService.kt:352）。
- **速率采样**：`VpnSpeedMonitor`（notification/VpnSpeedMonitor.kt:36-60）亮屏 2s / 熄屏 15s（:72-73），仅格式化文本变化才 `notify`（:55-57）。
- **保活**：`START_STICKY`（DnsVpnService.kt:180，所有分支统一返回，含 ACTION_* 非启动分支——重启时 `startIntent` 为 null，`startVpn(null)` 会走 `resolveDnsProviders(context,null)` 读持久设置，可接受）。常驻「未连接」通知由 `VpnMonitorService` 承担（`VpnMonitorManager.onVpnStarted` 停 / `onVpnStopped` 恢复，notification/VpnMonitorManager.kt:208-217）。**无 watchdog 自动重启 normal 服务**：`ExpressLifecycleGuard`（express/ExpressLifecycleGuard.kt）不引用 normal；`VpnMonitorService` 仅在 VPN 停止时**关掉自己**（:74），不重启 VPN。
- **省电**：`DnsVpnPowerOptimizer`（:32-63）注册 `SCREEN_ON/OFF` receiver（仅注册成功才置标志 :40-43），亮屏 `setTickIntervalMs(1000)`、熄屏 10000（:60-62,67-68）+ `TrafficStatsManager.setScreenInteractive`。`register()` 每次 VPN 启动都重新同步当前屏幕态（:44-49，注释说明覆盖「排除应用重建」）。
- **网络变化**：`DnsVpnNetworkMonitor`（:23-57）监听 WIFI/CELLULAR/ETHERNET 的 available/lost/linkProperties/capabilities → `scheduleIpv6AdaptationCheck`，但**当前实现是空操作**（:69-73：注释「AUTO 模式下 IPv6 稳定配置，避免抖动重连」，`onNetworkChanged` 默认 null，DnsVpnService.kt:57 未传）→ 实际**不重启隧道**。这是有意的设计（防 IPv6 泄漏与抖动），非缺陷，但意味着 IPv6 模式变更只能靠下次启动。
- **停止/销毁**：`stopVpn`（:367-384）顺序＝speedMonitor.stop → overlay → powerOptimizer.unregister → networkMonitor.stop → 置标志 false → **disconnectVpnInterface（releaseTun+close）** → 广播 → `stopInspectionDataPlane`（engine.stop+stopStackMitm）→ flush 日志 → stopForegroundCompat → 取消 monitor → stopSelf。`onDestroy`（:394-416）用**独立 `shutdownScope`**（:49-51 注释：serviceScope 已被 cancel，最后的日志 flush 必须能跑完）。`onRevoke`（:386-392）置 `wasStopped=false` 后 `stopVpn()`，使 onDestroy 走广播分支。
- **状态判定**：`DnsVpnStatusNotifier.isRunning`（:32-40）= prefs `dns_vpn_prefs/vpn_running` **与** 进程内 `isServiceAlive` 双条件，且发现「标志 true 但服务已死」会**自愈写回 false**。广播 `ACTION_VPN_STATUS_CHANGED` 用 `package=` 自限（:20-24）+ 触发 QS 磁贴刷新（QuickSettingsTileUpdater，:24）。
- **模式互斥**：`WorkModeLifecycleRegistry`（core/WorkModeLifecycleRegistry.kt:12-23 startNormalMode / :25-32 stopNormalMode）与 `VpnStateRegistry.isNormalRunning`（:10-13）都是**默认 lambda**，由 `DnsVpnService.init{}`（:454-465）在类加载时用真实实现覆盖（含 `stopNormalMode`、`updateNormalFloatingLogAppState`、`setNormalRunningFlag`）——即「未加载过 normal 类则退回读 prefs 标志」。`stopOtherModes`（:69-84）在 NORMAL 下停 server+express；express 启动时经 `ExpressModeLauncher.kt:42 stopOtherModes(EXPRESS)` 停 normal。`MainWorkModeCoordinator.switchWorkMode`（main/MainWorkModeCoordinator.kt:82-115）在切到 DNS 时 `onStop()`+`VpnMonitorManager.stop`，切到 EXPRESS 时 `ExpressModeLauncher` 负责停 normal。

## 8. 关键源码引证表

| 主题 | 路径:行 |
|---|---|
| onStartCommand 动作全集（10 个） | normal/DnsVpnService.kt:116-181 |
| ACTION 常量定义 | normal/DnsVpnIntentFactory.kt:14-40 |
| Builder 参数 | normal/DnsVpnTunnelManager.kt:186-250 |
| 绕过 LAN 50 条路由 | normal/DnsVpnTunnelManager.kt:364-415 |
| IPv6 GUA 判据 | normal/DnsVpnTunnelManager.kt:142-164 |
| fd→Go / protect 回调 | normal/GoInspectionTunnel.kt:91-99 |
| configureEngine 内 18 次 engine.* 调用 | normal/GoInspectionTunnel.kt:199-374 |
| Engine 实例 + ruleManager/logProcessor | normal/GoInspectionTunnel.kt:70-88 |
| 规则同步器 6 个 Go 推送点 | normal/GoTunnelRuleManager.kt:41-136 |
| DNS 批日志解码 | normal/GoTunnelLogProcessor.kt:24-100,163-164 |
| 热更新主流程 | normal/DnsVpnRuntimeConfigManager.kt:81-185 |
| 提交判定 | normal/RuntimeConfigCommitPolicy.kt:31-32 |
| 快照 JSON schema | normal/HttpsDnsConfigSnapshot.kt:48-90 |
| 跨模式 intent 派发中心 | core/rule/RuntimeDnsSettingsRefresher.kt:35-182 |
| rule-index 路径契约 | core/rule/RuleIndexLayout.kt:27-81 |
| 快照生成 | core/rule/DomainPolicyEngine.kt:118-255 |
| CA 生命周期 | core/cert/GoInspectionCaManager.kt:16-52 |
| 前台通知构建 | normal/notification/VpnNotificationBuilder.kt:30-119 |
| 电池/屏幕 | normal/DnsVpnPowerOptimizer.kt:32-63 |
| 组件装配 | normal/DnsVpnDatabaseComponents.kt:77-156 |
| 启动门（minApi29+64 位） | ui/mode/AppWorkMode.kt:20-25,48-61 |
| 服务声明 | Android/app/src/main/AndroidManifest.xml:31-42 |
| gomobile 接口签名 | `Android/app/libs/tunnel.aar` → classes.jar（本会话 javap 实测 54 个 native 方法名） |

## 9. Flutter 重构注意

本域即未来 Flutter 版「Android 平台包」的主体（Dart 侧不可能实现的都在这）。**确证过的映射**：

1. **必须留在 Kotlin/Java（Android framework API）**：`VpnService.prepare`（MainVpnController.kt:97）、`Builder` 全部参数、`establish()` 返回的 `ParcelFileDescriptor`、`protect(fd)`（VpnService 实例方法，`GoInspectionTunnel.kt:95`）、`startForeground(type)`、`ConnectivityManager.getConnectionOwnerUid`（UidPackageCache）、`AndroidCAStore` KeyStore 读取（GoInspectionCaManager.kt:35）、`registerReceiver(SCREEN_ON/OFF)`、`NotificationCompat`/渠道、`PackageManager.getPackageUid`（GoInspectionTunnel.kt:377）、`addDisallowedApplication`。
2. **tun fd 传递**：现有实现是「同进程 gomobile 直接传 int fd」。Flutter 下若 Go 引擎仍以 AAR/插件形式同进程存在，可原样保留；**不要**改成 fd 跨进程传递（`ParcelFileDescriptor` dup 语义 + `setBlocking(true)` 的组合已被现有代码依赖）。若 Go 移到独立插件进程，`protect()` 回调必须回主进程 → 一次 binder 往返/包，需实测吞吐（当前 `SocketProtector` 是每 socket 一次回调，GoInspectionTunnel.kt:94-96）。
3. **可上移到 Dart 的判据 = 是否依赖 Android framework API**：
   - 纯策略可上移：`HttpsDnsConfigSnapshot.toJson`（仅 org.json）、`RuntimeConfigCommitPolicy`（已「Android-free 可 JVM 单测」，KDoc :20-21 自述）、`GoTunnelLogProcessor` 的 JSON→实体映射、`DomainPolicyEngine` 7 级优先矩阵与快照 JSON 生成、`OutboundProxyConfig.validationError` 中除 `getApplicationInfo` 外的规则、debounce 调度骨架（`DnsVpnRuleSyncManager`）。
   - 不可上移：一切含 `Context/PackageManager/KeyStore/ConnectivityManager/NotificationManager` 的路径。
   - 中间态：UID↔包名映射与 5-tuple 反查必须留在平台侧，但**接口形状已确定**（`resolveUID(protocol,ip,port,ip,port)->Long`、`packageForUid(Long)->String`），直接做成 MethodChannel/FFI 回调即可；TTL 10s/负例 2s 缓存（UidPackageCache.kt:188-189）也应保留在平台侧。
4. **命名/契约要冻结**：`rule-index/domain/*.trie` 五文件布局 + JSON 短键（`d/b/t/r/a/i/k/e/c/ts/ttl`）+ `mode.storageValue` ↔ Go 枚举串（§3.1）+ `ZERO_ADDRESS→CUSTOM_IP` 这类映射（HttpsDnsConfigSnapshot.kt:107）都是**跨语言契约**，重构时以现有 Go 结构体（policy_engine.go:58-75 / dns_config.go:33）为准逐字对齐，不要「顺手改名」。
5. **架构债（重构时一并处理）**：
   - `DnsVpnService.kt` **560 行 > AGENTS.md 的 550 行上限**——本域唯一越线文件。
   - `GoInspectionTunnel.getDnsCacheStats()`（:118-120）用**反射**取 `getDNSCacheStats`，且**全仓零调用者**（实测 `grep "\.getDnsCacheStats()"` 仅命中定义行）→ 死代码 + 反射掩盖绑定缺失。
   - `ui/MainViewModel.kt:203 toggleVpn()` **零调用者**（实测 `grep -rn toggleVpn` 于 main+test 仅命中定义本身与 `DitingTileService.toggleVpnService` 的同名前缀），故 `WorkModeLifecycleRegistry.startNormalMode`（core/WorkModeLifecycleRegistry.kt:12-16，反射式 `setClassName` 构造 intent）只有这一个死调用者＝**未走的路径**；`stopNormalMode` 则相反，是活的（:18-23 被 `stopOtherModes` :76/:80 调用 → ExpressModeLauncher.kt:42）。真实启动统一走 `MainVpnController` → `DnsVpnService.startIntent`（:155）。两套启动路径并存，Flutter 重写时只保留一套。
   - `DnsVpnService.protectSocket(Socket/Int)` 伴生对象两个方法（:544-550）**零外部调用者**（实测 grep 无命中；极速模式用自己的 `ExpressVpnService.protectSocket`）→ 死代码。
   - `DnsVpnService` 伴生的 `refreshRuntimeConfigIntent/syncRuleIntent/refreshRuleIndexesIntent/syncHttpsRequestRulesIntent/refreshAppExclusionsIntent/refreshAppAllowlistIntent`（:474-507）**全部零调用者**——真实派发走 `RuntimeDnsSettingsRefresher`（按字符串 action，core/rule/RuntimeDnsSettingsRefresher.kt:19-33）。两套并存的 intent 工厂是「同一 action 字符串两处定义」的隐患源。
   - `Engine.start(long,SocketProtector)`、`setDNS/setTries/setImportantTries/setAppResolver/setFirewallChecker/setOutboundAdapter/clearMitmBlacklist/setHttpsBypassRules/getMitmCACert/getStats/is*` 在 Kotlin 侧无消费者（§3 表）：Flutter 重绑定时应以「本清单」裁剪 gomobile 导出面，而非按 Go 导出全量生成。
   - IPv6 地址前缀：KDoc 说 `/128`、代码 `addAddress(VPN_ADDRESS_V6, 64)`（:195）——以代码为准，需真机确认语义。
   - `start()` 返回 true 不代表 Go 真跑起来（§2.2）。
   - `DnsVpnNetworkMonitor` 的回调链是空实现（§7），要么实现 IPv6 自适应、要么删除，避免「看起来有守护」。

**待定清单**（未经真机/构建验证，不得当作结论）：
1. `addAddress(fd00:abcd::2, /64)` 与注释 `/128` 的差异是否影响 IPv6 DNS 行为——需真机 `ip -6 addr`。
2. `bypassLan` 关闭分支下 `allowFamily` 与路由的组合是否覆盖 link-local IPv6（代码只在 enableIpv6 时加 `::/0`，:227-229）。
3. `START_STICKY` 系统重启服务时 `startIntent=null` → `resolveDnsProviders(context,null)` 的 provider 是否与停止前一致（无 intent 覆盖）。
4. `ACTION_*` 广播式 intent 走 `startService`（RuntimeDnsSettingsRefresher.kt:62）而非 `startForegroundService`：Android 12+ 后台启动受限，若服务已被系统杀掉会 `IllegalStateException` 并被 `runCatching` 吞掉（仅日志）——即「设置改了但没生效」。是否需要在 Flutter 版改为「先判 isRunning 再 startForegroundService」待产品决定。
5. `setExtraPassthroughSuffixes` 与 `Engine.setHttpsBypassRules` 两条旁路通道谁生效（前者有调用、后者零调用）——Go 侧语义归第 10 章确认。
6. 自定义 HTTPS 旁路规则（`AppRulesSettingsStore.setHttpsBypassRules`）确无 UI 写入口——是遗漏还是刻意待「待定」。
7. `inspectionEnabled` 为构造期常量（GoInspectionTunnel.kt:80 传入 ruleManager），运行中开/关 MITM 依赖整隧道重建（排除应用通道），无更轻路径。
