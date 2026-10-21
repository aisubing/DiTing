# 15 · 旧版对齐审计表（第三轮）

> 口径：**旧版 = `C:\Users\leehaoze\DITING\Android`（1.4.3，Kotlin/Compose）**，
> **新版 = 本仓 `DITING_flutter`**。第三轮的约束是「旧版存在的界面和功能必须
> 保留，旧版不存在的界面、菜单及设置项一律移除」，同时**完全沿用新的 UI 设计
> 体系**（`lib/ui/` 零改动）。
>
> 判「旧版有没有」的唯一权威不是枚举声明，而是**真正被渲染的入口集合**。旧版
> 里有大量「声明了但没进 `all` 列表」的死条目（`ScreenDestinations` 的
> `outboundProxy` / `raceModeProviders` / `dataCleanup` / `agentApiSettings`），
> 它们不会出现在任何页面上，因此**不算旧版存在的界面**，不得迁移。

## 一、判定方法

| 判据 | 做法 |
|---|---|
| 路由是否存在 | 读 `ui/Routes.kt` 的常量，再回读 `SettingsRouteActivity.kt` 的 dispatch 分支——只有被 dispatch 的才算可达 |
| 设置项是否渲染 | 读 `ui/SettingsScreen.kt`：它按 `ScreenDestinations.mainEntries` 渲染，`mainEntries` 又只来自 `ScreenDestinations.all`（六条）；空组跳过 |
| 底栏项 | `ui/BottomBarDestination.kt` 六项、MIN 2 / MAX 4，默认 HOME/FEATURE_HUB/LOG_DASHBOARD |
| 功能中心卡片 | `FeatureHubScreen.kt` / `ExpressFeatureHubScreen.kt` 的 `add(...)` 调用序列 |
| 服务端界面 | `server/ui/navigation/DnsNavigation.kt` 三 Tab + `server/ui/DnsSettingsScreen.kt` 分组 |

## 二、路由对齐表

状态说明：**保留**＝本轮未改动；**重写**＝结构改成旧版形状；**新增**＝旧版有、
新版此前缺失；**删除**＝旧版没有、本轮移除；**保留项**＝旧版没有但用户明确要求
保留，需给出唯一入口。

### 2.1 底栏与一级页

| 旧版 | 新版路由 | 状态 | 说明 |
|---|---|---|---|
| `HOME` | `/` | 重写 | 仪表盘卡片集换成旧版 `AllModeDashboard` 的块；保留可编排（决策 C） |
| `FEATURE_HUB` | `/hub` | 保留 | 28 卡与旧版逐字一致（`feature_hub_migration_test` 守） |
| `LOG_DASHBOARD` | `/logs` | 重写 | 顶部三档日志模式 + 三套块组合 |
| `APP_TRAFFIC_STATS` | `/traffic` | 重写 | 删时间窗口/排序/搜索/会话曲线（旧版无） |
| `NETWORK_TOOLS` | `/tools` | 重写 | 四 Tab：测速 / Ping 测试 / DNS 解析 / 路由追踪 |
| `SETTINGS` | `/settings` | 重写 | 五组六行，标题「其他设置」 |

### 2.2 设置与外观

| 旧版 | 新版路由 | 状态 |
|---|---|---|
| `WORK_MODE_SELECTION` | `/mode/select` | 保留 |
| `USAGE_WIZARD` | `/mode/onboarding` | 保留 |
| `CACHE_SETTINGS` | `/hub/cache` | 保留 |
| `LOG_RETENTION_SETTINGS` | `/hub/log-retention` | 重写（接三档日志模式与保留天数） |
| `FOREGROUND_BACKGROUND_SETTINGS` | `/settings/background` | 新增 |
| `LANGUAGE_SETTINGS` | `/settings/language` | 新增 |
| `APPEARANCE_SETTINGS` | `/theme` | 重写（3 组 8 项菜单） |
| ↳ 日夜模式 | `/theme/day-night` | 新增 |
| ↳ 主题色配置 | `/theme/color` | 新增 |
| ↳ 首页透明度 | `/theme/home-opacity` | 新增 |
| ↳ 底栏自定义 | `/theme/bottom-bar` | 新增 |
| ↳ 首页句子 | `/theme/home-sentence` | 新增 |
| ↳ 通知栏设置 | `/theme/notification` | 新增 |
| ↳ 软件背景 | `/theme/background` | 新增 |
| —— | `/font-family` | 保留项 |

### 2.3 日志与下钻

| 旧版 | 新版路由 | 状态 |
|---|---|---|
| `DNS_LOGS` / `HTTP_REQUEST_LOGS`（同页来源分段） | `/requests` | 重写（来源 全部/DNS/HTTPS + 六档状态 + 导出 CSV） |
| `DNS_CACHE` | `/logs/cache` | 新增 |
| `RACE_STATS` | `/logs/race` | 新增 |
| `BOOTSTRAP_STATS` | `/logs/bootstrap` | 新增 |
| `SUBSCRIPTION_INTERCEPTION_STATS` | `/logs/subscription-stats` | 新增 |
| `DNS_QUERIES` | —— | 删除（与 `/requests` 来源=DNS 同表同状态，旧版无独立页） |

### 2.4 关于与更新

| 旧版 | 新版路由 | 状态 |
|---|---|---|
| `ABOUT` | `/about` | 重写（核心能力 / 运行边界 / 项目卡 / 页尾小字） |
| `SPONSOR` | `/sponsor` | 重写（三段文案） |
| `APP_UPDATE` | `/app-update` | 重写（+ 关闭启动检查 + QQ 群） |
| 首启弹窗 `使用须知与免责声明` | —— | 新增为应用层弹窗（`lib/app/initial_agreement.dart`） |
| `DISCLAIMER` | —— | 删除独立路由（旧版是弹窗 + 关于页一节） |

### 2.5 删除清单（旧版不存在）

| 新版路由 | 归属 | 删除理由 |
|---|---|---|
| `/proxies`、`/proxies/providers` | FlClash | 旧版无代理组概念 |
| `/profiles` 及 14 条子页 | FlClash | 旧版无配置档案 |
| `/config/general`、`network`、`tun`、`dns`、`ntp`、`sniffer`、`override`、`filters`、`rules`（追加规则）、`scripts`、`providers`（Clash）、`advanced` | FlClash | 旧版无内核配置 |
| `/access` | FlClash | 旧版的应用管控在 `/hub/excluded-apps` 等页 |
| `/backup` | FlClash | 旧版 WebDAV 只是备份页里的一张表单 |
| `/error` | —— | 全仓无入口 |
| `/theme/preview` | FlClash | 旧版外观设置无整页预览 |
| `/disclaimer` | —— | 改为首启弹窗 |
| `/agent` | —— | 与 `/hub/agent` 重复 |
| `/apps` | —— | 零引用；旧版「排除应用」在 `/hub/excluded-apps` |
| `/dashboard/profile` | FlClash | 配置档案删除后无宿主 |

## 三、保留项（旧版没有，用户要求保留）

这 18 项**不删**，但旧版没有对应菜单，因此不能新增设置行/菜单项。落点如下：

| 保留项 | 落点 | 入口 |
|---|---|---|
| 图标集 / User-Agent / 按需连接 | `/config/icon-sets`、`/config/user-agents`、`/config/on-demand` | `/config/custom-resources`（收为三行）→ `/developer` |
| 活动连接 / 资源更新 / IP 质量 | `/connections`、`/resources`、`/ip-quality` | `/developer` 组「诊断与观测」 |
| 组件画廊 / 表单演示页 / 扫码 / 编辑器 | `/demo`、`/form`（+5 子页）、`/scan`、`/editor` | `/developer` 组「设计与演示」 |
| 开发者选项 | `/developer` | **设置页顶栏扳手图标**（唯一新增的可点元素） |
| WebDAV | `/hub/config-transfer/webdav` | `/hub/config-transfer` 页尾一组 |
| 字体 | `/font-family` | `/theme` 的「界面显示」组 |
| 纯黑 / 字号 | —— | `/theme` 的「界面显示」组内联控件 |
| 底栏样式 / Tab 动画 / 液态玻璃 | —— | `/theme` 的「背景与动效」组 |

**入口自造的唯一一处**是设置页顶栏的扳手图标。理由：保留页需要可达，而设置
列表必须严格保持旧版的五组六行，一个不多一个不少。`retained_pages_reachable_test`
守这条：17 个保留路由都必须能从 `/developer` 或其他既有页进入，防孤儿。

## 四、数据与原生通道

### 4.1 新增落盘键（全部照抄旧版容器与键名）

| 键 | 容器 | 默认 | 来源 |
|---|---|---|---|
| `dns_log_mode` | 数据集（`dns_vpn_prefs` / `diting_express_prefs`） | `all` | `SystemSettingsStore` |
| `log_retention_days` | `dns_vpn_prefs` | 7（1–30） | `SystemSettingsStore` |
| `floating_log_enabled` | `dns_vpn_prefs` | false | `SystemSettingsStore` |
| `hide_from_recents_enabled` | `dns_vpn_prefs` | false | `SystemSettingsStore` |
| `bypass_lan_enabled` | `dns_vpn_prefs` | true | `SystemSettingsStore`（本轮补写侧） |
| `ipv6_mode` | 数据集 | `auto` | `SystemSettingsStore` |
| `app_language_mode` | `dns_vpn_prefs` | `system` | `AppearanceSettingsStore` |
| `initial_agreement_accepted` | `dns_vpn_prefs` | false | `SystemSettingsStore` |
| `disable_startup_update_check` | `dns_vpn_prefs` | **true**（默认不检查） | `SystemSettingsStore` |
| `custom_background_enabled` / `_uri` / `_uris` | `dns_vpn_prefs` | false / null / [] | `AppearanceSettingsStore` |
| `persistent` / `speed` / `custom_running_text` / `custom_stopped_text` | **`notification_settings_prefs`** | true / false / '' / '' | `NotificationSettingsStore` |
| `home_dns_detail_opacity` | `dns_vpn_prefs` | 1.0 | `AppearanceSettingsStore` |

> 通知栏四键的容器是独立的 `notification_settings_prefs`，不是 `dns_vpn_prefs`。
> 写错容器界面上看不出任何区别，但前台服务读的是前者——通知栏行为不会变。

### 4.2 新增原生通道

| 通道 | 方法 | 旧版对应 |
|---|---|---|
| `com.haoze.diting/dns_latency` | `probe(providers, domain, attempts)` | `core/dns/DnsLatencyTester` + `ui/DnsSpeedTestSection` |
| `com.haoze.diting/platform` | `applyRecentsPrivacy` / `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations` / `crashLogCount` / `clearCrashLogs` / `exportText` | `RecentsPrivacyController` / `SystemSettingsStore` / 崩溃目录 / CSV 导出 |

测速通道的契约以 `lib/data/native/dns_latency_bridge.dart` 为准；Kotlin 侧
`net/DnsLatencyBridge.kt` + `net/DnsLatencyTester.kt` 按同一契约实现，通道缺失时
页面显示「当前设备不支持测速」并禁用按钮，**不用假数字顶替**。

## 五、已知边界（不迁移，附理由）

| 条目 | 理由 |
|---|---|
| `PROVIDER_HEALTH` | 旧版只在 `LogRouteActivity` 的 dispatch 分支里声明，全仓无 `onNavigateToProviderHealth` 调用点，且 `provider_health_json` 在本仓没有写入者 |
| `ScreenDestinations` 的 `outboundProxy` / `raceModeProviders` / `dataCleanup` / `agentApiSettings` | 不在 `all` 里，旧版自己也不渲染 |
| `resolutionSingle/Smart/Parallel/Backup` | 同上，不在 `all` 里 |
| `app_traffic_stats_enabled` / `traffic_stats_retention_days` / `traffic_stats_hide_system_apps` | 旧版**没有任何设置界面**（仅服务端读取），新版也不得新增界面 |
| `通知常驻` 的「VpnMonitorService 宿主」 | 旧版有独立的 monitor 前台服务；本仓只做了通知文案与 ongoing 开关，独立 monitor 服务未迁移（影响：关闭主服务后不再保留一条「已停止」通知） |

## 六、验证

| 测试 | 守什么 |
|---|---|
| `route_catalog_test.dart` | 每条路由可 build 且不落兜底页 |
| `layout_regression_test.dart` | 3 档宽度 × 1.4 倍字号无溢出 |
| `app_shell_test.dart` | scopes 位置、branch 保活、路由清单 |
| `settings_catalog_test.dart` | 设置键名/容器/默认值、路由形状、底栏上限 4 |
| `retained_pages_reachable_test.dart` | 17 个保留路由都有入口，防被当孤儿删掉 |
| `feature_hub_migration_test.dart` | 28 卡标题与旧版逐字一致 |
| `body_top_inset_test.dart` | 每个 `body:` 都预留顶栏浮位 |
