# 安卓端缺陷分级 · Medium

> 本文档由对安卓端缺陷报告（扫描基线 `main @ 3a048c5`）逐条复核产出的**中严重度**缺陷构成，共 49 条，全部为 A 系列确认缺陷。源报告 `docs/desktop-bug-report.md` 已于 2026-10-18 删除，后续重建时不参考旧版本；本文档的「问题（复核后口径）」与「需修正要点」即为现存口径。分级依据**复核后严重度**；「判定」取 **存在** 或 **存在但需修正**（引证/触发面/影响叙述有偏差，见「需修正要点」）。
>
> - Medium 门槛：默认生产路径上功能完全失效或误导、数据静默丢失、跨模式串档、并发正确性缺口等，但无崩溃、无凭据外泄、无安全门绕过，或危害面被设备/模式门收窄。
> - 「文档原级」列保留已删除原报告的自评等级，用于对照复核后的升降级。原「中高」并入中或高、「低中」并入低，按复核后实际危害定。
>
> **处理状态（2026-10-18）**：49 条全部完成复核与处置。**无一条判定为「问题不存在」**——49 条均复核为「存在」或「存在但需修正」，已全部修复并附回归用例。修复细节见文末「修复记录」；对原文档表述的订正见「需修正要点」。

## 汇总表

| 编号 | 模块 | 问题（复核后口径） | 判定 | 文档原级 | 需修正要点 | 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| A-012 | VPN IPv6 探测 | AUTO 模式路由检查是死代码，有 GUA 地址即启用 IPv6（normal/Express 同犯） | 存在 | 中 | 无 | 已修（normal + express 两侧） |
| A-013 | 数据清理 | 清理删 `filesDir/updates`，APK 实写入 `app-update`，清理落空+残留泄漏 | 存在 | 中 | 无 | 已修 |
| A-014 | 流量统计保留 | `app_traffic_daily` 被「DNS 日志保留天数」清理，专属流量保留无消费者 | 存在 | 中 | 无 | 已修 |
| A-015 | 流量实时速度 | Go 隧道模式下每应用实时网速恒 0，排序/逐项速度永不生效 | 存在但需修正 | 中 | 引证行号错（start 签名在 :84，文档作 :96-100） | 已修 |
| A-018 | Go 引擎并发 | responseType 无锁写×无锁读构成数据竞争；`e.mu` 不建 happens-before | 存在但需修正 | 中高 | domainChecker 撕裂主张不成立（写均在服务前）；死 setter 应剔除；第二竞争对（dynamicResponse）不成立 | 已修 |
| A-020 | DNS 模式总开关 | 「启用域名过滤」在 DNS 模式完全失效：standalone 从不读 filterDNS，快照恒真 | 存在但需修正 | 高 | DnsServerEngine 行号漂移；「三层置位第四层不看」结论成立，降级为中 | 已修（Kotlin+Go 两侧） |
| A-021 | DNS 模式生命周期 | ACTION_STOP 与启动协程竞态，销毁后回填 RUNNING → 孤儿引擎占端口 | 存在但需修正 | 高 | 「UI 显示停止」不是被证伪而是**属实**——RUNNING 就是最终态，即缺陷本身；核心竞态成立，降级为中 | 已修 |
| A-023 | DNS 模式动态拦截 | applyDnsConfig JSON 从不含 dynamicResponse，Go 零值即禁用：死功能 | 存在 | 中 | 机制描述准确，缺根因；VPN 模式**会**发该 key，死功能仅限 DNS 模式 | 已修（补透传+补 key） |
| A-025 | 配置导入 | 未勾选「禁止联网名单」导出的备份再导入静默关闭总开关 | 存在但需修正 | 高 | ConfigTransferScreen 实际在 normal/ui/；受害面收窄 NORMAL/DNS，降级为中 | 已修 |
| A-027 | 配置往返 | latencyTestProviderRefs 被导出/解析但任何导入器不应用：测速节点选择丢失 | 存在 | 中 | 「仅应用五族」实为九族；另 raceProviderRefs 只解析不导出（双向各缺一半） | 已修 |
| A-028 | 批量添加 | 批量丢弃 appInverted，`~app=` 排除规则被反转为「仅这些应用」拦截 | 存在但需修正 | 中 | 丢弃分支**实为 4 处**（`:116/:125/:293/:315`）非 6 处；断链起点在 `ValidDomain` 缺字段；另修 `$修饰符` 被误判为重写箭头 | 已修 |
| A-029 | 批量添加 | 批量 URL 规则绕过 GoUrlRuleManager.parse 归一化直存原文：永不匹配/重复行 | 存在 | 中 | 无 | 已修 |
| A-030 | 规则导入 | CategorizedRuleStreamImporter 的 kind 从不参与过滤，typeSkipped 无写入点 | 存在 | 中 | 行号微偏；结论成立。**文档所述修法（hosts 只收 rewrite）错误**，与既有测试冲突 | 已修 |
| A-031 | 规则缓存 | AllowRuleCache.reloadCustomRules 仅按 pattern 保活订阅 special 规则：同 pattern 修饰规则被逐出 | 存在 | 中 | 合并行实为 `:142`（文档作 `:193`）；根因是 `ExportedSpecialAllowRule` 缺 `source` 字段 | 已修 |
| A-032 | AI 密钥存储 | API 24/25 上 KeyObfuscator 调 java.util.Base64（API 26+，未开 desugaring）必崩 | 存在但需修正 | 高 | **受害面为 API 24/25 全量设备**，不存在「Express 64 位设备门」收窄；三证经 api-versions.xml+Gradle 实证；降级为中 | 已修 |
| A-038 | 订阅暂存隔离 | staging_sub_* 不被「排除订阅」谓词识别：更新窗口内暂存当手动规则显示/计数/误删 | 存在但需修正 | 高 | 实测 `'sub_%'` 41 处、`NOT LIKE 'sub_%'` **20** 处、`NOT GLOB 'sub_*'` **16** 处（非 27/5）；真正不设防的 **4 组**；降级为中 | 已修 |
| A-039 | 订阅崩溃恢复 | recoverInterruptedImports 只清 3 表（漏 goUrl/cosmetic），deleteSubscription 从不触 staging | 存在但需修正 | 高 | 漏的是 goUrl+cosmetic 两族；恢复流程逐族手写而非复用 `deleteBySource`；降级为中 | 已修 |
| A-040 | Express 生命周期 | Express start↔stop 竞态：stop 不取消 start 协程、fd 复用、isRunning 复活 | 存在但需修正 | 高 | 「黑洞非永久」（`:265-267 if (isRunning) stop()` 可自愈）；`START_STICKY` null intent 实际走 `else -> startVpn` 会重跑；降级为中 | 已修 |
| A-041 | 网络诊断 | TunnelDiagnosticsResolver.tunnelResolver 从无赋值点：经隧道 DNS/Ping/Traceroute 恒报「VPN 未运行」 | 存在 | 高 | 功能 100% 恒坏但默认开关 OFF，仅主动开启者受害→降级为中；零赋值经全仓 grep（含 test/go/ts）确认 | 已修 |
| A-042 | DNS 测速 | DnsLatencyTester.testDoh 的 toHttpUrl() 在 try 外：畸形 DoH URL 测速未捕获崩溃 | 存在 | 中 | 行号逐字吻合；崩溃链实测成立（`testAverage` 无 per-provider 隔离，整轮测速抛出） | 已修 |
| A-045 | DNS 测速 | 测速计时窗口含 bootstrap/系统解析（DoT/DoH/Plain 三路径）：上游被冤枉慢 | 存在 | 中 | BootstrapSelector 实际在 core/diagnostic/（文档作 core/dns/）；超时上界 3s×N×2；污染的是 healthEngine ewma 而非 UI 耗时 | 已修 |
| A-046 | 日志写入 | RaceLogger/HttpRequestLogger 批量插入无 runCatching（对照 DnsLogger 有）：崩溃+丢日志 | 存在 | 中高 | 崩溃面含 Express 同族裸 flush；停机链中断后续属实；改前行号 `RaceLogger.kt:137`/`HttpRequestLogger.kt:100` | 已修 |
| A-049 | 日志仪表盘 | 仪表盘把防火墙拦截的连接标「旁路」：resultLabel 忽略 result==BLOCKED | 存在 | 中 | Go 生产者路径应为 engine_connection_log.go；BLOCKED 连接行确入仪表盘；同屏两处孪生正确对照 | 已修 |
| A-051 | 规则列表 | 黑/白/重写列表 loadPage 无任务取消：并发加载旧覆新 | 存在 | 中 | RewriteListViewModel **完全没有** searchJob（「仅搜索防抖」不成立）；RuleListViewModel 为同缺陷第 4 处 | 已修（5 处） |
| A-052 | 黑名单筛选 | 黑名单「规则订阅」页签漏订阅携带的 URL 拦截规则，计数同缺 | 存在 | 中 | 白名单有正确 `SUBSCRIPTION` 分支且留注释自认此不对称（逐字核对属实） | 已修（统计卡未补） |
| A-053 | 崩溃备份 | 连崩阈值用 >= 且自动导出成功后不置抑制标志：每崩刷一份全量备份 | 存在但需修正 | 中高 | `clearCrashLogs` 是抑制位**清零重武装**非置位（文档表述相反）；`MAX_CRASH_LOGS=8` 是文件上限不构成自限 | 已修 |
| A-054 | 崩溃计数 | collectMinimalReport 无保护在先、onCrashOccurred 在后：SOE/OOM 计数永不执行 | 存在 | 中 | 无（结构确证；浅栈不炸=现场无报告合理反证） | 已修 |
| A-059 | 密钥混淆 | KeyObfuscator 把 UTF-16 code unit 截成单字节：非 ASCII 密钥往返静默损坏 | 存在但需修正 | 低中 | JVM 实测坐实（「密钥abc」→「?abc」）；「全 API 等级都犯」应改「API≥26 上犯」；syncProviderToConfig 扩大污染 | 已修 |
| A-060 | 更新清理 | 下载失败 catch 无条件清全局单槽记录：旧版 APK 成孤儿+强制重下 | 存在但需修正 | 低中 | 标题「检查到新版失败」措辞失准，实为**下载**新版失败（check 路径不触 clear） | 已修 |
| A-063 | Go 元素隐藏 | buildCosmeticCss 从不并入 rules.GlobalException：全局 #@# 例外静默失效 | 存在 | 中 | 触发路径应走白名单页（黑名单 addRule 拒 #@#）；真实 Go 代码 go test 实证例外被丢弃 | 已修 |
| A-075 | Express 规则添加 | Express 可添加元素隐藏规则并提示成功，但永不编译 CSS、列表不显示 | 存在但需修正 | 中 | 「无任何 UI 手段删除」过强；闸门原本只拦 DNS_MODE（文案却说「仅普通模式」，自相矛盾） | 已修（统一闸门） |
| A-077 | HTTPS 检查证书 | 本会话是否 MITM 由缓存位 isHttpsInspectionReady 决定，异步真校验失败不重启隧道 | 存在 | 中 | 无（异步回调仅写偏好、不触碰 engine，全仓无其他动作） | 已修 |
| A-078 | 会话统计归零 | 编辑排除/禁止联网名单触发 restartVpnLocked → TrafficStatsManager.start 无条件清本会话 | 存在但需修正 | 中 | 「用户无任何提示」不成立（有「正在重连」toast，但未提会话清零）；UI 在 normal/ui/ | 已修 |
| A-079 | 缓存设置串档 | 极速模式缓存设置屏四处 Store 调用全漏传 dataset：读写打到 NORMAL prefs | 存在 | 高 | 四处调用独立数为 4，与文档一致；引擎只认 EXPRESS；降级为中 | 已修 |
| A-080 | AI 分析串库 | AgentAnalysisSheet 硬编码 AppDatabase+NORMAL 广播：极速 DNS 缓存页 AI 分析读错库 | 存在 | 高 | 硬编码点在 `:95` 非 `:92-104`；机制无误；降级为中 | 已修 |
| A-081 | 动态拦截极速侧 | 极速模式动态拦截可开可存，express/ 引擎零读取：功能纯空转 | 存在但需修正 | 中 | 「零读取」应改「引擎零消费、UI 仅读来渲染谎报文案」（ExpressRuleControlScreen:128 确读取）；DNS 模式那半边归 A-023 | 已修 |
| A-082 | 保留天数热更新 | 普通模式改「日志保留天数」不触发 onRuntimeDnsSettingsChanged：引擎按旧快照 prune | 存在 | 中 | 对照同屏日志模式项正确触发即证据；引擎快照 `activeLogRetentionDays` 在 `:50`、刷新点 `:96` | 已修 |
| A-083 | SAF 授权泄漏 | 全仓 5 处 takePersistableUriPermission、0 处 release：删图/删订阅后授权永久残留 | 存在 | 中 | take 5、release 0 独立计数一致；**订阅删除侧无法修**——`SubscriptionEntity` 无「是否持久化授权」标志，无条件 release 会误撤默认应用提供的文件 | 已修（订阅侧受模型限制） |
| A-084 | 服务器模式向导 | DNS 模式使用向导接入信息硬编码端口 1053（5 处），从不读 localListenPort | 存在 | 中 | **实测 6 处**（文档记 5 处，漏 `ModeOnboardingSteps.kt:140`）；触发需用户改过端口 | 已修 |
| A-085 | Go 全隧道半关闭 | countingConn 内嵌 net.Conn 接口致 CloseWrite 不提升：全隧道 TCP 半关闭永久失效 | 存在 | 中高 | 类型系统事实本会话 Go 复算确认；legacy 直连路径不经包装、应排除 | 已修 |
| A-087 | DoT 阻断开关 | SetBlockEncryptedDns 是死开关：blockEncryptedDNS 仅 1 Store 0 Load，853 恒硬拦 | 存在但需修正 | 中 | 第三消费点应为 `mitm_handler.go` 非 `engine_mitm.go`；1 Store/0 Load 全 Go 树实证 | 已修 |
| A-088 | 极速 bootstrap | BootstrapSelector 两处 Store 调用漏传 dataset：极速整套 bootstrap 失效 | 存在 | 中高 | 无（同族调用正确对照；极速运行期恒读 dns_vpn_prefs） | 已修 |
| A-089 | 应用放行闸门 | serveDNS 缓存命中/stale 分支不续 app_allowlist IP 授权：白名单应用「解析成功、连接恒被拦」 | 存在 | 中 | 无（两表独立性、rrTTL<缓存 TTL 数值差、可达入口集合均复核一致；legacy 路径已正确排除） | 已修 |
| A-091 | 服务商健康页 | ProviderHealthEngine 全仓零实例化、recordResult 零调用者：健康页恒空、权重是编造均匀值 | 存在 | 中 | 无（grep 仅命中类声明，零实例化亲验；`hedgeMisses` 无写 API，本修复未新增生产者，该字段仍恒 0） | 已修 |
| A-092 | bootstrap 健康双源 | BootstrapHealthEngine 三实例并存、flush→saveAll 全表 JSON 覆盖单键：互抹健康/冷却 | 存在 | 中 | 补强：store 单文件单键使 Express 与 NORMAL 覆盖更直接 | 已修 |
| A-093 | regex 规则大小写 | Kotlin regex 规则不注入 (?i)，Go 恒 (?i)：双引擎对同一订阅给出相反拦截 | 存在 | 中 | Go 注入点在 `policy_engine.go:110-114`，**非** `rule_compiler.go`；**不可**用 `RegexOption.IGNORE_CASE`（内联组开头时会与 Go 分叉） | 已修 |
| A-094 | `#$@#` 例外解析 | COSMETIC_DELIMITERS 缺 #$@#：例外型元素隐藏 substringBefore('#') 兜底整域拉黑 | 存在 | 中 | 第二形式垃圾串实为 `example.com#$@` 非 `#$`；**更严重的是兜底截断把畸形行放大成整域屏蔽**，修法须同时收紧截断且分隔符长优先 | 已修 |
| A-098 | bootstrap 健康污染 | BootstrapSelector 把日志落库异常误判为解析失败：一次成功解析双记+撤缓存 | 存在 | 中 | RaceModeSettingsViewModel 单参构造 flushScope=null→批量写只走栈内同步路径，异常必落 try（实证） | 已修 |
| A-099 | 预置白名单种入 | DefaultWhitelistSeeder seed(forceReset) 先删后解析且失败仍置位：直通域全删零补、同版本内永不自愈 | 存在 | 中高 | asset https_passthrough.txt 自数 =5 条（与文档一致，非「33」）；放大器是「先删后解析」+「无条件标记已初始化」叠加 | 已修 |

---

## 需修正要点补充说明

以下条目除表中摘要外，还有对后续修复方向有直接影响的细节订正：

- **A-018**：`SetFirewallChecker`(:273)、`SetAppResolver`(:277) 全仓 Kotlin 零调用者（死 setter），应从竞争面剔除。真实竞争对是 `SetBlockResponseType` 无锁写 × `engine_standalone.go:248` 单侧持锁读（单侧持锁不构成 happens-before）；文档所列 `dynamicResponse`/`dynamicBlocks` 竞争对**不成立**（两侧都持 `e.mu` 或 tracker 自带锁）。另修 `ApplyDNSConfig` 校验前先落盘的半应用。
- **A-020**：Go 侧一半由 `serveDNS` 补 `filterDNS` 守卫完成（`engine_standalone.go:147-154`），Kotlin 侧由 `DnsFilterMasterSwitch` 快照开关完成，**两套机制都要更新**，缺一不可。
- **A-023**：VPN 模式**发** `dynamicResponse`（`normal/HttpsDnsConfigSnapshot.kt:51-55`），只有 DNS 模式不发——「死功能」仅对 DNS 模式成立。Go 侧 tag 为 `enabled`/`requestThreshold`/`windowSeconds`/**`nxDomainDurationSeconds`**（驼峰 D），且 `dynamicBlockConfig` 内**没有** `responseType`；按 `nxdomainSeconds` 写会被 Go 静默忽略。另发现第二处缺口：`refreshDnsEngine()` 读 `DnsModeManager.config.value` 缓存，而设置屏直接写 prefs 不经 `updateConfig`，故补 key 后仍须 `reloadConfig()` 才即时生效。
- **A-028**：`appInverted` 硬编码是 **4 处**不是 6 处；断链起点在 `BatchRuleModels.ValidDomain` 缺字段，不在 Validator。**附带修出第二个既有缺陷**：`$~app=` 里的 `=` 被分支 5 当成重写箭头，导致任何「裸域名 + `$修饰符`」输入被静默拒绝为「域名格式无效」。
- **A-030**：**文档所述修法（hosts 只收 rewrite）错误**——`CategorizedRuleStreamImporterTest.kt:69-108` 已断言 domain 订阅合法携带 rewrite，按原文实现会让既有测试变红。正确口径是「hosts 排除 allow/url/cosmetic」。
- **A-038**：备注推荐的「staging 改名 sub_staging_<id>」有副作用——届时 `LIKE 'sub_%'` 会命中 staging，展示面从「混入手动」变「混入订阅」，非纯收益。修法是给 4 组谓词加 `AND source NOT LIKE 'staging_sub_%'`，不改名。
- **A-040**：`ExpressTunnelManager.kt:265-267 if (isRunning) stop()` 使第二次 start 干净重启，黑洞非永久；文档「START_STICKY 重启 intent 为 null 直接 return」误读，实际 `:79 else -> startVpn(intent)` 会重跑。
- **A-053**：修复时勿被文档「clearCrashLogs 置位」误导——`putBoolean(KEY_HAS_MANUALLY_EXPORTED, false)` 是清零重新武装抑制器，与文档表述相反。
- **A-079/A-080**：原报告自评「高」，因后果为跨模式偷改防护设置/读到错库日志（无崩溃、无凭据外泄），按门槛下调为中，非降级其机制。
- **A-085**：底层 `adapter.TCPConn` 实为 `*tcpConn{*gonet.TCPConn}`，gonet.TCPConn 有 CloseWrite，故包装确吞掉了本可提升的能力；legacy 路径 :51 传未包装 conn 不受影响。
- **A-093**：**不可**用 `RegexOption.IGNORE_CASE` 实现对齐。Go 只做字符串前缀判断（`HasPrefix("(?i)")`），故 `(?-i)Foo` 最终敏感；而 `IGNORE_CASE` 对以 `(?s)`/`(?m)` 开头的 pattern 不会补 `(?i)`，会与 Go 分叉。逐字镜像前缀判断是唯一完全一致的做法。
- **A-099**：`seed()` 必须「先解析、后删除」，且只有写入行数 > 0 时才写两个初始化 marker；只改其中一件仍会丢数据。

---

## 修复记录

### Go 隧道引擎（`Android/tunnel/`）

- **A-018**：`responseType` 改 `atomic.Int32`（`engine.go:48`）并新增 `storeBlockResponseType`/`blockResponseType` 访问器，三个读点全部改用访问器；`ApplyDNSConfig` 的发布动作移到全部校验通过之后。回归：`engine_block_response_test.go`（4 例）。
- **A-020（Go 半边）/ A-023**：`serveDNS` 在 rewrite 之后、policyEngine 之前补 `if !e.filterDNS.Load() { e.standaloneForward(...) }`（`engine_standalone.go:147-154`）；抽出 `effectiveBlockResponseType(domain)`（`engine_config.go:411`）统一「配置模式 + 动态升级」，`standaloneBlock`、`handleBlockedDomain`、`handleFirewallBlock` 三处共用。回归：`TestServeDNSSkipsFilteringWhenFilterDNSDisabled`、`TestServeDNSBlocksWhenFilterDNSEnabled`、`TestFullTunnelBlockEscalatesViaDynamicBlock`、`TestHandleBlockedDomainUsesDynamicResponse`。
- **A-063**：`buildCosmeticCss` 按 `len(rules.GlobalException)` 分配 exceptions 映射却从不填充，现全量灌入（`mitm_local_server.go:65-71`）。回归：`TestCosmeticCssAppliesGlobalException`。
- **A-085**：新增 `countingHalfCloseConn`（`traffic_tracker.go:119-129`）显式转发 `CloseWrite`，`WrapClientConn` 仅当底层确实支持时才返回该类型（不给 UDP 风格 conn 凭空造能力）。回归：`traffic_tracker_test.go`（4 例）。
- **A-087**：新增 `shouldBlockEncryptedDNS(serverPort)`（`engine_full_tunnel.go:377-388`），三处 853 硬拦改为按开关判断；`NewEngine()` 里 `blockEncryptedDNS.Store(true)` 作 fail-closed 默认。回归：`engine_encrypted_dns_test.go`（3 例）。
- **A-089**：新增 `rememberAppAllowlistWire(uid, rawResponse)`（`engine_app_allowlist.go:117-129`），复用上游同一份 `rememberAppAllowlistResponse` 授权逻辑，接线到缓存命中（`:316`）与 stale（`:338`）两分支；TTL=0、未指定地址、负缓存均不授权。回归：`engine_app_allowlist_test.go`（4 例，含端到端）。

### Kotlin 客户端（`Android/app/`）

- **A-012**：`isIpv6Usable(hasGlobalIpv6, hasIpv6Route) = hasGlobalIpv6 && hasIpv6Route`（`normal/DnsVpnTunnelManager.kt:346`、`express/ExpressTunnelManager.kt` 同款），GUA 地址不再单独放行 IPv6。回归：`DnsVpnTunnelManagerIpv6UsableTest`。
- **A-013**：新增 `update/AppUpdateDirectories.kt` 作目录名单一真相源（复用 `AppUpdateManager.UPDATE_DIRECTORY`），`DataCleanupManager` 改调它。回归：`AppUpdateDirectoryContractTest`。
- **A-014**：新增 `LogMaintenance.pruneExpiredTrafficStats(database, retentionDays)`，`pruneExpiredLogs` 不再碰流量表；`start()` 新增 `trafficRetentionDaysProvider` 默认 `{0}` 保持 Express 旧行为。回归：`LogMaintenanceTrafficRetentionTest`。
- **A-015**：新增 `TrafficSpeedEstimator.updateAppSpeedsForTick(appDeltas, elapsedSeconds)`，`onGoTrafficTick` 每 tick 喂 per-app EMA，缺席应用走衰减，空 tick 不新增条目。回归：`TrafficSpeedEstimatorAppTickTest`（5 例）。
- **A-020（Kotlin 半边）**：新增 `DnsFilterMasterSwitch`（`@Volatile` 标志 + `set(): Boolean` 返回是否变化），`DomainPolicy` 经闭包读它，`syncRules()` 先 `set(config.adBlockEnabled)` 再建快照；`updateConfig()` 的 `filteringChanged` 分支补 `syncRules()`。
- **A-021**：新增 `DnsModeStartGuard` 代际 token 守卫；`ACTION_STOP` 先 `onStopRequested()` + `startJob?.cancel()` 再 `stopSelf()`。
- **A-023（Kotlin 半边）**：`DnsModeConfig` 加 `dynamicBlockResponse: DynamicBlockResponseConfig`（复用 NORMAL 模型）；新增 `server/model/DnsDynamicBlockJson.kt` 严格镜像 Go tag；`DnsModePreferences.loadConfig` 经既有 `DnsRuleSettings.dynamicBlockResponseConfig` 读取（不复制 key）；`updateConfig()` 新增 `dynamicBlockChanged` 触发；`DnsModeManager.reloadConfig()` 修掉「设置屏直接写 prefs 而内存副本不更新」的第二处缺口。回归：`DnsDynamicBlockJsonTest`（7 例，含键名反向断言）。
- **A-025**：新增纯函数 `shouldApplyImportedBlockedAppsEnabled(hasImportedList, currentEnabled, importedEnabled)`，开关随名单导入。
- **A-027**：`ConfigExporter` 补导出 `raceProviderRefs`，`ProviderConfigImporter` 补落库 `latencyTestProviderRefs`（两侧各缺一半，均已补齐）。
- **A-028**：`appInverted` 贯穿 model → classify → validate → insert（`ValidDomain` 加字段、`ClassifiedLine.Domain` 加字段、去重 key 加字段），落库改走 `BatchRuleEntities.kt` 纯函数；另修分支 5 —— 抽出 `modifierSectionStart(raw)` 判据，判断箭头前先剥掉修饰符段，`$~app=` 的 `=` 不再被当成重写箭头。回归：`BatchRuleAppScopeAndUrlNormalizationTest`（18 例）。
- **A-029**：`validateUrl` 改为先 `goUrlRuleManager.parse(...)`，用返回的 `pattern`/`kind` 作为去重 key 与落库值；解析失败归为 invalid（原先是静默存脏数据）。
- **A-030**：`kind` 真正接上（`SubscriptionKind.isHosts(kind)` 决定 `acceptsDomainOnlyFamilies`），hosts 订阅下 allow/urlBlock/urlAllow/cosmetic 计入 `typeSkipped`；`countRules` 同步加 `kind` 保证进度总数一致。
- **A-031**：`ExportedSpecialAllowRule` 加 `source: String = USER_SOURCE`，`AllowRuleCacheLoader` 两处构造点补 `source = entry.source`，`AllowRuleCache` 改调 `retainSubscriptionSpecialRules(current, reloaded)` 按 `source.startsWith("sub_")` 保留。回归：`AllowRuleSpecialRulesReloadTest`（5 例）。
- **A-032 / A-059**：`KeyObfuscator` 改为纯 Kotlin UTF-8 字节往返 + 三组 XOR 密钥，新增 `util/Base64Codec.kt`（RFC 4648 带 padding），彻底移除 `java.util.Base64` 依赖。回归：`KeyObfuscatorTest`（11 例，含非 ASCII/emoji/长串往返与 RFC 向量）。
- **A-038**：4 组用户规则谓词补 `AND source NOT LIKE 'staging_sub_%'` / `NOT GLOB 'staging_sub_*'`（`BlockRuleDao:426`、`AllowRuleDao:370`、`RewriteRuleDao:45-49`/`:67`），采用加排除条件而非改名方案。
- **A-039**：抽出 `deleteSource(sources, source)` 一次删 5 个 DAO，staging 与 `sub_` 两条路径都走它，goUrl/cosmetic 的 staging 行不再永久泄漏。回归：`SubscriptionImportRecoveryStagingTest`（2 例）。
- **A-040**：新增 `ExpressLifecycleGuard` 同款代际 token 守卫，`ExpressVpnService` 接入。回归：`ExpressLifecycleGuardTest`。
- **A-041**：`DitingApp.onCreate()` 为 `TunnelDiagnosticsResolver.tunnelResolver` 赋值（`DitingApp.kt:55-59`），lambda 每次实时读 `activeService` 并经 `runCatching` 隔离异常，隧道未运行时仍返回 null 并保留原文案。回归：`TunnelDiagnosticsResolverTest`（11 例）。
- **A-042**：新增 `core/dns/DohUrlParser.kt`，`testDoh` 改为 `parseOrNull(...) ?: return Result(success = false, ...)`，畸形 URL 降级为单行失败而非整轮测速抛出。回归：`DohUrlParserTest`（9 例）。
- **A-045**：新增 `util/LatencyWindow.kt`，DoH/DoT/Plain 三条路径统一改为「先解析、后开窗」，计时只覆盖 DNS 查询本身；setup 失败记 0 不伪装成一次测量。回归：`LatencyWindowTest`（6 例）。
- **A-046**：`RaceLogger.flushLocked()`/`HttpRequestLogger.flushLocked()` 改 `runCatching { dao.insertAll(batch) }.onFailure { pending.addAll(0, batch) }`——吞异常并向队首回填供下次重试，DB 写失败不再打断 `flushLoggers()` 停机链。回归：`LogWriterFailureIsolationTest`（5 例）。
- **A-049**：新增 `ui/dashboard/DashboardLogLabels.kt` 收敛 `status`/`resultLabel` 两个孪生映射；`resultLabel` 先按 `log.result` 分派，仅 `PASSED` + `isConn` 时替换为「旁路」，`BLOCKED` 优先于 `isConn`。回归：`DashboardLogLabelsTest`（9 例）。
- **A-051**：新增 `util/LatestRequestGate.kt`（按**身份**比较——请求是 data class，`==` 会把旧请求误判为最新，正好废掉本修复）；`RewriteListViewModel`/`RuleListViewModel` 的 `loadPage` 改为「快照 → cancel 旧任务 → 用快照查询 → 写回前二次校验」。回归：`LatestRequestGateTest`（9 例）。
- **A-052**：URL/cosmetic 列表装配抽到 `ui/BlacklistModels.kt`（与 `WhitelistModels.kt` 同构），`queryBlacklistUrlItems` 的 `when` 补 `SUBSCRIPTION`（原先掉进 `else -> emptyList()`）。
- **A-053**：抽出 `shouldAutoExport(consecutiveCount, hasExported)`，自动导出成功分支补 `putBoolean(KEY_HAS_MANUALLY_EXPORTED, true)`，同一轮连崩只备份一份。回归：`CrashLogManagerAutoExportTest`（4 例）。
- **A-054**：新增 `crash/CrashCaptureSequence.kt`（逐步隔离执行、失败回调自身也 `runCatching`），`CrashHandler.uncaughtException` 改为 `breadcrumb → minimal-report → full-report → crash-bookkeeping` 4 步序列，`crash-bookkeeping` 恒执行。回归：`CrashCaptureSequenceTest`（4 例）。
- **A-060**：抽出 `shouldClearDownloadRecord(recordedVersion, failedVersion)`，下载失败只清**同版本**记录，旧版已下载的 APK 记录不再被误清。回归：`AppUpdateDownloadRecordRetentionTest`（4 例）。
- **A-075**：新增 `core/rule/CosmeticRuleSupport.kt` 共享闸门 `cosmeticRuleRejection(dataset)`（NORMAL → null，其余返回拒绝文案）；`BlacklistViewModel`、`WhitelistViewModel`、`BatchRuleClassifier` 三条路径统一接入，`BatchRuleEntities.committableCosmeticItems(items, dataset)` 兜底；`clearUserBlacklist()` 的 `deleteUserBlockRules()` + `compileScopedCss()` 包进 `dataset == NORMAL`。
- **A-077**：`isHttpsInspectionCertificateInstalled()` 记录本会话所用缓存位，`verifyHttpsInspectionCertificateAsync()` 比对真实结果，不一致时经 `DnsVpnRuntimeConfigManager.restartForCertificateMismatch()` 在 `refreshMutex` 下重启隧道。回归：`DnsVpnTunnelManagerCertificateMismatchTest`（3 例）。
- **A-078**：`TrafficStatsManager.start()` 用 `shouldResetSessionCounters(wasRunning) = !wasRunning` 判定，`restartVpnLocked()` 的重入不再清零会话；`lastGoTickTimeMs` 仍无条件刷新。回归：`TrafficStatsManagerSessionResetTest`（2 例）。
- **A-079 / A-080 / A-084 / A-088（Express 侧）**：4 处 Store 调用补 `dataset`；`AgentAnalysisSheet` 按数据集解析规则库/日志库；端口动态化（6 处硬编码 1053 全部改为读 `localListenPort`，不可绑定端口不再静默回退）；`ExpressTunnelManager` 两处传 `RuleDataset.EXPRESS`。回归：`DnsModePortAndFilterSwitchTest`、`AppRuleConfigImporterBlockedAppsSwitchTest`。
- **A-081**：新增 `express/ExpressDynamicBlockSupport.kt`（`isEscalationApplied`/`isMisleadingFor`/`blockResponseSubtitle`/`datasetLabel`），`isEscalationApplied` 收为 `dataset != EXPRESS`（DNS 模式经 A-023 后真正生效，不该再谎报不生效）。回归：`ExpressDynamicBlockSupportTest`（7 例）。
- **A-082**：新增 `ui/LogRetentionSettingsActions.kt` 把「改状态 → 落盘 → 通知引擎」顺序固化，保留天数单选改调它。回归：`LogRetentionSettingsActionsTest`（3 例）。
- **A-083**：新增 `util/PersistableUriPermissions.kt`（`take`/`release`/`releaseString`，均 `runCatching`）与 `util/SafGrantDecisions.kt`（纯函数决策）；三处 UI 改为调用 helper——`.txt` 校验失败与重选替换两条路径释放、删壁纸时释放、两处导入在 WorkManager 任务结束后释放。回归：`SafGrantDecisionsTest`（9 例）。
- **A-091**：`RaceModeSettingsViewModel.runLatencyTest()` 实例化 `ProviderHealthEngine` 并对每个测速结果 `recordResult`，随后 `flush` + 重新 `loadAll` 刷新 UI，`onCleared()` 中 `close()`；`recordResult` 算术抽为 `core/diagnostic/HealthSnapshotMath.kt`。回归：`HealthSnapshotMathTest`（11 例）。
- **A-092**：两个 Health Store 全部方法加尾部 `dataset` 并按 `dataset.prefsName()` 取 prefs；`saveAll` 由「整键覆盖」改 merge（`HealthStoreJson.merge`），reset 路径新增 `replaceAll` 避免被 merge 复活已删 id；静态单槽 `activeEngine` 改为按 dataset 分槽的 `ActiveHealthEngineRegistry`（`clearIfCurrent` 按**身份**比较）。回归：`HealthStoreJsonTest`（10 例）、`HealthEngineRegistryTest`（8 例）。
- **A-093**：新增 `core/rule/RuleRegex.kt`，`compile(pattern)` 逐字镜像 Go 的 `HasPrefix("(?i)")` 守卫，`containsMatch` 用非锚定 `containsMatchIn`；两个 matcher 改调它。回归：`RuleRegexTest`（6 例）。
- **A-094**：`COSMETIC_DELIMITERS` 改长分隔符优先 `listOf("#$@#", "#@#", "##", "#?#", "#$#")`，`parseCosmeticLine` 阶梯把 `#$@#` 放最前且 `isException` 认 `#$@#`；兜底截断收紧为「只有前面是空白的 `#` 才当注释剥掉」，`#` 粘在 pattern 上返回 `unsupportedCount = 1` 而不再降级成整域屏蔽。回归：`AdblockRuleLineParserCosmeticDelimiterTest`（9 例）。
- **A-098**：`BootstrapSelector` 的 try 收窄为只包裹 Bootstrap DNS 往返，成功后的副作用（`recordResult`、`logger.log`、`putCached`）移出，新增 `recordOutcome(...)` 对健康记录与日志写入各自 try/catch 且仅放行 `CancellationException`。
- **A-099**：`seed()` 改「先解析、后删除」，解析 0 条时返回 0 且不动既有 preset 行；`ensureInitialized` 只有 `shouldMarkInitialized(seeded)`（即 `seeded > 0`）时才写两个 marker。回归：`DefaultWhitelistSeederPresetTest`（5 例，含直接读 asset 断言 5 条）。

### 验证

- Kotlin：`cd Android; .\gradlew.bat testDebugUnitTest --offline` → **448 tests, 0 failed, 2 skipped**（74 个测试套件）。
- Go：`cd Android/tunnel; go build ./...` 通过；`go vet ./...` 干净；`go test -count=1 ./...` ok。
- `gofmt`：仓库基线即因 CRLF 全量报未格式化，故判据为「CRLF 归一化后与 `git show HEAD:<file>` 基线对照真差异行数」——11 个改动文件**无一比基线更差**，新增测试文件真差异均为 0。

### 本轮未覆盖 / 已知限制（如实记录）

1. **A-083 订阅删除侧未修**：`SubscriptionEntity` 只有 `url` 与 `sourceType`，无「是否持久化授权」标志，无法区分「本 App take 过的授权」与「默认应用提供、从未持久化的文件」；无条件 release 会误撤后者。需先加字段。
2. **A-052 统计卡未补订阅计数**：`BlacklistStats` 仍无 `subscriptionTotal`/`subscriptionEnabled`（`WhitelistStats` 有），补齐需改 `ui/components/` 统计卡 UI。
3. **A-091 `hedgeMisses` 仍恒 0**：该字段无任何写 API，本修复只让权重由实测样本驱动，未新增 hedgeMisses 生产者。
4. **A-087 运行时热切换**：已核实「VPN 重连会重建引擎并重读偏好」（`DnsVpnTunnelManager.kt:303` → `GoInspectionTunnel.configureEngine()` → `setBlockEncryptedDns`），故开关变更经既有的 `refreshAppExclusions` → 重连路径即生效，Go 侧 fail-closed 默认覆盖不推偏好的两个入口。
5. **`tunnel.aar` 需重建**：Go 侧改动要进 App 必须用 gomobile 重新生成 `Android/app/libs/tunnel.aar`（配方见 `docs/development/aar-build-notes.md`）。**本次未重建**，故 App 内实际运行的仍是旧 AAR。
6. **超出 550 行的既有文件**：`RuleOperationWorker.kt`（572）、`DnsVpnService.kt`（560）、`AllowRuleDao.kt`（554）。三者**改前即已超限**，本次改动均为最小必要（`DnsVpnService`/`RuleOperationWorker` 净 +0 行，`AllowRuleDao` 仅改谓词字符串），未扩大；拆需另立任务。
7. **`-race` 无法执行**：`go test -race` 报 `-race requires cgo`，环境无 C 编译器，A-018 的并发结论为静态论证（逐写点/读点枚举 + 锁的全序论证），无 race detector 证据。
