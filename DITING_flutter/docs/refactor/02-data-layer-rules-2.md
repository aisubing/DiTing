# 02 数据层与规则引擎（二）：匹配与索引、订阅体系、清理、重构注意

```yaml
所属系列: DITING Android Flutter 重构功能图谱 | 章: 02 | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测
```

> 本篇承接 [02-data-layer-rules.md](02-data-layer-rules.md)（§1–§3）。路径缩写同篇 1。

## 4. 匹配与索引算法

### 4.1 域名决策优先级（DomainPolicy，`K:core/rule/DomainPolicyEngine.kt:26-37` KDoc + :73-112 实现）

七级严格短路：①分应用 `$important` 屏蔽（:76）→ ②全局 `$important` 屏蔽（:82）→ ③分应用白名单（:88）→ ④全局白名单（:94）→ ⑤分应用普通屏蔽（含 `*$app=pkg` 全封，:100）→ ⑥全局普通屏蔽（:106）→ ⑦默认放行（:111）。决策缓存 `LruCache(8192)`，键 `domain#pkg|domain`（:44,60），`onCacheChanged` 联动 evictAll（`K:normal/DnsVpnDatabaseComponents.kt:95-96`）。

### 4.2 内存缓存结构（Block/AllowRuleCacheState，`K:core/rule/BlockRuleModels.kt:74-91` / `AllowRuleModels.kt:68-85`）

五层分桶，热路径全部 O(域名标签数) 或 O(1)：
- `customRules/importantCustomRules`：HashMap/Set 精确域 + `firstDomainSuffixHit` 逐父域探测（`K:core/rule/DomainRuleMatcher.kt:14-23`）。
- `*Wildcards`：`WildcardPattern` 线性表（:26-35 首个命中）；`K:core/rule/AdGuardRuleModels.kt:38-79`——字面量子串预筛（:66-68）+ glob→`Regex(IGNORE_CASE)`（:47-60）+ 父域后缀回退（:71-77）；`*.base` 特判含 base 本身（:40-42,65）。
- `appBuckets`：pkg→（exact/importantExact/wildcards/importantWildcards）四桶（BlockRuleModels:25-33）。
- `invertedRules`：`~app=` 反向豁免线性表（重要位过滤 + excludedApps 集合判定，BlockRuleMatcher.kt:143-159）。
- `subscriptionFallback + subscriptionIndex(mmap)`：订阅精确命中主索引，索引缺失才回落全量内存表（Loader 的 `if (mapped == null)` 分支，`K:core/rule/BlockRuleCacheLoader.kt:164-168`、AllowRuleCacheLoader.kt:164-168）。
- `specialRules`：regex/denyallow/dnstype（及索引在场时的带 appScope 订阅规则）线性表：`isRegex→RuleRegex.containsMatch`（Kotlin 与 Go 同规则加 `(?i)` 前缀，`K:core/rule/RuleRegex.kt:15-28`）、通配→即时构造 WildcardPattern、denyallow 后缀排除、appScope 正反判定（BlockRuleMatcher.kt:200-246）。
- block 侧额外 `subscriptionOverrides: Map<String,String?>`：单规则增删的 O(1) 覆盖层（null=禁用，值=仍订阅内），导出快照时转 `disabledRules`（BlockRuleCache.kt:170-177,330）。

匹配入口四段链（BlockRuleMatcher.findMatch :11-16）：importantCustom→importantSubscription→custom→subscription；DomainPolicy 则按 §4.1 用分应用/全局切分入口（findAppImportantMatch 等，:21-83）。

## 4.3 三模式规则下发通道对照表 + rule-index 目录共享风险定版（Lead 复核，本域最关键输入）

### 4.3.1 三模式规则下发通道对照（trie 文件 vs JSON snapshot）

| 维度 | normal（VPN 全隧道） | server（局域网 DNS_MODE） | express（纯 Kotlin） |
|---|---|---|---|
| 执行者 | Go `Engine`（`K:normal/GoTunnelRuleManager.kt`） | Go standalone `Engine`（`K:server/backend/DnsServerEngine.kt`） | 纯 Kotlin `ExpressDnsEngine`，无 Go 实例 |
| 域名 block/allow | **双通道**：JSON 快照 `engine.applyRuleSnapshot`（`GoTunnelRuleManager.kt:43-45`，DnsServerEngine 同款见下行）+ **DTRI trie 文件路径**（`buildRuleSnapshotJson(ruleIndexDirectory)` 的 4 个 `*TriePath` 字段，`DomainPolicyEngine.kt:122-143`；目录实参 `DnsVpnDatabaseComponents.kt:90 = File(filesDir,"rule-index")`） | **仅 JSON 快照**：`DnsServerEngine.kt:114 engine.applyRuleSnapshot(filter.buildRuleSnapshotJson())`，而 `DnsQueryFilter.kt:98 buildRuleSnapshotJson(null)`——传 null 即跳过全部 trie 路径分支（`DomainPolicyEngine.kt:122` 的 `if (ruleIndexDirectory != null…)`），**服务器模式规则不生成也不消费任何 trie/bloom 文件** | **无 Go 下发**：Kotlin 直查 `DomainPolicy`（内存 + mmap 索引），`ExpressTunnelManager.kt:330-341`；索引目录 `ExpressTunnelManager.kt:273 = rootDirectory(filesDir, EXPRESS)`（独立 `/express` 子目录） |
| 覆写 rewrite | `engine.setRewriteRules(JSON)`（`GoTunnelRuleManager.kt:82-97`）；DRWI `hosts/rewrite.trie` 由 `RewriteRuleManager` 生成入 `rule-index/hosts/`（`RuleIndexLayout.kt:81`） | `engine.setRewriteRules`（`DnsServerEngine.kt:118`）；`DnsQueryFilter.kt:60-65` 的 `RewriteRuleManager(indexDirectory=null)` → **不生成 DRWI** | 存而不评估（`express/engine/` 零 rewrite 引用） |
| URL 规则 | `engine.setRequestRules(JSON)`，双闸门（`GoTunnelRuleManager.kt:99-110`） | 无（DnsServerEngine 从不 setRequestRules） | 无 |
| 美化 cosmetic | `engine.setCosmeticRules(JSON)`（`GoTunnelRuleManager.kt:112-123`） | 无 | 无（闸门拒录入） |
| 阻断响应 | applyDNSConfig `blockResponse`（`HttpsDnsConfigSnapshot.kt:50,102-108`）→ `G:dns_config.go:163` | `engine.setBlockResponseType(filter.blockResponseMode.name)`（`DnsServerEngine.kt:119`） | Kotlin `ExpressDnsMessageUtils.buildBlockedResponse`（:109-115） |

小结：**DTRI/DRWI trie 文件通道仅 normal 一路真正使用**；server 全程走 JSON（且显式传 null 目录），express 走内存/mmap（独立子目录）。

### 4.3.2 `rootDirectory()` NORMAL==DNS_MODE 同目录风险定版

**事实基线**：`RuleIndexLayout.kt:42-46` 三 dataset 中只有 EXPRESS 返回 `rule-index/express`，NORMAL（:43）与 DNS_MODE（:45）返回**同一** `File(filesDir,"rule-index")`。

**① DNS_MODE 数据集下是否真有生成 trie/bloom 的调用链？**
主运行链路：**无**。服务器模式三大消费点都把 indexDirectory 置 null，规则只以 JSON 快照下发——
- `K:server/backend/DnsQueryFilter.kt:49-66`（block/allow/rewrite 三 manager 均 `indexDirectory=null`）；
- `K:server/backend/DnsServerEngine.kt:114` 经 `DnsQueryFilter.kt:98 buildRuleSnapshotJson(null)`，JSON 内不含任何 trie 路径；
- 后台串行化链路也按 dataset 门控为 null：`K:core/rule/RuleOperationWorker.kt:157-161`、`K:core/rule/SubscriptionAutoUpdateEngine.kt:312-316`。
故「服务器规则只走 applyRuleSnapshot JSON」这一 Lead 判断**成立**。
唯二可能用非空目录且 dataset=DNS_MODE 的旁路：
- `K:ui/transfer/RuleConfigImporter.kt:25-27` `ruleIndexDir = rootDirectory(filesDir, session.dataset)` **未按 dataset 门控**（与上面三处 gate 不同），:118-120 三 manager 携该目录；**但**本类内所有规则写入都 `refreshCache=false`（:130-131,157-158,183-184,209-210）且订阅仅 `addRemoteSubscription` 元数据入库（:89-96）不下载，故导入全程**不触发** `cache.reload→compileAndLoad`——目录形参在导入期实际未被消费（潜在、非活跃）。收尾 `refreshRuleIndexesIfRunning`（`K:ui/transfer/ConfigImporter.kt:59-70`）发的是 Intent，对 DNS_MODE 只 ping DnsModeService（`RuntimeDnsSettingsRefresher.kt:42-44,184-193`），不回本地 manager。
- `K:ui/RuleListViewModel.kt:134,162`：`RewriteRuleManager(rewriteRuleDao, File(filesDir,"rule-index"), …)` **目录硬编码为 NORMAL 且无 dataset 门控**，而 `rewriteRuleDao = RuleDatabases.forDataset(dataset).rewriteRuleDao()`（:31,35）按 dataset 路由；REWRITE 删除/启停走 `refreshCache(rebuild)`（RewriteRuleManager.kt:171,172→:37-47）→ 若 dataset=DNS_MODE **会把服务器库的 rewrite 行编成 `hosts/rewrite.trie` 落进 NORMAL 目录**。可达性取决于是否以 `ruleKind=REWRITE` 导航进 RULE_LIST（路由表 SettingsRouteActivity.kt:383-387 只见 BLOCK/ALLOW/URL_*；REWRITE 走 RewriteListScreen→RewriteListViewModel，其目录在 :70 已门控为 `if(dataset==NORMAL) … else null`）——**REWRITE 经 RuleListViewModel 触发交叉写属待定**，RewriteListViewModel 一路已确认安全。

**② 若有，服务器规则重建是否覆写普通模式索引文件？**
主链路安全：server 从不写 trie（见①），express 写独立 `/express` 子目录（`RuleIndexLayout.kt:44`），互不触碰。唯一交叉污染向量是①的 RuleListViewModel-REWRITE 旁路：一旦可达，DNS_MODE 数据会被序列化进 `rule-index/hosts/rewrite.trie`（NORMAL 目录），NORMAL 的 Go `applySnapshot` 依 mtime+size 变化（`G:policy_engine.go:422-425`）重开该文件 → **对运行中 VPN 施加错误数据集规则**（语义冲突，非仅竞态）。RuleConfigImporter 旁路当前不触发写入（①）。

**③ 清理互删是否影响运行中的另一模式？**
`DataCleanupManager` 的 DNS_MODE 分支（`K:data/cleanup/DataCleanupManager.kt:160-163`、`:242-244`、`:321-323`、`:518-521`）删除的是 `rule-index/domain/` 与 `rule-index/hosts/rewrite.trie`——即 NORMAL 在用产物；随后 `RuntimeDnsSettingsRefresher.refreshIfRunning(dataset=DNS_MODE)`（:163,244,323,521）**只** `pingDnsModeFilterReload`，其 when 分支互斥（`RuntimeDnsSettingsRefresher.kt:41-67`），**不会**向 NORMAL 的 DnsVpnService 发刷新意图。后果定版为**良性、自愈、不注入错数据**：
- 删除动作不移除已映射内存——NORMAL 侧 Kotlin `MappedSubscriptionRuleIndex`（RandomAccessFile map）与 Go `dtriReader`（`mapFileReadOnly`）句柄在文件删除后仍有效（POSIX/WAR 语义），运行中的 VPN 继续用旧规则，**不受即时影响**；
- 服务器库与 VPN 库物理隔离（`RuleDatabases.forDataset`），NORMAL 下一次自身 `refreshCache(forceRebuild=false)` 时因文件缺失回落 `compileAndLoad`（`BlockRuleCacheLoader.kt:64-95`）从 **NORMAL 自己的库**重建同名文件——数据正确，只是重建前有个「文件缺失但内存仍服务」的窗口；此窗口内若 NORMAL 冷重启 VPN，也从 NORMAL 库全新重建，结果正确。
- 故「清理互删」真正风险不在**删**（删只是销毁可重建派生物），而在②的**写**（写会把错误数据集内容固化进共享文件并被对端 mmap 读到）。

**Flutter 重构结论（模式数据隔离关键输入）**：`rule-index` 必须按 dataset 三分目录（现仅 EXPRESS 分），使「派生索引文件的命名空间」与「源数据 Room 库的命名空间」对齐；主链路（server 三大消费点、后台两 gate）已确认零交叉写，唯一已识别的**潜在**写向量是 RuleListViewModel-REWRITE 未门控目录（②，其 UI 可达性待定），清理共目录（③）经走查判为「成立但良性自愈」——记「本轮可暂不改，迁移时统一分目录」，不得记「无害」。门控现状不一致：RewriteListViewModel.kt:70 与 SubscriptionViewModel.kt:338,498 已有 `if(dataset==DNS_MODE) null` 守卫，RuleConfigImporter.kt:26（有 dir 但导入期不触发编译）与 RuleListViewModel.kt:134,162（无守卫、硬编码 NORMAL 根）应拉齐为同一 `rootDirectory` 门控约定。另注：`RuleIndexLayout` 现布局**不存在独立 `.bloom` 产物**（bloom 内嵌于各 .trie 文件 offset 36 起），Go 的 `LoadBloomFilter`/`*.bloom` 只属于 §8 第 3/6 条已判死的原生 trie 链。

### 4.4 mmap 索引文件格式（逐字段）

**DTRI**（`K:core/rule/MappedSubscriptionRuleIndex.kt`，MAGIC `0x44545249`="DTRI" :117，VERSION=1 :118，BIG_ENDIAN :158，FileChannel.map READ_ONLY）：

| 偏移 | 字段 | 说明 |
|---|---|---|
| 0..35 头（9×int32） | magic, version, nodeCount, edgeCount, sourceCount, bloomBits, bloomBytes, labelsBytes, sourcesBytes | 写出序 :270；载入校验 :159-172（含 `sourceOffset+sourcesBytes==limit` 全长断言） |
| 36.. | bloom 位图 | 7 个双重哈希（FNV-64 变体 h1/h2，:285-294），位=`max(64, 规则数×10)`（:254）；对**完整 pattern** 置位，查询对每个父域后缀做或判定（:55-71） |
| +bloomBytes | 节点表，12B/节点 | int32[3]：terminalSourceIdx(-1 非终止)、firstEdge、edgeCount（:106,252,273） |
| | 边表，12B/边 | int32[3]：labelOffset、labelLength、childNode（:84,250,274）；同一父节点边按 label 排序，二分查找（:73-88） |
| | 标签池 | UTF-8 字节连续拼接（:247-249） |
| | 源名表 | [len][utf8 bytes]×sourceCount；节点 terminalSourceIdx 即其下标（:174-184,108-110） |

树为**逆序域名前缀树**（label 自右向左 :210-217），仅收无修饰的精确订阅规则（compile 端过滤 :204-208 与 Loader 双保险 :84-88/:102-103）；同 pattern 多源取 `min` 源名（:218）。文件路径：`filesDir/rule-index[/express]/domain/{block,block.important,allow,allow.important}.trie`（`K:core/rule/RuleIndexLayout.kt:42-82`；express 根含 `/express` 子目录 :44，**DNS_MODE 与 NORMAL 共用根目录名 `rule-index`** :43/:45——但 DNS_MODE 运行链路全部传 `indexDirectory=null`（`K:server/backend/DnsQueryFilter.kt:49-66`、SubscriptionAutoUpdateEngine.kt:312-316、RuleOperationWorker.kt:157-161），仅 DataCleanupManager 的 DNS_MODE 分支真的按该目录删文件（:160-162,242-243,321-322,518-520），与 NORMAL 索引同名同路径——清理服务器模式规则可能连带删除 VPN 模式的 DTRI 文件，属**已确证的目录重叠**（RuleIndexLayout.kt:43/:45 恒等）。但 DataCleanupScreen 收到 dataset=DNS_MODE 的**入口可达性未证**：DnsSettingsScreen.kt:51-53 虽以 `createIntent(route, dataset=RuleDataset.DNS_MODE)` 开设置路由，但实测其 5 个目标（:78-138：CACHE_SETTINGS/RULE_CONTROL/BLACKLIST/WHITELIST/REWRITELIST_MANAGEMENT）不含 DATA_CLEANUP；openRoute 仅向子路由传播 requestedRuleDataset（SettingsRouteActivity.kt:223），上述 DNS_MODE 屏内无任何跳 DATA_CLEANUP 的按钮；主入口 MainModeDispatcher 只发 EXPRESS（:61）或 null→NORMAL（:111），DNS 工作模式分支（:71-77）根本不接 onNavigateToDataCleanup。故 DNS_MODE 清理分支（DataCleanupManager.kt:160-163 等四处删 NORMAL 同名文件）现状为「机制真实、入口可达性待定」，完整后果分析见 §4.3.2③。【待定：是否存在第三方入口/深链以 DNS_MODE 直达 DATA_CLEANUP】

**DRWI**（`K:core/rule/MappedSubscriptionRewriteIndex.kt`，MAGIC `0x44525749` :127，头 10×int32 :129，节点 16B：answerStart/answerCount/firstEdge/edgeCount :122,244,268，边 12B 同构，尾部 targetIds int32[] + 答案表 [typeLen][valLen][type][value] :187-198,272-276）。查询 `find` 先完整域精确走树、失败逐级剥父域重试（:34-44），bloom 同样按后缀族预筛（:60-69）。文件：`…/hosts/rewrite.trie`（RuleIndexLayout.kt:81-82）。生成时机：三个 Loader 均在缓存 reload 且（文件缺失/损坏/forceRebuild）时**先写 `.tmp` 再原子 rename，失败退化为 copyTo**（MappedSubscriptionRuleIndex.kt:129-153、RewriteIndex :139-163）；`finally` 无条件删残留 temp。注意 `RuleIndexLayout.deleteAll`（:85-91）**零调用方**（本会话 grep 双向确认，仅定义行命中），残留清扫实际靠 rename 前的 `target.delete()`。

### 4.5 并发与热更新语义

- 缓存对象不可变 state + `@Volatile` 引用 + `synchronized` 换装；旧 mmap 索引在换装后**判异性关闭**（`oldIndex !== new` 才 close，BlockRuleCache.kt:63-68）——Go 端另有延迟：DTRI 换代旧 reader `time.AfterFunc(2s, close)`（`G:policy_engine.go:427-431`）。
- 索引版本感知：Go 按 `mtime+size` 判重开（policy_engine.go:422-425），Kotlin 端 reload 时文件被替换即触发 mmap 重映射。
- Go 快照原子替换：`pe.snapshot.Store(snap)`（policy_engine.go:469），锁内只做快照，无锁读评估（`evaluate` :47-56 atomic Load）。
- 热重载触发面：`RuntimeDnsSettingsRefresher`（`K:core/rule/RuntimeDnsSettingsRefresher.kt`）6 个入口全部经**显式 startService Intent**（非广播，Manifest 无对应 receiver）：`REFRESH_RUNTIME_CONFIG`/`SYNC_RULE`/`REFRESH_RULE_INDEXES`/`SYNC_HTTPS_REQUEST_RULES`/`REFRESH_APP_EXCLUSIONS`/`REFRESH_APP_ALLOWLIST`（:23-28，normal DnsVpnService.kt:135-166 消费）、express `REFRESH_CONFIG`/`SYNC_RULES`（:30-31）、server `REFRESH`（:33）；每入口先查 `VpnStateRegistry.isNormal/isExpressRunning`（:57 等），DNS_MODE 还查 `WorkModeStore==AppWorkMode.DNS`（:185）。Intent 只带 reason/标志位，规则负载由接收服务重读 Room 再推 Go——**payload 与库始终同源**。express 的 SYNC_RULES 落点 `ExpressTunnelManager.syncRules`（:474-480）只刷 block/allow+失效域缓存，不刷 rewrite。
- `RuleUpdateNotifier.kt`（65 行）整类**死代码**：全仓仅定义行命中（双向 grep），热更新实际如上走 Intent；RuleOperationWorker 自建同渠道通知（`RuleOperationWorker.kt:142,525-540`，渠道 `diting_rule_operations_channel`）。
- keyset 分页装载：`util/KeysetPaginationHelper.kt:4-17`（lastId 循环），页大小三处各 2_000（BlockRuleCacheLoader.kt:49、AllowRuleCacheLoader.kt:49、RewriteRuleManager.kt:272）；导入分块 500（DAO replaceBySource 默认 :137-139）与 1000（CategorizedRuleStreamImporter.CHUNK_SIZE :26、RuleOperationWorker.IMPORT_CHUNK_SIZE :568）。`AllowRuleDao.kt:12` 的 `INDEX_PAGE_SIZE=500` 为**未引用私有常量**（本会话 grep 无消费点）。

### 4.6 Go 侧规则消费（跨语言契约面）

- **快照 JSON**（`DomainPolicyEngine.buildRuleSnapshotJson` :118-255 → `Engine.ApplyRuleSnapshot`，`G:engine_config.go:51-65` → `policy_engine.go:178+`）：字段 filterEnabled、4 个 trie 路径、globalAllow/globalBlock/globalImportant、appRules{allow,block,important}、invertedBlock/invertedAllow{pattern,source,important,excludedApps}、specialBlock/specialAllow（9 字段全镜像）、disabledRules。server 模式同函数但 `ruleIndexDirectory=null`（`DnsQueryFilter.kt:98`）。
- **DNS 阶段覆写**：`setRewriteRules(JSON map[domain]→string|array)`（`G:engine_config.go:80-106`），查询期 exact+父域后缀回退（rewriteLookup :142-160），IPv4/IPv6 直答 TTL300，CNAME 供 MITM 重定向。
- **URL 规则**：`setRequestRules`（`G:engine_request_filter.go:22-41`）最长前缀、等长 allow 优先（:61-66），命中 403（:82-94）；仅 normal，且双闸门 `inspectionEnabled && isAddressRulesEnabled`（`K:normal/GoTunnelRuleManager.kt:99-110`）。
- **美化规则**：`setCosmeticRules(scopedJson)`（`G:engine_mitm.go:228-230`→`mitm_cosmetic_inject.go`），Go 在 text/html 响应 `<head>` 后注入 `<link href="https://local.pwhs.app/cosmetic.css?h=host">`，CSS 由本地假域名服务器按 host+父域族合成（含 exception→`display:revert !important`）；仅 normal。
- **阻断响应**：`BlockResponseMode`（`K:core/rule/BlockResponseMode.kt:7-10`）四态：NXDOMAIN(rcode3)/NODATA(rcode0 ancount0)/REFUSED(rcode5)/ZERO_ADDRESS(0.0.0.0/::, TTL300)。normal 经 `goValue` 映射（ZERO_ADDRESS→"CUSTOM_IP"，`K:normal/HttpsDnsConfigSnapshot.kt:102-108`）入 applyDNSConfig 的 `blockResponse` 字段（`G:dns_config.go:35,163`）；server 直接 `.name`（DnsServerEngine.kt:119）——两支字符串不同但 ParseResponseType default 兜底一致（`G:dns_packet.go:28-39`）。express 纯 Kotlin 合成 `ExpressDnsMessageUtils.buildBlockedResponse`（:109-115）。**已确证不对称**：Go 全隧道合成 switch 无 `ResponseNoData` 分支（`G:engine_dns.go:261-270` default→零地址），NODATA 在 normal 全隧道退化为零地址；standalone（server）:261-262 正确出 NOERROR 空答。
- **动态升级**：`DynamicBlockResponseConfig`（阈值5/窗口60s/保持300s，`K:core/rule/DynamicBlockResponsePolicy.kt:13-21`；范围 2-100/10-300/60-3600）由 **Go 实现**（`G:dns_config.go:58-90 responseFor`：窗口内计数>阈值→置 NXDOMAIN 保持期；**未超阈值反而强制 NoData**；map 上限 4096 逐个踢出）。输入仅域名字符串，与 qtype/应用无关。Kotlin 同名 `DynamicBlockResponseTracker`（:26-37）**只有 clear() 且无任何读方**——vestigial（实例化 DnsVpnRuntimeConfigManager.kt:67，清空 :122,168）。express 明确不支持升级（`K:express/ExpressDynamicBlockSupport.kt`）。

## 5. 订阅体系

### 5.1 状态机（SubscriptionImportState：ready/importing/failed，`K:data/entity/SubscriptionEntity.kt:76-80`）

- →importing：插入时（addSubscription SubscriptionManager.kt:118、addLocalSubscription :247）；更新/编辑起手 setImportState（:375,:450）。
- →ready：add 成功整体 update（:146）；本地导入成功（:290）；update/edit 经 `publishStagedRules` 事务写回（:417,:485）；304 → `markNotModified`（DAO :98-109：仅 state/error/lastAttemptAt/失败计数清零/两个校验头，不动 ruleCount）。
- →failed：add 下载失败先 `removeSubscriptionRules` 再标 FAILED（:135-138）；catch 分支同（:158-165,:297-304）；update 失败 `removeStagingRules`+`markUpdateFailed`（consecutiveFailureCount+1，DAO :111-115；:492-511）；协程取消 → `markUpdateCancelled`（NonCancellable 清 staging + FAILED"已保留原有规则"，SubscriptionRuleStorage.kt:91-100，Manager :419-421,:489-491 重抛）。
- 中断恢复：`SubscriptionImportRecovery.recoverInterruptedImports`（:24-45）扫 `importState='importing'`，事务内删 `staging_sub_<id>` 五族（含 goUrl/cosmetic，:53-59）；从未成功过（ruleCount=0 且 lastUpdated=0）再删 `sub_<id>` 并 `markInterruptedImportFailed`（清计数+清校验头，DAO :85-90），否则仅标 FAILED 保留旧规则。**惰性触发**：每次手动任务开工（RuleOperationWorker.kt:192）与每次自动更新/重试开工（Engine :69,:147），非进程启动钩子。

### 5.2 下载与镜像链（`K:core/rule/SubscriptionDownloader.kt`）

OkHttp 默认客户端 + connect 30s/read 60s（:20-23，跟随重定向为 OkHttp 默认）；同步 execute 于 IO。首次导入 `downloadAndImport`（:38-54→:56-76）：镜像优先——`mirrorTemplate`→`buildMirrorUrl`（SubscriptionUrlHelper.kt:20-38，占位符集 `{url},{urlEncoded},{scheme},{host},{path},{pathAndQuery}` :7-9，校验必须含其一 :11-18），**只有 1 个镜像候选**，失败且 `mirrorFallback=true` 才回退原始地址（先清已流式写入的 live 规则 :72）。更新走 `downloadAndStage`（:129-152）：先清同 id 旧 staging（:138），条件 GET 仅此处启用——`If-None-Match`/`If-Modified-Since`（:165-166），304→NotModified（:170-171），412→丢校验重采（:173-174）。响应落 cacheDir 临时文件（前缀 `sub_import_`/`sub_stage_`，:90/:178，finally 删除）→ 三读：badfilter 键集 → countRules 进度总分 → 流式 import（:95-111/:183-199）。`ruleSetHash` **全链路恒 null**（:118、Manager :413,:481；无 MessageDigest 产生点，本会话 grep）——遗留列。HTTP 错误分类：408/425/429/5xx retryable（:214-217）。

### 5.3 解析入库与分组（`K:core/rule/CategorizedRuleStreamImporter.kt`）

六族并行批次（1000/flush，:114-119,135-230）；kind 门：hosts 只收 block+rewrite，allow/url/cosmetic 计 typeSkipped（:249-310；语义注释 :69-78）；badfilter 键比对剔除（键式见 §3.1/3.2；cosmetic 无 badfilter 路径）；`parsedRules==0 → onEmpty(typeSkipped>0)`（:320）产出"类型选错"vs"无有效规则"两种不可重试异常（Downloader :224-234）。去重靠 DB IGNORE+回查 id（AllowRuleDao.insertAllForSource :83-133 批量冲突回收 id）；duplicateCount=解析−实插−badfilter（:333）。`importTwoPass`（:346-370）仅测试用（本会话 grep：生产零调用）。

staging→live 提升：`SubscriptionRuleStorage.publishStagedRules`（:65-83）单事务 rename `staging_sub_<id>`→`sub_<id>`（block/allow/rewrite 走 replaceSource：删 live、UPDATE source、删孤儿）+ goUrl/cosmetic deleteBySource+promoteSource + subscription.update；**kind 形参未用**（五族无条件处理，:67 vs 实现），事务外 refreshAllCaches。源标签：`sub_<id>`/`staging_sub_<id>`（:33-35）；DAO 侧一切"订阅规则 vs 用户规则"分界都用 `LIKE/GLOB 'sub_%'` 与 `'staging_sub_%'` 前缀约定（AllowRuleDao/BlockRuleDao/RewriteRuleDao/CosmeticRuleDao/GoUrlRuleDao 各查询中反复出现）——**前缀即契约**，Flutter 迁移须保留或显式重构此约定。分组：`subscription_group.autoUpdateEnabled` 经 JOIN 门控自动更新资格（SubscriptionDao:34-38）。

### 5.4 自动更新调度（`K:core/rule/SubscriptionAutoUpdateScheduler.kt` / Engine.kt）

- 设置：`SubscriptionAutoUpdateSettings`（:31-63）按 dataset prefs 存 enabled/intervalHours，默认 24h，候选 {6,12,24,48}，界 1..168。
- 周期任务：`enqueueUniquePeriodicWork`，名按 dataset 三套：`subscription_auto_update` / `_express` / `_dns`（+对应 `_retry`）（:67-72,137-147），`ExistingPeriodicWorkPolicy.UPDATE`（:105），无 flex 参（WorkManager 默认 flex），约束仅 `NetworkType.CONNECTED`（**无充电约束** :98-102），退避 EXPONENTIAL 30s（:103）。`sync()` 三 dataset 对账（:75-79；调用：DitingApp.kt:63 启动、ExpressDefaultsSeeder.kt:114、SubscriptionAutoUpdateIntervalScreen.kt:75/107、PreferenceConfigImporter.kt:75）。
- 手动队列：`RuleOperationScheduler`（RuleOperationWorker.kt:52-125）唯一名 `manual_rule_operation_queue`，`APPEND_OR_REPLACE` 串行化（:117-123），前台通知 FOREGROUND_SERVICE_TYPE_DATA_SYNC（:504-518），10 种操作枚举（:39-50）。
- 批次：batchId=UUID（Engine:62）；逐订阅 `updateSubscription`，结果记 `subscription_auto_update_item`（Updated/NotModified→SUCCESS(changed 区分)，Failed→PENDING_RETRY 或 FAILED，recordOutcome :249-282）；剩 PENDING_RETRY→`scheduleRetry`（一次性、initialDelay 30s、REPLACE 策略，Scheduler :108-135）；重试预算 `MAX_RETRY_ATTEMPTS=3` 用 WorkManager `runAttemptCount` 判顶（Engine :29,176-184 封顶后转 FAILED）。**consecutiveFailureCount/lastAttemptAt 不参与任何跳过/重试判定**（本会话 grep：读方仅 UI SubscriptionItemList.kt:165,205）。
- 手动/自动互斥：`SubscriptionUpdateCoordinator`（30 行）单 Mutex + AtomicInteger；`runAutomatic` 见有手动在途或抢锁失败即整体放弃→`BlockedByManualOperation`→Worker `Result.retry()`（Scheduler :167-170）；自动循环每条目查 `shouldStop()` 协作中止（Engine :71-75）。
- 完成后：changed→强制重建三缓存（DTRI/DRWI forceRebuild）→`refreshRuleIndexesIfRunning`（NORMAL/EXPRESS Intent；DNS_MODE ping server 服务）+ NORMAL 额外 `syncHttpsRequestRulesIfRunning`（Engine :224-247）。
- 汇总通知：`SubscriptionAutoUpdateNotifier`（Scheduler :239-280），渠道 `diting_subscription_auto_update_channel`，id 4102，无 POST_NOTIFICATIONS 即静默。
- 统计口径：订阅拦截统计 `dns_log.blockSubscriptionId`+`http_request_log.blockSubscriptionId` 按 `sub_` 源 id 聚合（DnsLogRepository.subscriptionInterceptionStats :88-107；blockSubscriptionId 由 `subscriptionIdOrNull()` 从 source 标签反解，SubscriptionUrlHelper.kt:57-58）。

## 6. 数据清理与保留

### 6.1 LogMaintenance（`K:core/log/LogMaintenanceManager.kt`，object 名 `LogMaintenance`）

- 周期：启动 30s 后首扫，此后每 1h（:24-25,40-51）；两条 start 重载——AppDatabase 版（含流量）与 `DnsRuntimeDataSources` 版（express 无 http 表，ExpressTunnelManager.kt:286 接入）。
- 日志保留：`retentionDays<=0` 直接跳过（:61,99）；cutoff=now−days×86400000，对 dns_log/http_request_log/dns_race_log/bootstrap_log 各自 `deleteBefore`（:130-141）。设置 `log_retention_days` 默认 **7**，界 1..30（`K:ui/settings/SystemSettingsStore.kt:10,31,48-58`，按 dataset prefs）。
- 流量保留：独立设置 `traffic_stats_retention_days` 默认 **30**，界 1..90（:28,32,121-130）；`app_traffic_daily.deleteOlderThan(yyyy-MM-dd cutoff)`（LogMaintenance :78-88）。
- 清缓存：`DnsCacheDao.deleteExpired(now)`（DAO :108-109）+ LRU 逐出策略在 `core/cache/`（07 章）；`clearAllLogs` 先经 `activeComponentsClearBuffers` 钩子清各 Logger 内存缓冲（:143-157，注册 DnsVpnDatabaseComponents.kt:107-112）。

### 6.2 DataCleanupManager（`K:data/cleanup/DataCleanupManager.kt`，550 行顶格）

分区清理（每区均按 dataset 三分支；UI：normal/ui/DataCleanupScreen.kt:108-123、express/ui/ExpressDataCleanupScreen.kt:200-205）：

| 动作 | 内容 | 备注 |
|---|---|---|
| clearRequestLogs | EXPRESS 走 Express 库三表；否则 LogMaintenance.clearAllLogs | :49-62 |
| clearDnsCache | express 清表+`clearCacheIfRunning`；否则 DnsCacheController+刷新运行态 | :85-98 |
| clearAllDomainRules | 清 block/allow 全部、rewrite 仅 IPv4/IPv6 目标、cosmetic 全部、`deleteByKind(DOMAIN)` 订阅 + `resetAfterRuleCleanup()`（**A-066**：全表重置 ruleCount/lastUpdated/ETag 等，否则旧 ETag 令下次更新误判 304 永不重导，:209-211）+ auto-update 孤儿行；重播 preset（NORMAL：DefaultWhitelistSeeder；EXPRESS：ExpressDefaultsSeeder）；删 `domain/` 目录与 hosts/rewrite.trie；强制重建缓存+推运行态 | :118-213 |
| clearAllAddressRules | goUrl 全清 + rewrite 仅 CNAME + hosts 索引删除；**不清 subscription 行**（URL/hosts 类订阅保留） | :218-272 |
| clearAllSubscriptions | 订阅/分组/批次全清 + 五族 `clearSubscriptionRules()`（删 `sub_%`/`staging_sub_%` 源+孤儿） | :277-374 |
| resetCaCertificate / resetAppRules / resetOutboundProxy | prefs/证书重置+运行态刷新 | :379-406 |
| clearAllLocalData | 一键全清：EXPRESS 分支连 `rule-index/express` 整树与 express prefs 全清后重播种；DNS_MODE 分支清规则+`rule-index/domain`+hosts 索引+dns_mode prefs（**不动日志/缓存表**——DnsRulesDatabase 本无这些表）；NORMAL 分支串联上述全部+镜像模板+avatars/recognition 目录 | :455-549 |

保留期策略汇总：日志 7d（可 1-30）、流量 30d（可 1-90）、批次明细在 `finishBatch` 即删（Engine :284-294，通知后 deleteBatch）、崩溃日志/更新包/缓存目录见 05 章。

## 7. 关键源码引证表（路径:行）

| 主题 | 引证 |
|---|---|
| 三库定义/版本/迁移 | `K:data/AppDatabase.kt:46-89,114-163`；`K:data/ExpressRulesDatabase.kt:47-57,59-118`；`K:data/DnsRulesDatabase.kt:39-78,80-131` |
| dataset 路由 | `K:data/DnsRulesDatabase.kt:134-153`；`K:data/RuleDataset.kt:19-57` |
| 解析总线 | `K:core/rule/AdGuardRuleParser.kt:177-199,217-218`；`K:core/rule/AdblockRuleLineParser.kt:44-284`；`K:core/rule/HostsAndDnsmasqParser.kt:7-155`；`K:core/rule/AdGuardDomainUtils.kt:10-38,70-112` |
| 优先级矩阵 | `K:core/rule/DomainPolicyEngine.kt:26-37,73-112` |
| DTRI/DRWI 格式 | `K:core/rule/MappedSubscriptionRuleIndex.kt:115-297`；`K:core/rule/MappedSubscriptionRewriteIndex.kt:125-289`；`K:core/rule/RuleIndexLayout.kt:27-92` |
| 缓存分桶与匹配 | `K:core/rule/BlockRuleMatcher.kt:11-246`；`K:core/rule/AllowRuleMatcher.kt:8-212`；`K:core/rule/BlockRuleCacheLoader.kt:51-291`；`K:core/rule/AllowRuleCacheLoader.kt:51-289` |
| 快照跨语言 | `K:core/rule/DomainPolicyEngine.kt:118-255`；`G:engine_config.go:51-65`；`G:policy_engine.go:58-98,178,399-469`；`G:policy_dtri_reader.go:10-15,37-133`（MAGIC `0x44545249`/v1/头36B/节点12B/边12B 与 Kotlin 逐字段一致） |
| 订阅下载/入库 | `K:core/rule/SubscriptionDownloader.kt:20-23,63-75,129-212,214-234`；`K:core/rule/CategorizedRuleStreamImporter.kt:26,101-339`；`K:core/rule/SubscriptionRuleStorage.kt:33-35,65-100` |
| 状态机 DAO | `K:data/dao/SubscriptionDao.kt:34-38,82-115`；`K:core/rule/SubscriptionManager.kt:134-170,419-515` |
| 自动更新 | `K:core/rule/SubscriptionAutoUpdateScheduler.kt:31-147,239-280`；`K:core/rule/SubscriptionAutoUpdateEngine.kt:29,41-215,249-294`；`K:core/rule/RuleOperationWorker.kt:52-125` |
| 热重载 Intent 面 | `K:core/rule/RuntimeDnsSettingsRefresher.kt:19-33,35-193`；消费 `K:normal/DnsVpnService.kt:135-166` |
| 保留/清理 | `K:core/log/LogMaintenanceManager.kt:24-141`；`K:data/cleanup/DataCleanupManager.kt:49-549`；`K:ui/settings/SystemSettingsStore.kt:10,28,31-32,48-58,121-130` |
| Go 消费（URL/覆写/美化/响应） | `G:engine_request_filter.go:17-94`；`G:engine_config.go:69-175,390-432`；`G:engine_mitm.go:228-230`+`G:mitm_cosmetic_inject.go`；`G:dns_config.go:35-36,58-90,163`；`G:dns_packet.go:21-39`；`G:engine_dns.go:261-270` |

## 8. Flutter 重构注意（仅列本会话确证项）

1. **Room→drift 映射**：三库文件（diting_database/diting_express/diting_dns_rules）保持物理隔离语义；20 张表、5 处外键（实测 ForeignKey=5：allow/block/goUrl/rewrite 的 source 表 + subscription_auto_update_item→subscription，**cosmetic_rule_source 无外键**——孤儿清理在三 DAO 的 `deleteOrphans` SQL 里手工复刻，迁移 drift 时可统一改用 FK CASCADE，但注意 `deleteSource+deleteOrphans` 的"共享 pattern 行"语义：一条规则可被多源引用，CASCADE 只删关联不删主行的行为已内建）。source 表主键 `(ruleId,source)` + IGNORE 插入 + `-1 回查 id` 的去重协议（AllowRuleDao.kt:74-133）是订阅增量更新的地基，须原样翻译。
2. **迁移现状不可照搬**：`fallbackToDestructiveMigration(true)`（三库同）意味着历史上有静默清库风险；Flutter 侧应保留 `onDestructiveMigration→用户提示`（现仅 AppDatabase 有，AppDatabase.kt:154-157）。2→3 美化规则的 `LIKE '%#@#%'` 回填对 `#$@#` 误判（§2.4）应以词法重做。
3. **必须保持字节格式的文件**：`domain/{block,block.important,allow,allow.important}.trie`（DTRI，Go `G:policy_dtri_reader.go:10-15` 硬校验 magic `0x44545249`/version 1/头 36B/节点 12B/边 12B，BIG-ENDIAN，双 FNV bloom 7 哈希）——只要 Flutter 仍复用 Go AAR 做数据面，该格式与 `filesDir/rule-index/...` 相对路径（RuleIndexLayout.kt:29-37）就是 ABI。`hosts/rewrite.trie`（DRWI）与 `*.bloom`/原生 trie 格式**不跨语言**（Go 不读 DRWI；`SetTries/SetImportantTries/CheckDomainInTrieFile/CompileFilterList*` 经双向 grep 无任何 Kotlin/Go 生产调用者，属 legacy 平行实现，重构时可整块剔除——`G:engine_rules.go:16,112`、`G:rule_compiler.go:25,42`）。
4. **仅 Kotlin 消费 vs 双端消费切分**：域名五桶+特殊规则 =双端（Kotlin DomainPolicy 兜底 + Go 快照/trie）；覆写 IP/CNAME =双端语义但 **Go 是执行者**（Kotlin 只做导出与 express 之外的辅助查询）；URL 规则/美化规则 =**Go 独占执行**（Kotlin 仅存储+序列化）；DNS 阶段阻断响应 =normal/server 由 Go 合成、express 由 Kotlin 合成——四套实现（含 `engine_dns.go` NODATA 退化缺陷、`ZERO_ADDRESS↔CUSTOM_IP` 与 `.name` 两套字符串协议）在 Flutter 重构成单一策略函数时需**以修复后的语义为准，而非现状对齐**。
5. **前缀即契约**：`sub_<id>`/`staging_sub_<id>`/`preset`/`useradd`/`local_import`/`local_hosts` 六个源标签被 5 个 DAO 的 LIKE/GLOB 查询、快照导出、统计聚合、清理与恢复逻辑依赖（§5.3）；DTRI 内嵌 source 名亦入字节流。改名=跨语言+跨表事故。
6. **死代码可剔除清单**（双向 grep 确证）：`RuleUpdateNotifier` 整类；`SubscriptionUrlHelper.countRules`；`SubscriptionKind.isCanonical`；`CategorizedRuleStreamImporter.importTwoPass`（仅测试）；`CosmeticRuleManager.compileAllToCss*`；`DynamicBlockResponseTracker`（Go 已代实现）；`RuleIndexLayout.deleteAll`、`allScopeDirectories`；`AllowRuleDao.kt:12` 私有常量；Go `rule_compiler.go` 全文件与 `engine_rules.go` 原生 trie 路径（见第 3 条）。`RewriteRuleManager.answersFor` 唯一调用方 `DnsQueryFilter.rewriteAnswersFor` 再无调用者——三源合并精确查询在生产不可达（覆写走导出 JSON），保留该实现与否属重构决策，本档只记现状。
7. **并发纪律**：缓存换装用"判异性 close 旧索引"（BlockRuleCache.kt:63-68）与 Go 端 2s 延迟释放（policy_engine.go:427-431）配对；mmap 文件原子替换（tmp+rename）；DnsCacheDao 的 update→insertIfAbsent 组合规避了 SQLite UPSERT 的版本下限（DAO :40-55 注释），drift 同库同 API 面下仍受 minSdk24 设备 SQLite 版本影响，保留该写法。
8. **调度面**：WorkManager 唯一名六+一（周期 3、retry 3、manual 1）与 dataset×约束（仅 CONNECTED、无充电）需映射到 Flutter 侧等价持久调度；`APPEND_OR_REPLACE` 串行队列 + Mutex/AtomicInteger 让路协议（§5.4）是无 GC 竞品的行为规格，测试基线应包含"手动在途时自动整体放弃并 retry"。
9. **RuleOperationWorker.kt 实测 570 行**，超本项目 550 行红线（AGENTS.md 首条），重构时应自然拆分。
