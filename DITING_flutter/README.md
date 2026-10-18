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
| 设计系统 `lib/ui/` | FlClash 0.9.1 `lib/ui/` 全量移植（113 文件 / 约 25k 行） | ✅ 完成，`flutter analyze` 零问题 |
| 组件烟测 `test/` | 8 个冒烟用例，覆盖脚手架 / 列表 / 浮条 / 空态 / 加载 / 弹层 | ✅ 通过 |
| 应用层 `lib/app/` | 主题管理、MaterialApp 引导、路由、演示状态 | ⬜ 未开始 |
| 演示页面 `lib/pages/` | 代表性全覆盖（首页×3 模式 / 功能中心 / 规则 / 订阅 / 日志 / 流量 / 设置 / …） | ⬜ 未开始 |

> **下一步工作请读 [docs/ui-framework/20-handoff.md](docs/ui-framework/20-handoff.md)** ——
> 其中逐条列出已冻结的 API、必须补齐的引导代码、页面清单和验证口径。

## 命令

```bash
flutter pub get
flutter analyze lib test
flutter test
```

## 目录

```
lib/ui/        移植的 FlClash 设计系统（GPL 头保留，勿改风格）
lib/app/       本应用层（待写）
lib/state/     演示状态（待写）
lib/data/      mock 数据（待写）
lib/pages/     演示页面（待写）
tool/          一次性拆分 / 核对脚本（不参与构建）
test/          组件烟测与测试宿主
docs/refactor/ DITING Android 功能图谱（只读规格）
docs/ui-framework/  本框架的现状与后续指南
```

## Android 构建

`flutter build apk` 在本机暂时无法完成：Gradle 需要从 `services.gradle.org` 下载发行版，
而本机只有 `mirrors.cloud.tencent.com` 可达（详见交接文档 §6）。这是**环境**问题，
不是工程问题；源码层面的验证口径是 `flutter analyze` + `flutter test`。
