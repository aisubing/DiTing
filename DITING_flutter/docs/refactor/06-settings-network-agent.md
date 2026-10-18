# 06 设置体系 · DNS 解析与服务商 · 网络诊断 · LLM Agent · 本地化

```yaml
所属系列: DITING Android Flutter 重构功能图谱 | 章: 06 | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测
```

## 1. 概述

本域四个子系统，全部文件已精读：`ui/settings/` 实测 **18 个文件**（含 `SettingsPreferencesExtensions.kt` 读写扩展；17 个 Store/工具对象 + 1 屏）、`core/diagnostic/` 15 文件、`ui/localization/` 12 文件、设置屏族约 30 屏、Agent UI 4 文件（`ui/AgentApi*.kt`）+ `ui/agent/` API 调用层（Markdown 渲染组件归第 12 章）。

存储底座：`SettingsPreferencesExtensions.kt:8` 定 `PREFS_NAME="dns_vpn_prefs"`；`datasetPrefs()`(:10-12) 按 `RuleDataset.prefsName()`（`data/RuleDataset.kt:24-28`：NORMAL=dns_vpn_prefs / EXPRESS=diting_express_prefs / DNS_MODE=diting_dns_mode_prefs）取容器——同一 Store 方法传不同 dataset 即读写不同文件。另有 3 个**不参与 dataset 隔离**的独立 prefs：`network_tools_settings`（诊断）、`notification_settings_prefs`（通知）、`permission_disclosures`（权限披露）。字符串集合统一走 JSONArray 文本（readStringSet/writeStringSet，`SettingsPreferencesExtensions.kt:14-28`，写时 sorted 保证稳定）。

UI 源语言为硬编码中文，英文由 `LocalizationEngine` 运行时替换；设置键、默认值均以真实 `getXxx(key, default)` 参数为准。

## 2. 设置项总表

容器列：**D**=datasetPrefs（按调用方 dataset 落三个文件之一）；**N**=固定 dns_vpn_prefs；**X**=独立文件。

### 2.1 SystemSettingsStore（ui/settings/SystemSettingsStore.kt）

| 设置键 | 界面名称 | 可选值/范围 | 默认 | 容器 | 定义:行 | 消费方 |
|---|---|---|---|---|---|---|
| log_retention_days | 日志保留天数 | coerceIn(1,30) | 7 | D | :10,31,48-58 | 日志清理；race/bootstrap/http 日志裁剪同用此 cutoff（core/log/LogMaintenanceManager.kt:62,132-141） |
| dns_log_mode | 日志模式 | all/blocked_and_errors/off（DnsLogMode.kt:3-6） | ALL | D | :17,35-46 | 三模式日志门 |
| floating_log_enabled | 悬浮日志 | Bool | false | N | :18,60-70 | normal 悬浮窗 |
| floating_log_panel_size | 悬浮面板尺寸 | coerceIn(0,2) | 0 | N | :19,72-83 | 悬浮窗 |
| main_activity_foreground | 主界面前台标记 | Bool | true | N | :20,85-95 | 服务/前台判定 |
| hide_from_recents_enabled | 后台隐藏 | Bool | false | N | :11,33,97-107 | normal+express 前后台屏 |
| bypass_lan_enabled | 绕过局域网 | Bool | true | N | :12-13,238-248 | 仅 normal（express 屏物理无此项） |
| ipv6_mode | IPv6 流量接管 | auto/enabled/disabled（Ipv6Mode.kt:3-7） | AUTO | D | :14-15,250-261 | normal/express 各自独立一份（Express 屏显式传 EXPRESS，ExpressForegroundBackgroundSettingsScreen.kt:50,56） |
| app_update_download_path/version | 更新下载记录 | String | "" | N | :21-22,145-167 | 第 05 章 |
| disable_startup_update_check | 启动检查更新（取反） | Bool | **true=默认不检查** | N | :23,169-177 | 第 05 章 |
| settings_guide_acknowledged_ids | 指引已读 | StringSet | ∅ | N | :24,179-195 | SettingsGuideHost |
| initial_agreement_accepted | 首次协议 | Bool | false | N | :25,211-220 | 启动门 |
| data_reset_notice_pending | 数据重置提示 | Bool | false | N | :26,222-236 | 提示卡 |
| app_traffic_stats_enabled | 流量统计 | Bool | true | N | :27,109-119 | normal |
| traffic_stats_retention_days | 统计保留 | coerceIn(1,90) | 30 | N | :28-32,121-131 | normal |
| traffic_stats_hide_system_apps | 隐藏系统应用 | Bool | false | N | :29,133-143 | normal |

### 2.2 ResolutionSettingsStore（解析模式，全部 D 容器）

| 键 | 名称 | 可选值 | 默认 | 行 |
|---|---|---|---|---|
| dns_resolution_mode | 解析模式 | single/smart_prediction/parallel_race/primary_backup（DnsResolutionMode.kt:12-16） | SINGLE（解析失败回退 :106-110） | :17,106-117 |
| preset_dns_service | 内置服务协议 | DNS/DOT/DOH（PresetDnsService.kt:3-14，仅协议枚举，非服务商清单） | DNS | :18,203-214 |
| race_provider_ids | 竞速/测速候选 | Set JSON | {preset_alidns_dns, preset_dnspod_dns} | :13,26-29,33-60 |
| race_test_domain | 测速域名 | 非空串 | "mihoyo.com" | :14,31,91-104 |
| latency_test_provider_ids | 测速勾选 | Set JSON | ∅ | :15,62-89 |
| smart_prediction_provider_ids | 智能候选 | Set JSON | DEFAULT_RACE_PROVIDER_IDS | :19,137-141 |
| parallel_race_provider_ids | 竞速候选 | Set JSON | 同上 | :20,143-147 |
| primary_backup_provider_ids | 依次尝试序列 | List（有序 distinct） | 同上转 List | :21,149-170 |
| home_visible_protocols / home_hidden_provider_ids / home_visible_provider_ids | 服务显示 | Set<DnsProtocol.name> / Set id | MANAGED_PROTOCOLS{DNS,DOH,DOT}（HomeProviderVisibility.kt:6）/ ∅ / ∅ | :22-24,178-201 |

删服务商联动：`removeProviderFromResolutionModes`(:172-176) 清 smart/parallel/backup；race/latency/selected 由 `DnsProvider.deleteUserProvider`（core/dns/DnsProvider.kt:318-337）清，并 `ProviderHealthStore.remove`。

### 2.3 DnsCacheSettingsStore（缓存；键带 _v2/_v3 历史后缀，全 D）

| 键 | 可选/钳位 | 默认(getXxx 实参) | 行 |
|---|---|---|---|
| dns_cache_enabled_v2 | Bool | true | :10,22,42 |
| dns_cache_mode_v2 | follow_dns_ttl/limit_max_ttl/fixed_ttl（core/cache/DnsCachePolicy.kt:6-19） | LIMIT_MAX_TTL | :11,43-45 |
| dns_cache_max_ttl_seconds_v2 | coerceIn(30,86400)(:20-21) | 3600L | :12,46 |
| dns_cache_fixed_ttl_seconds_v2 | 30..86400 | 3600L | :13,48 |
| dns_cache_min_ttl_enabled_v2 | Bool | false | :14,50 |
| dns_cache_min_ttl_seconds_v2 | 30..86400 | 60L | :15,51 |
| dns_cache_stale_fallback_enabled_v2 | Bool | false | :16,53 |
| dns_cache_stale_fallback_seconds_v2 | 30..86400 | 300L | :17,54-57 |
| dns_cache_preset_v3 | conservative/balanced/high_hit_rate（DnsCachePreset.kt） | null→按 policy 反推 fromPolicy(:61-65) | :18 |

档位策略值（DnsCachePreset.kt:15-66）：CONSERVATIVE=follow_ttl/negTtl15；BALANCED=max3600/min60/stale300/neg30；HIGH_HIT_RATE=max21600/min120/stale900/neg60。写档位经 `setDnsCachePreset`(:67-70)→保留当前 enabled 整体覆写 9 键（:76-97）。`negativeTtl*` 仅 policy 字段（DnsCachePolicy.kt:27-28）无独立键——UI 只暴露档位，负 TTL 不可单独持久化（消费在缓存内核，归第 07 章）。

### 2.4 BootstrapDnsSettingsStore（全 D）

| 键 | 可选值 | 默认 | 行 |
|---|---|---|---|
| bootstrap_enabled | Bool | true | :13,17,24-34 |
| bootstrap_preset_ids | ⊂7 预设 id | {preset_volcengine, preset_dnspod, preset_alidns} | :14,18-22,89-113 |
| bootstrap_custom_json | [{id,name,ip,enabled}]，读时逐条校验 IP | null→∅ | :15,115-162 |

引导节点预设全表（core/diagnostic/BootstrapIpModels.kt:15-23）：阿里云 223.5.5.5 / 腾讯云 119.29.29.29 / 字节跳动 180.184.1.1 / CNNIC 1.2.4.8 / 114DNS 114.114.114.114 / Cloudflare 1.1.1.1 / Google 8.8.8.8。校验 `BootstrapIpValidator.isValidIp`(:26-49)：IPv4 逐段 0..255；IPv6 仅字符白名单（弱校验，待定级）。

### 2.5 DnsProvider 持久化（core/dns/DnsProvider.kt，全 D）

| 键 | 默认 | 行 |
|---|---|---|
| selected_provider_id | "preset_alidns_dns" | :55-56,211-221 |
| user_providers_json | ∅，读时过滤 MANAGED_PROTOCOLS、端口非法回退 853 | :54,253-286,364-377 |

**内置服务商预设全表**（PRESETS :58-197，实测 18 条=6 家×3 协议；协议枚举 DnsProtocol :13-25）：
- DNS/53：阿里云 `preset_alidns_dns` 223.5.5.5、腾讯云 DNSPod `preset_dnspod_dns` 119.29.29.29、360 `preset_360_dns` 101.226.4.6、OneDNS `preset_onedns_dns` 117.50.10.10、Cloudflare `preset_cloudflare_dns` 1.1.1.1、Google `preset_google_dns` 8.8.8.8
- DoH：阿里云 `preset_alidns_doh` https://dns.alidns.com/dns-query、DNSPod `preset_dnspod_doh` https://doh.pub/dns-query、360 https://doh.360.cn/dns-query、OneDNS https://doh.onedns.net/dns-query、Cloudflare https://cloudflare-dns.com/dns-query、Google https://dns.google/dns-query
- DoT/853：dns.alidns.com、dot.pub、dot.360.cn、dot.onedns.net、one.one.one.one、dns.google（id 后缀 _dot）
协议互切仅「阿里云/腾讯云 DNSPod」(:223-229,:445)；DoH URL 须 https://（:339-341）、DoT host 非 IP 字面量（:344-348）；IP 字面量判定含严格 IPv6 结构校验（:391-442）；动态运行时服务商 id=SHA-256 前 8 字节 `runtime_custom_xxx`（:451-458）。

### 2.6 AppRulesSettingsStore（ui/settings/AppRulesSettingsStore.kt）

D 容器键：

| 键 | 可选/钳位 | 默认 | 行 |
|---|---|---|---|
| block_response_mode | nxdomain/nodata/refused/zero_address（core/rule/BlockResponseMode.kt:6-10） | NXDOMAIN | :31,41,302-313 |
| dynamic_block_response_enabled | Bool | false | :32,318 |
| dynamic_block_request_threshold | coerceIn(2,100) | 5 | :33,319-325（常量 DynamicBlockResponsePolicy.kt:12-19） |
| dynamic_block_window_seconds | coerceIn(10,300) | 60 | :34,326-332 |
| dynamic_block_nxdomain_duration_seconds | coerceIn(60,3600) | 300 | :35,333-339 |
| domain_rules_enabled | Bool | true | :29,375-384 |
| allow_edit_default_whitelist | Bool | false（DNS_MODE 恒 true，RuleSettingsAccess.kt:56-65） | :36,397-406 |
| default_whitelist_initialized / default_whitelist_seeded_version | Bool / Long | false / 0 | :37-38,408-429 |
| ipv6/dns_log/retention | 见 §2.1 | | |

N 容器键（均固定 dns_vpn_prefs）：excluded_app_packages(∅)/_filter("USER")/_sort("LABEL_ASC")(:10-12)；blocked_app_packages(∅，读写剔除自身包名 :78,96)+blocked_apps_enabled(false)+filter/sort(:13-16)；app_allowlist_enabled(false)+app_allowlist_rules_json(JSONObject pkg→domains)+filter/sort(:17-19,107-187)；http_inspection_enabled(false)+http_inspection_app_packages(∅)+filter/sort(:20-23)；https_inspection_ready(false)+https_inspection_ca_backend(须=="go-v1" :40,246-259)；https_bypass_rules(∅)(:26)；http3_inspection_enabled(false)(:27)；encrypted_dns_blocking_enabled(false)(:28)；address_rules_enabled(true)(:30,386-395)。`resetAppControlRules`(:431-452) 一次清 16 个 app 管控键。

**RuleSettingsAccess**（ui/settings/RuleSettingsAccess.kt）按 dataset 分派规则管理读写：NORMAL/EXPRESS→AppRulesSettingsStore；DNS_MODE→DnsModePreferences.adBlockEnabled + DnsRuleSettings（server/backend/DnsRuleSettings.kt:14-46，同键名落 diting_dns_mode_prefs）。URL 规则仅 NORMAL 可用（:41-44）；CNAME 覆写 NORMAL 需 HTTPS 检查就绪、DNS_MODE 恒可用、EXPRESS 恒不可用（:53-54,110-115 纯函数可测表）。

### 2.7 OutboundProxySettingsStore（全 N，仅 normal）

| 键 | 可选/校验 | 默认 | 行 |
|---|---|---|---|
| outbound_proxy_enabled | Bool | false | :18,40 |
| outbound_proxy_protocol | socks5/http（OutboundProxyConfig.kt:6-13） | SOCKS5 | :19,41 |
| outbound_proxy_host | **仅 127.0.0.1 或 ::1**（OutboundProxyConfig.kt:23） | "127.0.0.1" | :20,42 |
| outbound_proxy_port | 1..65535（越界由启动自检回 7890，StartupSelfCheck.kt:64-69） | 7890 | :21,43 |
| outbound_proxy_username/_password | **AndroidKeyStore AES/GCM 加密**（iv12B+tag128，:154-188），≤255 字节 | "" | :22-23,44-45 |
| outbound_proxy_app | 代理宿主包名，不得为自身且须已安装 | "" | :24,46 |
| outbound_proxy_status/_status_message | connecting/ready/error 等 | "disabled"/"" | :25-26,107-132 |

进程内 `cachedConfig` 写穿缓存（:28-51），reset 清全部 9 键并复位缓存（:68-84）。`formatProxyErrorMessage`(:134-152) 把 Go 侧英文错误映射为中文（connection refused→代理未启动等 7 条）。

### 2.8 AgentApiSettingsStore（全 N；ui/settings/AgentApiSettingsStore.kt）

| 键 | 可选值 | 默认（getXxx 实参） | 行 |
|---|---|---|---|
| agent_api_enabled | Bool | **true** | :252,266 |
| agent_api_key | 明文 String（旧路径；新厂商路径经 KeyObfuscator） | "" | :253,267 |
| agent_api_base_url | URL | https://api.deepseek.com/v1（:21） | :254,268-269 |
| agent_api_model | 串 | deepseek-flash（:28） | :255,270 |
| agent_api_temperature | **以 String 存**，toDoubleOrNull 回退 | 0.7（:29） | :256,271-272 |
| agent_api_system_prompt | 多行 | "" | :257,273 |
| agent_ai_providers_json | List<AiProvider>（id/name/baseUrl/apiKey/modelName/presetId，apiKey 存 KeyObfuscator 混淆值） | null→performInitialMigration | :259,289-297,350-380 |
| agent_ai_active_provider_id | 串 | ""→firstOrNull 兜底 | :260,310-329 |
| agent_api_custom_presets / agent_api_preset_order | 自定义模型预设 JSON / 逗号 id 序 | ∅ / 无 | :62-63,134-176,227-245 |

首次迁移（:350-380）：已有非默认配置→建 "migrated_default" 厂商（KeyObfuscator.seal 收编明文 key）；否则建 preset_deepseek（baseUrl https://api.deepseek.com、model deepseek-chat）。活跃厂商变更即 `syncProviderToConfig`(:339-348) 把 baseUrl/**解密后明文 key**/model 回灌旧键——两套存储 key 保护强度不一致（providers 侧混淆、config 侧明文）。
模型内置预设 6 条（AgentApiPresetStore.BUILTIN_PRESETS :69-118，注释「最后核验 2026-09」）：deepseek-flash、deepseek-v4-pro、gpt-6-astra、gpt-5.6-terra、gpt-5.6-luna、kimi-k3；MODEL_SUGGESTIONS 同 6 id（:121-128）。厂商目录 **AiProviderPresets 实测 16 条**（AiProviderModels.kt:75-102）：国内厂商 8（DeepSeek/智谱/Kimi/阿里百炼/火山方舟/MiniMax/千帆/阶跃）、海外 5（OpenAI/Gemini/xAI/Mistral/Groq）、聚合与本地 3（硅基流动/OpenRouter/Ollama localhost:11434）。KeyObfuscator 为 3 组 XOR 掩码+Base64（util/KeyObfuscator.kt:5-38），**非真加密**。

### 2.9 其余 Store

| Store | 键（默认）| 容器 | 定义 |
|---|---|---|---|
| NetworkToolsSettingsStore | ping_via_tunnel / dns_lookup_via_tunnel / traceroute_via_tunnel（均 false） | **X: "network_tools_settings"** | ui/settings/NetworkToolsSettingsStore.kt:11-14,16-41 |
| HiddenFeaturesStore | hidden_features_set（StringSet，默认空=全显示；**N 固定、不分 dataset，三模式共享**） | N | HiddenFeaturesStore.kt:267,275-338 |
| AppearanceSettingsStore | app_theme_mode(SYSTEM)、theme_color_style(:SYSTEM)、home_component_opacity(1f, coerceIn .1..1)+5 个分项透明度（缺省继承总键 :67-71）、home_sentence_running("谛听万象，明察清浊")/stopped("收耳静眠，归于无声")、custom_background_enabled(false)+uri+uris(JSON)、bottom_bar_destinations(JSON)、bottom_bar_haptic_enabled(**true**) | N | AppearanceSettingsStore.kt:12-26 |
| StartupSelfCheck | 启动读校 5 键：dns_resolution_mode 非法→single；preset_dns_service 非法→DNS；bootstrap_custom_json/background_uris 非 JSON→删；代理端口越界→7890。入口 MainStartupCoordinator.kt:27→AppSettings.kt:21 | N | StartupSelfCheck.kt:9-74 |
| OptionalFeaturesStore | 无自有键：`OptionalFeature` 10 项枚举兼容层，全部转发 HiddenFeaturesStore（取反语义 visible↔hidden） | — | OptionalFeaturesStore.kt:81-115 |
| NotificationSettingsStore | notification_persistent_enabled(true)/traffic_speed_enabled(false)/custom_running_text(")/custom_stopped_text(") | **X: "notification_settings_prefs"** | notification/NotificationSettingsStore.kt:10-15 |
| PermissionDisclosureSettings | vpn_explained(false)/vpn_was_granted（app-list 委托 AppListPermissionHelper） | **X: "permission_disclosures"** | ui/PermissionDisclosureStore.kt:6-46 |
| AppLanguageManager | app_language_mode（system/zh/en，默认 system） | N | ui/AppLanguageManager.kt:23-36 |
| SubscriptionAutoUpdateSettings | subscription_auto_update_enabled(false)/interval_hours(24；档位 6/12/24/48，界 1..168) | D | core/rule/SubscriptionAutoUpdateScheduler.kt:31-42 |

功能中心模型（HiddenFeaturesStore.kt:51-264）：**HiddenFeature 实测 27 项**分 **7 个 FeatureCategory**（DNS 服务 4/策略规则 4/网络管控 4/进阶工具 4/界面设置 3/数据维护 5/关于 3）；`ContextUiExtensions.kt`（17 行）仅提供 showToast/copyToClipboard。设置导航目录 `ScreenDestinations`（SettingsSearchCatalog.kt:30-62）：一级 6 入口（缓存/解析模式/日志模式/前后台/运行模式/语言…实测 all=6 主+4 子 :50），`SettingsSection` 6 组（:17-18）；init 断言路由不重复、主/父二选一（:55-61）。设置屏入口路由在 SettingsRouteActivity.kt:328-519（如 :415 服务商管理、:421 Bootstrap、:422 网络诊断、:423 解析模式、:426-429 四模式配置、:430 缓存、:432 前后台、:389 出站代理、:396-400 AI、:474 外观、:496 通知、:508-509 隐藏功能——均实测）。

## 3. 设置屏结构（要点）

- **SettingsScreen**（:22-73）纯导航列表；语言项用资源串、其余 localizedText（:60-61）。
- **SettingsGuideHost**（SettingsGuide.kt:154-237）：确认写 acknowledged_ids(:228)；domain_rules 两步协议带勾选门（:124-143,231）；**英文整段文案硬编码在 englishGuide()(:32-112)，判定用系统 locale 而非 AppLanguageMode（:160）**——语言设置与指南语言可错位（待定）。
- **缓存屏**：开关+3 档 Radio，档位列表 AnimatedVisibility 仅 enabled 时（CacheSettingsScreen.kt:105-122）；DNS_MODE 改读写 DnsModeManager.config（:41-57）；每次保存 `setDnsCachePolicy(preset.toPolicy(enabled))` 整体覆写并回调 onRuntimeDnsSettingsChanged（:59-79）。
- **解析模式族**：主页英雄卡+模式选择对话框、四模式配置卡（ResolutionModeHomeScreen.kt:81-144）；配置屏 SINGLE=Radio 其余=Checkbox，协议分段仅 UI 态（ResolutionModeConfigScreen.kt:123-161）；主备拖序仅 onDragEnd 提交（PrimaryBackupOrderGroup.kt:312-314）。校验 isModeValid：SINGLE 需选中存在、其余 ≥2（RaceModeSettingsViewModel.kt:198-203）；切换失败给两档提示并跳配置页（:175-178; ResolutionModeHomeScreen.kt:86-88）。**preset_dns_service 变更会 remap 四套候选集到对应协议预设 id**（VM:259-284）。保存即写；仅当所改模式=当前生效模式才 refreshIfRunning（VM:210,233,294），模式/协议切换无条件刷新（:183,283）。
- **RuntimeDnsSettingsRefresher**：ui 层只是 typealias（ui/RuntimeDnsSettingsRefresher.kt:6），实体 core/rule/RuntimeDnsSettingsRefresher.kt——把「配置已变」翻译为 startService Intent（NORMAL REFRESH_RUNTIME_CONFIG / EXPRESS REFRESH_CONFIG / DNS_MODE 仅 WorkMode==DNS），**引擎未运行则静默跳过**（isNormalRunning/isExpressRunning 门，:46,57 等）。这是本域所有「保存后热生效」的统一出口。
- **Bootstrap 屏**：开关/勾选/增删全部即写即刷新 VM（BootstrapSettingsViewModel.kt:73-124）；进屏先 `flushActive(commit=true)` 落盘在途健康样本再读（:61）；addCustom 校验失败不写盘（:93-96）；删除自定义同时清健康记录（:114）。
- **前后台/通知/底栏 normal vs express**：同构屏读同批键；**差异穷尽**——express 前后台屏物理删「绕过局域网」节（ExpressForegroundBackgroundSettingsScreen.kt:31-37 注释：窄路由 TUN 局域网本就不进隧道）；express 通知屏删「实时速率」节（ExpressNotificationSettingsScreen.kt:35-40 注释）；express 底栏枚举仅 4 项（ExpressNavigation.kt:21-58，排除 APP_TRAFFIC_STATS/NETWORK_TOOLS），存回同一键 bottom_bar_destinations（互映射 :62-84）；BottomBarDestination 全枚举实测 **6 项**（HOME/FEATURE_HUB/LOG_DASHBOARD/APP_TRAFFIC_STATS/NETWORK_TOOLS/SETTINGS，:31-74），MIN_COUNT=2/MAX_COUNT=4（:75-76），DEFAULT=[HOME,FEATURE_HUB,LOG_DASHBOARD]（:78）。express 功能中心裁剪到 **EXPRESS_SUPPORTED_FEATURES 18 项**（ExpressHiddenFeaturesScreen.kt:38-66；排除覆写名单、网络管控全类、进阶工具全类——**极速模式无 AI 分析/网络诊断/出站代理入口**）。
- **外观族**：AppearanceSettingsScreen 为导航枢纽（日夜/主题色/透明度/底栏/句子/通知/背景+触感开关，AppearanceSettingsScreen.kt:55-124）；通知项 subtitle 按 WorkMode 分文案（:93-97）。日夜 Radio 3 项即写+悬浮层刷新（DayNightModeScreen.kt:44-53）；主题色 9 项含 swatch（ThemeColorSettingsScreen.kt:56-86；**GOLD 的 storageValue="indigo"**，ui/theme/AppTheme.kt:32——显示名与存储值不一致）。语言屏 3 Radio，选择即写+`recreate()`（LanguageSettingsScreen.kt:30-46; SettingsRouteActivity.kt:176-179,186-193；MainActivity.kt:222 同型）。首页句子**仅点「确定」才落盘、可留空**（HomeSentenceSettingsScreen.kt:67-77,82）。
- **自定义背景**：SAF takePersistableUriPermission（CustomBackgroundSettingsScreen.kt:81-87→util/PersistableUriPermissions）；isCustomBackgroundEnabled 要求 uri∈uris（Store:120-124）；删除当前项联动禁用（Store:154-165）；Manager 侧 filesDir 位图缓存+URI 标记文件防失权、解码失败回退窗口背景色（CustomBackgroundManager.kt:112-147,189-240）。
- **HTTPS 检查屏（normal 独有）**：主开关三态副标题依赖 httpsReady（CA 验证）+域名规则联动对话框「确认开启两者」（HttpInspectionSettingsScreen.kt:108-127,227-241）；URL 规则/HTTP3/阻断 DoT 三子开关需 httpsReady&&enabled，均即写+refreshAppExclusionsIfRunning（:164-213）；ON_RESUME 重验 CA（:63-69）。CA 屏写 https_inspection_ready 缓存位、失败强制关检查（CaCertificateSettingsScreen.kt:74-82）；安装=导出手动装→回屏重验（:84-134）。
- **出站代理屏（normal 独有，OutboundProxySettingsScreen.kt，实测 253 行非 421）**：**混合保存时机**——开关即时 setOutboundProxyEnabled+置 connecting、必要时直接拉起 DnsVpnService（:95-105）；协议分段/地址/端口/账号/密码只进 draft，点「保存」经 `validationError` 校验（仅 127.0.0.1/::1、1..65535、代理应用必选非自身已安装、账密≤255B，OutboundProxyConfig.kt:21-30）才 setOutboundProxyConfig（:194-207）；状态 1s 轮询仅 enabled 时（:77-82）；代理应用选择走子 Activity 单选回传（OutboundProxyAppsScreen:219-253; 路由 :389-394）。生效方式：配置经 Go 隧道应用（引用第 09 章桥接），本端仅 prefs+RuntimeDnsSettingsRefresher.refreshAppExclusionsIfRunning。
- **BlockResponse 屏**：4 固定响应 Radio（副标题含 5 分钟负缓存语义，BlockResponseSettingsScreen.kt:214-219）+动态开关+对话框三参数（数字过滤、范围用 MIN/MAX 常量报错，:134-156,202），即写+runtime 回调；经 RuleSettingsAccess 分 dataset（:44-50）。

## 4. 网络诊断工具

UI 容器：`NetworkToolsScreen.kt:150-162` HorizontalPager 4 页（SPEED_TEST/PING/DNS_LOOKUP/TRACEROUTE，NetworkToolsViewModel.kt:22-27）+顶部网络概览卡（NetworkInfoProbe 快照，展开逐行复制，:179-334）。路由 :422。

- **Ping**：`ProcessBuilder("ping"/"ping6", "-c" n, "-W" timeout, "-w" n*(timeout+2), host)`（NetworkPingTool.kt:82-99）——依赖系统二进制；count 默认 4 UI 可选 4/10、钳位 1..20（:52,67,254-255）；总超时 `n*(t+3)+15`s（:62-66）。正则解析 toybox/busybox 输出（REPLY/LOSS/TRANSMITTED/RECEIVED/RTT，:246-252，兼容 `seq=`），mstd 缺失时 jitter=平均绝对偏差（:200-204，非 RFC3550）；**回退**：isReachable(1000ms)→TCP 53/443/80 握手（:153-198），`measuredWithFallback` 标注。sanitizeHost 剥 scheme/路径/userinfo/端口（:223-245）。
- **Traceroute**：ICMP TTL 递增，逐跳 `ping -c 1 -W 2 -t <ttl>`（NetworkTraceRouteTool.kt:156-164）；默认 15 跳上限 30（:216-218），每跳单包无去重；命中 `time=` 判到达、`From …` 判中间跳、unreach 提前终止（:107-146）；ping 不支持 -t（Usage）直接报不可用（:104-106）——部分 toybox 构建失败面（待定真机）。
- **DNS 解析查询**：DnsLookupTool 仅 A/AAAA（core/dns/DnsLookupTool.kt:20-23），IP 字面量短路（:58-73）；传输 `PlainDnsTransport` UDP 多服务器轮询+TC→TCP，超时 5000ms（DnsTimeoutConstants.kt:3）、缓冲 65535；**查询不带 EDNS0/DO**（buildQuery 仅 RD=1，core/dns/DnsMessageUtils.kt:103-131）；DnsRecordParser 解 A/NS/CNAME/SOA/PTR/MX/TXT/AAAA/SRV、压缩指针 ≤64 跳、OPT(41) 跳过（:181-321）。服务器：SYSTEM=LinkProperties.dnsServers / CUSTOM 须 IP 字面量（NetworkToolsViewModel.kt:226-257）。
- **「通过隧道」语义**：仅把**域名→IP 解析**交给 Go 隧道（TunnelDiagnosticsResolver 静态钩子，DitingApp.kt:55 注册；JSON {ips,ttls,source:rewrite|upstream|blocked|nodata,reason,error}），探测流量仍走物理网（ping/trace 用 addressOverride，NetworkToolsViewModel.kt:186,293,308-325）；DNS 查询模式则整体改走隧道并显示来源标签（:204-224）。IP 目标忽略开关（:309）。
- **测速**：域名=race_test_domain；协议分段过滤候选服务商；并发 `DnsLatencyTester.testAverage(attempts=3)`（LATENCY_TEST_ATTEMPTS，RaceModeSettingsViewModel.kt:324,372），成功优先/耗时升序/成功数/名称排序；结果灌 ProviderHealthEngine+commit（:340-347，注释明确其唯一生产者身份）；勾选持久化 latency_test_provider_ids（与竞速候选独立，DnsSpeedTestSection.kt:180 提示）。
- **健康引擎**：EWMA α=.25/抖动 α=.2（失败不动 EWMA）、3 连败→30s 冷却、半衰期 30min 衰减计数（BootstrapHealthEngine.kt:92-124,199-244；共享纯函数 HealthSnapshotMath.kt:13-59——但 Bootstrap 引擎仍内联同款算术、Provider 引擎复用，两副本漂移风险+ProviderHealthEngine.kt:167-170 死常量）。权重=(decayedS+2)/(all+3)×250/(ewma+.5jitter clamp 20..5000)×0.1^冷却×1/(1+.2连败)，clamp 0.05..3（BootstrapHealthStore.kt:27-40）；Provider 版另乘 hedgeMiss 惩罚（1/(1+share×1.5)，ProviderHealthStore.kt:40-41）。选路：排除冷却、探索率 2%/8%/10% 三档随机加权采样+权重降序 fallback（BootstrapHealthEngine.kt:41-75）。持久化 bootstrap_health_json/provider_health_json（D 容器单 JSON 键，merge 写、reset replace 写；HealthStoreJson.kt 防多引擎互踩）。`ActiveHealthEngineRegistry` 按 dataset 分槽、`clearIfCurrent` 用 `===`（ActiveHealthEngineRegistry.kt:17-42，教训条目落地）。dirty→15s 防抖 flush、close/进屏 commit（BootstrapHealthEngine.kt:230; BootstrapSettingsViewModel.kt:61）。
- **Bootstrap 探测即数据面**：BootstrapSelector 对启用节点 UDP:53 各发 A+AAAA，3s 超时/1500B 缓冲/事务 ID 校验/**TC 置位直接判失败（不退 TCP——与 PlainDnsTransport 策略不一致）**（BootstrapSelector.kt:163-206）；60s host 缓存、sourceKey 含节点指纹防陈旧（:134-161）；观测与解析结论隔离（recordOutcome :101-132）。日志批量 20 条/2s 刷 BootstrapLogDao（BootstrapLogger.kt:51-59,99-102）。
- **统计屏**：RaceStats/BootstrapStats 窗口 今日/7天/全部（RaceStatsViewModel.kt:28；statsRangeStartMillis util/DateTimeUtils.kt:85-89，SEVEN_DAYS=7d）；竞速排行截断 MAX_PROVIDER_ROWS=10（RaceStatsScreen.kt:139,153,263）；服务商健康页把智能预测候选权重归一为合计 100% 整数（最大余数法，ProviderHealthStore.kt:131-150; ProviderHealthScreen.kt:64-86）。日志裁剪 cutoff= log_retention_days（LogMaintenanceManager.kt:62,132-141，race/bootstrap/dns/http 四表同 cutoff）。

## 5. LLM Agent 助手

- **入口**：AI 分析 hub `AgentApiSettingsScreen`（路由 :396；功能中心 AGENT_API 卡与「其他设置」均可达；极速无入口）；子页 `AI_PROVIDER_MANAGEMENT/AGENT_API_CREDENTIALS/AGENT_API_PRESETS` 三路由同指 AiProviderManageScreen（:397-399），`AGENT_API_PARAMS`→参数屏（:400）。hub 内 AgentApiSubPage 枚举 4 值但 PROVIDERS/CREDENTIALS/PRESETS 都跳厂商管理（AgentApiSettingsScreen.kt:42-47,85-93）。
- **hub 结构**：服务状态卡（启用 Switch→即写 agent_api_enabled；厂商+模型卡；Key 就绪态 sk-•••• 掩码）+导航组+**功能测试 playground**（默认测试域 "tracking.analytics-service.net"，AgentApiSettingsComponents.kt:214；两按钮分别造 AnalysisTarget.Domain/RecentTraffic，Screen:136-143）+恢复出厂（AgentApiConfig() 全量重置+确认框，Screen:174-189）+说明；ON_RESUME 重读双源（config+activeProvider，:73-83）。底部常驻 AgentAnalysisSheet（:192-198）。
- **参数屏**：系统提示词多行框**每次击键即写盘**（AgentApiParamsScreen.kt:110-118→updateConfig:66-69）+3 个 FilterChip 模板（安全威胁/极简审查/隐私遥测，:71-75）；温度 Slider 0..2、19 步、0.1 取整即时写（:199-207），风格三档提示（≤0.3 严谨/≤0.8 平衡/否则发散，:209-213）；「恢复默认参数」=温度 0.7+提示词清空（:241-250）。
- **API 调用层（AgentApiClient）**：OpenAI 兼容**非流式**——chat() POST 完整 JSON body、整读响应体取 `choices[0].message.content`+`usage.{prompt,completion,total}_tokens`（AgentApiClient.kt:148-208）。超时 connect15s/read45s/write15s（:35-39），fetchModels read20s（:45-48）。端点智能补全双规则（resolveChatCompletionsEndpoint/resolveModelsEndpoint :285-312：已含 /chat/completions 原样；/v1 追加；/api→/v1/…；裸 openai/deepseek 域名补 /v1；否则追加 /chat/completions）。错误：HTTP 非 2xx 解析 `error.message`→「AI 请求失败 (code): msg」（:314-327）；空 Key IllegalArgumentException；缺 data/models 键报错。testConnection 用固定 10 词问候（:100-107）。**没有流式/SSE 解析**——「流式响应解析」在本 app 不存在（已证）。
- **AgentApiTextParser（剪贴板导入，ui/AgentApiTextParser.kt）**：契约——JSON 分支识别 `apiKey|api_key|key`、`baseUrl|base_url|url`、`model`（:57-59）；复合分支 URL 正则 `https?://[^\s,;"'()]+` + key 正则 `sk-[A-Za-z0-9_-]{16,}` 或 ≥32 位字母数字（可带 Bearer 前缀）（:82-83）；仅 URL 条件「行数≤2 且无 sk-」(≤98)；兜底整段去空白当 Key（:105-107）；sanitizeInput 剥 \r\n\t 空格（:113-120）。**实测全项目零调用点（grep 仅命中定义文件）——死代码，Flutter 重构勿照抄**（待定其历史入口）。
- **分析对象 AnalysisTarget**（ui/agent/AnalysisTarget.kt:8-17）：`Domain(domain, contextLogs)` / `RecentTraffic(source: RequestSource=ALL)`。调用点实测 7 处：AgentApiSettingsScreen.kt:138,141；normal/ui/RequestLogScreen.kt:249,328；normal/ui/ModernLogDashboardScreen.kt:199；ui/DnsCacheScreen.kt:150,262。Sheet 挂载 4 处（同文件 + AgentAnalysisSheet.kt:80 内部）；**server 模式日志屏无 AI 入口**（grep server/ui 无 AnalysisTarget/AgentAnalysisSheet——实测）；express 请求日志为独立屏（ExpressRequestLogScreen.kt:82）亦无 Sheet 挂载。
- **AgentAnalysisSheet**（364 行）：ModalBottomSheet 全展开（:71-87）；dataset 正确路由（RuleDatabases.forDataset/runtimeForDataset，http_request_log 仅 NORMAL，:100-110 注释记录修复原因）；执行链：空 Key→引导卡、`!enabled`→「开启并继续」即写+重跑（:276-293）；Domain→`SELECT queryName,result,message FROM dns_log … LIKE … LIMIT 5`（:136-144）；RecentTraffic→近 40 DNS+30 HTTP 聚合 top8（:152-186）；提示词四段结构（域名分析：画像/风险评级/处置建议/总结，AgentApiClient.kt:229-238；流量分析：总体/异常/拦截率/黑白名单建议，:264-272）；失败=errorMessage 卡+重试+跳设置（:299-306）；结果操作条仅 Domain：加白/加黑→`syncRuleIfRunning` 热更新+回执文案（:325-358）。
- **厂商管理 AiProviderManageScreen**（516 行）：上半「我的厂商」点行=切活跃（setActiveProviderId→syncProviderToConfig 回灌 :339-348）、铅笔=编辑；下半 16 预设分组点加=预填 baseUrl 草稿（:89-90,167-182）。编辑器对话框：名称/BaseURL/模型（在线拉取后 FlowRow Chips 点选，Key 空先拦「请先填写 API Key」，:215-231）/密码掩码+显隐；**编辑时 Key 留空=保留原密封值**（:260-264）；保存=upsert+置活跃（sealApiKey 经 KeyObfuscator，:241-282）；删除二次确认、活跃删除回落第一个（:188-207）。模型列表来源 AiModelFetcher.fetchModelIds：容忍 data/models/result 数组、id/model_id/name 字段、去重排序（AiModelFetcher.kt:58-84）；空列表抛「请手动填写」（:47-49）。

## 6. 多语言与本地化

- **双层机制**：①资源层 values/strings.xml 与 values-en/strings.xml 各 **216 条**（本会话 grep -c 实测），其中 `localized_text_*` 各 **112 条**中英一一对应、`feature_hub_*` 各 38 条；②运行时替换层 LocalizationEngine.translate 四段链（LocalizationEngine.kt:46-53）：(1) 中文原文→`stableTextResourceName`：`31*hash+code` 32 位回绕，`toLong().and(0x7fffffff)`（正数=原值、负数=2^31−|h|，非 abs）拼 `localized_text_<n>` 查资源（:37-41）——**资源表本质是「中文→哈希资源名」字典**；(2) `translate*Exact` 10 域文件 when 链（:85-96）；(3) `translate*Pattern` 10 链（:98-109，DynamicPattern 殿后）；(4) 原文返回。两级 ConcurrentHashMap 缓存，负缓存哨兵上限 4096（:21-35,65-71）。
- **词典规模实测**（grep `" -> "`）：Common 521、RulesAndSubscription 475、SettingsAndAppearance 385、HttpInspection 96、DnsResolution 94、About/AppMgmt/LogsAndStats/NetworkTools 各 90、HomeAndOverview 19、DynamicPattern 0（纯 replace/前后缀模板，另含 173 个 pattern 分支；NetworkTools 是唯一用 Regex matches 的 pattern 域）。Exact 合计约 1950 条。**RulesAndSubscription 为在用代码**（引擎 :89 引用——「整文件停用」传闻已证伪）。
- **死资源实证**（本会话两版独立哈希对账，85/87 命中现行算法一致，**约 25-27 条 `localized_text_*` 名称与现行 `and(0x7fffffff)` 及 abs 算法均不可达**，疑为历史算法变更残留；抽样复核：「解析服务（」资源名 944478425 vs 现算 1203005223、「单应用域名放行」1219167136 vs 904590853）——对应文案由词典链兜底（DnsResolutionLocalization.kt:70、RulesAndSubscriptionLocalization.kt:371 等实测在表），但词典译文与死资源译文存在漂移（「解析服务（」→"Resolution provider (" vs 资源侧另一译文）。
- **语言开关**：`app_language_mode` system/zh/en（AppLanguageManager.kt:12-14）；`wrap()` 把 SYSTEM 折叠为 zh 或 en（:38-50）——应用从不真正走设备默认；Activity 侧 `AppLocalizedActivity.attachBaseContext(wrap)`（AppLocalizedActivity.kt:12-13），MainActivity/SettingsRouteActivity 继承并在 onResume 比对语言 `recreate()`（MainActivity.kt:222; SettingsRouteActivity.kt:188-192）。入口 `localizedText()`（Composable）看 `LocalConfiguration.locales[0]=="en"`（LocalizedTextHelper.kt:14-22）；`localizedText(context,…)` 先 wrap 再判（:28-35，Service/Worker/通知用）；`localizedResource` 供资源 id 场景，注释记录「格式串与参数须同源，否则半翻译」（:37-59；同型修复 RaceModeSettingsViewModel.kt:248-252 O-121）。全工程 localizedText 调用实测 1567 处、屏内 stringResource 23 处、localizedResource 消费面含通知渠道/磁贴/Worker 进度（AppNotificationChannels、DitingTileService:185、RuleOperationWorker 等）。**残留未闭环**：两处通知标题仍裸 `getString(R.string.app_name)` 跟系统 locale（VpnNotificationBuilder/ExpressNotificationBuilder）。**SettingsGuideHost 例外看系统 locale**（SettingsGuide.kt:160），指南语言可与语言设置错位。
- **自定义文案两条路径相反**：首页句子 home_sentence_running/stopped 渲染时**过整条翻译链**（MainScreenContent.kt:138、ExpressHomeContent.kt:153 `localizedText(homeSentence)`；默认诗句「谛听万象…」在词典有英文对译 "The readiness is all."/"The rest is silence."，HomeAndOverviewLocalization.kt:15-16——用户自定义中文一般兜底原样显示）；通知栏自定义文案则**原样输出不过链**（VpnNotificationBuilder.kt:47、ExpressNotificationBuilder.kt:61）。配置迁移链路含 home_sentence 键（ui/transfer/ConfigExporter.kt:319-320→ConfigTransferParser.kt:317）。

## 7. 关键源码引证表

| 事实 | 位置（相对 Android/app/src/main/java/com/haoze/diting/） |
|---|---|
| 三 prefs 文件/JSON 集合读写扩展 | data/RuleDataset.kt:24-28; ui/settings/SettingsPreferencesExtensions.kt:8-28 |
| 解析模式枚举+旧值兼容（parallel_race/race→BRUTE_FORCE_PARALLEL） | ui/DnsResolutionMode.kt:12-16; ui/RaceModeStrategy.kt:12-19（RaceModeStrategy 仅用于 race_log 统计/展示，分发在 express/engine/ExpressUpstreamDispatcher.kt:114-115） |
| 缓存 9 键+钳位 | ui/settings/DnsCacheSettingsStore.kt:10-26,76-97 |
| Bootstrap 预设表/校验 | core/diagnostic/BootstrapIpModels.kt:15-23,26-49 |
| 服务商 18 预设/CRUD 联动删除 | core/dns/DnsProvider.kt:58-197,318-337 |
| 代理 Keystore 加密+错误映射 | ui/settings/OutboundProxySettingsStore.kt:154-188,134-152 |
| Agent 双层键+迁移+回灌 | ui/settings/AgentApiSettingsStore.kt:252-380 |
| 端点补全/非流式 chat/usage | ui/settings/AgentApiClient.kt:148-208,285-312 |
| 剪贴板解析器（死代码） | ui/AgentApiTextParser.kt:43-108（零调用实测） |
| AnalysisTarget 7 调用点 | ui/agent/AnalysisTarget.kt:8-17 及各调用行见 §5 |
| ping/trace 命令与回退 | core/diagnostic/NetworkPingTool.kt:82-99,153-198; NetworkTraceRouteTool.kt:156-164,104-106 |
| 隧道钩子注册 | core/diagnostic/TunnelDiagnosticsResolver.kt:12-13; DitingApp.kt:55 |
| 健康算法 | core/diagnostic/BootstrapHealthEngine.kt:41-124,230-244; BootstrapHealthStore.kt:27-40; HealthSnapshotMath.kt:13-59 |
| 本地化哈希/链/缓存 | ui/localization/LocalizationEngine.kt:37-41,46-110 |
| 语言 wrap | ui/AppLanguageManager.kt:38-50; ui/LocalizedTextHelper.kt:14-59 |
| Runtime refresher 静默门 | core/rule/RuntimeDnsSettingsRefresher.kt:35-65,160 |

## 8. Flutter 重构注意

- **持久化映射**：三个 SharedPreferences 文件 → shared_preferences 按 dataset 前缀命名空间；独立 prefs（network_tools_settings/notification_settings_prefs/permission_disclosures）作独立域即可。`SettingsPreferencesExtensions` 的 JSONArray 字符串集与 coerceIn 钳位必须在保存层复刻（表 §2 内逐键标注），否则旧脏值穿透；启动自检（StartupSelfCheck 5 项）值得原样移植。`_v2/_v3` 键后缀是历史迁移产物，新实现建议只保留档位模型。代理账密 AndroidKeyStore 属强保护，Flutter 侧用 flutter_secure_storage 或原生通道；KeyObfuscator 仅是混淆（3 组 XOR+Base64），迁移时按明文对待并统一。
- **必须保留原生**：①`ping/ping6` 子进程+输出正则+isReachable/TCP 回退（Dart 无 ICMP）；②ConnectivityManager.getConnectionOwnerUid/LinkProperties.dnsServers（UidPackageCache.kt:96-108、NetworkInfoProbe.kt:77，API 29+/allNetworks 弃用注释在案）；③VpnService.protect（探测绕自家 VPN 的根机制）；④gomobile ResolveDomain JSON 桥（TunnelDiagnosticsResolver）；⑤AndroidKeyStore、SAF 持久 URI 授权。UDP DNS 裸查询（BootstrapSelector/DnsLookupTool/DnsRecordParser）可纯 Dart 重写，但需照搬 1500B 缓冲、TC→失败/回退策略差异与事务 ID 校验。
- **设置屏共性模式**：即写即生效+RuntimeDnsSettingsRefresher（未运行静默）是全局契约，Flutter 需等价「保存→通知运行中引擎」通道；例外三屏为「确定才保存」（HomeSentence、Notification 文案、OutboundProxy 表单）——迁移时勿统一成即时保存。
- **本地化**：Flutter 应改用 ARB/intl 并保留中文源语言，抛弃哈希查表；三个坑必移：wrap() 的 system→zh/en 折叠语义、localizedText 按 locale 标签判定与设置项解耦、通知/磁贴独立 locale（§6）。死代码 `AgentApiTextParser`、OptionalFeature 兼容层、ProviderHealthEngine 死常量（:167-170）与 Bootstrap/Provider 双份 EWMA 算术应合并，不照抄。
- **诊断偏差留档**（真机复核后再定 Flutter 行为）：traceroute 每跳 1 包且无去重、`-t` 兼容性；Bootstrap UDP 截断不退 TCP；RaceStatsScreen.kt:95-97 provider 名映射未带 dataset（EXPRESS/DNS_MODE 下靠落库名回退）。

## 9. 待定清单

1. express 设置屏隐藏控件穷举已完成三处（局域网/实时速率/底栏与功能中心），其余（如悬浮日志）入口分布待第 03/05 章交叉。
2. bypass_lan 在 server 模式是否有独立语义——待第 04 章。
3. localizedText 按系统 locale 而设置按 AppLanguageMode 的失配是否构成可复现回归——需真机（系统 zh + 应用 en）验证。
4. `negativeTtl*`、悬浮日志键、agent 旧明文 key 的完整消费方清单分属 07/05/09 章，本表只记定义侧。
5. AgentApiTextParser 死代码的历史入口（疑似曾挂厂商编辑器粘贴按钮）——git 考古未做。
6. SettingsGuideHost 英文文案与语言设置解耦、GOLD storageValue="indigo" 是否为笔误——未判。
7. BootstrapIpValidator IPv6 弱校验与 isValidDnsHost(:350-358) 口径差异的实际后果——标缺陷候选，未定罪。
