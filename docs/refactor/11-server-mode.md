---
所属系列: DITING Android Flutter 重构功能图谱
章: 11
最后校验: 2026-10-18
口径: server 23 文件（任务书预估 22，实测主源码 23 + 单测 5）+ 关联入口全部点名；数字均为本会话工具实测
---

# 11. 服务器模式（server）——把 Android 设备变成局域网 DNS 服务器

## 1. 概述

### 1.1 设计意图：独立 Activity 的进程内子应用
服务器模式（代码内称 DNS 模式 / `AppWorkMode.DNS`，storageValue `"dns"`）把本机变成局域网 DNS 服务器：Go 引擎在 `0.0.0.0:<port>` 与 `[::]:<port>` 上同时监听 UDP/TCP，局域网其他设备将 DNS 指向本机 IP 即可享受解析、缓存、规则拦截与 hosts 覆写；本机自身流量不经过该服务（首页说明文案 `server/ui/DnsHomeScreen.kt:216`）。

三模式架构上，server 与 express/normal 平级，由 `ui/mode/WorkModeStore`（prefs `diting_settings` / 键 `app_work_mode`，`ui/mode/WorkModeStore.kt:6-8`）持久化选择。`DnsModeService` 是 server 域唯一常驻组件；UI 侧曾为独立 Activity，现仅存壳：

- `server/DnsMainActivity.kt`（32 行）是**兼容性跳板**（:10-12 类注释）：onCreate 即转发 `Intent(this, MainActivity)` + CLEAR_TOP|SINGLE_TOP + 透传 extras，随即 finish（:18-24）。DNS 模式现已"原生嵌入 MainActivity"（Single-Activity 架构）。
- MainActivity 经 `main/MainModeDispatcher.kt:71-78`：`AppWorkMode.DNS -> DnsModeHost(...)`，把 server UI 嵌入主 Activity 的 Compose 树——server 是一棵**进程内独立路由树**（HorizontalPager + 枚举路由），与 normal/express 的导航互不共享。
- `DnsMainActivity` 仅剩两个真实引用点：前台通知 contentIntent（`server/backend/DnsModeService.kt:307`）与 Manifest 注册（`AndroidManifest.xml:139-144`，singleTask、exported=false）。其 `companion.createIntent` 返回的其实是 MainActivity 的 Intent 且全仓无调用者（`DnsMainActivity.kt:27-31`，死 API）。`SettingsRouteActivity.kt:28-29` 对 `DnsMainActivity`/`DnsModeManager` 的 import 为**残留未用**（全文各仅命中 import 行一次）。

### 1.2 与 Go standalone 数据面的分工
控制面（本文）= Kotlin：状态机、prefs、前台服务、规则快照构建；数据面 = Go `tunnel`（归第 10 章 `docs/refactor/10-go-tunnel-engine.md`，未生成，此处只引用桥接边界不展开）。唯一调用点：`server/backend/DnsServerEngine.kt:42 engine.startStandalone(port.toLong())` 与 `:56 engine.stopStandalone()`——`StartStandalone` 在 Go 侧定义于 `tunnel/engine_standalone.go:399`，全仓（含 gomobile/Kotlin/测试）生产调用者仅此一处（本会话 grep 双向核验）。gomobile 绑定实测（javap `app/libs/tunnel.aar` 内 classes.jar）：`startStandalone(long) throws Exception` / `stopStandalone()` 为 server 专属；`start(long,SocketProtector)`/`startFull`/`startStackMitm` 属 normal/express。

### 1.3 模式门禁与入口全链
- 设备门禁：`AppWorkMode.DNS` 的 `minApiLevel=29`（`ui/mode/AppWorkMode.kt:34`）——app minSdk 24 但服务器模式选择卡片在 API<29 设备显示不可用（`ui/mode/WorkModeComponents.kt:104 isSupportedOnCurrentDevice()`）。无额外 ABI 要求（EXPRESS 才有 64 位判定）。
- 进入路径共 4 类（全部实测点名）：
  1. `ui/mode/WorkModeActivity.kt:69-82` 选择模式 → `returnToMainActivity`(:90-99) 带 `EXTRA_WORK_MODE_CHANGED`+`EXTRA_TARGET_WORK_MODE` → `main/MainWorkModeCoordinator.kt:67-81 handleWorkModeChangeIntent` → `switchWorkMode`(:83-117)：进 DNS 时 `onStop()`（停 VPN）+ `VpnMonitorManager.stop`(:107-110)；离开 DNS 时 `DnsModeManager.stopService`(:96-97)。
  2. 首页 topbar 切换按钮 `Icons.Default.SwapHoriz → onSelectMode`（`server/ui/DnsMainScreen.kt:132-141`）→ `MainNavigationCoordinator.launchModeSelection`(:78-80) → WorkModeActivity。
  3. QS 磁贴：`tile/DitingTileService.kt:67 AppWorkMode.DNS -> toggleDnsService()`(:73-88)，直控 `DnsModeManager.start/stopService`。
  4. 通知/自动启动：`main/MainVpnController.kt:62-67 handleAutoStartIfNeeded`（`EXTRA_AUTO_START_VPN` 且当前模式 DNS → `DnsModeManager.startService`）；`onToggleVpn` 在 DNS 模式直接 return（:80）。
- 互斥：`core/WorkModeLifecycleRegistry.stopOtherModes`（:69-84）DNS↔VPN 互停；进入 EXPRESS 也会停 server（`express/ExpressModeLauncher.kt:42 + :110`，且从设置页切回时若前模式是 DNS 会重建 MainActivity 任务栈 NEW_TASK|CLEAR_TASK）。
- 权限模型：server 模式 VPN 不适用（`permission/AppPermission.kt:91,104,108`）、悬浮窗不适用；就绪评估跳过 VPN 检查（`permission/ModeReadinessState.kt:36-40`）；常驻通知监视器在 DNS 模式下判定应停（`notification/VpnMonitorService.kt:71`、`VpnMonitorManager.kt:220`）。

## 2. 启动/停止全链路时序

### 2.1 手动启动（UI → Go）
1. `PowerToggleButton`/磁贴/ON_RESUME 自愈 → `DnsMainViewModel.toggleService`（`viewmodel/DnsMainViewModel.kt:62-64`）→ `DnsModeManager.toggleService`（`backend/DnsModeManager.kt:105-113`；STARTING/STOPPING 期间点击被忽略防重复 intent）。
2. `DnsModeManager.startService`（:75-86）：RUNNING/STARTING 早退；置 `_status=STARTING`；**先持久化 `service_active=true`**（:78，为开机自启与 START_STICKY 重启留判据）；`ContextCompat.startForegroundService(ACTION_START)`；抛异常（如后台 FGS 限制）→ `_status=ERROR` + 回滚 service_active（:81-85，中文错误键「DNS 服务启动失败」）。
3. `DnsModeService.onStartCommand` ACTION_START（`backend/DnsModeService.kt:72-83`）：先 `startForegroundServiceInternal()` 立即入前台（:282-299）；若引擎已在（START_STICKY 重启场景）不重建（避免掉缓存/短暂释放端口），仅补发 `onServiceStarted()` 同步状态（:74-81）。
4. `startDnsEngine()`（:119-204）顺序关键：`startJob?.isActive` 防重入（:122）→ `startGuard.beginStart()` 取令牌（:123，`backend/DnsModeStartGuard.kt:25-29` 代际计数）→ `acquireLocks()` PARTIAL_WAKE_LOCK `Diting:DnsModeWakeLock` + `WIFI_MODE_FULL_HIGH_PERF` `Diting:DnsModeWifiLock`（:247-271，均非引用计数）→ `DnsQueryFilter` 懒建（:126）→ **先加载规则再绑端口**（:128-133，失败→`onServiceError("DNS 规则加载失败，请重试")`+回滚 service_active+stopSelf）→ 停等后复查令牌（:136）→ **此刻才读 config/upstream**（:144-145，规则加载慢窗口内提交的变更由此兜住）→ 旧引擎 stop、新引擎构造（:147-160）→ `engine.start()` 非挂起绑口 → 二次令牌校验，失败即 `engine.stop()` 丢弃防孤儿（:166-171）→ 成功：发布 `DnsModeManager.onServiceStarted()`（RUNNING+stats ticker，`DnsModeManager.kt:115-119`）+ 磁贴刷新 + 日志（:172-178）→ 再 `reloadConfig` 比对，若启动窗口有变更则 `updateConfig`+`syncRules`（:185-196）；失败：`onServiceError("DNS 服务启动失败，监听端口可能被占用")`+回滚+stopSelf（:197-202）。
5. `DnsServerEngine.start()`（`backend/DnsServerEngine.kt:37-51`）：`configureEngine()`（:124-182 推 config JSON/开关/快照/DomainChecker/LogCallback）→ `engine.startStandalone(port.toLong())`（:42）。
6. Go `StartStandalone`（`tunnel/engine_standalone.go:399`）：清理旧监听 → `resolver.ConfigureProviders(dnsConfig.Mode, Providers)`（:429 拒绝则仅日志）→ 绑定 `0.0.0.0:port` udp4(:452-455)+tcp4(:453-459) **必须成功否则整体报错**；`[::]:port` udp6/tcp6(:469/:474) **尽力而为**，失败只 log（IPv4 成功仍可服务）。
7. 查询回调：Go `LogCallback.onDNSQuery` → `DnsServerEngine.kt:166-181`（failed=errorMessage 非空）→ `DnsModeManager.recordQuery`（:240-257，平均时延只计成功查询：SERVFAIL 最长 10s 会拖垮均值）→ StateFlow → UI。

### 2.2 停止
1. UI/磁贴/切模式 → `DnsModeManager.stopService`（:88-103）：**先 flushStats**（:89）；STOPPED/STOPPING 早退；置 STOPPING；`context.startService(ACTION_STOP)`——普通 startService 即可，仅投递成功后才清 `service_active=false`（:93-97，注释说明防"发送失败但状态谎称已停"）。
2. `onStartCommand` ACTION_STOP（`DnsModeService.kt:54-66`）：`startGuard.onStopRequested()` **先失效在途启动令牌**（绑口阻塞不可取消，见 `DnsModeStartGuard` 类注释）→ cancel startJob → 清 service_active → `stopSelf()` → 返回 START_NOT_STICKY。
3. `onDestroy`（:99-111）：isServiceAlive=false → 再失效令牌 → stopDnsEngine（`DnsServerEngine.stop()` :53-59：`stopStandalone()` 失败退化 `engine.stop()`）→ releaseLocks → scope.cancel → `flushStats` → `onServiceStopped()`（:121-128，**ERROR 态不被 STOPPED 覆盖**——启动失败原因保留可见）→ 磁贴刷新。

### 2.3 START_STICKY 重启（intent=null）
`onStartCommand` null 分支（`DnsModeService.kt:84-94`）：`DnsModePreferences.isServiceActive` 为真→前台化+（若引擎不在）走完整 startDnsEngine；为假→stopSelf+NOT_STICKY。`onCreate`（:43-50）先置 `isServiceAlive=true` 再 `DnsModeManager.initialize(this)`——注意 initialize 在 `initialized` 已真时早退（`DnsModeManager.kt:57`），未初始化过的新进程会在此读到 isServiceAlive=true 而**立即显示 RUNNING**（:64-67），由随后 ACTION_START 路径落实真引擎。

### 2.4 BootReceiver 路径
`backend/DnsModeBootReceiver.kt:17-24`，三重判定：action==`ACTION_BOOT_COMPLETED`（`AndroidManifest.xml:159`；receiver exported=false，:156-161）→ `WorkModeStore.getAppWorkMode==AppWorkMode.DNS`（:19）→ `DnsModePreferences.isServiceActive`（:20，即"用户上次留着运行"）；满足则 `ContextCompat.startForegroundService(ACTION_START)`（:22，失败仅 log）。依赖 `RECEIVE_BOOT_COMPLETED`（Manifest:17）。**冷启动安全（FGS while-in-use）约束未在此处显式处理**——失败只吞进日志，属实测行为。

### 2.5 配置热更新（ACTION_REFRESH）
`DnsModeManager.refreshEngineIfRunning`（:218-225）仅在 RUNNING 时投递（`startService`，非前台）。`onStartCommand` ACTION_REFRESH（`DnsModeService.kt:67-71`）：`refreshNotification()`（重建通知：内容含当前上游变化）+ `refreshDnsEngine()`（:210-229：loadRules → **reloadConfig 重读磁盘**（:215-219 注释：拦截响应页直写 prefs 致内存副本陈旧）→ `engine.updateConfig` → 失败=换端口重启失败 → ERROR+stopSelf；成功 → `syncRules()`）。
规则编辑侧的触发链：黑名单/白名单/Hosts/订阅/清理页完成写库后经 `core/rule/RuntimeDnsSettingsRefresher.kt`（DNS_MODE 三分支 :43/:80/:119 → `pingDnsModeFilterReload` :184-192，**判据是当前工作模式==DNS 而非服务在运行**）；拦截响应/主开关页经 `SettingsRouteActivity.kt:127-130 onRuntimeDnsSettingsChanged → refreshIfRunning(dataset)`。规则库写侧 `RuleOperationWorker.kt:157` 与 `SubscriptionAutoUpdateEngine.kt:312` 对 DNS_MODE 强制 `ruleIndexDirectory=null`（mmap 索引归 VPN 模式所有，纯内存缓存）。

## 3. 设置与模型全表

### 3.1 DnsModePreferences 键全表（文件 `diting_dns_mode_prefs`，MODE_PRIVATE，`backend/DnsModePreferences.kt:16-36`）
| 键名 | 类型 | 代码默认 | 校验/迁移 | 生效时机 |
|---|---|---|---|---|
| `selected_upstream_id` | String | `"preset_alidns_dns"`（:70） | 读回找不到 id 时 `getActiveUpstream` 回落 PRESETS.first()（`DnsModeManager.kt:70-73`） | selectUpstream→refresh |
| `local_listen_port` | Int | 1053（`DnsListenPortValidator.DEFAULT_PORT`，`model/DnsListenPortValidator.kt:10`） | 一次性迁移 `local_listen_port_migrated`：旧默认 5353/5354（mDNS 冲突）→1053（`model/DnsListenPortMigration.kt:13-20`，`DnsModePreferences.kt:49-56`） | 端口变更触发引擎 stop+start（§4.6） |
| `cache_enabled` | Boolean | true（:72） | — | applyDnsConfig cache.enabled |
| `cache_preset` | String | BALANCED（`fromStorageValue(null) ?: BALANCED`，:67-68） | 非法值回落 BALANCED | toPolicy 展开 10 字段进 Go cache |
| `cache_ttl_seconds` | Int | 300（:74） | 无校验 | **无消费者**：仅 saveConfig/loadConfig 与 `DnsServerEngine.kt:73` 的变更判定参与，Go cache JSON（:196-208）只用 preset 策略字段——实测死键 |
| `ad_block_enabled` | Boolean | false（:75） | — | 过滤主开关（§4.4 双闸门） |
| `log_queries` | Boolean | false（:76） | 一次性迁移 `log_queries_default_off`：历史 true 一律翻 false（隐私默认，:61-66） | **无消费者**（全仓仅 :58/:76/:93 与模型字段，实测死键） |
| `service_active` | Boolean | false（:139） | 启动置真/停止或失败回滚 | BootReceiver 与 START_STICKY 判据 |
| `custom_upstreams` | String(JSONArray) | null→空表 | 序列化 id/name/address/port/protocol（:152-165）；反序列化：id/name/address 任一空白**跳过该项**，port 缺省 53，protocol 未知回落 DNS，整体解析失败→空表（:167-189） | initialize 时并入 upstreams |
| `stats_query_count` / `stats_cache_hit_count` / `stats_blocked_count` / `stats_failed_count` / `stats_latency_ms` / `stats_latency_total_ms` / `stats_uptime_seconds` | Long×7 | 0 | resetStats 走 `remove`（:122-132） | ticker 每 5 秒 flush（`DnsModeManager.kt:269-271`）；stop/destroy/ERROR 即时 flush |

同一 prefs 文件内另有 7 个键由 `DnsRuleSettings` 独占读写（"单一 writer + 单一 clamp"约定，`DnsModePreferences.kt:77-81` 注释、`backend/DnsRuleSettings.kt:15-25`）：

| 键名 | 类型 | 默认 | clamp 区间（读+写双侧） |
|---|---|---|---|
| `block_response_mode` | String | `"nxdomain"`（NXDOMAIN.storageValue） | `fromStorageValue` 非法→NXDOMAIN（`core/rule/BlockResponseMode.kt:13-15`） |
| `block_response_dynamic_enabled` | Boolean | false | — |
| `block_response_dynamic_threshold` | Int | 5 | 2..100 |
| `block_response_dynamic_window_seconds` | Int | 60 | 10..300 |
| `block_response_dynamic_nxdomain_duration_seconds` | Int | 300 | 60..3600 |
| `subscription_auto_update_enabled` | Boolean | false | — |
| `subscription_auto_update_interval_hours` | Int | 24 | 1..168，越界**读侧回落默认**（takeIf 而非 coerceIn，`DnsRuleSettings.kt:95-104`；常量在 `core/rule/SubscriptionAutoUpdateScheduler.kt:35-38`） |

（Dynamic 区间常量：`core/rule/DynamicBlockResponsePolicy.kt:13-21`。）

### 3.2 端口口径（全部实测）
- **本地监听端口**：合法区间 `1024..65535`（`DnsListenPortValidator.kt:11-12`）；非数字→「端口必须为数字」，越界→「端口必须在 1024-65535 之间」；`parse` 兜底 1053。刻意 ≥1024 避开特权端口。**无占用预检**：撞口只能等 Go bind 失败→ERROR「DNS 服务启动失败，监听端口可能被占用」。不可绑定值（0/负数/<1024/>65535）显示层回退 1053 **并强制伴随警告文案**（`unusablePortWarning`，:49-54），单测 `DnsModePortAndFilterSwitchTest.kt:94` 钉死"静默回退不允许"。
- **上游端口**：合法区间 `1..65535`（`model/DnsUpstreamValidator.kt:34-40`，比本地宽）；DoH 不校验端口；空白→协议默认（DNS 53 / DoH 443 / DoT 853，`model/DnsModeModels.kt:6-9`）。

### 3.3 上游配置项
`DnsModeProtocol`：DNS/DOH/DOT（defaultPort 53/443/853；`fromStorage` 大小写不敏感，未知→DNS，`DnsModeModels.kt:6-18`）。内置 PRESETS **18 条**：6×明文 DNS（阿里 223.5.5.5、DNSPod 119.29.29.29、360 101.226.4.6、OneDNS 117.50.10.10、Cloudflare 1.1.1.1、Google 8.8.8.8）+ 6×DoH + 6×DoT（`DnsModeModels.kt:47-192`；首条即默认 `preset_alidns_dns`）。`DnsModeProtocol.MANAGED_PROTOCOLS`（:12）在 server 域**无调用者**（他处同名物是 `DnsProtocol`，勿混）。自定义上游 id 形如 `custom_<UUID>`（`DnsModeManager.kt:152`）；非 DoH 地址入库前剥外层方括号（:154-160，Go 侧再按含 `:` 自动加回，`DnsServerEngine.kt:217-227`）；删除当前选中自定义上游→回落第一 preset（:186-194）。地址校验（`DnsUpstreamValidator.kt:22-32`）：空/含空白→拒；非 DoH 含 `/`→拒；DoH 必须 `https://`+非空 host（:47-58）；含冒号者仅当**结构合法 IPv6** 才放行（`[::1]:53`、`1:2` 被拒；:80-91 用字符类+`InetAddress.getByName is Inet6Address` 双判，注释即针对 `2001:db8::1::2` 型负例；注意 `2001:db8::1:53` 作为完整 IPv6 字面量是合法地址、会被接受）。

## 4. 查询过滤链（客户端识别 → 缓存 → 规则 → 响应）

### 4.1 客户端识别与归因
Go `serveDNS`（`tunnel/engine_standalone.go:24-28,56-108`）：standalone 下 uid 恒 `UIDUnknown=-1`（`socket_uid_resolver.go:21`）；应用归因需 `AppResolver.ResolveApp(源端口,...)`，而**全仓 Kotlin 无任何 `setAppResolver` 调用**（实测），`SetFirewallChecker` 同样零调用——故服务器模式查询的 appName 恒为 `"RootProxy"`，**无设备级/应用级归因**：规则命中仅按域名全局匹配，局域网设备彼此不可区分（日志归因属第 10 章）。appAllowlist（:37）按 uid 查表，未知 uid 不在表→放行（`engine_app_allowlist.go:73-80`），对 LAN 流量实际不生效。

### 4.2 DDR 与本地资产特判
`_dns.resolver.arpa`（含后缀形）→ NXDOMAIN + blocked 计数（:110-118，RFC 9462 缓解，防 Android13+/Chrome 探测绕过）；`local.pwhs.app` → 合成 A `198.51.100.1`、AAAA 空 NOERROR（:42-54）。

### 4.3 决策优先级（Go 侧逐段实测行号）
firewallChecker（:121，server 模式恒 nil 跳过）→ rewriteIP（:129）→ rewriteCNAME（:141）→ **filterDNS 主开关闸门**（:151，关→`standaloneForward` :281 直转上游）→ PolicyEngine 快照（:156，`isActive()&&hasRules()`）→ DomainChecker Kotlin 回调（:171）→ 原生 trie/bloom（:196 起）→ 上游转发。响应缓存由 Go native cache 承担（cache JSON §4.5）。

### 4.4 规则匹配引擎复用（import+调用点实证）
`server/backend/DnsQueryFilter.kt` 复用 core/rule：`BlockListManager`/`AllowListManager`/`RewriteRuleManager`（:46-65，全部 `indexDirectory=null`+`scope=RuleScope.DNS`+`reloadCacheAfterChanges=false`）、`DomainPolicy`（:67，注入 `{ masterSwitch.isEnabled() }`）、`DomainDecision`/`BlockResponseMode`/`RewriteAnswer`。决策矩阵 `$important 阻断 > allow > 普通阻断 > 默认放行`（`core/rule/DomainPolicyEngine.kt:52-111`，七级表见文件头注释；LruCache 决策缓存，reloadSync 后 `invalidateCache`，`DnsQueryFilter.kt:78-85`）。主开关三处消费：Go `filterDNS` 标志（`DnsServerEngine.kt:126`）、快照 `filterEnabled`（`DomainPolicyEngine.kt:120` 经 `isEnabledProvider()`）、Kotlin DomainChecker 回调路径——`model/DnsFilterMasterSwitch.kt` 类注释记载了历史上快照硬编码 true 的漂移缺陷；其 `snapshotFilterEnabled()`（:34）实测**无生产调用者**（快照取值走 DomainPolicy 闭包，不读该方法）。
数据面：**Room 用 `DnsRulesDatabase`**（文件 `diting_dns_rules`，v3，WAL，destructive 兜底，`data/DnsRulesDatabase.kt:100-131`），与 ExpressRulesDatabase/AppDatabase 完全隔离、永不迁移数据（:28-34 注释）；但 `RuleDatabases.runtimeForDataset(DNS_MODE)` 回落到 **AppDatabase**（:148-152）——DNS/拦截日志等运行表与普通模式共库。

### 4.5 快照与响应配置推送（syncRules 四连）
`syncRules()`（`DnsServerEngine.kt:107-122`）四连：`applyRuleSnapshot(filter.buildRuleSnapshotJson())`（内存规则导出，无 trie 路径键）→ `setRewriteRules(filter.buildRewriteRulesJson())`（域→IP 数组优先，CNAME 仅在无 IP 覆写时补，`DnsQueryFilter.kt:100-109`）→ `setBlockResponseType(filter.blockResponseMode.name)`（**来自 DnsRuleSettings 的 prefs 值**，`DnsQueryFilter.kt:82`；Go 解析映射 NXDOMAIN/REFUSED/NODATA/其余=零地址，`tunnel/dns_packet.go:28-39`）→ `clearDNSCache()`。拦截响应选项集（server 下可配 4 种）：`BlockResponseMode.NXDOMAIN/NODATA/REFUSED/ZERO_ADDRESS`（`core/rule/BlockResponseMode.kt:7-10`）；`applyDnsConfig` 另把 `blockResponse` 写为同一枚举名（`DnsServerEngine.kt:187`）。
**动态阻断 JSON**（逐字段，`model/DnsDynamicBlockJson.kt:22-42`）：config 顶层键 `dynamicResponse`，对象恒发四字段：`enabled`(bool)、`requestThreshold`(int)、`windowSeconds`(int)、`nxDomainDurationSeconds`(int)——键名镜像 Go `dns_config.go` 动态块结构，注释（:9-20）记载了漏发键导致动态升级从未生效的历史缺陷。Go 消费点 `effectiveBlockResponseType`（`engine_config.go:416-432`）：动态窗口内请求数过阈值→临时 NXDOMAIN，期满回落配置模式。缓存 JSON（:196-208）：`cache.{enabled,mode,maxTtlSeconds,fixedTtlSeconds,minTtlEnabled,minTtlSeconds,staleFallbackEnabled,staleFallbackSeconds,negativeTtlEnabled,negativeTtlSeconds}`，值全由 `DnsCachePreset.toPolicy(cacheEnabled)` 展开（CONSERVATIVE/BALANCED/HIGH_HIT_RATE 三档，`core/cache/DnsCachePreset.kt:13-66`）；`mode:"single"`、`providers:[单条]`、`bootstrap:{enabled:false,ips:[]}`（:234-237——server 模式 bootstrap 恒关）。

### 4.5.1 snapshotJson 完整构造链（Lead 必答题 ①）
调用点：`DnsServerEngine.syncRules()`（`backend/DnsServerEngine.kt:113` 构建、`:114 engine.applyRuleSnapshot(snapshotJson)` 下发；前置 `:111 filter.masterSwitch.set(config.adBlockEnabled)`）。链路：`DnsQueryFilter.buildRuleSnapshotJson()`（`DnsQueryFilter.kt:98`，恒传 `ruleIndexDirectory=null`）→ `DomainPolicy.buildRuleSnapshotJson(null)`（`core/rule/DomainPolicyEngine.kt:118-255`，序列化收口 `root.toString()` :254）。
数据来源（非直接 DAO，经内存缓存）：`DnsRulesDatabase` 的 `blockRuleDao()/allowRuleDao()`（`DnsQueryFilter.kt:46-58`）→ `BlockRuleCache/AllowRuleCache.reload(dao, scope=RuleScope.DNS)`（`core/rule/BlockListManager.kt:39-42` 调 `cache.reload`，其定义 `core/rule/BlockRuleCache.kt:25-36` 经 `BlockRuleCacheLoader.loadAll`）→ `exportSnapshot()`（`BlockListManager.kt:77`、`AllowListManager.kt:56`）→ 快照字段。注意 `RuleScope.DNS("dns")`（DAO 行级作用域列，`data/entity/RuleScope.kt:4-6`，区分 DNS 域名规则 vs HTTPS 请求规则）与 `RuleDataset.DNS_MODE`（库文件维度）**同名不同义**。
顶层字段逐条（实测 `DomainPolicyEngine.kt:120-251`）：
| 键 | 类型 | 来源 | server 模式取值 |
|---|---|---|---|
| `filterEnabled` | bool | `isEnabledProvider()`（:120，注入 `masterSwitch.isEnabled()`） | =adBlockEnabled |
| `blockTriePath`/`importantBlockTriePath`/`allowTriePath`/`importantAllowTriePath` | string | mmap 索引文件路径（:122-144） | **恒缺省**（directory=null 整段跳过） |
| `globalAllow` / `globalBlock` / `globalImportant` | 字符串数组 | allow/block 快照的全局规则 pattern | 有 |
| `appRules` | obj pkg→{allow[],block[],important[]} | 两侧 appRules 并集包名（:164-187） | 有（局域网查询 appName=RootProxy 不匹配 app 规则，实际仅全局生效——见 §4.1） |
| `invertedBlock` | [{pattern,source,important,excludedApps[]}] | :191-203 | 有 |
| `invertedAllow` | [{pattern,excludedApps[]}] | :206-215 | 有 |
| `disabledRules` | 字符串数组 | `blockSnapshot.disabledRules`（:217-220） | 有 |
| `specialBlock` | [{pattern,source,important,appScope?,appInverted,isWildcard,denyallow?,isRegex,dnsType?}] | :222-237（`?` 字段 null 时不 emit） | 有 |
| `specialAllow` | [{pattern,important,appScope?,appInverted,isWildcard,denyallow?,isRegex,dnsType?}] | :239-251 | 有 |

### 4.5.2 规则热更新触发路径（Lead 必答题 ②）
三类生产者→同一 ACTION_REFRESH：
1. **规则库写入侧**：黑名单/白名单/Hosts/订阅/批量页 → `RuleOperationWorker.kt`（DNS_MODE 分支 :157 `ruleIndexDirectory=null`）或 `SubscriptionAutoUpdateEngine.kt:312`（同 null）写 `DnsRulesDatabase`，完成后调 `RuntimeDnsSettingsRefresher.syncRuleIfRunning/refreshRuleIndexesIfRunning/refreshIfRunning`，其 **DNS_MODE dataset 分支**（`core/rule/RuntimeDnsSettingsRefresher.kt:42-44,79-81,118-120`）统一走 `pingDnsModeFilterReload`（:184-192）：判据 `WorkModeStore.getAppWorkMode==DNS` → `startService(ACTION_SERVER_REFRESH="com.haoze.diting.server.REFRESH")`（:186-190）。
2. **主开关/配置侧**：`RuleSettingsAccess.setMasterEnabled(DNS_MODE)` → `DnsModeManager.updateConfig`（`RuleSettingsAccess.kt:28-32`）→ `refreshEngineIfRunning`（`DnsModeManager.kt:218-225`，仅 RUNNING 投递）→ 同一 action。
3. **拦截响应侧**：`BlockResponseSettingsScreen.kt:54-55,77-78` 经 `RuleSettingsAccess` → `DnsRuleSettings.setBlockResponseMode/setDynamicBlockResponseConfig`（`DnsRuleSettings.kt:33-35,65-90`，同文件另一 writer 约定见 §3.1）→ `SettingsRouteActivity.kt:127-130 refreshIfRunning(dataset=DNS_MODE)`。
消费侧收敛于 `DnsModeService.onStartCommand ACTION_REFRESH`（`DnsModeService.kt:67-71`）→ `refreshDnsEngine`（:210-229）：`filter.reloadSync()`（重读 DAO→缓存、重读 block_response_mode、`invalidateCache`，`DnsQueryFilter.kt:78-85`）→ `DnsModeManager.reloadConfig`（重读 prefs，含 DnsRuleSettings 的动态块四键）→ `engine.updateConfig`（§4.6 分派）→ `engine.syncRules()`（重建快照下发）。

### 4.5.3 trie 对 server 为死路径 + 清理串扰风险（Lead 必答题 ③）
**服务器模式从不生成 trie 文件**——三重证据：① `DnsQueryFilter.kt:46-65` 三个 manager 恒 `indexDirectory=null`（类注释 :27-29 明示"避免两模式共写同一索引文件"）；② 两条规则写路径对 DNS_MODE 强制 null（`RuleOperationWorker.kt:152-160`、`SubscriptionAutoUpdateEngine.kt:309-315`，注释同述所有权）；③ `buildRuleSnapshotJson(null)` 跳过全部 trie 路径键（`DomainPolicyEngine.kt:122` 判空）。server 域全文（23 文件）无任何 `RuleIndexLayout`/索引文件引用（本会话 grep 实测零命中）。
**但清理链存在跨数据集删除**：`RuleIndexLayout.rootDirectory(filesDir, DNS_MODE)` 与 NORMAL **同目录** `filesDir/rule-index`（`core/rule/RuleIndexLayout.kt:43-45`，EXPRESS 才有子目录 `rule-index/express`）。`DataCleanupManager` 的三个 DNS_MODE 分支按此目录删文件——清空域名规则：`File(dnsIndexDir,"domain").deleteRecursively()` + `hostsIndex`（`data/cleanup/DataCleanupManager.kt:160-162`）；清空地址/Hosts：`hostsIndex(dnsIndexDir).delete()`（:242-243）；清空订阅：同（:321-322）。因 server 自己不写这些文件，**被删的实际是普通模式拥有并消费的 mmap 索引**（normal 侧缓存加载器下次 reload 是否自动重建属 normal 域，未在本章取证）→ 记为「trie 对 server 死路径 + DNS_MODE 清理串扰 NORMAL 索引文件」风险；Flutter 重构接口冻结面上：server 与 Go 之间规则面**只有 `applyRuleSnapshot(JSON)` 单通道**，Go 侧 `ApplyRuleSnapshot`（`engine_config.go:51`）解析上述顶层键；文件/共享内存索引不属于 server 契约。

### 4.6 变更传播矩阵（`DnsServerEngine.updateConfig` :66-105）
端口变→stop+start 重绑；upstream/cache/dynamicResponse 任一变→重发 applyDnsConfig；`adBlockEnabled` 变→`setFilterDNS`+`syncRules`（双闸门同步，注释 :91-102 记载单推 flag 的旧缺陷）；返回值=引擎是否仍存活（false→服务 ERROR+自停）。

## 5. 前台服务与通知

- 组件：`AndroidManifest.xml:146-153`，exported=false，`foregroundServiceType="specialUse"` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE=dns_service`；权限 `FOREGROUND_SERVICE_SPECIAL_USE`（:9）+ `FOREGROUND_SERVICE`（:7）+ `WAKE_LOCK`（:16）+ `POST_NOTIFICATIONS`（:10）。
- API34+ 走 `startForeground(id, notif, FOREGROUND_SERVICE_TYPE_SPECIAL_USE)`；失败退化普通 `startForeground`（`DnsModeService.kt:282-299`，双层 runCatching）；<34 直接两参版。
- 通道：`channel_dns_mode`，名「服务器模式」，IMPORTANCE_LOW，无角标，描述「显示服务器模式的运行状态」（:347-360）；通知固定 id **2002**（:365）。文案：标题「谛听 · 服务器模式运行中」，正文「当前上游: <本地化(上游名)> (<address)>」，动作「停止」→ PendingIntent.getService(reqCode=1, ACTION_STOP)，点按→ PendingIntent.getActivity(reqCode=0) 经 `DnsMainActivity` 跳板回 MainActivity；均 `FLAG_UPDATE_CURRENT|FLAG_IMMUTABLE`、ongoing、PRIORITY_LOW、小图标 `dns_svgrepo_com`（:306-345）。文案经 `localizedText(context, 中文键)` 走 LocalizationEngine（`ui/LocalizedTextHelper.kt:28-36`）——server 通知字符串全部中文字典键模式。
- 常驻条件：START_STICKY（ACTION_START/REFRESH 返回；ACTION_STOP 与"停但被重启"返回 NOT_STICKY）；PARTIAL_WAKE_LOCK 防 CPU 休眠、FULL_HIGH_PERF WifiLock 保 Wi-Fi 射频（:247-280）——这是"夜间局域网 DNS 持续可用"的实测机制。
- 电池优化：入口在首页/设置页（`DnsModeHost.kt:31` `BatteryOptimizationHelper.rememberBatteryOptimizationState`，`DnsSettingsScreen.kt:169-181` 已忽略则禁用点击并显示「已忽略」）；`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 声明于 Manifest:12。
- ON_RESUME 自愈：`DnsModeHost.kt:33-47`——`service_active && status==STOPPED → startService`（进程被杀/外部停止后回前台自动拉起；ERROR 态不覆盖，符合 §2.2 语义）。
- 磁贴联动：启动成功与 onDestroy 均 `QuickSettingsTileUpdater.requestTileUpdate`（`DnsModeService.kt:177,109`）。

## 6. UI 逐屏详解

### 6.1 DnsNavigation 路由表（`ui/navigation/DnsNavigation.kt:10-21`）
`DnsNavTab` 枚举即路由全集（无 NavHost，HorizontalPager 页序=枚举序）：
| 枚举 | route | 标题 | 图标 |
|---|---|---|---|
| HOME | `dns_home` | 概览 | Home |
| SERVERS | `dns_servers` | 上游服务器 | Dns |
| SETTINGS | `dns_settings` | 模式设置 | Settings |

### 6.2 DnsMainScreen（容器，243 行）
TopAppBar 透明底；HOME 标题「谛听 · 服务器模式」，其余页显示 tab 标题；actions：SERVERS→「新增」TextButton（开添加上游对话框）；HOME→`ModePermissionWarningAction(AppWorkMode.DNS)` + SwapHoriz 图标（→WorkModeActivity）。切页用 `navigateToPage`：90ms 淡出→scrollToPage→150ms 淡入，可被新点击取消并 snap 复位（:77-96）；`BackHandler` 非首页先回首页（280ms，:98-105）；`resetToHomeTrigger>0` 强制归零页（:71-75）。底部 `FloatingNavigationBar`（共享组件，pagerProgress 连续值驱动）；内容底部留白 108dp。托管两个对话框：重置统计确认（「将清空本次运行的全部统计数据…」→`viewModel.resetStats`）、`DnsPortEditDialog`（保存→`updateConfig(copy(localListenPort))`，:233-242）。状态全集经 `DnsMainViewModel.uiState`（combine 五流，`WhileSubscribed(5000)`，`viewmodel/DnsMainViewModel.kt:38-60`；activeUpstream 三级回落 :45-47）。

### 6.3 DnsHomeScreen（概览，221 行）
① `PowerToggleButton`：busy=STARTING/STOPPING；文案 启动中/停止/开启；② 状态文字五态（运行中/正在启动服务.../正在停止服务.../服务异常/服务器模式已停止）+ ERROR 时红色 errorReason（均 localizedText 中文键）；③「当前上游」组：NavigationItem 名+endpointLabel（`[DNS] 223.5.5.5:53` / `[DoH] url`），点击→SERVERS 页；④「局域网接入」组：`NetworkInfoProbe.probe(context).ipv4Addresses` 经 `formatEndpoints(sep=", ")` 渲染 `ip:port` 列表（**仅 IPv4，引擎虽绑 [::] 但界面不展示 IPv6**），无地址→「未连接 Wi-Fi 或未分配 IP」；副标题在端口不可绑定时替换为 `unusablePortWarning`；⑤「服务状态」组五项：总查询量/缓存命中/已拦截/平均时延（非运行 "--" ms）/运行时长（formatDuration）；⑥ 底部说明 `DnsHomeScreen.kt:216`。参数 `onRequestIgnoreBatteryOptimization` 在本屏**未被使用**（死参，实测 :43 仅签名）。

### 6.4 DnsServersScreen（上游，151 行）
委托共享组件 `ProviderManagementListContent`（协议分段：`DnsModeProtocol.entries` 三 tab，preset/custom 各自按 selectedProtocol 过滤）+ 顶部活动行「当前用于解析 DNS：([协议]) 名称」。新增（topbar「新增」）与编辑走 `ProviderEditDialog`：DoH 显示 URL 字段（`isUrlBasedProtocol = it==DOH`），port 初值=协议 defaultPort；确认前 `DnsUpstreamValidator` 三连校验（name/地址/端口），DoH 取 url 否则 host；新增成功后 `onSelectProtocol(protocol)` 切到该协议页便于查看。删除确认框（destructive，「删除 DNS 服务商」，:138-150——注意此三键**未过 localizedText**，直显中文原文）。命令→`viewModel.addCustomUpstream/updateCustomUpstream/removeCustomUpstream/selectUpstream`。

### 6.5 DnsSettingsScreen（设置，215 行）
五组七项，全部经 `openRuleRoute → SettingsRouteActivity.createIntent(route, dataset=RuleDataset.DNS_MODE)`（:51-55，规则/缓存页由此进入 DNS 数据集）：
| 组 | 控件 | 动作/键 |
|---|---|---|
| 代理与解析设置 | 缓存设置（副标：preset 名+摘要 或「已关闭 · 每次解析都请求上游 DNS」） | `Routes.CACHE_SETTINGS`→`CacheSettingsScreen` DNS_MODE 分支直改 `DnsModeManager.config`（`ui/CacheSettingsScreen.kt:46-77`） |
| | 规则控制（副标两态文案） | `Routes.RULE_CONTROL`；主开关读写经 `RuleSettingsAccess` DNS_MODE → `DnsModeManager.updateConfig`（`ui/settings/RuleSettingsAccess.kt:23-32`） |
| | 本地监听端口（副标「…默认 1053」，尾值=当前端口） | `DnsPortEditDialog` |
| 规则管理 | 黑名单/白名单/Hosts 覆写 | `BLACKLIST_MANAGEMENT`/`WHITELIST_MANAGEMENT`/`REWRITELIST_MANAGEMENT`（数据集恒 DNS_MODE） |
| 数据与重置 | 重置运行统计 | 确认框→resetStats |
| 后台稳定性 | 忽略电池优化 | 已忽略→禁用+「已忽略」尾标 |
| 运行模式 | 使用向导 | `ModeOnboardingActivity.start(context, AppWorkMode.DNS)`（向导内消费 `DnsListenPortValidator.noVpnDisclaimer/formatEndpoints/accessInstruction/unusablePortWarning`，`onboarding/ModeOnboardingSteps.kt:142,319,364,372`） |
| | 重新选择工作模式 | `onSelectMode`→WorkModeActivity |
`DnsMainScreen`/`DnsSettingsScreen` 均无「拦截响应设置」入口（实测全文无 `BLOCK_RESPONSE_SETTINGS` 引用）——它只在 `Routes.RULE_CONTROL` 页内联达（`SettingsRouteActivity.kt:395`，写库后经 :127-130 触发 REFRESH）。

### 6.6 DnsPortEditDialog（80 行）
仅收数字（`filter isDigit`）；`DnsListenPortValidator.validate` 失败→isError+错误 supportingText，成功→`parse` 后 onSave；辅助文案「范围 1024-65535，默认 1053」由常量拼接（:60）。

## 7. 关键源码引证表（路径:行）

| 主题 | 引证 |
|---|---|
| 跳板 Activity/Manifest | `server/DnsMainActivity.kt:14-31`；`AndroidManifest.xml:139-144,146-153,155-161,9,16,17` |
| 模式分发/切换 | `main/MainModeDispatcher.kt:71-78`；`main/MainWorkModeCoordinator.kt:90-117,155-157`；`ui/mode/WorkModeActivity.kt:69-99`；`main/MainVpnController.kt:62-67,80`；`core/WorkModeLifecycleRegistry.kt:26-31,69-84`；`express/ExpressModeLauncher.kt:42,110` |
| 状态机 | `server/backend/DnsModeManager.kt:30-43,49-53,55-68,75-135,218-225,240-274` |
| 服务生命周期 | `server/backend/DnsModeService.kt:43-97,119-229,237-240,247-299,306-360,362-392` |
| 启动守卫 | `server/backend/DnsModeStartGuard.kt:18-46`；单测 `test/.../server/DnsModeStartGuardTest.kt`（5 例） |
| 开机自启 | `server/backend/DnsModeBootReceiver.kt:17-24` |
| prefs 全键 | `server/backend/DnsModePreferences.kt:16-36,42-95,134-189`；`server/backend/DnsRuleSettings.kt:15-111` |
| 端口/上游校验与迁移 | `server/model/DnsListenPortValidator.kt:10-79`；`DnsListenPortMigration.kt:13-20`；`DnsUpstreamValidator.kt:12-91`；单测 `DnsListenPortMigrationTest.kt:19-45`、`DnsModePortAndFilterSwitchTest.kt` |
| Go 桥 | `server/backend/DnsServerEngine.kt:37-59,66-122,124-243,248-269`；`tunnel/engine_standalone.go:399-452-474`（§2.1/§4）；javap 实测 `app/libs/tunnel.aar!classes.jar tunnel/Engine`：`startStandalone(long)`/`stopStandalone()` |
| 规则链 | `server/backend/DnsQueryFilter.kt:40-67,78-109`；`core/rule/DomainPolicyEngine.kt:38-111,118-148`；`data/DnsRulesDatabase.kt:28-34,100-131,134-153`；`core/rule/RuntimeDnsSettingsRefresher.kt:21,33,43,80,119,184-192` |
| UI | `server/ui/DnsNavigation.kt:10-21`；`DnsMainScreen.kt:71-105,107-243`；`DnsHomeScreen.kt:48-219`；`DnsServersScreen.kt:36-151`；`DnsSettingsScreen.kt:51-214`；`DnsPortEditDialog.kt:32-79`；`DnsModeHost.kt:22-57`；`viewmodel/DnsMainViewModel.kt:26-94` |

## 8. Flutter 重构注意

1. **路由树映射**：server 无 NavHost——`DnsNavTab` 三枚举 = 三顶层路由（概览/上游/设置），HorizontalPager 手势滑动 + 淡入淡出切页 + 「返回先回首页」的 back 栈语义需在 Flutter 用 `Navigator`/`DefaultTabController` 复刻；页内对话框（端口编辑、重置确认、新增/编辑/删除上游）是路由层之上的 dialog route。`DnsMainActivity` 跳板可整体删除（仅通知点击链还引用它，重构时把 contentIntent 直指主路由即可）；`SettingsRouteActivity` 的两个残留 import 顺带清理。
2. **跨页耦合入口**：服务器模式设置页用外部 Activity（`SettingsRouteActivity.createIntent(dataset=DNS_MODE)`）承载规则/缓存/拦截响应子页，Flutter 化时应收敛为同一路由树的子路由 + dataset 参数；`RuntimeDnsSettingsRefresher` 的"按工作模式发 REFRESH intent"链在 Dart 侧等价物是服务层事件总线。已实测代码事实：DNS_MODE 分支门控只看"当前工作模式==DNS"（`RuntimeDnsSettingsRefresher.kt:185`），不像 NORMAL/EXPRESS 分支看"服务在跑"（:45/:52 `VpnStateRegistry.is*Running` 早退）。由此推得（未真机验证）：服务未启时收到 REFRESH 会空拉起 `DnsModeService`，且 `onCreate→initialize` 在 **DnsModeManager 尚未初始化**的进程里会依 `isServiceAlive=true` 把状态显示为 RUNNING 而引擎并未绑口（`DnsModeService.kt:45-48`+`DnsModeManager.kt:64-67`）；已初始化过的进程 `initialize` 早退（:57），该翻转不发生。重构时统一改为显式 running 门。
3. **Go API 专属面（仅确证过的）**：`startStandalone(long)`/`stopStandalone()` 是 server 模式独占调用；`applyDNSConfig(mode:"single", providers:[单条], bootstrap:{enabled:false}, dynamicResponse:{4 键}, cache:{10 键})` 的键形状必须按 `DnsDynamicBlockJson.kt`/`DnsServerEngine.kt:184-243` 逐字段保留（dynamicResponse 漏键=动态升级静默失效有案可稽）；`applyRuleSnapshot`/`setRewriteRules`/`setBlockResponseType`/`clearDNSCache`/`setFilterDNS`/`setDomainChecker`/`setLogCallback` 的调用次序（快照前推主开关）不可打乱。`setAppResolver`/`setFirewallChecker` 在 server 模式**从未被调用**——Flutter 版若不加设备归因，行为等价；不要臆造"按局域网设备归因"的既有能力。
4. **持久层**：prefs 文件名 `diting_dns_mode_prefs` 及 §3.1 全部键名需原样映射（含两个一次性迁移标志位——迁移语义是一次性的，Flutter 重写时须决定迁移是否随旧键一起废弃）；规则 DB 是独立文件 `diting_dns_rules`（同实体不同库），运行/日志表却共用 AppDatabase——拆分前勿假设 server 模式数据全在独立库。mmap 规则索引对 DNS 数据集恒禁用（内存快照），Flutter 侧不能"顺手"启用共享索引。
5. **杂项死代码（已实测，可不移植）**：`log_queries`/`cache_ttl_seconds` 两 prefs 键、`DnsFilterMasterSwitch.snapshotFilterEnabled()`、`DnsModeProtocol.MANAGED_PROTOCOLS`、`DnsMainActivity.createIntent`、`DnsQueryFilter.isBlocked/rewriteAnswersFor/reloadAsync`（生产零调用）、`DnsServerEngine.processQuery`（仅单测）、`DnsHomeScreen.onRequestIgnoreBatteryOptimization` 与 `DnsMainScreen.onSwitchToNormalMode` 死参。

## 9. 待定清单

- [待定] BootReceiver 开机拉起受 Android 12+ FGS-while-in-use 限制，代码仅 runCatching 吞日志（`DnsModeBootReceiver.kt:21-23`）——真机自启成功率未验证（本会话仅静态考古）。
- [待定] `dnsrewrite`/上游失败路径的 SERVFAIL 语义仅在单测钉住（`DnsModeTest.kt:275-299`，需 gojni 环境 `assumeTrue`），设备端 rcode=2 行为引用第 10 章口径。
- [待定] `runtimeForDataset(DNS_MODE)→AppDatabase`（`data/DnsRulesDatabase.kt:148-152`）的日志/缓存表混用在 10 章与 6 章（Room）边界上，归属与迁移策略需 Lead 仲裁。
- [待定] `docs/refactor/10-go-tunnel-engine.md` 尚不存在（本会话实测 `docs/` 仅有 assets/development），§2.1-6/§4 引用的 Go 行号来自 `Android/tunnel` 源码直读，若 10 章口径不同以其为准复核。
- [待定] 上游地址含冒号时 `2001:db8::1:53` 这类"带端口歧义"字面量按 RFC 是合法 IPv6 地址会被接受（`DnsUpstreamValidator.kt:60-91`）——是否符合产品意图未见注释表态。
- [待定] 服务器模式 `minApiLevel=29` 仅在模式选择卡片 UI 层拦截（`WorkModeComponents.kt:104`），BootReceiver/服务链路无二次 API 检查；经备份恢复（allowBackup=true，Manifest:21）把 DNS 模式 prefs 带回 API24-28 设备的后果未取证。
