---
章节: 10-go-tunnel-engine（续 2/3）
主题: gomobile API 契约、回调契约、规则语法 Go 子集、源码引证表
最后校验: 2026-10-18
---

# 10.4 对外契约总表（Kotlin ↔ Go）

## 10.4.1 Engine 导出方法 × 实际消费点

「消费」列均为 `Android/app/src/main/java/com/haoze/diting` 下真实调用行；未列出即全仓（含 Java/反射字符串拼接）零命中。

| Go 方法 | 签名要点 | 消费点 | 备注 |
|---|---|---|---|
| `StartFull(fd int, protector SocketProtector)` | 阻塞至会话结束，须在独立线程 | GoInspectionTunnel.kt:94 | fd 来自 `ParcelFileDescriptor` |
| `Stop()` | 幂等，不保证早退 | GoInspectionTunnel.kt:105；DnsServerEngine.kt:57；GoInspectionCaManager.kt:27 | 兼作资源回收（A-017） |
| `ReleaseTun()` | 仅关 TUN 文件 | GoInspectionTunnel.kt:110 | |
| `StartStackMitm(certDir string) string` | 返回错误串 | GoInspectionTunnel.kt:364；GoInspectionCaManager.kt:24 | 铸证用一次性 Engine |
| `StopStackMitm()` | | GoInspectionTunnel.kt:106；GoInspectionCaManager.kt:26 | |
| `SetMitmAllowedUIDs(csv)` | | GoInspectionTunnel.kt:365 | |
| `StartStandalone(port int) error` | | DnsServerEngine.kt:42 | |
| `StopStandalone()` | | DnsServerEngine.kt:56 | |
| `ServeDNS(w, r)` | miekg 类型，非 gomobile 可绑，仅内部经 HandlerFunc 使用 | — | 导出但不过 JNI |
| `ApplyRuleSnapshot(json) string` | 返回错误串 | GoTunnelRuleManager.kt:45；DnsServerEngine.kt:114 | |
| `ApplyDNSConfig(json) error` | | GoInspectionTunnel.kt:190；DnsServerEngine.kt:241 | |
| `SetRewriteRules(json)` | map 值可为 string 或数组 | GoTunnelRuleManager.kt:95；DnsServerEngine.kt:118 | |
| `SetRequestRules(json)` | | GoInspectionTunnel.kt:222；GoTunnelRuleManager.kt:101,107 | |
| `SetCosmeticRules(json)` | **写包级全局** | GoTunnelRuleManager.kt:114,120 | |
| `SetExtraPassthroughSuffixes(string)` | 换行分隔 | GoTunnelRuleManager.kt:70 | 是 SetHttpsBypassRules 的消费别名 |
| `SetAppAllowlist(json)` | | GoTunnelRuleManager.kt:135 | |
| `SetDomainChecker(DomainChecker)` | 7 方法接口 | GoInspectionTunnel.kt:226；DnsServerEngine.kt:133 | |
| `SetFilterDNS(bool)` | | GoInspectionTunnel.kt:260；DnsServerEngine.kt:92,126 | |
| `SetBlockResponseType(string)` | | DnsServerEngine.kt:119 | 全隧道侧走 dnsConfig.blockResponse |
| `SetBlockedUIDs(csv)` | | GoInspectionTunnel.kt:361 | |
| `SetFilterHttp3(bool)` | | GoInspectionTunnel.kt:367 | |
| `SetBlockEncryptedDns(bool)` | | GoInspectionTunnel.kt:368 | 默认 true（fail-closed） |
| `SetUseTcpStack(bool)` | | GoInspectionTunnel.kt:360 | 仅 legacy `Start` 读（:200）——现役路径恒真但现役路径不看它 |
| `SetUIDResolver / SetAppUidResolver` | | GoInspectionTunnel.kt:358,359 | |
| `SetBatchLogCallback / SetLogCallback` | | GoInspectionTunnel.kt:261；DnsServerEngine.kt:166 | |
| `SetRaceLogCallback / SetBootstrapLogCallback` | | GoInspectionTunnel.kt:269,310 | |
| `SetHttpLogCallback` | | GoInspectionTunnel.kt:336 | |
| `SetTrafficCallback / SetTickIntervalMs` | | GoInspectionTunnel.kt:369 / :135 | |
| `SetOutboundProxyStatusCallback / ConfigureOutboundProxy` | 后者返回错误串 | GoInspectionTunnel.kt:202,200 | |
| `ResolveDomain(domain, ipv4) string` | | GoInspectionTunnel.kt:157 | |
| `ClearDNSCache() / ResetBootstrapStats()` | | GoInspectionTunnel.kt:115,124；DnsServerEngine.kt:120 | |
| `GetDNSCacheStats() string` | | GoInspectionTunnel.kt:118-120 **反射** `javaClass.getMethod` | 绑定名不稳定 |

## 10.4.2 回调接口契约（Go → Kotlin）

| 接口 | 参数（顺序即契约） | Kotlin 解析点 |
|---|---|---|
| `LogCallback` | domain,blocked,queryType,responseTimeMs,appName,resolvedIPs,blockedBy,errorMessage,cached | DnsServerEngine.kt:166 |
| `BatchLogCallback` | `OnBatchLogs(json)`：`[{d,b,t,r,a,i,k,e,c,ts,ttl}]` | GoTunnelLogProcessor.kt:32-42；`obj.has("ttl")` 区分未知(:163-164) |
| `RaceLogCallback` | 13 参：domain,qtype,providerID,protocol,server,elapsedMs,success,primary,fallbackUsed,answered,rcode,answerCount,error | GoInspectionTunnel.kt:269-308 |
| `BootstrapLogCallback` | ipID,ipName,ip,host,success,elapsedMs,fallbackUsed,errorMessage | GoInspectionTunnel.kt:310-335 → BootstrapHealthEngine.recordResult |
| `HttpLogCallback` | url,host,uid,appName,outcome | GoInspectionTunnel.kt:336-356；outcome 9 值映射 GoTunnelLogProcessor.kt:143-153 |
| `OutboundProxyStatusCallback` | state,message（connecting/ready/error/disabled） | GoInspectionTunnel.kt:202 |
| `TrafficCallback` | `OnTrafficStatsTick("[{uid,tx,rx}]")` | TrafficStatsManager.kt:185-215 |
| `DomainChecker` | 仅 `CheckDomain(domain,uid,qtype)` 被 Go 调用 | 两处 setDomainChecker |
| `FirewallChecker` | `CheckFirewall(domain, uid)` | 生产未注入（legacy 分支） |
| `AppResolver / AppUidResolver` | `ResolveApp(ip[]byte,port[]byte)` / `PackageForUid(int)` | GoInspectionTunnel.kt:358-359 |
| `SocketProtector` | `Protect(fd)` | GoInspectionTunnel.kt:94 闭包 |

## 10.4.3 下发 JSON 契约的生产者

| Go 接收方 | Kotlin 生产者 | 关键字段 |
|---|---|---|
| `ApplyRuleSnapshot` | `DomainPolicyEngine.kt:118-250` | filterEnabled、4 个 trie 路径、globalAllow/Block/Important、appRules、inverted{Block,Allow}{pattern,source,important,excludedApps}、special{Block,Allow}{pattern,source,important,appScope,appInverted,isWildcard,denyallow,isRegex,dnsType}、disabledRules |
| `ApplyDNSConfig` | `HttpsDnsConfigSnapshot.toJson:48-90`；DnsServerEngine 侧 `applyDnsConfig:184-243` | mode/blockResponse/dynamicResponse{enabled,requestThreshold,windowSeconds,nxDomainDurationSeconds}/cache(10 键)/providers[{id,protocol,server,url}]/bootstrap{enabled,ips[{id,name,ip}]} |
| `SetRewriteRules` | `GoTunnelRuleManager.kt:82-97`（ipRewrites→JSONArray，cnameRedirects→String 合并） | 值类型混用是解析难点 |
| `SetRequestRules` | `GoUrlRuleManager.jsonSnapshot:35-39` | `[{pattern,kind}]`，无 `*`/`$` |
| `SetCosmeticRules` | `CosmeticRuleManager.kt:77-81` `compileScopedJson` | 写入包级全局 |
| `SetAppAllowlist` | `GoTunnelRuleManager.kt:135` | `{"<uid>":[domain...]}` |
| `ConfigureOutboundProxy` | `OutboundProxyConfig.toNativeJson:36-43` | host 必为回环 |

## 10.5 Go 侧实际支持的规则语法子集

- **域名匹配**：一律逆序标签后缀匹配（`ContainsOrParent` 语义），支持 DTRI 内 `*` 通配；无 `||`、`^`、`$`、`##`、`/path`、regex（除 `specialRule.isRegex` 单点，且 Kotlin 侧当前不产出 isRegex 规则）。
- **例外前缀**：`@@` 与 `||` 仅在 `MitmFilter.matchHostPattern`（订阅原始文本比对路径）支持，DTRI 快照走已解析结构不含这些符号。
- **URL 规则**：仅 `scheme://host[:port]/path` 前缀，最长前缀胜出，allow 平票优先；无通配、无正则、无 `$` 修饰。
- **重写**：域名→IP 数组（首个 v4/v6 各一生效，engine_config.go:108-141）或域名→CNAME（首个 cname 生效）；查找为「全域名→逐级剥前导标签」的最长后缀优先（:142-160）。
- **化妆规则**：仅作为 CSS 文本聚合注入，不做元素级选择器执行（选择器在 Kotlin 编译进 CSS）。

## 10.6 源码引证表（关键结论 ↔ 文件:行）

| 结论 | 引证 |
|---|---|
| GC 400% | engine.go:36-38 |
| DoT 阻断 fail-closed 默认 | engine.go:145-151；engine_full_tunnel.go:411-428 |
| 代际守卫防 StartFull/Stop 交叠 | engine_full_tunnel.go:218-228, 273-283；engine.go:88-94, 228-237 |
| idle Stop 也释放缓存（A-017） | engine.go:228-250；engine_session_race_test.go:62-73 |
| TUN 出站自愈重试 | engine_full_tunnel.go:53-59, 88-104, 108-170 |
| MITM 强制 HTTP/1.1 ALPN | mitm_cert_manager.go（NextProtos 设置处） |
| 自动拉黑阈值/7 天 TTL | mitm_filter.go:24, 281-297, 343 |
| 代理 host 限回环 | flow_outbound.go:85-112（:100-103） |
| 先 configure 再 publish（A-023） | dns_config.go:107-170（:156-165） |
| SERVFAIL 记为 provider 失败 | resolver_strategy.go:360-392 |
| 智能预测 50ms 后备 | resolver_strategy.go:21, 200-260 |
| stale-while-revalidate | dns_cache.go:144-226；engine_standalone.go:281-397 |
| TTL 无 omitempty（O-107） | log_aggregator.go:14-38 |
| 连接日志 8192 整体清空 | engine_connection_log.go:22, 43-59 |
| 化妆 CSS 包级全局 | mitm_cosmetic_inject.go:30-46 |
| 原生 trie+bloom 生产不可达 | `SetTries/SetImportantTries` 全仓零调用；engine_standalone.go:197-247 |
| `Engine.Start` 零生产调用者 | AGENT_MISTAKES.md:54（A-089）+ 本次 Kotlin 侧 grep 复核 |
