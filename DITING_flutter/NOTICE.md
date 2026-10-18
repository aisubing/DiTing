# NOTICE · 第三方来源与许可

本项目（谛听 DITING 的 Flutter UI 框架）**不是**从零设计的外观。`lib/ui/` 整层、两套字体、
玻璃着色器以及主题组装方式均移植自 FlClash 0.9.1；`lib/app/` 及页面内容才是 DITING 自己的。

## 1. FlClash

- 上游仓库：<https://github.com/chen08209/FlClash>
- 移植基线：v0.9.1（`LearningObjects/FlClash-0.9.1/`，`pubspec.yaml` 版本 `0.9.1+2026101702`）
- 版权：Copyright (c) the FlClash authors
- 许可证：**GPL-3.0-or-later**（全文见本目录 `LICENSE`）
- 本项目许可证：同为 GPL-3.0，兼容。

### 1.1 移植范围

`lib/ui/` 下每个 `.dart` 文件首行均带有：

```
// Portions derived from FlClash (https://github.com/chen08209/FlClash),
// Copyright (c) the FlClash authors, GPL-3.0-or-later.
```

| 上游路径 | 本项目路径 | 说明 |
|---|---|---|
| `lib/ui/**`（82 个根文件 / 25,948 行） | `lib/ui/**`（113 个文件） | 逐文件复制，`package:fl_clash/` → `package:diting/`，按 ≤550 行规则拆为 `part` |
| `lib/ui/icons/**` | `lib/ui/icons/**` | 7 个文件全量移植；`app_glyphs.dart` 由 2,023 行拆为根文件 + 5 个 part |
| `lib/ui/common/input_limits.dart`、`iterable.dart` | `lib/ui/support/` | 上游 `lib/common/` 中被 ui 引用的两个文件 |
| `lib/manager/theme_manager.dart` | `lib/app/theme/manager.dart`（待写） | 仅移植主题组装链，见 §3 |
| `assets/fonts/JetBrainsMono-Regular.ttf` | `assets/fonts/` | 原样复制 |
| `assets/fonts/Twemoji.Mozilla.ttf` | `assets/fonts/` | 原样复制（Twemoji 图形版权 CC-BY 4.0，字体文件来自 Mozilla 构建） |
| `shaders/liquid_glass.frag` | `shaders/` | 原样复制，AGSL 运行时着色器 |

### 1.2 未移植（非疏漏）

上游 `lib/ui/` 中以下 4 个文件被有意丢弃，均为桌面端或本阶段不需要：

| 文件 | 行数 | 原因 |
|---|---|---|
| `sidebar.dart` | 574 | 桌面侧栏；Android 单栏布局不用 |
| `table_layout.dart` | 243 | 桌面表格布局 |
| `super_reorderable_list.dart` | 28 | 仅被 `table_layout` 使用 |
| `paged_sheet.dart` | 233 | 上游仅被 `ui.dart` barrel 导出，仓库内零调用点 |

### 1.3 上游 `lib/` 中**未**移植的部分

FlClash 的 `lib/views/`、`lib/pages/`、`lib/widgets/`、`lib/features/`、`lib/providers/`、
`lib/models/`、`lib/manager/`（`theme_manager.dart` 除外）、`lib/common/`（两个 support 文件除外）
**全部未移植**。本项目的演示页面与状态层是独立编写的（`lib/app/`、`lib/state/`、`lib/data/`），
仅参照上游的组件组合方式。

## 2. 第三方 Dart 包

`pubspec.yaml` 中的以下依赖与 FlClash 0.9.1 的 `pubspec.lock` 锁定同版本，以保证移植组件的
API 不漂移：

| 包 | 版本 | 用途 | 许可 |
|---|---|---|---|
| `material_ui` | 1.5.0 | Flutter 官方拆出的 Material 3 库（`RoundedSuperellipseBorder`、`Easing`） | BSD-3-Clause |
| `material_color_utilities` | 0.13.0 | HCT 取色 / DynamicColor | Apache-2.0 |
| `material_new_shapes` | 1.0.0 | 空状态插画多边形 | Apache-2.0 |
| `animations` | 3.0.0 | `FadeThrough` / `OpenContainer` | BSD-3-Clause |
| `path_parsing` | 1.1.0 | Glyph SVG path 解析 | BSD-3-Clause |
| `emoji_regex` | 0.0.5 | Emoji 分组 | MIT |
| `flutter_riverpod` | 3.4.3 | 演示状态 | MIT |
| `go_router` | 16.3.0 | 路由 | BSD-3-Clause |

## 3. 主题组装链的来源

`seededColorScheme()` / `toPureBlack()` / `withAppShapes` / `withAppSurfaces` / `withAppTypography`
均在 `lib/ui/` 内（已带 GPL 头）。尚未移植的 `lib/app/theme/manager.dart` 将复刻上游
`lib/manager/theme_manager.dart` 的 `ThemeData(...)` 组装顺序；该文件同样按 GPL 头处理。
上游的 `defaultPrimaryColor = 0xFF007AFF` 与 8 个 Apple 系统色（`defaultPrimaryColors`）来自
`lib/common/constant.dart`，属常量数据，重新声明于 `lib/app/theme/colors.dart`。

## 4. 修改与再分发

本项目对上游代码的修改仅限于：

1. 包名改写（`package:fl_clash` → `package:diting`）；
2. 按 550 行规则拆分为 `part`，并为拆分出的成员生成 `_g_<name>_` 顶层私有常量与转发成员
   （公共 API 不变）；
3. 手写 `lib/ui/models.dart` 替代上游 `freezed` 生成类（公共语义一致）；
4. 增加 `lib/ui/analysis_options.yaml` 关闭三条与上游风格冲突的 lint。

分发本项目的二进制或源码时，须同时提供 GPL-3.0 全文并保留上述版权头。
