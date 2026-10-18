---
所属系列: DITING Android Flutter 重构功能图谱
章: 13
最后校验: 2026-10-18
口径: 数字均为本会话工具实测（find/grep/python 逐文件统计，未运行任何构建或测试）
基线: main @ dda2779, v1.4.3 / versionCode 10403
---

# 13 测试规格库与资源清单（上篇：规模 · 基建 · core/express 编目）

> 本篇把 `Android/app/src/test` 的 99 个 Kotlin 测试与 `Android/tunnel` 的 21 个 Go 测试当作**行为规格库**编目：测试期望值是 Flutter 重写的权威来源，优先级高于任何文档描述或臆测。
> 续篇：`13-tests-and-assets-2.md`（其余包编目 · 覆盖空白图 · Go 编目 · 资源与备份 · Flutter 注意）。

## 1. 规模实测

| 指标 | 实测值 | 口径 |
|---|---|---|
| Kotlin 测试文件 | **99** | `find Android/app/src/test -name "*.kt" \| wc -l` |
| Kotlin 测试总行数 | **11 394** | `find ... -exec cat {} + \| wc -l`（含空行，未裁剪） |
| `@Test` 注解总数 | **585** | `grep -rc "@Test"` 求和；与逐文件函数名解析结果一致（585） |
| `import com.haoze.*` 行数 | **207** | 被测类跨包引用密度 |
| `runBlocking` 出现 | **96** 次 / 14 个文件 | 协程式断言，非 `kotlinx-coroutines-test` |
| `import org.junit.*` | **382** 行 | 全部 JUnit4 |
| androidTest 源集 | **不存在** | `ls Android/app/src` 只有 `main` `test` → 无仪器化测试、无 Room/Robolectric |
| Go 测试文件 | **21**（3 834 行） | `find Android/tunnel -name "*_test.go"` |
| Go 非测试代码 | **64** 文件 / 13 872 行 | 测试代码占 Go 侧 LOC 21.6% |
| main 侧 Kotlin 文件 | **522** | `find Android/app/src/main/java -name "*.kt"` |

按测试目录分包（文件数 / 行数，和为 99 / 11 394）：

```
core 27/3288   ui 22/2268   express 17/2449   server 5/723   util 5/594
notification 5/588  normal 5/358  crash 4/388  update 4/231
data 2/268  permission 2/190  main 1/49
```

最大 6 个测试文件：`AdGuardRuleParserTest.kt` 407、`ExpressPacketCodecTest.kt` 388、`DnsModeTest.kt` 350、`ExpressRoomDnsCacheTest.kt` 327、`BatchRuleAppScopeAndUrlNormalizationTest.kt` 319、`BatchRuleValidatorTest.kt` 302。最短：`HiddenFeatureStructureTest.kt` 26、`AppUpdateManagerTest.kt` 29、`TrafficStatsManagerSessionResetTest.kt` 34、`WorkModeTest.kt` 36、`BlockRuleCacheTest.kt` 39。

## 2. 测试基建（实测依赖，非推测）

`Android/app/build.gradle.kts:234-235` 只有两行测试依赖：

```kotlin
testImplementation(libs.junit)   // junit 4.13.2  → libs.versions.toml:14,36
testImplementation(libs.json)    // org.json:json（供 HealthStoreJson/CosmeticRuleManager 直测）
```

- **无** MockK / Mockito / Robolectric / Truth / `kotlinx-coroutines-test` / JUnit5 / `@Parameterized` / `assertThrows`（逐项 grep 全测试源集，命中 0；唯一提及 Robolectric 的是 `HealthStoreJsonTest.kt:17` 注释，说明「单测类路径没有 Robolectric」）。
- 协程断言一律 `kotlinx.coroutines.runBlocking` 包体；并发用例用 `ConcurrentHashMap` + 多协程手写（`ExpressRoomDnsCacheTest.kt:226 testConcurrentPutAndGet` 20 键、`DnsLoggerTest.kt:105 testConcurrentBurstLogging`）。
- 时间/时钟全部靠**注入 now 参数**（`LogMaintenance.trafficCutoffDate(retentionDays, nowMillis = 1_700_000_000_000L)`、`HealthSnapshotMath.applySample(..., now = 1_000L)`），无时钟桩框架。
- 超时保护仅 1 处：`MarkdownBlockTest.kt` 3 个 `@Test(timeout = 2000)`（防解析死循环）。

### 2.1 Fake / helper 清单（被测 Room DAO 全部手写假实现）

| helper | 位置 | 形态 |
|---|---|---|
| `FakeDnsCacheDao` | `core/cache/DnsResponseCachePersistenceTest.kt:26`；另一份 `express/ExpressRoomDnsCacheTest.kt:23` | 实现 `DnsCacheDao` 接口，`ConcurrentHashMap<String,DnsCacheEntity>` 存储；前者带 `applyPendingWrites` 与可插拔挂起点（`:30` 注释「Suspension hook used to interleave a `clear()` with an in-flight write」） |
| `FakeDnsLogDao` | `core/log/DnsLoggerTest.kt:22` | 记录 `inserted` 列表 |
| `FakeSubscriptionAutoUpdateDao` | `core/rule/SubscriptionAutoUpdateEngineTest.kt:14` | 记录状态项 |
| `FakeCache` | `express/ExpressDnsEngineTest.kt:28` | 实现 `ExpressDnsEngine.ExpressDnsCache` |
| `ThrowingRaceLogDao` / `RecordingRaceLogDao` | `core/log/LogWriterFailureIsolationTest.kt:32 / :52` | 注入插入异常 |
| `ThrowingHttpRequestLogDao` | 同上 `:78` | 同上 |
| `Proxy.newProxyInstance` 动态代理 | `CategorizedRuleStreamImporterTest.kt`、`SubscriptionImportRecoveryStagingTest.kt:28`、`DataCleanupManagerTest.kt:25`、`BatchRuleAppScopeAndUrlNormalizationTest.kt:45`、`BatchRuleValidatorTest.kt:25` | 5 个文件用 JDK 动态代理造 `RuleDataSources` / DAO 族并断言「哪些方法被调用过」 |
| `private fun zone()/localDayIndex()` | `util/DateTimeUtilsTest.kt:33,36` | 测试内自带日历算法作为交叉预言 |

**Flutter 注意**：所有 Room DAO 假实现与 JDK 动态代理都是「按接口方法名记账」的规格，迁移时应翻译为 Dart 侧 `Fake`/`Mock`（`package:test` + `mockito`），接口方法清单本身就是 DAO 契约。

### 2.2 源码文本契约测试（Flutter 重写时必须丢弃或改写）

以下测试把**被测源码当文本读**（`java.io.File` + `readText()`），断言的是 Kotlin 代码形状而非运行行为；且当工作目录不对时**直接 return 静默通过**（`if (source.isBlank()) return` 共 **9 个文件 / 32 处**，另有 2 个文件用 `?: return` / `if (!asset.exists()) return` 同型守卫）：

| 文件 | 被测文本 | 守卫数 |
|---|---|---|
| `notification/AppNotificationChannelsRegistryTest.kt:28,37` | `AppNotificationChannels.kt` + `RuleOperationWorker.kt` | 6 |
| `ui/settings/RewriteCnameDeliveryTest.kt:22-26` | `server/backend/DnsQueryFilter.kt` **与 `../tunnel/engine_standalone.go`** | 4 |
| `ui/WhitelistEditDemotesPresetSourceContractTest.kt:27` | `WhitelistViewModel.kt` + `DefaultWhitelistSeeder` | 4 |
| `notification/NotificationSettingsIntentFallbackTest.kt:22` | `NotificationPermissionHelper.kt` | 4 |
| `data/cleanup/DataCleanupCustomBackgroundContractTest.kt:20` | `DataCleanupManager.kt` / 外观 store | 4 |
| `ui/RaceModeMessageLocalizationTest.kt:23` | `RaceModeSettingsViewModel.kt` | 3 |
| `core/WorkModeLifecycleRegistryPrefsTest.kt:23` | `WorkModeLifecycleRegistry.kt` | 3 |
| `ui/LogRetentionCrashCountRefreshContractTest.kt:19`、`crash/CrashLogManagerStateTest.kt:23` | 对应源码 | 各 2 |
| `normal/GoTunnelLogProcessorUpstreamTtlTest.kt:57` | `Android/tunnel` 内 Go 聚合器的 `json:"ttl"` tag（禁止 `omitempty`） | 存在性判断 |
| `core/rule/DefaultWhitelistSeederPresetTest.kt:45` | 读 `src/main/assets/https_passthrough.txt` | `if (!asset.exists()) return` |

> 这类测试是「文档难描述」行为的**唯一载体**（如「CNAME 覆写不受广告屏蔽总开关门控」），但它们钉的是当前实现写法，不是输入→输出。Flutter 侧不可移植，须改为在 Dart 层用真实调用序重述，否则该行为规格将随源码重写而消失。

## 3. Kotlin 测试编目 · core（27 文件 / 3 288 行 / 176 个 `@Test`）

| 测试文件:行 | 被测对象 | 覆盖的行为点（逐条，函数名原文） | 关键期望值常量 |
|---|---|---|---|
| `core/WorkModeLifecycleRegistryPrefsTest.kt:21` | `WorkModeLifecycleRegistry`（源码文本） | `theDeadPreferencesFileIsNoLongerWritten`；`theForegroundStateIsStillForwardedToTheRunningService`；`theRealStoreUsesTheDnsVpnPreferencesFile` | 禁止 `"system_settings"`+`getSharedPreferences` 共存；真 store = `dns_vpn_prefs`；键 `main_activity_foreground`（O-145） |
| `core/cache/DnsResponseCachePersistenceTest.kt:24` | `DnsResponseCache`（批量写路径） | `recordResolvedThenFlushCreatesRow`；`hitsAreCoalescedIntoCount`；`metadataRefreshDoesNotClobberHitCount`；`clearingThroughControllerDropsPendingWrites`；`hitWithoutResolvedRowUpdatesNothing`；`clearDuringFlushDoesNotResurrectRows`；`clearBeforeFlushDropsTheWholeBatch`；`explicitZeroTtlIsNeverCached`；`unknownTtlStillFallsBackToPolicyMaximum` | 新建行 `hitCount==0`(:146)；5 次命中合并为 `hitCount==5` 且 `dao.hitCount==0`(:158,160)；刷新后 3→5(:171,178)；clear 竞态后 `storage.size==0`(:189,196,243,256) |
| `core/diagnostic/HealthEngineRegistryTest.kt:18` | `ActiveHealthEngineRegistry` | `enginesOfDifferentDatasetsDoNotDisplaceEachOther`；`aLaterEngineOfTheSameDatasetReplacesTheEarlier`；`closingOneDatasetLeavesTheOtherRegistered`；`staleEngineCloseDoesNotEvictTheNewerEngine`；`unregisteredDatasetHasNoActiveEngine`；`everyDatasetSlotIsIndependent`；`identityIsPreservedForTheSameInstance`；`clearIfCurrentUsesIdentityNotEquality` | 按 `RuleDataset` 分槽：`NORMAL`→"normal-engine"、`EXPRESS`→"express-engine"(:26,27)；替换后 `countOf==1`(:39)；**身份语义**：`clearIfCurrent` 必须用 `===`（A-051 同型缺陷，`AGENT_MISTAKES.md` 2026-10-18 条目） |
| `core/diagnostic/HealthSnapshotMathTest.kt:19` | `HealthSnapshotMath`（纯函数） | `successCountsAndMovesLatencyTowardTheSample`；`failureCountsWithoutMovingTheLatencyEstimate`；`firstSampleForAnUnknownProviderStartsFromTheDefault`；`zeroElapsedIsClampedToOneMillisecond`；`consecutiveFailuresStartACooldown`；`successClearsTheFailureStreakAndCooldown`；`failuresBelowTheThresholdDoNotCoolDown`；`decayedCountersTrackEverySample`；`jitterGrowsWhenSamplesVary`；`measuredSamplesProduceDistinctPredictionWeights`；`neverSampledSnapshotFallsBackToNeutralWeight` | `DEFAULT_LATENCY_MS=250.0`、`EWMA_ALPHA=0.25`、`JITTER_ALPHA=0.2`、`COOLDOWN_FAILURE_THRESHOLD=3`、`COOLDOWN_MS=30_000`（`HealthSnapshotMath.kt:13-17`）；200×0.75+400×0.25=250(:56)；elapsed=0→按 1ms 计(:100)；`cooldownUntil==now+30_000`(:114)；无数据 `predictionWeight==1.0`(:198) |
| `core/diagnostic/HealthStoreJsonTest.kt:19` | `HealthStoreJson`（org.json） | `mergeKeepsKeysMissingFromUpdates`；`mergeAddsNewKeysAndReturnsFullSet`；`mergeOverwritesOnlyTheUpdatedEntry`；`mergeOnBlankOrCorruptInputStartsFresh`；`removeDropsOnlyTheRequestedKeys`；`removeMissingKeyIsHarmless`；`replaceProducesExactlyTheGivenEntries`；`parseRootToleratesCorruptAndBlankValues`；`parseRootRejectsNonObjectRoot`；`mergeSurvivesRoundTripThroughString` | `parseRoot(null/""/"   "/"{broken")==0`(:103-106)；非对象根 `"[1,2,3]"`、`"42"`→0(:114,115)；blank/corrupt 起新表后 length==1(:58-65) |
| `core/diagnostic/TunnelDiagnosticsResolverTest.kt:20` | `TunnelDiagnosticsResolver` | `unassignedResolverReportsNotRunning`；`assignedResolverIsActuallyInvoked`；`resolverReceivesDomainAndFamilyPreference`；`parsesUpstreamAnswerWithTtls`；`parsesRewriteSource`；`parsesBlockedSource`；`engineErrorTokenIsTranslated`；`malformedJsonBecomesAnErrorResultRatherThanACrash`；`autoFamilyFallsBackToIpv6OnlyWhenIpv4HasNoAnswer`；`autoFamilyDoesNotQueryIpv6WhenIpv4Answered`；`resolverFailureNeverPropagatesToTheTools` | IP 列表 `["1.1.1.1","8.8.8.8"]`、TTL `[60,120]`(:87,88)；`Source.UPSTREAM/REWRITE/BLOCKED/ERROR`；中文标签 "上游 DNS"(:92)、"覆写规则"(:101)、"Go 隧道未运行"(:122)、"解析结果无效"(:132)；family 调用序列 `[true,false]`(:151) / `[true]`(:169) |
| `core/dns/DnsMessageUtilsTest.kt:10` | `DnsMessageUtils`（普通/服务器共用报文工具） | `nxdomainAndNodataResponses`；`zeroAddressResponses`；`refusedAndMalformedResponses`；`detectsTruncatedDnsResponse`；`rewriteResponsesAnswerIpAndCnameTargets`；`buildQueryConvertsIdnToPunycode`；`rewriteResponseReturnsNullWhenNoTargetFits` | RCODE：NXDOMAIN=3、NOERROR=0、REFUSED=5、SERVFAIL=2(:18,25,48,53)；ID 透传 0x1234/0x1235/0x1236/0x3001；`extractAddressRecords=="0.0.0.0"`(:35)；IDN→`xn--fiq228c`(:90)；长度 `12+expectedQuestionLen`(:98)；应答长度==查询长度(:19,27) |
| `core/dns/DnsProviderIpLiteralTest.kt:14` | `DnsProvider.isIpLiteral / isValidDotHost / isValidDnsHost` | `acceptsIpv4Literals`；`rejectsOutOfRangeIpv4`；`rejectsHostWithPort`；`rejectsHostnames`；`acceptsIpv6Literals`；`rejectsMalformedIpv6`；`dotHostRejectsIpAndPortInput`；`dnsHostAcceptsIpButNotPortInput` | 负例集（**铁律 1「像但不合法」**）：`256.1.1.1`、`1.1.1`、`1.1.1.1.1`、`8.8.8.8:53`、`223.5.5.5:853`、`dns.google:853`、`[::1]:53`、`[2001:db8::1]:853`、`2001:db8::1::2`（双压缩）、`::gggg`、`2001:db8`、`[::1`、`::1]`；正例 `::1`、`::`、`fe80::1%wlan0`、`[::1]` |
| `core/dns/DohUrlParserTest.kt:19` | `DohUrlParser` | `parsesValidDohUrls`；`trimsSurroundingWhitespace`；`returnsNullForNullOrBlankInput`；`returnsNullForMissingScheme`；`returnsNullForUnparseableUrl`；`emptyAuthorityFallsBackToTheFirstPathSegmentAsHost`；`reportsEmptyUrlDistinctlyFromInvalidUrl`；`invalidUrlMessageQuotesTheOffendingValue`；`neverThrowsForAnyInput` | 空 authority leniency：`"https:///dns-query"` → host=="dns-query"（**不得**判非法，A-042）；文案 `"DoH 地址为空"` / `"DoH 地址无效：dns.google/dns-query"`(:79-87)；异常输入表 8 项必不抛 |
| `core/log/DnsLoggerTest.kt:20` | `DnsLogger` + `FakeDnsLogDao` | `testLogModeFiltering`；`testBatchFlushingWhenReachingBatchSize`；`testExplicitFlush`；`testConcurrentBurstLogging`；`testClearAll` | 批量阈值 **50**：未达阈值 `inserted.size==0`(:79)，达阈值 `==50`(:87)，第 50 条 `queryName=="host50.example.com"`(:88) |
| `core/log/LogMaintenanceTrafficRetentionTest.kt:19` | `LogMaintenance.trafficCutoffDate` | `trafficCutoffUsesTheTrafficRetentionWindow`；`trafficCutoffDiffersFromTheLogRetentionWindow`；`trafficCutoffIsMonotonicInRetentionDays`；`defaultRetentionWindowsAreIndependent` | `DEFAULT_LOG_RETENTION_DAYS==7`、`DEFAULT_TRAFFIC_STATS_RETENTION_DAYS==30`（A-014，两窗口必须独立）；单调性用 ISO 日期字典序比较 |
| `core/log/LogWriterFailureIsolationTest.kt:30` | `RaceLogger` / `HttpRequestLogger` | `raceLoggerFlushDoesNotThrowWhenInsertFails`；`raceLoggerKeepsBatchForRetryAfterFailure`；`raceLoggerBatchThresholdFailureDoesNotEscapeLog`；`httpRequestLoggerFlushDoesNotThrowWhenInsertFails`；`httpRequestLoggerBatchThresholdFailureDoesNotEscapeLog` | 写库异常**必须被吞**（不外抛、不丢批次）：`Throwing*Dao` 抛错后断言批次保留可重试 |
| `core/rule/AdGuardRuleParserTest.kt:10` | `AdGuardRuleParser`（规则解析权威） | 21 项：`parseBlockRulesWithModifiers`；`parseAllowRulesWithModifiers`；`parseIgnoresCommentsAndWhitespace`；`wildcardPatternMatching`；`parseDnsrewriteRules`；`parseHostsLines`；`parseDnsmasqLines`；`parseCategorizedMixedText`；`parseAllModifier`；`parseNegativeAppPrefix`；`parseBadfilterAndWebOnlyModifiers`；`badfilterDisablesTargetBlockRule`；`badfilterAllowOnlyDisablesAllowRule`；`badfilterWildcardAndRewriteRules`；`nonMatchingBadfilterDoesNotAffectOtherRules`；`extractBadfilterKeysExtractsExpectedKeys`；`parseDenyallowModifier`；`parseRegexRules`；`parseDnstypeModifier`；`genericCosmeticRulesAreNotTreatedAsComments`；`badfilterWithP1Modifiers` | `||x^$app=a\|b,important`→`appInverted==false`；`$app=~chrome`→`appInverted==true`；`$~app=` 等价反选；`$dnsrewrite=` 目标类型 IPV4/IPV6/CNAME，`NXDOMAIN`/`0.0.0.0` → **blockRules 而非 rewrite**；hosts：`0.0.0.0 域 域`→2 block，`1.2.3.4 域 域`→2 rewrite；dnsmasq `address=/x/`、`/x/0.0.0.0`、`/x/#`→block，`/x/10.0.0.1`→rewrite；badfilter key 字面量集合 `{"block:example.com:false:null:false","allow:allow.com:false:null:false","rewrite:rewrite.com:IPv4:1.2.3.4"}`(:304-307)；`$denyallow=` 空值→`invalidCount==1`；`$dnstype=INVALID_TYPE`→`unsupportedCount==1`；混合文本计数 block 3 / allow 1 / rewrite 3 / cosmetic 1 / ignored 3 |
| `core/rule/AdblockRuleLineParserCosmeticDelimiterTest.kt:13` | 同上（化妆分隔符子域） | `exceptionDelimiterAtRuleIsRecognized`；`exceptionDelimiterDollarAtRuleIsRecognized`；`hideDelimiterStillProducesNonExceptionRule`；`dollarHideDelimiterIsNotTreatedAsException`；`fourCharDelimiterWinsOverTwoCharDelimiter`；`garbageDollarAtLineDoesNotBecomeWholeDomainBlock`；`trailingCommentIsStillStripped`；`isCosmeticRuleLineCoversEveryDelimiter` | `#$#@`(4 字符) 必须优先于 `##`(2 字符)；`$#` 例外型；垃圾 `$@` 行不得退化为全域拦截 |
| `core/rule/AdblockRuleLineParserNegatedModifierTest.kt:18` | 同上（取反修饰符） | `negatedDenyallowKeepsRuleAndDropsExceptions`；`positiveDenyallowStillPopulatesExceptions`；`otherNegatedModifiersKeepTheirOwnSemantics`；`negatedDenyallowDoesNotAffectOtherModifiers`；`emptyNegatedDenyallowIsIgnoredNotReinterpreted` | `~denyallow=`：规则保留、例外清空（与 Go 侧对齐）；空值不得重新解释 |
| `core/rule/AdblockRuleLineParserRegexHashTest.kt:19` | 同上（`#` 词法） | `hashInsideRegexBodyDoesNotTruncateTheRule`；`hashInsideExceptionRegexBodyKeepsTheAllowRule`；`modifiersAfterAHashBearingRegexAreStillRead`；`hashInsideRegexBodyBeforeAModifierListIsNotMistakenForAComment`；`trailingCommentAfterARegexLineIsStillStripped`；`commentAndModifiersAfterAMultiHashRegexAreBothRead`；`unclosedRegexLiteralWithHashIsStillRejected`；`hashOnAPlainDomainLineStillTruncatesOnlyARealComment`；`cosmeticDelimitersStillWinOverTheRegexPath`；`dnsRewriteLineWithATrailingCommentStillParses` | **仅文档难描述**：`/ads#banner/` 体内 `#` 不截断，但 `@@/ads#banner/ # keep this` 的真注释必须截断（`AGENT_MISTAKES.md` A-095 回归对；判据是「`#` 在行首或紧跟空白才开注释」） |
| `core/rule/AllowRuleSpecialRulesReloadTest.kt:15` | 特殊规则 reload 语义 | `subscriptionSpecialRuleSurvivesWhenUserRuleHasSamePattern`；`userSpecialRulesAreDroppedBecauseTheReloadedListReplacesThem`；`subscriptionRulesWithDistinctPatternsAllSurvive`；`stagingSubscriptionSourceCountsAsSubscription`；`specialAllowRuleDefaultsToUserSource` | 订阅源（含 `SOURCE_STAGING`）不被用户同 pattern 规则顶替；默认 `SOURCE_USER`（`DefaultWhitelistSeeder.SOURCE_USER=="useradd"`、`SOURCE_PRESET=="preset"`，见 `ui/WhitelistEditDemotesPresetSourceContractTest.kt:88-89`） |
| `core/rule/BlockRuleCacheTest.kt:7` | `BlockRuleCache` | `findsTheMostSpecificMatchingRuleAndItsSource`；`returnsManualRuleSourceWithoutSubscriptionAttribution`；`matchesWildcardPattern` | 最长匹配：`ads.example.com`/`sub_12` 胜 `example.com`/`sub_8`（对 `tracker.ads.example.com`）；`*-analytics.google.com` 命中 `app-analytics`、`sub.app-analytics`，不命中 `other.google.com` |
| `core/rule/CategorizedRuleStreamImporterTest.kt:16` | `CategorizedRuleStreamImporter` | `importWithBadfilterKeysDropsTargetRules`；`importTwoPassReconcilesBadfilterAcrossEntireFile`；`countRulesAccountsForBadfilterKeys` | badfilter **两遍**协调（顺序无关）；计数口径包含 badfiltered |
| `core/rule/CosmeticRuleManagerTest.kt:10` | `CosmeticRuleManager`（CSS JSON） | `scopedRulesAreGroupedByDomain`；`globalHideIsNotDuplicatedPerDomain`；`exceptionIsNotCompiledAsHide` | JSON 结构 `globalHide` / `globalException` / 每域 `hide`+`exception` 数组；全局 hide 不复制进域；`#@#` 进 exception 不进 hide |
| `core/rule/DefaultWhitelistSeederPresetTest.kt:14` | `DefaultWhitelistSeeder` | `emptyAssetKeepsExistingPresetRules`；`nonEmptyAssetWritesPresetRules`；`failedSeedIsNotMarkedInitialized`；`successfulSeedIsMarkedInitialized`；`assetStillParsesToFivePassthroughDomains` | `PresetSeedOutcome.KEEP_EXISTING(0)` / `WRITE(5)`；`shouldMarkInitialized(0)==false`；`assets/https_passthrough.txt` 恰 **5** 域，含 `mtalk.google.com`、`connectivitycheck.gstatic.com`（A-099：先删后解析导致白名单永久清空） |
| `core/rule/RuleRegexTest.kt:12` | `RuleRegex` | `matchesUpperCasePatternAgainstLowerCaseDomain`；`matchesLowerCasePatternAgainstMixedCaseDomain`；`keepsLeadingIgnoreCasePrefixUnchanged`；`leadingNegativeInlineFlagStaysCaseSensitive`；`matchingIsUnanchored`；`invalidPatternNeverMatches` | 必须与 Go `policy_engine.go` 一致：不加已有 `(?i)`；`(?-i)` 前缀保持敏感；`MatchString` 语义=**非锚定搜索**；非法模式 `(unclosed` 恒 false（A-093） |
| `core/rule/SpecialRuleMatcherTest.kt:8` | `BlockRuleMatcher` | `testDenyallowMatching`；`testRegexMatching`；`testAppScopedSpecialRuleMatching` | denyallow：`example.com`/`bad.example.com` 命中，`good.example.com`、`safe.example.com` 及子域不命中；正则 `ad123`/`AD456`（大小写）命中而 `ad.example.com` 不命中；app 级规则 source=="app_regex_rule"，其他 UID 不命中 |
| `core/rule/SubscriptionAutoUpdateEngineTest.kt:12` | `SubscriptionAutoUpdateEngine` | `testRecordOutcomeUpdated`；`testRecordOutcomeNotModified`；`testRecordOutcomeFailedRetryable`；`testRecordOutcomeFailedNonRetryable`；`testCreateProgressData` | 三类状态 `SubscriptionAutoUpdateItemStatus` 的时间戳/成功计数语义（retryable 保留可重试、非 retryable 停止） |
| `core/rule/SubscriptionImportRecoveryStagingTest.kt:24` | 导入失败回收 | `stagingCleanupCoversEveryRuleFamily`；`bothStagingAndCommittedSourcesAreCleaned` | 清理必须覆盖**每个规则族** DAO（allow/block/cosmetic/goUrl/mirrorTemplate/rewrite/autoUpdate/subscription/group）；`RuleDataSources` 双源（staging+committed）都要清 |
| `core/traffic/TrafficSpeedEstimatorAppTickTest.kt:18` | `TrafficSpeedEstimator` | `appInTickGetsNonZeroRealtimeSpeed`；`multipleAppsInOneTickAreAllRecorded`；`appMissingFromNextTickIsDecayed`；`emptyTickDecaysEverythingAndNeverCreatesEntries`；`elapsedSecondsCompensatesAggregatedTicks` | **EMA_ALPHA=0.3**：30 KB/s→`tx==9000.0±0.5`、`rx==18000.0±0.5`；聚合 tick 100 KB/10 s→`3000.0±1.0`；空 tick 两次后精确 `0.0`，缺席包不建条目（A-015） |
| `core/traffic/TrafficStatsManagerSessionResetTest.kt:17` | `TrafficStatsManager.shouldResetSessionCounters` | `firstStartResetsSession`；`configRestartWhileRunningKeepsSession` | `wasRunning==false`→true（冷启动清零）；`true`→false（改配置重启不得清零会话，A-078） |

## 4. Kotlin 测试编目 · express（17 文件 / 2 449 行 / 95 个 `@Test`）

| 测试文件:行 | 被测对象 | 覆盖的行为点 | 关键期望值常量 |
|---|---|---|---|
| `express/ExpressConfigAdapterTest.kt:19` | `ExpressConfigAdapter` | `sanitizeExportSelection clears full tunnel features including custom address rules`；`sanitizeImportConfig strips full tunnel components from transfer config` | 导出净化后 `customBlockRules.size==1`、`customAllowRules.size==1`、`systemSettings.hideFromRecentsEnabled==true`（只削掉全隧道专属项） |
| `express/ExpressDataCleanupAndHiddenFeaturesTest.kt:15` | `EXPRESS_SUPPORTED_FEATURES` / `ExpressCleanupAction` | `testExpressHiddenFeaturesOmitFullTunnelFeatures`；`testExpressDataCleanupActionsOmitFullTunnelActions`；`testExpressDataCleanupLocalizationAvailability` | **27** 总特性 / **18** Express 支持 / 省略 **9**（REWRITE_LIST, TRAFFIC_STATS, APP_RULES, BLOCKED_APPS, EXCLUDED_APPS, HTTPS_INSPECTION, OUTBOUND_PROXY, NETWORK_TOOLS, AGENT_API）；`NETWORK_CONTROL`、`ADVANCED_TOOLS` 两类必须为空；`POLICIES_RULES` 只剩 **3**；清理动作 **11** 个，禁 TRAFFIC/ADDRESS_RULES/APP_RULES/OUTBOUND_PROXY/CA_CERTIFICATE；提示文案禁 "HTTP"/"覆写"/"证书"/"流量统计"/"地址规则"；每个 title/message 有 `translateExact` 译文 |
| `express/ExpressDataIsolationTest.kt:12` | `RuleDataset` 隔离 | `testPreferencesIsolation`；`testRuleIndexDirectoryIsolation`；`testScopeDirectoryIsolation`；`testRuleDatasetValues`；`testDefaultResolutionModeAlignment` | prefs 名精确：EXPRESS=`diting_express_prefs`、NORMAL=`dns_vpn_prefs`、DNS_MODE=`diting_dns_mode_prefs`(:16-18)；`RuleDataset` 恰 **3** 值；默认解析模式 `SINGLE`（`storageValue=="single"`，null→SINGLE） |
| `express/ExpressDnsEngineTest.kt:18` | `ExpressDnsEngine`（纯 Kotlin 引擎） | `testDdrMitigation`；`testRuleEvaluationBlocking`；`testNonAddressTypesBypassRules`；`testCacheHitAndMiss`；`testUpstreamFailureReturnsServfail`；`testTruncatedResponseNotCached`；`testRuleEvaluationBlockingPassesSubscriptionId` | DDR→`RCODE_NXDOMAIN` 且 `blockedQueries==1`；规则屏蔽→`RCODE_REFUSED`；放行→`NOERROR` 且计数不涨；cache miss→`cacheHits==0`、命中后 `==1` 且 `upstreamCount` 不变(:145)；ID 透传 0x1111/0x2222/0x4444；上游失败→`SERVFAIL`，日志含 "Network unreachable"；TC=1 响应不入缓存(`cache.map.isEmpty()`)；订阅归因 `subscriptionId==42L`；非地址类型(AAAA/HTTPS 之外)**跳过**规则求值 |
| `express/ExpressDnsMessageUtilsTest.kt:14` | `ExpressDnsMessageUtils` 位段 | `testBuildAndExtractQuestion`；`testBlockedResponses`；`testEnsureEdns0`；`testTtlPatching`；`testRfcCompliantNegativeResponsesWithoutSoa` | `TYPE_A==1`、`qclass==1`、ID 0x1234/0x5678；**逐位**：`bytes[4..5]`=QDCOUNT==1、`[6..7]`=ANCOUNT==0、`[8..9]`=NSCOUNT==0、`[10..11]`=ARCOUNT==0（负响应不得带 SOA）；应答长度==查询长度；TTL 300→patch 后 250（`cacheLifetimeSeconds`） |
| `express/ExpressDynamicBlockSupportTest.kt:16` | `ExpressDynamicBlockSupport`（A-081） | `escalation is never applied in express mode`；`escalation is applied everywhere except express mode`；`an enabled config is misleading only in express mode`；`express subtitle reports the fixed policy instead of the stored dynamic flag`；`normal dataset keeps the existing dynamic subtitle`；`dns mode now reports the live dynamic policy like normal mode`；`disabled config shows the fixed block response mode` | 子标题字面量：`"动态策略：先 NODATA，高频请求后 NXDOMAIN"`（NORMAL/DNS_MODE 启用态）、`"当前：NXDOMAIN"` / `"当前：NODATA"`（禁用态）；EXPRESS 启用态文案禁含 "动态策略"、必含实际模式名与 "极速模式" |
| `express/ExpressIpv6UsabilityTest.kt:19` | `ExpressIpv6Usability` | `global address with route is usable`；`global address without route is not usable`；`route without global address is not usable`；`neither address nor route is usable`；`verdict requires both inputs like the normal mode implementation` | **AND 而非 OR**（A-012：`hasIpv6Route \|\| hasGlobalIpv6` 恒真缺陷）；与 `DnsVpnTunnelManagerIpv6UsableTest` 同判据 |
| `express/ExpressLifecycleGuardTest.kt:17` | `ExpressLifecycleGuard`（A-040） | `start may publish running while no stop intervened`；`stop during the start window blocks publishing running`；`restart after a stop may publish running`；`only the latest of two overlapping starts may publish running`；`guard starts in the stopped state`；`repeated stops are idempotent and still block every outstanding token` | token 为代际序号；初始态 `isStopped()==true` 且 `canPublishRunning(0L)==false`；旧 token 在新一轮 start 后仍永久失效 |
| `express/ExpressLogModeAndDataIsolationTest.kt:22` | `DnsLogMode` + prefs 隔离 + 传输净化 | `testDnsLogModeStorageValues`；`testDnsLogModeFromStorageValue`；`testDatasetPreferencesIsolation`；`testExpressConfigAdapterPreservesLogSettings`；`testExpressLogDashboardNavigationAvailability` | storageValue 字面量 `"all"`/`"blocked_and_errors"`/`"off"`；null/""/"INVALID_MODE"→ALL；三 prefs 两两 `assertNotEquals`；净化后保留 `logRetentionDays==14`、`dnsLogMode=="ALL"`、`floatingLogEnabled==true`、`floatingLogPanelSize==2`、`hideFromRecentsEnabled==true`；`ExpressBottomBarDestination.LOG_DASHBOARD.id=="log_dashboard"` |
| `express/ExpressModeLauncherTest.kt:10` | `AppWorkMode.EXPRESS` / `ExpressVpnIntents` / `ExpressEnvironmentChecker` | `Express mode metadata conforms to specification`；`AppWorkMode fallback and parsing works for all modes`；`ExpressVpnIntents constants are distinct and non-empty`；`ExpressEnvironmentChecker and AppWorkMode isSupportedOnCurrentDevice evaluate consistently`；`ExpressVpnIntents action mappings are valid` | `storageValue=="express"`、`title=="极速模式"`、`badgeText=="极速"`、`minApiLevel==24`；action 全名 `com.haoze.diting.express.{START_VPN,STOP_VPN,REFRESH_CONFIG,SYNC_RULES,CLEAR_CACHE,STATUS_CHANGED,REFRESH_FLOATING_LOG,FLOATING_LOG_APP_STATE}`；未知值/null→NORMAL |
| `express/ExpressNavigationTest.kt:9` | `ExpressBottomBarDestination` | `default destinations are HOME, FEATURE_HUB and LOG_DASHBOARD`；`fromId resolves only supported Express destination ids`；`fromLegacy correctly maps supported destinations and filters unsupported ones`；`parseJsonList filters out full tunnel destinations and falls back safely`；`toJsonList and parseJsonList round trip preserves order` | 默认 **3** 项有序 [HOME, FEATURE_HUB, LOG_DASHBOARD]；`fromId`/`fromLegacy` 也接受 `settings`；非法 JSON→`DEFAULT_DESTINATIONS`；round-trip 保序 |
| `express/ExpressPacketCodecTest.kt:14` | `ExpressPacketCodec` + `PublicDnsHijackList` | `testInternetChecksumStandardVector`；`testIPv4DnsUdpQueryParsingAndResponseRoundtrip`；`testIPv6DnsUdpQueryParsingAndResponse`；`testIPv6ExtensionHeaderSkipping`；`testTcpResetForNon53Traffic`；`testMalformedAndFragmentPackets`；`testEncodeUdpResponseZeroAllocationAndOddChecksum`；`testDnsTtlPatchIdempotencyAndExpiry`；`testPublicDnsHijackList` | **RFC 1071 校验和向量** `00 01 f2 03 f4 f5 f6 f7` 拼回校验和后折叠和 ==0；RST 长度 **40**（20 IP+20 TCP）、`rstPacket[0]==0x45`、对 SYN(seq=1000) 的 RST `ack==1001`、flags==**0x14**(RST\|ACK)、seq==0；对 ACK(ack=5000) 的 RST seq==**5000**、flags==**0x04**（纯 RST）；**入向已带 RST→返回 null（不得 RST 回 RST）**；IPv6 逐跳扩展头（NH=0, hdrLen 8 字节）后正确取 UDP；分片三型 discard reason 字面量 `"Non-first fragment"` / `"Fragmented datagram (MF=1)"` / `"Fragmented IPv6 packet (M=1)"`；过短/截断/IP 版本 3 → null；奇数 3 字节载荷 encode 长度==`20+8+3`==31；TTL：extract 300、patch(0)→逐字节相等、patch(50)→250、overwrite(600)→600、patch(300) 与 patch(301)→**null**（已过期）；劫持表含 `8.8.8.8/1.1.1.1/223.5.5.5/114.114.114.114/2001:4860:4860::8888/2606:4700:4700::1111`，不含 `192.168.1.1/10.0.0.1/127.0.0.1`；`IPV4_HIJACK_IPS.size>=20`、`IPV6_HIJACK_IPS.size>=8` |
| `express/ExpressResidualScreensTest.kt:21` | 残留屏裁剪 | `testExpressBottomBarDestinationsAreConstrained`；`testExpressBottomBarFromLegacyFiltersResidualItems`；`testAboutCapabilitiesForExpressModeOmitFullTunnelFeatures`；`testAboutBoundariesForExpressModeClarifyDnsScope` | Express 底栏 **4** 个枚举；NORMAL `aboutCapabilities` **8** 项 vs EXPRESS **6** 项 |
| `express/ExpressRoomDnsCacheTest.kt:21` | `ExpressRoomDnsCache`（A-065） | `testCachePutAndGetHit`；`testCacheDisabledPolicy`；`testCacheExpiredEntity`；`testTtlOffsetsPopulatedInEntity`；`testMemoryCacheDefensiveCopy`；`testClearMemoryCache`；`testConcurrentPutAndGet`；`testDnssecOkAndCheckingDisabledProduceDistinctKeys`；`testPutPreservesHitCountersOfExistingEntry`；`testPutInsertsNewEntryWhenKeyAbsent` | policy(enabled, min 60, max 600)；禁用→`storage.size==0`；过期实体不返回；**DO/AD 标志产生不同 key**（DNSSEC OK vs CD 不得串用）；`put` 刷新保留 `hitCount==2` 与 `lastHitAt`（REPLACE=DELETE+INSERT 曾清零）；防御性拷贝（改原数组不影响缓存首字节）；20 并发键 |
| `express/ExpressTcpDnsHandlerTest.kt:17` | `ExpressTcpDnsHandler`（TCP DNS 状态机） | `testTcpThreeWayHandshakeAndDnsQueryResponse`；`testRstTerminatesConnection`；`testPacketForNonExistentConnectionReturnsRst`；`testDuplicatePayloadDoesNotCorruptBuffer`；`testFinWithPayloadProcessesPayloadAndAcksFin` | SYN→1 个 SYN\|ACK(flags **0x12**)、`ack==1001`；2 字节长度前缀帧查询→PSH\|ACK(**0x18**)、`ack==1001+framedQuery.size`、内层 DNS ID 0x3333；未知连接→RST(**0x04**) seq==67890；重复载荷→第二次仅 ACK(**0x10**) 不重复执行查询；FIN+载荷→先应答数据(0x18) 再 FIN\|ACK(0x11)，共 2 包 |
| `express/ExpressUpstreamDispatcherTest.kt:19` | `ExpressUpstreamDispatcher` | `testSingleMode`；`testPrimaryBackupFailover`；`testParallelRaceWinnerAndSocketCancellation`；`testSmartPredictionMode`；`testPrimaryBackupFailoverOnServfail`；`testParallelRaceIgnoresFastServfail` | 单模式只调主（`calledProviderId=="pA"`）；主挂→备份应答 **NOERROR**；并行竞速取胜者并取消落败 socket；**竞速必须忽略快速 SERVFAIL**（不得把先到的错误应答当胜者） |
| `express/ExpressVpnIntegrationTest.kt:14` | 常量与生命周期契约 | `testIntentActionConstants`；`testTunnelManagerConstants`；`testNotificationConstants`；`testNotificationStatusTextFormatting`；`testPublicDnsHijackListCoverage`；`testTunnelManagerSafeLifecycleWhenUnstarted` | TUN 地址 `10.0.0.2/10.0.0.1`（v4）、`fd00:abcd::2/fd00:abcd::1`（v6）、**MTU 1400**；`NOTIFICATION_ID_EXPRESS_VPN==2001`；未启动时 stop/clear 等调用不得抛 |

（续篇接 §5 起：其余包编目、覆盖空白图、Go 编目、资源与备份规则、关键引证表、Flutter 重构注意。）
