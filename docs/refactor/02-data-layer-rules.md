# 02 数据层与规则引擎（一）：Room 全库、迁移、规则模型与语法

```yaml
所属系列: DITING Android Flutter 重构功能图谱 | 章: 02 | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测
```

> 续篇：[02-data-layer-rules-2.md](02-data-layer-rules-2.md)（匹配与索引算法、订阅体系、数据清理、引证表、Flutter 重构注意）。
> 路径缩写：`K:` = `Android/app/src/main/java/com/haoze/diting/`，`G:` = `Android/tunnel/`。

## 1. 概述

本域 = Room 数据层（`data/` 实测 50 个 .kt：根 8 + entity 20 + dao 16 + repository 5 + cleanup 1）+ 规则引擎核心（`core/rule/` 实测 42 个 .kt，本会话全部逐行读完）+ 订阅体系（含在 core/rule 的 12 个 Subscription*/Categorized* 文件）。

- **三库隔离**：`AppDatabase`（NORMAL，VPN 全隧道）、`ExpressRulesDatabase`（EXPRESS，纯 Kotlin DNS）、`DnsRulesDatabase`（DNS_MODE/服务器局域网 DNS），三实例均为双检锁单例，WAL 模式，`fallbackToDestructiveMigration(true)`。实体/DAO 类三库复用，数据文件完全独立（`K:data/DnsRulesDatabase.kt:28-34` 注释明示"永不迁移数据"）。
- **规则五类**：域名规则（block/allow）、覆写规则（rewrite：IPv4/IPv6/CNAME）、URL 规则（go_url_rule，交 Go 引擎）、美化规则（cosmetic，元素隐藏 CSS，交 Go MITM）、应用规则（appScope 修饰，内嵌于域名规则字段）。
- **两级匹配架构**：Kotlin 内存缓存（BlockRuleCache/AllowRuleCache + mmap 的 DTRI 前缀树索引）计算快照 → JSON 快照 + DTRI 文件路径交给 Go policyEngine（normal/server）；express 纯 Kotlin 直接查同一套缓存。
- **订阅体系**：OkHttp 下载→临时文件→badfilter 预扫→流式分型入库（staging 源标签）→事务提升；自动更新由 WorkManager 周期任务（按 dataset 三套唯一名）驱动，手动/自动经互斥协调器让路。

## 2. 数据库全表

### 2.1 AppDatabase（`K:data/AppDatabase.kt`，文件名 `diting_database`，version=3，exportSchema=false）

20 实体全集（`@Database entities` 实测 20 项，:92-113）。

| 表名 | Entity | DAO | 用途 | 关键字段/索引 |
|---|---|---|---|---|
| dns_cache | DnsCacheEntity | DnsCacheDao | Go/Kotlin 解析结果持久缓存 | PK `key`；response BLOB；索引 expiresAt/lastHitAt/queryName/(queryType,expiresAt)（entity:10-15）；hitCount `@ColumnInfo(defaultValue="0")`:25 |
| dns_log | DnsLogEntity | DnsLogDao | DNS 查询流水 | result=PASSED/BLOCKED/ERROR(+REWRITTEN 写入方)，blockSubscriptionId、packageName；6 个索引（entity:16-23） |
| dns_race_log | RaceLogEntity | RaceLogDao | 竞速解析记录（仅真实发出 DoH 的请求） | strategy/winner/selectedProviderId+timestamp 复合索引 4 个（entity:13-18） |
| bootstrap_log | BootstrapLogEntity | BootstrapLogDao | Bootstrap IP 探活日志 | ipId/success+timestamp 索引（entity:9-13） |
| block_rule | BlockRuleEntity | BlockRuleDao（实测 70 个函数声明） | 黑名单域名规则 | pattern/rawLine/groupName/important/appScope(竖线分隔包名)/appInverted/isWildcard/denyallow/isRegex/dnsType；唯一索引 (pattern,important,appScope,appInverted,dnsType,isRegex) + appScope（entity:19-23） |
| block_rule_source | BlockRuleSourceEntity | 同上 | 规则↔来源多对多 | PK(ruleId,source)，FK→block_rule CASCADE，索引 source（entity:7-19） |
| allow_rule / allow_rule_source | AllowRuleEntity / AllowRuleSourceEntity | AllowRuleDao（实测 73 个函数声明） | 白名单，结构同 block（含 important/denyallow/dnsType/isRegex；entity:18-39） | 同上；source 表 FK CASCADE（allow_rule_source:10-16） |
| subscription | SubscriptionEntity | SubscriptionDao | 订阅元数据 | url+kind 唯一索引、groupId 索引（entity:7-13）；ETag/LastModified/ruleSetHash/lastAttemptAt/consecutiveFailureCount/mirrorTemplate/mirrorFallback/importState/importError |
| subscription_group | SubscriptionGroupEntity | SubscriptionGroupDao | 订阅分组 | name 唯一；autoUpdateEnabled |
| subscription_auto_update_item | SubscriptionAutoUpdateItemEntity | SubscriptionAutoUpdateDao | 自动更新批次明细 | PK(batchId,subscriptionId)，FK→subscription CASCADE，索引 subscriptionId/(batchId,status) |
| http_request_log | HttpRequestLogEntity | HttpRequestLogDao | HTTPS/MITM 请求流水（仅 NORMAL 库有） | outcome/authority/blockSubscriptionId；4 索引（entity:9-17） |
| rewrite_rule | RewriteRuleEntity | RewriteRuleDao | DNS 覆写规则 | 唯一索引 (pattern,targetType,targetValue)（entity:14）；targetType∈{IPv4,IPv6,CNAME}（RewriteTargetType:8-12）；同文件含 rewrite_rule_source |
| rewrite_rule_source | RewriteRuleSourceEntity（定义在 `K:data/entity/RewriteRuleEntity.kt:25-42`） | 同上 | 覆写规则来源 | PK(ruleId,source)+FK CASCADE+source 索引 |
| mirror_template | MirrorTemplateEntity | MirrorTemplateDao | 订阅镜像 URL 模板 | name 唯一 |
| go_url_rule / go_url_rule_source | GoUrlRuleEntity / GoUrlRuleSourceEntity | GoUrlRuleDao | URL 前缀规则（kind=block/allow；entity:21-24） | 唯一索引 (pattern,kind)；source FK CASCADE |
| cosmetic_rule / cosmetic_rule_source | CosmeticRuleEntity / CosmeticRuleSourceEntity | CosmeticRuleDao | 元素隐藏 CSS 规则 | 唯一索引 (domain,selector,isException)（entity:18-21）；**cosmetic_rule_source 无外键**（实测该文件 ForeignKey=0），靠手工 deleteSourcesByRuleId 维护 |
| app_traffic_daily | AppTrafficDailyEntity | AppTrafficDao | 分应用日流量累计（仅 NORMAL 库有） | PK(date,package_name)，UPSERT 用 `ON CONFLICT DO UPDATE`（dao:48-56，需 SQLite≥3.24，见 §6.3 注） |

配置：WAL（:145）；`onOpen` 执行 `PRAGMA synchronous = NORMAL`（:149-152）；`onDestructiveMigration` 置 `SystemSettingsStore.setDataResetNoticePending`（:154-157）——三库中只有 AppDatabase 有此回调。

接口面：`RuleDataSources`（9 个规则 DAO getter）与 `DnsRuntimeDataSources`（4 个日志/缓存 getter），定义在 `K:data/RuleDataset.kt:34-57`。`RuleDatabases.forDataset/forDatasetDb/runtimeForDataset`（`K:data/DnsRulesDatabase.kt:134-153`）按 dataset 路由；**注意 `runtimeForDataset(DNS_MODE)` 回落到 AppDatabase**（:151）——服务器模式自身规则库不含 4 张运行日志表。

### 2.2 ExpressRulesDatabase（`K:data/ExpressRulesDatabase.kt`，文件名 `diting_express`，version=2）

18 实体 = AppDatabase 全集去掉 `http_request_log` 与 `app_traffic_daily`（类注释 :39-46 明示"Explicitly excludes"，与 entities 数组实测一致）。复用同一批 DAO。WAL + destructive fallback（:111-113）。

### 2.3 DnsRulesDatabase（`K:data/DnsRulesDatabase.kt`，文件名 `diting_dns_rules`，version=3）

14 实体 = 9 类规则表全对（block/allow/rewrite/goUrl/cosmetic 主表+source 表共 10）+ subscription/subscription_group/subscription_auto_update_item/mirror_template；**无任何日志/缓存/流量表**（entities 数组 :81-96 实测 14 项）。WAL + destructive fallback（:124-126），无 onOpen/onDestructive 回调。

### 2.4 迁移与升级策略（逐条）

| 库 | 版本路径 | 迁移对象 | 内容 |
|---|---|---|---|
| AppDatabase | 1→2 | MIGRATION_1_2（`K:data/AppDatabase.kt:46-73`） | CREATE TABLE cosmetic_rule / cosmetic_rule_source + 各自索引（IF NOT EXISTS） |
| AppDatabase | 2→3 | MIGRATION_2_3（:75-89） | `ALTER TABLE cosmetic_rule ADD COLUMN isException INTEGER NOT NULL DEFAULT 0`；`UPDATE ... SET isException=1 WHERE rawLine LIKE '%#@#%'`；删旧唯一索引 (domain,selector)、建 (domain,selector,isException) |
| DnsRulesDatabase | 1→2 / 2→3 | DNS_RULES_MIGRATION_1_2 / 2_3（`K:data/DnsRulesDatabase.kt:39-78`） | 与 App 同名迁移逐字重复一份（代码不复用，属可整合重复） |
| ExpressRulesDatabase | 1→2 | EXPRESS_MIGRATION_1_2（`K:data/ExpressRulesDatabase.kt:47-57`） | 仅 isException 步（Express v1 建库即含 cosmetic 表）；当前 version=2 |
| 三库共同 | 任意未覆盖版本差 | `fallbackToDestructiveMigration(true)` | 未注册迁移直接**整表销毁重建**：App 仅在 onDestructiveMigration 提示数据重置；Express/DnsRules 静默销毁 |

回退策略：无 downgrade 迁移（Room 未配置），回退旧 APK 依赖 exportSchema=false 下不受影响的旧 schema 文件；2→3 迁移把旧数据全标 `isException=0`（hide 规则），`#@#` 行通过 rawLine LIKE 回填——LIKE 匹配 `%#@#%` 对含 `#$@#` 的行同样命中（`#$@#` 内含 `#@#`? 不含——`#$@#` 字符序列为 # $ @ #，不含子串 `#@#`），故 **`example.com#$@#sel` 迁移后被标成 hide 而非 exception**。此判据已按发生路径走查，属迁移精度缺口（Flutter 侧重建时须以分隔符词法而非 LIKE 判定）。【待定：现网是否存在含 `#$@#` 的订阅源】

## 3. 规则模型与语法

解析总线：`AdGuardRuleParser.parseCategorizedLine`（`K:core/rule/AdGuardRuleParser.kt:177-199`）——顺序：忽略行（`!`/注释/`[Header]`，:179-182；`#` 开头但含美化分隔符者不算注释 :217-218）→ dnsmasq（`address=/`、`server=/` 前缀 :186-188）→ hosts（:191-194）→ AdGuard/ABP/纯域名（:197-198 交 `AdblockRuleLineParser.parseAdblockOrDomainLine`）。

### 3.1 域名规则（block/allow）

存储：`block_rule`/`allow_rule` + source 表；pattern 为归一化域名（IDN→ASCII 小写，`K:core/rule/AdGuardDomainUtils.kt:70-84`；通配保留 `*`/`_` :86-102）。

| 语法 | 示例 | 判据（文件:行） |
|---|---|---|
| `||domain^` 托管域 | `||ads.example.com^` | AdblockRuleLineParser.kt:244（去 `||`、`^`） |
| 裸域名 | `ads.example.com` | :246（trimEnd `^`），归一 :250-254 |
| `@@` 例外(allow) | `@@||example.com^` | 前缀探测 AdGuardRuleParser.kt:197；剥壳 AdblockRuleLineParser.kt:66 |
| `$important` | `||x.com^$important` | :124 |
| `$app=pkg1\|pkg2` | `||x.com^$app=com.a\|com.b` | :132-143（`|` 分割、逐段可带 `~`，任一 `~` → appInverted） |
| `~app=` / `app=~pkg` | `||x.com^~app=com.a` | :133-138 同分支（isNegativePrefix 或 per-item `~`） |
| `$denyallow=d1\|d2` | `||cdn.com^$denyallow=ok.com` | :144-156（每项 normalize） |
| `~denyallow=` | `||x^~denyallow=y.com` | :128-131 **修饰符丢弃、规则保留**（注释记录历史缺陷） |
| `$dnstype=A\|AAAA`、`~dnstype=` | `||x^$dnstype=MX` | :157-174；合法类型表 AdGuardDomainUtils.kt:12-14（A,AAAA,CNAME,HTTPS,SVCB,TXT,MX,PTR,SRV,SOA,NS,ANY,CAA,DS,DNSKEY）；`~` 前缀存为 `"~T1\|T2"` |
| 正则域名规则 | `/ads[0-9]+\.example/` | :73-97（首末 `/` 抽取、`Regex()` 试编译 :78；尾随非 `$` 判 invalid :84-85） |
| 行尾注释 | `||x.com^ # note` | :57-64：`#` 须行首或前随空白才开注释；正则字面量体内跳过（commentSearchStart :34-42）——A-095 定案语义 |
| `||x.com^##banner`（`#` 粘连图案） | — | :61-63 判 unsupported（不截断为全域屏蔽） |
| `$badfilter` | `||x.com^$badfilter` | :201 + AdGuardRuleParser.kt:69-77（预扫全文收集 key）、:133-158（剔除 block/allow/rewrite 命中 key） |
| `$all` / `$empty` | — | :205-207 视作无操作 |
| Web-only 修饰符 34 token + 20 前缀 | `$script`、`$domain=`、`$redirect=`… | :202-204 → AdGuardDomainUtils.kt:16-38 整行 ignoredCount=1 |
| 未知修饰符 | `$foo` | :208 unsupportedCount=1 |
| `|` 锚定（单竖线） | `\|\|x` 之外的 `\|http…` 域名式 | :245 unsupported |

运行时匹配：Kotlin `BlockRuleMatcher`/`AllowRuleMatcher`（见续篇 §4）；normal/server 经快照同步 Go。

三模式生效性：
- **normal**：生效（Go `ApplyRuleSnapshot`，`K:normal/GoTunnelRuleManager.kt:43-49` + Kotlin 域检查回调双路）。
- **express**：生效（`K:express/ExpressTunnelManager.kt:330-341` ruleEvaluator→DomainPolicy），但 `packageName=null`（:331）——正向 appScope 规则永不命中（findAppMatch 需包名），**反向 `~app=` 规则当包名未知时命中**（BlockRuleMatcher.kt:149-151 `packageName == null || !in excluded`）。且仅 A/AAAA 查询过规则（ExpressDnsEngine.kt:96 isAddressQuery）。
- **server**：同 express——`K:server/backend/DnsQueryFilter.kt:93` `evaluate(domain, packageName = null)`；快照 trie 路径传 null（:98 `buildRuleSnapshotJson(null)`），Go 端仅吃 JSON 列表部分。

### 3.2 URL 规则（go_url_rule）

语法判据（域名规则总线内）：`AdblockRuleLineParser.isUrlOrPathRule`（:324-342）——`http(s)://…`、`|http(s)://…`、`||domain/path`（去 `||` 后含 `/`）、`*/path`（len>2）、`/path`（不以 `/` 结尾且 len>2）；净化 `cleanUrlPattern`（:344-346 去 `||`/`|`/`^`）。allow 版带 `@@`。badfilter 键 `url_block:<pattern>:<appScope>` / `url_allow:…`（:218-219；消费 CategorizedRuleStreamImporter.kt:279,291）。

手工录入的第二套窄语法：`GoUrlRuleManager.parse`（`K:core/rule/GoUrlRuleManager.kt:41-54`）只收**完整 http(s) URL 字面量**（拒绝 `*`、`$`、userInfo、fragment；省略默认 80/443 端口），kind=block/allow。

存储：`go_url_rule(+_source)` 三库皆有表。**但推送只有 normal**：`K:normal/GoTunnelRuleManager.kt:101-107` `engine.setRequestRules(jsonSnapshot)`；server 的 `DnsServerEngine.syncRules()`（`K:server/backend/DnsServerEngine.kt:113-120`）只推 snapshot/rewrite/blockResponseType，不推 URL 规则；express 无任何 GoUrlRuleManager 引用（本会话 grep `express/` 域 GoUrl 命中 0）。
Go 语义：`G:engine_request_filter.go:17-20` 结构仅 `{pattern,kind}`（appScope 不传输）；`:22-41` 小写+要求 http(s):// 前缀否则丢弃；`:43-69` 对 `scheme://host+path` 做**最长前缀匹配，等长时 allow 胜出**；无 URL 命中才回落域名策略（:71-77）。
三模式生效性：normal=生效；express=**存而不生效**（有表可导入，无推送无本地评估点）；server=**存而不生效**（同）。

### 3.3 覆写规则（rewrite_rule）

语法（产出 RewriteRule 的通道）：
- `$dnsrewrite=`：AdblockRuleLineParser.kt:175-200——`NXDOMAIN/REFUSED/SERVFAIL` 或 sinkhole（`AdGuardDomainUtils.kt:10` {0,0.0.0.0,127.0.0.1,::,::1}）→ 降级为 **block** 规则（:185-186 → :275-277）；IP 字面量→IPv4/IPv6（:187-192）；域名→CNAME（:193-199）；`;` 多值取策略名或末值（:178-181）。
- dnsmasq `address=/dom/ip`、`server=/dom/ip`：HostsAndDnsmasqParser.kt:7-92（sinkhole→block :28-47；IP→IPv4/IPv6 :49-70；域名→CNAME :72-89；多域名 `address=/a.com/b.com/1.2.3.4` 由 split('/') dropLast 支持 :21-25）。
- hosts `IP domain…`：:94-139（sinkhole 行→block，否则每域名一条 rewrite）；真实 IP 手工导入通道 `parseHostsRewriteLine`（:141-155，sinkhole 直接返回空）。
存储：`rewrite_rule(+_source)` 三库皆有；唯一键 (pattern,targetType,targetValue)；业务约束：CNAME 与 IP 互斥（RewriteRuleManager.addRule/editRule 用 countType/countOtherTypes 拦截，`K:core/rule/RewriteRuleManager.kt:115-124,201-223`）。
运行时：`answersFor(domain)`（:106-113，mmap 索引+fallback+manual 三源合并）、`ipRewrites()`/`cnameRedirects()`（:73-100，manual 最后写入压过订阅）。
三模式生效性：
- normal：`K:normal/GoTunnelRuleManager.kt:95` `engine.setRewriteRules`（Go 语义 `G:engine_config.go:79-105`：JSON map 域名→单值或数组；IPv4/IPv6 在 DNS 阶段应答，CNAME 供 MITM 重定向）。
- server：`K:server/backend/DnsServerEngine.kt:118` `setRewriteRules(filter.buildRewriteRulesJson())`（合并逻辑 DnsQueryFilter.kt:104-113：IP 数组优先，CNAME 仅当该域无 IP 目标）。
- express：**未发现评估点**（本会话 grep express/ 仅 ExpressDefaultsSeeder.kt:102 建索引与配置传输/UI 文案，`express/engine/` 命中 0）；判定"极速模式覆写规则不参与解析"。【待定：是否属功能缺口或在别章（08）补】

### 3.4 美化规则（cosmetic_rule）

语法：分隔符表 `COSMETIC_DELIMITERS = ["#$@#","#@#","##","#?#","#$#"]`（AdblockRuleLineParser.kt:14，长者优先注释 :7-13）；`#@#`/`#$@#`→isException（:289）；`domain1,domain2##selector` 逗号分域（:307-311）；行首 `##.ad` 全域规则因 :21-22 先于注释判定而保留。`ParsedCosmeticRule.toCss()`（AdGuardRuleModels.kt:35）仅诊断用。
存储：`cosmetic_rule(+_source)`；source 表无 FK（实测）。
运行时：`CosmeticRuleManager.buildScopedCssJson`（`K:core/rule/CosmeticRuleManager.kt:34-70`）→ globalHide/globalException/domains{hide,exception}，全局 hide 吞并同选择器的 scoped hide（:53-56,63）；推送 `K:normal/GoTunnelRuleManager.kt:114-120` `engine.setCosmeticRules`（Go：`G:engine_mitm.go:228-230` → `G:mitm_cosmetic_inject.go` 注入）。
三模式生效性：仅 normal。express/server **硬拒**：`cosmeticRuleRejection`（`K:core/rule/CosmeticRuleSupport.kt:22-25`，EXPRESS/DNS_MODE 返回拒绝文案"仅普通模式支持"），调用点 `K:ui/BlacklistViewModel.kt:303,395`、`K:ui/WhitelistViewModel.kt:312`、`K:ui/batch/BatchRuleClassifier.kt:100`、`K:ui/batch/BatchRuleEntities.kt:92`。注：订阅流式导入路径（CategorizedRuleStreamImporter）不经该闸门，仍会向 express/DnsRules 库写 cosmetic 行（Importer:208-230 按 dao 非空即写）——存而不生效。

### 3.5 应用规则（appScope）

非独立表：block/allow 行的 `appScope`（`|` 分隔小写包名）+ `appInverted` 字段（entity:32-33）。`~` 语义双实现：分桶正向规则进 AppBucket、反向规则进 inverted 列表（BlockRuleCacheLoader.kt:145-159）。订阅侧特殊规则（regex/denyallow/dnstype 带 appScope）走 specialRules 线性表（Loader:124-140）。查询侧包名来源与三模式生效性同 §3.1（express/server 传 null，仅反向豁免生效）。另有一套**独立于规则库的应用控制**（排除名单/分应用白名单等，SharedPreferences `AppRulesSettingsStore`，经 `RuntimeDnsSettingsRefresher.refreshAppExclusions/refreshAppAllowlist` 直达 Go，属 06/09 章），本域仅在清理函数签名中出现（`K:data/cleanup/DataCleanupManager.kt:392-397`）。

### 3.6 预设白名单（preset）

`DefaultWhitelistSeeder`（`K:core/rule/DefaultWhitelistSeeder.kt`）：assets `https_passthrough.txt` → allow_rule(source="preset", groupName=注释标题分类 :119-156)；播种代际门 = versionCode*1000 + PRESET_SCHEMA_VERSION(=2)（:20,33-64）；空解析绝不删旧（:81-111 + :168-169 双保险）。Express 版由 `K:express/ExpressDefaultsSeeder.kt:93` 复用同一 asset 解析写 Express 库。source 常量：`preset`/`useradd`/`sub_<id>`/`staging_sub_<id>`/`local_import`/`local_hosts`（RuleOperationWorker.kt:565-566 等）。
