---
所属系列: DITING Android Flutter 重构功能图谱
章: 07
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测
---

# 07 Kotlin 侧 DNS 内核：缓存、解析、传输、日志结构体

## 1. 概述

本章覆盖 `com.haoze.diting.core.cache`（6 文件）、`core.dns`（9 文件）、`core/log` 中与缓存/竞速相关的结构体，以及三模式（极速 express / 普通 normal / 服务器 server）对它们的调用关系。这是 Flutter 重构中**最不可让 AI 自由发挥**的部分：全部是位级报文构造、TTL 夹取、EWMA 权重等纯算法层，任何"看着更合理"的改写都会改变线上语义（阻断判定、缓存命中率、调度公平性）。必须 1:1 复刻本章每一条常量与分支。

实测文件规模（`(Get-Content).Count` 口径的 `wc -l`，本会话执行）：

| 文件 | 行数 |
|---|---|
| core/cache/DnsResponseCache.kt | 512 |
| core/cache/DnsCachePreset.kt | 93 |
| core/cache/DnsCacheKey.kt | 53 |
| core/cache/DnsCachePolicy.kt | 47 |
| core/cache/DnsCacheController.kt | 46 |
| core/cache/DnsCacheEntry.kt | 37 |
| core/dns/DnsMessageUtils.kt | 597 |
| core/dns/DnsProvider.kt | 460 |
| core/dns/DnsLookupTool.kt | 323 |
| core/dns/DnsLatencyTester.kt | 287 |
| core/dns/DnsRewriteMessage.kt | 173 |
| core/dns/DotTransport.kt | 121 |
| core/dns/PlainDnsTransport.kt | 98 |
| core/dns/DohUrlParser.kt | 28 |
| core/dns/DnsTimeoutConstants.kt | 3 |

**本章最重要的发现（先说结论）**：`DnsResponseCache` 的**读路径在生产代码中不可达**。普通模式的实际 DNS 缓存由 Go 引擎完成（`Android/tunnel/dns_cache.go`），Kotlin 侧 `DnsResponseCache` 只被当作"缓存展示数据库的统计写入器"使用（`recordCacheHit`/`recordResolved`），其 `resolve()/get()/put()/warmUp 读命中/materialize/singleflight/stale 回退`整条链没有任何生产调用方（双向 grep 证据见 §6/§7）。重构时必须区分"真在跑的语义"（Go 侧 + Express 侧 `ExpressRoomDnsCache`）与"名义存在但未接线"的 Kotlin 读路径——后者语义仍要记录（它被单测覆盖、且 `AGENT_MISTAKES.md` 铁律 2 要求先证明"在生产被执行"）。

## 2. 缓存子系统全解（core/cache）

### 2.1 分片与容量（DnsResponseCache）

- 分片数默认 **16**（`DEFAULT_SHARD_COUNT = 16`，DnsResponseCache.kt:508）；构造参数 `shardCount` 经 `coerceAtLeast(1)`（:35）。
- 总容量默认 **2048**（`DEFAULT_MAX_ENTRIES = 2048`，:507）；每分片上限 = `ceil(maxEntries / shardCount)`，即默认 16 片 × 128 条/片（:36）。
- 分片路由：`(key.hashCode() and Int.MAX_VALUE) % shards.size`（:437-440）。
- 淘汰策略：**LRU**，基于 `LinkedHashMap(maxSize, 0.75f, accessOrder=true)` + `removeEldestEntry(size > maxSize)`，每片一把 `Mutex`（内部类 `CacheShard`，:460-496）。不是时钟/second-chance。
- 普通模式实际构造时未传容量/分片参数（DnsVpnDatabaseComponents.kt:89 `DnsResponseCache(db.dnsCacheDao(), activeDnsCachePolicy, scope)`），因此使用 2048/16 默认值。

### 2.2 缓存键结构（DnsCacheKey.kt）

字段：`name`(小写、去尾部点、trim)、`type`、`qclass`、`dnssecOk`、`checkingDisabled`、`storageKey`（:5-12）。
`storageKey = "name|type|qclass|do(0/1)|cd(0/1)"`（:32-42，竖线分隔）。
DO 位取自查询 OPT RR 的 TTL 字段 `0x8000` 掩码（DnsMessageUtils.kt:21、:490-514），CD 位取自 header byte3 的 `0x10`（:64）。
对照：Express 侧用另一格式 `name#type#qclass#do#cd`（ExpressRoomDnsCache.kt:65-70，注释明确说这是对 core DnsCacheKey 的镜像，分隔符不同！两套键格式在**同一张 Room 表** `dns_cache` 中按数据库文件隔离——normal 用 `AppDatabase`、express 用 `ExpressRulesDatabase`，DnsRulesDatabase.kt:148-153 的 `runtimeForDataset`）。

### 2.3 TTL 裁剪/夹取（DnsCachePolicy.kt）

`effectiveTtlSeconds(upstreamTtl)`（:34-46）：
```
if (upstreamTtl <= 0) return 0            // :35  TTL=0 即不缓存
modeTtl = when(mode):
  FOLLOW_DNS_TTL -> upstreamTtl            // :37
  LIMIT_MAX_TTL  -> min(upstreamTtl, max(maxTtlSeconds,0))  // :38
  FIXED_TTL      -> max(fixedTtlSeconds,0) // :39
if (minTtlEnabled) return max(modeTtl, max(minTtlSeconds,0)) // :41-42
```
默认策略（:22-31）：`enabled=true, mode=LIMIT_MAX_TTL, maxTtl=3600, fixedTtl=3600, minTtlEnabled=false, minTtl=60, staleFallbackEnabled=false, staleFallbackSeconds=300, negativeTtlEnabled=true, negativeTtlSeconds=30`。
枚举 `DnsCacheMode`：`follow_dns_ttl / limit_max_ttl / fixed_ttl`，未知值回退 `LIMIT_MAX_TTL`（:15-17）。
注意：**没有"最大 TTL"常量在 DnsResponseCache 内**；夹取上限完全由 policy 决定；UI 持久化层再加区间夹取 `[30, 86400]` 秒（DnsCacheSettingsStore.kt:20-21 `MIN_CACHE_SECONDS=30 / MAX_CACHE_SECONDS=86_400`，读写两侧都 coerce，:46-57、:87-94）。

### 2.4 stale-while-revalidate（不是 swr，是"失败回退 stale"）

宽限期数值 = `policy.staleFallbackSeconds`（默认 300s；预设见 §2.8），`staleExpiresAt = expiresAt + max(staleFallbackSeconds,0)*1000`（DnsResponseCache.kt:452-458）。语义（:97-107）：仅当上游解析**抛异常**且 `staleFallbackEnabled` 时才读 stale（`now <= staleExpiresAt`，materialize :389-393）；**没有**"过期后台刷新"的 swr 机制。stale 命中不计数（:406-408 `if (!allowStale) recordHit`）。
`shouldDeleteUnavailable`（:420-424）：未启用 stale 回退则立即可删；启用则需 `now > staleExpiresAt` 才从内存+待发队列+DB 三处删除（removeExpired :426-435）。

### 2.5 singleflight（合并并发同键解析）

:77-118。`inFlight: HashMap<String, Deferred<ByteArray>>` + `inFlightMutex`（:38-39）。首个调用者成为 leader 并 `async { resolver() }`（:80-85），其余 `await` 同一 Deferred；leader 成功后 `put()`（:90-92，且要求 `DnsMessageUtils.isSuccessResponse`——**只有 NOERROR 响应入缓存，NXDOMAIN 不缓存**）；finally 中 leader 用 `===` 身份比较移除自己的 Deferred（:109-115，符合 AGENT_MISTAKES「身份判定必须 ===」教训）。所有等待者拿到同一份响应后用 `withTransactionId` 改写自己的 TXID（:94）。

### 2.6 CNAME 链

Kotlin 侧 `DnsResponseCache` **不解析 CNAME 链**：缓存键就是原始 QNAME+QTYPE，响应整包存储。链语义在别处：
- `extractAddressRecords`（DnsMessageUtils.kt:345-384）遍历 Answer 段，**跳过 CNAME**只取 A/AAAA（注释 :340-343），无深度限制（不需要）。
- Go 侧才有链目标（`dns_cache_types.go:31 chainTarget`、:50 `chainTargets`，归第 09 章）。
- 记录级 CNAME 解析仅在调试工具 `DnsRecordParser`（DnsLookupTool.kt:182 TYPE_CNAME=5、:230 直接 readName 展开，跳转上限 `jumps < 64`，:275）。
- `skipName` 压缩指针跳转上限 **128**（DnsMessageUtils.kt:546-548 `maxJumps = 128`；DnsRewriteMessage.kt:122-126 逐字相同的副本）。

### 2.7 负缓存（NXDOMAIN）

**Kotlin DnsResponseCache 不缓存负响应**：`put` 上游 `extractResponseTtlMetadata` 对 ANCOUNT+NSCOUNT+ARCOUNT=0 的响应返回 null → 拒绝入缓存（DnsResponseCache.kt:253；DnsMessageUtils.kt:421-422 `totalRecords == 0 → emptyList`；:398-405 空 offsets → null）。`recordResolved` 要求 `resolvedIPs` 非空（:171）。
`negativeTtlEnabled/negativeTtlSeconds`（DnsCachePolicy.kt:30-31，默认 30s）**仅被 Go 配置快照消费**：normal/HttpsDnsConfigSnapshot.kt:65-66 与 server/backend/DnsServerEngine.kt:206-207 把两字段序列化进 cache JSON，负缓存在 Go dns_cache 侧生效（`dns_cache_policy.go`，归第 09 章）；Kotlin 侧 `DnsResponseCache` 本身不读它（resolve.put 因 `isSuccessResponse` 只纳 NOERROR，NXDOMAIN 不入缓存；recordResolved 要求 resolvedIPs 非空）。因此 **Kotlin/Go 两套缓存的负缓存策略不对称**：express（Kotlin `ExpressRoomDnsCache`）NXDOMAIN 直接不入缓存，normal/server 交给 Go negativeTtl——这是三模式行为差异的关键事实，勿写成死代码，也勿在 Dart 缓存层给 express 凭空补负缓存。三档预设的 negativeTtl 值（15/30/60s，DnsCachePreset.kt:27-28/45-46/63-64）经 `toPolicy` 同样只流向 Go 快照与 UI 展示。

### 2.8 三档预设（DnsCachePreset.kt）

| 预设 | storageValue | mode | maxTtl | minTtl | stale | negTtl |
|---|---|---|---|---|---|---|
| CONSERVATIVE :13-30 | conservative | FOLLOW_DNS_TTL | 3600 | 关(60) | 关(300) | 15s |
| BALANCED :31-48 | balanced | LIMIT_MAX_TTL | 3600 | 开(60) | 开(300) | 30s |
| HIGH_HIT_RATE :49-66 | high_hit_rate | LIMIT_MAX_TTL | 21600 | 开(120) | 开(900) | 60s |

`fromPolicy` 反向归类启发式：:78-91（FOLLOW+双关→CONSERVATIVE；LIMIT_MAX 且各值≤BALANCED→BALANCED；否则 HIGH_HIT_RATE）。
server 模式唯一直接消费 `DnsCachePreset` 枚举（DnsModePreferences.kt:68 默认 BALANCED；DnsModeModels.kt:200）。

### 2.9 持久化与同步链（Room）

- 表 `dns_cache`（DnsCacheEntity.kt:8-16），主键 `key`，4 个索引：expiresAt、lastHitAt、queryName、(queryType,expiresAt)（:11-14）。字段 12 个（:18-29），`hitCount` 带 `defaultValue="0"`（:25）。
- **写库时机**（DnsResponseCache）：热路径**不写库**。`enqueueWrite`/`enqueueHit`（:288-312）合并进 `pendingWrites: LinkedHashMap` / `pendingHits: LinkedHashMap`；`markPendingLocked`（:318-331）：待发数 ≥ **200**（`WRITE_BATCH_SIZE`，:510）立即冲刷，否则挂一个 **30_000ms** 尾部定时器（`WRITE_FLUSH_DELAY_MS`，:509）。
- 冲刷：`flushPendingWrites`（:333-367）在 `dbWriteMutex` 内调 `dao.applyPendingWrites(writes, hits)`；失败时把批次回插待发并重新挂定时器（:347-365）；`pendingWriteEpoch`（:53、:377）防止 `clear()` 与在途冲刷竞态复活已删行（设计注释 :42-51、:340-344）。
- `clear()`（:131-138）= 清内存 + `clearPendingWrites`（epoch++）+ `dbWriteMutex { dao.clearAll() }`。
- `warmUp()`（:120-129）：取 `getUnexpired(now, maxEntries)` 灌入分片、清旧片、`deleteExpired(now)`。**普通模式调用它只为预热"统计展示库"**，读路径无人消费（§2.11）。
- DAO 语义（DnsCacheDao.kt）：`applyPendingWrites`（:81-103，`@Transaction`）先 `updateMetadata`（:49-67，故意不碰 hitCount/lastHitAt——minSdk24 无 UPSERT，注释 :40-48），0 行受影响才 `insertIfAbsent`（:36-38）；`addHits`（:70-71）原子累加合并后的增量。`insert(REPLACE)`（:33-34）在生产代码中**无调用方**（仅测试夹具 ExpressRoomDnsCacheTest.kt:162 用于造过期行）。
- 生命周期接线：`DnsCacheController`（单例，register/unregister/clearAll，DnsCacheController.kt:12-45）——normal 启动时注册并注入 `clearGoCacheCallback`（DnsVpnDatabaseComponents.kt:153，回调= `GoInspectionTunnel.clearDnsCache()`，DnsVpnService.kt:104）；数据清理页 `DataCleanupManager.clearDnsCache`（:85-98）EXPRESS 数据集直接 `ExpressRulesDatabase…clearAll()`，否则 `DnsCacheController.clearAll(dao)`。服务停止时 `flushLoggersAsync` → `dnsCache.flushPendingWrites()`（DnsVpnDatabaseComponents.kt:161-164、DnsVpnService.kt:380/407）。

### 2.10 命中率统计与暴露 API

- 内存计数：`DnsCacheEntry.currentHitCount/currentLastHitAt`（DnsCacheEntry.kt:9-10，可变；put 到新条目时迁移旧计数，DnsResponseCache.kt:470-479；`recordHit` :489-495）。`DnsCacheEntry.toEntity()`（:12-17）**零调用方（死代码，双向 grep：main+test 均无）**。
- DB 聚合：`countUnexpired`、`totalHitCount`（DnsCacheDao.kt:27-31）→ `DnsCacheRepository`（:28-34）→ 消费方 `ModernLogDashboardViewModel.kt:199-201`（recentEntries/countUnexpired/totalHitCount）与列表页 `DnsCacheViewModel.kt`（94 行：Paging 300ms 搜索去抖 :52、refreshCacheList 触发 deleteExpired :73-81）。
- **`GetDNSCacheStats`（问题中点名的 JSON 结构）**：Go 侧 `tunnel/engine_config.go:31` `GetDNSCacheStats()` → `dns_cache.go:382 statsJSON()`，JSON 字段见 `dns_cache_types.go:66-76`：`enabled, totalHits, totalMisses, staleHits, negativeHits, hitRatio, entryCount, maxEntries, evictionCount`（均 snake→camel tag）。Kotlin 侧反射包装 `GoInspectionTunnel.getDnsCacheStats()`（:118-120，反射 `getMethod("getDNSCacheStats")`，失败回退 `"{}"`）。**该包装函数自身无调用方**（双向 grep 全仓 kt/go/java/js/dart 仅命中定义与其内部反射字符串）——疑似死代码，且它反映的是 Go 缓存而非 Kotlin 缓存。

### 2.11 读路径不可达（重大）

`DnsResponseCache.resolve()`（:62-118）是唯一消费私有 `get()/put()/materialize()/singleflight/stale 回退` 的入口。证据：
1. 正向：`grep -rn "\.resolve(" app/src/main app/src/test`（含全仓，本会话实测）命中仅：ExpressTcpDnsHandler.kt:183 / ExpressTunnelManager.kt:417（那是 `ExpressDnsEngine.resolve`）、NetworkToolsViewModel.kt:211（`TunnelDiagnosticsResolver`）、RecognitionAvatarRepository（`java.io.File.resolve`）。无任何 receiver 为 `DnsResponseCache` 的调用，无 `::resolve` 方法引用，无反射 `getMethod("resolve…")`。
2. 反向：`DnsResponseCache` 构造点全仓仅 2 处——normal/DnsVpnDatabaseComponents.kt:89（生产）与测试夹具 DnsResponseCachePersistenceTest.kt:132；测试类也从未调用 `resolve`（只调 recordResolved/recordCacheHit/flush/clear）。`DnsCacheResult`（:19-23）除定义文件内零引用。
3. normal 实例上真正被调用的公开方法只有：`warmUp`（预热统计库）、`updatePolicy`（热更新，DnsVpnRuntimeConfigManager.kt:123/169）、`flushPendingWrites`、`clear`（经 Controller）、`recordCacheHit`、`recordResolved`（GoTunnelLogProcessor.kt:89/91）。`clearMemory()` 对外零调用（仅被同文件 clear() :132 内部调用）。
结论：`recordResolved`（:162-214，写 `EMPTY_RESPONSE=ByteArray(0)`、`responseSize=32+ips×(16|4)` 估算 :192）只维护**展示用元数据行**；Kotlin 分片缓存对真实解析流量的贡献 = 写计数 + warmUp 装载进内存但从不读（读它的唯一代码 get() 不可达）。Go 侧 `engine.applyDNSConfig` 收同一 `DnsCachePolicy` 的 JSON 快照（HttpsDnsConfigSnapshot.kt:48-66）执行真正的缓存。

### 2.12 过期清理调度

- 内存：读 miss 即删（removeExpired，仅在不可用且超出 stale 窗口时；:232-246）；LRU 逐出按容量。
- DB：`deleteExpired` 调用点——`warmUp`（:128）、`DnsCacheViewModel.refreshCacheList`（:77，进页面/手动刷新时）。无独立后台清理任务；`LogMaintenanceManager` 不负责 dns_cache（grep 无命中）。
- TTL 回写：materialize 用"剩余秒数"整体覆盖所有 RR 的 TTL 字段（patchResponseTtl 三参重载，DnsMessageUtils.kt:478-488，`remainingSeconds = ceil((expiresAt-now)/1000)` 下限 1，DnsResponseCache.kt:396-400）。

## 3. 解析调度全解（DnsProvider + 调度器 + 健康度）

### 3.1 DnsProvider 结构体（core/dns/DnsProvider.kt）

`data class DnsProvider(id, name, protocol=DOH, url="", host="", port=DEFAULT_DOT_PORT=853, isPreset=false)`（:30-38）。协议枚举 `DNS/DOH/DOT`（:13-25，`fromStorage` 未知回退 DOH；`MANAGED_PROTOCOLS=三种全含`）。`DEFAULT_DNS_PORT=53`（:51）。
预设 **18 个**（`PRESETS` :58-197，实测 6 DNS + 6 DoH + 6 DoT：阿里云/腾讯 DNSPod/360/OneDNS/Cloudflare/Google × 3 协议；360 DNS=101.226.4.6、OneDNS=117.50.10.10、Cloudflare DoT host=one.one.one.one、360 DoH=doh.360.cn/dns-query、OneDNS DoH=doh.onedns.net）。
持久化：SharedPreferences 按数据集 `dataset.prefsName()`（NORMAL→dns_vpn_prefs / EXPRESS→diting_express_prefs / DNS_MODE→…，RuleDataset.kt:24-28；DnsProvider.kt:199-201）。注意：常量 `PREFS_NAME="dns_vpn_prefs"`（:53）**未被使用**（prefs() 走 dataset）——小死码。用户服务商存 JSON 数组（:269-286），选中 id 默认 `preset_alidns_dns`（:56）。
`isIpLiteral`（:391-406）+ `isIpv6Literal`（:408-442）：结构化识别 IPv4/IPv6 字面量（拒 `[::1]:53`、`256.1.1.1`、双压缩 `2001:db8::1::2`；:394-399 单侧括号判否）——这是 AGENT_MISTAKES 解析器负例教训的落地。校验器 `isValidDohUrl`（https:// 前缀即过，:339-342）、`isValidDotHost`（非 IP、含点、无冒号，:344-348）、`isValidDnsHost`（:350-358）、端口 1..65535（:360-362）。
`runtimeCustomProviderId = "runtime_custom_" + SHA-256(url)[0..7] hex`（:451-458）。
`presetIdForProtocol`（:223-229）：仅"阿里云/腾讯云 DNSPod"两个名字可跨协议切换（:445），消费方 RaceModeSettingsViewModel.kt:267。
`GOOGLE_DOH_PROVIDER_ID`（:444）**零引用（死代码，双向 grep）**；`loadRaceProviderIds/saveRaceProviderIds`（:231-240）**零调用方（死代码）**——生产实际走 `ResolutionSettingsStore.getSmartPredictionProviderIds/getParallelRaceProviderIds`（ExpressVpnService.kt:275-277、DnsVpnProviderResolver.kt:58-60）。

### 3.2 候选集构建（两种模式同构）

normal：`DnsVpnProviderResolver.resolveDnsProviders(context, intent)`（DnsVpnProviderResolver.kt:21-72）：Intent 覆盖（EXTRA_DOH_URL→单自定义 DoH :24-35；EXTRA_DNS_HOST→DNS/DoT :36-52）→ 否则按 `DnsResolutionMode`：SINGLE 直落兜底；SMART_PREDICTION/PARALLEL_RACE 取对应 id 集，**不足 2 个则放弃**；PRIMARY_BACKUP 保序 mapNotNull，不足 2 放弃；兜底 `listOf(DnsProvider.loadSelected)`（:71）。
express：`ExpressVpnService.resolveActiveProviders`（:269-290）逐条同构，只是数据集换成 EXPRESS。启动/重配置时缓存在 `activeProviders/activeResolutionMode`（:48-49、:93-94、:182-183）。

### 3.3 执行调度器：Kotlin 侧只有 Express 有

`DnsResolutionMode`（ui/DnsResolutionMode.kt:10-25）：SINGLE/SMART_PREDICTION/PARALLEL_RACE/PRIMARY_BACKUP。
`ExpressUpstreamDispatcher.dispatch`（express/engine/ExpressUpstreamDispatcher.kt:103-117）伪代码：
```
SINGLE:  仅 providers.first()，无效响应 → throw（不重试）
PRIMARY_BACKUP: for p in providers: try { q(p); if usable return } catch → lastError
   // 注意 :134：usable=false 不 break 也不置错——直接进下一轮（隐式降级）
PARALLEL_RACE / SMART_PREDICTION: dispatchRace(...)
```
`dispatchRace`（:144-226）：每 provider 一个 `launch(Dispatchers.IO)`；`CompletableDeferred` 胜者门（`complete` 幂等，:172 首成功者赢并**立即 cancel 兄弟 job**，兄弟 job 的 `invokeOnCompletion` 关活动 socket :158-164）；全部失败才 completeExceptionally（:181-188）；成败都写 RaceLogger（question≠null 时，:197-224）。
**关键事实一：SMART_PREDICTION 在 Express 执行层与 PARALLEL_RACE 完全相同**（:114-115 只是 RaceModeStrategy 标签不同）。"智能"体现在候选来源上（见 §3.4），而非执行算法。normal 模式四策略的真正执行算法在 Go `resolver_strategy.go`（归第 09 章）；Kotlin 只把 mode.storageValue 序列化进配置（HttpsDnsConfigSnapshot.kt:49）。
**关键事实二（Express 与 core 的判据差异，重构必抄）**：Express 的 `isUsableUpstreamResponse` = `isDnsResponse && TXID 匹配 && (rcode==NOERROR || rcode==NXDOMAIN)`（ExpressDnsMessageUtils.kt:222-226），即 **SERVFAIL/REFUSED 判为不可用**——快速回 SERVFAIL 的对手会被竞速忽略（测试 ExpressUpstreamDispatcherTest.kt:120 `testParallelRaceIgnoresFastServfail` 断言胜者是 NOERROR 一方，实测通过）；而 core 版仅校验 QR+TXID、任意 rcode 均 usable（DnsMessageUtils.kt:298-301，core 版只被测速/诊断消费）。缓存写入另判：Express 引擎仅 `isSuccessResponse`（NOERROR）且未截断才 put（ExpressDnsEngine.kt:154），NXDOMAIN 虽 usable 但**不入缓存**。
传输注入点 `ExpressTransportInvoker`（:42-101）：按协议分发到 Express{Plain,Dot,Doh}Transport；DoH 无 onSocketActive 钩子（OkHttp 管理，:90-98）。SINGLE 路径同样以 `isUsableUpstreamResponse` 为唯一判据，不合格即抛 `Provider … returned invalid response`（:122-124，**不重试、不换下一个服务商**）。失败降级链：SINGLE 直抛 → 引擎侧转 SERVFAIL（ExpressDnsEngine.kt:147）；PRIMARY_BACKUP 逐个降级；RACE/SMART 全员不可用才抛（:181-188）。

### 3.4 EWMA 健康度（智能选择的权重来源）

共享纯算法 `HealthSnapshotMath.applySample`（core/diagnostic/HealthSnapshotMath.kt，72 行）：
```
EWMA_ALPHA = 0.25; JITTER_ALPHA = 0.2
DEFAULT_LATENCY_MS = 250.0
COOLDOWN_FAILURE_THRESHOLD = 3; COOLDOWN_MS = 30_000          // :13-17
ewma   = success ? ewma*(1-0.25)+max(elapsed,1)*0.25 : ewma   // 失败绝不污染延迟 :33-37
jitter = success ? jitter*(1-0.2)+|sample-ewma|*0.2 : jitter  // :38-42
consecutiveFailures = success ? 0 : +1                        // :43
cooldownUntil = consecutiveFailures>=3 ? now+30s : 0          // :46-50
decayedSuccesses/Failures += 1（半衰期另算）                   // :55-56
```
`ProviderHealthEngine`（172 行）：每数据集单引擎（`ActiveHealthEngineRegistry`，:156，教训：曾共享槽位互相抹除）；半衰期衰减 `0.5^(elapsed/1_800_000ms)` 即 **30 分钟**（HEALTH_HALF_LIFE_MS :165，decayed :139-149）；脏标记 + **15s** 延迟冲刷（FLUSH_DELAY_MS :164，markDirty :125-132）；close 时 commit（:91-107）。其 companion 里的 `EWMA_ALPHA/JITTER_ALPHA/COOLDOWN_*` 常量（:167-170）已被 applySample 取代、仅 DEFAULT_LATENCY_MS(:166 用于 :42) 在用——其余 4 个**未使用**（小死码）。
权重公式 `ProviderHealthSnapshot.predictionWeight`（ProviderHealthStore.kt:28-44）：
```
correctness = (decayedSuccesses+2)/(decayedAttempts+3)            // 拉普拉斯平滑 :32
speed       = 250 / clamp(ewma + 0.5*jitter, 20, 5000)            // :33-37
cooldownPenalty = in cooldown ? 0.1 : 1                            // :38
failurePenalty  = 1/(1 + 0.2*consecutiveFailures)                  // :39
hedgeMissPenalty = 1/(1 + 1.5*share)                               // :40-41
weight = clamp(correctness*speed*cooldown*failure*hedge, 0.05, 3.0)// :42-43, 常量 :47-55
```
**hedgeMisses 无任何生产者**（grep main+test 零写入点，仅序列化往返）→ 当前恒 0，hedgeMissPenalty 恒 1。待定：原设计意图。
唯一生产者：`RaceModeSettingsViewModel.runLatencyTest`（:341-345，测完 `recordResult` + `flush(commit=true)`）——**自动查询路径不回写健康度**（Express dispatcher 不调 recordResult；grep `recordResult(` 仅 3 处：BootstrapSelector:110、GoInspectionTunnel:322(bootstrap ip)、RaceModeSettingsViewModel:341）。因此智能选择权重实际来自"手动测速"，UI 注释也自证（RaceModeSettingsViewModel.kt:336-339）。展示侧：ProviderHealthScreen.kt:67-72 + `normalizeWeightsToPercent`（最大余数法凑 100%，ProviderHealthStore.kt:131-150）。
Bootstrap IP 健康（同算法复用）：BootstrapHealthEngine.kt:78-120，EWMA 参数 :234-235。

### 3.5 超时与重试

`DNS_UPSTREAM_TIMEOUT_MS = 5_000`（core/dns/DnsTimeoutConstants.kt:3，全文件仅此 3 行）。消费方：PlainDnsTransport soTimeout/connect :52/:72-73、DotTransport 内部 `TIMEOUT_MS`（DotTransport.kt:56）、DnsLatencyTester 三超时（:281-283）、Express 三 transport 默认参数（ExpressDohTransport.kt:164、ExpressDotTransport.kt:35、ExpressPlainDnsTransport.kt:34、dispatcher :54）。
重试语义：**没有指数退避层**。重试 = ①多地址顺序尝试（PlainDnsTransport.query :23-39 逐 address；DotTransport :30-37 逐 bootstrap ip）；②UDP 截断→TCP 重查（Plain :26-30）；③PRIMARY_BACKUP 逐服务商；④race 全败抛错。Express 竞速的取消即"止损"，不重试。

## 4. 传输层

### 4.1 UDP/TCP（PlainDnsTransport.kt，core）
- UDP：`DatagramSocket()` 裸建（:48）→ protect（VpnService.protect 注入）失败即抛 :49-51 → soTimeout 5s → `connect(address:port)`（connected UDP，不收 Spoof 包）→ 单发单收，收缓冲 `MAX_DNS_PACKET_SIZE=65_535`（:55、:97）。
- TCP：`Socket().use` + 2 字节大端长度前缀收发（:74-93）；`length==0` 抛错（:85）。**仅当 TC 位**（isTruncated，header byte2 &0x02，DnsMessageUtils.kt:332-335）才由 UDP 升级 TCP（:26-30）。
- 响应校验 `isUsableUpstreamResponse`：QR 位 + TXID 匹配（:298-301），不校验源端口。
- core 版 `protectSocket` 失败处理不对称：UDP 失败抛错，TCP 失败也抛错（:69-71）；DotTransport core 版 protect 返回值**被忽略**（DotTransport.kt:71 `protectSocket?.invoke(rawSocket)`）——与 Express 版一致（ExpressDotTransport.kt:116）。**待定：是否有意为之（protect 失败仍可继续发包）**。

### 4.2 DoT（DotTransport.kt core / ExpressDotTransport.kt）
- 建连：先裸 `Socket` connect（可指向 bootstrap IP，:75-76），再 `SSLSocketFactory.getDefault().createSocket(raw, host, port, true)`（:77-78）→ `endpointIdentificationAlgorithm="HTTPS"`（:81，主机名校验按 CN/SAN=HTTPS 规则）→ `SNIHostName(host)`（:82）→ startHandshake。
- **TLS 版本/ALPN/证书链**：未显式设 `enabledProtocols`（用平台默认，Android 一般 TLS1.2/1.3）、**未设 ALPN**（即不协商 dot h2；纯 DNS-over-TLS RFC7858 裸帧语义）、证书校验=平台信任库 + HTTPS 端点识别（无 pinning、无跳过）。`autoClose=true`（createSocket 第四参）。
- 报文：2 字节长度前缀 + wire DNS（:93-109），读前校验 `length in 1..65535`（:105）。
- Express 差异：EDNS0 注入（:39-43，`ensureEdns0(query, 1232)`，ExpressDnsMessageUtils.kt:413-428：追加 11 字节 OPT（根名 0x00 / TYPE=41 / CLASS=缓冲区大小 / TTL=0 / RDLEN=0，ARCOUNT+1）；`edns0BufferSize>0` 才注入）；`onSocketActive` 双回调（raw + ssl，:115/:124 供竞速取消）；响应 usable 校验（:94-96）。
- core 版 DoT 的**唯一生产调用方是 DnsLatencyTester**（测速 UI 链路，:248-255）——普通模式运行时 DoT 走 Go `resolver_dot.go`。

### 4.3 DoH（ExpressDohTransport.kt + DnsLatencyTester.testDoh）
- **只用 wire-format（RFC 8484），不存在 dns-json**：`application/dns-message` MediaType，**POST** + body=完整 DNS 查询报文，`Accept: application/dns-message` + `Content-Type: application/dns-message`（ExpressDohTransport.kt:35/:170-175；DnsLatencyTester.kt:32/:146-151）。全仓 grep 无 `application/dns-json`、无 GET+`?dns=` base64url 分支——**选择逻辑根本不存在：恒 POST wire-format**。
- 客户端：OkHttp，connect/read/callTimeout 均 5s（Express :109-111、Tester :281-283），`ConnectionSpec.MODERN_TLS`（:112/:284）。
- 客户端复用：Express 按 (timeout, host, bootstrapAddrs, protector 身份) 缓存 client，上限 16，`putIfAbsent` 竞态丢弃多余 client，会话结束 `releaseClients()`（:42/:51-100/:131-151，ClientKey.equals 用 `protector ===` :63——符合 === 教训）。
- Bootstrap DNS：注入 OkHttp `Dns`，仅替换目标 host 的解析（:116-126 / Tester :130-144）。
- 失败判定：HTTP 非 2xx 抛 `DoH HTTP error code`（:180-182）；空 body 抛；body 需 `isUsableUpstreamResponse`（:184-186）。Tester 则把 `dnsSuccess && r.isSuccessful` 合并（:172-173）。
- core 侧 DoH 运行时 = Go `resolver_doh.go`；`DnsMessageUtils` 不参与 DoH 报文。

### 4.4 报文构造/解析（DnsMessageUtils.kt，597 行）
- 常量：HEADER_LEN=12(:14)、TYPE_A=1(:15)、TYPE_AAAA=28(:16)、TYPE_OPT=41(:17)、CLASS_IN=1(:18)、**BLOCK_RESPONSE_TTL_SECONDS=300**(:19)、RECORD_HEADER=12(:20)、DNSSEC_OK_FLAG=0x8000(:21)、QR=0x80(:22)、RCODE 0/1/2/3/4/5(:23-28)。
- `buildQuery`（:103-132）：RD=1（`query[2]=0x01` 置 RD——byte2 位 QR0/AA2/TC1/RD0 ⇒ 0x01 恰好只置 RD，符合位表；无 AD 伪造），TXID=0 时随机 `0..65535`（:110）。
- IDN：`toWireLabels`（:148-159）先 `java.net.IDN.toASCII(…ALLOW_UNASSIGNED)` 转 Punycode，标签长度非 1..63 → 返回空列表（:155-157，产出**根名查询**——待定：调用方是否兜底）；对外 `toAsciiQueryName`（:140-146）。
- 解析：`readQueryName`（:521-541）**拒绝查询中的压缩指针**（len≥192 → null，:530）；QDCOUNT≠1 → null（:58-59）；`skipName`（:543-569）处理响应压缩：指针最多跳 128 次、记录"首次跳过后紧跟名字的结束点"以正确算 RDLENGTH 起点。
- 读 TX 偏移表：`extractTtlOffsets`（:414-456）扫 AN+NS+AR，**排除 OPT**（:441-449 注释：OPT 的 TTL 字段是 extendedRCODE/version/flags，含 0 会永久卡死缓存命中——该教训落地）；`minTtlSeconds = min(TTL)`（:403）。
- `patchResponseTtl` 双重载：按 elapsed 逐个递减、任一 ≤0 返回 null（:465-476）；按剩余值整体覆盖（:478-488，remaining≤0 → null，offset 越界 → null）。
- `extractResponseTtlMetadata`（:398-405）：无 TTL 记录（纯 NODATA 响应 AN/NS/AR=0）→ null → **NODATA 也进不了缓存**（负缓存零覆盖的又一佐证）。
- 头回写 `writeResponseHeader`（:264-269）逐位表（byte2: QR=0x80, OPCODE=0x78, AA=0x04, TC=0x02, RD=0x01；byte3: RA=0x80, Z=0x40, AD=0x20, CD=0x10, RCODE=0x0F）：
  ```
  response[2] = QR | (req[2] & 0x79)   // 0x79=OPCODE 全 4 位 + RD；AA/TC 被清零，QR 强制 1
  response[3] = RA | (req[3] & 0x10) | (rcode & 0x0F)   // 保留请求 CD 位；Z/AD 清零——不伪造 AD
  ```
  语义正确且与 AGENT_MISTAKES 位表教训一致（透传 OPCODE/RD/CD，置 QR/RA，不保留 AA/TC，AD 恒 0）。重构时照抄掩码，勿"顺手修正"。
- `buildErrorResponse`（:253-262）：仅 12 字节头 + 复制 TXID 2 字节，四个计数全 0（畸形查询兜底）。
- `withTransactionId`（:386-392）：拷贝后覆盖前 2 字节。
- `DnsQuestion(dnssecOk, checkingDisabled)`（:30-36）——缓存键的 DO/CD 来源。

### 4.5 重写报文（DnsRewriteMessage.kt，173 行）
`internal object`，hosts/rewrite 规则 → 合成应答：A 查询配 IPV4 目标、AAAA 配 IPV6、CNAME 查询配 CNAME 目标，类型不匹配返回 null 让上游兜底（:29-56）；TTL 常量 **REWRITE_RESPONSE_TTL_SECONDS=300**（:19）；应答名用指针 `0xC0|12` 指向问题名（:162-165）；IPv6 走 `InetAddress.getByName`（:88-92，注意这是**本地字面量解析**，非合法 IPv6 返回 null）。`writeResponseHeader` 与 DnsMessageUtils 逐字相同（:167-172）。
**生产不可达（重大）**：main 目录零调用（双向 grep：仅 DnsMessageUtilsTest.kt:65/74/115/120/124 调用）。`RewriteAnswer` 的生产消费链在别处：规则侧 `RewriteRuleManager/MappedSubscriptionRewriteIndex` 产出 `Set<RewriteAnswer>`，Go 侧经 `buildRewriteRulesJson`（server/DnsQueryFilter.kt:100）或 normal 快照推给 Go 引擎，由 Go 构造应答。Kotlin 这份是"单测锁语义的参考实现"。待定：作者意图（大概率是给重构留的黄金样例）。

### 4.6 DnsLookupTool（323 行）与 DnsLatencyTester
- LookupTool：诊断工具，A/AAAA（RecordType :20-23），IP 字面量短路（:58-73），走 `PlainDnsTransport`（protect 传 null :80——**诊断流量不出 VPN**，配合 addDisallowedApplication）；`tunnelLookup`（:117-149）把 Go `TunnelDiagnosticsResolver` 结果映射成同一 Result（server="Go 隧道"）。私有 `DnsRecordParser`（:177-323）覆盖 A/NS/CNAME/SOA/PTR/MX/TXT/AAAA/SRV/OPT（跳 OPT :214），readName 指针上限 64（:275）。消费方：ui/DnsLookupSection.kt + NetworkToolsViewModel（:211/:213/:264）。
- LatencyTester：`test` 单查计时（A 记录 :58），`testAverage` 默认 **3 次**（DEFAULT_ATTEMPTS :271），均值取成功样本 `roundToLong().coerceAtLeast(1)`（:92），部分成功消息"N/M 次成功"（:94-98）；**计时窗口只含查询本身**——bootstrap 解析在 `window.start` 之前（:156-160/:195-199/:228-236，三处同规则）；BASE_CLIENT 懒建共享（:279-286）。调用方：RaceModeSettingsViewModel:320（测速）、DnsSpeedTestSection（展示）；NetworkPingTool/TraceRoute 仅在注释提及。
- DohUrlParser：`parseOrNull` 防 `toHttpUrl()` 抛出炸整轮测速（:17-21，教训注释 :8-13）；**仅 DnsLatencyTester 使用**（:120-127）；ExpressDohTransport.kt:166 仍裸调 `url.toHttpUrl()`——待定：Express 路径是否会经配置导入塞入畸形 URL（Express 服务商源自 config import 路径存在，畸形 DoH URL 会抛 IllegalArgumentException 并在 dispatcher 里被 catch 为上游失败——**不崩**，但错误文案劣于 Tester）。

## 5. 阻断响应构造（报文级）

`BlockResponseMode`（core/rule/BlockResponseMode.kt:7-11）：NXDOMAIN/NODATA/REFUSED/ZERO_ADDRESS，默认回退 NXDOMAIN（:14-16）。
`DnsMessageUtils.buildBlockedResponse`（:161-172）→ 四构造器；整体 `runCatching`，构造异常→ 12 字节 SERVFAIL（:169-171）。
| 模式 | 报文语义 | 关键点 |
|---|---|---|
| NXDOMAIN | 原问题段完整复制 + header QR/RA/rcode=3，ANCOUNT=0（:164、:209-220、:228-244） | 问题名保留原编码 |
| NODATA | 同上但 rcode=0（:165） | ANCOUNT=0、NSCOUNT=0 |
| REFUSED | rcode=5，ANS=0（:166/:222-226） | 客户端视为定论策略（:176-178 注释：SERVFAIL 才允许重试） |
| ZERO_ADDRESS | 仅 qclass=IN 且 QTYPE∈{A,AAAA}：1 条应答，NAME=指针 `0xC00C`，RDATA=4/16 全零字节，**TTL=300**（BLOCK_RESPONSE_TTL_SECONDS :19、:183-207）；其他类型退化为 NODATA（:193） | 长度计算 `answerRecordSize`（:246-251）12+RDLEN |
生产接线：**Kotlin 版 `buildBlockedResponse` 在 main 中零调用**（仅 DnsMessageUtilsTest.kt:15-51）；真正在跑的：Express `ExpressDnsMessageUtils.buildBlockedResponse`（:109-118，同构实现）被 `ExpressDnsEngine.resolve` 消费（:104，A/AAAA 才判规则 :95-96）；normal/server 由 Go 侧完成（`HttpsDnsConfigSnapshot.kt:102-108` 把四模式映射成 `NXDOMAIN/NODATA/REFUSED/CUSTOM_IP`——注意 ZERO_ADDRESS→CUSTOM_IP 的名字差异，Go 侧可配自定义 IP）。
SERVFAIL 生产路径：Express `buildServfailResponse`（ExpressDnsMessageUtils.kt:122）用于查询不可解析（ExpressDnsEngine.kt:79）与上游全灭（:147）；core 版 `buildServfailResponse`（DnsMessageUtils.kt:179-181）**零调用（死代码，双向 grep main+test 无）**。
DDR 反制（Express 特有）：`_dns.resolver.arpa` 及后缀 → 直接 NXDOMAIN（ExpressDnsEngine.kt:85-92）。
Express 缓存只写成功且未截断的响应（:154）。

## 6. API × 模式 调用矩阵

（express=极速 / normal=普通 / server=服务器；✅=生产可达，❌=不可达/仅测试，🔶=仅配置序列化）

| API | 文件:行 | express | normal | server | 备注 |
|---|---|---|---|---|---|
| DnsResponseCache.resolve | DnsResponseCache.kt:62 | ❌ | ❌ | ❌ | **三模式均不可达**；缓存读实际走 Go（normal/server）与 ExpressRoomDnsCache（express） |
| ├ 私有 get/put/materialize/singleflight/stale | :220-410 | ❌ | ❌ | ❌ | 唯一入口是 resolve |
| warmUp | :120 | ❌ | ✅ DnsVpnDatabaseComponents.kt:154 | ❌ | 仅预热统计库 |
| updatePolicy | :58 | ❌ | ✅ DnsVpnRuntimeConfigManager.kt:123,169 | ❌ | 热更新 policy |
| clear | :131 | ❌ | ✅ DnsCacheController:38 | 🔶 server 无（用 Go clearDNSCache） | express 清理走 ExpressVpnController.kt:135-143 直清 DAO |
| clearMemory(公开) | :216 | ❌ | ❌ | ❌ | 外部零调用（内部 :132）——疑似死代码 |
| recordCacheHit | :140 | ❌ | ✅ GoTunnelLogProcessor.kt:89 | ❌ | 仅 Go 日志回写统计 |
| recordResolved | :162 | ❌ | ✅ GoTunnelLogProcessor.kt:91 | ❌ | TTL_UNKNOWN 三态语义 :168/:177-184 |
| flushPendingWrites | :333 | ❌ | ✅ DnsVpnDatabaseComponents.kt:163 | ❌ | 停机/批量阈值/30s 定时 |
| DnsCacheController.register/unregister/clearAll | :12/:19/:35 | ❌ | ✅ DnsVpnDatabaseComponents.kt:153,203；DataCleanupManager.kt:95 | ❌ | clearAll 附回调清 Go 缓存 |
| DnsCachePolicy.effectiveTtlSeconds | :34 | ✅ ExpressRoomDnsCache.kt:118 | 🔶→Go（快照 :56-66） | 🔶→Go（DnsServerEngine.kt:196-208） | express 唯一 Kotlin 消费方 |
| DnsCachePreset.fromPolicy/toPolicy | :69/:78 | ❌ | 🔶 DnsCacheSettingsStore:64/69/73 | ✅ DnsModePreferences.kt:68 | |
| DnsCacheKey.fromQuestion/create | :14/:24 | ❌(express 用自身 #格式) | ❌(仅经不可达 get) + ✅ recordHit/Resolved :147/:173 | ❌ | create 活、fromQuestion 死 |
| PlainDnsTransport.query (core) | :14 | ❌ | ✅ DnsLatencyTester:237 / DnsLookupTool:80 | ❌ | 运行时 53 端口查询走 Go |
| DotTransport.query (core) | :15 | ❌ | ✅ DnsLatencyTester:249 | ❌ | 运行时 DoT 走 Go |
| Express{Plain,Dot,Doh}Transport | express/transport/* | ✅ dispatcher :62-99 | ❌ | ❌ | |
| DnsMessageUtils.buildQuery | :103 | ❌ | ✅ BootstrapSelector:169 / LatencyTester:58 / LookupTool:79 | ❌ | |
| DnsMessageUtils.buildBlockedResponse | :161 | ❌ | ❌ | ❌ | **死代码**（仅测试 :15-51）；express 用 Express 版 |
| DnsMessageUtils.buildServfailResponse | :179 | ❌ | ❌ | ❌ | 死代码 |
| DnsMessageUtils.extractTtlOffsets / patchResponseTtl(3参) / extractResponseTtlMetadata / withTransactionId | :414/:478/:398/:386 | ❌ | 🔶 可达链仅经不可达 get/put 与 recordResolved(空响应) | ❌ | extractTtlOffsets 公开版：main 零调用（内部用）；withTransactionId:94/:409、patch(3参):401、extractMeta:253 均在死路径内——**整组读路径死码** |
| DnsMessageUtils.isSuccessResponse | :286 | ❌ | ✅(死 resolve 内) + BootstrapSelector? 否——实际 DnsLatencyTester:166/:206/:240 | ❌ | Tester 活跃 |
| DnsMessageUtils.extractQuestion | :56 | ❌ | ✅ DnsCacheKey:14 + DnsRewriteMessage:31 | ❌ | |
| DnsMessageUtils.extractQueryName/extractQueryType | :79/:88 | ❌ | ❌ | ❌ | 死代码（main+test 零） |
| DnsMessageUtils.cacheLifetimeSeconds | :394 | ❌ | ❌ | ❌ | 死代码（仅 Express 镜像被 Express 测试用） |
| DnsMessageUtils.extractAddressRecords | :345 | ❌ | ✅ BootstrapSelector.kt:171 | ❌ | |
| DnsRewriteMessage.buildResponse | :29 | ❌ | ❌ | ❌ | 死代码（仅 DnsMessageUtilsTest） |
| DnsProvider.PRESETS/loadAll/loadSelected | :58/:203/:211 | ✅ loadSelected:289 | ✅ DnsVpnProviderResolver:71 | ❌(server 用 DnsModeModels 自有结构) | |
| DnsProvider.isIpLiteral | :391 | ✅ dispatcher→Express 路径(经 DnsProtocol 处理? 实际 :64 getByName 前未判) | ✅ LatencyTester:230 / LookupTool:58 | 🔶 | |
| DnsProvider.runtimeCustomProviderId | :451 | ❌ | ✅ DnsVpnProviderResolver:78 | ❌ | |
| DnsProvider.loadRaceProviderIds/save… | :231/:238 | ❌ | ❌ | ❌ | 死代码（双向 grep） |
| DnsProvider.GOOGLE_DOH_PROVIDER_ID | :444 | ❌ | ❌ | ❌ | 死代码 |
| DnsLatencyTester.testAverage/test | :74/:52 | ❌ | ✅ RaceModeSettingsViewModel:320 | ❌ | test() 仅被 testAverage 内部用 |
| DnsLookupTool.lookup/tunnelLookup | :44/:117 | ❌ | ✅ NetworkToolsViewModel:264/:213 | ❌ | |
| HealthSnapshotMath.applySample | :26 | ❌ | ✅ ProviderHealthEngine:48 + BootstrapHealthEngine | ❌ | |
| ProviderHealthStore.predictionWeight | :28 | ❌(Express 执行层不用权重) | ✅ ProviderHealthScreen:67-72 展示 | ❌ | smart 排序真相见 §8 |
| ProviderHealthEngine.recordResult | :34 | 🔶 仅测速页 | ✅ RaceModeSettingsViewModel:341 | ❌ | |
| RaceLogger.log | RaceLogger.kt:31 | ✅ ExpressUpstreamDispatcher:198,214 | ✅ GoInspectionTunnel:290 | ❌ | 批 20 条 / 2s 定时（:156-157） |
| DnsLogResult.LogResult 枚举 | :3-8 | ✅ ExpressTunnelManager:36 | ✅ GoTunnelLogProcessor:44-49 | ✅ RequestLog 消费 | 结构归 05 章，此处仅记产生条件：ERROR=e非空、REWRITTEN=blockedBy 前缀"rewrite="、BLOCKED、PASSED |
| GoInspectionTunnel.getDnsCacheStats | :118 | ❌ | ❌ **自身无调用方** | ❌ | 疑似死代码；Go 真身 engine_config.go:31 |
| VpnStateRegistry / WorkModeLifecycleRegistry / CrashBreadcrumbs | core/VpnStateRegistry.kt:19/:23；core/WorkModeLifecycleRegistry.kt:33；crash/CrashBreadcrumbs.kt:31 | ✅ ExpressVpnService.kt:96 | ✅ DnsVpnService.kt:236 | ❌ | DNS 相关埋点：仅"启动时记录 resolutionMode.name"（Express :96、normal :236）；CrashBreadcrumbs 环形缓冲 150 条（:15 MAX_BREADCRUMBS）；WorkMode 互斥 stopOtherModes（:73-89）。无缓存级埋点 |

## 7. 关键源码引证表（汇总，均为本会话 Read/grep 实测行号）

- 分片/LRU：DnsResponseCache.kt:35-37, 437-440, 460-496, 507-510
- singleflight：:39, 77-118（=== 判等 :111）
- stale：:98-107, 389-393, 420-424, 452-458
- 写批：:288-331, 333-367（WRITE_BATCH_SIZE=200 :510、30s :509）
- TTL 夹取：DnsCachePolicy.kt:34-46；DnsCacheSettingsStore.kt:20-26, 46-57
- 键：DnsCacheKey.kt:31-42；Express 镜像 ExpressRoomDnsCache.kt:65-70
- 阻断：DnsMessageUtils.kt:161-269；BlockResponseMode.kt:7-11；goValue HttpsDnsConfigSnapshot.kt:102-108
- OPT 排除：DnsMessageUtils.kt:441-449；EDNS0 ExpressDnsMessageUtils.kt:413-428
- 头部位：DnsMessageUtils.kt:264-269（0x79/0x80|CD 掩码）
- DoH POST：ExpressDohTransport.kt:170-175；DnsLatencyTester.kt:146-151
- DoT TLS：DotTransport.kt:70-91；ExpressDotTransport.kt:106-137
- 5s 超时：DnsTimeoutConstants.kt:3
- EWMA：HealthSnapshotMath.kt:13-17, 26-59；ProviderHealthStore.kt:28-56；ProviderHealthEngine.kt:139-170
- Race 执行：ExpressUpstreamDispatcher.kt:103-226
- Go 平行实现（一句话，归第 09 章）：`Android/tunnel/dns_cache.go:22/40`（dnsCache 分片缓存本体，stats :353/statsJSON :382）、`dns_cache_flight.go:24/61`（singleFlight）、`dns_cache_policy.go`（含负缓存）、`dns_cache_types.go:31/36/66`（chainTarget/cacheEntry/dnsCacheStats）、`dns_cache_wire.go`（报文面）、`resolver.go`/`resolver_strategy.go:1+`（四策略真实现）、`resolver_doh.go / resolver_dot.go / resolver_plain.go`（Go 侧传输）、`resolver_stats.go:25`（providerStats）、`bootstrap_resolver.go:87/225`（bootstrap IP 健康+解析器）。

## 8. Flutter 重构注意

1. **纯 Dart 可 1:1 重写**：DnsCachePolicy/Key/Entry 全部位运算与字符串规范化、`DnsMessageUtils` 的 buildQuery/TTL 扫描/patch/withTransactionId/阻断四构造、`DnsRewriteMessage`、`HealthSnapshotMath` 与 `predictionWeight`、LRU 分片（`LinkedHashMap` 在 Dart 即插入有序，accessOrder 需自实现或换 package）、RaceLogger/DnsCache 的批量+定时器+epoch 竞态协议。这些都有单测锁语义（core/cache、core/dns 测试文件），重写后**必须先让旧测试用例（翻译为 Dart）全绿**。
2. **必须平台通道**：`DatagramSocket/Socket/SSLSocketFactory(HTTPS 端点识别+SNI)/OkHttp DoH(VpnService.protect 绑定)` ——Dart `RawDatagramSocket` 无 protect 等价物，TLS 端点识别细节（`endpointIdentificationAlgorithm="HTTPS"`）依赖平台实现差异，建议 method channel + 原生 keep-alive 句柄。
3. **双缓存取舍（确证事实支撑）**：普通/服务器模式运行时缓存 = Go 实现（Kotlin 读路径不可达 §2.11）。重构方向二选一：(a) Dart 引擎复刻语义、废掉 Go；(b) 沿用 Go。无论哪种，**Kotlin `DnsResponseCache` 的 resolve 链不要在 Flutter 侧"复活式"重写**——它是历史遗留的第二套实现，当前生产语义由 Go/Express 两处承担；UI 统计链（Room dns_cache + recordCacheHit/Resolved）可原样迁移。
4. **两套 Express 镜像文件**（ExpressDnsMessageUtils 527 行 vs core 版 597 行、ExpressRoomDnsCache 165 行 vs DnsResponseCache 512 行、三 transport 663 行 vs core 二 transport 219 行）在 Flutter 中应合并为一份实现 + 参数化（EDNS0 开关、超时、socket 钩子），但**键格式差异（`|` vs `#`）与 TTL 默认 300L 兜底（ExpressRoomDnsCache.kt:117 `?: 300L`）属于现存可见行为**，合并需数据迁移或保持双格式兼容，标记待定。
5. **AI 高危自由发挥点**：writeResponseHeader 的 `0x79`/`0x10` 掩码（看似可"修正"为严格 RFC，实际它透传 OPCODE+RD+CD、清 AA/TC、不伪造 AD——逐位表见 §4.4，照抄掩码值）；OPT 的 TTL 排除；`negativeTtl*` 仅流向 Go 配置快照、Kotlin 侧不读——express（Kotlin 缓存）NXDOMAIN 不入缓存、normal/server（Go 缓存）按 negativeTtl 负缓存，**别在 Dart 缓存层抹平这一不对称或凭空加负缓存**；SMART 模式在 express Kotlin 侧 = 纯并行（别自作主张实现加权路由）；**usable 判据两版不同**（Express = QR+TXID+rcode∈{NOERROR,NXDOMAIN}，core = QR+TXID 任意 rcode），迁移时必须按调用侧各取各的版本，不可统一。
6. 健康度自动反馈缺失（§3.4：真实解析不回写 recordResult）——若 Flutter 版要"顺手修复"，先记为产品决策而非等价重写。

## 9. 「待定」清单

1. Express 运行时 SMART_PREDICTION 与 PARALLEL_RACE 执行完全同构；`predictionWeight` 仅测速 UI/健康页消费、无自动回写——"智能选择"的 KDoc 承诺（SettingsGuide.kt:51）与实现差距是否为待修产品决策（normal 侧 Go resolver_strategy.go 才按权重路由，归 09 章确认）。
2. `DnsRewriteMessage` 仅测试可达——保留意图（黄金样例？）待作者确认。
3. DoT `protect()` 返回值被忽略（DotTransport.kt:71 / ExpressDotTransport.kt:116）与 UDP/TCP 版"失败即抛"不一致——是否有意。
4. DoH 无 GET 分支与 dns-json：全仓未见实现，若某服务商仅支持 GET（Google 老接口）当前会失败——记录现状即可，非缺口。
5. `hedgeMisses` 字段无生产者（ProviderHealthStore.kt:19-20/:40-41）——原设计（对冲路由？）无 Kotlin 痕迹。
6. `toWireLabels` 遇超长/空标签返回 emptyList → buildQuery 产生根名问题段（DnsMessageUtils.kt:155-157）——调用方兜底行为未逐一验证。
7. Express 竞速 `isUsableUpstreamResponse` 收紧到 `rcode∈{NOERROR,NXDOMAIN}`（ExpressDnsMessageUtils.kt:225）意味着 REFUSED/SERVFAIL 的上游在 PRIMARY_BACKUP 中被判失败——是否是刻意设计（把 REFUSED 视为服务商策略而非答案）未见注释，标待定；core 版未收紧（两版语义分歧已确证）。
8. server(DNS_MODE) 数据集 `runtimeForDataset` 回落到 `AppDatabase`（DnsRulesDatabase.kt:152-153）而 prefs 独立（RuleDataset.kt:27）——dns_cache 行是否与 normal 共表：按代码 DNS_MODE 不建自己的 dns_cache 表，缓存纯在 Go，此处仅 UI 可能误读，待 11 章核对。
9. `DnsProvider.PREFS_NAME`（:53）与 `ProviderHealthEngine` 四个未用常量（:167-170）——小死码，重构时删除即可，不属行为。
