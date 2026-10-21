---
所属: 谛听 Flutter UI 框架
状态: 第四轮台账（数据接线）持续更新
最后校验: 2026-10-20
口径: 上游 = Android/app/src/main/java/com/haoze/diting（1.4.3 Kotlin/Compose，只读参照）；本仓 = DITING_flutter/lib
---

# 21 · UI 全覆盖台账

> ## ⚠️ 口径更正（2026-10-20 第四轮实测，推翻此前全部「上游」引用）
>
> 本文件此前把 `LearningObjects/DITING-1.4.3/lib`（`lib/ui/` 90 文件、`lib/views/` 74 文件、
> `lib/features/` 28 文件）记为「上游」。**该目录在本工作区里是空的**（`Get-ChildItem -Recurse`
> 计数为 0），且从未被 Git 跟踪（`git ls-files LearningObjects` 无输出，
> `.gitignore` 的 `LearningObjects/` 已排除）。也就是说：
>
> - §1、§4、§5、§6、§7、§8、§10 里那些「上游文件 / 行数」对照表**无法被任何人复现**，
>   不应再被当作事实引用；
> - 唯一可验证、可 grep、可运行的参照是 **`Android/`（522 个 `.kt` / 92,186 行，
>   DITING 1.4.3 的 Kotlin + Jetpack Compose 实现）**；
> - 由此派生的事实：部分页面在 1.4.3 里**根本没有对应后端**（见 §15）。
>   它们不是「迁移未完成」，而是「上游没有这个功能」。
>
> 后续轮次请一律以 `Android/` 为参照。要恢复 Flutter 上游对照，必须先把
> `LearningObjects/DITING-1.4.3/` 真正检出，否则只能按 Kotlin 版重写对照表。

> 本文件是「对照 DITING 原版逐项核对 UI」的唯一清单。
> 第三轮在此基础上补了第四态：**数据来源**（真实持久化 / 演示数据）。
> 两者的区别见 §14——UI 已迁移但数据仍为演示的页面，不得在交付说明里写成「已完成」。

## 0. 判定规则（先读，避免口径漂移）

1. **「可见 UI」的边界**：用户能看到的都算 —— 页面、卡片、导航栏、仪表盘、弹窗、
   模态框、菜单、表单、设置项、状态提示、空态、骨架、图标、动画，以及**必须
   通过点击 / 长按 / 展开 / 切换 / 拖拽才能显示**的界面（编辑模式、抽屉、子页面、
   浮层、条件分支）。
2. **不算**：纯业务逻辑（网络、数据库、VPN、内核）、桌面专属（`sidebar.dart`、
   `table_layout.dart`、窗口管理、托盘、快捷键录制）、以及上游已证零调用点的死路由。
3. **本阶段做数据接线**：演示状态要换成真实持久化；确实没有上游后端的，如实标注。
4. **不修改上游**：`Android/` 只读，禁止写入。
5. **每个代码文件 ≤550 行**（AGENTS.md）；超了拆 `library` + `part`。

## 1. 上游规模实测与第二轮交付量

| 目录 | 文件数 | 行数 | 本仓对应（第二轮后） |
|---|---|---|---|
| `lib/ui/` | 90 | 29,421 | `lib/ui/` 127 文件 / 28,301 行（已全量移植，本阶段未改） |
| `lib/views/` | 74 | 约 26,900 | `lib/pages/` 覆盖 |
| `lib/pages/` | 5 | 2,878 | 覆盖（含编辑器 / 扫码 / 错误页） |
| `lib/features/` | 28 | 约 8,000 | `lib/pages/forms/` + 各域表单浮层 |
| **UI 合计** | — | **约 42,800** | **`lib/pages/` 206 文件 / 45,369 行** |

**第二轮交付量（基线 → 现状）**

| 指标 | 第二轮前 | 第二轮后 | 第三轮后（2026-10-20） |
|---|---|---|---|
| `lib/` 总行数 | 约 41,836 | **79,728**（370 文件） | **90,401**（419 文件） |
| `lib/pages/` 行数 | 10,514（43 文件） | **40,004**（187 文件） | **45,369**（206 文件） |
| 路由数 | 18 | **73**（16 基线 + 57 领域 GoRoute） | **85**（`lib/routes/*.dart` 全量） |
| 单文件最大行数 | — | 532（`pages/system/editor_page.dart`） | 550（同上，全部 ≤550） |
| 测试用例 | 8 | 62 | **153**（22 文件，运行期实测） |

结论：**设计系统层 100% 移植；页面层覆盖上游全部可见页面**；第三轮把设置与观测域的
**数据来源**接到旧版持久化（见 §14 台账）。剩余未迁移项只有 §13 列出的桌面专属能力与
主动延后的 `paged_sheet`。


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

## 5. 代理域（Proxies）——已整域删除

上游 `lib/views/proxies/` 8 文件 / 2,660 行在第二轮迁移时落地过（7 文件 / 1,381 行），
第五轮按「旧版不存在的一律移除」**整体删除**：`/proxies`、`/proxies/providers`
两条路由、`lib/pages/proxies/` 全部文件、以及仪表盘上的 `proxy_groups_card` /
`current_outbound_card`。

1.4.3 是 **DNS 应用**，没有 Clash 内核、代理组、配置档案。这些 UI 属另一套产品
语义，不迁移才是对的。若要复活，只能当新功能重新设计，不能从本仓历史里捞。

## 6. 观测域

### 6.1 已有

| 旧版 / 来源 | 本仓 | 状态 |
|---|---|---|
| `dns_log` + `http_request_log` 合并视图（`LogRouteActivity` 的「请求日志」） | `lib/pages/observability/requests_page.dart` | 已迁移（来源 全部/DNS/HTTPS + 六档状态 + 导出 CSV） |
| `AppTrafficStatsScreen` 应用流量统计 | `lib/pages/traffic/traffic_page.dart` | 已迁移（五档时间窗口 + 搜索 + 四档排序 + 隐藏系统应用 + 清除历史） |

### 6.2 资源与连接（旧版无对应界面，用户要求保留）

| 页面 | 状态 | 说明 |
|---|---|---|
| `/connections` 活动连接 | 保留 | 1.4.3 只有请求日志，没有「活动连接」概念；Go 引擎也未导出连接枚举 API |
| `/resources` 资源更新 | 保留 | 1.4.3 的规则来自订阅 + 内置预设资产，没有 geo/icon/rule-provider 远程下载器 |
| `/dns-queries` DNS 查询 | **已删除** | 与 `/requests`（来源选 DNS）读同一张表、同一批状态；旧版只有一页 |

两个保留页在 `/developer` 有入口，页脚标注「不属于旧版 1.4.3 的界面」。

## 7. 配置域（Profiles / 规则 / 订阅）

### 7.1 配置档案——已整域删除

上游 `lib/views/profiles/` 15 文件 / 约 8,600 行（配置网格、添加、编辑、预览、
自定义节点/组/规则/提供者/拨号器/图标、扩展详情）在第二轮迁移时全部落地过，
第五轮**整体删除**：15 条 `/profiles/*` 路由、`lib/pages/profiles/` 全部文件、
`dashboard/profile_detail_page.dart`。

1.4.3 没有「配置档案」这个概念。与它语义最接近的「规则订阅」由 `/subscriptions`
承担（读旧库 4 张订阅表），两者不是同一件事。

### 7.2 规则

| 旧版 | 本仓 | 状态 |
|---|---|---|
| `RuleListScreen`（黑名单 / 白名单 / 覆写三态） | `/rules/{block,allow,rewrite}` | 已迁移（真 `rule_snapshot` 表 + 只读保护 + 批量编辑） |
| 规则来源分组（用户自定义 / 规则订阅 / 内置预设） | `rules_page.dart` 的分组 | 已迁移 |
| 订阅拦截（`SubscriptionDownloader` + 4 张表） | `/subscriptions` | 已迁移（下载正文 + 统计行数，不入规则表） |
| 订阅拦截率统计 | `/logs/subscription-stats` | 第五轮新增 |

### 7.3 订阅

`/subscriptions` 读旧库 `subscription_*` 四张表；无旧库时渲染空状态而非 mock
（`app_shell_test.dart` 守着这条，反证 mock 播种已删除）。规则解析与入库明示
「将在后续版本接入」，不伪造入库结果。
## 8. 设置与外观

> 第五轮把这一节整体重写了。旧版设置页**只渲染六行**，前文按 FlClash 的八个分组
> 登记的设置项大部分已随配置页删除。

### 8.1 设置主页（`/settings`）

旧版 `SettingsScreen.kt` 按 `SettingsSection.entries.sortedBy { order }` 渲染，
每组只保留 `ScreenDestinations.mainEntries` 里的条目（`mainEntries` 只来自
`ScreenDestinations.all` 的六条），**空组直接跳过**。页面标题是
`R.string.other_settings` = 「其他设置」。

| 分组（order） | 行 |
|---|---|
| 运行模式（0） | 运行模式 |
| 性能优化（1） | 缓存设置 / 日志模式 |
| 运行行为（2） | 前后台行为 |
| 外观（3） | **空组，不渲染** |
| 数据管理（4） | 语言设置 |
| 其他设置（5） | 使用向导 |

本仓 `settings_page.dart` 逐行对齐这五组六行。唯一新增的可点元素是顶栏的扳手
图标 → `/developer`（保留页入口，见 §16.4）。

### 8.2 外观子树（`/theme`）

旧版 `AppearanceSettingsScreen` 是三组八项的子页菜单，本仓照此建：

| 组 | 项 | 路由 |
|---|---|---|
| 界面显示 | 日夜模式 | `/theme/day-night` |
| | 主题色配置 | `/theme/color` |
| | 首页透明度 | `/theme/home-opacity` |
| | 底栏自定义 | `/theme/bottom-bar` |
| 首页内容 | 首页句子 | `/theme/home-sentence` |
| | 通知栏设置 | `/theme/notification` |
| 背景与动效 | 软件背景 | `/theme/background` |

保留项（旧版无，用户要求留）内联在 `/theme` 的组里：字体（→ `/font-family`）、
纯黑开关、字号滑杆；「背景与动效」组内另有底栏样式 / Tab 动画 / 液态玻璃三项。

`CustomPrimaryColor` 的自定义取色随 `theme_color_sheet.dart` 一并删除——旧版只有
九套预设。

### 8.3 设置子页

| 路由 | 内容 |
|---|---|
| `/settings/background` 前后台行为 | 后台隐藏 / 绕过局域网 / IPv6 三档 |
| `/settings/language` 语言设置 | 跟随系统 / 简体中文（旧版枚举里的英文无文案资源，不臆造） |
| `/hub/cache` 缓存设置 | 保留 |
| `/hub/log-retention` 日志模式 | 三档日志模式 + 保留天数 1–30 + 悬浮窗 + 崩溃日志 |

## 9. 浮层 / 交互控件 / 动画（跨页面）

`lib/ui/` 已完整提供，本轮**零改动**（`docs/ui-framework/22-parallel-work-contract.md`
的第 1 条约束）。页面侧只用不造：

- 浮层：`showSheet` / `showFloatingDialog` / `CommonPopupBox` / `CommonPopupMenu`；
- 行分隔线：由 `ItemPosition` 驱动（`list_row_separator.dart`），按设备像素比取整到
  真正的发丝线。**不要在 `lib/ui` 之外自造 `Divider(height: 0.5)`**——那会得到 1
  逻辑像素，比其它列表页粗一倍；测速结果列表就是靠改用 `generateSection` 拿到这
  条发丝线的；
- 空状态：`NullStatus` + `NullStatusIllustration`；
- 加载：`CommonCircleLoading` / `ObservabilityLoading`；
- 图表：`line_chart.dart`（仪表盘曲线），环形图用 `CustomPainter` 自绘（不引三方库）。

## 10. 表单与编辑器（features）

上游 `lib/features/` 里的表单件在旧版中对应 `ui/components/`。第五轮的处置：

| 页面 | 状态 |
|---|---|
| `/form/rule-preset`、`/form/list-editor`、`/form/map-edit`、`/form/named-url`、`/form/selection` | 保留（用户点名的「表单演示页」，`/developer` 可达） |
| `/demo` 组件画廊 | 保留（`/developer` 可达） |
| `/form` 表单演示入口 | 保留 |
| `/scan` 扫码页 | 保留（相机预览用占位画布，页脚标注演示） |
| `/editor` 编辑器 | 保留（纯内存，页脚标注演示） |
| `/error` 错误页 | **已删除**（全仓无入口） |

## 11. 路由登记（以代码为准）

> **本表已废弃**。第五轮之前这里维护过一份 60 行的「新增路由登记表」，表格与
> `lib/routes/*.dart` 的实际内容漂移严重（登记的 `proxies` / `profiles` 全族已
> 删除，而新增的 `/theme/*` 六条、`/logs/*` 四条、`/config/*` 三条都没登记）。
> 手工维护两份清单必然漂移，所以改为**以代码为唯一权威**：

| 权威来源 | 内容 |
|---|---|
| `lib/router.dart` | `Routes` 常量（不属任何领域的顶层页）+ `_branchOrder` 六个 branch |
| `lib/routes/routes.dart` | 九个领域文件的 barrel |
| `lib/routes/<domain>_routes.dart` | 各领域的 `Paths` 常量类 + `xxxRoutes()` 路由表 |
| `test/route_catalog_test.dart` | `topLevelRoutes` / `idRoutes` 两张表，逐条 build 验活 |
| `test/layout_regression_test.dart` | 同一份表 × 3 档宽度 × 1.4 倍字号验布局 |

新增页面时**只改三处**：`Paths` 常量、`xxxRoutes()` 里的一条 `GoRoute`、
`route_catalog_test.dart` 的表项。后者漏改的表现是「页面能构建但没有任何测试覆盖
它」——不会报错，只会留个洞。

路由总数：**77 条**（第五轮从 85 条收敛而来，删除项见 §16.1）。

## 12. 复查记录

| 轮次 | 日期 | 范围 | 结论 |
|---|---|---|---|
| R1 | 2026-10-19 | 全量清点 + 台账建立 + 路由骨架 + 首页仪表盘 + 代理 + 配置档案 + 主题 + 观测 | 见 §13 |
| R2 | 2026-10-19 | 五条并行流全量补齐 + 仪表盘重建 + 壳层动画/玻璃接通 + 测试补强 | 见下 |
| R3 | 2026-10-20 | 设置域接回旧版 SharedPreferences + 日志真实数据 + 统计口径 | 见 §12.3 |

### R3 详细结论（2026-10-20）

**范围**：设置域的持久化，不新增页面。

已完成：

- 服务商：18 个 preset + `user_providers_json` 增删改、`selected_provider_id`、三种解析
  模式的 id 列表与主备顺序；删除自定义服务商时同步清洗选中与三份列表。
- 首页 / 解析模式的服务商目录与延迟展示（延迟读 `provider_health_json`，无记录显示「未测速」）。
- 服务显示过滤三键（`home_visible_protocols` / `home_hidden_provider_ids` / `home_visible_provider_ids`）。
- 缓存设置对齐 1.4.3 三档 preset，一次覆写 9 个 `dns_cache_*_v2` 键。
- 拦截响应 `block_response_mode` + 动态策略四键（含 2–100 / 10–300 / 60–3600 夹取）。
- 规则总控四开关（`domain_rules_enabled` / `http3_inspection_enabled` /
  `encrypted_dns_blocking_enabled` / `address_rules_enabled`）。
- 引导解析三键 + `bootstrap_log` 24 小时聚合（替换页面上的假样本）。
- 禁止联网 / 排除应用 / HTTPS 检查应用三份名单与开关，含互斥清洗。
- 应用清单接真实通道 `com.haoze.diting/apps`（`AppsBridge.kt`），四张选择页
  （`/apps`、应用独立规则、HTTPS 检查应用、出站代理应用）共用
  `installedAppsProvider`，不再有 `mockInstalledApps` / `mockPackages`；
  过滤与排序按 1.4.3 的 `AppListFilter` / `AppListSort` 落盘到各自的 `*_filter` /
  `*_sort` 键。原生侧尚未消费 `blocked_app_packages`（见 §14.3）。
- 首页统计条改读 `dnsLogDailyStatsProvider`（原先读 `mockServiceStatsSnapshot` 常量）。
- 日志页补 `LogAction.failed`（`ERROR` 不再显示成「放行」），仪表盘统计改读 `dns_log` 当日聚合。

数据仍未接线的页面：§14.2；原生侧缺失的引擎入参：§14.3。

**验证**：`flutter analyze lib test` 零问题；`flutter test` 153 用例全绿（新增
`provider_catalog_test.dart` 20 条落盘契约、`dns_log_stats_test.dart` 6 条统计口径；
`app_shell_test` 加 1 条首页统计条读真实聚合的回归）。
模拟器（`emulator-5554`）验证通过：设置项改动均能在 `dns_vpn_prefs.xml` 读到对应键值，
启动隧道后 Go 引擎加载成功、系统 DNS 经隧道解析并写入 `dns_log`。

**未覆盖**：arm64 真机（25102RKBEC）本轮未测；剩余演示页面与原生入参见 §14.2 / §14.3。

**R3 复核撤回**：初稿曾把首页统计条与 `/apps` 列入「已接真实持久化」，复核后发现
首页统计条读的是 `mockServiceStatsSnapshot` 常量（已在本轮改为读 `dnsLogDailyStatsProvider`），
`/apps` 的应用列表是 `mockInstalledApps` 常量——应用**名单**已落盘，但可选**应用清单**不是真的。
两者已分别更正为「已接」与「演示」。

### R2 详细结论

**已完成（Lead 主控）**
- 台账 + 并行开发约定（本文件 + [`22-parallel-work-contract.md`](22-parallel-work-contract.md)）。
- 路由按领域拆分：`lib/routes/{dashboard,proxies,observability,profiles,config,system}_routes.dart`
  + `routes.dart` 汇总，`lib/router.dart` 只做拼接。57 条领域路由落地。
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

## 14. 数据来源台账（R3 新增）

> 口径：只要页面渲染的**列表 / 记录 / 统计数字**来自 `lib/data/mock_*.dart` 的常量，
> 就记为「演示数据」；只用到 mock 里的枚举标签、文案或格式化函数（不承载数据）不算。
> 行数、条目数均为 2026-10-20 本会话工具实测。

### 14.1 已接真实持久化（设置与观测域）

| 域 / 页面 | 数据源 |
|---|---|
| 首页服务商卡 + 选择面板 | `provider_catalog_providers`（18 preset + `user_providers_json`），延迟读 `provider_health_json` |
| 首页统计条 + 日志仪表盘四格 | `dnsLogDailyStatsProvider`（当日 `dns_log` 聚合：行数/缓存命中/已拦截/平均延迟） |
| 解析模式页（候选与主备顺序） | `smart_prediction_provider_ids` / `parallel_race_provider_ids` / `primary_backup_provider_ids` |
| 服务商管理页（增删改） | `user_providers_json`，删除时同步清洗选中与三份 id 列表 |
| 服务显示过滤页 | `home_visible_protocols` / `home_hidden_provider_ids` / `home_visible_provider_ids` |
| 缓存设置页 | `dns_cache_preset_v3` + 9 个 `dns_cache_*_v2` |
| 拦截响应页 | `block_response_mode` + 4 个动态拦截键 |
| 规则总控页 | `domain_rules_enabled` / `http3_inspection_enabled` / `encrypted_dns_blocking_enabled` / `address_rules_enabled` |
| 引导解析页 | `bootstrap_enabled` / `bootstrap_preset_ids` / `bootstrap_custom_json` + `bootstrap_log` 24 小时聚合 |
| 禁止联网 / 排除应用 / HTTPS 检查应用 | `blocked_app_packages` / `excluded_app_packages` / `http_inspection_app_packages`（三处互斥清洗） |
| 规则列表（黑/白/覆写）、批量编辑 | 旧版 `diting_database` / `diting_dns_rules` 规则表 |
| 日志仪表盘（三视图） | `dns_log` / `dns_cache` / `dns_race_log` |
| 服务器模式统计 | 原生 `DnsServerStatus.stats`（引擎会话计数，UI 标注为当前会话） |

### 14.2 仍走演示数据（交接时必须如实说明）

| 页面 / 路由 | 依赖的 mock 文件与符号 | 缺口 |
|---|---|---|
| `/traffic` 应用流量 | `mock_data.dart`：`mockTrafficSamples`、`MockAppTraffic` | 需原生 `app_traffic_daily`（`TrafficStatsManager` 按 UID 归因）落库与查询通道 |
| `/connections` 连接列表 | `mock_observability_connections.dart`：`mockConnections`（`_loadDelay` 420ms 假加载） | 需引擎连接事件流（上游 `ConnectionsViewModel`） |
| `/requests` 请求列表 | `mock_observability_connections.dart`：`MockRequest`（380ms 假加载） | 需 `http_request_log` 读写 |
| `/dns-queries` DNS 查询 | `mock_observability_dns.dart`：`MockDnsQuery` | 可改为读 `dns_log`（与日志页同表），成本最低的一项 |
| `/resources` 资源更新 | `mock_observability_resources.dart`：`mockObsResources` | 更新动作只改内存时间戳/体积 |
| `/apps` 应用选择页 | **已接**：`com.haoze.diting/apps` 通道（`AppsBridge.kt`）+ `excluded_app_packages`；本页即「排除应用」编辑器 | 语义见交付报告：1.4.3 无独立通用选择页 |
| `/subscriptions` 订阅 | `subscription_providers.dart` 以 `mockSubscriptions` 播种，更新是 `Future.delayed` 假进度 | 需订阅表读取 + 下载/更新任务（`SubscriptionAutoUpdateScheduler`） |
| `/hub/app-rules` 应用独立规则 | 应用清单已接 `com.haoze.diting/apps`、放行域名读写 `app_allowlist_rules_json`；**DNS 专属黑白名单与「默认拦截全部外联」仍为说明位** | 后两项存在 `block_rule`/`allow_rule` 的 `appScope` 列上，`RuleRepository` 尚无按应用读写接口 |
| `/tools` 网络工具 | `mockServiceStats.averageLatencyMs`、`.uptimeLabel` | 四个面板的查询结果需原生诊断通道（上游 `NetworkToolsViewModel`） |
| `/hub` 功能中心、`/hub/hidden-features` | `mock_feature_hub.dart` 的静态卡片清单；隐藏开关为内存态 | 属文案清单而非业务数据；隐藏开关需要落盘 |
| 代理域（`/proxies`、`/profiles/*`） | `mock_proxies.dart`、`mock_profiles*.dart` | 上游是 Clash 内核语义，本仓仅 UI；接真实内核前保持演示 |
| `/config/*` 覆写与策略页 | `mock_config_*.dart` | 引擎的 TUN/DNS/嗅探覆写未接线 |

> 这些页面的 UI 迁移状态仍为「已迁移」——迁移的是**界面**。交付说明里必须成对写：
> 「UI 已迁移、数据仍为演示」，不得只写一半。接线顺序建议：`/dns-queries`（同表）→
> `/connections` + `/requests`（同库）→ `/apps`（需新增原生通道）→ `/traffic`（需新表）→ 其余。

### 14.3 原生侧尚未接线的引擎入参

静态调用链结论（2026-10-20 复核，Kotlin 全库 grep）：

| 键 | Dart 写盘 | Kotlin 读 | 进入 Go | 结论 |
|---|---|---|---|---|
| `blocked_app_packages`（+`blocked_apps_enabled`） | ✅ `legacy_settings.dart` | ❌ `blocked_app_packages` / `blockedApp` / `setBlockedUIDs` 全库零命中 | ❌ | **只写盘未读**：UI 勾选能保存，引擎完全收不到；`VpnStartRequest` 里也没有这个字段 |
| `excluded_app_packages` | ✅ | ✅ → `VpnRouteConfig` / `ExpressRouteConfig` 的 `addDisallowedApplication` | ⚠️ 仅 TUN 层 | **已接 TUN 路由，引擎侧白名单仍空**：`rule_snapshot.dart` 的 `appRules` 恒为 `{}`，`setAppAllowlist` 零调用 |
| 出站代理 | ❌ 只有内存 `OutboundProxyState` | ✅ `VpnBridge`/`ExpressVpnBridge` 读 `outboundProxy` | ⚠️ 恒为空 | **读了但恒为空**：Dart `_launch()` 组装 `VpnStartRequest` 时未传该字段，Kotlin 回落到 `DEFAULT_OUTBOUND_PROXY`（`enabled:false`） |
| `http_inspection_app_packages`（+ 开关） | ✅ | ❌ | ❌ | 只在 Dart UI 消费 |
| `https_inspection_ready` | ✅ 已有 getter | — | — | CA 证书页未读该键（只读内存 provider） |

接线位置：`DitingVpnService` / `ExpressVpnService` 组装引擎配置处，两条服务都要改；
`blocked_app_packages` 还需要先在原生侧补 package→UID 解析（`getPackageUid`），
上游 1.4.3 走的是 `GoInspectionTunnel.setBlockedUIDs(csv)`。

## 15. 无 1.4.3 后端的页面（2026-10-20 第四轮核查）

> 判定方法：对每个功能关键词在 `Android/app/src/main/java/com/haoze/diting/`
> 全库 `.kt` 做 `Select-String -SimpleMatch`，命中数为 0 且没有等价实现，即判「无后端」。
> 这些页面是照着「不存在的 Flutter 上游」搭出来的脚手架（见文件头的口径更正），
> **不是迁移欠账**。后续要么按 Kotlin 版重写对照、要么明确删掉，不能继续当「待接线」挂着。

| 页面 / 路由 | 核查关键词（命中数） | 结论与建议 |
|---|---|---|
| `/connections` 连接列表 | `ConnectionsViewModel`(0)、`TrackerInfo`(0)、`activeConnections`(0)、`ConnectionTracker`(0) | 1.4.3 只有**请求日志**（`dns_log` + `http_request_log`），没有「活动连接」概念。Go 引擎也未导出连接枚举 API（`tunnel-debug-sources.jar` 的 `Engine` 无相关方法）。**建议**：与 `/requests` 合并，或改为「当前会话」视图；不要虚构连接表 |
| `/resources` 资源更新 | `geoip`(0)、`geosite`(0)、`RuleProvider`(0) | 1.4.3 的规则来自订阅（`SubscriptionDownloader`）+ 内置预设资产，没有 geo/icon/rule-provider 远程下载器。**建议**：删页面，或改为「内置预设资产版本」只读信息页 |
| 代理域 `/proxies`、`/profiles/*` | `ProxiesScreen`(0)、`ProxyGroup`(0)、`Clash`(0)、`proxy_group`(0) | 1.4.3 是 **DNS 应用**，没有 Clash 内核、代理组、配置档案。这些 UI 属另一套产品语义。**建议**：整域标为「非本产品功能」，不要接假数据 |
| `/config/{tun,sniffer,ntp,override,filters,rules,scripts,providers,icon-sets,user-agents,on-demand}` | `sniffer`/`Sniff`(0)、`tun_stack`(0)、`ntp_server`(0)、`override`(0)、`clash`(0)、`on_demand`(0)、`user_agent`(0)、`icon_set`(0) | 1.4.3 的「配置覆写」只有 `bypass_lan_enabled`、`ipv6_mode`、`dns_*` 等真实键（见 `legacy_settings.dart`），并无 TUN 栈/嗅探/NTP/脚本覆写。**建议**：删掉无后端的 11 个页面，保留与真实 prefs 键对应的部分 |

**仍然真实可接的（本轮接线目标）**：流量（`app_traffic_daily`）、请求
（`http_request_log`）、DNS 查询（`dns_log`）、应用清单
（`PackageManager` + `QUERY_ALL_PACKAGES`）、订阅（4 张订阅表）、应用独立规则
（`app_allowlist_rules_json`）、出站代理（`outbound_proxy_*` 9 键 + AndroidKeyStore）、
HTTPS/CA（`GoInspectionCaManager` + `AndroidCAStore`）、网络工具
（`NetworkPingTool` / `NetworkTraceRouteTool` / `DnsLatencyTester` / `NetworkInfoProbe`）、
功能中心隐藏项（`hidden_features_set`）。

## 16. 第五轮收口：按旧版界面集合重定范围（2026-10-21）

> 本轮的约束换了方向：不再是「把 Flutter 侧能做的都做出来」，而是**旧版存在的
> 界面必须保留、旧版不存在的一律移除**，同时 `lib/ui` 设计体系零改动。
> 完整判定表见 `docs/refactor/15-legacy-parity-audit.md`。这里只登记对本节
> 前文结论的**修订**，避免旧结论继续误导后续判断。

### 16.1 第五节「无 1.4.3 后端」结论的最终处置

| 页面 | 前文建议 | 本轮最终处置 | 理由 |
|---|---|---|---|
| `/connections` 活动连接 | 与 `/requests` 合并或改「当前会话」 | **保留**，`/developer` 可达 | 用户在保留清单里明确点名要留；页脚标注不属于旧版界面 |
| `/resources` 资源更新 | 删页面或改只读信息页 | **保留**，`/developer` 可达 | 同上 |
| 代理域、配置档案 | 整域标为非本产品功能 | **已删除**（`/proxies`、`/proxies/providers`、`/profiles/*` 共 15 条路由） | 旧版无此概念 |
| `/config/*` 11 个内核配置页 | 删掉无后端的 11 个页面 | **已删除**（general/network/tun/dns/ntp/sniffer/override/filters/rules/scripts/providers/advanced） | 旧版无内核配置 |
| `/config/{icon-sets,user-agents,on-demand}` | 保留与真实 prefs 键对应的部分 | **保留**，收敛到 `/config/custom-resources` 三行 | 用户点名保留 |
| `/dns-queries` DNS 查询 | —— | **已删除** | 与 `/requests`（来源选 DNS）同表同状态，旧版只有一页 |
| `/apps`、`/agent`、`/error`、`/theme/preview`、`/access`、`/backup`、`/disclaimer`、`/dashboard/profile` | —— | **已删除** | 旧版无对应界面 / 改为首启弹窗 |

路由总数从 85 条收敛到 77 条。

### 16.2 本轮补齐的旧版界面（此前缺失）

| 旧版界面 | 新路由 | 说明 |
|---|---|---|
| 五档日志模式仪表盘 | `/logs` | 顶部三选自 `dns_log_mode`，三套块组合（8/4/6 块） |
| 缓存表 / 竞速统计 / Bootstrap 统计 / 订阅拦截率 | `/logs/{cache,race,bootstrap,subscription-stats}` | 四个下钻页，全部读真实旧库表 |
| 前后台行为设置 | `/settings/background` | 后台隐藏 / 绕过局域网 / IPv6 三档 |
| 语言设置 | `/settings/language` | 跟随系统 / 简体中文 |
| 外观三组八项 | `/theme/*` 六条子页 | 日夜模式 / 主题色 / 首页透明度 / 底栏 / 首页句子 / 通知栏 / 软件背景 |
| 网络诊断四 Tab | `/tools` | 测速 / Ping / DNS 解析 / 路由追踪，默认停 Ping（旧版初值） |
| 服务器模式三 Tab | `/server` | 概览 / 上游服务器 / 模式设置 |
| 首启「使用须知与免责声明」 | —— | 应用层弹窗（`lib/app/initial_agreement.dart`），非路由 |
| 关于页核心能力/运行边界 | `/about` | 极速模式按旧版规则减两条能力 |

### 16.3 本轮补回的原生能力

| 通道 | 方法 | 补回前状态 |
|---|---|---|
| `com.haoze.diting/dns_latency` | `probe` | **整个测速功能丢失**（旧版 `DnsSpeedTestSection` + `DnsLatencyTester`） |
| `com.haoze.diting/platform` | `applyRecentsPrivacy` / `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations` / `crashLogCount` / `clearCrashLogs` / `exportText` | 后台隐藏完全没有；崩溃日志是写死的 `_crashLogCount = 3` |
| `com.haoze.diting/dns_server` | `clearCache` | 引擎 `engine.clearDNSCache()` 未接出，页面只能显示「尚未接入」 |
| `com.haoze.diting/diagnostics` | `lookupDns` 增加 `server` 参数 | 「自定义 DNS 服务器」模式丢失，只能问系统解析器 |
| 通知栏四键 | —— | `notification_settings_prefs` 的 `persistent`/`speed`/自定义文案未接 |

### 16.4 保留项（旧版无界面，用户要求保留）

18 项全部保留并给出可达入口。入口自造的只有一处：**设置页顶栏的扳手图标**
（→ `/developer`），因为设置列表必须严格等于旧版的五组六行。
`retained_pages_reachable_test.dart` 守这条，防止下一轮被当孤儿删掉。

