# 谛听 DITING · Flutter 客户端

DITING 的 Flutter 重写：`lib/ui/` 是 1.4.3 设计体系的完整移植，应用层已接入**旧版
SharedPreferences 与旧版 SQLite**，因此外观、工作模式、解析服务商、缓存策略、拦截响应、
规则总控与三份应用名单在覆盖安装后都保持用户原值。

仍有部分页面（流量、连接/请求、订阅、应用独立规则、出站代理、CA 证书流程）走演示数据，
清单与原因见 [docs/ui-framework/21-ui-coverage-ledger.md](docs/ui-framework/21-ui-coverage-ledger.md)。

- 平台：Android（`android/`，包名 `com.haoze.diting`）
- 工具链：Flutter 3.47.7 / Dart 3.13.5
- 状态与路由：`flutter_riverpod` 3.4.3 + `go_router` 16.3.0
- 许可：GPL-3.0 —— 因为 `lib/ui/` 移植自 GPL-3.0 的 DITING，详见 [NOTICE.md](NOTICE.md)

## 当前进度

| 层 | 内容 | 状态 |
|---|---|---|
| 设计系统 `lib/ui/` | DITING 1.4.3 `lib/ui/` 全量移植（127 文件 / 28,301 行） | ✅ 完成 |
| 应用层 `lib/app/` | 主题管理（种子→纯黑→shape/surface/type）、`MaterialApp.router` 引导、scopes | ✅ 完成 |
| 数据兼容 `lib/data/` | 旧版 11 个 SharedPreferences 容器 + 旧版 SQLite（`diting_database` / `diting_express` / `diting_dns_rules`） | ✅ 完成 |
| 状态 `lib/state/` | 外观、工作模式、服务商目录/可见性、解析模式、规则、日志聚合（全部读旧版持久化） | ✅ 完成 |
| 壳层 `lib/shell/` | 六 tab 底栏（`StatefulShellRoute.indexedStack` + `NavigationDock`） | ✅ 完成 |
| 页面 `lib/pages/` | 206 文件 / 45,358 行；**85 条路由**（含设置域二级页） | ✅ 完成 |
| 测试 `test/` | **22 文件 / 153 个用例**：落盘契约、VPN 配置、三模式、日志聚合、全路由构建、多尺寸布局 | ✅ 通过 |

> **下一步工作请读 [docs/ui-framework/20-handoff.md](docs/ui-framework/20-handoff.md)** ——
> 其中逐条列出已冻结的 API、引导代码约定、剩余可做的事、统计口径与验证口径。

## 命令

```bash
flutter pub get
flutter analyze lib test      # 期望 No issues found
flutter test                  # 期望 153 个用例全绿
flutter build apk --debug     # 已验证可出包（见文末）
```

> 模拟器（x86_64）联调必须用多 ABI 的 AAR：`flutter build apk --debug -PtunnelAar=libs/tunnel-debug.aar`，
> 否则 `libgojni.so` 只有 `arm64-v8a`，`System.loadLibrary` 会失败。正式 arm64 包不受影响，
> 详见 [docs/development/aar-build-notes.md](../docs/development/aar-build-notes.md)。

**关于 `flutter run`**：`lib/main.dart` 已恢复，`DitingApp` 可直接启动。本机工程只配了
`android/` 平台目录（Android 能构建、能出包）；想在桌面或浏览器跑，先补平台目录：

```bash
flutter create . --platforms windows,web   # 补平台目录（会新增 windows/ web/）
flutter run -d windows                     # 或 -d chrome
```

源码级验证口径始终是 `flutter analyze` + `flutter test`，不依赖平台目录。

## 目录

```
lib/main.dart  唯一入口（ProviderScope + DitingApp）
lib/app/       应用层：主题（colors/layout/manager）、引导（bootstrap）、文案（l10n）、根组件（app.dart）
lib/router.dart  路由表与 branch 顺序（底栏下标映射依赖它，勿随意重排）
lib/routes/    按域拆分的 GoRoute 声明（dashboard/hub/observability/profiles/config/system/proxies）
lib/shell/     壳层：六 tab 底栏
lib/state/     Riverpod 状态（外观 / 工作模式 / 服务商目录 / 规则 / 日志聚合）
lib/data/      prefs（旧版容器读写）、db（旧版 SQLite 只读 + 清空）、vpn（引擎配置与 prefs 组装）、mock_*（未接线的演示数据）
lib/pages/     页面，按域分目录
lib/widgets/   跨页面共享小组件（StatStrip / KeyValueRow / SectionBlock / PageBody / DockSpacer / glyphByName）
lib/ui/        移植的 DITING 设计系统（GPL 头保留，勿改风格）
tool/          一次性拆分 / 核对脚本（不参与构建）
test/          落盘契约、引擎配置、三模式、日志聚合、组件与整机烟测、测试宿主
docs/refactor/ DITING Android 功能图谱（只读规格）
docs/ui-framework/  本框架的现状与后续指南
```

## 应用层约定（写页面前必读）

1. **`MaterialApp.builder` 里挂 scope**：`AppScopes` 必须位于 `Navigator` 之上、`MaterialApp` 之下，
   否则 `showFloatingDialog` / `showSheet` / `CommonPopupBox` 这类浮层路由拿不到
   `MeasureScope` / `ViewScope` 而在 build 期 assert。详见 `lib/app/app.dart` 的注释。
2. **`locale: zh_CN` 必须配 `GlobalMaterialLocalizations`**：`DefaultMaterialLocalizations` 只有
   en_US，`AppBar` 会直接抛 `No MaterialLocalizations found`。
3. **主题必须走 `AppThemeCache`**：`ThemeData` 每次重建都不相等，直接用会让 `ThemeCrossFade`
   在每帧把整屏截图淡出。
4. **底栏下标 ≠ branch 下标**：用户可配置底栏项，`lib/router.dart` 的 `_branchOrder` 是固定的
   branch 顺序，`AppShell` 负责两者映射；重排 branch 会打乱所有 `goBranch`。
5. **每个代码文件 ≤550 行**（AGENTS.md）；超了拆 `library` + `part`，参照 `lib/data/mock_data.dart`。

## 旧版数据兼容（覆盖安装后仍是用户原值）

写入一律经 `LegacySettings`（`lib/data/prefs/`），容器名与键名逐字对齐 1.4.3：

| 容器 | 内容 |
|---|---|
| `dns_vpn_prefs` | 解析服务商（`user_providers_json` / `selected_provider_id`）、三种解析模式的 id 列表、首页服务显示过滤、9 个 `dns_cache_*_v2` 键与 `dns_cache_preset_v3`、`block_response_mode` + 4 个动态拦截键、规则总控 4 个开关、Bootstrap 三键、三份应用包名列表与开关、外观与工作模式 |
| `diting_express_prefs` | 极速模式的 DNS 键（键名同上，容器不同） |
| `express_vpn_prefs` | `express_vpn_running` |
| `diting_database` / `diting_express` / `diting_dns_rules` | 旧版 Room 库：规则、`dns_log`、`dns_cache`、`dns_race_log`、`bootstrap_log` |

两条硬约定：

1. **写入后必须 `bump()`** `legacySettingsRevisionProvider`，否则其他页面读到旧值（`SharedPreferences` 不可观察）；
2. **数值夹取放在 setter 里**（动态拦截 2–100 / 10–300 / 60–3600、TTL 秒数），不要只靠控件。

## 日志仪表盘口径

顶部四格都来自 `dns_log` 的**当日**聚合（`DnsLogRepository.dailyStats`），不是引擎会话计数
（引擎计数重启即归零）：

- 今日查询 = 当日行数；已拦截 = `result = 'BLOCKED'`；缓存命中 = `cached = 1` 的行数；
- 命中率分母 = `passed + error`，对齐 Go 的 `hitRatio = hits / (hits + misses)`；
  被规则拦截的行不查缓存，不进分母；
- 平均延迟 = 当日带 `elapsed=NNms` 行的均值，无样本显示 `—` 而不是 `0ms`。


## Android 构建

`flutter build apk --debug` **可以正常完成**，实测产出：

```
build/app/outputs/flutter-apk/app-debug.apk    157 MB
```

> ⚠️ 本文旧版写着「本机暂时无法完成，因为只有 `mirrors.cloud.tencent.com` 可达」。
> **该结论已证伪**：2026-10-19 复测 `services.gradle.org` / `repo1.maven.org` /
> `plugins.gradle.org` 全部 200，Gradle 9.3.1（224 MB）、NDK 28.2（约 2.1 GB）、
> SDK Platform 36 与全部 Gradle 依赖均下载成功。详见交接文档 §6。

首次构建慢是**一次性环境准备**，不是卡死：Gradle 发行版 + NDK + SDK 平台 + Gradle 依赖
合计约 3 GB。之后是增量编译，几十秒级。

**看进度别用 `| Select-Object -Last N`** —— 它会缓冲全部输出，命令结束前一个字都不显示，
看起来像卡住。正确做法：

```powershell
flutter build apk --debug *> build.log   # 或 Start-Process -RedirectStandardOutput
Get-Content build.log -Tail 20           # 另开一个窗口跟
```

