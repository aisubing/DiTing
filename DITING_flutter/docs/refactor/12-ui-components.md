---
所属系列: DITING Android Flutter 重构功能图谱 | 章: 12 | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测
---

# 12. 可复用 UI 组件体系与视觉主题（上）：组件目录 + Cascade 体系

源码根：`Android/app/src/main/java/com/haoze/diting/`（下文相对路径均以此为根，行号实测于 v1.4.3 工作区）。

## 12.0 概述：组件库规模实测

- 本域精读文件 **55 个、7818 行**（逐文件 `wc -l` 实测）：`ui/components/` 6 文件 + `cascade/` 4 文件 + `cascade/internal/` 6 文件、`ui/component/liquid/` 6 文件、`ui/theme/` 11 文件（AppTheme/AppTypography/M3ColorPalette + 8 个 PresetPalette）、`ui/agent/` 6 文件、ui 根 13 文件（AppThemeMode/AppThemeSurface/CoBuilderListScreen/DataResetNoticeCard/RememberDebouncedValue/ContextUiExtensions/PowerToggleButton/SponsorListScreen/SponsorScreen/RecognitionAvatarLoader/RecognitionAvatarRepository/RecognitionListContent/RecognitionMembersRepository）、`localization/DynamicPatternLocalization.kt` 1 文件、首页句子/可见性 2 文件。
- 顶层 `@Composable` 函数 **60 个 public**（awk 逐行统计 `@Composable` 后紧跟顶层 `fun`）；另有 internal/private 顶层 Composable **16 个**（agent 包 8：SheetComponents 6 internal + AgentAnalysisSheetContent + buildMarkdownAnnotatedString；components 包 1 private RuleStatItem；cascade 包 3：private CascadeDropdownMenuContent + internal AnimateEntryExit/PositionPopupContent；ui 根 4：internal PowerToggleButton/DataResetNoticeCard + private SponsorList/RecognitionListItem；CascadeColumnScope 的 3 个成员 Composable 不计入顶层）。设计令牌 object/val 约 25 个。
- 主题预设实测为 **8 套 PresetPalette 文件、16 个 M3ColorPalette 对象**（light+dark），`ThemeColorStyle` 枚举 **9 项**（SYSTEM + 8 预设，SYSTEM 复用 PURPLE 板）——任务书「10 预设」与工作区不符，按实测记录。
- 消费点口径：`被 N 屏使用` = `grep -rlw <名>`（剔除定义文件自身）所得**文件数**；`调用点` = `grep -rn "<名>("` 剔除定义行后的行数。两者都给出时以文件数为主。

## 12.1 组件目录

### A. 对话框家族（ui/components/AppAlertDialog.kt，160 行，3 个 Composable）

| 名称 | 文件:行 | 用途 | 参数 | 交互行为 | 动画/参数 | 使用面（实测） |
|---|---|---|---|---|---|---|
| `AppAlertDialog` | AppAlertDialog.kt:27-101 | M3 AlertDialog 包装：正文可滚动 + 中性按钮三键布局 | `neutralButton/icon/title/text/shape/containerColor/tonalElevation/properties/scrollable=true` | `scrollable=true` 时正文套 `verticalScroll`；传 neutral 时按钮重排为「中性居左、取消+确认居右（间隔 8.dp）」 | **高度上限 = 屏高×0.8**（:46 `screenHeightDp * 0.8f`），其余全部 M3 默认 | 28 文件 / 调用点 34 |
| `AppDialogButton` | :104-123 | 对话框文字按钮，destructive 标红 | `label/onClick/destructive/enabled` | `TextButton`，`destructive=true`→contentColor=`colorScheme.error` | 无自定义动画 | 27 文件 / 调用点 65 |
| `AppConfirmDialog` | :126-159 | 标题+正文+取消/确认统一确认框 | `title/confirmLabel/onConfirm/message/cancelLabel="取消"/destructive/confirmEnabled/icon` | 正文 bodyMedium+onSurfaceVariant | — | 16 文件 / 调用点 19 |

### B. 设置页家族（ui/components/SettingsComponents.kt，579 行，17 个 public Composable）

BLUKE 风格「inset 分组卡片」体系（源码注释 :126-127、:152-153、:206-207 自述）。设计令牌（实测字面量）：

- `SettingsCornerShape = RoundedCornerShape(12.dp)`（:129）——全应用按钮/输入框圆角，51 文件引用。
- `SettingsCardMargin = 16.dp`（:138）、`SettingsSectionSpacing = 12.dp`（:131）、`SettingsItemSpacing = 2.dp`（:132）、默认行内边距 `PaddingValues(horizontal=24.dp, vertical=16.dp)`（:130）。
- 分组卡片**可变圆角拼接**：`SettingsSurfaceItem`（:181-204）首项上下圆角 28.dp、中间项 4.dp、末项 28.dp（:188-189），实现 iOS 设置式「切片粘连」外观；容器色默认 `surfaceVariant.copy(alpha = 0.5f)`（:185）。

| 名称 | 文件:行 | 用途 | 关键参数/行为 | 使用面 |
|---|---|---|---|---|
| `SettingsScaffold` | :54-124（双 overload） | 全设置子页骨架：TopAppBar+返回+actions+belowTopBar | 字符串版转发 Composable 版；`showBackIcon` 可关返回；topBar 滚动时不换色（scrolledContainerColor=containerColor） | 70 文件 / 调用点 77 |
| `SettingsSurfaceGroup` | :155-178 | 卡片组容器（`List<@Composable () -> Unit>` 驱动） | 空 content 直接 return；组内 spacedBy(2.dp) | 61 文件 / 调用点 141（最重的组件） |
| `SettingsNavigationGroup`+`SettingsNavigationItemData` | :210-234 / :140-149 | 数据驱动的导航行组 | 无副标题且无图标时垂直内边距 12.dp，否则 20.dp（:226-229）；`valueMaxScreenFraction` 限宽（coerceIn 0.1f..1f） | 10 文件 / 调用点 13 |
| `SettingsItem` | :331-389 | 基本行：min 高度 44.dp、leading icon tint=primary、disabled 文字 alpha 0.38f | onClick 可空（纯展示行）；title/subtitle 均过 `localizedText` | 23 文件 / 调用点 49 |
| `SettingsSwitchItem` | :394-418 | 整行点击翻转 Switch | 行点击调 `onCheckedChange(!checked)` | 27 文件 / 调用点 34 |
| `SettingsCheckboxItem` | :423-449 | 整行点击翻转 Checkbox | 同上 | 8 文件 / 调用点 28 |
| `SettingsNavigationItem` | :454-506 | 值+右箭头导航行 | disabled 时箭头隐藏；value 右对齐 bodyMedium | 6 文件 / 调用点 16 |
| `SettingsTextItem` | :511-536 | 动作行（可破坏性） | textColor 透传 titleColor | 7 文件 / 调用点 38 |
| `SettingsRadioItem` | :541-567 | 单选行：选中显示 CheckCircle（未选中右侧留空） | disabled tint=onSurface 0.38f | 11 文件 / 调用点 25 |
| `SettingsActionButton`/`SettingsOutlinedActionButton` | :239-274 | 主/次按钮（shape=SettingsCornerShape） | — | 各 6 文件 / 调用点 6、8 |
| `SettingsGroupTitle` | :279-292 | 组标题（titleSmall、onSurfaceVariant，padding start/top 24/24、bottom 8） | — | 50 文件 / 调用点 129 |
| `SettingsInfoText` | :297-310 | 组尾说明（bodySmall） | — | 46 文件 / 调用点 63 |
| `SettingsLoadingContent` | :315-325 | 居中 CircularProgressIndicator 占位 | — | 6 文件 / 调用点 6 |
| `SettingsDivider` | :572-579 | 兼容旧调用：2.dp Spacer 代替分割线 | 注释自述「replaces in-group dividers with spacing」 | 7 文件 / 调用点 8 |

### C. 规则列表家族（ui/components/RuleListSharedComponents.kt，515 行，11 个 Composable）

黑白名单/改写/应用规则等「规则管理屏」共用（文件头注释 :57-60）。

| 名称 | 文件:行 | 用途 | 参数/行为 | 动画/参数 | 使用面 |
|---|---|---|---|---|---|
| `RuleSearchField` | :63-85 | 圆角搜索框 | `OutlinedTextField` singleLine、leading Search、有值时 trailing Close 清空 | **shape=RoundedCornerShape(28.dp)**（胶囊，:83） | 7 文件 / 调用点 7 |
| `RuleFilterChipRow<T>` | :88-108 | LazyRow 筛选 FilterChip | spacedBy 8.dp、contentPadding vertical 2.dp；`labelKeyOf` 走 localizedText | — | 7 文件 / 调用点 8 |
| `RuleListCountHeader` | :111-130 | 「规则列表 / 共 N 条」头 | padding 8/8/8/4 | — | 3 文件（Blacklist/RewriteList/Whitelist 各 1 调用点） |
| `RuleListEmptyState` | :133-152 | 空态卡（SettingsSurfaceGroup 内 32.dp padding 居中文字） | `groupContentPadding=PaddingValues.Zero` | — | 5 文件 / 调用点 5 |
| `BoxScope.RuleListPaginationBar` | :159-275 | 底部悬浮分页胶囊：上一页/`当前/总页` TextButton/下一页；点中间弹「跳转到页面」输入框（digit-only、Number 键盘、IME Done、1..totalPages 校验，错误走 supportingText） | `alwaysShow=false` 时仅 totalPages>1 显示（:171）；须放 BoxScope，`align(BottomCenter)` | 胶囊 **RoundedCornerShape(28.dp)、tonalElevation 2.dp、shadowElevation 4.dp**、色 surfaceContainerHigh（:180-183） | 4 文件 / 调用点 4 |
| `RuleStatsCard`（+private `RuleStatItem`） | :277-363 | 规则统计卡：图标+标题+启用徽标+分隔+统计项 | 徽标 primaryContainer 12.dp 圆角；统计数字 titleMedium Bold primary，标签 bodySmall.copy(fontSize=11.sp)（:359） | Card surfaceVariant 0.5 alpha | 3 文件 / 调用点 3 |
| `RuleTagChip` | :366-390 | 规则行小标签（来源/类型/重要/通配） | 全可定制 `containerColor/contentColor/maxLines/overflow/shape`；默认 **RoundedCornerShape(4.dp)**、padding 4/1、labelSmall | — | 7 文件 / **调用点 30** |
| `RuleConfirmDialog` | :396-416 | 破坏性确认（默认 destructive=true） | 确认后先 onConfirm 再 onDismiss（注释 :392-394 保留原调用点顺序） | — | 5 文件 / 调用点 10 |
| `RuleItemActionsMenu` | :419-460 | 行内「更多操作」：MoreVert→CascadeDropdownMenu(编辑/删除-红) | enabled=false 时点击走 `onDisabledClick`、图标 alpha 0.4f（:432-433） | **fixedWidth = 160.dp**（:440） | 3 文件 / 调用点 3 |
| `masterDisabledMessage(context, isDomainType)` | :463-478 | 总开关关闭时的引导文案决策链（CA→检查开关→目标应用→URL 规则开关） | 纯函数，非 Composable | — | 3 文件 |
| `DomainRulesLinkageKind` + `DomainRulesInspectionLinkageDialog` | :480-515 | 域名规则↔HTTPS 检查强制联动的确认框 | ENABLE_BOTH 非破坏 / DISABLE_BOTH destructive | — | 2 文件 / 调用点 2 |

### D. 网络诊断家族（ui/components/NetworkToolComponents.kt，305 行，7 个 Composable）

文件头注释（:41-44）自述「仅被网络诊断 section 使用，与全局设置组件样式解耦」。消费者固定为 `ui/PingSection.kt`、`ui/DnsLookupSection.kt`、`ui/TracerouteSection.kt`、`ui/DnsSpeedTestSection.kt` 四文件。

| 名称 | 文件:行 | 用途/参数 | 实测样式 | 使用面 |
|---|---|---|---|---|
| `NetworkToolSegmentedRow` | :50-71 | `SingleChoiceSegmentedButtonRow` 单选分段（ping 次数/记录类型/DNS 模式） | label maxLines=1 | 4 文件 / 调用点 5 |
| `NetworkToolRunButton` | :77-101 | 运行按钮：running 时禁用并内嵌进度圈+换文案 | **CircularProgressIndicator 16.dp、strokeWidth 2.dp、onPrimary**；shape=SettingsCornerShape | 4 文件 / 调用点 4 |
| `NetworkToolStat`（data）+ `NetworkToolStatBand` | :106-110 / :116-159 | min/avg/max 等指标横带 | Surface **RoundedCornerShape(12.dp)、surfaceContainerHigh**、垂直 padding 12.dp、值 titleMedium、标签 labelMedium、`VerticalDivider height 24.dp thickness 1.dp outlineVariant`；valueColor null→onSurface | 1 文件（PingSection）/ 调用点 1 |
| `NetworkToolResultHeader` | :165-207 | 成功/失败图标标题 | CheckCircle/ErrorOutline 20.dp，成功 primary、失败 error | 3 文件 / 调用点 3 |
| `NetworkToolSectionLabel` | :213-223 | 子区标签 | labelLarge onSurfaceVariant | 4 文件 / 调用点 8 |
| `NetworkToolInfoRow` | :229-253 | 左标签右值（值 Monospace） | spacedBy 12.dp；value 默认 onSurface | 3 文件 / 调用点 5 |
| `NetworkToolCopyValueRow` | :259-288 | 整行点击复制 + trailing 复制图标 | Monospace、ContentCopy 16.dp、整行 clickable(onCopy) | 1 文件（DnsLookupSection）/ 调用点 1 |
| `formatMsValue` / `formatLossPercent`（internal） | :290-305 | 时长/丢包格式化：≥100ms 取整、否则 1 位小数；整数丢包不带小数 | — | Ping/Traceroute |

### E. DNS 服务商管理家族（ui/components/ProviderManagementComponents.kt，357 行，5 个 Composable）

泛型 `<P>`（协议枚举）+ `<T>`（服务商条目）以同时服务 NORMAL 与 SERVER 两套数据模型。

| 名称 | 文件:行 | 用途 | 行为/参数 | 使用面 |
|---|---|---|---|---|
| `ProtocolToggleRow<T>` | :37-64 | DNS/DoH/DoT 三档 FilterChip（weight(1f) 均分，间隔 8.dp） | 仅在本文件内被 E 族其余组件复用（:182、:302）——**外部消费者 0**（`grep -rlw` 剔除定义文件后为空） | 文件内调用点 2 |
| `ProviderListItem` | :67-113 | 服务商行：选中 CheckCircle + 可选编辑/删除 IconButton | 自定义条目，无外部消费者（同上口径） | 文件内调用点 2 |
| `AddressErrorText` | :116-137 | 错误行：ErrorOutline **14.dp** + bodySmall error；默认文案「当前的地址并不符合要求」 | 无外部消费者 | 文件内调用点 2 |
| `ProviderEditDialog<P>` | :140-262 | 编辑弹窗（AppAlertDialog 内嵌表单）：名称/协议切换/URL 或 host+port | 协议切换时非 URL 协议自动回填 `defaultPortForProtocol`（:187-189）；端口输入 digit-only（:236）；地址非法时点「保存」先亮 `AddressErrorText`（:252-254），合法才可提交；所有字段 IME=Next、shape=SettingsCornerShape | 2 文件（server/ui/DnsServersScreen.kt:67,100、ui/ProviderManagementScreen.kt:99,131）/ 调用点 4 |
| `ProviderManagementListContent<T,P>` | :265-357 | LazyColumn 内容区：当前生效提示→协议行→内置组→自定义组 | 内置组只读、自定义组带编辑/删除；spacedBy(12.dp)；空组走 SettingsInfoText 文案（默认文案 :284） | 2 文件（DnsServersScreen.kt:41、ProviderManagementScreen.kt:72）/ 调用点 2 |

### F. 徽标与杂项（ui 根）

| 名称 | 文件:行 | 用途 | 实测参数 | 使用面 |
|---|---|---|---|---|
| `DnsProtocolBadge` | components/DnsProtocolBadge.kt:14-31 | 协议小徽标 | **RoundedCornerShape(6.dp)、secondaryContainer、labelSmall、padding 8/2**；文字 `protocol.label.uppercase(Locale.US)`——DOH 标签渲染为「DOH」（枚举 label 实测为 "DNS"/"DoH"/"DoT"，DnsProvider.kt:13-16） | 5 文件 / 调用点 5 |
| `PowerToggleButton` (internal) | PowerToggleButton.kt:28-156 | 首页主电源钮 | 4 组 `animateColorAsState` + 3 组 `animateDpAsState` 全部 **tween(250)**：glow 128/108.dp（primary .28f / outline .12f）、halo 148/124.dp（primary .12f / 透明）、按钮 92/84.dp（primary↔surface 换色互换 content）；外框 156.dp；busy 时 42.dp CircularProgressIndicator(strokeWidth 4.dp)；disabled 整钮 alpha 0.5f；触觉：运行中点=REJECT（API30-用 KEYBOARD_TAP）、停止点=CONFIRM | 3 调用点：ExpressHomeContent.kt、normal/MainScreenContent.kt、server/DnsHomeScreen.kt |
| `DataResetNoticeCard` (internal) | DataResetNoticeCard.kt:20-73 | 「配置与规则库已更新」提示卡 | Card **surfaceVariant .9f**、SettingsCornerShape、💡18.sp、正文 bodySmall onSurfaceVariant .85f、「知道了」TextButton | 2 调用点：ExpressHomeContent.kt、MainScreenContent.kt |
| `rememberDebouncedValue` | RememberDebouncedValue.kt:13-20 | 搜索防抖 | `delayMillis` 默认 **250ms**（LaunchedEffect(value) 简单尾随延迟，非 leading 节流） | 1 调用点：normal/ui/AppRuleManagementScreen.kt:134 |
| `Context.showToast` / `Context.copyToClipboard` | ContextUiExtensions.kt:9-16 | Toast 自动 localizedText / 剪贴板封装 | duration 默认 LENGTH_SHORT | 39 文件 / 9 文件（grep 剔除定义文件） |

## 12.2 Cascade 体系专节（ui/components/cascade/，10 文件，4+6 结构，合计 1014 行实测 `wc -l`）

**它是什么**：谛听自研的「级联下拉菜单」——不是级联选择器（无省市区语义），而是 **带导航回退栈的 Popup 菜单**：顶层 `CascadeDropdownMenu` 锚定触发点弹出；scope 内 `DropdownMenuItem(children=…)` 点击后整张菜单面板**水平滑动替换**为子菜单（iOS/macOS 式 drill-down），子菜单头部 `DropdownMenuHeader` 返回上一级。文件头注释（CascadeDropdownMenu.kt:53-58）自述三点能力：精准锚点定位、基于触发点的缩放揭开动画、无缝级联过渡。

### 对外 API（公开层 4 文件）

1. **`CascadeDropdownMenu`**（CascadeDropdownMenu.kt:59-134）
   `expanded: Boolean, onDismissRequest, modifier, offset: DpOffset = Zero, fixedWidth: Dp? = 200.dp, shadowElevation = 4.dp, tonalElevation = 4.dp, properties = PopupProperties(focusable = true), state = rememberCascadeState(), shape = RoundedCornerShape(12.dp), content: @Composable CascadeColumnScope.() -> Unit`
   - 用 `MutableTransitionState` 让退场动画播完才真正卸载（:73-76）。
   - 锚点 = **调用处父布局坐标**（:90-97 `parentLayoutCoordinates ?: coordinates`），包一层零尺寸 Box 测位。
   - 外层 `Popup(usePlatformDefaultWidth=false, FixedPopupPositionProvider(IntOffset.Zero))` 铺满全屏，菜单本体在 popup 内部再**手工定位**（:99-131）——与 M3 DropdownMenu 的实现路线完全不同，见 internal 层。
2. **`CascadeDefaults`**（CascadeDefaults.kt:12-28）：menuWidth **200.dp**、minWidth **196.dp**、shadowElevation **4.dp**、tonalElevation **4.dp**、shape **12.dp**（注释 :25「遵循谛听规范的 12.dp 圆角」）。
3. **`CascadeState` / `rememberCascadeState`**（CascadeState.kt:9-64）：`mutableStateListOf<CascadeBackStackEntry>` 回退栈；`navigateBack()/canNavigateBack()/resetBackStack()` 公开，`navigateTo` 内部（重复 entry 不入栈 :39-41）；`BackStackSnapshot(topMostEntry, backStackSize)` 驱动 AnimatedContent。菜单销毁时 `DisposableEffect` 重置栈（CascadeDropdownMenu.kt:145-149）。
4. **`CascadeColumnScope`**（CascadeColumnScope.kt:36-168）——interface 暴露 3 属性（`cascadeState/hasParentMenu/isNavigationRunning`）+ 3 个作用域 Composable：
   - `DropdownMenuItem(text, children, childrenHeader=默认用父项文本, …)`：级联项。trailing 箭头 `KeyboardArrowRight` **offset 出右缘**：`iconOffset = contentPadding 末端内边距 − 4.dp`（:74-79，视觉贴边）。
   - `DropdownMenuItem(text, onClick, …)`：直通 M3 DropdownMenuItem。
   - `DropdownMenuHeader(modifier, contentPadding = PaddingValues(10.5.dp), text)`（:125-167）：可点返回（`isNavigationRunning` 时吞点击防重入 :133-136）；样式 = LocalContentColor alpha **0.6f**、labelLarge 的 **fontSize×0.9 + letterSpacing×0.9**（:141-146）、返回箭头 16.dp；仅 `hasParentMenu` 时画箭头。

内容渲染（CascadeDropdownMenu.kt:136-201）：`Surface(requiredWidth(fixedWidth) 或 widthIn(min=196.dp), color=surface, tonalElevation=4.dp)` + `AnimatedContent(label="cascadeAnimation")`；**导航中阻塞新导航**：`snapshotFlow{backStack}.onEach{ isTransitionRunning.first{ !it } }`（:163-169）与 `LaunchedEffect(transition.isRunning){ tryEmit }`（:196-198）构成互锁；`isNavigationRunning` 透传给 scope 供 header 吞点击。

### internal 层 6 文件

| 文件 | 职责 | 关键实测参数 |
|---|---|---|
| AnimateEntryExit.kt（172 行） | 展开/收起的缩放+揭开（reveal-clip）+阴影 | 进出场 duration 均 **300ms**（:37-38 tween），reveal 额外 ×1.2=360ms 进 / ×0.8=240ms 出（:66），reveal 值域 **0.25→1**（:69）；scale 0→1；`createRevealingRect`：pivotY>0.5 从底边向顶展开、否则从顶向下（:103-114）；阴影层与内容层分离，阴影走 `clipDifference`（drawWithCache + ClipOp.Difference，:144-161），shadow(clip=false, ambient/spot=Black×alpha)（:125-131） |
| CascadeTransitionSpec.kt（33 行） | 级联滑动切换 | duration **350ms**；前进：新层从 +width 滑入、旧层滑向 −width/4；后退镜像；RTL 用 `inverseMultiplier=-1`；`targetContentZIndex=backStackSize`、SizeTransform 同步 350ms（:16-32） |
| DropdownMenuPositionProvider.kt（95 行） | 锚点定位 + 翻转 | 复刻 M3 内部逻辑：x 候选 `toRight→toLeft→贴屏边`，y 候选 `toBottom→toTop→toCenter→贴底`（:33-60）；`MenuVerticalMargin=48.dp`（:70）；`calculateTransformOrigin` 用锚点与菜单交叠中心算缩放原点（:72-95） |
| PositionPopupContent.kt（86 行） | 在全屏 Popup 内容里手工摆放菜单 | 内容 alpha 先 0，测得位置后才显示（:72）；API29+ 且 `excludeFromSystemGesture` 时设置 `systemGestureExclusionRects`（:41-49） |
| ScreenRelativeBounds.kt（83 行） | 跨 window（锚点 Activity window ↔ Popup window）坐标换算 | root 坐标 + `windowBoundsMinusIme`（减去 IME insets，:51-62）——为「弹层与输入法共存」设计，比 M3 原生 popup 多了 IME 感知 |
| CascadeInternalUtils.kt（84 行） | 小工具 | `CoercePositiveValues`（负坐标钳 0 + `correctMenuBounds` 平移修正 :17-47）、`FixedPopupPositionProvider`、`PopupProperties.copy(usePlatformDefaultWidth=…)`（补 SDK copy 缺参）、`clickableWithoutRipple`、`thenIf` |

### 消费点实测（双向 grep）

`CascadeDropdownMenu(` 调用点 **8**，分布 7 个消费文件：`express/ui/ExpressRequestLogScreen.kt:167`、`normal/ui/RequestLogScreen.kt:174`、`ui/BlacklistScreen.kt:130`、`ui/WhitelistScreen.kt:110`、`ui/RewriteListScreen.kt:105`、`ui/traffic/TrafficFilterBar.kt:74`、`ui/InstalledAppPickerComponents.kt:109`，另加组件库内 `RuleItemActionsMenu`（RuleListSharedComponents.kt:437）。**真正用到级联（children=）的只有 4 处**：两份 RequestLog 屏的「状态筛选」（ExpressRequestLogScreen.kt:201 / RequestLogScreen.kt:208）与 InstalledAppPickerComponents.kt:140/165（过滤应用、排序方式）；其余 4 屏只当普通菜单用（换取揭开动画与定位）。`DropdownMenuHeader` 显式调用点 4（均作 childrenHeader 覆写）。`fixedWidth` 覆写仅 2 处：160.dp（RuleItemActionsMenu）、200.dp（InstalledAppPickerComponents.kt:112）。`rememberCascadeState` **外部调用点 0**——state 全部走默认参数。

Flutter 等价物要点：单 Popup + 内部 AnimatedSwitcher(水平 slide 350ms) + 自维护回退栈；缩放原点按锚点交叠计算、reveal 用 ClipRect 动画（`clipPath Difference` 阴影层在 Flutter 可用两层 Stack+CustomClipper 近似）。
