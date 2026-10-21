# 谛听 DITING · Flutter 客户端

> 本目录是**新版主力工程**（原名 `DITING_flutter/`，现名 `DITING-Flutter/`）。
> 旧版 Kotlin 1.4.3 基线已停止维护，位于仓库内 `../DITING-Legacy/`，仅供对照实现。

DITING 1.4.3 的 Flutter 重写。`lib/ui/` 是上游设计体系的逐文件移植，应用层独立编写；
数据层**直接读写旧版 1.4.3 的 SharedPreferences 与 SQLite**，因此覆盖安装后用户的设置、
规则、日志与统计保持原值。

- 平台 Android（`android/`，包名 `com.haoze.diting`）；Flutter 3.47.7 / Dart 3.13.5；
  `flutter_riverpod` + `go_router` + `sqflite`
- 本文件是**唯一** Markdown 文档。代码、测试与 `AGENTS.md` 是其余信息的权威来源。

```bash
flutter pub get
flutter analyze lib test      # 期望 No issues found
flutter test
flutter build apk --debug     # 或跑 build_apk.bat
```

## 1. 许可与来源

本项目**不是**从零设计的外观：`lib/ui/` 整层、两套字体、玻璃着色器与主题组装方式移植自
[DITING](https://github.com/chen08209/DITING)，版权归其作者，**GPL-3.0-or-later**；本项目
同为 GPL-3.0。分发二进制或源码须同时提供 GPL-3.0 全文并保留各文件首行的版权头。

| 来源 | 移植到 |
|---|---|
| 上游 `lib/ui/**` | `lib/ui/**`：逐文件复制，`package:fl_clash/` → `package:diting/`，超行数的拆 `part` |
| 上游 `lib/common/input_limits.dart`、`iterable.dart` | `lib/ui/support/`（仅这两份被 `lib/ui` 引用） |
| 两套字体、`shaders/liquid_glass.frag` | `assets/fonts/`、`shaders/`（原样复制；Twemoji 图形版权 CC-BY 4.0） |

GPL-3.0 全文见本目录的 `LICENSE`（仓库根没有另一份）。

- **有意未移植**：上游 `sidebar.dart`、`table_layout.dart`、`super_reorderable_list.dart`
  （桌面布局）与 `paged_sheet.dart`（上游仅被 barrel 导出、零调用点）。这是决定，不是欠账。
  上游其余 `lib/`（`views/`、`pages/`、`features/`、`providers/`、`models/`、`manager/` 等）
  全部未移植，应用层是独立编写的。
- 对本项目内移植代码的修改只有四类：包名改写；按 ≤550 行拆 `part`（拆出的成员以
  `_g_<name>_` 顶层私有常量承载、原类保留 `static const` 转发，公共 API 不变）；手写
  `lib/ui/models.dart` 替代 freezed；`lib/ui/analysis_options.yaml` 关闭三条与上游风格冲突
  的 lint（`lib/app` 等不受影响）。

第三方 Dart 包许可以 `pubspec.yaml` 为准（BSD-3-Clause / Apache-2.0 / MIT）。
**Go 引擎（`android/app/libs/tunnel.aar`）另有合规义务**：其 `go.mod` 依赖 `tun2socks`、
`quic-go`、`gvisor` 等各有 copyleft/许可条款，分发前须逐依赖复核——换写成 Dart 也绕不开，
引擎仍是该 AAR。

## 2. 构建与签名

**必须走 `flutter build apk`**。直接调 Gradle 只编译 Android 壳，Dart 代码不会进 APK，装上
去是空壳或闪退；`flutter build` 会先跑 `flutter assemble` 产出 Dart 快照再调 Gradle。
交互式脚本 `build_apk.bat` 打包了 Debug / Release / per-ABI / Clean 与 ADB 安装，等价命令：

```bash
flutter build apk --debug      # 产物 build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release    # 或 --release --split-per-abi
```

> **`build_apk.bat` 必须保持纯 ASCII**。`cmd.exe` 按 OEM 代码页（本机 936）解析批处理，
> UTF-8 中文会被错切并把 `if`/`goto` 截断成非法命令；`chcp 65001` 写在文件里也救不了
> ——解析发生在它生效之前。中文说明只放本文件。

**签名**：`android/key.properties` 与 `android/keystore/diting-release.jks` **不入库**（分别由
`android/.gitignore` 与根 `.gitignore` 忽略），新克隆需从备份取回 —— `storeFile` 写
`../keystore/diting-release.jks`（相对 `android/app/`，也兼容相对 `android/` 与 `app/`），
另有 `storePassword` / `keyAlias=diting-release` / `keyPassword`。CI 可改用环境变量
`DITING_KEYSTORE_FILE` / `DITING_KEYSTORE_PASSWORD` / `DITING_KEY_ALIAS` /
`DITING_KEY_PASSWORD` 避免落盘。

**缺密钥不报错**：`android/app/build.gradle.kts` 检测不到密钥时自动回退 debug 签名，
`--release` 照样成功，只是产物不是正式签名。**构建通过不等于签名正确**，验收看指纹：

```bash
keytool -list -v -keystore android/keystore/diting-release.jks \
        -storepass <口令> -alias diting-release | grep SHA256
$ANDROID_HOME/build-tools/<ver>/apksigner verify --print-certs \
        build/app/outputs/flutter-apk/app-debug.apk
```

两者 SHA-256 一致即正确；正式密钥 DN 是 `CN=DITING, OU=DITING Team, O=DITING, C=CN`，
出现 `CN=Android Debug` 说明回退了 debug 密钥。

**`signDebugWithRelease` 默认为 `true`**：不带参数时 `flutter build apk --debug` 也用正式密钥
签名（debug 包要能覆盖安装已发布的正式版，否则 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`）。要
验证「debug 密钥」路径必须显式传 `-PsignDebugWithRelease=false`。

**模拟器（x86_64）联调**必须换多 ABI 的 AAR，否则 `libgojni.so` 只有 `arm64-v8a`、
`System.loadLibrary` 失败：`flutter build apk --debug -PtunnelAar=libs/tunnel-debug.aar`。
正式 arm64 包用默认的 `libs/tunnel.aar`，测试 AAR 不入库。

改过 `android/**/*.kt` 后单独编译一次 Kotlin（`flutter analyze` 不覆盖 Kotlin）：
`cd android; .\gradlew.bat compileDebugKotlin --console=plain -q`，失败时去掉 `-q` 并 grep `^e:`。

## 3. 目录

```
lib/main.dart      唯一入口（ProviderScope + DitingApp）
lib/app/           主题（theme/）、引导（bootstrap）、文案（l10n）、根组件（app.dart）、首启须知
lib/router.dart    Routes 常量 + _branchOrder + createRouter()
lib/routes/        按域拆分的 GoRoute（dashboard/hub/logs/observability/config/system）
lib/shell/         壳层：六 tab 底栏          lib/state/  Riverpod 状态，按域拆文件
lib/data/prefs/    旧版 SharedPreferences 读写  lib/data/db/     旧版 SQLite 仓储
lib/data/vpn/      引擎配置组装与隧道通道       lib/data/native/ 平台通道封装
lib/data/server/   服务器模式配置与通道         lib/data/mock_*  仍走演示数据的数据源（§8）
lib/pages/         页面，按域分目录             lib/widgets/     跨页面共享件（PageBody 等）
lib/ui/            移植的设计系统（GPL 头保留，勿改风格）
tool/              一次性拆分脚本，不参与构建
test/              契约、模式、日志聚合、路由可达、布局与组件冒烟
```

## 4. 不可违背的约定

1. **每个代码文件 ≤ 550 行**（`AGENTS.md`），超了拆 `library` + `part`。三种已用技法与各自
   的陷阱：库级拆 part；单类拆 part 必须把成员提到库级私有常量（Dart 不允许类跨 part）；
   State 类抽同库 `extension`，但**类内 `static` 成员必须先提到库级私有**，否则报
   `unqualified_reference_to_static_member_of_extended_type`。
2. **`AppScopes` 装在 `MaterialApp.builder` 里**（`child` 即 `Navigator`，scopes 在它之上）。
   挂到 `home:` 会让浮层路由读不到 `MeasureScope` / `ViewScope` 而 assert。
   `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 的装法**必须同步**，否则单组件
   测试与整机测试给出不同结论；`test/scope_placement_test.dart` 用正例+反例钉这条。
3. **主题必须走 `AppThemeCache`，组装顺序不可变**：`seededColorScheme` → `.toPureBlack` →
   （深色时）`ElevatedColorScheme` → `.withAppShapes` → `.withAppSurfaces` →
   `.withAppTypography`。`ThemeData` 每次重建都不相等、`ThemeCrossFade` 靠它淡出；顺序错了
   纯黑会被后面的 surface 重算回带色偏的深色。细节见 `lib/app/theme/manager.dart` 注释。
4. **底栏下标 ≠ branch 下标**。`_branchOrder` 是固定的 branch 顺序，底栏只是它的可配置子集
   视图（2–4 项），`AppShell` 负责映射；重排 branch 会打乱所有 `goBranch`。`branchIndexOf`
   必须按**最长前缀**匹配：首页路径是 `/`，对任何绝对路径都 `startsWith` 为真，用
   `indexWhere(startsWith)` 取第一个命中会恒返回 0。
5. **`locale: zh_CN` 必须配 `GlobalMaterialLocalizations`**（来自 `material_ui`，无需额外加
   `flutter_localizations`）。`DefaultMaterialLocalizations` 只有 en_US，`AppBar` 会直接抛
   `No MaterialLocalizations found`。
6. **枚举上屏必须取 `.label`**。裸插值渲染出的是源码标识符，analyze 与路由冒烟都拦不住。
   `test/enum_display_test.dart` 会扫描它挑中的那批枚举（手写清单，不是自动发现）——
   新增枚举要自己确认 `.label`，别指望这个测试自动覆盖。
7. **`lib/ui/models.dart` 的 `copyWith` 用 `_keep` 哨兵复刻 freezed 语义**：省略参数 = 保留旧
   值，显式传 `null` = 置空。`scaffold_a.dart` 里退出搜索态的 `copyWith(query: null)` 依赖
   后者，不要改成 `??`。
8. **新增页面只改三处**：`XxxPaths` 常量、`xxxRoutes()` 里一条 `GoRoute`、
   `test/route_catalog_test.dart` 的表项。漏改测试表不会报错，只留覆盖洞；路由器挂了
   `errorBuilder: UnknownRoutePage`，漏注册才会变成硬失败。
9. **挂 `DitingApp` 的测试必须在 `main()` 顶部调 `installGlobalTestHooks()`**，并把
   `appTestOverrides()` 塞进 `ProviderScope`：前者关掉仪表盘永动动画（否则 `pumpAndSettle`
   永远超时），后者跳过首启须知（否则遮罩吃掉点击，症状是一堆与功能无关的「点不到」）。
   两者都在 `test/support/test_hooks.dart`。
10. **`LiquidGlassScope` 默认关闭**（`LiquidGlassMode.none`）。玻璃层与着色器已完整移植，
    开启不需要恢复代码。

## 5. 旧版 1.4.3 数据兼容契约

本项目存在的前提。**容器名、键名、默认值、落盘值都必须与 1.4.3 逐字一致**：写错一个字母，
设置照样存、界面照样显示，只有升级/降级后才丢设置——渲染测试抓不到。

### 5.1 容器

`legacy_prefs_store.dart` 的白名单（11 个）与 Kotlin 侧 `LegacyPrefsBridge.kt` 的
`CONTAINERS` 是同一份约束，越界写入直接 `invalid_container`；两侧必须同步增删，否则新容器
在 Dart 侧可写、在原生侧被拒（或反之）。清单：`dns_vpn_prefs`、`diting_express_prefs`、
`diting_dns_mode_prefs`、`express_vpn_prefs`、`diting_settings`、`permission_disclosures`、
`mode_permission_preferences`、`notification_settings_prefs`、`diting_crash_state`、
`network_tools_settings`、`recognition_members`。

写错容器界面上看不出区别，但读方在别处：

| 用途 | 容器 |
|---|---|
| 全局 UI 键、外观、三份应用名单、规则总控、引导解析、出站代理、数据集感知的 DNS/缓存/服务商键（普通模式） | `dns_vpn_prefs` |
| 同一批 DNS 键（极速模式） | `diting_express_prefs` |
| 服务器模式键 / 工作模式选择 / 网络工具参数 | `diting_dns_mode_prefs` / `diting_settings` / `network_tools_settings` |
| 通知栏四键（`persistent`、`speed`、`custom_running_text`、`custom_stopped_text`） | **`notification_settings_prefs`** |
| 极速运行标志 `express_vpn_running` | `express_vpn_prefs` |

极速模式的实现方式是**只替换 DNS 容器**（`LegacySettings.forExpress()`），UI 键仍留在全局
容器；三份应用名单属全局键，**不进极速容器**。

### 5.2 数据库

| 文件 | 版本 | 内容 |
|---|---|---|
| `diting_database` | 3 | 普通模式主库：`dns_log`、`dns_cache`、`dns_race_log`、`bootstrap_log`、`app_traffic_daily`、`http_request_log`、规则表、订阅表 |
| `diting_express` | 2 | 极速模式独立库；**没有** `app_traffic_daily` 与 `http_request_log` |
| `diting_dns_rules` | 3 | 服务器模式规则库，与 VPN 模式互不可见、永不迁移数据 |

打开方式即契约：`databaseExists` 为假返回 `null`（全新安装），**不传 `version`**（带上会改写
Room 的 `user_version`、触发迁移），打开后设 `PRAGMA foreign_keys = ON`。
`diting_dns_rules` 只在 Dart 侧出现，Kotlin 无该库名。普通与服务器共用 `diting_database`，
极速用 `diting_express`；两张日志/流量表只存在于主库，相关页面固定读主库。

### 5.3 三条硬约定

1. **写入后必须 `bump()` 对应 revision**。`SharedPreferences` 不可观察，不 bump 其他页面就
   读到旧值。设置域经 `WidgetRef.writeSettings()` 一处完成「读 + 写 + bump」，日志、订阅、
   应用清单、CA、出站代理各有自己的 revision provider。唯一例外是 CA 页故意不 bump 自身
   （会自激循环）。
2. **数值夹取写在 setter 里**，不要只靠控件——自定义输入与配置导入不经过控件。已实现的
   夹取：TTL 秒 30–86400、透明度 0.1–1.0、本地端口 1024–65535、动态拦截 2–100 / 10–300 /
   60–3600、日志保留 1–30；下发引擎前还会二次夹取，防直写绕过。
3. **四份应用集合在保存时互斥清洗**：`blocked_app_packages`（禁止联网）、
   `excluded_app_packages`（排除应用）、`http_inspection_app_packages`（HTTPS 检查）、
   `app_allowlist_rules_json`（应用独立规则）——一处勾选要从另外三处移除。实现必须**显式
   传入归属方并跳过它**，不能写成「先写 A 再从 A 读回来做差集」：那样读回的就是刚写进去的
   那一份，差集恒为空，用户保存等于清空自己的选择，而且不抛异常、SnackBar 照样显示「已保存」。

`versionCode` 只增不减（`major*10000+minor*100+patch`，1.4.3 是 10403），否则覆盖安装会被判
降级。

旧版有**三条一次性迁移标记**，其中只有一条在本仓实现：`default_whitelist_seeded_version`
（`versionCode*1000+2` 门控预设白名单种子，`legacy_settings.dart` + `rule_bootstrap.dart`）；
`local_listen_port_migrated`（5353/5354 → 1053）与 `log_queries_default_off`（日志默认翻转）
**由旧版 Kotlin 的 `DnsModePreferences` 完成，本仓不执行，也不要补做**——一次性语义不可重放，
重放会把用户当前设置当成「未迁移」再改一遍。

## 6. 原生通道

十个 `MethodChannel`，Kotlin 侧统一在 `MainActivity` 注册，方法名两侧必须逐字一致。

| 通道 | 主要方法 | 用途 |
|---|---|---|
| `legacy_prefs` | `readAll` / `put` / `remove` / `versionCode` | 旧版 SharedPreferences（受容器白名单约束） |
| `vpn` | `prepare` / `start` / `stop` / `status` / `trafficRates` | 普通模式全隧道 |
| `express_vpn` | 同上（`trafficRates` 明确回 `unsupported`） | 极速模式窄路由 |
| `dns_server` | `start` / `stop` / `status` / `clearCache` | 服务器模式（`startStandalone`） |
| `apps` | `listInstalled` / `resolveUids` / `isSelf` | 已安装应用清单 |
| `https_inspection` | `inspectCa` / `exportCa` / `openCaInstallSettings` | MITM 根证书 |
| `outbound_proxy` | `read` / `write` / `reset` / `setStatus` | 出站代理（凭据走 AndroidKeyStore） |
| `diagnostics` | `ping` / `traceRoute` / `lookupDns` / `networkInfo` | 网络工具 |
| `dns_latency` | `probe` | 服务商查询耗时测速 |
| `platform` | `applyRecentsPrivacy` / `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations` / `crashLogCount` / `clearCrashLogs` / `exportText` | 后台隐藏、电池优化、崩溃日志、导出 |

（通道名前缀均为 `com.haoze.diting/`。）两条易漂移点：`platform` 与 `dns_server` 的通道常量在
`lib/data/` 与 `lib/pages/server/server_platform_probe.dart` 各写了一份；`clearCache` 没有
bridge 封装，只在探针里裸调。反向通道只有 `onPrepareResult` 一个方法名，但 `vpn` 与
`express_vpn` 两个通道各自会发一次，Dart 侧 `vpn_bridge` 两处都要接。

`trafficRates` 是**独立方法**而不是塞进 `status`：仪表盘每秒轮询一次速率，而 `status` 还要序列化
引擎的计数器 JSON，共用一个调用会让 1 Hz 的读秒变成每秒一次重活。两个模式对它的回答刻意不同：
普通模式回 `TrafficRateMonitor.snapshot()`（常驻通知里那个 ↑/↓ 读数同源），极速模式回
`unsupported = true`——它的窄路由从不注册 `EngineDataPlane.attachTraffic`。**不要**给极速模式
补一个 `0 B/s`：那是「空闲」，与「没有这个数据源」是两件事。

**降级契约：宁缺勿假。** 通道不存在时页面必须说明并禁用，不得用假数字顶替——测速显示
「当前设备不支持测速」并禁用按钮，电池优化显示「当前设备不可用」，应用清单 / 证书 / 诊断
各有对应的「通道不可用」文案；所有通道在非 Android 宿主与测试里必须落到内存桩，而不是崩在
缺插件上。三个原生服务的 `activeEngine` 都是私有 companion：给诊断开口子时只加只读访问器，
**不要提供 setter**，也不要合并停机时刻意置空它的那几处——合并会让 `status()` 在停止后继续
返回上一条隧道的计数。

## 7. 统计口径（这些是约定，不是缺陷）

### 7.1 日志统计口径

**口径定义在 `DnsLogRepository.dailyStats()`**（`dns_log` 的**当日**聚合，`timestamp >= 今日
零点`，不是引擎会话计数——引擎计数重启隧道即归零）：

| 指标 | 口径 |
|---|---|
| 今日查询 | 当日行数，含 `BLOCKED` / `ERROR` |
| 缓存命中 | `cached = 1`，只在 PASSED/REWRITTEN 桶内统计 |
| 已拦截 | `result = 'BLOCKED'` |
| 平均延迟 | 当日 `elapsed=NNms` 的均值；无样本显示 `—`，不显示 `0ms` |

命中率分母取 `passed + error`，对齐 Go `dns_cache.go` 的
`hitRatio = totalHits/(totalHits+totalMisses)`；被规则拦截的行从不查缓存，不进分母。
`test/dns_log_stats_test.dart` 在**仓储层**钉这套口径（四桶互斥、分母、跨零点、空样本），
`test/real_data_wiring_test.dart` 在**聚合层**钉「两表相加 / 跨零点 / 两个裁剪模式」。

**首页与 `/logs` 顶部那几格数字读的就是这套口径**：`logDashboardProvider`
（`state/log_dashboard_overview_providers.dart`）一次扫描 `dns_log` + `http_request_log`
两张表，形状照旧版 `buildDashboardState()`。三个模式的裁剪也照旧版：

- `all`：两表全量相加；
- `blocked_and_errors`：DNS 侧 `passed` / `cached` 归零，HTTPS 只保留非通过行
  （`it.copy(passed = 0, cached = 0)` + `filter { normalizeHttpOutcome != "passed" }`）；
- `off`：不读两张日志表的当日统计，只留缓存 / 竞速 / Bootstrap 三项。

命中率在 `blocked_and_errors` 下跟着归零——否则会出现「通过 0、命中率 40%」的自相矛盾。

服务器模式概览里的统计是引擎**会话计数**，与「今日」不是一回事，**界面上应标明「当前会话」**
（目前几个标签是「总查询量 / 缓存命中 / …」，并未标窗口）。

> ⚠️ 这里曾经有一个 `dnsLogDailyStatsProvider`（只算 `dns_log` 一张表），已随本轮接线删除。
> 它没有消费方，但「口径相同、少一张表」的入口留在那里，下一个人接线时几乎必然选错——
> 概览只认 `logDashboardProvider`。

### 7.2 已知差异——勿「修」

1. **stale 命中**：stale-while-revalidate 命中在日志里是 `cached=1`，引擎却计入 `staleHits`
   而非 `totalHits`，所以 DB 口径命中率天然略高于引擎 `hitRatio`。
2. **竞速排行**：只统计 `success = 1` 且 `winnerProviderId` 非空的行，失败数来自整表汇总
   （失败行 winner 为 NULL，按服务商分组会把失败摊到某个服务商头上）。单服务商模式也写
   记录，排行不区分模式。
3. **缓存表**：Go 的 DNS 缓存是纯内存分片 LRU，没有枚举接口；`dns_cache` 表是 1.4.3 留下的
   快照，升级后为空**属正常**，空状态文案不得暗示「启动后会写入缓存表」。
4. **`dns_log.result` 是字符串四值**（PASSED/REWRITTEN/BLOCKED/ERROR，不是枚举）。现有两处
   `switch` 都已显式处理 `ERROR`；新增的 `switch` 也必须显式列出，**不要用 `_` 兜底**——把
   `ERROR` 落进 `_` 会把上游失败渲染成「放行」，语义正好相反。

引擎回调是**逐项开关**（`setBatchLogCallback` / `setRaceLogCallback` / `setTrafficCallback` /
`setHttpLogCallback` / `setUIDResolver` / `setAppUidResolver` 各自独立），漏注册一项的后果是
对应的表恒空、`dns_log.packageName` 为 NULL。判「某表没数据」先 grep 该表的生产者回调是否
被注册。

## 8. 已知边界

### 8.1 仍走演示数据

连接列表、资源更新、功能中心卡片清单（文案常量）、配置资源三表（图标集 / User-Agent /
按需连接）、系统域的免责条款与更新日志、表单族与编辑器 / 扫码 / IP 质量、WebDAV 与配置传输、
Agent 设置页。

其中一部分页面已有如实的「演示」标注（扫码、编辑器、应用更新、表单演示页、配置传输与
WebDAV、Agent 设置页等），另一部分**没有**（见 §8.2）。补标注可以，**换成看起来像真的
假数据不行**；也不要把这些页面写成已完成。

流量、请求、DNS 日志、订阅、出站代理、CA/HTTPS、网络工具、应用清单、数据清理已接真实数据源。

**本轮新增接线**（此前是写死的演示值）：

| 位置 | 现在读什么 |
|---|---|
| 首页 / `/logs` 概览块与四格 | `dns_log` + `http_request_log` 当日聚合（`logDashboardProvider`） |
| 流量监控卡的「今日代理流量」 | `app_traffic_daily` 当日行（与 `/traffic` 同一份） |
| 流量监控卡与 `/traffic` 的「实时速率」 | 原生 `TrafficRateMonitor.snapshot()`（`vpn` 通道 `trafficRates`） |
| 服务状态卡四行 | 端口（`local_listen_port`）、当前服务商（目录）、`dns_cache` 条数、已测速个数；耗时来自 `dns_latency` 通道真测 |
| 内核状态点 | `powerProvider` / `serverStatusProvider` 的真实状态机 |
| 规则控制页的「N 个」与自动更新摘要 | `subscription` 表、`mirror_template` 表、数据集 prefs 的 `subscription_auto_update_*` |
| 自动更新设置页 | 同上（写入数据集 prefs + `subscription_group.autoUpdateEnabled` 列） |
| 镜像站模板页 | `mirror_template` 表（增删改全落库） |
| `/hub/data-cleanup` 全部十六个动作 | 真实删除：日志/流量/缓存三表、权重 JSON、规则与订阅事务、四份应用名单、出站代理、CA、下载与背景缓存、引导标记（`DataCleanupService`） |

### 8.1.1 数据清理是「真删」，不是弹提示

`/hub/data-cleanup` 上一轮十六个动作**全部**只弹一句「已删除 X」然后什么都不做——这是本仓
最坏的一种占位：文案描述的是后果，用户据此以为数据没了，磁盘上一个字节都没动。现在每个动作
都落到真实存储（`lib/data/cleanup/`）：

| 存储 | 动作 | 落点 |
|---|---|---|
| sqflite | 请求日志 / 流量 / 缓存 | 四张日志表 + `app_traffic_daily` + `dns_cache`，逐表容错（极速库没有 `http_request_log`） |
| sqflite 事务 | 域名 / 地址规则、订阅 | 规则表 + `*_source` 表 + `deleteOrphans` + `resetAfterRuleCleanup` |
| prefs | 权重、应用名单、壁纸、引导 | 三个数据集容器各删一份；`mode_permission_preferences` 的 `recommendation_dismissed_*` 也要清 |
| 原生通道 | 崩溃 / 下载缓存 / 背景缓存 / 代理 / 证书 | `platform` 的 `clearCrashLogs`、`clearUpdateCache`、`clearCustomBackgroundCache`；`outbound_proxy.reset`；`inspectCa(regenerate)` |

三条照抄旧版、**不能省**的语义：

1. **删域名规则后必须重播预设白名单**。旧版「删 + `DefaultWhitelistSeeder.seed(forceReset)`」；
   只删不播会让保活域名从放行变成拦截，而界面已经说了「已删除」。
2. **订阅行要 `resetAfterRuleCleanup()`**。`ruleCount` / `lastUpdated` / ETag 仍指向已被删掉的
   规则时，下次自动更新会拿旧 ETag 请求、被判「未修改」而永不重新导入（旧版 A-066）。
3. **「清理全部本地数据」按序跑完整清单**。中途失败就停会留下「日志清了、规则还在」的半清理
   态，而应用已经退出。引导重置与全面清理两个动作会主动退出应用：它们清掉了首启协议标记，
   留在前台会出现「应用还在跑、但下次启动要重新同意协议」的分裂状态。

条数为 0 时提示「没有可清理的数据」，**不说「已删除」**——静默的假成功是最坏的结果。
`test/data_cleanup_test.dart` 直接对着内存数据库断言删除结果（14 条），因为这个缺陷在
Widget 测试里看不见（SnackBar 文案本来就是对的）。

### 8.2 旧版没有后端的界面

`/connections`、`/resources` 在 1.4.3 里没有对应后端（那一版只有请求日志，没有「活动连接」
概念，也没有 geo/icon 远程下载器）。两者按用户要求保留，入口收在 `/developer`。

「旧版没有」必须让用户看得见，但**机制目前是分裂的**：`DemoPageNotice`（文案
`演示页：不属于旧版 1.4.3 的界面`）只用在 `/editor`、`/scan`、`/ip-quality`；
`/connections` 与 `/resources` 的页脚是功能性说明，**没有**这个标注。给这两页补标注时不要删掉
原有页脚，也不要把标注去掉——「保留」和「看起来像旧版就有」是互斥的。

同理，`/proxies`、`/profiles/*`、11 个内核配置页等 FlClash 语义的域已删除，因为 1.4.3 是 DNS
应用，没有 Clash 内核、代理组或配置档案。要复活只能当**新功能重新设计**，不要从 git 历史里
捞半成品页面。保留项（旧版无界面但用户要求保留）统一收在 `/developer` 或内联在 `/theme`；
设置列表必须严格等于旧版的五组六行，因此**唯一自造的入口是设置页顶栏的扳手图标**，
`test/retained_pages_reachable_test.dart` 防止它们被当孤儿删掉。

### 8.3 能力缺口（不是 bug）

- **订阅**：更新是真实 HTTP 下载，但订阅正文**尚未写入规则表**（解析链未移植），所以
  `ruleCount` 是词法行数而非生效规则数，卡片与页脚必须如实标注——改成「规则已更新」是谎报。
- **应用独立规则**：应用清单与放行域名已通，DNS 专属黑白名单与「默认拦截全部外联」仍是只读
  说明位（`block_rule.app_scope` 有列，仓储无按应用读写接口）。
- **`http_request_log` 常为 0 行**：只在 MITM 真正拦到流量时才产生，需要用户先装并信任 CA。
  `blockSubscriptionId` 写 NULL（旧版用 Kotlin 规则缓存反查，本移植没有那套缓存）——填错比
  留空更坏。
- **服务器模式没有设备归因**：LAN 客户端无法按应用归属，per-app 规则对它们不生效。不要臆造
  已有能力。
- **极速模式是能力子集**：只做窄路由 DNS 加速，不含应用管控与 HTTPS 检查；不消费
  rewrite/GoUrl/cosmetic，也不执行动态拦截升级（存而不生效）。
- **流量「本次会话」档不存在**：引擎会话计数是全局累计、不按应用拆分，所以按应用的排行只提供
  有落库来源的时间窗口。**「实时速率」不是这一类**：它有原生来源（`TrafficRateMonitor`），
  只是不按应用拆分、也不跨会话保留；极速模式确实没有（窄路由不挂流量回调），页面要说明。
- **未迁移的旧版能力**：独立 VPN monitor 前台服务、QS Tile、开机自启、悬浮日志窗、崩溃收集、
  应用内更新安装、运行时本地化词典。
- **已知未验证**：`getConnectionOwnerUid` 的实参方向是按 Go 侧 `resolveFlowUID` 的实参顺序推导
  的（Go 把 `id.appIP` 传第一位），模拟器上产出正确包名，arm64 真机未复核。

## 9. 提交约定

中文 Conventional Commits，一个阶段一个提交；提交前 `flutter analyze` 零问题，测试范围按改动
的实际风险决定（高风险改动跑 `flutter test` 全绿），文件行数不超过 600 行。
`dart format` / `flutter analyze` / 不带路径的 `git commit` 都是全局操作，只对自己作用域的路径
跑；提交一律带明确文件列表——同一工作区里多个 agent 共享 `.git/index`。

## 附录：命名陷阱与遗留引用

上游包名与直觉相反，沿用是为了与规格对得上：`normal` 指「全隧道 Go 模式」而非普通 DNS；
`AppWorkMode.DNS` / `DnsMode*` / `RuleDataset.DNS_MODE` 指**服务器模式**；`express` 指
DNS-only 窄路由；`GOLD` 色板的落盘值仍是 `indigo`，不可改。

### 待修：指向已删除文档的引用

本文件吸收了原 `NOTICE.md`、`android/SIGNING.md` 与 `docs/` 下全部文档。下列位置仍是旧引用，
**内容已在本文件对应小节，但字面路径已失效**——改代码/脚本时请顺手改指本文件：

| 位置 | 现状 | 应指向 |
|---|---|---|
| `lib/pages/system/disclaimer_page.dart`（`/about` 的「免责声明」入口）与其数据源 `lib/data/mock_system.dart` 的「四、第三方组件」条 | **用户可见文案**写着「许可条款见仓库 NOTICE.md」 | §1 |
| `lib/ui/analysis_options.yaml` 首行注释 | 注释指向 `NOTICE.md` | §1 |
| `lib/data/prefs/legacy_settings.dart` 文件头 | 注释指向 `docs/refactor/01-foundation-and-startup-2.md` §3.1 | §5 |
| `lib/state/work_mode_providers.dart` | 注释指向 `docs/refactor/14-migration-strategy.md` §5 | 本节 |
| `lib/app/theme/colors.dart` | 注释指向 `docs/refactor/03-navigation-and-main-ui.md` §5.2（九选一与 `GOLD`→`indigo`） | §1 的移植说明 + 本节命名陷阱 |
| `lib/pages/mode/mode_select_page.dart` | 注释指向 `docs/refactor/03-navigation-and-main-ui.md` §4.7 的 feature 步 | 该页与 `mode_onboarding_page.dart` 各有一套文案，**互不替代**，改文案时两处都要看 |
| `build_apk.bat` 头注释 | 注释指向 `android/SIGNING.md` | §2 |

第一行优先级最高：那是用户能读到的条款文本，它承诺的「第三方组件许可条款」现在只存在于本
文件 §1，而不是一个独立的 NOTICE 文件。首启的「使用须知与免责声明」弹窗
（`lib/app/initial_agreement.dart`）是另一份文案，不含该引用。
