---
所属系列: DITING Android Flutter 重构功能图谱
章: 13（续篇）
最后校验: 2026-10-18
口径: 数字均为本会话工具实测；承接 13-tests-and-assets.md §4
---

# 13 续 · 其余包编目 · 覆盖空白图 · Go 编目 · 资源清单 · Flutter 注意

## 5. Kotlin 测试编目 · 其余 55 文件

### 5.1 server（5 文件 / 723 行 / 45 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `server/DnsDynamicBlockJsonTest.kt:30` | `DnsDynamicBlockJson` / `DnsModeConfig` | `json keys match the Go struct tags exactly`；`enabled and parameter values are carried through`；`disabled config still emits enabled false instead of omitting the key`；`defaults stay inside the ranges Go clamps to`；`the key name is dynamicResponse as Go expects`；`dns mode config carries the dynamic policy so it can reach the snapshot`；`embedded object parses back the way Go would decode it` | **与 Go 结构体 tag 逐键对齐**（A-023）：`KEY=="dynamicResponse"`，字段 `requestThreshold==7`、`windowSeconds==90`、`nxDomainDurationSeconds==600`、json 长度恰 4；**禁用态仍须 emit `enabled:false` 而非省略键**（对应 Go 侧曾用的 `json:"ttl,omitempty"` 教训，O-107 同型） |
| `server/DnsListenPortMigrationTest.kt:16` | `DnsListenPortMigration` | `legacyMdnsPortsAreMigratedToDefault`；`defaultPortIsKept`；`deliberateUserChoicesAreKept`；`unbindableValuesAreNotTreatedAsLegacyDefaults` | 5353/5354（mDNS）→`DEFAULT_PORT==1053`；其余不可绑定值不得被当 legacy 默认改写（A-022「每次读都重写存储值」缺陷） |
| `server/DnsModePortAndFilterSwitchTest.kt:17` | `DnsListenPortValidator` / `DnsFilterMasterSwitch` | `formatEndpoints uses the configured port for every address`；`...renders nothing for an empty address list`；`formatEndpoint appends the configured port`；`displayPort keeps a valid port and falls back...`；`accessInstruction splices...`；`noVpnDisclaimer splices...`；`instruction helpers fall back to the default port for unbindable values`；`isBindable accepts exactly the bindable range`；`a usable port produces no warning`；`a silent fallback is never allowed - an unusable port must warn`；`master switch defaults to enabled and reports changes`；`master switch can start disabled` | 字面量 `"192.168.1.10:1053 / 10.0.0.5:1053"`、分隔符版 `"…, …:6000"`；`isBindable` 恰 **[1024, 65535]**（1023/53/0/-1/65536 均 false，:74-84）；不可用端口必须出警告且文案同时含 53、1053、"不可用"，`displayPort(53)==1053`（A-084）；A-020 总开关默认开且能报变化 |
| `server/DnsModeStartGuardTest.kt:19` | `DnsModeStartGuard` | `start may publish running while no stop intervened`；`stop during a start blocks that start from publishing running`；`a fresh start after a stop may publish running again`；`only the latest of two concurrent starts may publish running`；`guard starts in the stopped state` | A-021：端口 bind 非挂起点，代际 token 判定与 `ExpressLifecycleGuard` 同构（少 `repeated stops idempotent` 一条） |
| `server/DnsModeTest.kt:22` | `DnsModeProtocol`/`DnsUpstreamServer`/`DnsServiceStatus`/`DnsModeManager`/`DnsModeConfig`/`DnsUpstreamValidator`/`DnsServerEngine`/`DnsModePreferences`/`DnsCachePreset` | `DnsModeProtocol has correct properties and default ports`；`DnsUpstreamServer presets contain dns doh and dot endpoints`；`DnsServiceStatus isRunning resolves accurately`；`DnsModeStats tracks query counts and latencies properly`；`failed queries count but do not skew average latency`；`onServiceStarted preserves accumulated stats across service starts`；`DnsModeManager service lifecycle callbacks transition status`；`ERROR status survives service destroy notification`；`DnsModeConfig default values are reasonable`；`DnsUpstreamValidator accepts valid inputs and rejects invalid ones`；`custom upstream serialization round trips`；`DnsServerEngine starts and stops cleanly`；`DnsServerEngine answers SERVFAIL when upstream is unreachable`；`getActiveUpstream falls back gracefully when id is unknown`；`DnsListenPortValidator accepts editable range and rejects others`；`multi-tier cache presets map to coherent policies`；`resetStats clears in-memory stats` | DNS=53/DoH=443/DoT=853，label "DNS"/"DoH"/"DoT"，`fromStorage` 大小写不敏感、未知→DNS；预设 **18** 个，首项 id `preset_alidns_dns`（"阿里云"）、cloudflare→`1.1.1.1`、`endpointLabel()` 形如 `"[DoH] host/path"`、`"[DoT] host:853"`；默认配置 port **1053**、cacheTtl **300**、preset BALANCED（`maxTtlSeconds==3600`，high-hit `==21_600`）；`parsePort("",DNS)==53`、`parsePort("853",DOT)==853`；stats 累计/保留/清空数值（queryCount 0→1→2→3，latency 20→12→8→15）；ERROR 在 onDestroy 后仍保持并带文案 `"DNS 服务启动失败，监听端口可能被占用"` |

### 5.2 normal（5 文件 / 358 行 / 19 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `normal/DnsVpnTunnelManagerBypassRoutesTest.kt:13` | `DnsVpnTunnelManager.IPV4_BYPASS_LAN_ROUTES` | `bypassRoutesCoverOnlyNonTunnelRanges`；`publicChinaTelecomAndUnicomRangesAreTunneled`；`previouslyCoveredRangesStayCovered` | 补集**精确等于** 7 条 CIDR 列表：`0.0.0.0/8, 10/8, 127/8, 169.254/16, 172.16/12, 192.168/16, 224.0.0.0/3`；测试自带「路由不得重叠」前置 `check`；116–119、122–123 不得进补集（曾泄漏直连） |
| `normal/DnsVpnTunnelManagerIpv6UsableTest.kt:15` | `DnsVpnTunnelManager` IPv6 判定 | 4 项：GUA 无路由 / 有路由无 GUA / 两者皆有 / 两者皆无 | AND 语义（A-012 普通模式侧） |
| `normal/DnsVpnTunnelManagerCertificateMismatchTest.kt:15` | 证书不一致→重启判定 | `sessionAssumedInstalledButActuallyMissingRequiresRestart`；`sessionAssumedMissingButActuallyInstalledRequiresRestart`；`matchingStatesDoNotRestart` | A-077：缓存标志与真实校验结果不符时必须重建隧道 |
| `normal/GoTunnelLogProcessorUpstreamTtlTest.kt:24` | `upstreamTtlFrom` + Go 聚合器 tag | `missingTtlKeyIsUnknown`；`explicitZeroTtlIsPreserved`；`positiveTtlIsReadBack`；`negativeTtlIsForwardedAndDroppedByTheCache`；`goPayloadAlwaysCarriesTheTtlKey` | 缺键→`DnsResponseCache.TTL_UNKNOWN`；`0`→`0L`（**必须区分**，O-107）；120→120L；-5 原样转发由 cache 丢弃；Go 侧 `ttl` 字段 tag 存在且**不含 `omitempty`**（源码文本钉） |
| `normal/RuntimeConfigCommitPolicyTest.kt:19` | `RuntimeConfigCommitPolicy` | `failedRefreshKeepsTheModeTheEngineIsRunning`；`successfulRefreshCommitsTheRequestedMode`；`snapshotNeverAdvancesPastTheEngine`；`noopRefreshIsStableOnEveryPath` | 快照模式==引擎实际模式（O-103 不变式）；解析失败分支不得提交新选择的 `PARALLEL_RACE` |

### 5.3 notification（5 文件 / 588 行 / 27 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `notification/AppNotificationChannelsRegistryTest.kt:26` | `AppNotificationChannels` + `RuleOperationWorker`（源码文本） | `theChannelIdsAreAllDistinct`；`theRuleOperationChannelIsTheOnlyOneTheWorkerUses`；`channelTitlesAreReadInTheAppLanguage`；`theLocalizedResourceHelperWrapsTheContextFirst`；`theStoppedMonitorNotificationUsesTheAppLanguage`；`theWorkerResolvesItsProgressTextInTheAppLanguage`；`creatingChannelsIsIdempotentOnOldApis` | `CHANNEL_RULE_OPERATIONS=="diting_rule_operations_channel"`；禁止裸 `NotificationChannel(` 构造（正则 `(^\|[^A-Za-z0-9_])NotificationChannel\(`）；标题须走 app-language helper（A-034/A-037） |
| `notification/NotificationSettingsIntentFallbackTest.kt:20` | `NotificationPermissionHelper`（源码文本） | `theNotificationChannelSettingsIntentIsVersionGuarded`；`everyLaunchPathHasAnAppDetailsFallback`；`theFallbackIsSelfContainedEnoughToWorkFromANonActivityContext`；`thePermissionProbeStillShortCircuitsBelowAndroid13` | `ACTION_APP_NOTIFICATION_SETTINGS` 仅 API≥26；所有启动路径都要 App-details 兜底；13 以下权限探测短路（A-036） |
| `notification/ServiceStartupDefectFixTest.kt:19` | 服务常量与非启动安全 | `testVpnMonitorServiceConstantsAndLiveness`；`testDefaultWhitelistSeederCacheLifecycle`；`testExpressTunnelManagerUnstartedSafety`；`testDnsVpnTunnelManagerUnstartedSafety` | **通知 ID：monitor=1002、normal VPN=1001、express VPN=2001**，两两 `assertNotEquals`；seeder 缓存 2 条、首域 `example.com` |
| `notification/VpnMonitorLifecycleStateTest.kt:15` | `VpnMonitorLifecycleState`（前台服务义务状态机） | 9 项：`stop is refused while a start foreground obligation is outstanding`；`stop becomes safe after the service reports promotion`；`stop is safe when the service instance is already alive`；`duplicate start requests are collapsed while a start is in flight`；`a stale in flight start is allowed to retry after the timeout`；`start failure rolls back the in flight marker`；`service destruction clears the in flight marker`；`stop unblocks once the in flight start is provably stale`；`sync after stop clears the stop request` | 构造注入 `inFlightTimeoutMs = 10_000L`；这是冷启动 `ForegroundServiceDidNotStartInTimeException` 修复（f3f9886）的行为规格 |
| `notification/VpnNotificationIdConflictTest.kt:12` | 跨模式通知 ID/渠道分区 | `notification IDs across modes and monitor are distinct and strictly partitioned`；`notification channels across services are separated`；`express VPN service liveness flag reflects state accurately` | 渠道名 `diting_vpn_monitor_channel` / `diting_express_vpn_channel` / `diting_vpn_service_channel` 三者互异 |

### 5.4 crash（4 文件 / 388 行 / 21 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `crash/CrashCaptureSequenceTest.kt:19` | `CrashCaptureSequence` | `everyStepRunsWhenAnEarlierStepThrows`；`bookkeepingRunsEvenWhenBothReportStepsFail`；`failingFailureCallbackDoesNotAbortTheRemainingSteps`；`allSuccessfulStepsReportNoFailures` | 记账步**必须执行**：失败步集合 `["minimal-report"]` / `["minimal-report","full-report"]`，成功计数 1/2（A-054：OOM/SOE 时簿记被跳过） |
| `crash/CrashExportCompletionTest.kt:28` | `CrashExportCompletion.commit` | `bookkeepingSurvivesCancellationOfTheCallingScope`；`bookkeepingStillRunsOnTheHappyPath` | 调用方 scope `cancel()` 中途，簿记仍完成（`NonCancellable`）；A-058 |
| `crash/CrashLogManagerAutoExportTest.kt:20` | `CrashLogManager.shouldAutoExport` | `belowThresholdNeverExports`（1、2 均 false）；`thresholdExportsOnceWhenNotYetBackedUp`（3、未导出→true）；`alreadyBackedUpStreakDoesNotExportAgain`（4、99 已导出→false）；`manualExportAlsoSuppressesAutoBackup` | `CONSECUTIVE_THRESHOLD==3`（`CrashLogManager.kt:42`）；注释明确纠正 triage 文档：`clearCrashLogs()` 是**清除**抑制位（重武装），非设置（A-053 + 铁律 4） |
| `crash/CrashLogManagerStateTest.kt:22` | `CrashLogManager` 连胜/水位（含源码文本部分） | `crashInsideTheWindowIncrementsTheStreak`；`crashOutsideTheWindowStartsANewStreak`；`crashExactlyAtTheWindowEdgeStillCounts`；`firstEverCrashStartsAtOne`；`theStreakUpdateIsSerializedByTheStateLock`；`theWaterlineIsPersistedBeforeEachStreakIncrement`；`clearKeepsTheWaterlineOnTheSystemReportedClock`；`clearNeverLowersAnExistingWaterline`；`clearWithoutHistoricalRecordsKeepsTheWaterline`；`clearWithNoWaterlineAndNoRecordsStaysAtZero`；`privateDownloadFallbackDirectoryIsMappedForFileProvider` | `nextConsecutiveCount(currentCount=0,…)==1`；窗口 `CONSECUTIVE_EXPIRY_MS==24h` 边界含等号；`PRIVATE_DOWNLOAD_DIR_NAME=="downloads"`（与 `file_paths.xml` 的 `crash_export_private` 对齐）；`MAX_CRASH_LOGS==8`；A-055/O-123/O-124 |

### 5.5 update / data / permission / main（12 文件 / 738 行 / 39 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `update/AppUpdateDirectoryContractTest.kt:20` | `AppUpdateDirectories` + `DataCleanupManager` | `updateDirectoryNameIsAppUpdate`；`downloadDirectoryResolvesUnderFilesDir`；`cleanupActuallyDeletesADownloadedApk`；`legacyUpdatesDirectoryIsNotTouched` | `UPDATE_DIRECTORY=="app-update"`（**不是** `updates`，A-013）；清理后 `listFiles().size==0` |
| `update/AppUpdateDownloadRecordRetentionTest.kt:16` | 下载记录保留判定 | `recordOfTheFailedVersionIsCleared`；`recordOfAnOlderDownloadedVersionIsPreserved`；`missingRecordIsNotCleared`；`recordedVersionIsComparedVerbatim` | A-060：仅失败版本自身等于记录版本才清 |
| `update/AppUpdateManagerTest.kt:8` | 版本比较 / Release 解析 | `comparesNumericVersionsAndIgnoresPrereleaseSuffix`；`parsesNewerReleaseAndPrefersArm64Asset` | `version=="3.0.18"`、`downloadUrl` 取 arm64 资产、`releaseNotes=="- 修复网络问题"` |
| `update/AppUpdateProgressThrottleTest.kt:14` | `AppUpdateProgressThrottle` | `firstReportIsAlwaysAllowed`；`byteStepBelowThresholdIsSuppressed`；`timeGapBelowThresholdIsSuppressedOnFastLinks`；`windowRestartsAfterEachReport`；`forcedReportMovesTheBaseline`；`defaultsAreBounded` | 双阈值（字节步进 + 时间间隔）节流，强制上报移动基线（A-047） |
| `data/cleanup/DataCleanupCustomBackgroundContractTest.kt:18` | 自定义背景清理（源码文本） | `theWipedPreferencesFileIsTheOneTheStoreActuallyUses`；`everyCandidateUriAndTheEnabledFlagAreCleared`；`appearanceStoreLivesInTheSharedPreferencesFile` | 清理文件必须是 `dns_vpn_prefs`，禁 `appearance_settings`（A-016） |
| `data/cleanup/DataCleanupManagerTest.kt:22` | `DataCleanupManager`（动态代理 DAO 族） | `testClearDomainRulesData`；`testClearAddressRulesData`；`testClearSubscriptionsData`；`testDeleteDirectoryContents`；`testDeleteDirectoryContentsEdgeCases` | 按调用序列断言「清了哪些表」：域规则=allow+block+rewrite；地址规则=goUrl+cosmetic；订阅=sub+group+autoUpdate；目录清空后 size==0，含不存在/非目录边界 |
| `permission/AppListPermissionTest.kt:11` | `AppPermission.PACKAGE_QUERY` / `ModeReadinessState` | `testAppListPermissionConstants`；`testAppPermissionPackageQueryAttributes`；`testModeReadinessStateWithAppPermission`；`testAppListPermissionLocalization`；`testAppManagementLocalizationForAppList`；`testAppListPermissionCacheInvalidation` | title `"应用列表访问"`；`getLevel` NORMAL=**RECOMMENDED**、EXPRESS/DNS=OPTIONAL；`isApplicableTo` 仅 NORMAL；缺失时 `hasBlocker==false` 且 `isFullyReady==false`、`missingRecommended` 含该项 |
| `permission/BatteryOptimizationTest.kt:13` | `AppPermission` 电池项 / helper | 5 项（attributes/readiness/cache invalidation/action constants/localization） | 动作常量集合与本地化精确匹配；helper 缓存失效 |
| `main/MainDecompositionTest.kt:9` | `MainActivity` 常量 / `MainWorkModeCoordinator` / `MainStartupCoordinator` | `MainActivity constants remain consistent with public contract`；`MainWorkModeCoordinator initializes with sensible defaults`；`MainStartupCoordinator startup tuning constants adhere to spec`；`MainWorkModeCoordinator constructor callbacks default to safe no-ops` | `EXTRA_AUTO_START_VPN=="auto_start_vpn"`、`EXTRA_WORK_MODE_CHANGED=="main_work_mode_changed"`、`EXTRA_TARGET_WORK_MODE=="main_target_work_mode"`；默认 NORMAL、`hasSelectedWorkMode==false`、`resetToHomeTrigger==0L`、`DATABASE_WARMUP_DELAY_MS==500L` |

### 5.6 ui（22 文件 / 2 268 行 / 115 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `ui/AiProviderTest.kt:13` | `AiProvider`/`AiProviderPresets`/编解码 | `keyObfuscator_encryptsAndDecryptsProperly`；`keyObfuscator_handlesEmptyAndBlank`；`aiProviders_serializationAndDeserialization`；`aiProviderPresets_containsValidEntries` | `decodeAiProviders(encodeAiProviders(list))` 往返一致（含空列表与多提供商） |
| `ui/BatchRuleAppScopeAndUrlNormalizationTest.kt:43` | `BatchRuleValidator`+`to*Entity` 全家（A-028/A-029/A-075） | 18 项（见 `:118-312`）：`invertedAppScopeSurvivesClassificationAndValidation`；`missingCaretIsInsertedBeforeTheModifierSection`；`missingCaretOnAllowFallbackIsInsertedBeforeTheModifierSection`；`modifierEqualsSignIsNotTreatedAsARewriteArrow`；`arrowMappingStillProducesRewrite`；`fatArrowMappingStillProducesRewrite`；`bareEqualsMappingStillProducesRewrite`；`invertedAppScopeIsPersistedOnTheBlockRow`/`AllowRow`；`nonInvertedAppScopeStaysFalse`；`batchUrlRuleIsNormalizedLikeTheSingleRulePath`；`batchUrlRuleDropsDefaultHttpPortAndAddsRootPath`；`nonDefaultPortIsKept`；`urlRowKindFollowsAllowFlag`；`elementHidingRuleIsRejectedOutsideNormalMode`/`AcceptedInNormalMode`；`commitGuardDropsCosmeticItemsOutsideNormalMode`；`cosmeticEntityKeepsExceptionFlag` | **`$~app=` 的 `=` 曾被当重写箭头**（AGENT_MISTAKES 2026-10-18「真实卡点分支」条目）；`~app` 反选必须穿透分类→校验→入库三跳；URL 规则去默认 80 端口 + 补 `/`；化妆规则仅 NORMAL 可提交 |
| `ui/BatchRuleValidatorTest.kt:23` | 同上（模式维度校验） | `testBlacklistValidationNormalMode`；`testBlacklistDnsModeRejectsUrl`；`testWhitelistValidation`；`testRewriteValidation`；`testUnifiedMixedRulesValidation`；`testModeDisambiguation`；`testMultiDomainHostsLines` | DNS 模式下 URL 型黑名单条目必须判非法；混合批次逐条分类；hosts 多域展开 |
| `ui/BottomBarDestinationTest.kt:8` | `BottomBarDestination` | `default destinations are HOME, FEATURE_HUB and LOG_DASHBOARD`；`fromId resolves all valid destination ids`；`parseJsonList returns defaults for null or empty`；`...filters out unknown and duplicate items`；`...falls back to default if fewer than 2 items`；`...caps at max 4 items`；`toJsonList and parseJsonList round trip preserves order`；`toJsonList falls back to default when input has less than 2 items` | id 字面量 `home/feature_hub/log_dashboard/app_traffic_stats/network_tools/settings`；**下限 2、上限 4** |
| `ui/HiddenFeatureStructureTest.kt:9` | `HiddenFeature` | `hidden feature keys are all unique and non-empty`；`fromKey resolves every hidden feature` | keys distinct |
| `ui/LogRetentionCrashCountRefreshContractTest.kt:17` | 崩溃日志屏（源码文本） | `theCrashLogCountIsRefreshedWhenTheScreenResumes`；`theRefreshDoesNotIntroduceAViewModel` | 计数必须在 resume 时重采，且**禁止**引入 ViewModel（O-126 交付口径钉） |
| `ui/LogRetentionSettingsActionsTest.kt:16` | `LogRetentionSettingsActions` | `retentionChangePersistsThenNotifiesRuntime`；`notifyRunsEvenWhenPersistingTheSameValue`；`everySupportedWindowNotifiesTheRuntime` | 通知计数==1（重复选同值也必须通知）；每个支持窗口都持久化后回调运行时（A-082） |
| `ui/RaceModeMessageLocalizationTest.kt:21` | `RaceModeSettingsViewModel`（源码文本） | `noUserVisibleMessageUsesTheUnwrappedApplicationContext`；`theFormatStringAndItsArgumentComeFromTheSameLocalizationSource`；`everyBareGetStringInTheViewModelIsGone` | 禁 `getApplication().getString`（O-121） |
| `ui/SettingsUsageWizardTest.kt:9` | 使用向导入口 | `testUsageWizardDestinationConfiguredInOtherSettings`；`testUsageWizardLocalization` | `Routes.USAGE_WIZARD`、标题 `"使用向导"`→`"Usage Wizard"`、归属 `SettingsSection.OTHER` |
| `ui/WhitelistEditDemotesPresetSourceContractTest.kt:25` | 白名单编辑降级（源码文本） | `editedDomainRuleIsAlwaysStoredAsAUserRule`；`theConditionalPresetSourceSelectionIsGone`；`theResetThatWouldHaveDeletedTheEditStillTargetsOnlyPresetRows` | `SOURCE_USER=="useradd"`、`SOURCE_PRESET=="preset"`；编辑后必写 useradd（A-100：保留 PRESET 会被 `deleteBySource` 删掉用户改动） |
| `ui/WorkModeTest.kt:8` | `AppWorkMode` | `AppWorkMode fromStorageValue resolves correctly`；`AppWorkMode availability states are correct` | 三模式 title `"普通模式"/"服务器模式"/"极速模式"`、badge `"推荐"/"轻量"/"极速"`、**minApiLevel 29/29/24**、storage `normal/dns/express`，未知与 null→NORMAL |
| `ui/agent/MarkdownBlockTest.kt:11` | `parseMarkdownBlocks` / `formatMarkdownAnnotatedString` | 13 项：空/标题(1-6 级，`#no-space` 非标题、`#######` 7 级不成标题)/分隔线 4 形/代码块(``` 与 ~~~、语言标签、未闭合)/引用/表格/列表/混合/样式；3 个 `@Test(timeout = 2000)` 防死循环（`handlesNonTablePipes…`、`handlesSingleLinePipe…`、`handlesEmptyPipes…`） | 结构化 AST 逐块相等断言（`MarkdownBlock.Heading(1,"Heading 1")` …） |
| `ui/agent/MarkdownInlineAnnotatorUnderscoreTest.kt:20` | 内联下划线斜体 | `snakeCaseIdentifiersAreLeftAlone`；`identifiersKeepTheirUnderscoresWhenOtherMarkdownIsPresent`；`realEmphasisStillRenders`；`emphasisSurvivesNextToASnakeCaseIdentifier`；`otherUnderscoreFormsAreUnaffected`；`leadingIdentifierUnderscoreDoesNotOpenASpan` | 按 `FontStyle.Italic` span 集合断言；`dns_vpn_prefs` 不得拆斜体（A-097） |
| `ui/dashboard/DashboardLogLabelsTest.kt:23` | `dashboardDnsResultLabel/Status` | 9 项（BLOCKED→`"过滤"`/`"blocked"`、PASSED 连接行→`"旁路"`/`"bypassed"`、PASSED DNS 行→`"通过"`/`"passed"`、REWRITTEN→`"覆写"`、ERROR→`"失败"`、未知值原样回显、逐结果标签互异、blocked≠passed） | 标签必须由 `result` 决定而非 `isConn` 布尔（A-049） |
| `ui/floating/FloatingLogWindowTypeTest.kt:18` | `floatingLogOverlayWindowType(api)` | `api26AndAboveUsesApplicationOverlay`（26/29/36）；`belowApi26FallsBackToLegacyPhoneType`（24/25）；`everyReachableSdkResolvesToARealWindowType` | A-050 API 分界 26 |
| `ui/localization/LogsAndStatsFilteredEmptyMessageTest.kt:20` | `LocalizationEngine` 精确链 | `filteredDnsEmptyStateHasAnExactTranslation`；`exactChainResolvesItBeforeTheDynamicPrefixRule`；`patternStageNoLongerNeedsToGuessTheSentence`；`theTwoNarrowerSiblingsKeepTheirOwnWording`；`theEngineResolvesAllThreeInOnePass`；`noFilteredEmptyStateLeaksChineseIntoTheTranslation` | 三句精确译文；「翻译结果不得含 U+4E00–U+9FFF」（A-061 半翻译缺陷的通用判据） |
| `ui/settings/CnameRewriteOperationalTest.kt:22` | `cnameRewriteOperational(dataset){probe}` | `dnsModeCnameRewritesAreAlwaysOperational`；`expressNeverProgramsRewrites`；`normalModeFollowsTheHttpsInspectionPrerequisites`；`onlyNormalModeConsultsTheHttpsInspectionPrerequisites` | 判定表 + **探针只被 NORMAL 调用**（`consulted` 侧信道断言，O-119） |
| `ui/settings/RewriteCnameDeliveryTest.kt:20` | `DnsQueryFilter.kt` 与 `engine_standalone.go` 文本 | `dnsFilterPushesCnameRedirectsWithoutAnAdBlockGate`；`goEngineAppliesCnameBeforeTheFilteringSwitch`；`expressHasNoRewritePathAtAll` | `buildRewriteRulesJson` 体内含 `cnameRedirects()` 且**不含** `adBlockEnabled` |
| `ui/traffic/TrafficSessionClockTest.kt:13` | `sessionClockText` | `formatsElapsedTimeUnderAnHour`；`...OverAnHour`；`negativeDeltaClampsToZero`；`subSecondProgressDoesNotTickTheText` | `"00:00"/"00:07"/"01:00"/"59:59"`→`"01:00:00"`、`"02:03:04"`；负值与 0 终点→`"00:00"`（A-057） |
| `ui/transfer/AppRuleConfigImporterBlockedAppsSwitchTest.kt:17` | 导入对开关的影响 | `a backup without the list leaves the switch untouched`；`...enabled false turns the switch off`；`...enabled true turns the switch on`；`an already matching switch is left alone` | 「备份缺字段=不动本地」语义 |
| `ui/transfer/ConfigTransferParserOutboundProxyTest.kt:17` | 配置传输解析 | `formatVersionIsBumpedPastCredentialExport`；`v10ExportWithoutCredentialsParses`；`legacyV9FileWithCredentialsStillImports`；`absentOutboundProxyStaysAbsent` | v10 无凭证可解析、v9 含凭证仍可导入；`socks5/127.0.0.1/7890/com.example.proxy` + 空用户名密码；`http/::1/alice/s3cret` |
| `ui/transfer/NotificationTextsImportMergeTest.kt:18` | 通知文案合并 | `onlyTheRunningTextExported…`；`onlyTheStoppedTextExported…`；`bothTextsExportedAreBothApplied`；`aBackupWithNeitherFieldLeavesLocalSettingsUntouched`；`anEmptyImportedStringIsStillAnExplicitValue` | 逐字段合并：缺字段保留本地、空串视为显式值 |

### 5.7 util（5 文件 / 594 行 / 48 个 `@Test`）

| 测试文件:行 | 被测对象 | 行为点 | 关键期望值 |
|---|---|---|---|
| `util/DateTimeUtilsTest.kt:27` | `dayStartMillis` / `dayStringAt` / `currentDayString` / `statsRangeStartMillis` | 11 项：`springForwardDayStartsAtRealMidnightNotAnHourEarly`；`documentedReproductionPointIsNotActuallyAffected`；`fallBackDayKeepsTheFirstHourInsteadOfDroppingIt`；`ordinaryDaysOnEitherSideOfTheTransitionAreUnchanged`；`zonesWithoutDaylightSavingTimeStayExact`；`northernAndSouthernHemisphereTransitionsBothResolve`；`midnightThatDoesNotExistResolvesToTheFirstExistingInstantOfTheDay`；`resultIsAlwaysTheFirstInstantOfItsOwnLocalDayAndNeverAfterNow`；`dayStartAgreesWithTheLocalDateOfTheInstant`；`sevenDaysRangeUsesTheSameDayStartConvention`；`dayStringFormattingIsStable` | 期望值**由 `java.time` 独立推导后钉为字面 epoch 毫秒**（KDoc 明言，A-056）；向量含 NY 2026-03-08→`1772946000000L`、NY 2026-11-01→`1793505600000L`、Berlin `1774738800000L`/`1792879200000L`、Sydney `1791036000000L`/`1775307600000L`、Santiago 无 00:00 日 `1788667200000L`；6 时区 × 6 锚点 × 17 min 步长的性质扫描（`start<=now`、同本地日、前 1 分钟属前一日）；`ALL`/未知范围→`0L`；日期串契约 `Regex(r"\d{4}-\d{2}-\d{2}")` |
| `util/KeyObfuscatorTest.kt:13` | `KeyObfuscator.seal/open` + `Base64Codec` | `seal_open_roundTripsAsciiKey`；`...NonAsciiKey`；`...EmojiAndMixedScript`；`...LongNonAsciiKey`；`blankInputsStayEmpty`；`open_returnsEmptyForMalformedCiphertext`；`seal_producesStandardPaddedBase64`；`base64Codec_matchesKnownVectors`；`base64Codec_roundTripsArbitraryBytes`；`base64Codec_decodesKnownVectors`；`base64Codec_rejectsMalformedInput` | `seal("")/seal("   ")/open("")→""`；畸形密文 `invalid_base64_???`、`abc`、`ab*d` → `""`（**不抛**）；标准向量 `f→Zg==`、`fo→Zm8=`、`foo→Zm9v`、`foobar→Zm9vYmFy`、空字节→`""`；`sealed.length % 4 == 0`（A-032 API26 Base64 误用、A-059 非 ASCII 静默损坏） |
| `util/LatencyWindowTest.kt:19` | `LatencyWindow` | `reportsZeroBeforeStart`；`measuresOnlyTimeInsideTheWindow`；`excludesSetupTimeThatHappenedBeforeStart`；`elapsedIsNeverNegative`；`restartResetsTheWindow`；`eachAttemptGetsItsOwnWindow` | start=10 000 → elapsed(10 120)==120、elapsed(3 050)==50（setup 段不计，A-045）；未 start 时 elapsed==0；restart 后 1 500→500 归零、2 010→10；两次尝试分别 400 / 50 |
| `util/LatestRequestGateTest.kt:20` | `LatestRequestGate<T>` | `newestRequestIsLatest`；`olderRequestStopsBeingLatest`；`onlyTheLastOfManyRequestsIsLatest`；`nothingIsLatestBeforeAnyRequest`；`sameRequestValuesButDifferentInstanceIsNotLatest`；`clearInvalidatesTheCurrentRequest`；`beginReturnsTheRequestForCapturing`；`interleavedSearchAndPagingKeepsOnlyTheNewest`；`aLookalikeNeverRegisteredInstanceIsNotLatest` | **身份语义权威**：`:67-68` 先钉 `assertEquals(older,newer)` + `assertNotSame(older,newer)` 前提，再要求旧实例失效；`:103-111` 未 `begin` 的同值新对象必须判「非最新」（防退回 `==`）；`begin` 返回入参本身 |
| `util/SafGrantDecisionsTest.kt:18` | SAF 持久授权决策 | `rejectedPickReleasesItsOwnGrant`；`rejectedPickKeepsThePreviousFilesGrant`；`replacedPickReleasesThePreviousGrant`；`firstPickReleasesNothing`；`rePickingTheSameFileKeepsItsGrant`；`cancelledPickerReleasesNothing`；`removingAWallpaperReleasesItsGrant`；`removingABlankUriReleasesNothing`；`everyDecisionReturnsAtMostOneUri`；`mayReleaseOnlyWhatThisAppPersisted`；`mayReleaseIgnoresBlankAndUntrimmedInput` | 决策函数返回「至多一个待释放 URI」+ `mayRelease` 白名单门（A-083：曾 5 处 take、0 处 release） |

## 6. 测试覆盖空白图（实测）

口径：按 `com/haoze/diting/` 下**二级包**统计 main 源文件数与被任一测试引用的文件数；引用判据 = 该文件内声明的任意类型名/顶层函数名/顶层属性名（长度≥4）在任一测试文件中出现（脚本逐文件提取，启发式，未含纯注释巧合）。

**总体：522 个 main 文件，181 个被测试引用（34.7%）；仅按类名口径为 164 / 31.4%。**

空白最严重区（引用率 0% 且逻辑复杂 → Flutter 重写高风险区）：

| 区域（包 / 文件） | 规模 | 风险说明 |
|---|---|---|
| `normal/ui/**`（24 文件全 0%） | AppRuleManagementScreen、AppRuleViewModel、AppTrafficStats*、BlockedAppsScreen、ExcludedAppsScreen、ConfigTransferScreen、DataCleanupScreen、FeatureHubScreen、HttpInspection*、MainScreen(+Content)、ModernLogDashboardScreen、NotificationSettingsScreen、OptionalFeaturesScreen、OutboundProxySettingsScreen、RequestLogScreen、RuleControlScreen、BottomBarCustomization、Ca*Screen | 普通模式全部业务屏无测试；行为只能靠源码考古 |
| `ui/components`(16/16 0%)、`ui/theme`(11/11 0%)、`ui/component`(6/6 0%)、`ui/dashboard`(3/4)、`ui/floating`(5/6)、`ui/apprule`(3/3)、`ui/traffic`(6/7) | 视觉层 | Compose 视觉规格缺失，Flutter 须重建 golden |
| `express/transport/**`（`ExpressDohTransport`、`ExpressDotTransport`、`ExpressPlainDnsTransport` 全 0%） | 3 文件 | **极速模式三种上行传输零覆盖**（协议细节只在 `ExpressUpstreamDispatcher` 测试里以注入方式触及） |
| `express/ui`（11/14 0%）、`ExpressModeLauncher`、`ExpressVpnController`、`ExpressSettingsRefresher`、`ExpressDefaultsSeeder` | | 极速模式生命周期与播种 |
| `core/rule`（19/42 未触及） | `DomainPolicyEngine`、`SubscriptionManager`、`SubscriptionDownloader`、`SubscriptionUpdateCoordinator`、`SubscriptionRuleStorage`、`MappedSubscriptionRuleIndex`、`MappedSubscriptionRewriteIndex`、`AllowRuleCacheLoader`、`BlockRuleCacheLoader`、`HostsAndDnsmasqParser`、`AddressRuleBackupCodec`、`AdGuardDomainUtils`、`CosmeticRuleSupport`、`DomainRuleMatcher`(部分)、`RuleUpdateNotifier`、`SubscriptionAutoUpdateScheduler`、`RuntimeDnsSettingsRefresher`、`SubscriptionUrlHelper` | 订阅全链（下载→两遍导入→索引落盘→热更新）**无 JVM 测试**，只有导入器与 badfilter 有 |
| `crash/Tombstone*`（6/6 全 0%）+ `CrashCollector`、`CrashBreadcrumbs` | protobuf 解码 / wire reader / 脱敏 / 格式化 / 解析 | native 崩溃报告整链无测试 |
| `core/diagnostic`（9/15 未触及） | `BootstrapHealthEngine`、`BootstrapSelector`、`BootstrapIpModels`、`BootstrapLogger`、`ProviderHealthStore`、`NetworkInfoProbe`、`NetworkPingTool`、`NetworkTraceRouteTool`、`UidPackageCache` | 仅纯数学与 JSON 两半被测；调度/选择/工具实现未测 |
| `core/dns`（5/9 未触及） | `DnsLatencyTester`、`DnsLookupTool`、`DnsTimeoutConstants`、`DotTransport`、`PlainDnsTransport` | 普通模式 DNS 传输与超时表无测 |
| `core/traffic`（5/7 未触及） | `KernelTrafficSampler`、`TrafficDatabaseSyncer`、`SystemAppClassifier`、`TrafficAppResolver`、`AppTrafficModels` | 内核采样与 DB 同步（含 API 30 UPSERT 门）无测 |
| `data/repository`（5/5 全 0%）、`data/dao` 3 项、`data/entity` 8 项、`data/*Database`/模型 7 项 | DnsCacheRepository、DnsLogRepository、RaceLogRepository、RequestLogRepository、BootstrapLogRepository、AppTrafficDao、BootstrapLogDao、EnabledRuleProjection | DB 读写契约只有 DAO 假实现层面的间接覆盖 |
| `server/ui`(7/7)、`server/viewmodel`、`DnsMainActivity`、`DnsModeService`、`DnsModeBootReceiver`、`DnsRuleSettings` | | **服务器模式测的是逻辑不测 UI/服务**（见下「三模式分布」结论） |
| `normal` 其余 11 文件 | `GoTunnelRuleManager`、`DnsVpnRuleSyncManager`、`GoInspectionTunnel`、`GoInspectionResolvers`、`DnsVpnProviderResolver`、`DnsVpnNetworkMonitor`、`DnsVpnPowerOptimizer`、`DnsVpnStatusNotifier`、`DnsVpnIntentFactory`、`DnsVpnDatabaseComponents`、`VpnSpeedMonitor` | Go↔Kotlin 规则同步与巡检通道无测 |
| `core/cert/GoInspectionCaManager`、`core/tile/QuickSettingsTileUpdater`、`tile/DitingTileService`、`onboarding`(4/4)、`permission` 3 项（`ModePermissionStore`、`ModePermissionWarningAction`、`ModeReadinessBanner`）、`notification/NotificationSettingsStore`、`main` 3 协调器（`MainModeDispatcher`、`MainNavigationCoordinator`、`MainVpnController`）、`util`（`KeysetPaginationHelper`、`MetricFormatters`、`PersistableUriPermissions`、`DeviceScreenHelper`）、`update/AppUpdateHost`、`AppUpdateNotifier`、`RecognitionAvatar*`/`RecognitionMembersRepository` | | 各自独立小空白 |

### 6.1 三模式断言分布（实测，回应任务 D 项）

- 测试文件 `import com.haoze.diting.<pkg>`：`ui` **54**、`express` **30**、`server` **15**、`normal` **3**。
- `RuleDataset.*` 字面引用：core N=17/E=6/**D=0**；ui N=26/E=4/D=5；express N=10/E=13/D=8；其余 8 个包全 0。
- `AppWorkMode` 出现于 **5** 个测试文件（`WorkModeTest`、`ExpressModeLauncherTest`、`MainDecompositionTest`、`AppListPermissionTest`、`BatteryOptimizationTest`）。

结论修正：**「服务器模式几乎无测试」不成立**——server 目录 5 文件 / 723 行 / 45 个 `@Test`，`server/model` 6/6 = 100% 被引用、`server/backend` 5/8 = 62.5%。真实空白是：(a) **服务器模式的 UI 与服务壳 0%**（`server/ui` 7 文件、`DnsMainActivity`、`DnsModeService`、`DnsModeBootReceiver`、`DnsMainViewModel`）；(b) 跨模式一致性只有「Express 相对 NORMAL/DNS_MODE 的裁剪表」，**没有任何测试断言 NORMAL 与 DNS_MODE 的引擎行为等价**；(c) 普通模式（normal 包）自身仅 5 文件 / 358 行 / 19 个 `@Test`，是三者中最薄的**逻辑**侧。

## 7. Go 测试编目（21 文件 / 3 834 行 / 102 个 `Test*` + 1 个 `Benchmark*`）

行为级描述 + 行号（引擎架构见第 10 章，此处仅作契约佐证）：

| 文件:行 | 行为规格 | 关键期望值 |
|---|---|---|
| `dns_cache_test.go:16,71,102,148,227,286,327` + `BenchmarkDNSCacheGetFast_Hit:374` | 命中/回填、TTL 钳制、stale 兜底、负缓存、零拷贝改 ID、singleflight 防死锁、分片并发 | `MaxTTLSeconds 3600/60/300`、`MinTTLSeconds 10`、`FixedTTLSeconds 1`+`StaleFallbackSeconds 10`、`NegativeTTLSeconds 20`；3600s 记录钳到 `60*time.Second`(:97)；命中回填 `Id 5678`、`93.184.216.34`；NXDOMAIN 与 NODATA 均 `isNegative=true`；panic 后二次调用不得死锁（2 s 超时）；30 worker × 100 查询 |
| `resolver_test.go:132,159,197,240,283,323` | EWMA 打分与四种解析模式 | 默认分 `defaultEWMA`；20 ms→15 ms 后分下降、失败计数 2 计入罚分、成功后 `failureCount` 归 0；主挂→备份应答；**NXDOMAIN 直接透传不回落**；竞速 150 ms vs 5 ms 取快者；smart prediction 5 ms vs 100 ms |
| `resolver_truncation_test.go:118,149` | RFC 1035 §4.2.1 TC=1 → TCP 重试（A-019） | UDP 应答 TC=1 时最终答案必须是 TCP 上 1 条 A 记录；完整 UDP 应答不得开 TCP（测试故意不建 TCP 监听以证伪） |
| `dns_config_test.go:10,41,139` | 解析模式规范化、Provider 校验、ApplyDNSConfig 模式匹配 | 负例表：`8.8.8.8`（缺端口）非法、`[1.1.1.1:53]:53`（Kotlin 曾把带端口的 host 再加括号）非法、`[:::]:53` 非法、`http://` DoH 非法；正例 `[2001:db8::1]:53`、`quic://dns.adguard.com:853`(DOQ)、`DNSCRYPT` 未知协议非法；SINGLE 给 2 个 provider 必须报错 |
| `dns_low_regression_test.go:25,55,118,155,219,242,264,282,311,325,339,352,390` | Low 分级回归：TC 位判定、截断响应禁入缓存、IPv6 UDP 校验和覆盖载荷、`clear()` 后 LRU 元素解链、证书缓存有界/过期清理/复位、`connLogSeen` 去重集合有界、InjectingReader EOF 冲刷半头、`ApplyDNSConfig` 不得部分生效 | `TC` 位与 QR(0x80)/AA(0x04) 不串（:45-49）；不同 payload 必须产生不同校验和(:140-148)；`dedup.size() <= connLogSeenMaxEntries`(:296)；空 provider 列表整体拒绝 |
| `engine_block_response_test.go:19,44,52,78,115,135,155,199` | 屏蔽响应模式原子发布、nil 引擎、拒绝的配置不得生效（A-018/A-023）、总关闭时跳过过滤、full-tunnel 走动态升级 | 新引擎默认 `ResponseCustomIP`；nil 引擎返回构造默认；被拒快照后模式不变；`filterDNS` 关闭时必须返回上游答案而非合成屏蔽；`handleBlockedDomain` 用动态响应 |
| `engine_encrypted_dns_test.go:13,34,50` | 「阻断加密 DNS (DoT)」开关（曾死开关） | 新引擎 **fail-closed**；仅 **853** 端口算加密 DNS，其他端口不得吞；nil 引擎不 panic |
| `engine_full_tunnel_test.go:68,96,122,151,171` | 出站 TUN 写失败自愈 | 瞬态失败重试后投递（3 s 内）；耗尽预算后丢包但 goroutine 存活；**降级态单次尝试**（40 次退避不得重付，`elapsed <= 2 s`、`writeFailures>=11`）；`halt()` 幂等；队列满时写不阻塞 |
| `engine_lifecycle_test.go:17,37,50` | Stop 契约（A-017） | Stop 后 dnsCache 报 closed；二次 Stop 为 no-op；cert 缓存同释 |
| `engine_session_race_test.go:18,42,62` | `sessionGen` 代际（O-104） | 启动窗口内 Stop 使在途 StartFull 失效（即便 running 已被新会话置回 true）；无中断时代际仍有效；无隧道运行时 Stop 也必须 bump 代际，且顺带释放 cache（A-017 不得回归） |
| `engine_app_allowlist_test.go:103,129,164,216` | 应用白名单 IP 授权跨缓存快路径 | 缓存命中/stale 分支也须授权；负应答**不得**授权；按域扇出要覆盖 UIDUnknown(netd)；TTL 内授权有效 |
| `engine_response_chain_test.go:63,78,103,124,134,144,154` | CNAME 链二次核查 | 白名单只豁免首跳，后续跳仍屏蔽；HTTPS(65)/SVCB(64) `TargetName` 参与；未激活引擎/无规则跳过；无链则原样；大小写与尾点归一 |
| `engine_rewrite_test.go:11,45,61,71,84,106,125,138` | 覆写规则解析与查询 | 字符串/数组双形态；`github.com→140.82.112.3`、`example.com→93.184.216.34 / 2606:2800:220:1:248:1893:25c8:1946`、CNAME `alias.example.org→origin.example.net`；后缀匹配与大小写无关；`notgithub.com` 不得命中；IP 条目不做 CNAME；空内容清空；`ResolveDomain` JSON `source` = rewrite/blocked + `reason`；IPv6 只有 v4 覆写时落到上游路径返回 `"tunnel resolver not active"` |
| `flow_outbound_test.go:11,58` | 代理出站状态 | UDP 不支持必须回 `errOutboundUDPUnsupported` 且**不上报错误状态**；ready/error 去重后事件序列精确匹配 expected 列表 |
| `mitm_cosmetic_test.go:24,42,63,83,89,100` | 化妆 CSS 编译 | 域内规则不得外泄；`#@#` 例外覆盖 hide（全局例外在 host 走完后仍生效）；空载荷样式表；`<link>` 带 host、无 host 时不带 query；`serveCss` 按请求 Host |
| `mitm_trust_test.go:19,41,55` | 内嵌根证书 | ISRG 根可解析、`IsCA=true`、未过期；上游根池含两枚内嵌根；EV 判定 |
| `mitm_wrap_test.go:44,83,106` | 注入响应自定界 | 必须有边界（Connection: close / chunked / Content-Length）；HEAD 保帧；大 body 不得整体缓冲（流式） |
| `packet_pipe_test.go:14,31,49,70,85` | 池化包管道 | push/read、write/pop 往返；超限绕过池（cap 不在池尺寸类内）；close 后 `io.EOF` 且 Write 不报错；并发生产者 |
| `policy_special_rules_test.go:9,47,90,133` | Go 策略引擎特殊规则 | denyallow、正则、dnstype（`AAAA` 只拦 AAAA、`~A` 反向、`A\|AAAA`）；**优先级六档**：app-important block > global important > app allow > global allow > app normal block > global normal block，逐例验证跨档压制 |
| `traffic_tracker_test.go:54,102,116,131` | 流量包装 | `CloseWrite` 仅在被包传输支持时再声明；转发错误不得吞；`uid<=0` 原样返回；字节记账 Read→Tx、Write→Rx |
| `bootstrap_resolver_test.go:56,87,123` | 引导解析器 | 初始权重 1.0；快应答 >1.0；**3 次连续失败进入 coolingDown 且罚权 <0.5**；快慢 IP 计划分配显著差异；`ResetStats` 后 health map 为空；mock 解析得 `93.184.216.34` |

## 8. 资源与备份规则清单

### 8.1 图片与图标

- `res/drawable`（**10** 文件）：`default_avatar.webp`、`dns_svgrepo_com.xml`、`ic_launcher_foreground.xml`、`ic_launcher_monochrome.xml`、`ic_notification.xml`、`ic_overlay_close.xml`、`ic_overlay_minimize.xml`、`ic_overlay_resize.xml`、`ic_play_arrow.xml`、`ic_splash_squircle_logo.xml`。
- `res/mipmap-anydpi-v26`（**2**）：`ic_launcher.xml`、`ic_launcher_round.xml`（自适应图标；无密度位图目录，说明纯矢量/自适应）。
- `res/values` 目录：`values`(colors/strings/themes)、`values-en`(strings)、`values-night`(colors/themes)、`values-v31`(colors)、`values-night-v31`(colors)。`colors.xml` 各 4 个 `name=`（v31 变体 3 个）、`themes.xml` 2 个。

### 8.2 字符串规模与中英对齐

| 文件 | `<string` 计数 | `name="` 计数 |
|---|---|---|
| `res/values/strings.xml` | 216 | 216 |
| `res/values-en/strings.xml` | 216 | 219 行 / 216 键 |

键集合 **完全相同**：`comm -23/-13` 双向差集为空（0 条仅中、0 条仅英）。无 `<string-array>` / `<plurals>` / `<bool>` / `<integer>`（类型计数仅 `<string` 216）。即 XML 资源只承载外壳文案，**业务翻译在主源 `ui/localization/*` 的 Kotlin 字典里**（12 文件，仅 6 个被测试触及），这是 Flutter 侧真正的本地化工作量。

### 8.3 `res/xml` 逐项语义（影响数据迁移）

- `backup_rules.xml`：注释明确「ignored for devices older than API 31」；`<full-backup-content>` **体内容全部被注释**（模板状态）→ 无显式 include/exclude → Android 采用**全量默认备份**（sharedpref、files、databases 等）。
- `data_extraction_rules.xml`：`<cloud-backup>` 内是 `TODO` 注释、`<device-transfer>` 整段注释 → 云备份与设备迁移均为**默认全量**，无任何敏感数据排除。
- `file_paths.xml`（FileProvider 4 条映射）：`app_update`→`files-path app-update/`；`crash_logs`→`files-path crash_logs/`；`crash_export`→`external-files-path Download/`；`crash_export_private`→`files-path downloads/`（附 **O-125** 注释：`getExternalFilesDir()` 不可用时回落 `File(filesDir,"downloads")`，缺此映射则 `getUriForFile` 抛异常、已写文件永久孤立；须与 `CrashLogManager.PRIVATE_DOWNLOAD_DIR_NAME` 同步）。
- `locales_config.xml`：`zh`、`en`（与 `values-en` + `locales_config` 共同构成 per-app-language）。
- `AndroidManifest.xml:21-23`：`allowBackup="true"` + `dataExtractionRules="@xml/data_extraction_rules"` + `fullBackupContent="@xml/backup_rules"`。

### 8.4 `recognition_members.json`（项目根，schema 逐字段）

```jsonc
{
  "version": 1,                     // int，实测 1
  "sponsors":   [ { "name": string, "avatarFileName"?: string } ],   // 15 条
  "coBuilders": [ { "name": string, "avatarFileName"?: string } ]    // 11 条
}
```

- 两数组字段集相同（仅 `name`、`avatarFileName`）；`avatarFileName` **可缺省**：`sponsors` 有 2 条无头像（`轻`、`七月柠檬`），`coBuilders` 全部有头像。
- 去重后 `avatarFileName` **17** 个，全部在 `avatars/` 存在（缺失 0）；`AceTaffy1883 / alone / 恐龙复生 / 理塘丁真 / 睿上源 / 天涯浮客 / 心疼头头哥` 同时出现在两个数组。
- 该文件是**远程契约**而非本地资源：`RecognitionMembersRepository.kt:22` 从 `https://raw.githubusercontent.com/haoze-evolluling/DITING/main/recognition_members.json` 拉取，ETag 增量（`If-None-Match`/304→返回 null）、`MAX_CONFIGURATION_BYTES = 256*1024`、OkHttp 15 s/30 s 超时、缓存写 `recognition_members.json`、prefs `"recognition_members"` 存 `etag`；头像文件名白名单正则 `[a-z0-9_]+_avatar\.jpg`、单文件上限 `1_024*1024`、目录 `File(filesDir, "recognition_avatars")`。
- **实测目录/命名不一致（待定影响）**：`DataCleanupManager.kt:546-548` 清的是 `File(filesDir,"avatars")`、`File(cacheDir,"recognition")`、prefs `"diting_recognition_members"`，而写入侧是 `filesDir/recognition_avatars`、prefs `"recognition_members"`，`cacheDir/recognition` 在 main 侧 grep 无任何生产者。三处名称互不重合 → 「清理」实际清不到东西。属 `AGENT_MISTAKES.md` A-016/O-145 同型缺陷，Flutter 重写时须统一到单一命名（不改现有行为，仅记录）。
- `avatars/` 目录：**18** 文件（17 个 `*_avatar.jpg` + `default_avatar.png`），合计 736 K；`default_avatar.png` 未被 JSON 引用（`res/drawable/default_avatar.webp` 才是 `R.drawable.default_avatar`，用于 `RecognitionListContent.kt:100`）；`avatars/default_avatar.png` 作为 GitHub 原始文件的镜像，是否被 URL 消费 → 待定。
- `assets/https_passthrough.txt`：唯一 assets 文件，`DefaultWhitelistSeederPresetTest.kt:45` 钉其恰 5 个连通性域。

## 9. 关键引证表（路径:行）

| 主张 | 引证 |
|---|---|
| 测试依赖只有 junit4.13.2 + org.json | `Android/app/build.gradle.kts:234-235`；`Android/gradle/libs.versions.toml:14,36-37` |
| 无 MockK/Robolectric/coroutines-test | 全测试源集 grep 命中 0；`core/diagnostic/HealthStoreJsonTest.kt:17` 注释自陈 |
| 585 个 `@Test` | `grep -rc "@Test"` 求和；`ui/agent/MarkdownBlockTest.kt` 3 处 `@Test(timeout = 2000)` 为仅存超时钉 |
| 身份必须 `===` | `util/LatestRequestGateTest.kt:57-72,103-111`；`core/diagnostic/HealthEngineRegistryTest.kt:97` |
| 位表权威 | `express/ExpressPacketCodecTest.kt:17-39`(RFC1071), `:150-223`(RST 0x14/0x04/seq=ack/不 RST 回 RST), `:225-273`(三分片 reason 字面量), `:297-326`(TTL 300→250/600/过期 null) |
| 位表权威（报文） | `express/ExpressDnsMessageUtilsTest.kt:80-106`（`[4..5]/[6..7]/[8..9]/[10..11]` 逐段计数与无 SOA）；`core/dns/DnsMessageUtilsTest.kt:13-56` |
| 规则解析负例 | `core/rule/AdGuardRuleParserTest.kt:321-323,348-350,366-368`（invalid/unsupported 计数）；`AdblockRuleLineParserRegexHashTest.kt:24-119`；`AdblockRuleLineParserNegatedModifierTest.kt:23-77`；`AdblockRuleLineParserCosmeticDelimiterTest.kt:59-78` |
| IP 字面量负例集 | `core/dns/DnsProviderIpLiteralTest.kt:25-68`（含 `2001:db8::1::2`、`[::1]:53`、`256.1.1.1`） |
| 解析器 leniency 必须保留 | `core/dns/DohUrlParserTest.kt:58-73`（`https:///dns-query`→host `dns-query`） |
| race / 代际边界 | `express/ExpressLifecycleGuardTest.kt:20-72`；`server/DnsModeStartGuardTest.kt:22-70`；`notification/VpnMonitorLifecycleStateTest.kt:20-113`；Go `engine_session_race_test.go:18-72` |
| TTL 0 vs 未知 | `core/cache/DnsResponseCachePersistenceTest.kt:260,274`；`normal/GoTunnelLogProcessorUpstreamTtlTest.kt:26-76` |
| 数值权威：EWMA/冷却 | `core/diagnostic/HealthSnapshotMathTest.kt:56,100,113-114,198`；`core/diagnostic/HealthSnapshotMath.kt:13-17` |
| 数值权威：限速 EMA | `core/traffic/TrafficSpeedEstimatorAppTickTest.kt:21-103` |
| 数值权威：TUN 常量 | `express/ExpressVpnIntegrationTest.kt:29-38`（10.0.0.2/10.0.0.1/fd00:abcd::2/::1/**1400**/2001） |
| 数值权威：通知 ID | `notification/ServiceStartupDefectFixTest.kt:23-29`、`VpnNotificationIdConflictTest.kt:20-36` |
| 数值权威：模式 API 门 | `ui/WorkModeTest.kt:30-32`（NORMAL 29 / DNS 29 / EXPRESS 24） |
| 数值权威：端口 | `server/DnsModePortAndFilterSwitchTest.kt:74-111`；`server/DnsModeTest.kt:320-321`；`DnsListenPortMigrationTest.kt:20-21` |
| 与 Go 的 JSON 契约 | `server/DnsDynamicBlockJsonTest.kt:33-121`；Go `engine_block_response_test.go:78-97` |
| 备份全默认 | `res/xml/backup_rules.xml`、`res/xml/data_extraction_rules.xml`（体内容皆注释）+ `AndroidManifest.xml:21-23` |
| FileProvider 4 路径 | `res/xml/file_paths.xml`（含 O-125 注释） |
| 清理命名不重合 | `data/cleanup/DataCleanupManager.kt:546-548` vs `ui/RecognitionAvatarRepository.kt:21,139` vs `ui/RecognitionMembersRepository.kt:26` |

## 10. Flutter 重构注意

### 10.1 应直接移植为 Dart golden test 的测试（判据：**纯函数/纯数据 + 期望值明确 + 不触 Android API**）

第一优先（协议/位段/解析，文档无法替代）：

1. `core/rule/AdGuardRuleParserTest.kt` + 三个 `AdblockRuleLineParser*Test.kt`（407/95/78/121 行）——规则语法正负例全表，含 badfilter key 字面量集合。
2. `express/ExpressPacketCodecTest.kt`、`express/ExpressDnsMessageUtilsTest.kt`、`core/dns/DnsMessageUtilsTest.kt`——RFC 1071 向量、TCP 状态机位/标志值、DNS 头部逐段计数。
3. `core/dns/DnsProviderIpLiteralTest.kt`、`core/dns/DohUrlParserTest.kt`——输入→布尔/字符串映射，负例即规格。
4. `util/DateTimeUtilsTest.kt`——**字面 epoch 向量**（`1772946000000L` 等 30+ 个）+ 跨时区性质检查（`resultIsAlwaysTheFirstInstantOfItsOwnLocalDay…`）。Dart 用 `timeZone`/`DateTime` 重写时，同一批毫秒值必须原样保留为 golden。
5. `core/diagnostic/HealthSnapshotMathTest.kt`、`core/traffic/TrafficSpeedEstimatorAppTickTest.kt`、`core/log/LogMaintenanceTrafficRetentionTest.kt`、`ui/traffic/TrafficSessionClockTest.kt`、`update/AppUpdateProgressThrottleTest.kt`、`util/LatencyWindowTest.kt`、`server/DnsModeTest.kt`（stats 部分）——纯算术 + 常量阈值。
6. `util/KeyObfuscatorTest.kt`、`util/Base64Codec` 向量、`ui/AiProviderTest.kt`——`Zg==/Zm8=/Zm9v/Zm9vYmFy` 已知向量；注意 A-032：Android 侧曾误用 API26 `java.util.Base64`，Dart 侧 `base64` codec 直接可用但**向量不变**。
7. `util/LatestRequestGateTest.kt`、`util/SafGrantDecisionsTest.kt`、`core/diagnostic/HealthEngineRegistryTest.kt`——身份/所有权决策表；Dart 注意：`identical()` 对应 `===`，「结构相等但不同实例」的用例必须成对保留，否则重演 A-051。
8. `express/ExpressLifecycleGuardTest.kt`、`server/DnsModeStartGuardTest.kt`、`normal/RuntimeConfigCommitPolicyTest.kt`、`notification/VpnMonitorLifecycleStateTest.kt`——代际/提交决策表（后者含 Android fg 语义，可拆成纯状态机 + 平台胶水）。
9. `ui/BottomBarDestinationTest.kt`、`express/ExpressNavigationTest.kt`、`express/ExpressDataCleanupAndHiddenFeaturesTest.kt`、`express/ExpressResidualScreensTest.kt`、`express/ExpressDynamicBlockSupportTest.kt`、`ui/settings/CnameRewriteOperationalTest.kt`、`ui/dashboard/DashboardLogLabelsTest.kt`、`ui/WorkModeTest.kt`、`permission/*`、`ui/localization/LogsAndStatsFilteredEmptyMessageTest.kt`——功能裁剪/映射/文案决策表（含精确中文字面量，Flutter 侧字典须逐字对齐）。
10. `ui/agent/MarkdownBlockTest.kt` + `MarkdownInlineAnnotatorUnderscoreTest.kt`——解析 AST + span 样式 golden；3 个 2 s 超时用例是防死循环，Dart 侧改为显式输入长度上限。
11. `ui/BatchRuleValidatorTest.kt` + `BatchRuleAppScopeAndUrlNormalizationTest.kt`、`core/rule/CategorizedRuleStreamImporterTest.kt`、`core/rule/CosmeticRuleManagerTest.kt`、`core/diagnostic/HealthStoreJsonTest.kt`、`server/DnsDynamicBlockJsonTest.kt`——批次校验与 JSON 结构（后两者可直接搬 `dart:convert`）。
12. `core/cache/DnsResponseCachePersistenceTest.kt`、`express/ExpressRoomDnsCacheTest.kt`、`core/log/DnsLoggerTest.kt`、`core/log/LogWriterFailureIsolationTest.kt`、`core/rule/SubscriptionAutoUpdateEngineTest.kt`、`data/cleanup/DataCleanupManagerTest.kt`、`core/rule/SubscriptionImportRecoveryStagingTest.kt`——**把 Kotlin 的 `Fake*Dao` / JDK 动态代理换成 Dart fake**，断言「哪个方法被调了几次」的规格逐条照搬（批量 50、hitCount 保留、异常不外抛、clear 竞态不复活）。

不可移植（须改写或放弃，见 §2.2）：9 个源码文本契约测试（`RewriteCnameDeliveryTest` 的一半其实等价于 Go 侧 `engine_*` 行为测试，可用 Go 测试补位）；纯 Android API 钉（`FloatingLogWindowTypeTest`、`NotificationSettingsIntentFallbackTest`、`AppNotificationChannelsRegistryTest`、`AppUpdateDirectoryContractTest`、`WorkModeLifecycleRegistryPrefsTest`）。

### 10.2 备份规则 → Flutter 数据迁移对应点

1. **当前 = 全量默认备份**：`backup_rules.xml`/`data_extraction_rules.xml` 均是未填写的模板，`allowBackup="true"`，故 Android 会把 `dns_vpn_prefs`、`diting_express_prefs`、`diting_dns_mode_prefs`、`diting_settings`、`diting_crash_state`、`recognition_members` 六个 prefs 文件 + Room 三库（`diting_database`、`diting_dns_rules`、ExpressRulesDatabase）+ `files/` 整体纳入云端备份与设备转移。**没有任何被显式排除的敏感数据**（注意 `OutboundProxySettingsStore` 用 Android Keystore alias `diting_outbound_proxy` 加密代理凭证，密钥本身不备份；`KeyObfuscator` 的 provider key 却是明文 prefs → 迁移时须决定新存储位置）。
2. Flutter 迁移须逐名对应：prefs 名是测试钉死的字符串（`ExpressDataIsolationTest.kt:16-18`、`ExpressLogModeAndDataIsolationTest.kt:49-55`），改名会同时破坏三模式数据隔离规格与 `DataCleanupCustomBackgroundContract`/`WorkModeLifecycleRegistryPrefs` 两条「必须落在真 store」的行为；`shared_preferences` 的 key 前缀方案要保留「同一逻辑键跨数据集互不可见」这一断言。
3. FileProvider 四路径（`file_paths.xml`）对应 Flutter 侧的 `app-update/`、`crash_logs/`、`Download/`、`downloads/` 导出/分享目录；`downloads` 私有回落路径是 O-125 修复的一部分，导出逻辑重写时必须保留「外部不可用→私有目录→URI 仍可分享」这条链，否则备份文件孤立。
4. 版本/遗留值迁移必须照搬的行为：`DnsListenPortMigration`（5353/5354→1053，但**不得**改写其它不可绑定值）、`ConfigTransferParserOutboundProxyTest`（format v9 兼容含凭证、v10 无凭证，缺字段=不动本地）、`NotificationTextsImportMergeTest`（逐字段合并语义）、`DefaultWhitelistSeeder` 播种与 `shouldMarkInitialized`、`WhitelistEditDemotesPresetSource`（编辑即降级为 `useradd`）、`CrashLogManager` 24 h 连胜窗口与「水位只升不降」。
5. `recognition_members.json` / `avatars/` 是 **GitHub raw 远程契约**（URL、ETag、256 KB/1 MB 上限、15/30 s 超时、`[a-z0-9_]+_avatar\.jpg` 文件名正则、`filesDir/recognition_avatars` 缓存目录）——Flutter 若换目录或换 prefs 名，须同步 `DataCleanupManager` 侧的清理命名（§8.4 实测三处不重合）。

### 10.3 规模与口径提示

- Kotlin 99 文件 / 11 394 行 / 585 用例 vs Go 21 文件 / 3 834 行 / 102 用例 + 1 基准；main 522 文件引用率 34.7%（类名口径 31.4%）。**无 androidTest 源集**（`Android/app/src` 仅 `main`+`test`），即全部行为规格都在 JVM 层，UI/权限/服务壳规格在测试里不存在——这部分必须靠重构前补齐 Dart 测试，不能指望「移植测试」得到等价覆盖。
- 三模式分布修正见 §6.1：服务器模式并非「几乎无测」（45 个 `@Test`、`server/model` 100% 触及），真正空白是其 UI/服务壳 0%；普通模式逻辑侧才是最薄（358 行 / 19 用例）。
