---
所属系列: DITING Android Flutter 重构功能图谱 | 章: 08（续） | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测
---

# 08 极速模式（Express）续篇：配置全表 · UI 差异 · 引证 · Flutter 注意

前篇：`08-express-mode.md`（§1-5）。本篇 §6-9。

## 6. 极速模式配置适配全表（设置键 → 引擎行为）

prefs 文件：规则/解析/缓存/系统类全部读写 `RuleDataset.EXPRESS.prefsName()` = **`diting_express_prefs`**（`data/RuleDataset.kt:26`）；VPN 运行标志在独立文件 **`express_vpn_prefs`**，键 `express_vpn_running`（`ExpressVpnController.kt:32-33,179-188`；`core/VpnStateRegistry.kt:13-17` 默认 lambda 同名）。注意 `DnsProvider` 的伴生 `PREFS_NAME="dns_vpn_prefs"`（`core/dns/DnsProvider.kt:53`）**未被使用**（读取一律经 `prefs(context, dataset)` :199-201→`dataset.prefsName()`），服务商 JSON 实际存 `diting_express_prefs.user_providers_json` / `.selected_provider_id`（键名 :54-55）。

生效时机两类：**热**（运行中经 ACTION_REFRESH_CONFIG / ACTION_SYNC_RULES 重读）与**冷**（仅下次建隧/建引擎读取）。

| 设置键（prefs 文件 diting_express_prefs） | 存储/默认 | 引擎读取点 | 生效方式 | 行为 |
|---|---|---|---|---|
| `domain_rules_enabled`（AppRulesSettingsStore:29） | Boolean / Seeder 置 true（Seeder:65；读取默认 true :375-377） | `domainRulesEnabledProvider`（Service:122 → TunnelManager:264,276,345 → Engine:25,96 与 `DomainPolicy.isEnabledProvider`） | 热（开关处发 `RuntimeDnsSettingsRefresher.refreshIfRunning`，但注意 express 的 refreshConfig 不重读此键——真正生效靠 DomainPolicy 每次 evaluate 现读 provider（Engine lambda `AppRulesSettingsStore.isDomainRulesEnabled`）→ **即时**） | 关掉后 DNS 查询跳过全部域名规则 |
| `block_response_mode`（AppRules:31，默认 NXDOMAIN :41） | 枚举 / Seeder NXDOMAIN（:66） | `blockResponseModeProvider`（Service:121 → Engine:26,103 → `ExpressDnsMessageUtils.buildBlockedResponse` :109-120） | 即时（每命中现读） | NXDOMAIN / NODATA(NOERROR 空答) / REFUSED / ZERO_ADDRESS(0.0.0.0 或 ::，TTL 300) |
| `dynamic_block_response_enabled` + 阈值 3 键（AppRules:32-35） | — | **引擎无任何消费**；仅 UI 文案判定（ExpressDynamicBlockSupport） | 不生效 | 极速不执行动态升级（§5.2） |
| `dns_resolution_mode`（ResolutionSettingsStore:17，默认 SINGLE :106-110；Seeder 置 SINGLE :67） | Service:93,182 + `resolveActiveProviders` :269；Engine:28,136 → Dispatcher:111-116 | 热（REFRESH_CONFIG 重读 :182）| SINGLE/依次尝试/并发竞速/智能选择 |
| `smart_prediction_provider_ids` / `parallel_race_provider_ids` / `primary_backup_provider_ids`（:19-21） | Set/List，缺省回退 `DEFAULT_RACE_PROVIDER_IDS={"preset_alidns_dns","preset_dnspod_dns"}`（:26-29,119-161） | `resolveActiveProviders` :274-286（要求交集 ≥2 否则回退单选） | 热 | 竞速/回退成员集 |
| `user_providers_json` / `selected_provider_id`（:54-55） | 默认选中 `preset_alidns_dns`（:56；Seeder:72 `saveSelected`） | `DnsProvider.loadSelected/loadRuntimeProviders`（:207-217）经 Service:279,283,288 | 热 | 服务商池 |
| `dns_cache_enabled_v2` + mode/max/fixed/min/stale/preset 8 键（DnsCacheSettingsStore:10-18） | enabled=true（:22；Seeder:68）；policy 默认 LIMIT_MAX_TTL/3600s（`core/cache/DnsCachePolicy.kt:26-35`） | `cachePolicyProvider`（Service:123 → TunnelManager:280 → `ExpressRoomDnsCache:77,114,118`，仅 `enabled`+`effectiveTtlSeconds` 两字段被消费） | **冷**（ExpressRoomDnsCache 每次 get/put 现调 provider——实际即时） | 关→不查不写缓存；mode 影响 TTL 上限/固定值 |
| `dns_log_mode`（SystemSettingsStore:17，默认 ALL） | Seeder ALL（:69） | `dnsLogModeProvider`（Service:124 → DnsLogger 构造 :281；DnsLogger:37+ 按 mode 过滤写入） | 即时（每 log 现读） | 记录全部/仅拦截与错误/关闭 |
| `log_retention_days`（SystemSettingsStore:10，默认 7，范围 1..30 :56） | 非 Seeder 播种 | `LogMaintenance.start(retentionDaysProvider=…)`（TunnelManager:286-293） | 服务存活期周期清理 EXPRESS 库 | 日志保留天数 |
| `ipv6_mode`（SystemSettingsStore:14，默认 AUTO） | Seeder AUTO（:70） | `SystemSettingsStore.getIpv6Mode(this, EXPRESS)`（Service:101 → `establishVpnInterface` :102,202-206） | **冷**（仅建隧时读；UI 文案亦提示「修改后重新开启服务生效」`ExpressForegroundBackgroundSettingsScreen.kt:115`） | 决定 TUN 是否加 IPv6 地址/路由/AF_INET6 |
| `race_test_domain`（ResolutionSettingsStore:14，默认 `mihoyo.com` :31）/ `latency_test_provider_ids`（:15） | — | 极速引擎不消费（属服务商测速 UI，06/07 章） | — | |
| 订阅自动更新 enabled/interval（SubscriptionAutoUpdateSettings，dataset=EXPRESS） | Seeder: 开/24h（Seeder:71） | Seeder:114 + `SubscriptionAutoUpdateScheduler.sync`（WorkManager 按 dataset 隔离） | 后台任务 | 极速库订阅更新 |
| Intent extras（一次性覆盖）：`doh_url`、`dns_protocol`+`dns_host`+`dns_port`+`dns_name` | — | `resolveActiveProviders` :238-267——**优先于全部持久设置** | 本次启动 | 自定义上游临时注入（`startIntent(context, provider)` 唯一生产方=Controller.start :100；当前所有 UI 调用方 provider=null，实际只有测试/未来入口用） |
| `main_activity_foreground`（SystemSettingsStore:20） | 默认 true（:87） | Service:78 与 Controller:156 双写；悬浮日志读 | 热 | 前后台可见性 |
| 通知文案 `custom_running_text`（NotificationSettingsStore） | 可空 | `ExpressNotificationBuilder:61-66` | 热（保存后发 REFRESH_CONFIG :121） | 前台通知正文 |

`ExpressConfigAdapter.kt` 不是运行时参数适配器，而是**导入导出口径裁剪器**（§5.2 之外补充）：导出侧 `sanitizeExportSelection` 强制 8 个全隧道字段=false（:34-45），导入侧 `sanitizeImportConfig` 将其剥为 null/空集（:51-81），并保留本机 `blockedAppsEnabled` 原值防误同步（:60-65,76）。生产消费者仅 `ui/ConfigTransferViewModel.kt:78,125`（按 dataset==EXPRESS 分派）；`exportConfig/importConfig` 两函数（:86-104）**仓内零调用**（ViewModel 直接用 ConfigExporter/Importer + sanitize；待定：视为预留 API）。

## 7. 极速模式独有 / 差异 UI 功能清单（逐屏）

导航骨架差异：`main/MainModeDispatcher.kt:39-70` 在 EXPRESS 分支把**几乎所有设置路由都带 `RuleDataset.EXPRESS`**（外观/关于/赞助/更新/隐藏功能等全局项传 null 除外）。通用首页/设置组件复用主 UI（03 章），下列仅差异点。

1. **ExpressMainScreen.kt**（301 行）：HorizontalPager + FloatingNavigationBar；顶栏标题「谛听 · 极速」（:164）+ 模式切换按钮（SwapHoriz, :168-174）；页面集合来自 `ExpressBottomBarDestination.getDestinations`（:100）；切页 alpha 动画（90ms out/150ms in，:285-287）；返回键先回 page0（:138-142）。与 normal `MainScreen` 结构同构但页枚举收窄。
2. **ExpressNavigation.kt / ExpressBottomBarDestination**（115 行）：仅 4 页 HOME/FEATURE_HUB/LOG_DASHBOARD/SETTINGS；**物理排除 APP_TRAFFIC_STATS 与 NETWORK_TOOLS**（KDoc :17-19；对照 `ui/BottomBarDestination.kt:52-65` 6 值）；MIN2/MAX4（:58-59）；默认 3 页不含 SETTINGS（:61-62）；`fromLegacy` 映射（:67-73）+ JSON 存取复用 legacy 存储键（存 `BottomBarDestination` 再反向 map，`ExpressBottomBarCustomizationScreen.kt:75-76`）。
3. **ExpressHomeContent.kt**（360 行）：电源钮 `enabled = selectedProvider!=null && (SINGLE || raceIds>=2)`（:144-145）；解析模式非 SINGLE 时服务商选择器变多选用 `ModeProviderSelectionDialog` + `ProviderEndpointList`（:282-306）；条目内含虚拟项「管理服务...」「服务显示...」（:170-175）；透明度/标语全走 AppearanceSettingsStore（:91-97）。无 LAN 绕过、无实时速率卡（KDoc :69-70）。
4. **ExpressFeatureHubScreen.kt**（367 行）：5 分类 19 项实测（DNS 服务 4、策略规则 3、界面设置 4、数据维护 4、关于 4——:129-229；注释「3 项，覆写名单已在极速模式物理移除」:148）；日志项长按压→日志保留设置 + 引导提示（:186-197）；受 HiddenFeatures 过滤。物理移除清单（KDoc :86-88）：覆写列表、流量统计、应用规则、禁止联网、排除应用、HTTPS 检查、出站代理、网络诊断、AI 分析。
5. **ExpressHiddenFeaturesScreen.kt**（152 行）：白名单集合 `EXPRESS_SUPPORTED_FEATURES` 18 项实测（:38-66；对照 HiddenFeature 全枚举 27 项 `ui/settings/HiddenFeaturesStore.kt`——排除 REWRITE_LIST + NETWORK_CONTROL 4 项 + ADVANCED_TOOLS 4 项 = 9 项）；「全部恢复」只清 express 白名单内的键（:94-98）。
6. **ExpressRuleControlScreen.kt**（186 行）：三组=过滤控制（域名规则总开关 :104-123）、拦截策略（单项「拦截响应」，副标题走 `ExpressDynamicBlockSupport.blockResponseSubtitle` :129-150）、订阅与更新（订阅/自动更新/镜像模板 :152-183）。**无 URL 规则、无 HTTPS 检查联动弹窗、无 IPv4/IPv6 覆写引用**（KDoc :38-42）。注意默认参数 `dataset=RuleDataset.NORMAL`（:51）——调用方 SettingsRouteActivity:342 必须显式传 ruleDataset（实测已传）。
7. **ExpressLogDashboardScreen.kt**（187 行）：VM key `ExpressLogDashboardViewModel_${dataset.name}`（:59）；`onNavigateToTrafficStats=null` 三处（:162,172,180）——流量统计入口物理拔除；无 AI 分析 action（KDoc :45-47）。
8. **ExpressRequestLogScreen.kt**（396 行）：VM 固定 `RequestSource.DNS + RuleDataset.EXPRESS`（:88-95）；CSV 导出（:106-117,381-396，含 BOM）；域名点击→DomainActionDialog 加黑/白名单后 `RuntimeDnsSettingsRefresher.syncRuleIfRunning(EXPRESS)`（:301-324）；**analyze=null 去 AI**（:325）；无 HTTPS tab（KDoc :78-80）。
9. **ExpressConfigTransferScreen.kt**（413 行）：导出勾选仅 7 项（providers/bootstrapIps/dnsCache/subscriptions/customDomainRules/appearance/systemSettings，:99-128，其余 8 项硬编码 false）；仪表盘 3 卡（无「管理应用数」:274-293）；导出文件名 `DITING-express-config-<yyyyMMdd>.json`（:227）。
10. **ExpressDataCleanupScreen.kt**（299 行）：`ExpressCleanupAction` 11 项枚举实测（:231-279），5 分组 3+2+2+2+2（:73-184）；物理移除流量统计删除/地址规则/应用控制重置/出站代理重置/抓包证书重置 5 项（KDoc :36-42）；DOMAIN_RULES/SUBSCRIPTIONS 完成→`onRuntimeDnsSettingsChanged`，SETTINGS_GUIDES/ALL_DATA→`onExitApp`（:208-223）。
11. **ExpressBottomBarCustomizationScreen.kt**（374 行）：候选=4 个 express 页（:80-82），文案「2～4 个」（:174）；保存回写 legacy 枚举列表（:75-76）。
12. **ExpressForegroundBackgroundSettingsScreen.kt**（135 行）：**无「绕过局域网」节**（KDoc :33-36——窄路由下局域网流量本就不进 TUN）；保留 后台隐藏 / IPv6 三态单选（:88-114，写 `getIpv6Mode/setIpv6Mode(EXPRESS)` :50-56）/ 电池优化。
13. **ExpressNotificationSettingsScreen.kt**（156 行）：**无「实时速率」节**（KDoc :37-39）；常驻开关 + 双文案 + 系统权限；保存时对 express 服务发 REFRESH_CONFIG(reason="notification_texts" :121)。
14. **ExpressWorkModeCard.kt**（36 行）：仅委托 `WorkModeCard(EXPRESS)`（:28-35）+ `ExpressEnvironmentChecker.isSupported()`（:12-14）——**两者仓内零调用者**（grep 双向确认；模式选择 UI 实际直接用 AppWorkMode，归 03 章）。
15. **LogRouteActivity.kt:24-28**：日志路由 activity 无显式 dataset extra 时按当前工作模式回推 EXPRESS；`isExpressMode` 影响 DNS_LOGS 屏（:103）。

隐藏功能/不可达入口对照（普通 vs 极速可见入口）：极速隐藏 9 个 HiddenFeature（§7.5）+ 2 个底栏页 + HTTPS/流量/URL 类设置屏 5 组；极速新增可见差异 = 0（无任何「仅极速有」的功能屏——极速 UI 是普通模式 UI 的严格减法，这是重构关键结论）。

## 8. 关键源码引证表（路径:行，均相对 `Android/app/src/main/java/com/haoze/diting/`）

| 主题 | 引证 |
|---|---|
| 服务生命周期总线 | `express/ExpressVpnService.kt:52-65(onCreate/播种) :67-84(动作分发) :86-150(startVpn) :201-211(stopVpn) :213-235(onRevoke/onDestroy) :291-309(companion/protect*)` |
| Builder 参数 | `express/ExpressTunnelManager.kt:198-246`（常量 :76-83） |
| TUN 读循环/分发 | `express/ExpressTunnelManager.kt:402-459`；tcpChannel :106-109；tcpWorker :377-389；retransmit :391-400；writePacket :464-472；stop :500-537 |
| 引擎五步流水线 | `express/engine/ExpressDnsEngine.kt:76-160`（DDR :85-92，规则 :94-117，缓存 :119-131，上游 :133-148） |
| 包编解码 | `express/engine/ExpressPacketCodec.kt:67-196(parse) :201-279(RST) :285-352(UDP 响应) :388-445(校验和) :452-524(TTL patch) :526-550(skipDnsName)` |
| TCP DNS 会话 | `express/engine/ExpressTcpDnsHandler.kt:64-254`；MSS1300/重传 1s×3 :21-23 |
| 上游分发 | `express/engine/ExpressUpstreamDispatcher.kt:103-239`；超时常量 `core/dns/DnsTimeoutConstants.kt:3` |
| 劫持路由表 | `express/engine/PublicDnsHijackList.kt:21-77`；消费 `express/ExpressTunnelManager.kt:221,228` |
| 缓存两套实现 | `express/cache/ExpressRoomDnsCache.kt:65-164` vs `core/cache/DnsResponseCache.kt`（全文 512 行）；表列 `data/ExpressRulesDatabase.kt:59-82` |
| 规则判定共享 | `core/rule/DomainPolicyEngine.kt:38-112`；注入点 `express/ExpressTunnelManager.kt:330-343` |
| 生命周期守卫 | `express/ExpressLifecycleGuard.kt:18-43`；使用 `express/ExpressVpnService.kt:91,130` |
| 状态/互斥 | `express/ExpressVpnController.kt:50-57,162-177`；`core/VpnStateRegistry.kt:13-19`；`core/WorkModeLifecycleRegistry.kt`（stopExpressMode lambda、stopOtherModes）；`express/ExpressModeLauncher.kt:33-68` |
| 通知 | `express/notification/ExpressNotificationBuilder.kt:28-29,34-48,54-125`；FGS 类型 `AndroidManifest.xml:45-55` |
| 播种 | `express/ExpressDefaultsSeeder.kt:47-116`（幂等键 `express_initialized` :37,40-42,108-111） |
| 动态升级差异声明 | `express/ExpressDynamicBlockSupport.kt:24-63`；UI 消费 `express/ui/ExpressRuleControlScreen.kt:137-145` |
| 传输三件套 | `express/transport/ExpressPlainDnsTransport.kt:28-126`、`ExpressDotTransport.kt:29-137`、`ExpressDohTransport.kt:42-151(client cache),159-208(query)` |

## 9. Flutter 重构注意（只列本会话确证项）

1. **packet 编解码与 tun 读写：建议保留平台侧（Kotlin/或 Dart FFI 化的 C）而非 Dart 重写**。事实依据：① 热路径是每包 parse+每响应 build——纯 CPU、零系统调用，Dart 单次 isolate 可承载但需压测；② 当前模型是「一个阻塞读线程 + 每查询一个协程」（`ExpressTunnelManager.kt:402-431`），UDP 侧无背压，Dart 重写不会改变这个结构性风险，收益仅在少一层平台通道；③ 逻辑规模小（codec 572 行、TCP handler 348 行）且**已有 1,993 行 JVM 行为锁定测试**（codec 388 + tcp 267 + utils/其余），是全套件里最可移植的纯函数部分——若 Dart 重写，应把这些测试逐向量迁移（含 `ExpressPacketCodecTest` 的分片/校验和/TTL 用例）。结论二选一都成立，**决策点=压测 Dart 单 isolate 处理 10³ qps×512B 包的 GC 压力**，本会话无线上数据，标「待定」。
2. **双实现收敛（最高优先级技术债）**：`ExpressDnsMessageUtils` vs `DnsMessageUtils` 是 90% 同构双写（本会话归一化 diff 证实，§5.2 列出全部 6 类差异）；三 transport vs core 两 transport 同理（express 版是严格超集）。Flutter 侧应保留 express 的**超集行为**（EDNS0、取消钩子、bootstrap 回退、DoH 客户端缓存），删除 core 版独有件前先确认 normal/server 对 core 版的独立消费仍在。两套 DNS 缓存同理：core 版功能为超集（single-flight、stale、批写、精确 TTL patch），express 版独有价值仅「Room 同步写 + hitCount 保护(A-065) + 独立 DB」——合并时以 core 语义为基，Express 的 '#' 分隔 key 与 '|' 不兼容，需数据迁移或统一（现两侧分库无运行时冲突，`DnsCacheKey.kt:28-38` vs `ExpressRoomDnsCache.kt:69`）。
3. **窄路由 + 公共 DNS /32 劫持表是极速模式的身份本身**（30 个 IP 实测，§4.4），任何重构（含切 Go/切 Dart）都必须保留「表驱动路由」而非全隧道；IPv6 表随 `enableIpv6` 条件加入，判据 GUA&&route 不可回退到 `||`（`ExpressTunnelManager.kt:187-190` 历史缺陷注释）。
4. **生命周期竞态守卫必须以代际/token 语义移植**（`ExpressLifecycleGuard` 及其测试）：Express 的「规则加载挂起期间 stop 到达」竞态在 Flutter+VpnService 绑定的任何形态里都同样存在；用布尔位 `running` 判定会回归（同 AGENT_MISTAKES「身份判定须用代际」教训）。
5. **FGS 时序约束平台无关**：`onCreate` 播种必须在 IO（`ExpressVpnService.kt:58-64`）、`startForeground` 先于耗时建立、提升失败不得 `stopSelf`（`notification/VpnMonitorManager.kt` stop 注释与 f3f9886 崩溃史）——Flutter plugin 侧同样要守。
6. **tcpChannel DROP_OLDEST(256) 是有意的内存上限**（`ExpressTunnelManager.kt:102-109` 注释）；UDP 无对应背压。重构若换队列模型须保留「TCP flood 不打爆堆」这一已确证属性，并给 UDP 侧补等价的并发上限（当前缺失）。
7. **ExpressVpnService.protect* 伴生三函数、ExpressWorkModeCard/ExpressEnvironmentChecker、`ExpressSettingsRefresher.syncRulesIfRunning`、DnsProvider.PREFS_NAME、`HijackEntry.provider/description`、`EngineStats`（无 UI 消费）、`EXTRA_REFRESH_REASON`（express 侧无读取）均为死代码/预留 API**——迁移清单按「不移植」处理，除非 Flutter 侧计划复用（逐项 grep 双向确认于本会话）。
8. **动态拦截升级、覆写规则、rewrite/GoUrlRule/Cosmetic 表**：极速数据面完全不消费（Seeder 仅建索引 `ExpressDefaultsSeeder.kt:102`；`ExpressConfigAdapter` KDoc :16-25 物理裁剪清单与 §5.2/§7 一致）——Flutter 侧 express 可完全不实现这些子系统，但 express **数据库 schema 仍含全部 18 实体**（含 GoUrlRule/Cosmetic 表，`data/ExpressRulesDatabase.kt:59-77`），为 UI 通用屏复用而存在；缩表需先审计通用 UI（02/04 章）。

## 「待定」清单

| # | 事项 | 缺什么证据 |
|---|---|---|
| 1 | UDP 查询协程无上限在真实 flood 下的内存表现（§3.4） | 真机/压测数据 |
| 2 | Dart 重写 codec 的单 isolate 吞吐（§9.1） | 基准压测 |
| 3 | START_STICKY null-intent 重建路径的实际触发频率（§2.4）：logcat/现场 | 真机取证 |
| 4 | `ExpressConfigAdapter.exportConfig/importConfig` 是否外部（文档/未来入口）引用 | 已 grep 仓内零调用；仓外无从证实 |
| 5 | express 携带 answer 段查询时 `hasDnssecOk` 两侧实现的行为分叉是否可被现实客户端触发（§5.2⑤） | 需构造 RFC 合法但含 answer 的查询样本比对 |
| 6 | 极速模式对 DoQ/DoH-GET/自定义端口的支持边界——引擎仅 DOH-POST/DOT/DNS 三协议（`DnsProtocol` 3 值实测），DoQ 不存在 | 无（属功能边界确认，非缺口） |
