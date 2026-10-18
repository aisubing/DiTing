# 01（续）基础设施、配置与工程构建 — 配置键字典 / 构建体系 / Manifest / 引证

```yaml
所属系列: DITING Android Flutter 重构功能图谱
章: 01-2（本篇是 01-foundation-and-startup.md 的续篇，第 1–2 节见彼篇）
最后校验: 2026-10-18
口径: main 源码 522 个 Kotlin 文件全部点名（find app/src/main -name "*.kt" 实测 522；test 实测 99）；数字均为本会话工具实测
```

## 3. 配置键全量字典

### 3.0 容器总览（实测：全应用 0 个 Jetpack DataStore，`preferencesDataStore|createDataStore` grep = 0 命中；持久层 = 9 个 SharedPreferences 文件 + 1 个幽灵容器）

| 容器文件名 | 归属 | getSharedPreferences 引用点（实测计数） |
|---|---|---|
| `dns_vpn_prefs` | RuleDataset.NORMAL + 全局 UI 设置混装 | 126 处经包内常量 `PREFS_NAME`（SettingsPreferencesExtensions.kt:8，同包 10+ 个 Store 文件无本地定义直接复用）+ AppLanguageManager.kt:23、DnsProvider.kt:53、DnsVpnStatusNotifier.kt:13、VpnStateRegistry.kt:11,26、RuleDataset.kt:25 |
| `diting_express_prefs` | RuleDataset.EXPRESS | RuleDataset.kt:26；写入者：dataset 感知型 Store + ExpressDefaultsSeeder |
| `diting_dns_mode_prefs` | RuleDataset.DNS_MODE | RuleDataset.kt:27、DnsModePreferences.kt:16、DnsRuleSettings.kt:15 |
| `express_vpn_prefs` | Express 运行标志 | ExpressVpnController.kt:32、VpnStateRegistry.kt:17 |
| `diting_settings` | 工作模式选择 | WorkModeStore.kt:6 |
| `permission_disclosures` | 权限披露 | PermissionDisclosureStore.kt:6、AppListPermissionHelper.kt:26 |
| `mode_permission_preferences` | 分模式引导/建议忽略 | ModePermissionStore.kt:10 |
| `notification_settings_prefs` | 通知设置 | NotificationSettingsStore.kt:10 |
| `diting_crash_state` | 崩溃计数 | CrashLogManager.kt:35 |
| `network_tools_settings` | 网络工具隧道开关 | NetworkToolsSettingsStore.kt:11 |
| `recognition_members` | 名单 ETag | RecognitionMembersRepository.kt:26 |
| `diting_recognition_members` | **幽灵容器：唯一引用是 `clear()`**（DataCleanupManager.kt:548），读写方实际用 `recognition_members`——清理从未命中（缺陷候选，见第 6 节 R-14） |

> dataset 感知键（下表标 `按dataset`）同时存在于三个 dataset 容器；全局键只落 `dns_vpn_prefs`。`readStringSet/writeStringSet`（SettingsPreferencesExtensions.kt:14-28）把 Set 序列化为排序 JSONArray 字符串——迁移时注意 StringSet 键实际多为 String(JSON) 存储。
> **完整性审计（2026-10-18 Lead 复核后补）**：对 `ui/settings/*.kt` 全部字符串字面量（实测 195 个 ≥4 位小写 token）与本字典做 set 差集（87 项），逐项分类：全部为枚举 storageValue（system/disabled…）、JSON 协议字段（choices/messages/usage/role/content/model_id…）、AI 厂商 id（builtin_*/preset_deepseek…，其中 `migrated_default` 为 AgentApiSettingsStore.kt:356 的 AiProvider 实例 id 非 prefs 键）、FileProvider/KeyStore alias（diting_outbound_proxy :156）、容器名本身、HiddenFeature 分类名（app_rules/network_control…，存于 hidden_features_set 值域非键）——**无遗漏键**。字典收录数由合并行拆分后 = 见 §3.0-A/B/C/D 各表逐行计数。agent_* 系列确认容器为 `dns_vpn_prefs`（AgentApiSettingsStore 无本地 PREFS_NAME，解析到包内常量 SettingsPreferencesExtensions.kt:8）。

### 3.1 键字典（键名 | 容器 | 类型 | 默认值 | 定义行 | 主要消费方 | 说明）

**A. 全局身份/外观（`dns_vpn_prefs`，全局）**
| 键 | 类型 | 默认 | 定义 | 消费 | 备注 |
|---|---|---|---|---|---|
| app_language_mode | String | "system" | AppLanguageManager.kt:24 | AppLocalizedActivity:13, MainActivity:219 | system/zh/en |
| app_theme_mode | String | system(回退) | AppearanceSettingsStore.kt:12 | MainActivity:91 等三宿主 | 非法值→SYSTEM（AppThemeMode.kt:13） |
| theme_color_style | String | system(回退) | :13 | 同上 | AppTheme.kt:38 回退 SYSTEM |
| home_component_opacity | Float | 1f, 钳[0.1,1] | :15 | 主页 | DEFAULT_HOME_COMPONENT_OPACITY :10 |
| home_power_button_opacity | Float | 跟随 home_component_opacity | :16 | 主页 | getHomeOpacity 二级回退 :67-71 |
| home_provider_selector_opacity | Float | 同上 | :17 | 主页 | |
| home_mode_button_opacity | Float | 同上 | :18 | 主页 | |
| home_poem_opacity | Float | 同上 | :19 | 主页 | |
| home_dns_detail_opacity | Float | 同上 | :20 | 主页 | |
| home_sentence_running / home_sentence_stopped | String | "谛听万象，明察清浊" / "收耳静眠，归于无声"（硬编码中文默认） | :21-22 | 主页诗句 | :102,:108 |
| custom_background_enabled | Bool | false | :23 | MainActivity/CustomBackgroundManager | 生效条件 enabled=true **且** 当前 uri ∈ uris 列表 :120-124 |
| custom_background_uri | String? | null | :24 | 同上 | StartupSelfCheck 可清除 |
| custom_background_uris | String(JSONArray) | 空 | :25 | 同上 | 去重 :140 |
| bottom_bar_destinations | String(JSON) | [HOME,FEATURE_HUB,LOG_DASHBOARD] | :14 | 主页底栏 | BottomBarDestination.kt:78,82-97（数量上限 MAX_COUNT 截断） |
| bottom_bar_haptic_enabled | Bool | true | :26 | 底栏 | |
| excluded_app_packages | StringSet | 空 | AppRulesSettingsStore.kt:10 | Normal 引擎 app 排除 | 全局容器（非 dataset） |
| excluded_apps_filter | String | "USER" | :11 | 应用选择器 | |
| excluded_apps_sort | String | "LABEL_ASC" | :12 | 应用选择器 | |
| blocked_app_packages | StringSet | 空 | :13 | 联网封锁 | 读写剔除自身包名 :78,96 |
| blocked_apps_enabled | Bool | false | :14 | 联网封锁 | |
| blocked_apps_filter | String | 继承 excluded_apps_filter | :15 | 联网封锁 | |
| blocked_apps_sort | String | "LABEL_ASC" | :16 | 联网封锁 | |
| app_allowlist_enabled | Bool | false | :17 | 应用放行 | |
| app_allowlist_filter | String | "USER" | :18 | 应用放行 | |
| app_allowlist_sort | String | "LABEL_ASC" | :19 | 应用放行 | |
| app_allowlist_rules_json | String(JSON pkg→domains) | 空 map | :107 | AllowList 引擎 | 剔除自身/空白 :118,138 |
| http_inspection_enabled | Bool | false | :20 | HTTPS 检查开关面 | |
| http_inspection_app_packages | StringSet | 空 | :21 | HTTPS 检查开关面 | |
| http_inspection_apps_filter | String | 继承 excluded_apps_filter | :22 | HTTPS 检查开关面 | |
| http_inspection_apps_sort | String | "LABEL_ASC" | :23 | HTTPS 检查开关面 | |
| https_inspection_ready + https_inspection_ca_backend | Bool + String | false + 无 | :24-25 | 判定 = ready && backend=="go-v1" | :246-251；backend 常量 :40；CA 重装即失效重确认 :269-278 |
| https_bypass_rules | StringSet | 空 | :26 | MITM 旁路 | |
| http3_inspection_enabled | Bool | false | :27 | QUIC 检查 | |
| encrypted_dns_blocking_enabled | Bool | false | :28 | DoT/DoH 出网阻断 | |
| address_rules_enabled | Bool | true | :30 | 地址规则总开关 | 全局容器 |
| {user_providers_json, selected_provider_id} | String(JSON)/String | 无 / 回退 preset_alidns_dns→PRESETS.first | DnsProvider.kt:54-56,211-220 | 服务商选择 | **按dataset**（prefs() :200 用 dataset.prefsName()） |
| agent_api_enabled | Bool | **true** | AgentApiSettingsStore.kt:252 | AI 旁路分析 | 全局容器；:266 默认开 |
| agent_api_key | String | "" | :253 | 同上 | **KeyObfuscator.seal 混淆存储** :332-336（非加密） |
| agent_api_base_url | String | https://api.deepseek.com/v1 | :254 | 同上 | DEFAULT_BASE_URL :21；空白亦回退 :269-270 |
| agent_api_model | String | "deepseek-flash" | :255 | 同上 | DEFAULT_MODEL :28；缺失或空白均回退 :264,271 |
| agent_api_temperature | String(存 double 文本) | "0.7"（读侧 toDoubleOrNull 失败/缺失→DEFAULT_TEMPERATURE=0.7，:29） | :256 | 同上 | 以 String 存取：写 :271-272 区段 setAgentApiConfig(:278-287) 用 toString、读用 toDoubleOrNull——迁移勿当 Number |
| agent_api_system_prompt | String | ""（orEmpty） | :257 | 同上 | trim 后落盘 :286 |
| agent_ai_providers_json | String | 首次迁移初始化 | :259 | 厂商列表 | getProviders 空时 performInitialMigration :294-299 |
| agent_ai_active_provider_id | String | "" | :260 | 同上 | |
| agent_api_custom_presets | String | — | :62 | 预设管理 | |
| agent_api_preset_order | String | — | :63 | 预设管理 | |
| hidden_features_set | StringSet | 空 | HiddenFeaturesStore.kt:267 | 功能隐藏面 | @Volatile initialized + StateFlow 缓存 :270-282 |
| outbound_proxy_{enabled,protocol,host,port,username,password,app,status,status_message} | 混合 | false/—/"127.0.0.1"/7890/AES密文/""/""/"disabled"/"" | OutboundProxySettingsStore.kt:18-26 | 出站代理 | username/password 用 AndroidKeyStore AES/GCM（密钥 alias `diting_outbound_proxy`，IV 前置拼接 Base64）:154-188；进程内 cachedConfig 双检锁 :34-51 |
| settings_guide_acknowledged_ids | StringSet | 空 | SystemSettingsStore.kt:24 | 引导条 | resetAllSettingsGuides 连带 ModePermissionStore.clearDismissedRecommendations（O-146 注释）:197-209 |
| initial_agreement_accepted | Bool | false | :25 | MainActivity 首屏门 | 拒绝→finishAndRemoveTask |
| data_reset_notice_pending | Bool | false | :26 | 数据重置提示 | |
| hide_from_recents_enabled | Bool | false | :11 | RecentsPrivacyController | MainActivity onResume 重apply |
| bypass_lan_enabled | Bool | **true** | :12,13 | VPN 路由 | |
| floating_log_enabled / floating_log_panel_size | Bool/Int | false / 0 钳[0,2] | :18-19 | 悬浮日志 | 全局容器 |
| main_activity_foreground | Bool | **true** | :20 | FloatingLogOverlayController.kt:62 | 崩溃后残留 true 会被 onStart 纠正 |
| app_update_download_path / _version | String | "" | :21-22 | AppUpdateManager | 下载断点续用 |
| disable_startup_update_check | Bool | **true=默认不检查**（语义反装） | :23 | MainStartupCoordinator.kt:41 | 注意键名与默认值方向 |
| app_traffic_stats_enabled / traffic_stats_retention_days / traffic_stats_hide_system_apps | Bool/Int/Bool | true / 30 钳[1,90] / false | :27-29,32 | 流量统计 | |
| app_list_explained | Bool | false | AppListPermissionHelper.kt:27 | InstalledAppPickerComponents.kt:330-448 | 权威读写在此；PermissionDisclosureStore.kt:7 的同名 KEY_ 常量**零读写**（方法已委托 Helper）→死 |
| vpn_explained / vpn_was_granted | Bool | false | PermissionDisclosureStore.kt:9-10 | MainVpnController:99-115, updateVpnGrant 撤权时清 explained :36-45 | |
| vpn_running | Bool | false | DnsVpnStatusNotifier.kt:14（另有 VpnStateRegistry.kt:12,26 字面量默认实现） | 崩溃自愈：flag && !serviceAlive → 改写 false | DnsVpnService.kt:455 init 把注册表钩替换为服务实况 |

**B. dataset 感知键（同时存在于 dns_vpn_prefs / diting_express_prefs / diting_dns_mode_prefs*，\*DNS_MODE 有独立同名异源键见 D）**
| 键 | 类型 | 默认 | 定义 | 备注 |
|---|---|---|---|---|
| dns_resolution_mode | String | single | ResolutionSettingsStore.kt:17 | StartupSelfCheck 修复点① |
| preset_dns_service | String(枚举名) | DNS | :18 | |
| race_provider_ids | String(JSON Set) | {preset_alidns_dns, preset_dnspod_dns} | :13 | |
| race_test_domain | String | "mihoyo.com" | :14,31 | 空/空白回退默认 :91-104 |
| latency_test_provider_ids | String(JSON Set) | 空 | :15 | |
| smart_prediction_provider_ids / parallel_race_provider_ids | String(JSON Set) | 同 race 默认对 | :19-20 | |
| primary_backup_provider_ids | String(JSON List 有序去重) | 同上 .toList() | :21 | 顺序有意义 |
| home_visible_protocols / home_hidden_provider_ids / home_visible_provider_ids | String(JSON Set) | DnsProtocol.MANAGED_PROTOCOLS / 空 / 空 | :22-24, HomeProviderVisibility.kt:6 | |
| bootstrap_enabled | Bool | true | BootstrapDnsSettingsStore.kt:13 | |
| bootstrap_preset_ids | String(JSON Set) | {preset_volcengine,preset_dnspod,preset_alidns} | :14-22 | 写入过滤非法 id :106-108 |
| bootstrap_custom_json | String(JSONArray) | 空 | :15 | 自校验 IP 合法性读写两侧 :65,125,148 |
| dns_cache_enabled_v2 | Bool | true | DnsCacheSettingsStore.kt:10 | **键名带 _v2/_v3 版本后缀** = 历史键换代 |
| dns_cache_mode_v2 | String | limit_max_ttl | :11 | follow_dns_ttl/limit_max_ttl/fixed_ttl（DnsCachePolicy.kt:10-12） |
| dns_cache_{max,fixed}_ttl_seconds_v2 | Long | 3600/3600 钳[30,86400] | :12-13 | |
| dns_cache_min_ttl_enabled_v2 / _seconds_v2 | Bool/Long | false/60 钳上 | :14-15 | |
| dns_cache_stale_fallback_enabled_v2 / _seconds_v2 | Bool/Long | false/300 钳上 | :16-17 | |
| dns_cache_preset_v3 | String | null→从 policy 反推 | :18,61-65 | 双写：setPolicy 同步落 preset :84-96 |
| dns_log_mode | String | all | SystemSettingsStore.kt:17 | |
| log_retention_days | Int | 7 钳[1,30] | :10,31 | |
| ipv6_mode | String | auto | :14 | |
| domain_rules_enabled | Bool | true | AppRulesSettingsStore.kt:29 | |
| block_response_mode | String | nxdomain | :31,41 | nxdomain/nodata/refused/zero_address（BlockResponseMode.kt:7-10） |
| dynamic_block_response_enabled / dynamic_block_request_threshold / dynamic_block_window_seconds / dynamic_block_nxdomain_duration_seconds | Bool/Int/Int/Int | false / 5 钳[2,100] / 60 钳[10,?] / 300 | :32-35, DynamicBlockResponsePolicy.kt:13-18 | NORMAL/EXPRESS 走这套；DNS_MODE 走 DnsRuleSettings 的**异名键**（见 D） |
| allow_edit_default_whitelist / default_whitelist_initialized / default_whitelist_seeded_version | Bool/Bool/Long | false/false/0 | :36-38 | seeded_version=0 表示"从旧版升级未记录"（:419 注释） |
| subscription_auto_update_enabled / subscription_auto_update_interval_hours | Bool/Int | false / 24 钳[1,168]，候选{6,12,24,48} | SubscriptionAutoUpdateScheduler.kt:33-34,35-38 | 同文件 :32 `private const PREFS="dns_vpn_prefs"` 零引用（死常量） |
| provider_health_json / bootstrap_health_json | String(JSON) | ewma 初值 250.0 | ProviderHealthStore.kt:67 / BootstrapHealthStore.kt:64 | per-dataset 隔离注释（防两引擎互相擦除）；读侧 merge 写 |

**C. 其他独立容器键**
| 键 | 容器 | 类型 | 默认 | 定义 | 消费 |
|---|---|---|---|---|---|
| app_work_mode | diting_settings | String | null→NORMAL | WorkModeStore.kt:7 | 全模式分发 |
| work_mode_initial_selected | diting_settings | Bool | false | :8 | MainActivity:134,185 |
| express_vpn_running | express_vpn_prefs | Bool | false | ExpressVpnController.kt:33 | 同 vpn_running 自愈逻辑（:80-89 persisted && ExpressVpnService.isServiceAlive） |
| express_initialized | diting_express_prefs | Bool | false | ExpressDefaultsSeeder.kt:37 | 沙箱初始化标记；工厂重置 forceReset 重种 :108 |
| onboarding_completed_{normal,dns,express} | mode_permission_preferences | Bool | false | ModePermissionStore.kt:11（前缀+storageValue 组合） | 各模式引导门 |
| permission_explained_{AppPermission.name} / recommendation_dismissed_{name} | mode_permission_preferences | Bool | false | :12-13 | VPN/NOTIFICATION/BATTERY_OPTIMIZATION/PACKAGE_QUERY/SYSTEM_ALERT_WINDOW（AppPermission.kt:36-60） |
| notification_persistent_enabled / notification_traffic_speed_enabled / notification_custom_{running,stopped}_text | notification_settings_prefs | Bool/Bool/String/String | true/false/""/"" | NotificationSettingsStore.kt:12-18 | 掉线提醒常驻通知 |
| ping_via_tunnel / dns_lookup_via_tunnel / traceroute_via_tunnel | network_tools_settings | Bool | 均 false | NetworkToolsSettingsStore.kt:12-14 | 网络工具是否经 Go 隧道解析 |
| consecutive_crash_count / has_manually_exported / last_crash_time / pending_auto_export_notice / last_recorded_native_exit_time | diting_crash_state | Int/Bool/Long/Bool/Long | 0/false/0/false/0 | CrashLogManager.kt:36-40 | 连 crash≥3（24h 窗口 :43-44）自动导出；崩溃路径用 **commit()** 同步落盘（:154-171 注释）；native 水位线防重复收割（:376-377,412,437-444） |
| etag | recognition_members | String | null | RecognitionMembersRepository.kt:27-28 | If-None-Match 增量拉取 |

**D. DNS_MODE 专属键（`diting_dns_mode_prefs`，DnsModePreferences.kt:18-36）**
| 键 | 类型 | 默认 | 说明 |
|---|---|---|---|
| selected_upstream_id | String | "preset_alidns_dns" | :70 |
| local_listen_port | Int | 1053（DnsListenPortValidator.kt:10） | 一次性迁移：旧默认 5353/5354（mDNS 冲突）→1053，由 local_listen_port_migrated 保证只迁一次（:44-56） |
| cache_enabled / cache_preset / cache_ttl_seconds | Bool/String/Int | true / BALANCED / 300 | :72-74 |
| ad_block_enabled | Bool | false | 服务器模式拦截总开关 |
| log_queries | Bool | false | 一次性迁移把历史 true 翻转（隐私默认）:58-66，由 log_queries_default_off 标记 |
| service_active | Bool | false | DnsModeBootReceiver.kt:20 重启恢复判据 |
| custom_upstreams | String(JSONArray) | 空 | :142-188 自/反序列化，protocol 非法回退 DNS |
| stats_{query_count,cache_hit_count,blocked_count,failed_count,latency_ms,latency_total_ms,uptime_seconds} | Long×7 | 0 | 运行统计持久化 :97-132 |
| block_response_mode | String | nxdomain | DnsRuleSettings.kt:17 — **与 B 表同名键在不同容器互不干扰** |
| block_response_dynamic_{enabled,threshold,window_seconds,nxdomain_duration_seconds} | Bool/Int/Int/Int | false/5/60/300 | :18-21 — 与 AppRules 的 dynamic_block_* **键名不同族**，重构勿混 |
| subscription_auto_update_{enabled,interval_hours} | Bool/Int | false/24 | :23-24 — 与 B 表同名键在 DNS_MODE 容器独立存 |

**E. Intent Extra / 广播 Action 键空间（非持久但同属"配置面"）**
- MainActivity：auto_start_vpn / main_work_mode_changed / main_target_work_mode（MainActivity.kt:241-243）。
- LogRouteActivity：log_route / log_request_source / log_dataset（:154-156）。
- SettingsRouteActivity：settings_* 前缀 12 个（实测 companion object 15 个常量含 EXTRA_RULE_*，SettingsRouteActivity.kt companion）。
- 服务 action 域：com.haoze.diting.{STOP_VPN, REFRESH_*, SYNC_*, FLOATING_LOG_APP_STATE}（DnsVpnIntentFactory.kt:14-40 实测 25 常量）与 express 同构（ExpressVpnIntents.kt 16 处常量）；广播 com.haoze.diting.VPN_STATUS_CHANGED（VpnStateRegistry.kt:32，接收方 MainViewModel.kt:103/AboutScreen.kt:213，发送方 ExpressVpnController.kt:171/MainWorkModeCoordinator.kt:159/DnsVpnStatusNotifier.kt:20）。

## 4. 构建与打包体系

### 4.1 版本策略
- `appVersionCode = 10403`、`appVersionName = "1.4.3"`（app/build.gradle.kts:15-18）；推导式 `major*10000+minor*100+patch` 由维护工具箱执行且**只增不减**（:14 注释；AGENT_MISTAKES.md 2026-10-17 工具条目：`max(旧值, 推导值)`、清单按全仓声明点维护）。1.4.3 → 10403 验证成立。
- APK 归档命名 `DITING-<type>-v1.4.3.apk` → `app/build/outputs/apk/versioned/<type>/`，由 `copy*ApkWithVersion` Copy 任务 + `assemble* finalizedBy` 实现（:180-198）。

### 4.2 签名链（无 keystore 即无 release 签名配置，可复现降级）
1. 按 6 个候选路径找 `keystore.properties`（Android/DITING-keystore/、Android/keystore/、Android/、仓库根三级镜像，:26-33）。
2. 属性缺失时逐项回退环境变量 `DITING_KEYSTORE_FILE/_PASSWORD/_ALIAS/_KEY_PASSWORD`（:41-48）。
3. storeFile 再按 4 基准目录解析（properties 同目录/仓库根/app 目录/上级，:50-62）。
4. storeFile+storePassword+keyAlias 三者齐备才 `create("release")`，keyPassword 缺省回退 storePassword；V1+V2+V3（无 V4）（:92-105）。
5. `-PsignDebugWithRelease=true` 时 debug 也用 release key（:64,110-114）——bat 菜单项 [3]。
6. 仓库实况：`Android/DITING-keystore/{diting-release.jks,keystore.properties}` 存在于本机但被 .gitignore 排除（.gitignore:31-42）；`git ls-files Android/app/libs/` 实测确认 **tunnel.aar(5,157,156B) 与 tunnel-sources.jar(26,991B) 是入库产物**。

### 4.3 Gradle 配置逐项（app/build.gradle.kts）
| 项 | 值 | 含义/风险 |
|---|---|---|
| plugins | AGP 9.2.1(toml) + kotlin-compose 2.3.10 + **KSP 2.3.10 硬编码 id+version（:7，未进 version catalog）** | KSP 版本与 kotlin 手工同步点 |
| compileSdk | `release(36){minorApiLevel=1}` DSL（:71-75） | AGP9 新 DSL |
| minSdk/targetSdk | 24 / 36 | 无 coreLibraryDesugaring（Base64Codec.kt:6-8、DateTimeUtils.kt:50-51 两处注释互证）→ java.time/java.util.Base64 不可用 |
| ndk.abiFilters | 仅 arm64-v8a（:83-85） | 与 libgojni.so 单架构一致；AppWorkMode EXPRESS 另有运行时 64 位判定（AppWorkMode.kt:50-58） |
| androidResources.localeFilters | zh/en/zh-rCN（:88-90） | 资源裁剪 |
| buildTypes.release | minify+shrinkResources+双 proguard（:116-126） | |
| compileOptions | Java 11（:129-132） | |
| buildFeatures | buildConfig=true（CrashCollector.kt:70,367 BuildConfig.DEBUG、AppUpdateDialog.kt:36 VERSION_NAME 消费）、compose=true | |
| packaging.resources.excludes | 19 条 META-INF/LICENSE 类 + DebugProbesKt.bin + *.kotlin_builtins（:139-161） | 纯体积裁剪 |
| packaging jniLibs/dex useLegacyPackaging | true（:163-168） | so 安装时解包（arm64 13.6MB libgojni 场景） |
| lint | checkReleaseBuilds=false, abortOnError=false（:171-174） | 构建不被 lint 阻断 |
| gradle.properties | Xmx2048m/UTF-8、configuration-cache=true、**android.disallowKotlinSourceSets=false**（AGP9 built-in Kotlin 下 KSP 必需，:5-6 注释）、auto-download=false、daemon toolchainVersion=25（gradle-daemon-jvm.properties） | 构建单点串行教训在 AGENT_MISTAKES（KSP 缓存竞争） |
| settings.gradle.kts | 腾讯云 nexus 镜像最前 + FAIL_ON_PROJECT_REPOS + foojay-resolver 1.0.0（但自动下载关） | |

### 4.4 Proguard keep 策略（proguard-rules.pro 全文 13 行，实测）
- `-keep com.haoze.diting.data.entity.** { *; }`：Room 实体防删（注释自称"保险起见"）。
- `-keepclassmembers DnsProvider/DnsProtocol`：org.json 反射序列化字段面。
- `-assumenosideeffects Log.{v,d,isLoggable}`：release 剥离 verbose/debug。
- AAR 自带 consumer 规则（实测解包）：`-keep class go.** + tunnel.**`——gomobile 绑定类不可混淆。

### 4.5 Go AAR 接入链
- `implementation(files("libs/tunnel.aar"))`（build.gradle.kts:205，注释标明 GPL-3.0 gVisor 栈仅用于 HTTPS 检查）。
- AAR 实测内容：AndroidManifest(pkg go.tunnel.gojni, minSdk 24)/proguard.txt/classes.jar(34 个顶层类：Engine、CertManager、TcpIpStack、BloomFilter、MmapTrie、各 LogCallback…)/jni/arm64-v8a/libgojni.so(13,597,528B)/R.txt。
- 重建命令与三坑（SDK 路径、GOFLAGS=-buildvcs=false、javac PATH）：docs/development/aar-build-notes.md:33-91 [文档主张，产物侧本次实测吻合：仅 arm64 jni、ZIP 压缩]。go.mod：go 1.23.5，miekg/dns、quic-go 0.48.2、sagernet/gomobile fork、tun2socks v2.6.0、gvisor。
- 时序红线（AGENT_MISTAKES 2026-10-18）：AAR 只在 Go 源码定稿后重建。

### 4.6 build_apk.bat 流程（394 行实测）
`cd %~dp0` → 校验 gradlew.bat 存在（:9）→ 菜单 1 debug / 2 release / 3 debug+release key（`-PsignDebugWithRelease=true` :78）/ 4 clean → `gradlew.bat assembleX` → APK 定位：标准路径优先，退化 `dir /b /s /o:-d *.apk` 按时间新→旧过滤（含 build\outputs\apk、含 buildType、排除 androidTest/unaligned/-test，:104-116,290-296）→ 询问装否 → `where adb` → `adb devices` 计数：0 台→手输 IP:PORT `adb connect`+2s 等待+复查（:215-265）；1 台直装；多台编号选 → `adb -s X install -r`。错误路径全部带 Cause/Action 文案 + pause。**纯 Windows 交互脚本，不含 Go/AAR 构建**。

### 4.7 资源配置文件角色
| 文件 | 角色 | 实测备注 |
|---|---|---|
| res/xml/backup_rules.xml、data_extraction_rules.xml | 均为**未定制模板**（include/exclude 全注释，allowBackup=true） | 意味着 prefs+DB+filesDir 走系统默认全量云备份——agent_api_key（混淆）、代理凭据（Keystore 密文）也在内；Flutter 重构须显式决策 |
| res/xml/file_paths.xml | FileProvider 4 路径：app-update/、crash_logs/、external Download/、files/downloads/ | 末条 O-125 修复注释：必须与 CrashLogManager.PRIVATE_DOWNLOAD_DIR_NAME 同步（:33-35 注释） |
| res/xml/locales_config.xml | zh/en | 配 Manifest localeConfig |
| values/themes.xml + values-night/themes.xml | Theme.DITING = Material Light/暗 无 ActionBar + windowBackground=@color/diting_window_background | 冷启动底色，配合 CustomBackgroundManager 防白闪 |
| values/colors.xml、values-night、values-v31、values-night-v31 | 4 色：diting_window_background(#FFFBFE/#1C1B1F)、ic_launcher 前景背景、splash_card_stroke；v31 起 launcher 色改用 `@android:color/system_accent1/neutral*` **动态取色** | 实测 values-v31/colors.xml:3-4 |
| mipmap-anydpi-v26 | 自适应图标 + monochrome 层 | drawable 目录实测 10 文件；mipmap 仅 anydpi-v26（**无位图兜底密度**，API24/25 设备用默认 mipmap——待定：是否触发构建期缺资源告警） |
| assets/https_passthrough.txt | Express 默认白名单种子源（DefaultWhitelistSeeder.parseAssetWhitelist 消费，ExpressDefaultsSeeder.kt:75） | |

## 5. 权限与 Manifest 声明全表

### 5.1 权限（Manifest:5-17，实测 13 条）
| 权限 | 用途 | 申请/判定点（实测） |
|---|---|---|
| INTERNET | 基础 | 无需申请 |
| ACCESS_NETWORK_STATE | 网络快照探测 | core/diagnostic/NetworkInfoProbe.kt:32, UidPackageCache.kt:25 |
| FOREGROUND_SERVICE + _DATA_SYNC + _SPECIAL_USE | 三类前台服务；DATA_SYNC 专给 androidx SystemForegroundService（Manifest:66-69 tools:node=merge 把 Work 的 FGS 类型改为 dataSync）；SPECIAL_USE 给 DnsVpnService/ExpressVpnService/VpnMonitorService/DnsModeService 四个（subtype 属性 vpn/vpn/vpn_monitor/dns_service，Manifest:39-41,61-63,150-152） | 系统自动 |
| POST_NOTIFICATIONS | API33 通知 | 运行时申请 3 链：MainVpnController.kt:72,90,120、ModeOnboardingActivity.kt:171、ModePermissionWarningAction.kt:119；封装 NotificationPermissionHelper.kt:25 |
| REQUEST_INSTALL_PACKAGES | APK 更新安装 | AppUpdateManager.installDownloadedUpdate（:165-177，FileProvider+ACTION_VIEW package-archive）；**未发现** canRequestPackageInstalls 预检/ACTION_MANAGE_UNKNOWN_APP 引导（实测 grep 0 命中） |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | 保活 | BatteryOptimizationHelper.kt:97 直发系统弹窗 intent、:69 状态判定；披露门控 MainVpnController.kt:123-129 |
| QUERY_ALL_PACKAGES | 应用列表（AOSP 路径） | AppListPermissionHelper.canQueryInstalledApps 探测式判定 :59-91（1.5s 内存缓存），注释自述为 MIUI 之外的原生路径 |
| com.android.permission.GET_INSTALLED_APPS | 应用列表（MIUI/HyperOS 定制运行时权限，非标准） | 同上 :51-58，runtime request 失败降级设置页 :143-163 |
| SYSTEM_ALERT_WINDOW | 悬浮日志 | Settings.canDrawOverlays 判定 FloatingLogOverlayController.kt:147、LogRetentionSettingsScreen.kt:125,147；引导跳 ACTION_MANAGE_OVERLAY_PERMISSION :156-158 |
| WAKE_LOCK | 服务器模式锁 | DnsModeService.kt:252 PARTIAL_WAKE_LOCK |
| RECEIVE_BOOT_COMPLETED | 重启恢复 LAN DNS | DnsModeBootReceiver（Manifest:155-161）。**注意 receiver exported=false 收系统 BOOT_COMPLETED——可达性证据缺口，见待定 U-3** |

### 5.2 四大件之外的声明
- **application 属性**：allowBackup=true、largeHeap=true（全量规则索引驻内存域）、supportsRtl、localeConfig、theme=Theme.DITING、name=.DitingApp（Manifest:19-30）。
- **5 Activity**：MainActivity(exported=true, QS_TILE_PREFERENCES filter)、SettingsRouteActivity/WorkModeActivity/ModeOnboardingActivity/LogRouteActivity（全 exported=false, standard, adjustResize）、DnsMainActivity（exported=false, **singleTask**；被 DnsModeService 通知与 SettingsRouteActivity import 引用，DnsModeService.kt:307）。
- **QS_TILE_PREFERENCES 处理为空**：MainActivity 全代码零处读取该 action（实测 grep 0）——点磁贴齿轮=普通冷启动 MainActivity（行为声明，非缺陷判定）。
- **activity-alias `.MainActivityCurrentIconAlias`**（exported=true, enabled=true）：LAUNCHER intent-filter 挂在 alias 而非 activity 上；全仓无 `setComponentEnabledSetting`/组件切换代码（实测 grep 0）——alias 当前仅等效直通。[README 未核验：无文档主张，此为纯代码观察]
- **provider**：FileProvider（:71-79）。**receiver**：DnsModeBootReceiver。**tile**：DitingTileService（BIND_QUICK_SETTINGS_TILE，TOGGLEABLE_TILE=true，217 行实现：按当前工作模式分流 normal/express 切换、Android14+ PendingIntent 版 startActivityAndCollapse）。

## 6. 关键源码引证表（断言 → 路径:行）
| # | 断言 | 引证 |
|---|---|---|
| R-1 | 全应用无 DataStore，持久=SharedPreferences | grep `preferencesDataStore|PreferenceDataStoreFactory|createDataStore` = 0（本会话）；139 处 getSharedPreferences 调用点 |
| R-2 | DitingApp.instance 零消费者 | 定义 DitingApp.kt:24-27；全仓 `DitingApp` 仅剩清单声明 Manifest:20 与测试注释 |
| R-3 | 崩溃钩子时序：breadcrumb→minimal(commit)→full→bookkeeping，步骤级失败隔离 | CrashHandler.kt:36-72 |
| R-4 | vpn_running 自愈 = persisted && serviceAlive 双判 | DnsVpnStatusNotifier.kt:32-40；Express 同构 ExpressVpnController.kt:80-89 |
| R-5 | 注册表默认 lambda 用字符串类名 Intent（抗混淆/解耦），运行期被各服务 init 替换 | WorkModeLifecycleRegistry.kt:12-54；替换点 DnsVpnService.kt:455-465、DnsModeManager.kt:50、ExpressVpnController.kt:50-57 |
| R-6 | 隧道诊断钩唯一接地点在 Application | DitingApp.kt:55-59 → TunnelDiagnosticsResolver.kt:13,40 → DnsVpnService.kt:557 resolveThroughTunnel |
| R-7 | dataset 三容器隔离模型 | RuleDataset.kt:19-29；清理侧 DataCleanupManager.kt:491,521 各自 clear() |
| R-8 | AppRules 的 dynamic_block_* 仅 NORMAL/EXPRESS 使用；DNS_MODE 用 DnsRuleSettings block_response_dynamic_*（异名） | RuleSettingsAccess.kt:77-84（when(dataset) 分派实测） |
| R-9 | 代理账密 AES-GCM/AndroidKeyStore `diting_outbound_proxy`；Agent API Key 仅 XOR+Base64 混淆 | OutboundProxySettingsStore.kt:154-188；AgentApiSettingsStore.kt:332-336 |
| R-10 | SAF 授权收口：take 5 类入口全部经 PersistableUriPermissions，release 决策纯函数化 | PersistableUriPermissions.kt:23-87；SafGrantDecisions.kt:22-69；消费 4 文件实测 |
| R-11 | StartupSelfCheck 只修 NORMAL 容器 | StartupSelfCheck.kt:22（getSharedPreferences(PREFS_NAME) 非 datasetPrefs） |
| R-12 | 启动更新检查默认关闭 | SystemSettingsStore.kt:169-171（默认 true）+ MainStartupCoordinator.kt:41 |
| R-13 | dayStartMillis DST 定点探针算法，±5×6h 覆盖全球偏移 | DateTimeUtils.kt:53-70（含 28.4%/5.45M 差分实测注释） |
| R-14 | `diting_recognition_members` 是幽灵容器：清理写它、读写方用 `recognition_members` | DataCleanupManager.kt:548 vs RecognitionMembersRepository.kt:26 |
| R-15 | 死代码 6 项（双向 grep 定义+调用均 0）：PermissionDisclosureStore 死键×2+委托方法×3（isAppListExplained/setAppListExplained/markAppListAvailable/wasAppListAvailable 仅内部自引用）、DnsProvider.load/saveRaceProviderIds（DnsProvider.kt:231-240，调用方直接用 ResolutionSettingsStore）、WorkModeStore.resetWorkModeSelection（:35）、SubscriptionAutoUpdateSettings.PREFS 常量（Scheduler:32） | 本会话 grep 逐条实测 |
| R-16 | versionCode 推导+只增不减 | app/build.gradle.kts:13-15；AGENT_MISTAKES.md:67 |
| R-17 | tunnel.aar 与 sources.jar 入 Git，keystore 不入 | `git ls-files Android/app/libs/`（2 行命中）vs .gitignore:31-42 |
| R-18 | CrashBreadcrumbs 恰 150 环、无 I/O，读取面仅 CrashCollector×2 | CrashBreadcrumbs.kt:15-47；CrashCollector.kt:262,324 |
| R-19 | 语言面=zh/en 二值，SYSTEM 模式下非中文系统一律英文 | AppLanguageManager.kt:38-50 |
| R-20 | 手机锁竖屏判据=DeviceScreenHelper sw600dp 模拟 | AppLocalizedActivity.kt:33-36；DeviceScreenHelper.kt:22-32 |

## 7. Flutter 重构注意（仅列本会话确证项）

**必须原样保留的语义**
1. 第 3 节全部容器×键×默认×钳位矩阵：迁移 shared_preferences 时按容器→key 前缀（如 `normal.`, `express.`, `dns.`）展平，dataset 感知键（B 表）三容器各存一份的现状要保留为独立键空间（Express 工厂重置整库 clear 依赖此隔离，DataCleanupManager.kt:491）。
2. 三个一次性迁移标记：`local_listen_port_migrated`、`log_queries_default_off`、`default_whitelist_seeded_version=0 语义`——幂等迁移历史决策，新平台首启若把新装当升级跑这些迁移会错。
3. `vpn_running`/`express_vpn_running` 的 persisted&&alive 自愈读法（R-4）与崩溃期 `commit()` 同步落盘（CrashLogManager 注释）。
4. Agent Key「混淆≠加密」定级与代理账密 AndroidKeyStore AES-GCM 定级不同（R-9）：前者 shared_preferences 明文等价可接受，后者必须走平台安全存储通道。
5. 工作模式/首启协议/onboarding 三级门次序（2.3/2.8）。
6. `disable_startup_update_check` 默认 true（更新静默）与 `main_activity_foreground` 默认 true 两个反直觉默认（A 表）。
7. FileProvider 双下载目录映射与 CrashLogManager 常量同锁步（file_paths.xml O-125 注释）。
8. versionCode 推导式 + max(旧值) 只增不减（R-16），三处版本号声明点（gradle/toml 无、manifest 无 versionName——实测仅 build.gradle.kts:15-18 单点）。

**可删除/合并（R-15 死代码 6 项 + 以下）**
- AppSettings 门面（仅 1 个转发方法）、`DitingApp.instance`、`SubscriptionAutoUpdateSettings.PREFS` 死常量、KSP 版本硬编码并入 toml、alias 直通组件（若确认无换图标规划）。
- `diting_recognition_members` 幽灵容器写点改正为 `recognition_members`（一行修正，属缺陷修复非重构）。
- PermissionDisclosureStore 中零消费的 2 键与 3 个委托方法整体删除。

**需另起平台的**
- arm64 gomobile AAR：Dart FFI 不可直接用（gomobile 是 JNI 对象图非 C ABI），须原生 Platform Channel 壳或重写导出层；classes.jar 34 类清单（4.5）即通道面基线。
- SAF persistable URI（2.7 两文件）：Android 特有 ContentResolver 语义，Flutter 侧要么 keep 在原生通道要么改「复制入应用目录」模型——**注意改模型即丢「撤销他人授权风险」判定逻辑**（releaseIfPersisted 存在理由，PersistableUriPermissions.kt:57-79 注释）。
- 前台服务三件套 + QS Tile + BOOT 恢复：Flutter 需原生 Service 层保留（插件如 flutter_foreground_task 不等价 specialUse subtype 语义）。
- LocalizationEngine 运行期中英翻译（2.10）：strings.xml 216×2 只是壳，大量中文串走哈希资源名+词典——Flutter l10n 必须整体重新设计，不可只迁 strings。
- build_apk.bat → 跨平台任务脚本（flutter build apk --debug/--release + -PsignDebugWithRelease 透传 + adb install 逻辑），签名链 6 路径+env 回退可原样平移进 Flutter 的 android/ 子工程。
- minSdk24 的纯 Kotlin 手工实现（Base64Codec、DateTimeUtils.dayStartMillis）在 Dart 侧有等价库，但 **DST 语义与 statsRangeStartMillis 的按枚举 name 匹配**（DateTimeUtils.kt:85-89）须行为级对齐。

**待定（缺证据类型）**
- U-1：MainActivity 未声明 launchMode（标准模式）却实现 onNewIntent——各生产者（VpnMonitorService.kt:121、tile:154 等）的 launch flag 与"实例已存在"路径组合是否真触发 onNewIntent，需运行期日志或 AOSP ActiveServices 语义核验。
- U-2：mipmap 仅 anydpi-v26，无位图密度兜底，API24/25 桌面的图标回退行为未实测。
- U-3：DnsModeBootReceiver exported=false + BOOT_COMPLETED intent-filter 的可达性（系统广播是否豁免 exported 检查）需 AOSP/真机取证。
- U-4：`allowBackup=true` + 空备份规则是否真把 diting_crash_state/agent_api_key 上传云备份——需 ADB backup 实验取证。
