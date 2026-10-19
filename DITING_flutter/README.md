# 谛听 DITING · Flutter UI 框架

FlClash 视觉体系的纯 UI 移植，用于 DITING 的 Flutter 重构。**本阶段不含任何业务逻辑**：
没有网络、没有数据库、没有 VPN 服务，所有页面与交互都由本地 mock 状态驱动。

- 平台：Android（`android/` 为 `flutter create` 产物，包名 `com.haoze.diting`）
- 工具链：Flutter 3.47.7 / Dart 3.13.5
- 状态与路由：`flutter_riverpod` 3.4.3 + `go_router` 16.3.0
- 许可：GPL-3.0 —— 因为 `lib/ui/` 移植自 GPL-3.0 的 FlClash，详见 [NOTICE.md](NOTICE.md)

## 当前进度

| 层 | 内容 | 状态 |
|---|---|---|
| 设计系统 `lib/ui/` | FlClash 0.9.1 `lib/ui/` 全量移植（127 文件 / 约 28k 行） | ✅ 完成，`flutter analyze` 零问题 |
| 应用层 `lib/app/` | 主题管理（种子→纯黑→shape/surface/type）、`MaterialApp.router` 引导、scopes、路由 | ✅ 完成 |
| 演示状态 `lib/state/` | 外观（主题/色板/透明度/底栏/触感）+ 工作模式（电源/服务商/解析）两组 Notifier | ✅ 完成 |
| 演示数据 `lib/data/` | 服务商 / 规则 / 订阅 / 日志 / 缓存 / 竞速 / 流量 / 应用 / 功能卡，按域拆 3 个 part | ✅ 完成 |
| 壳层 `lib/shell/` | 六 tab 底栏（`StatefulShellRoute.indexedStack` + `NavigationDock`） | ✅ 完成 |
| 演示页面 `lib/pages/` | 18 条路由：首页（三模式共用壳）/ 功能中心 / 规则×3 / 批量编辑 / 订阅 / 日志 / 流量 / 工具 / 应用 / 设置 / 模式×2 / 服务器 / AI / 关于 / 组件画廊 | ✅ 完成 |
| 测试 `test/` | **52 个用例**：组件烟测 8 + 整机 5 + 应用层 28 + scopes 层级 2 + 枚举上屏 5 + 多尺寸布局 4 | ✅ 通过 |

> **下一步工作请读 [docs/ui-framework/20-handoff.md](docs/ui-framework/20-handoff.md)** ——
> 其中逐条列出已冻结的 API、引导代码约定、页面清单、剩余可做的事和验证口径。

## 命令

```bash
flutter pub get
flutter analyze lib test      # 期望 No issues found
flutter test                  # 期望 52 个用例全绿
flutter run                   # 需先有平台目录，见下
```

**关于 `flutter run`**：`lib/main.dart` 已恢复，`DitingApp` 可直接启动。但本机工程只配了
`android/` 平台目录，而 Android 构建受网络限制（见文末），桌面/浏览器需要先补平台目录：

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
lib/shell/     壳层：六 tab 底栏
lib/state/     Riverpod 演示状态
lib/data/      演示数据（3 个 part）
lib/pages/     演示页面，按域分目录
lib/widgets/   跨页面共享小组件（StatStrip / KeyValueRow / SectionBlock / PageBody / DockSpacer / glyphByName）
lib/ui/        移植的 FlClash 设计系统（GPL 头保留，勿改风格）
tool/          一次性拆分 / 核对脚本（不参与构建）
test/          组件烟测、整机烟测与测试宿主
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


## Android 构建

`flutter build apk` 在本机暂时无法完成：Gradle 需要从 `services.gradle.org` 下载发行版，
而本机只有 `mirrors.cloud.tencent.com` 可达（详见交接文档 §6）。这是**环境**问题，
不是工程问题；源码层面的验证口径是 `flutter analyze` + `flutter test`。

