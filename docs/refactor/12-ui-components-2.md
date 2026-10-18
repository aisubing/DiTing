---
所属系列: DITING Android Flutter 重构功能图谱 | 章: 12 | 最后校验: 2026-10-18 | 口径: 本域文件全部点名；数字均为本会话工具实测；本篇为 12-ui-components.md 的同编号续篇（§12.3–12.8）
---

# 12. 可复用 UI 组件体系与视觉主题（下）：Liquid / 主题令牌 / Markdown / 赞助墙

前篇：`12-ui-components.md`（§12.0 规模实测、§12.1 组件目录、§12.2 Cascade 体系）。本篇续 §12.3–12.8。

## 12.3 Liquid 液态玻璃组件专节（ui/component/liquid/，6 文件 895 行实测合计）

**唯一消费者是 `ui/FloatingNavigationBar.kt`**（悬浮底部导航条，屏级实现归第 03 章）：实测该文件 import 本包 9 个符号（InnerShadow/innerShadow/IosIndicatorSpecular/drawSpecularHighlight/rememberGravityRotatedHighlight/rememberDeviceTilt/DampedDragAnimation/InteractiveHighlight/rememberLiquidNavHaptics）；其余对外数据类型（SpecularHighlight/BloomStroke/LightSource/LightPosition/DeviceTilt）`grep -rlw` 剔除 liquid 包与导航条后命中数为 0——仅包内互用（DeviceTilt 仅再被 LiquidSpecularHighlight.kt 引用）。**包名 `component`（单数）与 `components`（复数）是两个不同目录**——重构时勿合并。

**实现技术总述**：全体系**不用 RenderEffect/高斯模糊背景**。「玻璃感」= 半透明纯色 + 内阴影 + 镜面描边 + 触摸光斑。整个包内 **RuntimeShader/AGSL 仅 1 处**（LiquidInteractiveHighlight.kt:44-57，API 33+ 门槛，API<33 走径向渐变回退）——Flutter 迁移成本集中在这一点。`isGlassActive = isGlassEnabled && !isInDark`（FloatingNavigationBar.kt:120-121，按 `surface.luminance()<0.5f` 判暗色）——**深色模式直接不启用玻璃**。

| 文件:行 | 对外 API | 实现 | 关键参数（字面量实测） |
|---|---|---|---|
| LiquidInnerShadow.kt:29-156 | `data class InnerShadow(radius=24.dp, offset=DpOffset(0.dp, radius), color=Black α0.15, alpha=1f, blendMode=Default)`；`Modifier.innerShadow(shape, shadow: () -> InnerShadow?)`；`InnerShadow.Default` | 自绘 `ModifierNodeElement`+`DrawModifierNode`（:48-152）：`GraphicsLayer(CompositingStrategy.Offscreen)` 上画「形状填充 → 平移 offset 后用 `BlendMode.Clear` 再画形状挖掉」，`BlurEffect(radius,radius,TileMode.Decal)` 做柔和，最后 clipPath(shape) 内 drawLayer | radius==0 时 `renderEffect=null`（:116 免模糊）；`prevRadius` 缓存避免每帧重建（:115-118）；`shouldAutoInvalidate=false`（:87）手动失效。消费点：FloatingNavigationBar.kt:424-429 `InnerShadow(8.dp × max(pressProgress,0.4f), Black α0.18)`——按下时内阴影半径随按压进度放大 |
| LiquidSpecularHighlight.kt:25-163 | `LightPosition(x,y,z)`、`LightSource(position, color=White, intensity=1f)`、`BloomStroke(color=White α0.12, innerBlurRadius=2.0.dp, primaryLight=LP(.5,-.3,-.05), secondaryLight=LP(.5,.8,-.5) α0.4, dualPeak=true)`、`SpecularHighlight(width=1.dp, alpha=1f, style=BloomStroke())`、常量 `IosIndicatorSpecular`（:50-68）；`Modifier.drawSpecularHighlight(shape, highlight, alpha=1f)`（:119-163）；`rememberGravityRotatedHighlight(base, extraDegrees=0f, tiltState=null)`（:82-117） | **无 shader**：沿 outline 描一条 `Stroke(widthPx)` 的 `BlendMode.Plus` 线性渐变——4 个停靠点 α 系数 **0.55 / 0.12 / 0.05 / 0.35**（:148-151，主光/次光各两峰，`dualPeak=false` 时次光强度置 0）；渐变起止点按主光位置 ×0.8 摆动（:138-144） | `rememberGravityRotatedHighlight`：主光位置 = 参考点 (0.5, 0.7)（`LIGHT_REF_X/Y` :70-71）+ 归一化重力方向旋转 extraDegrees（阈值 `GRAVITY_DIR_THRESHOLD_SQ=0.01f`，:72/95-100）。消费：导航条底板 extraDegrees=**-45°**、滑块 **90°**，共享同一 tiltState（FloatingNavigationBar.kt:220-222）；绘制 α 底板 **0.85**、滑块 **0.90**（:248-250、:419-422） |
| LiquidDeviceTilt.kt:18-105 | `data class DeviceTilt(gx=0, gy=-1, gz=0)`；`rememberDeviceTilt(enabled=true): State<DeviceTilt>` | `Sensor.TYPE_GRAVITY`（缺失回退 `TYPE_ACCELEROMETER`），`SENSOR_DELAY_UI`；读数除以 GRAVITY_EARTH，x 取反 | **死区阈值 `TILT_UPDATE_THRESHOLD_SQ = 1e-5f`**（:28），低于则不触发 recomposition；KDoc（:35-43）声明的成本约束：仅在 `enabled && 生命周期≥RESUMED` 注册，ON_PAUSE 注销、ON_RESUME 重注册；DisposableEffect 键控 (enabled, lifecycleOwner) 防重复注册。消费：`enabled = isGlassActive`（FloatingNavigationBar.kt:220） |
| DampedDragAnimation.kt:33-231 | `class DampedDragAnimation(animationScope, initialValue, valueRange, visibilityThreshold=0.001f, initialScale=1f, pressedScale=78f/56f, canDrag, onDragStarted/onDragStopped/onDrag)`；暴露 `value/targetValue/isRunning/pressProgress/scaleX/scaleY/velocity/modifier`；方法 `press()/release()/snapToValue()/updateValue()/animateToValue()/pulseRebound()`；`inspectDragGestures(...)`（:177-231，自研 awaitEachGesture 拖拽核） | **KernelSU/SyncTouch 移植**（文件头注释 :29-32）。6 个 spring spec（:45-50）：value `spring(1f,1000f)`、tab 切换 `spring(0.9f,600f)`、velocity `spring(0.5f,300f,阈值×10)`、pressProgress `spring(1f,1000f)`、scaleX `spring(0.6f,250f)`、scaleY `spring(0.7f,250f)`；5 个 Animatable + `MutatorMutex` 互斥 + `VelocityTracker` 归一化速度（:167-173）。`pulseRebound()` 果冻回弹（:153-164）：pressProgress→0.6 `spring(1f,1200f)`、scaleX ×1.08 / scaleY ×0.92 `spring(0.5f,500f)`、**delay(40L)** 后回弹。`release()` 先 `awaitFrame()`，若 value≠target 则等差值 < **range×0.025f** 再收（:109-111） | 消费：滑块初值=当前页、`valueRange=0f..(tabs-1)`、`pressedScale=78/56`（≈1.3929，FloatingNavigationBar.kt:169-176）；`DampedDragAnimation` 在导航条外**零消费者** |
| LiquidInteractiveHighlight.kt:27-149 | `class InteractiveHighlight(animationScope, position=(size,offset)->offset)`；`press(down)/updatePosition/release(target?)/cancel()`；`modifier`（绘制）、`gestureModifier`（手势） | 触摸光斑：整面 `White α=0.06×progress` Plus 叠加 + 光点半径 `minDimension×1.35` 的柔光；**API 33+**：AGSL `RuntimeShader`（smoothstep(radius, radius*0.4, dist)×color，`ShaderBrush` 绘制，:42-57/:104-113）；**API<33 回退**：`Brush.radialGradient(White α0.18×progress→Transparent)` 画圆（:115-128）；`runCatching` 编译 shader，失败也走回退。press/release 动画均 `spring(0.5f,300f)`（:31-32）；progress≤0.001 时完全跳过绘制（:92） | 消费：光点 x 钳进宽度、y 锁 `size.height/2`（FloatingNavigationBar.kt:208-213） |
| LiquidNavHaptics.kt:21-91 | `class LiquidNavHaptics(view, enabled)`；`onDragSlideTick()/onDragBoundaryBump()/onTabSwitchClick()/onActiveTabRebound(scope)`；`rememberLiquidNavHaptics(enabled = AppearanceSettingsStore.isBottomBarHapticEnabled(ctx))` | 常量映射（全带 `FLAG_IGNORE_VIEW_SETTING`）：滑过档位=**SEGMENT_TICK(27)**，API<34 回退 CLOCK_TICK；撞橡皮筋边界=REJECT（API<30 回退 CLOCK_TICK）；切页=CONFIRM（API<30 回退 KEYBOARD_TAP）；重复点当前页=CONFIRM+**delay(40L)**+CLOCK_TICK 双脉冲（:73-80，与 pulseRebound 的 40ms 对齐） | 用户开关存 AppearanceSettingsStore（设置屏归第 03 章） |

降级路径总结：AGSL→径向渐变（API33）；SEGMENT_TICK→CLOCK_TICK（API34）；REJECT/CONFIRM→CLOCK_TICK/KEYBOARD_TAP（API30）；TYPE_GRAVITY→TYPE_ACCELEROMETER；整套玻璃→深色模式直接不渲染（isGlassActive=false）。

## 12.4 主题与设计令牌

### 12.4.1 色板体系（ui/theme/，11 文件 907 行实测合计）

`M3ColorPalette.kt`（131 行）：`data class M3ColorPalette` 含 **36 个角色字段**（primary…surfaceTint，M3 全套；:13-50，实测 `grep -c "val .*: Color"` = 36），`toColorScheme(darkTheme)`（:52-131）逐字段灌入 `lightColorScheme/darkColorScheme`。每个 Preset*Palette.kt 各 86 行 = `XXX_LIGHT` + `XXX_DARK` 两个完整板；文件头注释自述「由 Google 官方 material-color-utilities 从种子色按 **Tonal Spot** 方案生成」——**代码中不含种子色十六进制**，只有生成后的角色值（8 文件 grep「种子」仅命中注释行）。下表 primary 即生成板 40 号色调近似值；「用途」列为 `ThemeColorStyle` displayName（AppTheme.kt:24-32）：

| 预设（storageValue） | 中文名 | LIGHT primary | DARK primary | LIGHT background/surface | DARK background/surface | LIGHT surfaceContainerHigh | DARK surfaceContainerHigh |
|---|---|---|---|---|---|---|---|
| system | 跟随系统 | （复用紫板 #65558F；API31+ 走动态取色） | （#CFBDFE） | #FDF7FF | #141218 | — | — |
| purple | 鸢尾紫 | **#65558F** | **#CFBDFE** | #FDF7FF | #141218 | #ECE6EE | #2B292F |
| blue | 睡莲蓝 | #36618E | #A0CAFD | #F8F9FF | #111418 | #E6E8EE | #272A2F |
| cyan | 池水青 | #006A64 | #81D5CD | #F4FBF9 | #0E1514 | #E3E9E8 | #252B2A |
| green | 柳叶绿 | #4C662B | #B2D189 | #F9FAEF | #12140E | #E8E9DE | #282B24 |
| orange | 暮光赭 | #8F4C37 | #FFB59F | #FFF8F6 | #1A110F | #F7E4E0 | #322825 |
| red | 罂粟红 | #904A42 | #FFB4AA | #FFF8F7 | #1A1110 | #F7E4E1 | #322826 |
| pink | 暮霞粉 | #8C4A60 | #FFB0C8 | #FFF8F8 | #191113 | #F5E4E7 | #31282A |
| indigo（枚举名 GOLD） | 麦穗金 | #79590C | #EBC16C | #FFF8F2 | #17130B | #F1E7D9 | #2E2921 |

（值均取自各 Preset*Palette.kt:11/:50 primary、:27-29/:66-68 background/surface、:44/:83 surfaceContainerHigh。）注意枚举项 `GOLD("indigo", "麦穗金", GOLD_LIGHT, GOLD_DARK)`（AppTheme.kt:32）——storageValue 写成 "indigo" 是历史遗留（无金色枚举值），持久化兼容须保留。error 全板统一 #BA1A1A(light)/#FFB4AB(dark)（M3 标准红，8 板 grep 实测仅此两值）。**「种子色」为待定项：仓内只存生成后的角色色值，种子十六进制不在任何源码/注释中**——Flutter 若改用 `ColorScheme.fromSeed` 动态生成，需自行为每板反推种子（或维持静态 16 板平移）。

**动态取色启用条件**（AppTheme.kt:61-65）：`colorStyle == SYSTEM && Build.VERSION.SDK_INT >= S(31)` → `dynamicLight/DarkColorScheme(context)`；其余（含 API<31 的 SYSTEM）回落紫板。`swatchColor`（:44-51）在设置色样页对 SYSTEM+API31+ 显示**真实壁纸动态 primary**，其余显示静态板 primary——色样选择器归 12.4.4。

### 12.4.2 Typography（AppTypography.kt，16 行）

**只覆写一个角色**：`bodyLarge = FontFamily.Default / Normal / fontSize 16.sp / lineHeight 24.sp / letterSpacing 0.5.sp`（:9-16），其余全部 M3 默认。所谓「字号表」在本应用实际不存在定制——Flutter 侧等价：`Typography.material2021` 仅改 bodyLarge。正文实际大量使用的字号散落在组件里（如 11.sp 徽标/统计标签，RuleListSharedComponents.kt:359、AgentAnalysisSheetComponents.kt:251）。

### 12.4.3 主题入口与深浅色切换

- `DITINGTheme(darkTheme, colorStyle, transparentBackground, content)`（AppTheme.kt:54-72）：选板→`MaterialTheme(colorScheme, typography=Typography)`；`transparentBackground=true` 时仅把 `background` 替换为 `Color.Transparent`（:68）。
- `AppThemeMode`（AppThemeMode.kt:3-15）：SYSTEM/LIGHT/DARK 三值枚举，storageValue+displayName（跟随系统/浅色模式/深色模式），`fromStorageValue` 非法值回退 SYSTEM。
- `AppThemeSurface(themeMode, colorStyle, backgroundEnabled, backgroundUri, …)`（AppThemeSurface.kt:27-105，**主题+自定义背景的唯一宿主容器**）：darkTheme 三态判定（:70-74）；自定义背景三级加载（内存位图直出→同步 ensureLoaded→LaunchedEffect 异步，:42-68，管理器 `CustomBackgroundManager` 归第 03/06 章）；位图 `ContentScale.Crop` 满铺 + **黑色遮罩 alpha：亮色 0.16 / 深色 0.34**（:94-98），同时把主题 background 置透明防遮挡。消费者：MainActivity、LogRouteActivity、ModeOnboardingActivity、SettingsRouteActivity、WorkModeActivity（5 个 Activity 入口，grep 实测）。
- 窗口底色（XML 层，与 Compose 主题并行）：`values/colors.xml` `diting_window_background=#FFFFFBFE`、`values-night/colors.xml` `#FF1C1B1F`；`Theme.DITING` 仅设 windowBackground（light parent=Material.Light.NoActionBar / night parent=Material.NoActionBar）。桌面启动闪屏色。
- **v31 自适应图标动态取色**（自绘图标清单外补充）：`values-v31/colors.xml` 把 `ic_launcher_foreground` 指到 `@android:color/system_neutral2_700`、背景 `system_accent1_100`；`values-night-v31` 反转（accent1_100 前景/neutral1_800 背景）——Android 12+ 图标随壁纸变色。

### 12.4.4 形状/间距/动效约定（实测汇总）

- 形状：**12.dp**（SettingsCornerShape，按钮/输入框/多数卡片；Cascade 菜单同款）、**28.dp**（胶囊：搜索框、分页条；SurfaceGroup 首末项；AgentAnalysisSheet 顶角）、**16.dp**（Agent 卡）、**10–12.dp**（统计带/表格卡）、**6.dp**（协议徽标/表头）、**4–8.dp**（标签/Chip 小件）、**CircleShape**（电源钮/头像/导航胶囊）。
- 间距：卡片左右 16.dp、行内 24/16.dp、组间 12.dp、组内 2.dp、统计行 spacedBy 8/12.dp。
- 动效约定：**tween(250)** 用于状态换色/换尺寸（PowerToggleButton 全 7 组、FloatingNavigationBar 面板偏移）；**tween(220)** 文字位移 + **fadeIn(160ms, delay 220ms)** 头像浮现（RecognitionListContent.kt:80-96）；Cascade 300/350ms；liquid 全 spring。无 infinite 常驻动画（对本机 GPU 友好，对照 AGENT_MISTAKES 2026-10-16 教训）。
- 色样选择屏 `ThemeColorSettingsScreen.kt:34-90`：9 项列表、28.dp 圆点 swatch、选中白色 CheckCircle 18.dp；改动即 `WorkModeLifecycleRegistry.refreshFloatingLogOverlay` 同步悬浮日志（归 03 章）。

## 12.5 Markdown 渲染能力清单（ui/agent/）

**渲染链**：`parseMarkdownBlocks(rawText)`（MarkdownBlock.kt:36，行级分块，8 种块，:6-15 sealed）→ `MarkdownViewer`（MarkdownViewer.kt:49-322 逐块渲染）→ 块内联经 `buildMarkdownAnnotatedString`（MarkdownInlineAnnotator.kt:33-51，正则在 :25-27，**单层、不支持嵌套强调**）。

| 语法 | 支持 | parser 证据 | 渲染证据 |
|---|---|---|---|
| ATX 标题 #~###### | ✔ | HEADING_REGEX MarkdownBlock.kt:18 | H1 titleLarge、H2 titleMedium+**3.5×18.dp primary 竖条**（MarkdownViewer.kt:70-80）、H3 titleSmall、H4-6 bodyLarge；≤3 级 primary 色（:90） |
| setext 标题 / ===== | ✘ | 无正则 | — |
| 粗体 **/__ | ✔ | INLINE 正则 :26；`**`≥4 判定 :85-92 | Bold；**粗体内含风险词自动染色**（resolveBadgeColor :88） |
| 斜体 *text*/_text_ | ✔（`_` 带 Unicode 边界守卫：前后非字母数字下标才成对，防 `dns_vpn_prefs` 误斜体——单测 MarkdownInlineAnnotatorUnderscoreTest.kt:34-99 锁定） | 正则 :26 尾部 lookbehind 组 | Italic :132-138 |
| 粗斜体 ***/***/___ | ✔ | :76-82 | Bold+Italic |
| 删除线 ~~text~~ | ✔ | :95-100 | LineThrough |
| 行内码 `code` | ✔ | :103-115 | Monospace+背景 surfaceContainerHighest+primary 文字，**前后各加一空格**（:113） |
| 链接 [label](url) | **视觉有、功能无**：仅着色下划线，url 丢弃、不可点击 | :118-129（groupValues[2]=label） | Flutter 重构须补 tap recognizer |
| 围栏代码 ```/~~~+语言 | ✔（未闭合容错） | :53-65 | Card 12.dp：语言标（空→"CODE" 大写 primary）、**复制按钮**（copyToClipboard+Toast，:175-189）、Monospace 12.sp/18.sp、横向滚动 |
| 引用块 > 多行 | ✔ | :85-93 | 左 **4.dp primary 竖条**+斜体 bodyMedium、21.sp 行高、10.dp 右侧圆角（:211-241） |
| 无序列表 - * +，缩进 2 空格/级 | ✔ | :19-20、indent=空格/2 限 0..4（:116-118） | 5.dp primary 圆点 + 缩进 `indent*14+4`.dp（:104-127） |
| 有序列表 1. 2.（序号原样保留） | ✔ | :20、:125-131 | 加粗 primary 数字（:129-151） |
| 表格 \|a\|b\| + 分隔行 `:?-+:?` | ✔（**对齐冒号解析但不生效**） | isTableStart :23-31、:96-111 | 表头 primaryContainer .5 底 + 斑马纹行 + 每格 **widthIn(min=90.dp)** 横向滚动（:250-318）；不支持列内换行 |
| 分隔线 ---/***/___ (≥3) | ✔ | HR_REGEX :17 | HorizontalDivider outlineVariant .5（:243-248） |
| 图片 ![]() / HTML / 任务列表 / 嵌套列表多行续行 | ✘ | 无 | — |
| 【高危】【安全】等 AI 决策徽标 | ✔（谛听定制） | 正则尾部 11 词白名单 :26 | 着色加粗：高危/屏蔽规则→error、中风险→**#FFE65100**、低风险→**#FFF57F17**、安全/白名单→**#FF2E7D32**、正常放行→**#FF1976D2**、旁路直连→tertiary（MarkdownInlineAnnotator.kt:164-179） |

### AgentAnalysisSheet（ModalBottomSheet，agent/AgentAnalysisSheet.kt:56-88）

`sheetState=rememberModalBottomSheetState(skipPartiallyExpanded=true)`；**顶角 28.dp、containerColor=surfaceContainerLow、tonalElevation=6.dp、内容列 heightIn(max=680.dp)**（:71-78、:216）。消费点 4 屏：ExpressLogDashboard、ModernLogDashboard、RequestLog、DnsCache（另 AgentApiSettingsScreen 仅用 AnalysisTarget 类型）。参数 `target: AnalysisTarget?`（null 直接不渲染）、`dataset: RuleDataset`——注释（:100-108）记录历史缺陷修复：按 dataset 选库 `RuleDatabases.forDataset/runtimeForDataset`，HTTP 日志 DAO 仅 NORMAL 非空。

**交互流程**（状态机，Content :90-364）：`LaunchedEffect(target)` 重读配置→apiKey 空→`AgentApiKeyMissingCard`（Settings 图标 44.dp、「前往配置」Button，SheetComponents.kt:46-93）；`!enabled`→`AgentApiDisabledCard` 一键开启并立即分析（:95-138）；进行中→`AgentAnalysisLoadingView`（**CPI 44.dp strokeWidth 3.dp** + 模型名，:140-169）；失败→`AgentAnalysisErrorCard`（errorContainer 卡、「检查设置」OutlinedButton+红色「重试」Button，:171-230）；成功→`AgentAnalysisResultContent`（:232-306）：**LazyColumn：SuggestionChip「模型: x」11.sp + 「消耗 N Tokens」（totalTokens>0 才显示）→ MarkdownViewer 卡（surfaceContainerHighest .6）→ appliedActionText 反馈卡**。底栏 `AgentAnalysisBottomBar`（:308-378，仅 Domain 目标显示前两键）：加入白名单（FilledTonal+Shield）/加入屏蔽规则（error Button+Close）/复制结果/重新分析。白/黑名单写入走 `AllowListManager/BlockListManager(scope=RuleScope.DNS).addRule` + `RuntimeDnsSettingsRefresher.syncRuleIfRunning` 热更新，成功/失败写 appliedActionText（Sheet.kt:325-358）。Domain 上下文采集：`dns_log LIKE %domain% LIMIT 5`、流量摘要 `dns LIMIT 40 + http LIMIT 30` 拼统计文本（:136-186）——API 调用层 `AgentApiClient` 归第 06 章。

## 12.6 赞助墙与云控名单（实测）

**数据链**：GitHub 仓库根 `recognition_members.json`（工作区现值 `version:1`：sponsors **15** 人、coBuilders **11** 人、合计 26 条记录、去重后 19 个不同昵称、7 人同时上榜；2 名赞助者无头像字段走缺省图）→ `RecognitionMembersRepository`（ui/RecognitionMembersRepository.kt）ETag 增量拉取 → 原子缓存 → `RecognitionList` 渲染 → 头像名再经 `RecognitionAvatarRepository` 从 `avatars/` 子目录懒下载。`docs/development/recognition-members.md` 为该云控机制的官方维护文档。

- **URL（字面量）**：配置 `https://raw.githubusercontent.com/haoze-evolluling/DITING/main/recognition_members.json`（:23-24）；头像基址 `…/DITING/main/avatars/`（RecognitionAvatarRepository.kt:22-23）。OkHttp connect 15s / read 30s（两库一致 :30-33）。
- **schema**（parseConfiguration :73-83）：根须有非空 `version`；`sponsors`/`coBuilders` 数组，成员 `{name: 必填非空且组内唯一, avatarFileName?: 须匹配 `[a-z0-9_]+_avatar\.jpg`（:29，组内唯一）}`；sponsors 的 acknowledgement 固定「感谢您对谛听项目的赞助支持」、coBuilders 固定「感谢为谛听提出建议与帮助测试」（:77-78 硬编码）。缺省头像名→客户端 `R.drawable.default_avatar`。
- **缓存**：`filesDir/recognition_members.json`，`AtomicFile` 整写（:109-119）；响应体上限 **256KB** 流式截断即弃（:28、:121-133）；304→返回 null 表示「未变」；ETag 存 SharedPreferences `recognition_members/etag`（:25-27、:60）。
- **头像仓库**：目录 `filesDir/recognition_avatars/`；单文件上限 **1MB**、先写 `.<name>.download` 临时文件、`isValidImage`（BitmapFactory inJustDecodeBounds 探测）后 `AtomicFile` 替换、finally 删临时（:100-137）；全局 `downloadMutex` + 双检缓存；**解码缓存 `ConcurrentHashMap<path@size@targetPx, ImageBitmap>`** 进程级驻留（:40-43）；`decodeScaled` 后台线程按 2 的幂 `inSampleSize` 降采样 + **RGB_565**（:67-84）——显示尺寸固定 48.dp（RecognitionListContent.kt:74）。
- **Loader**（RecognitionAvatarLoader.kt）：per-成员名状态机 Loading/Available/Failed（Repository:26-30），init 先填本地缓存判定；`loadMissing()` 并发 async 补差集、`retryMissingOrFailed()→AvatarRefreshResult(refreshed, failed)`；`isRefreshing` 供按钮禁用（:24-26）。
- **UI 组件 `RecognitionList`**（RecognitionListContent.kt:40-66，消费点 SponsorListScreen.kt:117 + CoBuilderListScreen.kt:103 共 2 处）：卡片组行——48.dp 圆裁头像 + 名称(bodyLarge Medium)/致谢语(bodySmall)；**动画**：文字起始位 0→60.dp `tween(220)`、头像 fadeIn **160ms 延迟 220ms** / fadeOut 100ms（:80-96）——无头像时文字左移补位。
- **SponsorListScreen**（125 行）：进页先 loadCached 秒开、随后 refresh 静默更新，失败 Toast「名单更新失败：…」；顶栏两钮——Refresh（304 时改走 retryMissingOrFailed，三态 Toast 文案 :78-82；刷新中 CircularProgressIndicator padding 10.dp）与 SwapVert 倒序开关（`asReversed()`，Toast 播报当前序）；isConfigurationLoading 时 LinearProgressIndicator。
- **CoBuilderListScreen**（111 行）：同骨架少 SwapVert 钮（共建者榜强制字母序/pinyin，说明文案 :97）。归属核对：03/06 章均未认领组件视角。
- **SponsorScreen**（171 行，赞助引导页）：无网络，静态文案 + 外链 `https://github.com/haoze-evolluling/DITING#sponsorship`（:31，ACTION_VIEW，runCatching 失败 Toast「无法打开链接」）；「你的每一笔支持都会用于」三条 / 「即使不捐赠，也欢迎」四条（:106-131）；private `SponsorList` bullet 组件（:144-171）。文案「请作者喝杯蜜雪 🧋」（:63）。

## 12.7 其余未分配 UI 文件与资源清单

- **ui/localization/DynamicPatternLocalization.kt**（218 行）：`internal fun translateDynamicPattern(text): String?`——**单一大 when**（~150 个模式分支）的后缀/前缀/内嵌片段替换引擎，处理「数字+单位」「A · B · C」拼接串与用户自定义句子模板等**静态字典覆盖不到的动态文案**；由 `LocalizationEngine.translatePatterns` 作字典未命中后的最后兜底（LocalizationEngine.kt:98-108）。与 HomeSentenceSettingsScreen 的关系（渲染侧）：首页句子是**用户自由文本**，无法预登记字典，运行时以 `text.startsWith(用户句子)` 等动态模式回译（DynamicPatternLocalization.kt:100 处理「两项内容均可留空…」提示句）；句子编辑屏 HomeSentenceSettingsScreen.kt（85 行）仅用标准件：SettingsScaffold+两 OutlinedTextField(minLines=2, SettingsCornerShape)+SettingsActionButton 存 AppearanceSettingsStore、留空即隐藏（:47-82）。HomeProviderVisibility.kt（25 行）：`data class(visibleProtocols 默认 MANAGED_PROTOCOLS, hiddenProviderIds, visibleProviderIds) + isVisible/isDefault`——**纯模型无 UI**（可见性屏归 03 章、持久化归 06 章；消费者实测 MainViewModel/ResolutionSettingsStore/ProviderConfigImporter/HomeProviderVisibilityScreen 4 处）。
- **res/values 自定义**：**无 dimens*.xml**（全仓 find 0 结果）——间距全走 Compose 字面量（见 12.1/12.4.4）。colors.xml 4 色：`diting_window_background #FFFFFBFE`（night #FF1C1B1F）、`ic_launcher_foreground #FF5CB67B`（谛听绿，v31 被动态色覆盖）、`ic_launcher_background #FFFFFFFF`、`splash_card_stroke #1F000000`（night #25FFFFFF）。themes.xml 仅 `Theme.DITING`（windowBackground）。
- **res/drawable 自绘图标 10 件**（ls 实测；未读二进制 path 内容）：`dns_svgrepo_com.xml`（通知小图标+磁贴，消费者 8 处：RuleOperationWorker:526/537、RuleUpdateNotifier:45、SubscriptionAutoUpdateScheduler:269、DnsModeService:333、DitingTileService:191、AppUpdateNotifier:32/48）、`ic_notification.xml`（VPN 三系通知：ExpressNotificationBuilder:85、VpnNotificationBuilder:78、VpnMonitorService:141）、`ic_overlay_{close,minimize,resize}.xml`（悬浮日志窗按钮，FloatingLogViewFactory.kt:84/92/100）、`ic_play_arrow.xml`（VpnMonitorService:145 action）、`ic_launcher_foreground.xml`+`ic_launcher_monochrome.xml`（108dp 自适应图标）、`ic_splash_squircle_logo.xml`（144dp 方圆形 logo；全仓唯一 Kotlin 消费者 WorkModeComponents.kt:50 工作模式选择页，strokeColor=splash_card_stroke，**未在 Manifest/主题中作系统启动图**）、`default_avatar.webp`（头像缺省图，RecognitionListContent.kt:100）。mipmap 仅 anydpi-v26 两枚 adaptive-icon。
- 未认领文件核对：CoBuilderListScreen/SponsorScreen/SponsorListScreen/PowerToggleButton/DataResetNoticeCard/RememberDebouncedValue/ContextUiExtensions 均无 03 章认领迹象，按组件视角由本章收录。

## 12.8 Flutter 重构注意（只列确证项）

1. **组件映射**：SettingsSurfaceGroup+可变圆角切片 → SliverToBoxAdapter+自绘 ` BoxDecoration( BorderRadius.vertical(...))`（首末 28/中间 4 的拼接规则须原样保留）；SettingsItem 族 → `ListTile` 定制（minHeight 44、disabled alpha 0.38）；AppAlertDialog 的 0.8 屏高+滚动正文 → `AlertDialog`+`ConstrainedBox(maxHeight: 0.8*MediaQuery)`；CascadeDropdownMenu → 自定义 `OverlayEntry`+水平 PageRoute 式切换（参数：宽 200/最小 196、圆角 12、阴影/色调 4、进出场 300ms、级联 350ms、reveal 0.25→1）；RuleListPaginationBar → 底部居中胶囊（28 圆角、elev 2/4）。
2. **Liquid → Flutter**：InnerShadow 无原生等价物 → `ShaderMask`+高斯或两 CustomClipper Stack；specular 描边 → `ShaderMask` linearGradient（α .55/.12/.05/.35、Plus 混合用 `BlendMode.plus`/colorLayer）+重力方向旋转（`sensor_events` 插件取 TYPE_ACCELEROMETER，1e-5 死区与 0.85/0.90 系数照抄）；**InteractiveHighlight 的 AGSL→`FragmentProgram`（ShaderCompiler .frag，API<33 无 runtimeEffect 时保留径向渐变回退）**；DampedDragAnimation 全 6 组 spring（damping 1.0/0.9/0.5 + stiffness 1000/600/300/250）可近似 `SpringSimulation`，但 pulseRebound 的「先压 0.6/1.08/0.92、40ms 后释放」时序须显式编排；`pressedScale=78/56` 与滑块 64.dp 条高来自消费方约定，勿改。
3. **主题**：8 板×2 侧共 16 个 `ColorScheme` 直接平移（hex 见 12.4.1 表）；Monet 用 `DynamicColor`/`seedColor` 等价（条件同为 SDK≥31+system）；**GOLD 枚举 storageValue="indigo" 是持久化契约**，改名会破配置迁移（PreferenceConfigImporter 消费）。Typography 仅 bodyLarge 定制一处。深浅切换 = AppThemeSurface（背景遮罩 α 0.16/0.34 语义保留）。
4. **Markdown**：能力子集（12.5 表）可用 `flutter_markdown` 起步，但必须补：`~~` 删除线、**下划线斜体的 Unicode 边界守卫**（有单测背书，MarkdownInlineAnnotatorUnderscoreTest 5 用例）、【风险徽标】11 词白名单+六色映射（error/#E65100/#F57F17/#2E7D32/#1976D2/tertiary）、链接可点击化（现版只着色）、表格 min 90dp 横向滚动。`***` 粗斜体与嵌套均不支持——勿在 Flutter 里擅自增强导致文案回退不一致。
5. **赞助墙**：ETag/304/256KB 上限/原子写/1MB 头像上限/RGB_565 降采样/进程级 decodeCache 全部可平移（`shared_preferences`+`path_provider`）；avatarFileName 正则白名单是安全边界（防路径注入），Flutter 侧必须保留；头像 fade-in 160ms/delay 220ms+文字 60dp 位移是既有观感契约。
6. **动效常量速查**：250（电源/色变）、220+160/220（头像）、300/360/240/350（Cascade）、40（果冻/触觉双脉冲）、300ms spring(0.5,300)（光斑/位置）、0.025f（release 收敛带）、28/12/6/4.dp 圆角族、16/24/12/2.dp 间距族。

## 关键源码引证表（本篇新增，路径:行均本会话 Read/Grep 实测）

| 主张 | 锚点 |
|---|---|
| AGSL 仅一处、API33 门槛+回退 | ui/component/liquid/LiquidInteractiveHighlight.kt:42-57,104-128 |
| 玻璃仅浅色模式 | ui/FloatingNavigationBar.kt:120-121 |
| 重力死区 1e-5 / 阈值 0.01 | ui/component/liquid/LiquidDeviceTilt.kt:28、LiquidSpecularHighlight.kt:72 |
| spring 全参数 | ui/component/liquid/DampedDragAnimation.kt:45-50,153-164 |
| 触觉常量映射 | ui/component/liquid/LiquidNavHaptics.kt:25-42,73-80 |
| 9 枚举 8 板、GOLD="indigo"、Monet≥S | ui/theme/AppTheme.kt:24-32,44-65 |
| Typography 单角色 | ui/theme/AppTypography.kt:9-16 |
| 背景遮罩 0.16/0.34 | ui/AppThemeSurface.kt:94-98 |
| v31 动态图标色 | res/values-v31/colors.xml、values-night-v31/colors.xml |
| 名单 URL/256KB/ETag/原子写 | ui/RecognitionMembersRepository.kt:23-28,46-63,109-133 |
| 头像 URL/1MB/解码缓存/RGB_565 | ui/RecognitionAvatarRepository.kt:21-24,42-43,67-84,100-137 |
| 头像动画 220/160+220 | ui/RecognitionListContent.kt:80-96 |
| sheet 28 顶角/680 上限/skipPartiallyExpanded | ui/agent/AgentAnalysisSheet.kt:71-78,216 |
| 状态机 5 分支 | ui/agent/AgentAnalysisSheet.kt:276-314 |
| 行内正则全貌 | ui/agent/MarkdownInlineAnnotator.kt:25-27 |
| 徽标六色 | ui/agent/MarkdownInlineAnnotator.kt:164-179 |
| 动态文案兜底挂点 | ui/localization/LocalizationEngine.kt:98-108 + DynamicPatternLocalization.kt:6,100 |
| 图标消费者 | 见 12.7 正文内联行号 |
