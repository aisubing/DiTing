---
所属: 谛听 Flutter UI 框架
状态: 第二轮 UI 全覆盖台账（持续更新）
最后校验: 2026-10-19
口径: 上游 = LearningObjects/FlClash-0.9.1/lib（GPL-3.0，只读参照）；本仓 = DITING_flutter/lib
---

# 21 · 第二轮 UI 全覆盖台账

> 本文件是第二轮「对照 FlClash 原版逐项核对 UI」的唯一清单。**每一项都必须能被
> 指到上游源码位置**；本仓侧只允许三态：`已迁移` / `部分` / `缺失`。
> 任何新增页面都要在 §10 登记，否则视为未完成。

## 0. 判定规则（先读，避免口径漂移）

1. **「可见 UI」的边界**：用户能看到的都算 —— 页面、卡片、导航栏、仪表盘、弹窗、
   模态框、菜单、表单、设置项、状态提示、空态、骨架、图标、动画，以及**必须
   通过点击 / 长按 / 展开 / 切换 / 拖拽才能显示**的界面（编辑模式、抽屉、子页面、
   浮层、条件分支）。
2. **不算**：纯业务逻辑（网络、数据库、VPN、内核）、桌面专属（`sidebar.dart`、
   `table_layout.dart`、窗口管理、托盘、快捷键录制）、以及上游已证零调用点的死路由。
3. **本阶段只做 UI**：交互只需演示反馈（本地 state / 延时模拟），不接真实业务。
4. **不修改上游**：`LearningObjects/FlClash-0.9.1/` 只读，禁止写入。
5. **每个代码文件 ≤550 行**（AGENTS.md）；超了拆 `library` + `part`。

## 1. 上游规模实测与第二轮交付量

| 目录 | 文件数 | 行数 | 本仓对应（第二轮后） |
|---|---|---|---|
| `lib/ui/` | 90 | 29,421 | `lib/ui/` 127 文件 / 28,261 行（已全量移植，本阶段未改） |
| `lib/views/` | 74 | 约 26,900 | `lib/pages/` 覆盖 |
| `lib/pages/` | 5 | 2,878 | 覆盖（含编辑器 / 扫码 / 错误页） |
| `lib/features/` | 28 | 约 8,000 | `lib/pages/forms/` + 各域表单浮层 |
| **UI 合计** | — | **约 42,800** | **`lib/pages/` 187 文件 / 40,004 行** |

**第二轮交付量（基线 → 现状）**

| 指标 | 第二轮前 | 第二轮后 | 倍数 |
|---|---|---|---|
| `lib/` 总行数 | 约 41,836 | **79,728**（370 文件） | 1.90× |
| `lib/pages/` 行数 | 10,514（43 文件） | **40,004**（187 文件） | **3.80×** |
| 路由数 | 18 | **74**（16 基线路由 + 58 领域路由） | 3.9× |
| 单文件最大行数 | — | 532（`pages/system/editor_page.dart`） | 全部 ≤550 |

结论：**设计系统层 100% 移植；页面层从约 25% 提升到覆盖上游全部可见页面**。剩余
未迁移项只有 §13 列出的桌面专属能力与本轮主动延后的 `paged_sheet`。


## 2. 设计系统 `lib/ui/`（已完成，仅登记差异）

| 项 | 状态 | 说明 |
|---|---|---|
| 上游 90 个 `.dart` | 已迁移 | 拆为 127 文件，公共 API 不变 |
| `sidebar.dart` / `table_layout.dart` / `super_reorderable_list.dart` | 不迁移 | 桌面专属；`super_reorderable_list` 仅被 `table_layout` 用 |
| `paged_sheet.dart` | **仍缺失** | 上游仅被 barrel 导出、仓内零调用；但它是通用浮层能力，见 §9-A |
| `models.freezed.dart` | 等价实现 | 本仓手写 `lib/ui/models.dart` |
| `NullStatusSwitcher` | 已迁移未上屏 | 需要 loading/empty 状态机，见 §9-B |
| `LiquidGlass*` | 已迁移未上屏 | 默认关闭，见 §9-C |

## 3. 导航与壳层

| 上游 | 位置 | 本仓 | 状态 |
|---|---|---|---|
| 底栏浮条 `NavigationDock` | `pages/home.dart:94-109` | `lib/shell/app_shell.dart` | 已迁移 |
| 非浮条 `NavigationBar` 回退 | `pages/home.dart:113-133` | `app_shell.dart:_FallbackBar` | 已迁移 |
| tab 切换淡入/滑动（`TabAnimation`） | `pages/home.dart:278-323`、`views/theme.dart:_TabAnimationItem` | 无 | 已迁移（切 tab 无动画选项） |
| 返回键回首页（`HomeBackScopeContainer`） | `pages/home.dart:417-444` | 无 | 已迁移 |
| 页面保活 `KeepScope` + `TickerMode` | `pages/home.dart:177-223` | `StatefulShellRoute.indexedStack` 等价 | 已迁移（机制不同） |
| 侧栏（桌面） | `ui/sidebar.dart` | — | 不迁移（Android 单栏） |

## 4. 仪表盘（首页）

上游 `lib/views/dashboard/` 共 20 文件 / 约 8,900 行。第二轮已实现全部 10 张
可编排卡片 + 完整编辑模式；桌面专属的 `NetworkTakeoverCard` 与多列布局不迁移。

### 4.1 卡片清单（`views/dashboard/widget_registry.dart:8-20`）

| # | 卡片 | 上游文件 | 行数 | 本仓 | 状态 |
|---|---|---|---|---|---|
| 1 | `CurrentOutboundCard` 当前出站/状态 | `widgets/current_outbound.dart` | 945 | `cards/current_outbound_card.dart` | 已迁移 |
| 2 | `NetworkSpeedCard` 网络速率（上/下行双图） | `widgets/traffic.dart` | 339 | `cards/network_speed_card.dart` | 已迁移 |
| 3 | `OutboundModeCard` / `OutboundModeBar` 出站模式 | `widgets/outbound_mode.dart` | 174 | `cards/outbound_mode_card.dart` | 已迁移 |
| 4 | `VpnCard` / `VpnTile` VPN 开关 | `widgets/network_takeover.dart` | 299 | `cards/vpn_card.dart` | 已迁移（VPN 形态） |
| 5 | `NetworkTakeoverCard` 网络接管（桌面） | 同上 | — | — | 桌面专属，不迁移 |
| 6 | `ServiceStatusCard` 服务状态（多服务探测） | `widgets/service_status.dart` | 1,050 | `cards/service_status_card.dart` | 已迁移（多服务形态） |
| 7 | `ProfilesCard` 当前配置卡（含波浪进度） | `widgets/profiles.dart` | 446 | `cards/profiles_card.dart` | 已迁移 |
| 8 | `ProxyGroupsCard` / `ProxyGroupsSummaryCard` 代理组 | `widgets/proxy_groups.dart` | 634 | `cards/proxy_groups_card.dart` | 已迁移（摘要形态） |
| 9 | `ConnectionStatsCard` 连接统计三计数 | `widgets/connection_stats.dart` | 131 | `cards/connection_stats_card.dart` | 已迁移 |
| 10 | `IntranetIpCard` 内网 IP | `widgets/intranet_ip.dart` | 150 | `cards/intranet_ip_card.dart` | 已迁移 |
| 11 | `MemoryInfo` + `MemoryDetailSheet` 内存信息 | `widgets/memory_info.dart` | 654 | `cards/memory_card.dart` | 已迁移 |

### 4.2 仪表盘外壳与编辑模式

| 项 | 上游位置 | 状态 |
|---|---|---|
| 卡片编排容器（移动端单列） | `dashboard.dart:290-357` | 已迁移 `dashboard_board.dart` |
| 编辑模式（进入/完成、卡片移除徽标、拖拽换位、添加行） | `edit.dart:33-650` | 已迁移 `dashboard_board.dart` + `edit/dashboard_edit_sheet.dart` |
| 编辑模式「卡片摇摆」动画 | `edit.dart` | 有意简化（改为缩放抬升，见 §12） |
| 桌面多列布局（2/4 列、表格填充） | `dashboard.dart:114-288` | 不迁移（Android） |
| 密度适配 `DashboardDensity` | `dashboard/layout.dart`、`dashboard/style.dart` | 已迁移 `dashboard_density.dart` / `dashboard_style.dart` |
| `CoreStatusButton` 内核状态按钮 | `widgets/core_status_button.dart` | 已迁移（并入 `current_outbound_card.dart`） |
| 连接明细表 `ConnectionsTableCard` | `widgets/connections_table.dart` | 见 §6.2（独立连接页承载） |
| 配置详情浮层 `ProfileDetailSheet` | `widgets/profile_detail.dart` | 已迁移 `profile_detail_page.dart`（`/dashboard/profile`，仪表盘配置档案卡直进） |
| 卡片基元（`DashboardCard` / `DashboardChip` / `DashboardConnectedButton` / `DashboardIconButton` 等） | `widgets/card.dart:1-898` | 已迁移 `dashboard_card.dart` |

## 5. 代理（Proxies）

上游 `lib/views/proxies/` 8 文件 / 2,660 行。本仓 7 文件 / 1,381 行。

| 上游 | 位置 | 本仓 | 状态 |
|---|---|---|---|
| `ProxiesView` 外壳（标题/搜索/延迟测试/定位/设置菜单） | `proxies.dart` | `proxies_page.dart` | 已迁移 |
| tab 模式：`ProxiesTabView` + `GroupTabs` 分组 chip 条 | `tab.dart`、`group_tabs.dart` | `proxies_page.dart:_TabBody` / `_GroupTabs` | 已迁移 |
| list 模式：`ProxiesListView` 折叠分组列表 | `list.dart` | `proxies_page.dart:_ListBody` | 已迁移 |
| `ProxyCard` 代理卡片（延迟色、选中态、三档尺寸） | `card.dart` | `proxy_card.dart` | 已迁移 |
| 外部代理提供者 `ExternalProvidersSliver` + 编辑页 | `providers.dart` | `proxy_providers_page.dart` + `proxy_provider_form.dart` | 已迁移 |
| 代理设置面板 `ProxiesSetting`（六项） | `setting.dart` | `proxies_settings_sheet.dart` | 已迁移 |
| 节点长按上下文菜单 | `card.dart` | `proxies_page.dart:_NodeMenuSheet` | 已迁移 |

**有意简化**：`DelayText` 的延迟数字滚动动画简化为直接换字（一个列表几十个
数字各自跑 `AnimationController` 会让 `pumpAndSettle` 永不静止）；测速与延迟
数据用固定种子的 `Random(20261019)`，保证同一会话内可复现。

**已知与上游一致的「怪」行为**（不是缺陷，接线时不要"修"）：
- `ProxiesLayout`（紧凑/标准/宽松）与 `ProxyCardType`（宽松/标准/紧凑）在设置
  面板里显示同一组词，同屏重复文案，`findsOneWidget` 类断言要注意；
- 隐藏超时节点时，若某组全部节点都超时，该组整条从列表消失（不是空组态）；
- 顶栏动作上限 2 个，页面占用「模式切换」后，`iconActions` 会折进「更多」菜单。


## 6. 观测域

### 6.1 已有

| 上游 | 本仓 | 状态 |
|---|---|---|
| `views/logs.dart` 日志列表 + 导出 | `lib/pages/logs/` 三视图 | 已迁移（导出弹窗 + 级别筛选已补） |
| `views/dashboard/widgets/traffic.dart` 速率图 | `lib/pages/traffic/` + 仪表盘 `network_speed_card` | 已迁移（双序列 + 累计流量） |

### 6.2 连接 / DNS / 资源

| 上游 | 行数 | 状态 |
|---|---|---|
| `views/connection/connections.dart` 连接列表 + 拦截按钮 | 214 | 已迁移 |
| `views/connection/requests.dart` 请求列表 | 129 | 已迁移 |
| `features/connection/tracker_info_item.dart` 连接详情条目 | 306 | 已迁移 |
| `features/connection/tracker_info_list.dart` 连接详情列表 | 172 | 已迁移 |
| `features/connection/tracker_info_table.dart` 连接详情表格 | 249 | 已迁移 |
| `features/connection/tracker_speed_ranker.dart` 速率排名 | 118 | 已迁移 |
| `views/dns_queries.dart` DNS 查询列表 + 详情 + 错误行 | 451 | 已迁移 |
| `views/resources.dart` 资源更新（geo/icon/rule-provider/script） | 606 | 已迁移 |

## 7. 配置（Profiles / 规则 / 订阅）

### 7.1 配置档案

上游 `lib/views/profiles/` 15 文件 / 约 8,600 行。

| 上游 | 行数 | 状态 |
|---|---|---|
| `profiles.dart` 配置网格 + 卡片 + 长按重排 sheet | 657 | 已迁移（本仓 `/subscriptions` 是规则订阅，语义不同） |
| `add.dart` 添加配置 | 155 | 已迁移 |
| `edit.dart` 编辑配置（名称/URL/密钥/自动更新/文件项） | 598 | 已迁移 |
| `preview.dart` 配置预览 | 20 | 已迁移 |
| `custom/custom.dart` 自定义配置总览 | 621 | 已迁移 |
| `custom/custom_proxies.dart` 自定义节点 + 分享链接 | 1,581 | 已迁移 |
| `custom/groups.dart` 自定义代理组 | 1,404 | 已迁移 |
| `custom/members.dart` 组成员选择 + 过滤器 | 854 | 已迁移 |
| `custom/providers.dart` 自定义提供者 | 643 | 已迁移 |
| `custom/rules.dart` 自定义规则 | 620 | 已迁移 |
| `custom/dialers.dart` 拨号器 | 158 | 已迁移 |
| `custom/icon.dart` 图标选择器（网格） | 593 | 已迁移 |
| `custom/quick_edit.dart` 文本快速编辑 | 79 | 已迁移 |
| `extend/extend.dart` 扩展页（脚本/标准） | 158 | 已迁移 |
| `extend/script.dart` / `extend/standard.dart` | 89 / 403 | 已迁移 |

### 7.2 规则

| 上游 | 本仓 | 状态 |
|---|---|---|
| 黑白名单 / 覆写列表 | `lib/pages/rules/` | 已迁移 |
| 批量添加规则 | `lib/pages/rules/batch_editor_page.dart` | 已迁移 |
| `config/rules.dart` 追加规则（added rules） | 无 | 已迁移 |
| `features/form/rule.dart` / `rule_preset.dart` 规则表单与预设 | 无 | 已迁移 |

### 7.3 订阅

| 上游 | 本仓 | 状态 |
|---|---|---|
| 订阅列表 / 添加 / 自动更新间隔 | `lib/pages/subscriptions/` | 已迁移 |

## 8. 设置与外观

### 8.1 外观

| 上游 | 本仓 | 状态 |
|---|---|---|
| `views/theme.dart` 主题页（1209 行，14 个条目） | `lib/pages/appearance/theme_page.dart` | 已迁移（14 条目全实现） |
| ├ 日夜模式 `_ThemeModeItem` | 有（`ListItem.options`） | 已迁移 |
| ├ 主题色 `_PrimaryColorItem` + 8 色板 | 有（9 色板圆点） | 已迁移 |
| ├ **自定义取色** `_CustomColorSheet`（色轮 + 吸管徽标 + 预览） | 无 | 已迁移 |
| ├ 纯黑 `_PureBlackItem` | 有 | 已迁移 |
| ├ 底栏样式 `_NavigationBarItem` | 无 | 已迁移 |
| ├ **tab 切换动画** `_TabAnimationItem` | 无 | 已迁移 |
| ├ Liquid 玻璃 `_LiquidGlassItem` | 无 | 已迁移 |
| ├ 侧栏模糊 `_SidebarBlurItem` | — | 桌面专属，不迁移 |
| ├ 字体 `_FontFamilyItem` + `font_family.dart` 字体选择页 | 无 | 已迁移 |
| ├ 字号 `_TextScaleFactorItem` | 有（滑杆） | 已迁移 |
| └ 重置按钮 `_ResetButton` | 无 | 已迁移 |
| `views/theme_preview.dart` 主题实时预览（迷你屏/分割屏） | 无 | 已迁移 |
| `views/tools.dart` 语言选择 `_LocaleItem` | 无 | 已迁移 |

### 8.2 配置页（`views/config/` 17 文件 / 约 6,600 行）

| 上游 | 行数 | 状态 |
|---|---|---|
| `general.dart` 通用（日志级别/UA/测试 URL/端口/Hosts/鉴权/外部控制器） | 485 | 已迁移 |
| `general/port_form.dart` 端口表单 | 207 | 已迁移 |
| `network.dart` 网络（VPN/TUN/绕过/代理/IPv6/DNS 劫持/栈/接口名/路由） | 611 | 已迁移 |
| `tun.dart` TUN 覆写 | 265 | 已迁移 |
| `dns.dart` DNS（覆写规格 / 策略字段） | 414 | 已迁移 |
| `ntp.dart` NTP | 125 | 已迁移 |
| `sniffer.dart` 嗅探 | 285 | 已迁移 |
| `override.dart` 覆写编辑器（5 种字段类型） | 695 | 已迁移 |
| `filters.dart` 过滤器 | 289 | 已迁移 |
| `rules.dart` 追加规则 | 207 | 已迁移 |
| `scripts.dart` 脚本 | 412 | 已迁移 |
| `providers.dart` Clash 提供者 | 636 | 已迁移 |
| `icon_sets.dart` 图标集 + 预览 | 316 | 已迁移 |
| `user_agents.dart` User-Agent 列表 | 235 | 已迁移 |
| `on_demand.dart` 按需连接 | 394 | 已迁移 |
| `advanced.dart` 高级（网络） | 52 | 已迁移 |
| `custom_resources.dart` 自定义资源（代理） | 48 | 已迁移 |

### 8.3 其他设置页

| 上游 | 行数 | 状态 |
|---|---|---|
| `views/access.dart` 应用访问控制（+ `PackageListItem`/`AccessControlPanel`） | 649 | 已迁移（本仓 `/apps` 只是勾选页） |
| `views/backup_and_restore.dart` 备份与恢复（WebDAV 表单、恢复选项） | 491 | 已迁移 |
| `views/disclaimer.dart` 免责声明（同意/复述弹窗） | 516 | 已迁移 |
| `views/developer.dart` 开发者选项 | 118 | 已迁移 |
| `views/hotkey.dart` 快捷键（桌面） | 521 | 桌面专属，不迁移（录制器交互可作演示） |
| `views/about.dart` 关于（贡献者/链接徽标/开发者模式触发） | 314 | 已迁移 |
| `views/font_family.dart` 字体族选择 | 194 | 已迁移 |
| `views/theme_preview.dart` | 850 | 已迁移 |

## 9. 浮层 / 交互控件 / 动画（跨页面）

| 项 | 上游 | 状态 |
|---|---|---|
| A `paged_sheet` 分页浮层 | `ui/paged_sheet.dart` | 仍缺失（仓内仍零调用；需要多页浮层时再移植） |
| B `NullStatusSwitcher` loading/empty 状态机 | `ui/null_status*.dart` | 已上屏（观测域各列表；注意它 `isSearching: true` 会忽略自定义 `nullStatus`） |
| C Liquid 玻璃 | `ui/liquid_glass*.dart` | **已上屏**：`MaterialApp.builder` 挂 `LiquidGlassScope`，由主题页三档开关驱动 |
| D `ShowBarScrollBehavior` 滚动隐藏顶栏 | `ui/scroll*.dart` | 已上屏 |
| E 长按上下文菜单 `ContextMenuRegion` | `ui/context_menu.dart` | 已上屏（连接 / 节点长按菜单） |
| F 拖拽排序 `SortableItem` / `SortHandle` | `ui/sortable*.dart` | 已上屏（仪表盘卡片排序、分组排序） |
| G 折叠分区 `SliverCollapsibleSection` | `ui/collapsible_section.dart` | 已上屏（配置页分组） |
| H 文本放大镜 `TextLoupe` | `ui/text_loupe.dart` | 已上屏（YAML 编辑器选区） |
| I 分段控件 / 搜索框 / 骨架 / 图表 | `ui/*` | 已上屏 |
| J 表单浮层 `showFormSheet` / `FormSheetRoute` | `ui/form_sheet.dart` | 已上屏（表单域 5 个演示页 + 各域新增/编辑浮层） |

## 10. 表单与编辑器（features）

| 上游 | 行数 | 状态 |
|---|---|---|
| `features/form/form_page.dart` 表单页 | 53 | 已迁移（`lib/pages/forms/`） |
| `features/form/form_row.dart` 表单行（297 行，多类型） | 297 | 已迁移 |
| `features/form/list_editor_page.dart` 列表编辑器 | 377 | 已迁移（`/form/list-editor`） |
| `features/form/map_edit_view.dart` 键值编辑器 | 317 | 已迁移（`/form/map-edit`） |
| `features/form/named_url_form.dart` 命名 URL 表单 | 324 | 已迁移（`/form/named-url`） |
| `features/form/selection_sheet.dart` 选择浮层 | 346 | 已迁移（`/form/selection`） |
| `features/form/nested_form_sheet.dart` 嵌套表单 | 113 | 已迁移 |
| `features/form/batch_section.dart` 批量区块 | 49 | 已迁移 |
| `features/form/custom_issue.dart` 自定义问题提示 | 170 | 已迁移（`NullStatus` 变体 + 表单内联提示） |
| `features/form/filter.dart` 过滤 | 57 | 已迁移 |
| `features/form/rule.dart` / `rule_preset.dart` | 429 / 145 | 已迁移（`/form/rule-preset`） |
| `features/ip_quality/*` IP 质量浮层与文本 | 323 | 已迁移（`/ip-quality`） |
| `features/editor/completion_popup.dart` 补全浮层 | 216 | 已迁移 |
| `pages/editor.dart` YAML 编辑器 | 1,260 | 已迁移（`/editor`，含行号栏 + 语法高亮 + 补全浮层） |
| `pages/scan.dart` 扫码页 | 840 | 已迁移（`/scan`，相机预览用占位画布） |
| `pages/error.dart` 错误页 | 344 | 已迁移（`/error`） |

## 11. 新增路由登记表（本仓）

> 新增页面必须在此登记，并同步 `lib/routes/paths.dart` 与对应
> `lib/routes/<domain>_routes.dart`。

| 路由 | 页面 | 归属 | 状态 |
|---|---|---|---|
| `/dashboard/edit` | 仪表盘编辑模式（redirect 进编辑态） | dashboard | 已实现 |
| `/proxies` | 代理（tab/list 双模式 + 设置浮层 + 节点长按菜单） | proxies | 已实现 |
| `/proxies/providers` | 代理提供者（+ 编辑表单） | proxies | 已实现 |
| `/connections` | 连接列表 | observability | 已实现 |
| `/requests` | 请求列表 | observability | 已实现 |
| `/dns-queries` | DNS 查询 | observability | 已实现 |
| `/resources` | 资源更新 | observability | 已实现 |
| `/profiles` | 配置档案网格 | profiles | 已实现 |
| `/profiles/add` | 添加配置 | profiles | 已实现 |
| `/profiles/edit` | 编辑配置 | profiles | 已实现 |
| `/profiles/preview` | 配置预览 | profiles | 已实现 |
| `/profiles/custom` | 自定义配置总览 | profiles | 已实现 |
| `/profiles/custom/proxies` | 自定义节点 | profiles | 已实现 |
| `/profiles/custom/groups` | 自定义代理组 | profiles | 已实现 |
| `/profiles/custom/rules` | 自定义规则 | profiles | 已实现 |
| `/profiles/custom/providers` | 自定义提供者 | profiles | 已实现 |
| `/profiles/custom/dialers` | 拨号器 | profiles | 已实现 |
| `/profiles/custom/icon` | 图标选择器 | profiles | 已实现 |
| `/profiles/extend` | 扩展 | profiles | 已实现 |
| `/profiles/extend/script` | 脚本扩展 | profiles | 已实现 |
| `/theme` | 主题设置（完整） | appearance | 已实现 |
| `/theme/preview` | 主题实时预览 | appearance | 已实现 |
| `/font-family` | 字体族选择 | appearance | 已实现 |
| `/config/general` | 通用设置 | config | 已实现 |
| `/config/network` | 网络设置 | config | 已实现 |
| `/config/tun` | TUN 覆写 | config | 已实现 |
| `/config/dns` | DNS 覆写 | config | 已实现 |
| `/config/ntp` | NTP | config | 已实现 |
| `/config/sniffer` | 嗅探 | config | 已实现 |
| `/config/override` | 覆写编辑器 | config | 已实现 |
| `/config/filters` | 过滤器 | config | 已实现 |
| `/config/rules` | 追加规则 | config | 已实现 |
| `/config/scripts` | 脚本 | config | 已实现 |
| `/config/providers` | Clash 提供者 | config | 已实现 |
| `/config/icon-sets` | 图标集 | config | 已实现 |
| `/config/user-agents` | User-Agent | config | 已实现 |
| `/config/on-demand` | 按需连接 | config | 已实现 |
| `/config/advanced` | 高级 | config | 已实现 |
| `/config/custom-resources` | 自定义资源 | config | 已实现 |
| `/access` | 应用访问控制 | system | 已实现 |
| `/backup` | 备份与恢复 | system | 已实现 |
| `/disclaimer` | 免责声明 | system | 已实现 |
| `/developer` | 开发者选项 | system | 已实现 |
| `/sponsor` | 赞助与共建 | system | 已实现 |
| `/app-update` | 应用更新 | system | 已实现 |
| `/ip-quality` | IP 质量浮层 | system | 已实现 |
| `/editor` | YAML 编辑器 | system | 已实现 |
| `/scan` | 扫码 | system | 已实现 |
| `/error` | 错误页 | system | 已实现 |
| `/form/list-editor` | 列表编辑器 | forms | 已实现 |
| `/form/map-edit` | 键值编辑器 | forms | 已实现 |
| `/form/named-url` | 命名 URL 表单 | forms | 已实现 |
| `/form/selection` | 选择浮层 | forms | 已实现 |
| `/form/rule-preset` | 规则预设 | forms | 已实现 |

## 12. 复查记录

| 轮次 | 日期 | 范围 | 结论 |
|---|---|---|---|
| R1 | 2026-10-19 | 全量清点 + 台账建立 + 路由骨架 + 首页仪表盘 + 代理 + 配置档案 + 主题 + 观测 | 见 §13 |
| R2 | 2026-10-19 | 五条并行流全量补齐 + 仪表盘重建 + 壳层动画/玻璃接通 + 测试补强 | 见下 |

### R2 详细结论

**已完成（Lead 主控）**
- 台账 + 并行开发约定（本文件 + [`22-parallel-work-contract.md`](22-parallel-work-contract.md)）。
- 路由按领域拆分：`lib/routes/{dashboard,proxies,observability,profiles,config,system}_routes.dart`
  + `routes.dart` 汇总，`lib/router.dart` 只做拼接。58 条领域路由落地。
- **仪表盘全量重建**：10 张卡片 + 卡片基元（`dashboard_card.dart`）+
  密度/取色/文字角色（`dashboard_density.dart` / `dashboard_style.dart`）+
  编辑模式（移除徽标、拖拽换位、添加卡片浮层、空态）+ 卡片入场动画。
- 首页重构：固定区（电源/句子/服务商/解析模式）与可编排区分离，编辑态隐藏
  固定区与快捷入口（与上游一致）。
- **壳层接通主题开关**：`LiquidGlassScope` 挂进 `MaterialApp.builder`；
  `AppShell` 消费 `bottomBarStyleProvider`（普通 → `NavigationBar` 回退）与
  `tabTransitionProvider`（淡入/滑动/缩放）。
- **设置页新增三组入口**（代理与配置 / 观测与内核 / 系统与安全），把 19 个
  系统页与各领域页变成可回访的二级入口，不再只靠功能中心发现。
- **未知路由兜底页** `UnknownRoutePage` + `GoRouter.errorBuilder`：原先漏注册的
  路由会渲染空白且**测试不报错**，现在既给用户明确提示，也让路由测试硬失败。

**已完成（五条并行流，均为独立 teammate，互不重叠写域）**
- 代理 / 观测 / 配置档案 / 内核配置 / 系统外观表单 五个领域，逐项映射见各章。

> **代理域（task-1）的实际交付方式**：并行流交付了数据层（`mock_proxies.dart`
> 276 行）与状态层（`proxies_providers.dart` 516 行）后停滞两小时未产出页面，
> 由 Lead 中断接手，补完 7 个页面文件 / 1,381 行 + 2 条路由 + 6 个交互测试。
> 接手时抓到的真实缺陷：`searchState` 传了非空 `query:` 会让
> `CommonScaffold` 一进页面就进入搜索模式（`_isSearch` 判据是
> `searchState.query != null`），标题与所有分组被藏掉。

**测试补强**
- 新增 `test/route_catalog_test.dart`：功能中心每张卡片的 route 必须真实注册
  （卡片路由是字符串字面量，`mock_apps.dart` 是 part 无法 import 常量），
  且每条路由构建后**不得落到 `UnknownRoutePage`**。
- `test/layout_regression_test.dart` 改为直接消费同一份路由表（原先各写一份），
  并在 320/412/834 三档宽度 + 1.4 倍字号下逐条跑溢出检查。
- 新增 `test/support/test_hooks.dart`：统一关掉演示用的无限动画，否则
  `pumpAndSettle` 必然超时。

**本轮发现并修复的真实缺陷（analyze 查不出，全是运行时问题）**
| 缺陷 | 症状 | 修法 |
|---|---|---|
| 手写泰勒级数 `_sin` 在 `x` 大时发散 | 速率变成 `6,582,849`，`LineChart` 里 `double.clamp(lower>upper)` 抛 `ArgumentError` | 改用 `dart:math` 的 `sin`；两处（数据层 + 卡片 `CustomPainter`） |
| `profiles_card` 波浪进度条 `repeat()` | `pumpAndSettle` 永远等不到静止 | 加 `debugDisableDashboardLiveUpdates` 开关，测试期不启动 |
| 首页 1 秒 tick 定时器 | 同上 | 同上（页面 `_startTicking` 读开关） |
| `feature_hub_page` 卡片硬编码 92dp 高 | 1.4 倍字号溢出 6dp | 高度按 `textScaler` 线性放大 |
| 速率卡 / 出站卡 / 配置卡的指标行 | 320 宽下横向溢出 36/130dp | 改 `Expanded` 等分 + 文字 `ellipsis`；数值与标签换行 |
| `null_status.dart:105-110` | `isSearching: true` 时忽略自定义 `nullStatus` | 页面级过滤不再传 `isSearching` |
| `AnimatedCrossFade`（system-ui） | 无界高度下 `size.isFinite` assert | 换 `AnimatedSwitcher` |
| 编辑器行号栏（system-ui） | 不跟随滚动 | 按 `scroll.offset / _lineHeight` 推导可见行 |

**有意简化（需在交付说明中保留）**
| 项 | 简化方式 | 原因 |
|---|---|---|
| 仪表盘编辑模式「摇摆」 | 改为 `ScaleTransition` 抬升 1.02 | 摇摆需要每卡一个 `AnimationController` 且与 `ReorderableListView` 的手势竞争；抬升同样能表达「可拖」 |
| 仪表盘桌面多列 | 不实现 | Android 单栏；`DashboardDensity.of` 仍保留判定，桌面宿主不会崩，只是单列 |
| `DashboardConnectedGroup` 的按下抬升 | 用普通 `Row` | 本仓卡片默认不裁剪，膨胀不会被兄弟遮挡，无需自定义 `RenderFlex` |
| 速率/内存趋势数据 | 正弦叠加的固定波形 | 随机数会让截图与 widget 测试不可复现（AGENT_MISTAKES） |
| 代理延迟数字滚动动画 | 直接换字 | 几十个数字各跑一个 `AnimationController` 会让 `pumpAndSettle` 永不静止 |
| 代理测速数据 | 固定种子 `Random(20261019)` | 同一会话内可复现，截图与回归稳定 |
| `_TabTransitionHost` 不做交叉淡入 | 旧 tab 立即消失，新 tab 入场 | 同时挂两棵长列表子树换 1 帧，收益不抵开销 |
| 桌面专属配置项 | 不渲染开关 | 开机自启/静默启动/托盘/系统代理/路由标记在 Android 无对应能力，不做「点了没反应」的开关 |
| DNS 策略表 | 列表式 `DnsPolicySection` | `MapEditView` 自带批量粘贴区，与十来条策略的逐条用法不符 |
| 覆写清空值后保留行 | 保留空值行 | 用户需要看得见「这一项现在没有覆写」 |
| 追加规则排序 | 上下箭头 | 搜索态下拖拽落点会跳到看不见的行 |
| 图标集预览 | 字形占位 | 演示环境不联网，网格与格子数是真实的 |
| 扫码页相机预览 | 画布占位 | 无相机权限通道 |

## 13. 无法复刻 / 主动不迁移（需在交付说明中保留）

| 项 | 原因 |
|---|---|
| 桌面侧栏 `ui/sidebar.dart` | Android 单栏，无侧栏形态 |
| `table_layout.dart` / `super_reorderable_list.dart` | 仅桌面表格使用 |
| `NetworkTakeoverCard`（系统代理 / TUN 接管） | 桌面网络接管，Android 无对应系统能力 |
| `views/hotkey.dart` 快捷键录制 | 桌面键盘；Android 无全局快捷键 |
| `SidebarBlurItem` 侧栏模糊 | 依赖侧栏 |
| 窗口标题栏 `WindowHeaderContainer` | 桌面窗口装饰 |
| 托盘 / 通知栏自定义 | 平台能力，非 UI 移植范围 |
| 真实数据源（内核流 / 订阅下载 / 测速 / 扫码 / 相机） | 本阶段只做 UI；所有页面用确定性假数据，形状与真实一致 |
| 按需连接的定位/电池优化授权 | 需要平台通道，本仓只报状态 |
