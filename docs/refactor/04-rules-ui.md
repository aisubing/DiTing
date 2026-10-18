---
所属系列: DITING Android Flutter 重构功能图谱
章: 04
最后校验: 2026-10-18
口径: 本域文件全部点名；数字均为本会话工具实测
基线: main @ dda2779, v1.4.3 / versionCode 10403
---

# 04 规则管理 + 订阅管理 UI/ViewModel 层

> 引擎侧（core/rule 解析、索引、订阅下载 Worker）见第 02 章；导航/路由/模式骨架见第 03 章。本章只覆盖 **UI 与 ViewModel（业务逻辑层）**，对 core/rule 仅引用本会话确证的调用点。

## 1. 概述（实测规模）

| 指标 | 实测值 | 来源 |
|---|---|---|
| 本域点名文件数 | 46 | `wc -l` 清单合计 |
| 本域文件总行数 | 12 636 | 同上次行 `tail -1` |
| 顶层「屏」Composable（本域 46 文件内） | 19 | 各 `*Screen.kt` 的 `fun XxxScreen(` 定义行；`SingleAppRulePanel` 不计为屏（二级面板） |
| ViewModel 类 | 9 | `grep '^class\|^internal class'` 命中：Blacklist/Whitelist/RuleList/RuleManagement/RewriteList/Subscription/SubscriptionInterceptionStats/ProviderManagement(均 ui/)、AppRuleViewModel(normal/ui) |
| 对话框文件内 Composable 数 | 27 | BlacklistDialogs 4、WhitelistDialogs 6、RewriteListDialogs 4、SubscriptionDialogs 3、SubscriptionGroupDialogs 2、apprule/AppRuleDialogs 5、DomainActionDialog 1、ProviderSelectionDialog 2（`grep -c 'fun .*Dialog('`） |
| 屏内联对话框（不在 Dialogs 文件） | ≥8 | 订阅 URL 框、订阅/分组删除 3 框（SubscriptionScreen.kt:242-368）、规则来源筛选框（RuleListScreen.kt:167）、镜像模板操作框+删除框（MirrorTemplateScreen.kt:141-204）、覆写动态参数框（BlockResponseSettingsScreen.kt:111） |
| 统一分页大小 pageSize | 100（5 处各自硬编码） | BlacklistViewModel.kt:42、WhitelistViewModel.kt:43、RuleListViewModel.kt:38、RewriteListViewModel.kt:74、AppRuleViewModel.kt:497 |
| 搜索防抖 250 ms | 5 处 | BlacklistViewModel.kt:43、WhitelistViewModel.kt:44、RuleListViewModel.kt:39、RememberDebouncedValue.kt:13、AppPickerScreen.kt:69 |
| LazyPagingSource（Room Paging）| 本域仅 1 个关联屏：DNS 缓存（域外文件，作对照）| `data/repository/DnsCacheRepository.kt:16-46`；本域规则列表全部用「offset/limit 手动分页」 |
| RuleUpdateNotifier 生产调用者 | 0（死代码） | 全 `Android/` 目录 grep `RuleUpdateNotifier` 仅命中定义 `core/rule/RuleUpdateNotifier.kt:18` |
| 域名快捷处置弹窗 DomainActionDialog 触发点 | 3 处（文件在本域，宿主在域外） | ui/DnsCacheScreen.kt:231、normal/ui/RequestLogScreen.kt:302、express/ui/ExpressRequestLogScreen.kt:294 |

**结构结论**：规则/订阅 UI 层围绕三把「隔离锁」构建——`RuleDataset`（NORMAL/EXPRESS/DNS_MODE 三套数据库+三套 SharedPreferences，`data/RuleDataset.kt:18-30`）、`RuleScope`（本域全部以 `RuleScope.DNS` 实例化 Manager，见 §7）、以及工作模式判定 `WorkModeStore.getAppWorkMode(...) == AppWorkMode.EXPRESS` 的**渲染期读取**（黑名单/白名单/覆写页用它裁剪 URL/元素隐藏项）。同一份 Screen/ViewModel 代码通过 `dataset` 参数服务三种模式，路由在 `SettingsRouteActivity.kt:56-64` 决定 dataset、`:327,335` 决定 express 分支。

---

## 2. 逐屏详解

约定：每节 = 布局结构 / VM 状态 / 交互全集 / 校验 / 性能。路径省略公共前缀 `Android/app/src/main/java/com/haoze/diting/`。

### 2.1 黑名单 BlacklistScreen（ui/BlacklistScreen.kt, 507 行）

**路由**：`Routes.BLACKLIST_MANAGEMENT`（SettingsRouteActivity.kt:365-370，注入 `onNavigateToBatchAdd → BATCH_ADD_RULES`）。服务器模式入口经 `server/ui/DnsSettingsScreen.kt:51-53,122` 以 `dataset=RuleDataset.DNS_MODE` 重启 SettingsRouteActivity。

**布局**：`SettingsScaffold`（标题「黑名单」+ 右上 `MoreVert` 菜单）→ `Box`：`LazyColumn`[① 统计卡 ② 「规则管理」标题 ③ 搜索框+筛选 Chips 行 ④ 计数头 ⑤ 列表/空态] + 浮动 `RuleListPaginationBar` + 左下 FAB「添加黑名单」。VM 按 `key="blacklist_${dataset.name}"` 缓存（Screen.kt:88-91）——每个 dataset 一个实例。

**VM 状态（BlacklistViewModel，StateFlow ×8）**：`stats/items/currentPage/totalPages/totalCount/searchQuery/filter`（VM.kt:46-65）+ `activated` 位（67）。生命周期：`DisposableEffect` 调 `activate()`，ON_RESUME 再 `refreshAll()`（Screen.kt:110-121）。

**交互全集**：
- 顶栏菜单 3 项：添加黑名单规则→showAddDialog；批量添加规则→`onNavigateToBatchAdd()`（离开本屏）；清空自定义黑名单→showClearUserDialog（Screen.kt:130-158）。
- FAB → showAddDialog（261-272）。
- 搜索框 `RuleSearchField`（placeholder 按模式变，见校验）；筛选 `RuleFilterChipRow`：express/DNS_MODE 隐藏 URL、COSMETIC chips（Screen.kt:201-207，判据 `supportsAdvancedRules = dataset==NORMAL && !isExpress` 在 :192-193）。
- 行内：Switch 启停（主开关关闭时点击弹 Toast `masterDisabledMessage`，:231-241）；`RuleItemActionsMenu` 编辑/删除（:501-504，删除无行内确认前置，弹 `BlacklistDeleteConfirmDialog`）。
- 添加/编辑对话框（BlacklistDialogs.kt）：规则内容单行框 + 「指定应用包名(可选)」框 + 按钮 添加/取消/批量添加（neutral 槽）。**注意**：`important` 状态变量存在（Dialogs.kt:35、:121）但对话框内**没有任何控件修改它**——添加时恒 false、编辑时原样回传（见 §8 发现 10）。
- 删除确认框文案按 `isUserRule && !isSubscription` 区分（Dialogs.kt:185-189）。
- 清空确认框（Dialogs.kt:199-211）。
- 列表项 key = `"${item.type}_${item.id}"`（Screen.kt:224）。行内容：pattern 单行省略 + 标签组（自定义/规则订阅名/URL/元素隐藏/重要/通配符/App: [~]pkg/分组名）+ rawLine≠pattern 时原文（:479-487）。半透明=非 effectiveEnabled（:377）。

**校验/拒收（VM.addRule，VM.kt:290-382）**：
- 空 →「规则内容不能为空」(297)。
- 含 `##/#@#/#?#/#$#`：`#@#` 拒「该规则为放行规则，请在白名单中添加」(300-302)；否则 `cosmeticRuleRejection(dataset)` 非 null 拒（EXPRESS/DNS_MODE →「元素隐藏规则仅普通模式支持…」，core/rule/CosmeticRuleSupport.kt:22-25）；解析 `parseCategorizedLine` 取首条 cosmetic，空→「元素隐藏规则格式无效」(306-308)；`insertForSource` false→「该元素隐藏规则已存在」(325)。
- URL（`http(s)://` 或 `||http(s)://` 开头）：DNS_MODE 拒「URL 规则仅普通模式支持」(336-338)；`||` 前缀剥离后 `GoUrlRuleManager.addRule`，失败→「URL 格式无效或规则已存在」(346)。
- 域名：裸域自动包成 `||x^`（351-355）；`parseLine` 双兜底失败→「域名规则格式无效」(359)；重复→「该域名规则已存在」(380)。
- 编辑（VM.kt:384-453）域名/元素走 **deleteById + insertForSource**（432-444），`useradd` 源回写并保留 item.enabled。

**性能**：`SEARCH_DEBOUNCE_MS=250`+searchJob 取消（VM.kt:43-44,84-93）；`loadPage` 在 Dispatchers.IO 组装（125），主线程发布（213）。**无 LatestRequestGate**（见 §8 发现 5）。混排分页：URL+元素列表全量内存加载后 drop/take，域名走 SQL 分页；offset<nonDomainCount 时补 `domainLimit = pageSize - 已取数`（VM.kt:179-195）。统计卡数字来源 VM.loadStats（100-123）：`enabledPatternsCount/userRulesCount/enabledUserRulesCount/GoUrlRuleDao.count(BLOCK)/CosmeticRuleDao.blockRulesCount` 等，主开关关闭时 enabled 计数直接报 0（105,109,111）。

### 2.2 白名单 WhitelistScreen（ui/WhitelistScreen.kt, 407 行 + 专属组件 WhitelistComponents.kt 222 行）

**路由**：SettingsRouteActivity.kt:359-364。VM key `whitelist_${dataset.name}`（:66-69）。

**布局**：与黑名单同构，多两块：**「预设规则保护」分组**（仅 `dataset==NORMAL` 渲染，Screen.kt:168,176）内含 `SettingsSwitchItem`「允许编辑默认白名单」；顶栏菜单在 NORMAL 下多一项「重置默认白名单」（:130-139）。

**交互全集**：
- 「允许编辑默认白名单」开关：开启先弹 `WhitelistRiskWarningDialog`（AppConfirmDialog 红色警告 :321-330 + Dialogs.kt:27-42），确认才 `setAllowEditDefault(true)`；关闭直接 `setAllowEditDefault(false)` + Toast「已恢复默认白名单只读保护」（:190-197）。持久化键见 §7。
- 只读保护行（`item.isPreset && !allowEditDefault`）：Switch disabled（Components.kt:210）、`RuleItemActionsMenu enabled=false` 点击 Toast「请先开启【允许编辑默认白名单】开关」（:214-219）；toggle/edit/delete 三入口同样硬拦（Screen.kt:271-291）。行透明度三态：未生效 0.5f / 只读 0.75f / 正常 1f（Components.kt:83）。
- 顶栏：添加/批量添加/（NORMAL）重置默认/清空自定义（4 项，重置仅 NORMAL）。
- 编辑 preset 行：标题变「编辑默认默认预设规则」（Dialogs.kt:139），VM 保存时**源改写为 useradd**（VM.kt:444-459，A-100 注释：防升级 `deleteBySource(SOURCE_PRESET)` 静默丢用户改动）。
- 删除文案三分支（preset 提示可重置恢复/订阅/自定义，Dialogs.kt:198-204）。
- 筛选 chips：非 express 时全集；express/DNS 隐藏 URL、元素；`dataset!=NORMAL` 再隐藏 PRESET（Screen.kt:228-240）。
- 统计卡三分支（Components.kt:35-57）：NORMAL+非 express 6 项；NORMAL+express 3 项；DNS_MODE 2 项。`WhitelistStats.subscriptionTotal/subscriptionEnabled` **计算但从未渲染**（见 §8 发现 9）。

**校验**：VM.addRule（:301-390）——`#@#` 放行元素（DNS/EXPRESS 拒）、`@@http(s)://` URL（DNS_MODE 拒 :344-346）、域名 `@@||x^` 包装（359-363）。**本文件集无正则**；格式性校验全部委托 core/rule 的 AdGuardRuleParser（引擎语义见第 02 章），UI 侧仅做前缀判定与 Result 文案映射。重置= `DefaultWhitelistSeeder.seed(forceReset=true)`（VM.kt:470-479）。清空= `deleteUserRules` + URL user 源删除 + NORMAL 才删元素放行（:481-493）。

### 2.3 覆写名单 RewriteListScreen（ui/RewriteListScreen.kt 310 行 + RewriteListComponents.kt 153 行 + RewriteListDialogs.kt 269 行）

**路由**：两条——`Routes.REWRITELIST_MANAGEMENT`（带批量入口，SettingsRouteActivity.kt:371-376）与 `Routes.REWRITE_RULE_LIST`（不带批量，:385）。服务器模式经 DnsSettingsScreen.kt:138 以 DNS_MODE 打开。

**布局**：同构；顶栏菜单 3 项（添加/批量/清空自定义覆写）。统计卡固定 4 项 IPv4/IPv6/CNAME/用户自定义（Components.kt:31-36）。筛选 chips：全部/用户自定义/规则订阅/IPv4/IPv6/CNAME（`RewriteListFilter`，VM.kt:23-30）。

**交互**：FAB 与菜单均开 `RewriteAddDialog`；对话框结构：目标类型 FilterChip 三选（IPv4/IPv6/CNAME，Dialogs.kt:59-78）+ 域名单行框 + 目标值框（label 随类型切换 :92-96）+ 添加/取消/批量添加。编辑同结构。删除确认带「pattern -> targetValue」（:250）。行内 Switch 主开关判据：IPv4/IPv6→`isMasterEnabled`，CNAME→`isCnameRewriteOperational`（VM.kt:250-251；Screen 点击 guard :202-211，`masterDisabledMessage(context, targetType==IPV4||IPV6)`）。

**校验**：addRule 仅判空（域名/目标不能为空）后交 `RewriteRuleManager.addRule`，false→「域名、目标格式无效或存在规则冲突」(VM.kt:295-301)；editRule→「修改失败：格式无效或存在规则冲突」(319-325)。冲突判定在引擎（第 02 章）。

**性能**：**唯一使用 `LatestRequestGate` 的规则列表**——`loadPage` 先快照 `LoadPageRequest(page,query,filter)`、`begin` 注册、回主线程 `isLatest(request)` 不符则丢弃（VM.kt:100,167-179,269-277；util/LatestRequestGate.kt:35 `latest === request` 身份比较）。`setSearchQuery` **无防抖**，每次键击直接 loadPage（VM.kt:124-127）——依赖 gate+job cancel 兜底，键入快时每键一次 SQL。loadStats/loadPage 各自 cancel 旧 job（:135,176）。

### 2.4 规则列表 RuleListScreen（ui/RuleListScreen.kt 329 行 + RuleListViewModel.kt 403 行）

**定位**：单屏多形态（`ManagedRuleKind` 枚举 BLOCK/ALLOW/REWRITE/URL_BLOCK/URL_ALLOW，VM.kt:377-389），由路由 extra 决定：RULE_LIST→BLOCK、ALLOW_RULE_LIST→ALLOW、ADDRESS_RULE_LIST→URL_BLOCK、ADDRESS_ALLOW_RULE_LIST→URL_ALLOW（SettingsRouteActivity.kt:383-387；REWRITE_RULE_LIST 不走本屏）。VM key `rule_list_${dataset.name}`。

**布局**：Scaffold 标题=kind.title；右上「筛选规则来源」`MoreVert`（仅非 URL kind 显示，Screen.kt:89-96）→ 列：搜索框 + 「共 N 条…」+ 分割线 + LazyColumn（key=rule.id）+ 分页条（`alwaysShow=true`，:162）。

**交互**：行内 Switch（`masterEnabled` 关闭时点击不响应且不 Toast——直接 `if (rule.masterEnabled)` 吞掉，:143-148）+ 垃圾桶图标删除（无确认框，区别于黑名单/白名单）。来源筛选对话框 = `AppAlertDialog` 内 `SettingsSurfaceGroup` 单选列表：全部/手动添加/每条订阅名/每个 appScope（:167-227）。`NavigationSettledEffect(ruleKind to ruleScope)` 变化时重设 kind+activate（:80-83）。

**VM 状态**：rules/currentPage/totalPages/totalCount/searchQuery/sourceFilter/sourceSubscriptions/availableAppScopes（:41-63）。

**校验**：本屏无输入校验（纯展示/删除/启停）。删除分派：URL→GoUrlRuleManager.delete + NORMAL 才 syncHttps；REWRITE→rewriteRuleManager.deleteRule；ALLOW/BLOCK→`*.deleteRule(id)?.let{syncRuleIfRunning(...,"allow"/"block")}`（VM.kt:131-157）。

**性能**：`pageJob?.cancel()` 新请求获胜 + 注释明确「同黑名单缺陷」修复（VM.kt:93-112）；搜索防抖 250ms（:114-123）。订阅列表按 kind 查询（withRewriteRules/withAllowRules/withBlockRules，URL kind 返回空 :321-336）；appScopes 合并 split('|') 去前缀 `~` distinct sorted（:338-352）。masterEnabled 粒度：URL→`isAddressRulesOperational`；REWRITE→CNAME 用 cnameOperational 否则 domainEnabled；ALLOW/BLOCK→domainEnabled（:194-232）。

### 2.5 规则订阅 SubscriptionScreen（ui/SubscriptionScreen.kt 369 行）+ VM 580 行

**路由**：`Routes.SUBSCRIPTION_MANAGEMENT`（SettingsRouteActivity.kt:458-464，注入 `onNavigateToAddSubscription`）；VM key `subscription_${dataset.name}`。

**布局**：Scaffold（右上「全部更新」`Refresh` + 「添加」`Add`，均 `busy` 时 disabled :135-140）→ `belowTopBar = SubscriptionGroupTabs`（横向滚动 chip 行，未分组固定首项，分组长按进 `SubscriptionGroupActionDialog`，SubscriptionGroupTabs.kt:27-49，`combinedClickable` :65）→ LazyColumn[消息条 / 分组标题 + `SubscriptionItems` 卡片组或空态 / 导入类型说明]。

**本地 UI 状态**：8 个对话框宿主位 + `selectedGroupId/selectionInitialized`（:97-117）+ `showInlineAddScreen`（无导航回调时内嵌整页 AddSubscriptionScreen，:62-70 —— 与路由跳转入口形成双实现，见 §8 发现 15）。

**数据流（VM，StateFlow 16 个 + 3 个 Flow 直出）**：subscriptions/ruleBreakdowns/pendingSubscriptions/mirrorTemplates/subscriptionGroups/allSubscriptions（Room `observeAll()` 冷流直出，:64-66）/importing/importingSubscriptionId/updatingSubscriptionId/message/operationMessage/progress + `_progress:SubscriptionProgress(current,total)`（:39）。`activate(scope)` 订阅 Room flow 过滤 `deletingSubscriptionIds` 即时隐藏删除中行（:95-106,410-411）。

**交互全集**（行 MoreVert → SubscriptionActionDialog，SubscriptionDialogs.kt:37-91）：
- **更新规则**：仅 `sourceType==REMOTE` 显示该项（:53-61）→ `viewModel.updateSubscription(id)`。
- **编辑/重命名**：LOCAL→`RenameSubscriptionDialog`（只改 name）；REMOTE→`EditSubscriptionDialog`。
- **启用/禁用**：`toggleSubscriptionEnabled`（operationMessage「正在启用/禁用规则订阅...」VM:452-456）。
- **删除规则**：先弹确认「确定删除「名」及其导入的所有规则吗？」（Screen:314-326）。
- 订阅 URL 行（REMOTE 才可点，SubscriptionItemList.kt:100-110）→ 可复制地址对话框（Screen.kt:242-261 SelectionContainer）。
- 分组 Tab 长按 → 重命名/解散（订阅移未分组，不删）/删除本组全部订阅（带成员数文案，Screen:327-368）。
- 「更新所有订阅」按钮 → `updateAllSubscriptions()`。
- 分组选择：`LaunchedEffect(subscriptionGroups)` 默认选首个分组、当前选中组消失时回退未分组（:109-117）。

**手动更新全链路**（§4 详述）：点击后 UI 侧**无取消入口**（本域文件 grep `cancel|取消` 仅命中对话框取消按钮，无操作取消）；进度/错误展示见 SubscriptionItemList.kt:177-213。

**性能/正确性**：`ruleBreakdowns` 每次订阅变化对**每条订阅**执行 3 个 countBySource SQL（VM.kt:565-579，N 订阅 → 3N 查询）。`applyBackgroundWorkState` 用 `combine(手动tagFlow, 自动tagFlow)` 推导 importing/进度/operationMessage（:84-93,528-555）。

### 2.6 添加订阅 AddSubscriptionScreen（452 行）

**路由**：`Routes.ADD_SUBSCRIPTION`（SettingsRouteActivity.kt:466-471），`initialKind` 由调用方 extra 决定（本路由默认 DOMAIN）。复用 `SubscriptionViewModel`（key `add_subscription_${dataset.name}`，:65-68——与订阅列表页 VM 不同 key，互不共享）。

**分区**（LazyColumn + 每区 SettingsInfoText 说明）：导入方式（订阅地址/本地文件单选）→ 规则类型（DOMAIN=仅黑白名单域名 / HOSTS=仅 hosts+CNAME 覆写）→ 订阅信息（REMOTE：url Uri 键盘框 min2 max4 行 + 名称可选框；LOCAL：SAF 文件选择行 + 名称可选框）→ 所属分组（单选 + 新建分组名框）→ 镜像加速（**仅 REMOTE 渲染** :332）→「导入规则」按钮。

**交互细节**：
- 文件选择：`ActivityResultContracts.OpenDocument()`（mime `text/plain`,`*/*`，:90-113）→ `PersistableUriPermissions.take` → 仅接受 `.txt`（否则 Toast「请选择扩展名为 .txt 的规则文件」）→ `SafGrantDecisions.releasesOnPick` 回收被替换/被拒 URI 的旧授权（:97-102）。默认名 = 去 `.txt` 后缀。
- 提交前校验（:115-122）：REMOTE 要求 `isUrlValid`（`http(s)://` 前缀，无更深正则）+ `isMirrorValid`（`!useMirror || validMirrorTemplate`）；LOCAL 要求已选文件；`isSubmitting` 防重复点击。提交成功即 `onRuntimeDnsSettingsChanged(); onBack()`——**留在页内不显示进度**（进度只在列表页可见）。
- 镜像模板空列表时显示错误色提示「暂无模板，请先在域名规则 → 镜像站模板中添加。」（:345-352）。

### 2.7 订阅编辑对话框 EditSubscriptionDialog + 编辑器组件（SubscriptionDialogs.kt 205 + SubscriptionEditorComponents.kt 272）

结构：类型不可改说明（删除重建，Dialogs.kt:116-121）→「订阅信息」卡（URL+名称复用组件）→ 折叠卡「订阅分组」（`SubscriptionGroupSelector` 单选 + 新建名框，填名自动取消选中组 :170-179）→ 折叠卡「自定义镜像」（`MirrorEditor`：开关 + 模板单选 + `请求预览` + 回退直连开关 :183-237）。保存按钮 enabled：`url 非空 && name 非空 && (!useMirror || validMirrorTemplate)`（:159-160）。`validMirrorTemplate`：http(s) 前缀 + 含六占位符之一（EditorComponents.kt:254-258）；`mirrorPreview` 按 `{urlEncoded}>{url}>{scheme}>{host}>{pathAndQuery}>{path}` 顺序替换（:260-272）。

### 2.8 订阅统计两屏

**SubscriptionInterceptionStatsScreen**（140 行）+ VM（102 行）：路由 `Routes.SUBSCRIPTION_INTERCEPTION_STATS`（LogRouteActivity.kt:123）。三区块：时间范围 chips（今日/近 7 天/全部，`data/RequestLogModels.kt:14-18`，复用 `RuleFilterChipRow`）→ 概览「全部已记录请求」→「屏蔽订阅」列表（名 + 状态|拦截 N 次|百分比，已删除订阅显示「已删除订阅 #id」，VM:69-80 排序 hits 降序→名称）。数据源 `DnsLogRepository.subscriptionInterceptionStats(range)`（runtime 库；NORMAL 附加 http 日志 DAO，VM:34-41）。VM 状态：range/totalRequests/items/loading 4 个 StateFlow。无分页、无搜索。

**SubscriptionAutoUpdateIntervalScreen**（237 行）：**无独立 VM**（直接 Room flow + RuleSettingsAccess）。区块：总开关（副标题说明受系统调度影响）→ 更新频率预设 `intervals=[6,12,24,48]` 单选 + 「自定义更新时间」项（选中态=非预设值）→ 分组自动更新逐组 Switch（`subscriptionGroupDao().setAutoUpdateEnabled`，:165-174）→ 说明。自定义对话框校验：`toIntOrNull() ∈ 1..168`（`SubscriptionAutoUpdateSettings.MIN/MAX_INTERVAL_HOURS`，core/rule/SubscriptionAutoUpdateScheduler.kt:37-38），失败 inline error「请输入 1 至 168 之间的小时数」。输入框 `filter(Char::isDigit)`。持久化：`SubscriptionAutoUpdateSettings.save` + `SubscriptionAutoUpdateScheduler.sync(context, dataset)`（每保存一次重排 WorkManager 周期，:68-76）。总开关关闭时频率与分组开关全部 `enabled=false`（:65）。

### 2.9 DNS 服务商管理 ProviderManagementScreen（208 行）+ VM（208 行）+ 组件（ui/components/ProviderManagementComponents.kt 357 行）

**路由**：`Routes.PROVIDER_MANAGEMENT`（SettingsRouteActivity.kt:415）。VM 带 `dataset`（providers/selectedId/message/initialLoading 4 StateFlow；`DnsProvider.loadAll/loadSelected`，:56-67）。

**布局**：`ProviderManagementListContent`：顶部「当前用于解析 DNS: (协议) 名称」→ 协议 chips（`DnsProtocol.MANAGED_PROTOCOLS=[DNS,DoH,DoT]`）→ 内置组（preset，`isPreset`，不可编辑删除）→ 自定义组（`isUserProvider()`，带 编辑/删除 图标按钮）（Components.kt:264-357）。右上「新增」TextButton。

**交互**：点击行=选中（同 id 去抖 `if (provider.id == selectedId) return`，Screen:45-48）→ `select(id)` 持久化 + `RuntimeDnsSettingsRefresher.refreshIfRunning(context,"provider_selected",dataset)`。新增/编辑走泛型 `ProviderEditDialog`：name 框 + `ProtocolToggleRow` 协议 chips（切协议自动填默认端口 53/853，DOH 无端口框）+ 地址框（DOH=url，其余=host+port，port 框 `filter(isDigit)`）+「保存」。校验两层：`validateInput` 决定保存可用态；`validateAddress` 失败先显示行内 `AddressErrorText`（Components.kt:245-255 两段式：地址非法时按钮仍可点，点击转为 inline 错误）。VM 侧再校验（:152-192）产出 string 资源消息。删除弹 `AppConfirmDialog`（destructive）。健康展示在**域外** ProviderHealthScreen.kt:55-116（本域不渲染健康；`Health` 数据在 core/diagnostic，见第 06 章口径）。

**首页选择弹窗 ProviderSelectionDialog.kt（479 行）**：单选版（SINGLE 模式）与多选版 `ModeProviderSelectionDialog` 共用 `ProviderDialog`——`Dialog(usePlatformDefaultWidth=false)` + 自绘进出动画（200/220ms fade+scale 进，150ms 出，:159-167）+ 高度上限 68% 屏高（:169）+ `ConfigureDialogWindow` 把 dim 设 0 并去系统窗动画（:447-457）。保留虚拟行 `MANAGE_PROVIDER_ID="__manage__"` / `PROVIDER_VISIBILITY_ID="__provider_visibility__"`（:65-66）：不进可选列表，作为底部分割线下两枚导航按钮（Tune/Visibility 图标）。多选版选中行相邻合并圆角（`providerRowShape` :322-338）；副标题 `raceProviderSummary`「已选 N 个：名1、名2 等」（:68-73）。宿主：normal/ui/MainScreenContent.kt:253-285 按 `resolutionMode==SINGLE` 切两版，`selectProvider/toggleModeProvider` 回调。

### 2.10 镜像站模板 MirrorTemplateScreen（290 行）+ 格式指南 MirrorFormatGuideScreen（227 行）

MirrorTemplateScreen 路由 `Routes.MIRROR_TEMPLATES`（SettingsRouteActivity.kt:498-502），VM = `RuleManagementViewModel(key="mirror_${dataset.name}")` ——**该 VM 在本域唯一消费者**（grep 确证，见 §3）。布局：说明 →「操作」导航组（添加模板→对话框；镜像站格式示例→Guide 路由）→「已保存模板（N）」列表（每行 MoreVert → 操作框 编辑/删除）。添加/编辑共用 `MirrorTemplateDialog`：名称框 + 地址框（supportingText=错误或「必须使用 HTTP(S) 并包含至少一个占位符」）+ 六个占位符按钮（`chunked(3)` 两行，点击**追加**占位符，第三列 weight 0.4）+ 提交态文案「添加中/保存中...」。校验在 VM.validateMirrorTemplate（RuleManagementViewModel.kt:151-155）：名称非空、http(s) 前缀、含占位符之一。删除确认「已使用此模板的订阅不会被修改」（:192-204）。保存成功判据是**字符串比较**「已添加/已更新镜像站模板」（:277）。

MirrorFormatGuideScreen：无 VM；内置中英两份 Markdown 字符串（:24-142），按 `LocalConfiguration.locales[0].language=="en"` 选择（:149-153），自研轻量渲染 `MirrorMarkdownLine`（#/##/列表/分隔线 + 反引号代码 token 正则 `mirrorCodeToken :144` 二级高亮）。**不是**通用 markdown 引擎，Flutter 侧可换真实 renderer，但内容语义（六个占位符表、检查清单）需原样保留。

### 2.11 应用规则 UI（AppPicker / apprule / normal 四屏）——详见 §5

共享骨架 `AppPickerScreen`（ui/AppPickerScreen.kt 199 行）：单选/多选应用列表 + 250ms 防抖搜索（label/包名 lowercase contains）+ 过滤/排序 + 全选/清除/反选 + 保存 FAB + `BackHandler` 脏则自动保存再返回（:85-94）。`rememberAppListAccessState`（InstalledAppPickerComponents.kt:325-462）实现「告知→授权→失败降级」三态（`apps=null` 加载中 / `emptyList+unavailable` 拒权 / 列表），ON_RESUME 重查权限。`loadInstalledApps`（:193-216）过滤自身包名、缓存 normalizedLabel。

### 2.12 阻断响应 BlockResponseSettingsScreen（220 行）

路由 `Routes.BLOCK_RESPONSE_SETTINGS`（SettingsRouteActivity.kt:395）。**无 VM**，本地 remember 态 `responseMode/dynamicConfig/showParameterDialog`（:48-50）。固定响应：`BlockResponseMode.entries`（NXDOMAIN/NODATA/REFUSED/ZERO_ADDRESS）单选行，副标题本地写死（:215-220）；选中即 `settings.setBlockResponseMode` + `onRuntimeDnsSettingsChanged()`。动态策略：开关（「同一域名的所有记录类型合并计数」）+ 动态参数导航项（摘要「N 次 / W 秒 / 保持 D 秒」）→ `DynamicParametersDialog` 三框（纯数字 filter），范围校验用 `DynamicBlockResponseConfig.MIN/MAX_*` 常量（:139-144）。持久化键（`AppRulesSettingsStore`，按 dataset 分 prefs）：`block_response_mode`、`dynamic_block_response_enabled`、`dynamic_block_request_threshold`、`dynamic_block_window_seconds`、`dynamic_block_nxdomain_duration_seconds`（AppRulesSettingsStore.kt:31-35；DNS_MODE 走 `DnsRuleSettings`，RuleSettingsAccess.kt:67-85）。语义/生效链见第 02 章。

### 2.13 域名快捷处置 DomainActionDialog（ui/DomainActionDialog.kt 59 行）

内容：域名粗体行 + 可选「AI 分析该域名」（AutoAwesome）+ 复制 + 加入白名单规则 + 加入屏蔽规则，全宽按钮列；取消关闭。`analyze=null` 时隐藏 AI 行（:36）。**三个触发点**（本域文件、宿主域外）：
1. DnsCacheScreen.kt:230-265：点缓存行→弹窗；add 直调 `AllowListManager/BlockListManager(scope=DNS).addRule(domain)` + `syncRuleIfRunning(...,dataset)` + `entries.refresh()`；analyze=「AnalysisTarget.Domain」。
2. normal/ui/RequestLogScreen.kt:302-333：同上，ruleScope 取 `pendingRuleScope`（默认 DNS，:117），analyze 可用。
3. express/ui/ExpressRequestLogScreen.kt:294-322：**analyze=null**（极速无 Agent）；dataset=EXPRESS。

---

## 3. VM 间共享与跨屏通信

1. **无 VM 间直接引用**。跨屏同步靠三机制：
   - `dataset → 每屏独立 VM 实例`（viewModel key 含 dataset 名，进程内 Activity 栈共享时同一 dataset 复用同一实例；不同 dataset 完全隔离）。
   - **Room `observeAll()` 冷流**：SubscriptionScreen/RuleControlScreen/SubscriptionAutoUpdateIntervalScreen/MirrorTemplateScreen 直接 collect dao flow（SubscriptionViewModel.kt:64-66；normal/ui/RuleControlScreen.kt:56-57），任何写库自动广播——分组名、订阅增删跨屏即时可见。
   - **`onRuntimeDnsSettingsChanged()` 回调链**：几乎所有 mutation 成功后调用，宿主 SettingsRouteActivity 转 `RuntimeDnsSettingsRefresher.refreshIfRunning(dataset=...)`（SettingsRouteActivity.kt:128）。
2. **引擎通知面**：UI 层不直接持有引擎，全部经 `core/rule/RuntimeDnsSettingsRefresher`（object，194 行）静态方法：`refreshIfRunning/syncRuleIfRunning/refreshRuleIndexesIfRunning/syncHttpsRequestRulesIfRunning/refreshAppExclusionsIfRunning/refreshAppAllowlistIfRunning`。分派按 dataset 三分支（EXPRESS→ExpressVpnService intent、NORMAL→DnsVpnService intent、DNS_MODE→DnsModeService REFRESH intent，仅当 `WorkModeStore==DNS`），Express 把 6 种刷新压缩成同一 `SYNC_RULES` intent（RuntimeDnsSettingsRefresher.kt:82-91,121-130）。**本域确证消费点**：toggle/delete/addRule 链（§2.1/2.2/2.3/2.4）、订阅 `refreshSubscriptionRuleIndexes`（SubscriptionViewModel.kt:489-507）、应用规则四保存函数（§5）、服务商 select/add/update/delete 的 `refreshIfRunning("provider_*")`。
3. **RuleUpdateNotifier：零生产调用者**。`internal class`（core/rule/RuleUpdateNotifier.kt:18），全仓 grep 只命中定义行——订阅/规则后台进度通知实际由 `RuleOperationWorker.createForegroundInfo` 自建（core/rule/RuleOperationWorker.kt:504-529）。UI 侧对「谁在跑」的感知来自 WorkManager 两条 tag flow（§4）。重构时应删除该类或接入 Worker，不得当作现役事件总线。
4. **RuleManagementViewModel 大半为死代码**：唯一消费者 MirrorTemplateScreen 只用 `mirrorTemplates/addMirrorTemplate/editMirrorTemplate/deleteMirrorTemplate`；`importRules`（WorkManager IMPORT_RULES）、`importHostsRules`、`addRewriteRule`、`activate(scope)`/`loadRuleCount`/`rewriteRuleCount` **无任何 UI 调用**（grep 确证；`ui/transfer/RuleConfigImporter.importRules` 是同名异类，勿混淆）。
5. `SubscriptionViewModel.updatingSubscriptionId` 在 VM 内写入（:545）但没有任何 UI collect（消费方只读 `importingSubscriptionId`，SubscriptionScreen.kt:80）。
6. 跨屏事件语义清单：批量添加（BATCH_ADD_RULES，域外 ui/batch/）、订阅添加双路径（路由 vs 内嵌，§2.5）、Provider 选择回首页（§2.9）。

---

## 4. 订阅 UI 全链路（添加→编辑→更新→分组→统计）

**添加（REMOTE）**：列表页「+」→ 路由/内嵌 AddSubscriptionScreen → 选类型 DOMAIN|HOSTS（类型决定只进 block+allow 表还是 rewrite 表，引擎消费见第 02 章）→（镜像开关：模板单选+预览+回退）→「导入规则」→ `addSubscription`：先 `resolveGroupId`（新建分组名查重「分组名称已存在」）→ 插入 `pendingSubscriptions` 伪行（id 负数递减 `nextPendingSubscriptionId--`，importState=IMPORTING，VM.kt:146-156）→ `RuleOperationScheduler.enqueue(ADD_SUBSCRIPTION, url/name/kind/mirrorTemplate/mirrorFallback/groupId/scope/dataset)`（unique work `manual_rule_operation_queue`，`APPEND_OR_REPLACE`，联网约束，退避 30s 指数——RuleOperationWorker.kt:52-113）→ `enqueueAndObserve(workId, pendingId)` 完成即移除伪行、Toast/「操作失败：msg」、`loadSubscriptions()`。本地文件同理（ADD_LOCAL_SUBSCRIPTION + `PersistableUriPermissions.take`）。

**手动更新（单订阅）**：行 MoreVert →「更新规则」（**LOCAL 订阅不显示该项**，SubscriptionDialogs.kt:53-61）→ `updateSubscription(id)` 入队 UPDATE_SUBSCRIPTION。**进度展示**：`applyBackgroundWorkState`（VM.kt:528-555）从 `getWorkInfosByTagFlow(TAG)+自动更新tag` 合并流取**第一个未终态** WorkInfo 的 progress（KEY_TYPE/SUBSCRIPTION_ID/CURRENT/TOTAL）→ `importing`（仅 5 种订阅操作为 true）、`importingSubscriptionId`、`progress`。列表行据此渲染：`isUpdating||IMPORTING` → 文案「正在下载并更新规则...」（LOCAL 变体「正在导入规则...」）+ `current/total（pct%）` 或「已导入 n 条」+ `LinearProgressIndicator`（total>0 确定模式，否则不确定模式；SubscriptionItemList.kt:177-200）。**错误**：`importState==FAILED` →「更新失败（连续 N 次）：<importError>」红行（REMOTE）/「导入失败：…」LOCAL（:201-213）。全部更新：顶栏 `updateAllSubscriptions()`（UPDATE_ALL_SUBSCRIPTIONS，operationMessage「正在更新所有规则订阅...」）。**busy 语义**：`busy = importing || operationMessage!=null`（Screen:84）——仅禁用行按钮/顶栏/编辑入口，**没有任何取消/中止操作**（见 §8 发现 14）。

**自动更新**：`SubscriptionAutoUpdateScheduler`（WORK_TAG「subscription_auto_update_work」）周期由 §2.8 屏配置；UI 侧 `applyBackgroundWorkState` 把自动 tag 同样并入进度（手动/自动共享同一进度面板）；引擎侧行为见第 02 章。

**分组**：Tab 行（未分组+各组，长按→重命名/解散/删本组订阅三确认框）；新建分组经添加页/编辑对话框的「新建分组名称」框（填名自动清选中，EditorComponents.kt:170-179）；`resolveGroupId/createGroupInternal` 查重非空（VM.kt:350-363）；解散=`clearGroup(id)+deleteById` 包 `withTransaction`（VM.kt:287-295）。

**统计**：行内「N 条规则（黑名单 x · 白名单 y · 覆写 z）」（ruleBreakdowns，Screen 渲染于 SubscriptionItemList.kt:132-142）+ 独立拦截率屏（§2.8）。

---

## 5. 应用规则 UI：排除/禁止/白名单(放行)/HTTPS 检查 四类

| 屏 | 入口路由 | 主开关 | 持久化键（AppRulesSettingsStore，prefs 按 dataset 分） | 互斥/联动（保存时） | 生效模式（渲染条件行号） |
|---|---|---|---|---|---|
| 排除应用 ExcludedAppsScreen | EXCLUDED_APPS（SettingsRouteActivity.kt:388） | 无 | excluded_app_packages / excluded_apps_filter / _sort | 检查−、禁止−、放行−（:46-48） | 仅 normal 模式暴露：express 功能白名单不含 EXCLUDED_APPS（ExpressHiddenFeaturesScreen.kt:31-33 注释+38-66 集合） |
| 禁止联网应用 BlockedAppsScreen | BLOCKED_APPS(_SELECTION)（:417-418） | 「启用禁止联网」（headerContent，BlockedAppsScreen.kt:78-92） | blocked_app_packages / blocked_apps_enabled / _filter / _sort | 排除−、检查−、放行−（:52-54） | 仅 normal（同上，BLOCKED_APPS 不在 EXPRESS_SUPPORTED）；保存 Toast 分支「DNS VPN 正在重连/下次启动生效」:56-57 |
| 应用独立规则（单应用放行+DNS黑白+全阻断）AppRuleManagementScreen | APP_RULE_MANAGEMENT / APP_ALLOWLIST(_SELECTION)（:358,419-420） | 「启用单应用域名放行」（:200-208，isAppAllowlistMasterEnabled→KEY app_allowlist_enabled） | app_allowlist_rules_json（Map<pkg,Set<domain>>）+ app_allowlist_enabled / _filter / _sort | `addAllowlistDomain` 清该 pkg 的 禁止/检查/排除 三集合（AppRuleViewModel.kt:318-320） | 仅 normal（路由与文件均位于 normal 包；express 无对应） |
| HTTPS 检查应用 HttpInspectionAppsScreen | HTTP_INSPECTION_APPS（:442） | 无（开关在 HttpInspectionSettingsScreen，域外） | http_inspection_app_packages / http_inspection_apps_filter / _sort | 排除−、禁止−、放行−（:41-43） | 仅 normal（ADVANCED_TOOLS/HTTPS_INSPECTION 不在 express 白名单，同文件注释 :33） |

**AppRuleManagementScreen 两级结构**：列表级=应用总表（行徽标「放行 n 域名 / DNS m 条 / 未配置」apprule/AppRuleComponents.kt:45-148；搜索防抖 `rememberDebouncedValue`；过滤 SELECTED 语义改为「已配置任一规则」:146-149；排序=有配置者优先再按名称 :153-159；右上「清空全部放行规则」DeleteSweep→`ClearAllAllowlistDialog`，仅在存在放行配置时显示 :171-178；overflow 菜单**隐藏**全选/清除/反选 `showSelectionActions=false` :187）→ 点行进 `SingleAppRulePanel`（二级屏，BackHandler 先关面板 :75-76,115）。

**SingleAppRulePanel（ui/apprule/SingleAppRulePanel.kt 446 行）四段**：① 外联与隔离模式——「默认拦截全部外联」Switch，开启先 `FullBlockConfirmDialog`；开启后红色警示卡；引擎侧=写 `*​$app=<pkg>` 全域名 block 规则（AppRuleViewModel.kt:354-392，`toggleFullBlockTemplate` 复用 fullBlockRuleIdForApp 增删 + `syncCachedPattern("*")`）② 专属放行域名（网络层）Set 行（每行「包含子域名」+删除；「清空放行域名」确认框）③ DNS 专属白名单分页列表 ④ DNS 专属拦截分页列表。②③④ 各自「添加」→ `AddAllowlistDomainDialog`（域名必填「请输入有效的域名」）/ `AddDnsRuleDialog`（pattern+「高优先级 ($important)」Checkbox，`contains('*')` 判通配符，AppRuleDialogs.kt:149）。删除按钮**仅 isUserRule 行渲染**（AppRuleComponents.kt:285-294）；VM 二次拦截：sources 全为 `sub_*` 的行 deleteRule 直接 return（AppRuleViewModel.kt:470-479）。

**性能**：分页=offset 累加 + 「hasMore」哨兵（PAGE_SIZE=100，`pagedByAppScope`）；「加载更多」footer item 进入组合即 `LaunchedEffect` 触发下一页（SingleAppRulePanel.kt:338-345,390-395）——滚动驱动的增量加载；`blockLoading/allowLoading` + `loadedPackage` 双守卫防串页（AppRuleViewModel.kt:186-222）。列表级计数改为**单条 GROUP BY 扫描** `appScopeCounts()`（避免 N 应用 × 2 全表 LIKE 扫描，注释 :122-125）；订阅名解析只查本页引用的 sub id（:229-233）。

**AppPickerScreen 第四消费者**：normal/ui/OutboundProxySettingsScreen.kt:237（单选 `singleSelect=true`、无选择动作菜单），语义属域 06，结构归本骨架。

---

## 6. 两模式「规则控制」页差异对照（RuleControlScreen 239 行 vs ExpressRuleControlScreen 186 行）

路由分派：`SettingsRouteActivity.kt:331-357`——`RULE_MANAGEMENT|RULE_CONTROL|DOMAIN_RULE_MANAGEMENT|ADDRESS_RULE_MANAGEMENT` 四路由，`isExpress = WorkModeStore==EXPRESS`（:327）时渲染 Express 版，否则 normal 版；服务器模式经 DnsSettingsScreen.kt:89 用同 normal 版但 `dataset=DNS_MODE`。

| 区块/控件 | normal 版（RuleControlScreen.kt 行号） | express 版（ExpressRuleControlScreen.kt 行号） | 差异性质 |
|---|---|---|---|
| 页首说明文案 | NORMAL 与 DNS_MODE 两分支（:103-107） | 固定「极速模式…黑名单与白名单…功能中心」（:96） | 文案 |
| 分组标题 | 「过滤与覆写控制」（:114） | 「过滤控制」（:102） | 覆写字样去除 |
| 域名规则总开关标题/副标题 | 「启用域名规则/启用域名过滤」按 dataset（:121-130） | 恒「启用域名规则」（:108-111） | 文案 |
| 关总开关的联动 | `!checked && dataset==NORMAL && httpInspectionEnabled` → `pendingLinkage=DISABLE_BOTH` 弹 `DomainRulesInspectionLinkageDialog`，确认后**同时关 HTTPS 检查**（:133-136,222-238） | **无联动**，直接关（:114-119） | express 无 HTTPS 检查 |
| 「URL 规则与内容过滤」导航卡 | **仅 `dataset==NORMAL` 渲染**（:145-162）；四态就绪文案（CA 未装/检查未开/未选应用/已暂停/运行中）:148-154 | **整卡不存在** | 能力裁剪 |
| 拦截响应入口副标题 | `dynamicConfig.enabled ? 动态 : 当前模式`（:176-179） | `ExpressDynamicBlockSupport.blockResponseSubtitle`：stored 开关≠实际行为时显示「极速模式暂不执行动态升级，当前按固定策略返回（…）」（:137-144 + express/ExpressDynamicBlockSupport.kt:35-56） | 极速引擎不执行动态升级，UI 报实态而非存储位 |
| 订阅与更新三入口 | 规则订阅（副标题含「IPv4/IPv6 覆写」:201）/自动更新/镜像站模板（:197-217） | 同三项，副标题改「管理域名规则订阅源及分组」（:166） | 覆写字样去除 |
| 状态刷新 | ON_RESUME `refreshState()` 重读 7 个本地 remember 态（:68-88） | 同机制但只 3 个态（:66-82） |  |
| `onNavigateToHttpInspection` 参数 | 有（:47） | **无此参数**（:44-53 签名比对） | API 面 |

服务器模式（dataset=DNS_MODE 走 normal 版）：说明文案变体（:106-107）、地址规则卡被 `dataset==NORMAL` 条件隐藏（:145）、总开关读写路由到 `DnsModePreferences.adBlockEnabled`（RuleSettingsAccess.kt:21-34）、`isAddressRulesOperational` 恒 false（:41-44）故 URL/元素规则在三个规则列表页均显示为未生效。

---

## 7. 关键源码引证表

| # | 事实 | 路径:行 |
|---|---|---|
| 1 | 黑名单搜索防抖 250ms + job cancel | ui/BlacklistViewModel.kt:43-44, 84-93 |
| 2 | 黑名单混排分页 drop/take 与补位取数 | ui/BlacklistViewModel.kt:176-195 |
| 3 | `#@#` 引导到白名单的拒收文案 | ui/BlacklistViewModel.kt:300-302 |
| 4 | DNS_MODE 拒 URL 规则（两处对称） | ui/BlacklistViewModel.kt:336-338; ui/WhitelistViewModel.kt:344-346 |
| 5 | 元素隐藏数据集门控函数 | core/rule/CosmeticRuleSupport.kt:22-25 |
| 6 | express/DNS 隐藏 URL/元素筛选 chips | ui/BlacklistScreen.kt:192-207; ui/WhitelistScreen.kt:220-240 |
| 7 | 预设白名单保护开关+风险确认 | ui/WhitelistScreen.kt:176-202, 321-330; ui/WhitelistDialogs.kt:27-42 |
| 8 | 编辑 preset→改存 useradd（A-100） | ui/WhitelistViewModel.kt:444-459 |
| 9 | 覆写列表 LatestRequestGate 双检 | ui/RewriteListViewModel.kt:100,167-179,269-277; util/LatestRequestGate.kt:20-37 |
| 10 | 覆写搜索无防抖（直发 loadPage） | ui/RewriteListViewModel.kt:124-127 |
| 11 | 规则列表 pageJob cancel「新请求获胜」注释 | ui/RuleListViewModel.kt:93-99 |
| 12 | ManagedRuleKind 5 形态+isUrlRule | ui/RuleListViewModel.kt:377-389 |
| 13 | RuleSourceFilter（All/Manual=sub_useradd/Subscription=sub_id/AppScope） | ui/RuleListViewModel.kt:355-375 |
| 14 | 订阅 WorkManager 双 tag combine | ui/SubscriptionViewModel.kt:84-93, 528-555 |
| 15 | 伪行 pending 订阅（负 id） | ui/SubscriptionViewModel.kt:60-63, 146-156, 197-206 |
| 16 | 删除即时过滤 deletingSubscriptionIds | ui/SubscriptionViewModel.kt:59, 95-106, 410-448 |
| 17 | 更新进度/失败文案渲染 | ui/SubscriptionItemList.kt:177-213 |
| 18 | 入队 unique work + 网络约束 + 指数退避 | core/rule/RuleOperationWorker.kt:52-113 |
| 19 | 自动更新区间 6/12/24/48、1..168 校验 | core/rule/SubscriptionAutoUpdateScheduler.kt:35-48; ui/SubscriptionAutoUpdateIntervalScreen.kt:216-221 |
| 20 | 自定义镜像校验六占位符 | ui/SubscriptionEditorComponents.kt:254-272; ui/RuleManagementViewModel.kt:151-155 |
| 21 | 服务商两段式校验（inline 错误优先） | ui/components/ProviderManagementComponents.kt:162-256 |
| 22 | 虚拟管理/显示行常量 | ui/ProviderSelectionDialog.kt:65-66 |
| 23 | 多选自适应圆角合并 | ui/ProviderSelectionDialog.kt:322-338 |
| 24 | 域名处置弹窗 3 触发点 | ui/DnsCacheScreen.kt:230-265; normal/ui/RequestLogScreen.kt:302-333; express/ui/ExpressRequestLogScreen.kt:294-322 |
| 25 | 阻断响应持久化 5 键 | ui/settings/AppRulesSettingsStore.kt:31-35 |
| 26 | 规则控制联动对话框（关域名→连带关检查） | normal/ui/RuleControlScreen.kt:133-136, 222-238; ui/components/RuleListSharedComponents.kt:488-515 |
| 27 | URL 规则就绪四态文案 | normal/ui/RuleControlScreen.kt:147-154 |
| 28 | 极速拦截响应报实态不报存储位 | express/ExpressDynamicBlockSupport.kt:35-56 |
| 29 | 全阻断 = `*​$app=pkg` 规则 | normal/ui/AppRuleViewModel.kt:354-392（尤其 :366-367） |
| 30 | 放行域名保存清三集合 | normal/ui/AppRuleViewModel.kt:316-321 |
| 31 | 订阅来源行不可删（二次拦截） | normal/ui/AppRuleViewModel.kt:470-479 |
| 32 | app 规则 GROUP BY 计数优化 | normal/ui/AppRuleViewModel.kt:121-142 |
| 33 | footer LaunchedEffect 增量翻页 | ui/apprule/SingleAppRulePanel.kt:338-345, 390-395 |
| 34 | 应用列表权限三态机 | ui/InstalledAppPickerComponents.kt:325-462 |
| 35 | masterDisabledMessage 五级引导链 | ui/components/RuleListSharedComponents.kt:463-477 |
| 36 | 分页跳转对话框（1..totalPages） | ui/components/RuleListSharedComponents.kt:228-274 |
| 37 | dataset→prefs 隔离 | data/RuleDataset.kt:18-30 |
| 38 | RuleSettingsAccess 三分派 | ui/settings/RuleSettingsAccess.kt:21-100 |
| 39 | 路由 dataset 解析（EXPRESS 默认） | SettingsRouteActivity.kt:56-64 |
| 40 | 规则控制四路由 isExpress 分派 | SettingsRouteActivity.kt:331-357 |
| 41 | 服务器模式三规则页入口（DNS_MODE） | server/ui/DnsSettingsScreen.kt:51-53, 122, 130, 138 |
| 42 | RuleUpdateNotifier 零调用 | core/rule/RuleUpdateNotifier.kt:18（全仓 grep 仅此命中） |

---

## 8. 关键发现（本会话确证）

1. **黑名单/白名单对话框的 `important` 是死参数**：Dialogs.kt:35/121（黑）与 :54/134（白）声明并原样传给 VM，但对话框内无任何控件修改它（全文无 Checkbox/Switch 绑定该 state）→ 添加恒 false、编辑原样保留；`important` 实际仅能经批量/订阅/引擎路径写入。
2. **RuleManagementViewModel 除镜像模板外全部无人消费**：`importRules/importHostsRules/addRewriteRule/rewriteRuleCount/loadRuleCount/activate` 零调用（§3-4），且 `MirrorTemplateScreen` 从不调 `activate`，`rewriteRuleCount` 恒 0 且无人读。镜像模板校验错误经回调字符串比较判成功（MirrorTemplateScreen.kt:277）——脆弱耦合。
3. **RuleUpdateNotifier 为死类**（§3-3 / 引证 42）：进度通知实际在 `RuleOperationWorker.createForegroundInfo` 自建；UI 进度完全靠 WorkManager progress 流。
4. **`SubscriptionViewModel.updatingSubscriptionId` 写了没人读**（VM.kt:73-74,545；屏读的是 importingSubscriptionId，SubscriptionScreen.kt:80）。
5. **并发翻页正确性四屏不一致**：RewriteList 用 `LatestRequestGate`（begin+主线程 isLatest 双检）；RuleList 仅 `pageJob?.cancel()`（注释自承同型缺陷，RuleListViewModel.kt:93-99）；Black/Whitelist 连 cancel 都没有（loadPage 不持有 job 引用）；四者都存在「旧请求覆盖新请求」残余窗口（cancel 无法覆盖已过最后挂起点的旧任务——这正是 LatestRequestGate KDoc 声明的场景）。
6. **覆写页搜索无防抖**（RewriteListViewModel.kt:124-127）与其余三页（250ms）不一致。
7. **白名单 `subscriptionTotal/Enabled` 统计字段被计算但从未渲染**（loadStats VM.kt:125-126；WhitelistComponents.kt:35-57 三分支均不含）。
8. **`effectiveEnabled` 的 masterEnabled 语义跨屏不同源**：黑/白=域名主开关与地址规则就绪（`isMasterEnabled/isAddressRulesOperational`）；覆写=按 target 类型分流 IPv4/6→域名主开关、CNAME→`isCnameRewriteOperational`（VM.kt:250-251）；DNS_MODE 下 `isAddressRulesOperational` 恒 false（RuleSettingsAccess.kt:41-44）→ 服务器模式黑名单里 URL/元素行**永远显示半透明未生效**（虽然 chips 已隐藏这些类）。
9. **RuleListScreen 的 Switch 在主开关关闭时静默吞点击**（Screen.kt:143-148），而黑/白/覆写三屏同场景 Toast 引导——交互不一致。
10. **订阅删除的伪反馈策略**：UI 先本地移除行（`deletingSubscriptionIds`，VM.kt:410-411,102），失败再 `loadSubscriptionsIntoState()` 回滚（:435-438）——依赖 Room 流与手动写竞态，重构需保「删除中即消失、失败复现」。
11. **AddSubscriptionScreen 双入口**：路由 `ADD_SUBSCRIPTION`（SettingsRouteActivity.kt:466）与内嵌 `showInlineAddScreen`（SubscriptionScreen.kt:62-70,93）并存，内嵌版无初始 kind、无 dataset 传参差异（两路径 VM key 不同）。
12. **SAF 授权生命周期**在 UI 层三处成环：take@pick（AddSubscriptionScreen.kt:94）/take@enqueue（VM.kt:174）/release@import 完成（RuleManagementViewModel.kt:88-90,180 已死；活路径 releaseIfPersisted 在订阅删除 VM.kt:418-428）+ `SafGrantDecisions.releasesOnPick` 回收换选/拒收的陈旧授权（:97-102）。
13. **服务商校验是双层双份**：Screen 侧 `isProviderInputValid/isProviderAddressValid`（纯函数，控制按钮态）+ VM 侧 `validate()`（消息文案），同规则两套实现（ProviderManagementScreen.kt:173-208 vs VM.kt:152-192）；DOH 协议强制 port=853 常量（VM.kt:195）。
14. **手动更新无取消路径**：本域文件对运行中 WorkManager 任务只有观察（getWorkInfoByIdFlow），无 cancelWorkById/取消 UI；busy 期间顶栏与行按钮禁用但入队可继续 APPEND（enqueue unique APPEND_OR_REPLACE）。
15. **应用规则四类的互斥是「保存时清洗」而非「勾选时清洗」**：仅 AppRuleViewModel.addAllowlistDomain 在输入时清三集合（:318-320），三个 AppPicker 屏在 onSave 时互相剔除（BlockedAppsScreen.kt:52-54、ExcludedAppsScreen.kt:46-48、HttpInspectionAppsScreen.kt:41-43）——同一应用可**同时**处于勾选多个列表的状态直到任一次保存。
16. express 功能面裁剪以**数据白名单**实现（`EXPRESS_SUPPORTED_FEATURES`，ExpressHiddenFeaturesScreen.kt:38-66），覆写名单/APP_RULES/BLOCKED/EXCLUDED/HTTPS 检查不在其中；但 `REWRITE_RULE_LIST` 路由本身未被 express 拦截——裁剪仅在入口层，重构时勿只移入口不移路由（本域未确证 express 下直达路由的行为，标**待定**）。

---

## 9. 「待定」清单

1. 本域文件**零正则字面量**（全部 Regex 命中来自 MirrorFormatGuideScreen.kt:144/183 的展示高亮与列表序号判断）；格式/冲突/去重的真判据在 core/rule 引擎 → 见第 02 章。
2. `BatchRuleClassifier`（域外）是否与单条 `addRule` 校验完全等价——本域未读该文件，待定。
3. `RuleScope` 非 DNS 值在本域的实际使用：`RuleListViewModel` 接受 `ruleScope` 参数、`SubscriptionViewModel.activate(ruleScope)` 透传，但 SettingsRouteActivity 各调用点默认 `RuleScope.DNS`；`ADDRESS_RULE_MANAGEMENT` 路由是否曾以非 DNS scope 进入本域屏——未发现直接证据，待定。
4. express 直达 `Routes.REWRITE_RULE_LIST`/`APP_RULE_MANAGEMENT` 的兜底行为（入口裁剪 vs 路由可达性）需真机/路由表进一步验证。
5. `ProviderSelectionDialog` 中 `onActionClick` 在单选版被复用为 `onProviderSelected`（含虚拟行 id 判定在宿主 MainScreenContent.kt:258-263），极速首页同型（ExpressHomeContent.kt:267-290）——两宿主回调差异细节属首页域（第 03 章）。
6. 域名处置弹窗的 `pendingRuleScope` 在非 DNS scope 下是否会取到 HTTPS scope 值（RequestLogScreen.kt:117,291 只见 DNS 赋值），待定。

---

## 10. Flutter 重构注意（仅列本会话确证项）

1. **屏→Widget 切分建议**：每屏拆「Scaffold/路由参数 / 列表主体（stats 卡+搜索行+chips 行+分页列表）/ 对话框族」三层，与 Compose 文件边界一致；`RuleStatsCard/RuleSearchField/RuleFilterChipRow/RuleListPaginationBar/RuleListEmptyState/RuleItemActionsMenu/masterDisabledMessage`（ui/components/RuleListSharedComponents.kt 515 行）全部是**无状态复用件**，直接映射为 Flutter StatelessWidget/子组件；`CascadeDropdownMenu`（级联菜单）在 Material 3 Flutter 无原生对应，需自研 overlay（黑名单/白名单顶栏、行操作、应用列表过滤/排序三处依赖其级联语义）。
2. **dataset 参数化保留**：三套 Room DB ↔ Flutter 侧同样以 dataset 枚举选 Dris 库/prefs 命名空间（`RuleDataset.prefsName()`），**VM key=`"<屏>_${dataset.name}"` 的按-dataset 单例语义**必须保留（同一进程内返回栈多页共享 VM 实例的行为依赖它）。
3. **分页方案**：本域规则列表 = offset/limit 手动分页（pageSize 100 + 页码跳转对话框），仅 DNS 缓存/日志用 Paging3；Flutter 侧建议 `PaginationController`/`InfiniteScrollPagination` 组件实现手动分页族，**不要把本域列表改造成 PagingSource 语义**——混排（内存 URL/元素列表 + SQL 域名页）的 `drop/take + 补位` 算法（BlacklistViewModel.kt:176-195 等）需原样移植并**统一补上 LatestRequestGate 等价物**（发现 5），否则迁移会固化旧竞态。
4. **对话框语义保持点**：① 添加/编辑框的 inline `error = err.message ?: fallback`（失败留在框内、成功 Toast+关闭）；② 风险确认链（白名单编辑权限、全外联、清空、删除订阅/分组）不可降级为 snackbar；③ `RuleConfirmDialog` 先 onConfirm 后 onDismiss 的顺序（组件注释明示，RuleListSharedComponents.kt:392-395）；④ 服务商编辑的「先 inline 地址错误、后放行保存」两段式；⑤ neutralButton「批量添加」跳转语义（AppAlertDialog 三按钮槽布局约定）。
5. **搜索防抖统一 250ms**（含发现 6 的覆写页补齐）；`rememberDebouncedValue` 是通用件，Flutter 用 debounce stream 等价实现即可。
6. **WorkManager ↔ Dart**：订阅/导入的进度（current/total/operationMessage）与 `APPEND_OR_REPLACE` 串行队列语义、`getWorkInfosByTagFlow` 双 tag 合并是 UI 唯一后台真相；Flutter 端保留同一 work 协议（类型枚举+progress keys），不可改为自建 isolate 队列——第 02 章的 Worker 链是既定事实。
7. **应用选择器**：`rememberAppListAccessState` 三态机（告知→授权→降级重试）含 ON_RESUME 复查与缓存失效，Flutter 需以 `PermissionHandler` + AppLifecycleState.resumed 监听复刻；`loadInstalledApps` 全量扫描在正常路径只做一次（Remember 态），列表过滤在 `Dispatchers.Default`——对应 Flutter 应放 `compute()`。
8. **单应用规则面板**：footer-LaunchedEffect 式滚动加载（进入视口即取下一页）依赖 Compose item 组合时机；Flutter 用 `ScrollEndNotification`/visibility_detector 重建等价触发，并保留 `loadedPackage`/双 loading 守卫（AppRuleViewModel.kt:186-222 的串页防护）。
9. **两模式规则控制页**：差异是**结构性**（URL 卡/联动/覆写字样整块不存在）而非 dataset 条件渲染——Flutter 应做两个页面类共享子件，不要合并成带大量 `if (isExpress)` 的单页，避免复刻当前 RuleControlScreen 里的 dataset×模式双维判断。
