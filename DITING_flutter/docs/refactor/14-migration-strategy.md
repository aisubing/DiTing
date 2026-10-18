# 14 · Flutter 迁移总策略（Lead 汇总撰写）

```yaml
所属系列: DITING Android Flutter 重构功能图谱
章: 14（终章）
作者: Lead（基于第 01–13 章交叉校验后的汇总；各章断言的复核记录见各章 YAML 与本文引证）
最后校验: 2026-10-18
口径: 本文只汇总「已被至少一处源码实测支撑」的跨章结论；各章「待定」项在本文仅作为决策输入列出，不当作事实
```

---

## 1. 迁移总原则

1. **功能图谱是唯一需求源**：第 01–13 章按「屏/组件/设置键/规则语法/API 契约」四级穷尽；写 Flutter 代码前先查对应章，查不到再回源码。
2. **行为等价优先于架构优雅**：本项目大量行为只存在于测试期望值（第 13 章 585 个 `@Test`）与注释里的历史修复（AGENT_MISTAKES.md）；重构不得「顺手优化」第 6 节红线清单上的语义。
3. **三模式分别对待**：极速=纯 Kotlin 数据面（Dart 可承接大半）；普通=Kotlin 编排+Go 数据面（平台包主体）；服务器=Go standalone 薄编排（接口面最小）。
4. **死代码不带入**：第 8 节清单在 Flutter 侧直接不实现（已双端 grep 确证零消费者）。
5. **单进程假设不变**：现状全部组件同进程（Manifest 无 `android:process`）；Flutter 版维持单 Isolate+平台线程模型，除非有实测吞吐证据（09 章待定 2）。

## 2. 目标架构分层

```
┌────────────────────────────────────────────────────────┐
│ Flutter App (Dart)                                      │
│  presentation/   121 屏重组（03/04/06/12 章路由表为纲）  │
│  application/    51 VM → Riverpod notifier（04 章清单） │
│  domain/         规则引擎/调度算法/缓存策略（02/07 章）   │
│  data/           drift 三库 + shared_preferences 158 键  │
├────────────────────────────────────────────────────────┤
│ Platform Bridge（MethodChannel/EventChannel 单一门面）   │
│  engine_bridge   Go AAR 调用面（09 章 §3 冻结清单）      │
│  vpn_bridge      双 VpnService + fd 传递 + protect       │
│  system_bridge   通知/Tile/悬浮窗/更新/崩溃/权限/流量采样 │
├────────────────────────────────────────────────────────┤
│ Android 原生（Kotlin，最小残留）                          │
│  VpnService 壳×2、前台服务×2、Tile、BroadcastReceiver、   │
│  tunnel.aar（Go 引擎）、KeyStore/CA、TrafficStats         │
└────────────────────────────────────────────────────────┘
```

判据（09 章 §9.3，Lead 认同）：**是否依赖 Android framework API** 决定代码留在 Kotlin 还是上移 Dart。纯策略类（快照 JSON 构造、提交判定、7 级优先矩阵、日志实体映射）全部上移 Dart；`Context/PackageManager/KeyStore/ConnectivityManager/NotificationManager/VpnService` 路径一律留原生。

## 3. 六大迁移决策（每项：事实 → 选项 → 建议）

### D1 Go 引擎：保留 AAR vs Dart 重写
- 事实：Go 侧 85 文件/13,872 行非测试码（13 章实测）；gVisor netstack + MITM CA + tun2socks 为普通模式数据面（10 章）；Kotlin 消费面仅 5 文件 12 符号（10 章发现 1，Lead 复验）；AAR 仅 arm64、13.6MB libgojni.so（01 章实测）；gomobile 绑定名不稳定已被反射规避（GoInspectionTunnel.kt:118-120，09/10 章双证）；构建链在仓外（10 章发现 18：无 gomobile 脚本入库）。
- 选项：a) 原样保留 AAR+冻结接口面；b) 保留 AAR 但用 `gobind` 显式收窄导出；c) 重写为 Dart（network stack+MITM）。
- 建议：**b 起步、c 仅评估极速模式已验证的纯 DNS 部分**。netstack/MITM 重写风险远超收益（10 章重写风险表第 1–3 位）；重写导出面时以「Kotlin 实际调用清单」裁剪，而非按 Go 导出全量生成（09 章 §9.5）。

### D2 数据层：Room → drift
- 事实：3 库 52 表定义（02 章）；全 `fallbackToDestructiveMigration`+仅一处销毁提示；迁移链含「以代码为准的基线值」与一次性标记（02/01 章）；DAO 里 updateMetadata→insertIfAbsent 两段式绕开 minSdk24 无 UPSERT（07 章发现 7）。
- 建议：drift 保 SQLite 文件路径与表名不变（备份兼容），迁移策略升级为显式 `onUpgrade`；**destructive fallback 语义是既有行为**（升级版本不匹配时清空规则），Flutter 版若改为强制迁移=行为变更，需产品签字。
- 已知债：`runtimeForDataset(DNS_MODE)→AppDatabase`（服务器日志/缓存写普通模式主库）——现状如此（02/11 章 Lead 复验），隔离或保持必须显式决策（见红线 R6）。

### D3 状态管理与导航
- 事实：无 Navigation Compose，三模式 `when` 切子树+二级页 Activity 自嵌套+6 布尔跨栈总线（03 章，Lead 复验）；51 个 ViewModel；Paging3 四列表屏竞态防护不一致（04 章发现 5）。
- 建议：单 Flutter Activity + go_router；自嵌套=Navigator push/pop（返回栈语义等价）；6 位总线→app-level listener/stream；ViewModel→Riverpod；竞态防护统一「代际 token + 双检丢弃」四屏同构（04 章建议，与 AGENT_MISTAKES 的 `===` 教训同源——Dart 用 `identical()`）。

### D4 配置持久化
- 事实：0 DataStore、9+1 容器、158 键名/168 落盘键面（01 章终版，Lead 参与差集审计）；`dns_vpn_prefs` 混装业务+全局；dataset 后缀键三库并存；StringSet 实存 JSONArray 字符串；`getPreferredEditor` 死代码（06 章）。
- 建议：shared_preferences 单容器起步但**键名逐字保留**（含 `_v2/_v3` 历史后缀、`GOLD→"indigo"` 错位值、三迁移标记）；按 dataset 分文件用 `SharedPreferences.setPrefix` 语义模拟；导入导出格式（05 章 ConfigTransfer）不改 schema 则旧备份可直接读——这是跨端兼容锚点。

### D5 后台任务
- 事实：WorkManager 7 个唯一名（3×2 自动更新+retry、1 手动串行队列，02 章+Lead 实测）；仅 CONNECTED 约束；订阅恢复依赖任务列表语义（02 章发现 12-14）；无 AlarmManager/JobScheduler 直用；开机自启=BroadcastReceiver（server 专属，Android12+ FGS 限制为待定）。
- 建议：flutter_background_work 或**保留 Kotlin WorkManager**（订阅 staging/recovery 语义复杂，迁移收益低风险高）；「先判 isRunning 再 startForegroundService」修复 09 章待定 4（设置改了但没生效的静默失败面）。

### D6 本地化与主题
- 事实：双层机制=values 216×2 条（中英零差集，Lead 实测）+运行时词典 ~1950 条+Pattern 模板层（06 章）；25-27 条哈希资源名不可达（算法变更残留）；9 色板+动态取色+Liquid 玻璃（AGSL 仅 1 点，12 章）；首页自定义句子过翻译链、通知文案不过链（06 章发现 14，行为相反）。
- 建议：intl/ARB 承接 values 层；**运行时词典层保留等价物**（动态语句/服务商名替换是产品特性）；「过链与否」两处行为差异按现状复刻或统一（产品决策，默认复刻）；Liquid 用 shader+warm-up 降级双路径照抄（12 章 §12.3 参数表）。

## 4. 进程与并发模型映射

| 现状 | Flutter 目标 | 注意 |
|---|---|---|
| 单进程；裸 Thread×N + 协程 scope | 主 Isolate + Dart isolate/pthread | Go 线程由 gomobile 管理，勿动 |
| tun 读：单线程逐包；UDP 每查询一协程无上限（08 章） | fd→Dart stream 或留原生 | flood 内存为 08 章待定 1，需压测后定背压 |
| Go 回调（7 类）→ Kotlin channel 消费（09 章） | EventChannel 单流多类型 或 7 通道 | 载荷 JSON 字段名逐字冻结（含 `ttl` 无 omitempty） |
| 缓存批写：200 条/30s 双阈值 + epoch 防竞态（07 章） | drift batch + 同语义 | 两段式绕 UPSERT 在 Dart 同样需要（保持不引入 SQL 方言差异） |
| 前台服务/通知/Tile/悬浮窗（05/09/11 章） | 保留 Kotlin，Flutter 只管展示开关 | 渠道 id/名称/通知 id（2001/2002）是系统级契约 |

## 5. 命名陷阱对照表（重构必读）

| 现名 | 实际语义 | Flutter 建议名 |
|---|---|---|
| `normal` 包 | Go 全隧道+MITM 模式（并非「普通 DNS」） | `full_tunnel` |
| `AppWorkMode.DNS` / `DnsMode*` | 服务器模式（局域网 DNS） | `server` |
| `express` 包 | DNS-only 窄路由 VPN | `express`（保留） |
| `RuleDataset.DNS_MODE` | 服务器模式数据集 | `server` |
| `MainActivityCurrentIconAlias` | 唯一 LAUNCHER 入口（真图标开关候选） | `launcher_alias` |
| `LogRouteActivity` | 日志/统计/诊断 8 路由宿主 | `log_host` |
| `tunnel.start(...)`（Kotlin） | GoInspectionTunnel 的封装，非 Go 方法 | — （勿与 `Engine.start` 混淆，后者已死） |
| `GOLD` 色板 | storageValue="indigo" | 迁移保 "indigo"，UI 名可改 |

## 6. 迁移红线（破坏即行为回归，均有多章/Lead 实测支撑）

1. **DTRI 字节契约**：magic 0x44545249/v1/36B 头/12B 节点/12B 边/7×FNV bloom——Kotlin 写 Go 读，逐字段两侧一致（02 章发现 5 + 10 章发现 17 + Lead 双侧复核）。改一端=另一端静默判空。
2. **JSON 短键契约**：`d/b/t/r/a/i/k/e/c/ts/ttl` 等快照键、`negativeTtl*` 恒发（02/09/11 章）；`ttl` 无 omitempty + Kotlin `has()` 区分「真实 0/未知」（10 章发现 12，O-107 教训）。
3. **阻断响应字符串协议两套并存**：normal `ZERO_ADDRESS→"CUSTOM_IP"`、server 直发枚举 `.name`，靠 `ParseResponseType` default 兜底一致（02 章发现 10）——统一前先证明消费面。
4. **sessionGen 代际守卫**：`Stop()` 加 `!running` 早退会回归缓存/证书释放（10 章发现 5，AGENT_MISTAKES O-104/A-017 实录）；保留双测试钉。
5. **usable 判据两版分歧是现状**：Express `rcode∈{NOERROR,NXDOMAIN}`、core 任意 rcode（07 章发现 10 + Lead 定版）；「竞速忽略快速 SERVFAIL」只有 Express 成立。
6. **三模式数据隔离只做了一半**：规则三分库、运行表 DNS_MODE 回落 AppDatabase（02/06/11 章三章独立+Lead 复验）。改=产品决策，不改=注释明示。
7. **rule-index 目录 NORMAL≡DNS_MODE 重叠**：运行链已门控 null，但清理链互删派生物、写链一处硬编码（现状不可达）——Flutter 按 dataset 三分目录（02 章 §4.3 定版 + 11 章 §4.5.3，Lead 亲验入口链未证可达故不记「已发生」）。
8. **存储格式怪癖全保真**：express 缓存键 `#` vs core `|`（07 章发现 10/Lead 复验）；StringSet→JSONArray；`disable_startup_update_check=true`（出厂不查更新，01 章）；缓存三档预设覆写 9 键、negativeTtl 用户不可改恒吃预设（06/07 章）。
9. **三迁移标记一次性语义不可重放**：`local_listen_port_migrated`（5353/5354→1053）、`log_queries_default_off`（隐私翻转）、`default_whitelist_seeded_version=0`（01/11 章）。
10. **`addDisallowedApplication` 不可热改**：排除应用变更=整隧道重建（09 章热更新管线行 :169，onRestartVpn 路径）——Flutter 侧保持「重启换配置」的 UX 语义（含其通知文案）。
11. **minApi 拦截层级不统一**：NORMAL/DNS minApi29 仅 UI 卡片层（11 章发现 12），EXPRESS 有 64 位判定（AppWorkMode.kt:48-61）；allowBackup 回带旧设备的后果未取证（11 章待定⑥）——迁移时补齐服务层守卫或接受现状，显式选。
12. **START_STICKY + null-intent 重建语义**：Express 恒 START_STICKY、重启用持久化标志自愈（08 章发现 6）；normal 待定 3（09 章）——两模式恢复行为不同，勿统一。
13. **应用规则四类互斥=保存时清洗**（非勾选时，04 章发现 10）；`~app=` 在 express/server 评估（packageName=null）时的命中语义（02 章发现 8）。
14. **服务器模式无设备归因**：`setAppResolver/setFirewallChecker` 全仓零调用（11 章发现 5 + Lead 实测）——per-app 规则对 LAN 客户端不生效是现状；勿臆造已有能力。
15. **许可与分发约束**：应用 GPL-3.0 + Go 依赖各自的 copyleft；保留 AAR=保留合规义务面（README+Lead 实测 go.mod）。

## 7. 冻结契约清单（平台通道 API 面）

- 控制面 MethodChannel ≈ 09 章 §3 表的**被消费行**（`startFull/stop/stopStandalone/startStandalone/startStackMitm/stopStackMitm/applyDNSConfig/applyRuleSnapshot/setRewriteRules/setRequestRules/setCosmeticRules/setFilterDNS/setBlockResponseType/setBlockedUIDs/setAppAllowlist/setMitmAllowedUIDs/setExtraPassthroughSuffixes/clearDNSCache/setUseTcpStack/setUIDResolver/setTickIntervalMs/configureOutboundProxy/setAppAllowlist` 等，含 `getDNSCacheStats` 反射位改名固化）。
- 回调面 EventChannel ×7：log/batchLog/raceLog/bootstrapLog/httpLog/outboundProxyStatus/traffic（GoInspectionResolvers.kt 的 10-JSON 字段映射表在 09 章 §2/05 章）。
- 回调注入面反向通道：DomainChecker/AppUidResolver/SocketProtector/UIDResolver/AppResolver（Kotlin 实现，Go 调用）——Flutter 需平台侧 handler，接口签名冻结（09 章 §9.3 中间态）。

## 8. 死代码剔除清单（Flutter 不实现，证据链在各章）

Kotlin：RuleUpdateNotifier 全类（04）｜AgentApiTextParser（06）｜DnsMainActivity 跳板（03/11）｜ExpressWorkModeCard、OptionalFeaturesScreen、ModeReadinessBanner（03/08）｜8 条死路由（03）｜DnsResponseCache 读路径（resolve 链，07）｜core buildBlockedResponse/buildServfailResponse（07）｜getDnsCacheStats 反射包装（07/09）｜DnsVpnService.protectSocket×2 与伴生 6 个 intent 工厂、MainViewModel.toggleVpn 与 WorkModeLifecycleRegistry.startNormalMode 未走路径（09，Lead 复验）｜AppSettings 门面、DitingApp.instance、PermissionDisclosureStore 死键×2+3 方法、load/saveRaceProviderIds、resetWorkModeSelection、DnsModePreferences 死键×2（01/11）｜RuleIndexLayout.deleteAll/allScopeDirectories、SubscriptionUrlHelper.countRules、isCanonical、importTwoPass、compileAllToCss*、RewriteRuleManager.rulesBySource、answersFor 链（02）｜`getPreferredEditor`（06）。
Go：Engine.Start 链、SetTries/SetImportantTries/CheckDomainInTrieFile/原生 trie+bloom、setDNS/setAppResolver/setFirewallChecker/setOutboundAdapter/clearMitmBlacklist/setHttpsBypassRules/getStats（10 章死代码表 + 09 章消费面交叉；rule_compiler.go 本体保留——applyRuleSnapshot 复用）。
量级：Go 约 1,200–1,500 行（10 章估计，逐文件复核为待定）+ Kotlin 若干；剔除时逐条回本清单引证，不扩大。

## 9. 测试迁移策略

1. **直接移植为 Dart golden test**（13 章 §10.1 十二组）：位段表（writeResponseHeader/RST/分片 reason 字面量）、规则解析对偶负例（A-095 组）、IP 字面量/DDR/DohUrl 边界、EWMA/TTL 夹取数值、`identical()` 代际语义。
2. **必须新建**（原空白 Top6，13 章）：三模式业务屏 golden、三传输、订阅全链、tombstone 链、traffic 采样、视觉动效。
3. **丢弃**：9 个源码文本契约测试（isBlank 守卫 32 处）——它们钉的是 Kotlin 文件形态而非行为。
4. **保留 Go 侧全部 21 测试文件**（若走 D1-b）；差分用例是 DTRI/JSON 契约的执法者。
5. 完成判据沿用项目铁律 6：改源码→静态检→单测→构建→目标平台启动验证，不以「编译过」为完成。

## 10. 里程碑（建议顺序，每步含退出判据）

| M | 内容 | 依赖章 | 退出判据 |
|---|---|---|---|
| M0 | 工程骨架+契约冻结测试（DTRI/JSON/通道名） | 02/09/10 | 契约红→绿基线建立 |
| M1 | data/：drift 三库+158 键 prefs+迁移标记 | 01/02 | 与现库文件级互读（sqlite 对拍） |
| M2 | domain/：缓存/调度/usable 判据/阻断四模式 | 07 | 位段与数值 golden 全绿 |
| M3 | express 数据面（codec/窄路由 Builder/劫持表/竞速） | 08/07 | ExpressPacketCodec/Dispatcher 测试移植 |
| M4 | 规则引擎+订阅全链+WorkManager 编排 | 02/04 | badfilter/两遍导入/staging 对拍 |
| M5 | normal：AAR 桥+MITM+CA+热更新管线 | 09/10 | 真机全隧道冒烟+回调 JSON 对拍 |
| M6 | server：standalone 桥+端口/归因现状复刻 | 11 | applyRuleSnapshot 单通道测试 |
| M7 | UI 全量+系统周边 | 03/04/05/06/12 | 屏级 golden+导航对账 |
| M8 | 死代码剔除执行+文档回写「迁移后基线」 | 全 | 第 8 节清单逐条勾销 |

## 11. 与桌面端（Desktop/）的关系（范围提示）

本图谱仅覆盖 Android。`Desktop/internal/dNSS` 与 `Android/tunnel` 是同源不同代的 Go 实现（README 宣称，本系列未核验）；若未来三端共享 Go 核心，第 7 节通道契约是最大公约数候选——属另一份图谱的工作，此处只登记边界。

## 12. 已知缺陷汇总（现状记录，修复=产品决策）

幽灵容器清理（01 R-14）｜DNS_MODE 清理删 NORMAL 索引（02/11）｜RuleListViewModel 硬编码目录（02 旁路 B，不可达）｜allowBackup 全量云备份含混淆级 API key（01/06/13）｜LogRoute 主题不刷新（03）｜QS_TILE_PREFERENCES 无消费者（01/03）｜`#$@#` 迁移误标窗口（02 发现 4，需现网订阅取证）｜negativeTtl 用户不可改（07）｜Bootstrap 探测截断不退 TCP（06/07 不一致）｜RequestLog pendingRuleScope 恒 DNS（04 待定 5）｜Go NODATA 全隧道合成缺陷（02 发现 10）｜DnsVpnService 560 行/RuleOperationWorker 570 行超 550 红线（09/02 实测）。

---

*交叉校验方法声明*：本系列执行「Lead 亲测基础事实 → 子代理分域深读 → Lead 抽样复验承重断言（计数/死代码/契约双侧回读）→ 冲突仲裁回源码定版」流程；抽查记录累计覆盖 01/02/03/04/06/07/08/09/10/11/12/13 各章关键断言，两处子代理错误结论（03 章 API 措辞、07 章 SERVFAIL 段内部矛盾）与两处 Lead 自身误判（「server 几乎无测试」「negativeTtl 摆设」）均已修正留痕——后者符合 AGENT_MISTAKES 铁律 4「判无消费者须全仓查」。
