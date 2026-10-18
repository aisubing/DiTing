# 安卓端缺陷分级 · Medium

> 本文档由对 `docs/desktop-bug-report.md`（扫描基线 `main @ 3a048c5`）逐条复核产出的**中严重度**缺陷构成，共 49 条，全部为 A 系列确认缺陷。分级依据**复核后严重度**；「判定」取 **存在** 或 **存在但需修正**（引证/触发面/影响叙述有偏差，见「需修正要点」）。
>
> - Medium 门槛：默认生产路径上功能完全失效或误导、数据静默丢失、跨模式串档、并发正确性缺口等，但无崩溃、无凭据外泄、无安全门绕过，或危害面被设备/模式门收窄。
> - 「文档原级」列保留原报告自评等级，用于对照复核后的升降级。原「中高」并入中或高、「低中」并入低，按复核后实际危害定。
> - 详细正文见原文档对应小节。

## 汇总表

| 编号 | 模块 | 问题（复核后口径） | 判定 | 文档原级 | 需修正要点 |
| --- | --- | --- | --- | --- | --- |
| A-012 | VPN IPv6 探测 | AUTO 模式路由检查是死代码，有 GUA 地址即启用 IPv6（normal/Express 同犯） | 存在 | 中 | 无 |
| A-013 | 数据清理 | 清理删 `filesDir/updates`，APK 实写入 `app-update`，清理落空+残留泄漏 | 存在 | 中 | 无 |
| A-014 | 流量统计保留 | `app_traffic_daily` 被「DNS 日志保留天数」清理，专属流量保留无消费者 | 存在 | 中 | 无 |
| A-015 | 流量实时速度 | Go 隧道模式下每应用实时网速恒 0，排序/逐项速度永不生效 | 存在但需修正 | 中 | 引证行号错（start 签名在 :84，文档作 :96-100） |
| A-018 | Go 引擎并发 | responseType 无锁写×无锁读构成数据竞争；`e.mu` 不建 happens-before | 存在但需修正 | 中高 | domainChecker 撕裂主张不成立（写均在服务前）；死 setter 应剔除 |
| A-020 | DNS 模式总开关 | 「启用域名过滤」在 DNS 模式完全失效：standalone 从不读 filterDNS，快照恒真 | 存在但需修正 | 高 | DnsServerEngine 行号漂移；「三层置位第四层不看」结论成立，降级为中 |
| A-021 | DNS 模式生命周期 | ACTION_STOP 与启动协程竞态，销毁后回填 RUNNING → 孤儿引擎占端口 | 存在但需修正 | 高 | 「UI 显示停止」被状态机覆盖顺序证伪；核心竞态成立，降级为中 |
| A-023 | DNS 模式动态拦截 | applyDnsConfig JSON 从不含 dynamicResponse，Go 零值即禁用：死功能 | 存在 | 中 | 无 |
| A-025 | 配置导入 | 未勾选「禁止联网名单」导出的备份再导入静默关闭总开关 | 存在但需修正 | 高 | ConfigTransferScreen 路径不存在（在 normal/ui/）；受害面收窄 NORMAL/DNS，降级为中 |
| A-027 | 配置往返 | latencyTestProviderRefs 被导出/解析但任何导入器不应用：测速节点选择丢失 | 存在 | 中 | 「仅应用五族」实为九族；另 raceProviderRefs 只解析不导出 |
| A-028 | 批量添加 | 批量丢弃 appInverted，`~app=` 排除规则被反转为「仅这些应用」拦截 | 存在但需修正 | 中 | 丢弃分支实为 6 处非 3 处；模型文件路径更正 |
| A-029 | 批量添加 | 批量 URL 规则绕过 GoUrlRuleManager.parse 归一化直存原文：永不匹配/重复行 | 存在 | 中 | 无 |
| A-030 | 规则导入 | CategorizedRuleStreamImporter 的 kind 从不参与过滤，typeSkipped 无写入点 | 存在 | 中 | 行号微偏；结论成立 |
| A-031 | 规则缓存 | AllowRuleCache.reloadCustomRules 仅按 pattern 保活订阅 special 规则：同 pattern 修饰规则被逐出 | 存在 | 中 | 合并行 :192（文档 :193）；结论成立 |
| A-032 | AI 密钥存储 | API 24/25 上 KeyObfuscator 调 java.util.Base64（API 26+，未开 desugaring）必崩 | 存在但需修正 | 高 | 未提 Express 64 位设备门，受害面收窄；desugaring/minSdk/Base64 since=26 三证自 api-versions.xml+Gradle 实证；降级为中 |
| A-038 | 订阅暂存隔离 | staging_sub_* 不被「排除订阅」谓词识别：更新窗口内暂存当手动规则显示/计数/误删 | 存在但需修正 | 高 | 读/清侧 27 处漏、删侧 5 处知（非「全漏」）；行号漂移；清空手动→误删链经 UI 可达已亲验；降级为中 |
| A-039 | 订阅崩溃恢复 | recoverInterruptedImports 只清 3 表（漏 goUrl/cosmetic），deleteSubscription 从不触 staging | 存在但需修正 | 高 | 生效被 HTTPS 抓包门/地址规则开关/订阅 enabled/NORMAL 四重收窄，有「再更新即自愈」通道；降级为中 |
| A-040 | Express 生命周期 | Express start↔stop 竞态：stop 不取消 start 协程、fd 复用、isRunning 复活 | 存在但需修正 | 高 | 窗口 2 描述与 START_STICKY 分支误读；实质危险仅窗口 1（首启秒停），可再启自愈；降级为中 |
| A-041 | 网络诊断 | TunnelDiagnosticsResolver.tunnelResolver 从无赋值点：经隧道 DNS/Ping/Traceroute 恒报「VPN 未运行」 | 存在 | 高 | 功能 100% 恒坏但默认开关 OFF，仅主动开启者受害→降级为中；零赋值经全仓 grep（含 test/go/ts）确认 |
| A-042 | DNS 测速 | DnsLatencyTester.testDoh 的 toHttpUrl() 在 try 外：畸形 DoH URL 测速未捕获崩溃 | 存在 | 中 | 无（行号逐字吻合；崩溃链实测） |
| A-045 | DNS 测速 | 测速计时窗口含 bootstrap/系统解析（DoT/DoH/Plain 三路径）：上游被冤枉慢 | 存在 | 中 | BootstrapSelector 实际在 core/diagnostic/（文档作 core/dns/）；超时上界 3s×N×2 |
| A-046 | 日志写入 | RaceLogger/HttpRequestLogger 批量插入无 runCatching（对照 DnsLogger 有）：崩溃+丢日志 | 存在 | 中高 | 崩溃面含 Express 同族裸 flush（文档未述）；停机链中断后续属实；行号 :133-138 |
| A-049 | 日志仪表盘 | 仪表盘把防火墙拦截的连接标「旁路」：resultLabel 忽略 result==BLOCKED | 存在 | 中 | Go 生产者路径应为 engine_connection_log.go；BLOCKED 连接行确入仪表盘（recentLogs 无排除）；同屏两处孪生正确对照 |
| A-051 | 规则列表 | 黑/白/重写列表 loadPage 无任务取消：并发加载旧覆新 | 存在 | 中 | RewriteListViewModel 完全没有 searchJob（文档「仅搜索防抖」不成立）；RuleListViewModel 为同缺陷第 4 处未列 |
| A-052 | 黑名单筛选 | 黑名单「规则订阅」页签漏订阅携带的 URL 拦截规则，计数同缺 | 存在 | 中 | 白名单注释自认此不对称（逐字核对属实） |
| A-053 | 崩溃备份 | 连崩阈值用 >= 且自动导出成功后不置抑制标志：每崩刷一份全量备份 | 存在但需修正 | 中高 | clearCrashLogs 是把抑制位**清零重武装**非置位（文档表述反，误导修复方向）；≤8 份、秒级名互不覆盖核实 |
| A-054 | 崩溃计数 | collectMinimalReport 无保护在先、onCrashOccurred 在后：SOE/OOM 计数永不执行 | 存在 | 中 | 无（结构确证；浅栈不炸=现场无报告合理反证） |
| A-059 | 密钥混淆 | KeyObfuscator 把 UTF-16 code unit 截成单字节：非 ASCII 密钥往返静默损坏 | 存在但需修正 | 低中 | JVM 实测坐实（「密钥abc」→「?abc」）；「全 API 等级都犯」在 API<26 无意义（先按 A-032 抛）；syncProviderToConfig 扩大污染 |
| A-060 | 更新清理 | 下载失败 catch 无条件清全局单槽记录：旧版 APK 成孤儿+强制重下 | 存在但需修正 | 低中 | 标题「检查到新版失败」措辞失准，实为**下载**新版失败（check 路径不触 clear） |
| A-063 | Go 元素隐藏 | buildCosmeticCss 从不并入 rules.GlobalException：全局 #@# 例外静默失效 | 存在 | 中 | 触发路径应走白名单页（黑名单 addRule 拒 #@#）；真实 Go 代码 go test 实证例外被丢弃 |
| A-075 | Express 规则添加 | Express 可添加元素隐藏规则并提示成功，但永不编译 CSS、列表不显示 | 存在但需修正 | 中 | 「无任何 UI 手段删除」过强——DataCleanupManager 走 expressDb.cosmeticRuleDao 清理路径存在；三条件（可加/提示/不可见不生效）核实为真 |
| A-077 | HTTPS 检查证书 | 本会话是否 MITM 由缓存位 isHttpsInspectionReady 决定，异步真校验失败不重启隧道 | 存在 | 中 | 无（异步回调仅写偏好、不触碰 engine，全仓无其他动作，双读确认） |
| A-078 | 会话统计归零 | 编辑排除/禁止联网名单触发 restartVpnLocked → TrafficStatsManager.start 无条件清本会话 | 存在但需修正 | 中 | 「用户无任何提示」不成立（Blocked/ExcludedApps 有「正在重连」toast，但未提会话清零）；文件应在 normal/ui/ |
| A-079 | 缓存设置串档 | 极速模式缓存设置屏四处 Store 调用全漏传 dataset：读写打到 NORMAL prefs | 存在 | 高 | 四处调用独立数为 4，与文档一致；引擎只认 EXPRESS；降级为中（跨模式偷改但无崩溃） |
| A-080 | AI 分析串库 | AgentAnalysisSheet 硬编码 AppDatabase+NORMAL 广播：极速 DNS 缓存页 AI 分析读错库 | 存在 | 高 | 行号区间略偏（NORMAL 分支在 :92-104）；机制无误；降级为中 |
| A-081 | 动态拦截极速侧 | 极速模式动态拦截可开可存，express/ 引擎零读取：功能纯空转 | 存在但需修正 | 中 | 「零读取」应改「引擎零消费、UI 仅读来渲染谎报文案」（ExpressRuleControlScreen:128 确读取） |
| A-082 | 保留天数热更新 | 普通模式改「日志保留天数」不触发 onRuntimeDnsSettingsChanged：引擎按旧快照 prune | 存在 | 中 | 无（对照同屏日志模式项正确触发即证据；极速侧不受影响） |
| A-083 | SAF 授权泄漏 | 全仓 5 处 takePersistableUriPermission、0 处 release：删图/删订阅后授权永久残留 | 存在 | 中 | take 5、release 0 独立计数一致；隐私失控非功能故障 |
| A-084 | 服务器模式向导 | DNS 模式使用向导接入信息硬编码端口 1053（5 处），从不读 localListenPort | 存在 | 中 | 1053 五处、向导零读端口实证一致；触发需用户改过端口 |
| A-085 | Go 全隧道半关闭 | countingConn 内嵌 net.Conn 接口致 CloseWrite 不提升：全隧道 TCP 半关闭永久失效 | 存在 | 中高 | 类型系统事实本会话 Go 复算确认（内嵌接口→断言 false，内嵌具体→true） |
| A-087 | DoT 阻断开关 | SetBlockEncryptedDns 是死开关：blockEncryptedDNS 仅 1 Store 0 Load，853 恒硬拦 | 存在但需修正 | 中 | 第三消费点文件名应为 mitm_handler.go 非 engine_mitm.go；1 Store/0 Load 全 Go 树实证 |
| A-088 | 极速 bootstrap | BootstrapSelector 两处 Store 调用漏传 dataset：极速整套 bootstrap 失效 | 存在 | 中高 | 无（同族调用正确对照 BootstrapSettingsViewModel/ConfigExporter 传 dataset；极速运行期恒读 dns_vpn_prefs） |
| A-089 | 应用放行闸门 | serveDNS 缓存命中/stale 分支不续 app_allowlist IP 授权：白名单应用「解析成功、连接恒被拦」 | 存在 | 中 | 无（两表独立性、rrTTL<缓存 TTL 数值差、可达入口集合均复核一致；legacy 路径已正确排除） |
| A-091 | 服务商健康页 | ProviderHealthEngine 全仓零实例化、recordResult 零调用者：健康页恒空、权重是编造均匀值 | 存在 | 中 | 无（grep ProviderHealthEngine( 仅命中类声明，零实例化亲验；hedgeMisses 无写 API） |
| A-092 | bootstrap 健康双源 | BootstrapHealthEngine 三实例并存、flush→saveAll 全表 JSON 覆盖单键：互抹健康/冷却 | 存在 | 中 | 补强：store 单文件单键使 Express 与 NORMAL 覆盖更直接 |
| A-093 | regex 规则大小写 | Kotlin regex 规则不注入 (?i)，Go 恒 (?i)：双引擎对同一订阅给出相反拦截 | 存在 | 中 | 无（/Ads\..*/ vs 小写域 Kotlin=false/Go=true 实证复算） |
| A-094 | `#$@#` 例外解析 | COSMETIC_DELIMITERS 缺 #$@#：例外型元素隐藏 substringBefore('#') 兜底整域拉黑 | 存在 | 中 | 第二形式垃圾串实为 example.com#$@ 非 #$；缺陷方向一致；实证复算 |
| A-098 | bootstrap 健康污染 | BootstrapSelector 把日志落库异常误判为解析失败：一次成功解析双记+撤缓存 | 存在 | 中 | RaceModeSettingsViewModel 单参构造 flushScope=null→批量写只走栈内同步路径，异常必落 try（实证） |
| A-099 | 预置白名单种入 | DefaultWhitelistSeeder seed(forceReset) 先删后解析且失败仍置位：直通域全删零补、同版本内永不自愈 | 存在 | 中高 | asset https_passthrough.txt 本会话自数 =5 条（与文档一致，非「33」）；两触发形态与进程级毒化下发链实证 |

---

## 需修正要点补充说明

以下条目除表中摘要外，还有对后续修复方向有直接影响的细节订正：

- **A-018**：`SetFirewallChecker`(:273)、`SetAppResolver`(:277) 全仓 Kotlin 零调用者（死 setter），应从竞争面剔除；VPN 模式运行中 `syncDnsConfig`→`applyDNSConfig`（持锁写）vs `engine_dns.go:260/280`（无锁读）是文档漏列的第二竞争对。核心 UB（responseType）判定不变。
- **A-038**：备注推荐的「staging 改名 sub_staging_<id>」有副作用——届时 LIKE 'sub_%' 会命中 staging，订阅侧查询在导入窗口把 staging 当订阅规则返回，展示面从「混入手动」变「混入订阅」，非纯收益。破坏性链（清空手动→deleteUserSources→误删 staging）经 BlacklistViewModel:482/WhitelistViewModel:573/RewriteRuleManager:225 三处 UI 入口亲验可达。
- **A-040**：`ExpressTunnelManager.kt:265-267 if (isRunning) stop()` 使第二次 start 干净重启，黑洞非永久；文档「START_STICKY 重启 intent 为 null 直接 return」误读，实际 `:79 else -> startVpn(intent)` 会重跑。
- **A-053**：修复时勿被文档「clearCrashLogs 置位」误导——`:358 putBoolean(KEY_HAS_MANUALLY_EXPORTED, false)` 是清零重新武装抑制器，与文档表述相反。
- **A-079/A-080**：原报告自评「高」，因后果为跨模式偷改防护设置/读到错库日志（无崩溃、无凭据外泄），按门槛下调为中，非降级其机制。
- **A-085**：底层 `adapter.TCPConn` 实为 `*tcpConn{*gonet.TCPConn}`，gonet.TCPConn 有 CloseWrite，故包装确吞掉了本可提升的能力；legacy 路径 :51 传未包装 conn 不受影响。
