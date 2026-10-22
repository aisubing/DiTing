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

连接列表、资源更新、功能中心卡片清单（文案常量）、系统域的免责条款与更新日志、
表单族与编辑器 / 扫码。

其中一部分页面已有如实的「演示」标注（扫码、编辑器、表单演示页等），
另一部分**没有**（见 §8.2）。补标注可以，**换成看起来像真的假数据不行**；也不要把这些
页面写成已完成。

流量、请求、DNS 日志、订阅、出站代理、CA/HTTPS、网络工具、应用清单、数据清理、
备份与迁移（含 WebDAV 云同步）、应用更新、配置资源三表（图标集 / User-Agent /
按需连接）、IP 质量检测、AI 分析（Agent）已接真实数据源。

**本轮新增接线**（此前是写死的演示值）：

| 位置 | 现在读什么 |
|---|---|
| 首页 / `/logs` 概览块与四格 | `dns_log` + `http_request_log` 当日聚合（`logDashboardProvider`） |
| 流量监控卡的「今日代理流量」 | `app_traffic_daily` 当日行（与 `/traffic` 同一份） |
| 流量监控卡与 `/traffic` 的「实时速率」 | 原生 `TrafficRateMonitor.snapshot()`（`vpn` 通道 `trafficRates`） |
| 服务状态卡四行 | 端口（`local_listen_port`）、当前服务商（目录）、`dns_cache` 条数、已测速个数；耗时来自 `dns_latency` 通道真测 |
| 内核状态点 | `powerProvider` / `serverStatusProvider` 的真实状态机 |
| 规则控制页的「N 个」与自动更新摘要 | `subscription` 表、`mirror_template` 表、数据集 prefs 的 `subscription_auto_update_*` |
| 自动更新设置页 | 同上（写入数据集 prefs + `subscription_group.autoUpdateEnabled` 列），并显示按 `lastAttemptAt` 推出的下次更新时刻与上次执行结果 |
| 自动更新的**执行** | 启动/回前台时前台补跑（`AutoUpdateRunner`，见 §8.1.12）；不是只存设置 |
| 镜像站模板页 | `mirror_template` 表（增删改全落库） |
| `/hub/data-cleanup` 全部十六个动作 | 真实删除：日志/流量/缓存三表、权重 JSON、规则与订阅事务、四份应用名单、出站代理、CA、下载与背景缓存、引导标记（`DataCleanupService`） |
| `/hub/config-transfer` 四格统计 | 服务商数（prefs）、订阅数（`subscription` 表）、自定义规则数（规则表 `user` 来源）、名单应用数（四份名单并集） |
| AI 分析（Agent）全流程 | 厂商配置落盘 + 真实 HTTP 调用厂商接口（见 §8.1.9） |
| 应用独立规则的黑/白名单与全阻断 | 规则库 `appScope`（见 §8.3；不再有「尚未接通」占位） |
| 订阅更新 | 真实下载 + 真实解析 + 真实入库（见 §8.3；`ruleCount` 是入库条数） |
| `/logs/race` 竞速统计的策略概览与智能选择首选 | `dns_race_log` 的 `strategy` / `fallbackUsed` / `selectedProviderId` 三列聚合（见 §8.1.11） |
| 服务器模式自定义上游的增删改 | `diting_dns_mode_prefs` 的 `custom_upstreams` / `selected_upstream_id`（见 §8.1.13） |

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

### 8.1.2 日志保留期真的会删数据

同一个毛病的第二种形态：`log_retention_days` 会落盘、日志模式页写着「超过所选时间的 DNS
请求日志会自动删除」，但**没有任何代码读回这个键**。设置在磁盘上，效果不存在。

现在移植了 1.4.3 的 `LogMaintenance`（`android/.../log/LogRetention.kt`），由两个隧道服务在
启动时各自调度：

| 项 | 值 | 说明 |
|---|---|---|
| 首次延迟 | 30 s | 清扫与隧道握手争磁盘；启动瞬间清理没有收益 |
| 周期 | 1 h | 旧版 `MAINTENANCE_INTERVAL_MS` |
| 日志窗口 | `log_retention_days`（数据集容器，1–30，默认 7） | 四张日志表按 `timestamp <` |
| 流量窗口 | `traffic_stats_retention_days`（全局容器，1–90，默认 30） | `app_traffic_daily` 按 **`date` 字符串**比较 |

三个易错点：

1. **两个窗口必须分开**。用日志窗口去清流量表会把 30 天历史截成 7 天，旧版对此有专门注释。
2. **`app_traffic_daily.date` 是 `yyyy-MM-dd` 字符串**，拿毫秒时间戳跟它比会把整张表删光。
3. **极速模式只清四张日志表里的三张**：`ExpressRulesDatabase` 没有 `http_request_log` 与
   `app_traffic_daily`，所以 `includeHttpAndTraffic = false`。

调度器随隧道结束一起 `stop()`；漏掉会在服务停止后继续删用户正在看的表，线程也会比服务活得久。
实测：普通模式隧道启动 30 秒后 logcat 出 `pruned 2 rows older than 7 d`，`dns_log` 里 20 天前的
行消失、当天的行保留，`app_traffic_daily` 里 `2026-01-01` 的行被清而今天的保留。

### 8.1.3 崩溃日志现在可导出

「导出崩溃日志」此前只弹一句「导出内容需原生侧提供文件读取」——按钮可点、提示像成功、
**文件不存在**。现在 `platform` 通道新增 `readCrashLogs`：原生侧合并两份崩溃目录
（`crash/` 与 1.4.3 的 `crash_logs/`，按时间倒序，带文件名索引），Dart 侧再经 `exportText`
落到外部私有目录，成功后提示真实路径。

### 8.1.4 备份与迁移真的读写文件

`/hub/config-transfer` 上一轮的两端都是假的：

- **导出**只弹「已导出 DITING-config.json」，磁盘上没有任何文件。用户会以为备份在，
  换机时才发现没有——这是最不能接受的失败方式（承诺已兑现，事实没有）。
- **导入**不论选什么文件都弹同一份写死的「新增 9 项，跳过 3 项」+ 五行项目名。
  那是纯装饰：文件没被读过，配置没被写过。
- 页顶四格 `6 / 5 / 23 / 8` 是常量，与备份内容毫无关系。

现在（`lib/data/backup/`）：

| 环节 | 实现 |
|---|---|
| 导出 | `BackupExporter` 按 15 个分组序列化 → 系统「保存文件」选择器（`ACTION_CREATE_DOCUMENT`）写入用户选定的位置 |
| 导入 | 系统「打开文件」选择器 → `BackupImporter` 校验 → 逐组合并 → 明细对话框 |
| 统计 | `backupStatsProvider` 读 prefs / `subscription` / 规则表 / 四份名单 |

文件格式固定 `{format:"diting-backup", version:1, exportedAt, selection, data}`。
`format` 与 `version` **必须**校验：解析器的输入是用户从文件管理器随手挑来的文件，
不校验就会把任意 JSON（甚至别的应用的备份）当配置写进库。

三条合并语义（照抄 1.4.3 `ConfigImporter` 的分档）：

1. **规则只导 `user` 来源**。预设由应用自带、订阅由订阅链接重建，一起导出会让恢复时
   产生重复行。
2. **订阅导入后 `ruleCount`/`lastUpdated`/ETag 归零**。备份存的是地址而非内容；沿用旧的
   `ruleCount` 会让界面显示一个本机不存在的规则数，带着旧 ETag 还会被判「未修改」而永不下载。
3. **出站代理不含账号密码**（AndroidKeyStore 加密，导出成明文等于泄露），
   `credentialsExcluded: true` 明确写进文件；HTTPS 抓包开关也**不**从备份打开
   （是否可用取决于本机 CA，拿别人的开关打开会让每个 HTTPS 请求失败）。

`test/backup_transfer_test.dart`（20 条）对着内存库断言真实写入与合并，因为这个缺陷在
Widget 测试里看不见（旧对话框的文案本来就是"对"的）。

实测（emulator-5554）：导出 → `/sdcard/Download/DITING-backup-20261022-010939.json` 3034 字节，
内容含 `"credentialsExcluded": true` 与种子订阅；删掉库里的规则后导入同一文件 → 对话框报
「新增 19 项，跳过 5 项」，`block_rule` 里 `ads.seed.test` 恢复。

### 8.1.5 WebDAV 云同步真的传文件

`/hub/config-transfer/webdav` 上一轮的「测试连接」是 `await Future.delayed(1.2s)` +
「服务器地址里有没有 `fail` 字样」——**服务器不存在也会显示「连接成功」**，用户据此
以为云备份可用。1.4.3 里没有任何 WebDAV 代码（这是本仓新加的能力），所以没有可照抄的
实现，按 RFC 4918 里真正用到的那一小部分自己写（`lib/data/backup/dav_client.dart`）：

| 动作 | 请求 |
|---|---|
| 测试连接 | `PROPFIND`（Depth: 0）；404 则 `MKCOL` 建目录 |
| 上传备份 | `PUT <path>/diting-config.json`，内容来自 §8.1.4 同一份生成器 |
| 下载恢复 | `GET` 同一路径，交给同一个 `BackupImporter` 合并 |

- 只用标准库（四个动词 + 一条 XML），不引 WebDAV 包：那会带进它自己的 XML 解析器和依赖树。
- 密码只存在内存与单次请求头里，**不落盘**——与备份文件「不含凭据」的承诺一致。
- 远端路径自动补齐前导/尾部斜杠：少一个斜杠会让 PROPFIND 打到上一级目录。
- 状态码翻成可操作的话：401「用户名或密码不正确」、403「没有读写权限」、
  507「存储空间不足」；连接失败带上原因，不再一律「连接失败」。

`test/dav_client_test.dart`（10 条）起一个真实的本地 `HttpServer`，逐条验证
PROPFIND/404→MKCOL/PUT/GET 与 401 分支。注意它必须 `HttpOverrides.global = null`：
`flutter_test` 默认装了一个假客户端，把所有请求直接答成 400。

实测（emulator-5554，本机 Python 最小 WebDAV 服务 + `adb reverse`）：
错误密码 → 「认证失败：用户名或密码不正确」（服务端日志 401）；
正确密码 → 服务端 `PROPFIND 404` → `MKCOL 201` → 界面「连接成功／目录不存在，已自动创建」；
上传 → 服务端 `PUT 200`，`davroot/diting/diting-config.json` 3032 字节；
删掉库里的规则后下载 → 服务端 `GET 200`，对话框报「恢复汇总：新增 19 项」，
`block_rule` 里 `ads.seed.test` 恢复。

### 8.1.6 检查更新真的查 GitHub

`UpdateNotifier.check()` 上一轮是 `await Future.delayed(900ms)` 然后直接置
`available`——**永远提示有更新，与服务器无关**。这会引导用户去下载一个不存在的包。
`download()` 同样是十步假进度条走到「下载完成」。

现在 `lib/data/update/app_update_checker.dart` 照抄 1.4.3 `AppUpdateManager`：

| 项 | 值 |
|---|---|
| 端点 | `api.github.com/repos/haoze-evoluling/DITING/releases/latest` |
| 请求头 | `Accept: application/vnd.github+json` + `User-Agent`（GitHub 对无 UA 请求返回 403） |
| 版本比较 | 去 `v` 前缀、取 `-` 前、按 `.` 拆整数逐段比（不是字符串比：`1.4.10 > 1.4.9`） |
| 资产挑选 | 优先 `.apk` 且名字含 `arm64-v8a`，其次任意 `.apk`；挑不到就报错 |
| 403/404/5xx | 翻成具体原因；403 且响应体含 `rate limit` 时明说「接口限流」 |

三个刻意的「不」：

1. **看不懂的 tag 不算更新**。`latest` / `1.4.x` 这类解析不出整数的版本一律 `false`——
   宁可「没有更新」，也不要把垃圾 tag 当成新版本提示下载。
2. **没有 APK 资产就报错**，不猜下载地址。
3. **下载仍未接入**：`download()` 如实提示「本机尚未接入安装包下载器，请用浏览器打开
   下载地址」，不再用假进度条冒充「下载完成」。1.4.3 自带 `DownloadManager` 下载器，
   这部分尚未移植，本文不把它写成已完成。

页脚那句「演示层不发起真实请求」同时删掉，改为真实行为说明；失败时页脚显示失败原因
（红色），不再显示一句与事实相反的提示。「更新日志」标题改成「历史版本更新日志」——
它是静态发布历史，真实的最新版本在上方卡片里。

`test/app_update_checker_test.dart`（20 条）起真实 `HttpServer` 覆盖全部解析分支与
HTTP 状态，含「字符串比较会判错」的 `1.4.10 vs 1.4.9` 用例。

实测（emulator-5554，三种结果都出现过）：
真实 GitHub → 「检查更新失败：GitHub 接口限流（未认证请求每小时 60 次），请稍后再试…」
（宿主机 IP 已限流，这恰好证明请求真的发出去了）；
本地假 release（`--dart-define=DITING_RELEASE_URL=...` + `adb reverse`，tag `v9.9.9`）→
「可更新到 9.9.9／发现新版本」，按钮变「重新检查 / 下载」；
同一端点改成 `v1.4.4` → 「已是最新／当前已是最新版本（1.4.4）」。

顺带修掉一个真 bug：`PlatformBridge.UPDATE_DIR` 原为 `"updates"`，而下载目录实际是
`"app-update"`——「清理下载与临时缓存」一直在删一个不存在的目录却照样报「已清理」。
1.4.3 犯过同一个错并用 `AppUpdateDirectories` 收敛常量，这里改为 `"app-update"`。

### 8.1.7 图标集 / UA / 按需连接会落盘

这三张表上一轮只活在内存里：加完图标集、切完按需连接，杀进程就全没了，而界面没有任何
「不保存」的提示——用户会以为设置生效了。1.4.3 没有这三张表（是本仓保留的能力），
所以自行设计存储（`lib/data/prefs/config_resource_store.dart`）：

| 项 | 做法 |
|---|---|
| 位置 | 新 prefs 容器 `diting_config_resources`，不与 1.4.3 的十一个容器共享兼容契约 |
| 形态 | 每组一条 JSON（三组各自落一个键）+ 两个标量 |
| 理由 | 三张表的操作**都是整表替换**：没有按行查询、没有跨表关联、条数在几十的量级。建三张 sqlite 表要多写三个 DAO、三份 schema 迁移和一轮异步装配，换来的能力这里一个都不用 |

损坏数据的处理是逐组的：一组 JSON 坏了只让那一组回落到初始值，另外两组照常读回；
一组里的单条记录坏了只丢那一条。**空数组是合法结果**——用户可能把 UA 删光了，
这时不该又冒出四条默认值。

落地时踩了两个「静默丢数据」的坑，都记在代码注释里：

1. 原生 `LegacyPrefsBridge.CONTAINERS` 是**白名单**，新容器不在里面写入会被拒
   （`invalid_container`）。界面照常反映「已保存」，磁盘上却没有文件。
2. Dart 侧 `legacyPrefContainers` 是**另一份**清单，决定冷启动时读哪些容器。
   只加原生那份，会出现「写入成功、文件在磁盘上、重启读不到」——界面显示默认值，
   看起来像「设置没保存」。

`test/config_resources_test.dart`（13 条）用一个 `MemoryLegacyPrefsStore` + 新建
`ProviderContainer` 模拟冷启动，断言写入、删除、选中态、损坏回落。它抓到一个真实的
顺序 bug：`updateUserAgent` / `removeUserAgent` 在 `state` 已经更新之后才判断「原来选中
的是不是这一条」，于是选中态永远同步不过去。

实测（emulator-5554，每次都 `am force-stop` 后重启）：
开按需连接 → `shared_prefs/diting_config_resources.xml` 出现
`on_demand_enabled=true` → 冷启动后开关仍为开、SSID 列表仍在；
删掉「地区旗帜」→ 文件里只剩两个集 → 冷启动后页首是 **2 图标集 / 20 图标总数**，
被删的那个没有复活。

### 8.1.8 IP 质量检测真的查出口地址

`/ip-quality` 上一轮是「进来就渲染 `mockIpQualityReport`」：`203.0.113.24` / `AS64500` /
「风险」/ 五行来源全部写死，`detect()` 只有 `await Future.delayed(1000ms)`。点「重新检测」
只有转圈在动，地址与结论从不变化——而这类页面最坏的地方在于**它看起来像检测结果**。

现在 `lib/data/tools/ip_quality_checker.dart`：先取出口 IP，再并发查三个公开情报源，
汇总出类型与级别。没有报告时页面按阶段说话（未检测 / 检测中 / 失败原因 + 重试），
不再摆一份写死的样例。

| 环节 | 端点 |
|---|---|
| 取出口 IP（回退链） | `api64.ipify.org` → `api.ip.sb/ip` → `ifconfig.me/ip` |
| 情报源 | `ip-api.com`（明文 HTTP，该服务 TLS 是付费功能）、`ipwho.is`、`ipinfo.io` |

三条来自实测的判断：

1. **探测端点必须是一条回退链**。`api.ipify.org` 在 emulator-5554 上 `curl` 返回 `000`
   （连接被重置），同服务的 `api64.ipify.org` 是 200。单端点实现会把「一个域名在你网络里
   不通」变成「IP 质量检测不可用」，而文案是「网络不可达」——用户会去查自己的网络。
2. **只接受像 IP 的响应**。门户劫持 / 运营商插播 / 限流页会回 200 + HTML，把整段 HTML
   当出口 IP 去查三个源，结果是一屏「失败」而没有一句能读懂的原因。
3. **一个源挂了不影响结论**。缺一家只是少一行；一个源都没通才报失败，不回落「优秀」。
   分类关键词表兜底成「商业」而不是「住宅」：把机房误标成住宅会让用户以为 IP 很干净。

`test/ip_quality_checker_test.dart`（12 条）起真实 `HttpServer`，逐条决定分支，含
「首个探测端点不通」「返回 HTML」「一个源 429」「全部源失败」「ipinfo 额度用尽」。
注意必须 `HttpOverrides.global = null`：`flutter_test` 默认把所有请求答成 400。

顺手修掉两个真机问题：卡片第二行 `Row` 用 `Spacer` + 无约束 `Text` 装机构名，真机上
印出 `RIGHT OVERFLOWED BY 51 PIXELS`（改成 `Expanded` + 省略，并给 ASN 一个宽度上限）；
来源行的 `Row` 改 `Wrap`，并把失败原因（`HTTP 500` / `private range`）显示出来——
只写「失败」用户无从判断是限流、地址错还是网络问题。

实测（emulator-5554，VM Service `ext.diting.go` 跳页）：真实网络下首屏拿到
`223.104.55.236` / AS9808 / 移动 / 优秀，三个源全命中（5571ms / 5753ms / 406ms）；
改回单端点时同一台机器上是「检测失败：无法获取当前出口 IP」。

### 8.2 旧版没有后端的界面

`/connections`、`/resources` 在 1.4.3 里没有对应后端（那一版只有请求日志，没有「活动连接」
概念，也没有 geo/icon 远程下载器）。两者按用户要求保留，入口收在 `/developer`。

「旧版没有」必须让用户看得见。`DemoPageNotice`（文案
`演示页：不属于旧版 1.4.3 的界面`）现在五处都在用：`/editor`、`/scan`、`/ip-quality`，
以及本轮补上的 `/connections` 与 `/resources`（加在列表末尾，原有功能性页脚保留不动）。
补标注时不要删掉原有页脚，也不要把标注去掉——「保留」和「看起来像旧版就有」是互斥的。

补这两个标注的理由不是整齐：连接页摆着「新加坡 01 · 流媒体 · GEOSITE,netflix」这种
逐行可读的路由链路，资源页摆着带体积与更新时间的文件清单，而引擎里**没有**连接枚举接口
（`tunnel` 通道只有 `tcpFlowCount`/`udpFlowCount` 两个计数），1.4.3 也**没有**任何 geo/icon
远程下载器。没有标注的话，这两页是最容易被当成「功能已就绪」的两屏。

同理，`/proxies`、`/profiles/*`、11 个内核配置页等 FlClash 语义的域已删除，因为 1.4.3 是 DNS
应用，没有 Clash 内核、代理组或配置档案。要复活只能当**新功能重新设计**，不要从 git 历史里
捞半成品页面。保留项（旧版无界面但用户要求保留）统一收在 `/developer` 或内联在 `/theme`；
设置列表必须严格等于旧版的五组六行，因此**唯一自造的入口是设置页顶栏的扳手图标**，
`test/retained_pages_reachable_test.dart` 防止它们被当孤儿删掉。

### 8.3 能力缺口（不是 bug）

- **订阅已全接通**：更新是真实 HTTP 下载 + 真实解析 + 真实入库，`ruleCount` 是**已入库
  规则条数**（不再有「词法行数」口径）。
  - 解析器 `lib/data/rules/`（`rule_parser` / `adblock_line_parser` / `hosts_parser` /
    `rule_domain_utils`）逐条移植 1.4.3 的 `AdGuardRuleParser` 一族：AdGuard/ABP 域名与
    `$` 修饰符、`$dnsrewrite=`、`$badfilter`（两趟扫描，与出现顺序无关）、hosts 一行多域名、
    dnsmasq `address=/` `server=/`、元素隐藏分隔符（`#$@#` 必须先于 `#$#` 识别）。
  - 入库器 `RuleImporter` 按 `sub_<id>` 来源写 `block_rule` / `allow_rule` / `rewrite_rule` /
    `go_url_rule` 及其 `*_source` 表；重复导入按 `(pattern, important, appScope,
    appInverted, dnsType, isRegex)` 查重复用既有行——**设备上的老库没有那组唯一索引**
    （`sqlite_master` 里只有 source 表的主键索引），只靠 `OnConflictStrategy.IGNORE`
    会让每次更新追加一整份副本。
  - 更新前先删该订阅的旧来源行再导新的：订阅内容是「当前全量」，增量追加会让上一版已
    移除的域名永远留着。删来源行而不是删规则行，用户手加或别的订阅引用的同一 pattern
    不受影响；无来源引用的孤儿规则行会被清掉。
  - 订阅总开关同时置 `*_source.enabled`：规则生效条件是「规则行启用 && 至少一个来源行
    启用」，只改 `subscription.enabled` 会让关掉的订阅继续拦截。
  - **元素隐藏（cosmetic）规则解析但不入库**：Go 引擎没有注入通道，写进表只会让条数虚高。
    `RuleImportSummary.notAppliedCount` 单独计数，UI 如实说明。
  - `go_url_rule` 没有 `appScope` 列（旧版实体也没有），带 `$app=` 的 URL 规则会被跳过而
    不是退化成全局 URL 拦截。
- **应用独立规则已全接通**（不再有只读说明位）：应用清单、网络层放行域名、DNS 专属黑/白名单、
  「默认拦截全部外联」都是真实读写 + 落库。
  - 网络层放行域名 → `app_allowlist_rules_json`，引擎侧 `Engine.setAppAllowlist`。
  - DNS 专属黑/白名单 → `block_rule` / `allow_rule` 的 `appScope` 列
    （`RuleRepository.loadForApp` / `addForApp`）。
  - 默认拦截全部外联 → 注入/删除 `pattern='*'` 且 `appScope=<pkg>` 的 `block_rule` 行
    （`setFullBlock`），等价旧版 `*$app=<pkg>`。
  - **关键语义**：`appScope` 非空的规则必须进快照的 `appRules[pkg].block/important`，
    不能进 `globalBlock`（否则单应用拦截被放大成全局拦截）。`buildRuleSnapshot` 已分流，
    `RulesNotifier` 也把这类规则过滤出全局规则页，避免同一行出现在两个页面。
  - 快照只在隧道启动时下发，所以页面提示「启动 DNS VPN 后生效」。
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

### 8.1.9 AI 分析真的调用厂商接口

`/hub/agent` 上一轮是纯壳子：厂商列表、模型下拉、温度滑杆都在，但「测试连接」「拉取模型」
只弹一句「已保存」，「开始分析」弹的是写死的示例结论——用户付了 token 钱、拿到的却是常量。

现在整条链路是真的（`lib/data/agent/` + `lib/state/agent_providers.dart`）：

| 环节 | 实现 |
|---|---|
| 端点解析 | 逐字移植旧版 `AgentApiClient.kt` 的 `resolveChatCompletionsEndpoint` / `resolveModelsEndpoint`（`/v1` 结尾、`#` 后缀、裸主机三种写法都要兼容） |
| 密钥存储 | 移植 `KeyObfuscator.kt`（三层 XOR + Base64），落盘的是密文；`agent_api_key` 等四个平铺键同步写入，旧版分析读到的就是界面这一份 |
| 测试连接 | 真发一次最小 chat 请求，回显模型名与 token 用量 |
| 拉取模型 | `GET /models`，兼容 `data` / `models` / `result` 三种返回形状 |
| 域名分析 / 流量分析 | 组 prompt → 真实调用 → 渲染模型返回的正文，附模型名与 token 用量 |
| 参数与提示词 | 温度与系统提示词落盘到 `agent_api_temperature` / `agent_api_system_prompt`，改完即对下一次分析生效 |

三条不做假的规矩：没配密钥时直接说「未配置密钥」，不发请求；全部情报源/样本为空时让模型
**明确不要编造**（送检摘要里如实写「无可用样本」）；厂商返回的错误按 401/403/404/429/5xx
翻译成可操作的中文，而不是把 HTTP 状态码甩给用户。

实测（模拟器 + 本地假 OpenAI 服务）：拉取模型返回两个 chip、测试连接回显 `130 tokens`、
域名分析把 `example-tracker.com` 原样送进 prompt 并拿回模型正文、流量分析的 prompt 里带着
`dns_log` 的真实域名行、冷启动后配置与密钥仍在、401 时对话框显示
「API Key 无效或已过期」。

### 8.1.10 弹窗输入框的控制器必须由弹窗自己持有

这一条是**真崩溃**，不是风格问题：把 `TextEditingController` 建在调用方、`await
showFloatingDialog(...)` 之后立刻 `dispose()`，`pop` 一调用弹窗的 future 就完成了，而退场
动画（404 ms）还没跑完、`TextField` 仍在树上挂着这个 controller。实测在模拟器上点「保存」
直接整屏红：

```
'package:flutter/src/widgets/framework.dart': Failed assertion: line 6281 pos 12:
'_dependents.isEmpty': is not true.
```

只在**输入框获得过焦点**（软键盘弹出过）时触发，所以纯点点点的回归测试会漏掉它。改法统一：
让弹窗成为一个 `StatefulWidget`，在它自己的 `dispose()` 里释放（与 `InputDialog` 同一套
生命周期）。已修的站点：系统提示词、应用放行域名、HTTPS 绕过域名、订阅更新间隔、镜像站模板、
表单演示页的增改弹窗。

### 8.1.11 竞速统计补齐旧版四组（不再删两组）

1.4.3 的 `RaceStatsScreen` 有四组：概览、策略概览、胜出服务商排行、智能选择首选。
上一轮只做了首尾两组，并在页面头注释里写「`strategy` / `fallbackUsed` /
`selectedProviderId` 这三列在本仓原生写入侧尚未落地，因此不列」——**这个判断是错的**。
原生 `RaceLogWriter.kt` 自始就在写这三列（Go 引擎的 `notifyRaceLog` 回调把它们逐条
落库），所以「策略概览」与「智能选择首选」本可以算出来，只是被误当成缺数据删掉了。

补回的两条 SQL 逐字移植自旧版 `RaceLogDao.strategyStats` /
`smartSelectionStats`（`RaceLogRepository`），口径有三处不能省：

1. **`primaryWins` 是「首选即胜出且成功」**，不是「只要成功」。兜底救回的查询
   （`fallbackUsed = 1`、首选失败换下一个）不算首选命中，否则智能预测的命中率会被
   高估。
2. **`selectedSuccesses` 排除兜底**：与旧版一样要求 `fallbackUsed = 0 AND
   winnerProviderId = selectedProviderId AND success = 1`。
3. **窗口按 `timestamp` 过滤**，否则「今日」档会混进历史行。

页面按旧版形态渲染：策略行副标题只对智能选择追加「首选命中率 · 兜底次数」；
其余策略只显示「成功 x% · 平均 x ms」。库缺这几列（旧库 / 残缺库）时这两组留空，
但「概览」与「胜出服务商」仍正常显示——`raceStatsProvider` 只对这两条聚合的
`no such column` 容错，不让整页报错。

`test/race_stats_test.dart`（4 条）用内存库钉住上面三个口径与策略显示名的历史别名。
实测（emulator-5554，注入 5 行覆盖三种策略的竞速数据）：策略概览三行
「最快响应 / 依次尝试 / 智能选择（首选命中 33.3% · 兜底 2 次）」，智能选择首选
「阿里云 · 首选命中 33.3% · 平均首选耗时 1277 ms · 3 次」，与 SQL 手算一致；
删空后回到空态（0 请求、破折号、两组自动隐藏）。

### 8.1.12 订阅自动更新：从「只存设置」到前台补跑

上一轮的自动更新页只把「总开关 + 间隔」写进数据集 prefs、把分组开关写进
`subscription_group.autoUpdateEnabled`，页脚如实写着「本机尚未接入后台调度器」。
结果是：**打开开关之后什么都不会发生**——设置是真的，执行是空的。旧版靠
`SubscriptionAutoUpdateScheduler` 的 WorkManager 周期任务执行，本仓原生侧没有
移植那个调度器。

本轮补的是执行侧（`lib/state/auto_update_runner.dart`）：

1. **触发点**：应用启动 + 每次回到前台（`AppLifecycleListener.onResume`）。只在启动
   检查会让长期挂后台的用户永远等不到；只在回前台检查会让首启不跑。
2. **到期判据**：订阅行的真实 `lastAttemptAt`（成功 / 304 / 失败都会写）与设置的间隔
   比较。用 `lastAttemptAt` 而不是 `lastUpdated`——一个一直 304 的订阅 `lastUpdated`
   很久不变，用它会永远判定到期而每次回前台都全量下载；失败过的订阅同理。
   不额外维护「上次运行」本地变量，避免两条真相打架。
3. **执行**：复用 `SubscriptionUpdateNotifier.updateAll`，与用户手点「全部更新」是同一条
   链路（真发包、真解析、真入库、真写 ETag）。手动更新正在跑时本轮让路（对应旧版
   `BlockedByManualOperation`）。
4. **可观测**：设置页新增「执行状态」组——「下次预计更新」（按最早到期的那条算）与
   「上次自动更新」（真实摘要，如「2 个失败（2 个订阅）」）。跳过（未到期 / 已关闭）
   不刷新「上次更新」，否则「刚检查过」会被误读成「刚更新过」。

**与旧版的真实差距照实写在页脚**：应用被完全关闭期间不会更新（没有后台任务队列）。
不写「会在后台按此频率更新」这种做不到的承诺。

实测（emulator-5554）：

- 打开开关后「下次预计更新」显示 `10 月 23 日 10:56（22 小时 58 分钟后）`，由库里
  `lastAttemptAt` 推出，与手算一致；
- 把 `lastAttemptAt` 清零模拟到期并重启：`lastAttemptAt` 被写成当前时刻、
  `consecutiveFailureCount` 3→4（种子地址 `sub.seed.test` 不存在，真发包失败），
  页面显示「上次自动更新：2 个失败（2 个订阅）」；
- 换成真实可访问的 hosts 订阅后重启：`importState` 从 `ready` 走到 `importing`
  再到 `ready`，`ruleCount = 71492`，`block_rule` 由 1 行涨到 71493 行，
  `consecutiveFailureCount` 归零——**七万条规则由自动更新真的下载并入库**。

`test/auto_update_runner_test.dart`（10 条）钉住到期判定的边界：从未尝试→到期、
未满间隔→不到期、刚好满间隔→到期、间隔跟随设置（不是写死 24 小时）、
`nextDueAt` 取最早到期、从未尝试的订阅立即到期。

### 8.1.13 服务器模式自定义上游：补上增删改入口

`/server` 的「上游服务器」页上一轮只做到**列出**：内置项可切换，自定义组的
空状态写着「自定义上游在旧版设置页添加，本仓尚未接入编辑入口」。这句话本身
就是缺口自述——旧版 `DnsMainScreen` 的 `onAddUpstream` / `onUpdateUpstream` /
`onDeleteUpstream` 三个回调都挂在这一屏上，`DnsModeManager` 里对应
`addCustomUpstream` / `updateCustomUpstream` / `removeCustomUpstream`。

补的是写入侧（`ServerUpstreamActions` + `UpstreamDialog`）：

1. **id 前缀**：新增用 `custom_` 开头（旧版 `"custom_" + UUID`）。读取侧靠
   `preset_` 前缀区分内置与自定义，自定义项一旦用 `preset_` 开头就会被当成内置、
   变得不可编辑。
2. **IPv6 方括号归一**：非 DoH 地址落盘前去掉 `[]`。旧版注释写得很明确——
   方括号输入**校验时接受**，但存储要裸地址，否则引擎自己再包一层会变成
   `[[2001:db8::1]]:53`。
3. **删除当前选中项要回落**：`selected_upstream_id` 指向已删除记录时，服务启动
   只能靠兜底猜。旧版直接 `selectUpstream(PRESETS.first().id)`，本仓同样回落到
   第一个内置项。
4. **序列化只写五个字段**：`id` / `name` / `protocol` / `address` / `port`，与旧版
   `DnsModePreferences.serializeUpstreams` 逐字一致；多写字段会让降级回 1.4.3 时
   解析出脏数据。

校验放在数据层（`validateServerUpstream`）而不是对话框里：两套校验迟早会分叉成
「对话框放过了、写盘时被拒」的静默失败。DoH 必须 `https://` 且能解析出 host；
其余协议端口 1–65535。

界面入口：右上角加号新增、空状态行也可点；自定义行尾「更多」弹出「编辑 / 删除」，
删除有二次确认并说明会回落。

实测（emulator-5554，服务器模式 → 上游服务器）：

- 新增 `MyIPv6DNS` / `[2001:db8::1]` / 53 → 列表显示 `DNS · 2001:db8::1:53`
  （方括号已去掉），落盘 `[{"id":"custom_1792643203674222_1",...,
  "address":"2001:db8::1","port":53}]`；
- 点该行选中 → `selected_upstream_id=custom_1792643203674222_1`，顶部标题变为
  「当前用于解析 DNS：(DNS) MyIPv6DNS」，重启应用后仍保持；
- 更多 → 编辑：对话框预填原值，改名 `EditedDNS` 保存后列表与顶部标题同步更新，
  **id 不变**；
- 更多 → 删除：确认后 `custom_upstreams` 变 `[]`、`selected_upstream_id` 回落
  `preset_alidns_dns`，界面回到「阿里云 + 暂无自定义服务商」空态。

`test/server_upstream_actions_test.dart`（18 条）钉住上面三条落盘语义、校验规则
与序列化字段集，并验证选中的自定义上游确实进入 `buildServerDnsConfig`。

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
