# DITING Android → Flutter 重构功能图谱

> 本系列是对现有 Android 项目（`Android/app` + `Android/tunnel`）**只读考古**的产物，作为 Flutter 彻底重构的功能规格与决策依据。
> 分析基线：`main` 分支 commit `dda2779`（v1.4.3，versionCode 10403）。分析日期：2026-10-18。
> **红线**：本系列撰写全程未修改任何项目代码与既有配置；所有计数与引证均来自分析会话的真实工具输出。

## 阅读顺序建议

1. 先读本文件与 [01 基础设施与启动](01-foundation-and-startup.md) 建立骨架认知；
2. 按重构模块顺序读：数据/规则 → 内核 → 各模式 → 系统周边 → UI；
3. 动手写 Flutter 代码前，必读 [14 迁移总策略](14-migration-strategy.md) 与 [13 测试规格](13-tests-and-assets.md)。

## 章节索引

| 章 | 文件 | 域 | 覆盖包/目录（Android/app/src/main/java/com/haoze/diting/ 下，另注明者除外） |
|---|---|---|---|
| A | [00-file-inventory.md](00-file-inventory.md) | 附录：522 文件逐文件点名索引（行数/归属章，机械生成） | 全仓 |
| 01 | [01-foundation-and-startup.md](01-foundation-and-startup.md) | 基础设施、配置键、启动、工程构建与打包 | 根 5 文件、`util/`、`main/`、Manifest、gradle/bat/res/xml |
| 02 | [02-data-layer-rules.md](02-data-layer-rules.md) | Room 数据层 + 规则引擎核心 + 订阅体系 | `data/`（含 entity/dao/repository/cleanup）、`core/rule/` |
| 03 | [03-navigation-and-main-ui.md](03-navigation-and-main-ui.md) | 导航骨架、首页、工作模式体系、引导 | `ui/mode/`、`onboarding/`、主屏/导航相关 ui 文件 |
| 04 | [04-rules-ui.md](04-rules-ui.md) | 规则/订阅/服务商/应用规则的全部 UI 与 ViewModel | 黑白名单/覆写/订阅/应用选择相关 ui 文件、`ui/batch/` |
| 05 | [05-traffic-log-system.md](05-traffic-log-system.md) | 流量统计、日志体系、悬浮窗、通知、Tile、崩溃、更新、权限、导入导出 | `core/traffic/`、`core/log/`（部分）、`ui/traffic/`、`ui/dashboard/`、`ui/floating/`、`notification/`、`tile/`、`crash/`、`update/`、`permission/`、`ui/transfer/` |
| 06 | [06-settings-network-agent.md](06-settings-network-agent.md) | 设置体系全表、网络诊断工具、LLM Agent、本地化引擎 | `ui/settings/`、`core/diagnostic/`、`ui/agent/`、`ui/localization/`、诊断/设置相关 ui 文件 |
| 07 | [07-dns-kernel.md](07-dns-kernel.md) | Kotlin DNS 内核：缓存/调度/传输/报文 | `core/cache/`、`core/dns/` |
| 08 | [08-express-mode.md](08-express-mode.md) | 极速模式全链路（纯 Kotlin DNS 窄路由 VPN） | `express/` 全部 |
| 09 | [09-normal-mode-vpn.md](09-normal-mode-vpn.md) | 普通模式 Kotlin 编排 + Kotlin↔Go 桥接契约 | `normal/` 全部 |
| 10 | [10-go-tunnel-engine.md](10-go-tunnel-engine.md) | Go 引擎数据面全貌（gomobile AAR） | `Android/tunnel/` 全部 85 文件 |
| 11 | [11-server-mode.md](11-server-mode.md) | 服务器模式（局域网 DNS 服务） | `server/` 全部 |
| 12 | [12-ui-components.md](12-ui-components.md) | 设计系统：组件库、主题色板、特效、Markdown 渲染 | `ui/components/`、`ui/component/liquid/`、`ui/theme/`、`ui/agent/` 渲染组件等 |
| 13 | [13-tests-and-assets.md](13-tests-and-assets.md) | 测试行为规格库 + 覆盖空白图 + 资源/备份规则 | `src/test/`、tunnel `*_test.go`、`res/`、`recognition_members.json`、`avatars/` |
| 14 | [14-migration-strategy.md](14-migration-strategy.md) | 跨章汇总：Flutter 架构映射、进程模型、依赖选型、里程碑（本文件作者亲自撰写） | 全系列 |

> 超长章节以同编号续篇拆分（如 `02-data-layer-rules-2.md`），主篇文末均有指向；全量 25 份文件一览见 [00-file-inventory.md](00-file-inventory.md)（附录 A：逐文件点名索引）。

## 全项目基础事实（Lead 本会话实测，非引用 README）

- **模块构成**：单 Gradle 模块 `:app`；Go 引擎独立目录 `Android/tunnel`，经 gomobile 编译为 `app/libs/tunnel.aar` 以 `implementation(files(...))` 引入。
- **规模实测**：`src/main` 522 个 `.kt` / 92,185 行；`src/test` 99 个 `.kt`；`Android/tunnel` 85 个 `.go`（含 ~20 个 `_test.go`）。Kotlin 顶层包 40+，文件数 Top：`ui/`116、`core/rule/`42、`normal/ui/`24、`data/entity/`20、`ui/settings/`18。
- **版本**：versionName 1.4.3 / versionCode 10403；AGP 9.2.1、Kotlin 2.3.10、Compose BOM 2026.02.01、Room 2.7.0(KSP)、OkHttp 4.12.0、Paging 3.3.6、WorkManager 2.10.1；compileSdk 36.1、targetSdk 36、minSdk 24、ABI 仅 `arm64-v8a`；Java 11；release 开启 R8+资源压缩；locale 过滤 zh/en/zh-rCN。
- **Manifest 组件全集**：3 个 VpnService 类服务（`.normal.DnsVpnService`、`.express.ExpressVpnService`、`.server.backend.DnsModeService`）+ `.notification.VpnMonitorService`（第三方 VPN 冲突监控）+ QS Tile（`.tile.DitingTileService`）+ FileProvider + `DnsModeBootReceiver`（开机自启）+ 6 个 Activity（`MainActivity` 经 activity-alias 挂 LAUNCHER、`SettingsRouteActivity`、`WorkModeActivity`、`ModeOnboardingActivity`、`LogRouteActivity`、`server.DnsMainActivity`）。
- **权限 13 项**：INTERNET、ACCESS_NETWORK_STATE、FOREGROUND_SERVICE(+DATA_SYNC/SPECIAL_USE)、POST_NOTIFICATIONS、REQUEST_INSTALL_PACKAGES、REQUEST_IGNORE_BATTERY_OPTIMIZATIONS、QUERY_ALL_PACKAGES、GET_INSTALLED_APPS、SYSTEM_ALERT_WINDOW、WAKE_LOCK、RECEIVE_BOOT_COMPLETED。
- **工作模式枚举**（`ui/mode/AppWorkMode.kt:20-46`）：`NORMAL`（storageValue "normal"，minApi **29**）、`DNS`=服务器模式（"dns"，minApi **29**）、`EXPRESS`（"express"，minApi **24** 且要求 64 位设备 `isSupportedOnCurrentDevice()`，`AppWorkMode.kt:48-61`）。默认回退 NORMAL（`fromStorageValue`，:64-66）。
- **模式运行状态存储**（`core/VpnStateRegistry.kt:10-30`）：普通=`dns_vpn_prefs.vpn_running`，极速=`express_vpn_prefs.express_vpn_running`，跨组件广播 `com.haoze.diting.VPN_STATUS_CHANGED`（:32）。
- **依赖注入**：无 Hilt/Dagger——手写单例 + 注册表闭包（如 `VpnStateRegistry` 的可替换 lambda）；Application 为 `.DitingApp`。
- **数据库（实测）**：三个 Room 库共享同一套 Entity/DAO 类型——`AppDatabase`（20 实体，version 3，普通模式主库；实现 `RuleDataSources`+`DnsRuntimeDataSources` 接口，`data/AppDatabase.kt:91-130`）、`ExpressRulesDatabase`（version 2，库名 `diting_express`，极速模式全量独立库，`:59-99`）、`DnsRulesDatabase`（version 3，库名 `diting_dns_rules`，服务器模式规则库；类注释明示「与 VPN 模式互不可见、永不迁移数据」，`:80-112`）。表级细节见 02 章。
- **Go 引擎依赖**（`Android/tunnel/go.mod`）：miekg/dns、quic-go（DoH/DoQ）、xjasonlyu/tun2socks/v2、gvisor.dev/gvisor（用户态 TCP/IP 栈，MITM 用）、sagernet/gomobile + golang.org/x/mobile（绑定）、golang.org/x/net|sys；Go 1.23.5。**许可证注意：应用本体 GPL-3.0（README 声明），tun2socks、quic-go 等各有自己的 copyleft/许可条款——Flutter 重构若保留 Go 层，分发合规需逐依赖复核，不能假设「换语言就绕开」。**
- **命名陷阱（Flutter 侧建议重命名）**：包/类语义与直觉相反——`normal` = 全隧道 Go 模式、`server/model.DnsMode*` 的 "Dns" = 服务器模式、`ui/LogRouteActivity` 承载日志路由。映射表见 14 章。

## 文档维护约定

- 每章 YAML 的 `最后校验` 日期表示该章全部断言在该日之前逐条回读过源码；修订时同步更新。
- 「待定」条目必须写明缺哪类证据，供下一轮或真机验证补齐；不得当作结论引用。
