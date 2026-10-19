# AGENT_MISTAKES.md

> 每条含「现象 → 根因 → 教训」，只留能改变后续决策的信息；同源条目已合并，被证伪的做法以「反例」并入。

## 通用铁律（跨条目去重）

1. **期望源**：协议/布局以规范样例向量为准；测试红先分辨「期望错 vs 代码错」，禁止改被测代码让测试变绿；位段先手写逐位表（含跨字节拆分）；解析器先列「像但不合法」负例（`[::1]:53`、`256.1.1.1`、`2001:db8::1::2`）。
2. **可达性**：严重度 = 缺陷机制 × 可达面。双向 grep caller（Go 导出方法 → gomobile → Kotlin 调用点，含接口注入/默认构造）并查设备/模式门；legacy/平行实现须证明「在生产被执行」。判「会执行」须走完整控制流（`if`/循环守卫与跳转目标）；崩溃类高危先找「为何现场没炸」反证。
3. **代理结论零权重**：子代理的「已确认/高危」逐条回读源码到调用链两端，组合主张拆条验；计数与规模自己数，「实测 N」须来自本会话工具输出；核验对象是它的位表/判据本身。报告未到手=零信息；复核批按 6–12 条切，含「待定」立即拆小批重派。
4. **归因顺序**：先 `git show HEAD:<file>` 确认基线，别把「我以为它没做」当事实；据错判写的改动整体回退。判「问题不存在」须显式走一遍「发生路径」——「代码保留了 X」通常证明 X 会被后续流程消费，而非证明无害；「机制成立但修它不划算」记「本轮不改」，不得记「证伪」。
5. **交付自证**：多文档分类用脚本 set 差集证明互斥；清单声明口径与扩展名；误报/撤回留痕，编号不复用；补「对称性差距」前先确认被对标那半真被消费（无人渲染的字段照抄只会放大死代码）。
6. **产物时序**：AAR/jar/exe 只在源码定稿后重建：改源码 → `gofmt`/`go vet`/`go test` → 构建 → 目标平台编译/单测/启动验证；不以退出码 0 或单文件可读为完成标准；`.vue` 改动须跑含 `vue-tsc` 的完整构建。
7. **仓内优先**：列「需外部取证」前先搜源码、测试、仓库注释——作者注释比记忆更硬；判「无法修」前查完平台 API（「模型缺字段」常意味着「该换判据」），以「需加 DB 字段/迁移」为由放弃须附「已排除的替代判据」。

## 事件记录（时间倒序）

### 2026-10-19: 「并行流停滞 2 小时零页面」+ `searchState.query` 让整页隐身 + widget 测试断言选错标尺

- **现象/根因**：
  1. **子代理停滞的空转识别太晚**。proxies-ui 交付数据层 276 行 + 状态层 516 行后停滞约 2 小时，期间零页面产出，最后是我主动 `interrupt_agent` 才止损。当时它已交的两份产物**零消费方**——`dart analyze lib` 全绿只证明可解析，运行时行为一次都没被执行过。教训：**并行流的完成判据是「有消费方且测试跑过」**，不是「文件存在且 analyze 绿」；超过一轮没有新文件就该主动查它卡在哪，而不是等它自己报。
  2. **`AppBarSearchState` 传非空 `query:` 会把整页藏掉**。`CommonScaffold` 用 `searchState.query != null` 判「当前是否在搜索模式」（`scaffold_a.dart:13` 的 `_isSearch`），而非「搜索词的初值」。我在代理页把 provider 里的当前搜索词回灌给顶栏，结果一进页面就展开搜索框、标题和所有分组全部不渲染。**analyze 绿、路由可达测试也绿**（页面确实 build 了，只是 build 出的是一根搜索框）。抓法：`find.text('代理')` 为 0 而 `find.byType(CommonScaffold).widget.title == '代理'`——「组件属性对、屏幕上没有」这个组合只在「组件被另一分支替换掉」时出现。
  3. **widget 测试断言选错标尺，把设计意图当成 bug**。我在代理页断言「第二个组的组名不存在」，实际顶部 chip 条本来就列出所有组名（那是切换入口）；又断言「过滤后选中节点不存在」，实际组头始终显示该组的当前选中节点（那是组的属性，不随搜索变化）。两次都是**先猜再测**，而不是先看清哪些文字由哪个 widget 承载。正确做法：断言用一个**只可能由目标控件承载**的字符串（这里是非选中节点名），而不是顺手抓一个在场字符串。
  4. **顶栏 `iconActions` 会被静默折进「更多」菜单**。`_maxBarButtons`/`_maxGroupedActions` = 2，页面自己占一个动作后，加进去的 `iconActions` 就不在栏上了。测试里 `find.byTooltip('测速全部')` 找不到是**设计行为**，不是缺陷；应该改测组内入口，或从「更多」菜单点。同理 `Tooltip` 在无头测试里不一定建出可命中节点，`find.bySemanticsLabel` 比 `find.byTooltip` 稳。
  5. **`pumpAndSettle` 会吞掉「短暂中间态」**。测速是 `Future.delayed(900ms)`，`pumpAndSettle` 推帧直到静止，一次就把 900ms 走完，「测速中」那一帧永远观察不到。要观察中间态必须 `pump()` + `pump(短时长)`，把 `pumpAndSettle` 留给最终态。
- **教训**：① 子代理交付判据加「有消费方 + 交互测试」，停滞一轮即主动查；② `AppBarSearchState.query` 是「模式开关」不是「初值」，代码里写注释挡住复发；③ 先读承载 widget 再写断言，别拿在场字符串当标尺；④ 折叠/裁剪类容器（顶栏、`Wrap`、`ListView`）里的 `findsNothing` 先确认是「没渲染」还是「折进去了」；⑤ 中间态观察用定步 `pump`，终态用 `pumpAndSettle`；⑥ 探测脚本（`test/probe*_test.dart`）用完立刻删——遗留文件会让全量 `flutter test` 变红。

### 2026-10-19: 三类「analyze 全绿、运行时才炸」的缺陷 + GoRouter 未匹配路由静默放行

- **现象/根因**：
  1. **手写泰勒级数近似 `sin` 在大参数下发散**。为「不想为一行数学引入 `dart:math`」写了 7 阶泰勒展开，输入到 `2π×t×3.7`（t 到 60 量级）时误差爆炸，速率算成 `6,582,849`，`ui/line_chart.dart` 的 `slopesOf` 里 `.clamp(-3v, 3v)` 因此拿到 `lower > upper` → `ArgumentError: Invalid argument(s): 6582849.66`。**analyze 完全看不见**，只有在 widget 测试里真正 `paint()` 才炸。同一 commit 里我在两处各写了一份 `_sin`（数据层 + 卡片 `CustomPainter`），所以两处都要改。
  2. **无限动画让 `pumpAndSettle` 永远超时**。首页速率曲线用 1 秒 `Future.delayed` 自循环 + `profiles_card` 波浪进度条 `AnimationController..repeat()`。`pumpAndSettle` 的前提是「没有待处理帧」，两者不可兼得——表现是 `pumpAndSettle timed out`，栈里只有 `LineChart`，**看上去像路由/scope 问题，实际是动画**。`CommonCircleLoading`（`ui/loading.dart`）与 `ui/skeleton.dart` 也是永久 `repeat()`，只是它们只在加载态出现才没炸。
  3. **`GoRouter` 对未匹配路径不抛异常**。它渲染 `errorBuilder`，我没设 `errorBuilder` 时是一片空白；更糟的是「每条路由都能 build 且不 throw」这类用例**对漏注册的路由静默放行**——本轮 `/proxies` 就是这么一路绿到最后一轮全量扫描才被抓到的。给路由器加 `errorBuilder: UnknownRoutePage` 后，测试改成同时断言 `find.byType(UnknownRoutePage) == findsNothing`，漏注册立刻变硬失败。
  4. **固定像素高度的卡片在 1.4 倍字号下溢出**（`feature_hub_page` 92dp 卡片溢出 6dp）。横向同理：`Row` 里放三组「标签+数值」时 320 宽下溢出 36/130dp。
- **教训**：
  - (a) **永不手写三角函数/超越函数的近似**——`dart:math` 就在标准库里，「省一个 import」换来的是 analyze 查不出、只在 paint/test 阶段炸的数值缺陷。凡是「数学近似」都要问一句「参数域上界是多少，近似在那里还成立吗」。
  - (b) **演示用的永动动画必须有全局关闭开关**。本仓约定：`debugDisableDashboardLiveUpdates`（`lib/state/dashboard_providers.dart`），测试统一走 `test/support/test_hooks.dart` 的 `installGlobalTestHooks()`。新加任何 `repeat()` / 自循环定时器前先想「`pumpAndSettle` 还能过吗」。
  - (c) **「没抛异常」不等于「路由存在」**：任何「每个路由都能构建」的测试，都必须同时排除兜底页，否则用例只证明「GoRouter 能把请求导向某处」。
  - (d) **固定尺寸容器 + 可放大文字 = 潜在溢出**：高度用 `textScaler` 线性放大，横向多列一律 `Expanded` + `ellipsis`，不要指望 `Text` 自己收缩。
  - (e) 长测跑完看到一堆 `pumpAndSettle timed out`，先 `grep -r "\.repeat("` 与「自循环 `Future.delayed`」，比逐页找布局问题快得多。

### 2026-10-19: 并行流里跑 `dart format` 误伤同伴文件；`-replace` 改测试文件把结构改坏

- **现象/根因**：(1) config-ui 在收尾时对 `lib/state`/`lib/` 整体跑了 `dart format`，把 `appearance/rules/subscription/work_mode_providers.dart` 一并改写（纯格式差异），只能 `git checkout --` 逐个还原。并行开发的写域隔离在**工具层没有被强制**——`dart format`、`dart fix`、代码生成器都按目录工作，不受「我只负责这几个文件」的约束。(2) 我用 PowerShell `-replace` 给三个测试文件的 `void main() {` 插入一行调用，替换串里含 `$` 与换行，反向引用被解释，直接把 `app_shell_test.dart` / `layout_regression_test.dart` 改成语法错误（`missing_function_body`、`duplicate_definition`），只能从 git 恢复重做。
- **教训**：(a) 并行阶段禁止任何**目录级**格式化/批量改写命令，只对自己负责的文件列表显式逐个跑。(b) **改代码用 edit/write 工具，不要用 PowerShell 正则替换**——`-replace` 会把 `$1`、`$&` 当反向引用，多行替换里 `\r\n` 还会错位；只有「确定不含 `$` 与正则元字符的单行字面替换」才勉强可用，而这条判断本身不值得做。(c) 已提交的文件被改坏时别试图修补，直接 `git checkout --` 回基线再重做一遍，比修语法错误快。

### 2026-10-19: 把「网络不可达、Android 构建跑不通」当成事实引用了三轮（实际全 200）
- **现象/根因**：`README.md` 与 `20-handoff.md §6` 都写着「`services.gradle.org`/`repo1.maven.org`/`plugins.gradle.org` 全不可达，仅腾讯镜像 200，因此 `flutter build apk` 无法完成」，并在三轮交付里被当作既定事实复述。**实测全部 200**，`gradle-9.3.1-all.zip`（224 MB）、NDK 28.2（约 2.1 GB）、SDK Platform 36、AGP 9.1.0/Kotlin 2.4.0 依赖全部下载成功，`flutter build apk --debug` 产出 157 MB APK。同时还有第二个假象叠加：命令写成 `flutter build apk --debug 2>&1 | Select-Object -Last 40`，`Select-Object -Last` **缓冲全部输出直到进程结束**，中间十分钟一个字节都不显示，主观上完全等于「卡死」，于是又反过来「印证」了网络不可达的结论。
- **教训**：(a) 判「网络不可达」必须用 `curl`/`Invoke-WebRequest` 打**真实构件 URL**，不能打域名根路径——根路径 404/400 是正常的（`dl.google.com`、`storage.googleapis.com` 都如此），把 404 当「不可达」会直接得出反向结论。(b) 文档里的环境类结论**有保质期**，引用前必须重测；「上轮记录的失败」不等于「本轮仍然失败」。(c) 长任务跟进度一律写日志文件 + `Get-Content -Tail`（或 `Start-Process -RedirectStandardOutput`），**禁止用 `Select-Object -Last`/`Tee-Object` 之类会缓冲的过滤器**——它们会让「慢」看起来像「死」。(d) 首次 Flutter Android 构建要下约 3 GB（Gradle + NDK + SDK + 依赖），必须区分「一次性环境准备」与「真的卡死」，判据是看 Gradle 守护进程 CPU 是否在动 + `build/app/intermediates/` 是否在长。
### 2026-10-19: 枚举上屏变源码字形（`ProviderProtocol.doh`）+ 分组标题与滑杆标签同名
- **现象/根因**：(1) 设置页「解析服务商」副标题由 `providerEndpointOf(id)` 生成，实现里拼的是 `'${provider.protocol} · ${provider.address}'`——`ProviderProtocol` 没覆写 `toString`，于是 UI 上真的显示 `ProviderProtocol.doh · https://…`。**这个缺陷在 analyze 与「路由能构建」两类检查里都是绿的**，只有把页面文字 dump 出来才看得见。同仓 `home_page.dart:311` 早就写对了（`provider.protocol.label`），是我照着「同一工具函数」复用才带进来。(2) `HomeLayer.poem` 的标签就是「首页句子」，而我给设置分组也起名「首页句子」→ 同屏两个 17pt 标题，一个在 `ListHeader` 里（13pt）、一个在滑杆卡里，肉眼看不出谁是分组。
- **教训**：凡是把枚举/对象插值进 `Text`，先确认它的 `toString` 被覆写过或显式取 `.label`——编译器、analyze、路由冒烟**三类检查都拦不住**这类问题；复用「现成的工具函数」前读它的实现，别只看名字；自测时把整页 `Text` dump 一遍（`for (final e in find.byType(Text).evaluate())`）比只断言几个关键文案更能抓到这种字面错误；同一屏内的标题文案必须唯一，分组名要给控件标签让位。

### 2026-10-19: 长设置页自测：`scrollUntilVisible` 三重失效 + 浮条遮挡导致 tap 落空
- **现象/根因**：给 `lib/pages/settings` 写交互自测时连续踩三坑：(1) `scrollUntilVisible(find.text(x), 300)` 在页面里有多个 `Scrollable` 时抛 `Bad state: Too many elements`；(2) 传入 `scrollable:` 后仍失败，因为**底栏项一改动 shell 会重建**，缓存的 `ScrollPosition` 失效，`jumpTo` 静默失效后循环到上限即 `fail('滚不到')`；(3) 目标行滚到视口边缘时 `tap()` 报 `derived an Offset … that would not hit test`，命中点落在固定的 `NavigationDock` 上（浮条盖住底部约 100dp），而 `tester.ensureVisible` 认为「已在视口内」不会再挪。
- **教训**：长页自测统一用「每次循环**重新取** `ScrollableState.position` → `jumpTo(pixels ± step)` → `pumpAndSettle`」的粗扫，别缓存 position；命中后再按 `tester.getRect(row).center.dy - 视口中线` 微调一次，把行挪到中部避开浮条；`find.text` 会同时命中页面行与底栏标签（`BottomBarDestination.label` 与设置行同名），断言前先用 `find.descendant(of: find.byType(ListView), …)` 排除浮条；自测脚本放 `tool/` 下（不进 `test/`）跑完即删，避免污染交付的测试集。

### 2026-10-19: 设计系统 API 三处「按直觉写就报错」（primaryAction 类型 / 具名构造的类型参数 / 同屏重复文案）
- **现象/根因**：(1) `CommonScaffold.primaryAction`/`confirmationAction` 收的是 `IconButtonData`（顶栏图标按钮），不是 `Widget`；传 `FilledButton` 直接 `argument_type_not_assignable`。需要可见文案的主按钮（如「导入 N 条」）得放进 `body`，顶栏只能放图标 + `tooltip`。(2) `ListItem.options` 是泛型类的**具名构造**，类型实参写在类名上——`ListItem<RuleKind>.options(...)`；写成 `ListItem.options<RuleKind>(...)` 报 `wrong_number_of_type_arguments_constructor`，报错文案不会提示该改位置。(3) 计数头写「空时显示『没有匹配的规则』」，同时 `NullStatus.label` 也是同一句 → 同屏两份完全相同文案，既是视觉重复也让 `findsOneWidget` 失败。
- **教训**：写组件前先 `Select-String` 读构造签名，别按「应该是 Widget」推断；泛型类的具名构造类型参数一律前移到类名；空状态文案与计数头文案必须分工（一个报数字、一个说原因），否则同屏重复且不可断言。

### 2026-10-19: Flutter 页面自测四坑（同名文本 finder / 浮层读不到 scope / sheet 首屏溢出 / 并发编译失败归因）
- **现象/根因**：(1) `SegmentedControl` 视图标签「缓存」与 `TonalChip(LogAction.cached.label)`（也是「缓存」）同屏 → `find.text('缓存')` 命中 12 个，`tap()` 抛 "Found 12 widgets"；标签文案必须与同一屏内的枚举文案去重（改为「缓存表」），不能靠 `.first` 掩盖。(2) **浮层里读 `ViewScope`/`MeasureScope` 会 assert**：`showSheet`/`showFloatingDialog` 的监听器挂在根 `Navigator` 上，是与 `home:` **平级**的兄弟路由，所以 `home:` 里装的 scopes 覆盖不到浮层内容，`ViewScope.isMobileOf` 立刻 `Failed assertion: 'scope != null'`（本会话已用对照 probe 钉死，见 `test/scope_placement_test.dart` 两条用例）。正确做法是 scopes 装 `MaterialApp.builder`——它的 `child` 就是 `Navigator` 本身，scopes 因此在 Navigator 之上。另注：`SheetOverhangScope` 的 `of`/`fillsDetentOf` 都是**空安全**的，它不是 assert 来源，别把它当元凶。(3) 临时测试文件放仓根时 `import 'support/app_host.dart'` 解析失败，必须放进 `test/`。(4) `tester.pageBack()` 找 `CupertinoNavigationBarBackButton`，本工程 sheet 的关闭按钮是 `GlyphIcon`，一律用 `Navigator.of(element).maybePop()`；`scrollUntilVisible` 在 finder 命中多个可滚动区时抛 `Bad state: Too many elements`，限高后直接断言可见项更快。(5) 面板里 6 行服务商列表把「发起查询」挤出首屏 → 次要选项改横向 chip 行。(6) `flutter test` 报 `lib/pages/server/server_page.dart: Error: The method '_showUpstreamSheet' isn't defined`——那是并行代理正在改的别人的文件，**编译期失败先看报错文件是否自己的**，等 30–60s 重试即可，不要动手改。
- **教训**：同屏文案唯一性是可测性前提（也是可用性前提）；「能弹出 / 浮层能渲染」类用例必须用真实 App 路由壳（`DitingApp(initialLocation:)`）或在 `builder` 装 scopes；断言「某 scope 缺失」前先读它的 `of()` 是不是空安全——空安全的 scope 永远不会 assert；行数统计用 `(Get-Content $f).Count`（`Measure-Object -Line` 跳过空行，见 2026-10-18 条）；并发工作区里编译错误先归因到文件归属，再决定等或改。

### 2026-10-19: 宿主层级结论两次翻车（先误判「必须 home:」，再误判「两种都行」）+ zh_CN 缺 MaterialLocalizations + 构建产物受网络所限
- **现象/根因**：(1) **这条结论本身被推翻过两次，最终定论见下**。第一版说「scopes 装 `MaterialApp.builder` 会让浮层报 `Navigator operation requested with a context that does not include a Navigator`，必须放 `home:`」。我据此做了「对照实验」并宣称两边都无异常、于是判定第一版「证伪」——**但那次实验本身是无效的**：探针内容用的 `CommonCard` 恰好没走 assert 路径，于是两边都「通过」。两路代理随后各自撞到真实失败，我改用**会真正 assert 的读法**（浮层内容里调 `ViewScope.isMobileOf`）重测，才得到确定结论：`home:` 装法下浮层内 `Failed assertion: 'scope != null': No ViewScope found above Builder(dirty)`；`builder` 装法正常。**定论：scopes 必须装在 `MaterialApp.builder`**（其 `child` 就是 `Navigator`，scopes 因此在 Navigator 之上，路由与浮层都能拿到），`home:` 只覆盖首个路由、浮层是它的兄弟路由所以覆盖不到。已用 `test/scope_placement_test.dart` 两条用例（正例 + 故意复刻错误装法的反例）钉死。(2) `DefaultMaterialLocalizations` 只带 en_US：`locale: zh_CN` 时 `AppBar` 直接抛 `No MaterialLocalizations found`（先有一条 "locale not supported by all delegates" 警告）。zh_CN 必须用 `material_ui` 里 intl 生成的 `GlobalMaterialLocalizations.delegates`（它同时含 Cupertino/Widgets 三个 delegate）。(3) `LocalizationsDelegate.load` 是异步的，`pumpWidget` 后首帧渲染为空，直接 `expect(find.text(...))` 必红；补一次 `pump()`。(4) `lib/ui` 的 `UiLocalizations.of` 是 `assert` 而非默认值，缺 delegate 时在 build 期崩溃。(5) `flutter build apk` 失败真因是 `services.gradle.org`/`repo1.maven.org`/`plugins.gradle.org` 全不可达（仅腾讯镜像 200），本地缓存的 gradle-9.4.1-bin 与 flutter 插件所需的 `kotlin-dsl 6.5.2` 都不全；把 wrapper 指向镜像属改工程配置，未获授权不得自行改。
- **教训**：(a) **「对照实验没复现」不等于「缺陷不存在」**——探针必须先证明自己处在会被触发的路径上（这里要用会 assert 的读法，而不是「能渲染就算过」）；负结果要连同「探针为什么足以触发」一起写，否则假阴性会被当成证据写进文档，比不测更坏。(b) 同一个结论被推翻两次后，不要再靠推理定论，直接把不变量写成**正例 + 反例两条测试**钉住（`test/scope_placement_test.dart`）。(c) 凡 `MaterialApp` 带非英文 `locale`，先确认用了 `GlobalMaterialLocalizations`。(d) 测试宿主 `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 的 scopes 装法必须一致，改一处就要同步另一处。(e) 构建失败先 `curl` 逐个探域名，把「环境不可达」与「代码坏」分开写进交付说明，不拿退出码当结论。

### 2026-10-18: 三次「问题不存在」初判被自己推翻（A-096/A-100/O-107）
- **现象/根因**：A-096 称「`finally` 只删本线程 temp」，实为两个 `Mapped*Index` **无条件** `temp.delete()`，缺的只是残留清扫（`RuleIndexLayout.deleteAll` 零调用）⇒ 应判「成立但不改」；A-100 拿「`editRule:444` 保留 `SOURCE_PRESET`」当反证——正因保留，升级时 `deleteBySource(SOURCE_PRESET)` 才删掉用户改动；O-107 真因不是 `DnsCachePolicy:34-35`（`<=0 return 0` 正确），而是 `log_aggregator.go` 的 `json:"ttl,omitempty"` 删掉 TTL=0 的键 + `recordResolved` 用 `<=0` 合并「真实 0」与「未知」（基线早有 `notifyLogWithTTL`）。
- **教训**：结论若是「因此不会发生」，先把发生路径写出来走一遍（铁律 4）。

### 2026-10-18: 照抄他人的 `Stop()` 早退守卫会回归同轮已修项（O-104 vs A-017）
- **现象/根因**：给 `Engine.Stop()` 加 `if !e.running { return }` 修 O-104，会让空闲期不再释放 `dnsCache`/`stackCertMgr`，**回归同轮刚修的 A-017**；改用 `sessionGen` 代际判定后两件事同时成立。
- **教训**：采纳外部修复建议前先算它对其他已修项的影响面；守卫条件要表达「是谁」（代际/身份），而非会被下个会话重置为真的状态位（`running`）。

### 2026-10-18: 词法截断改「搜索起点」换来新回归；死分支用「单原子」近似（A-095/O-133）
- **现象/根因**：首版把 `indexOf('#')` 改成「从正则字面量闭合 `/` 之后搜」，`/ads#banner/` 修好了，但 `@@/ads#banner/ # keep this` 的真注释被跳过 ⇒ 合法 allow 规则被判 unsupported；改为「`#` 在行首或紧跟空白才开注释，仅当前导正则字面量**体内**时跳过」后两输入同时成立。之后的「优化」版在 606 组差分用例上 0 差异 ⇒ 属等价重写，已回退。O-133 死分支：按「只含单个 `text.` 谓词」得 8 个、按合取蕴含得 14 个、triage 文档 13 个（含错项 108/119、漏 49/72/83/84/106），三者互异。
- **教训**：词法缺陷的判据是「什么字符序列构成注释」而非「从哪里开始找」——改起点等于重定义词法，先列「旧行为必须保持」的回归用例；声称有缺陷前用差分用例证明两版**不等价**；`when` 可达性须逐原子蕴含且 `text` 参数同一，先排除 `||`/`in`/正则等非原子内容。

### 2026-10-18: 先入为主复述「fgRequired 被重新武装」的相反结论（AOSP 取证）
- **现象/根因**：把冷启动崩溃根因写成「`stop()` 里 `startService(stopIntent)` 把 `fgRequired` 重新置 true」并已写进注释；回读 `ActiveServices.startServiceInnerLocked:1196` 的 `r.fgRequired = fgRequired;` 才知该值来自**调用方 API**（`startService`→false、`startForegroundService`→true），故它是**清除**义务。真凶是同 `stop()` 里的 `stopService()`：置 `startRequested=false` 后经 `bringDownServiceIfNeededLocked`（`mPendingServices` 无记录，走 `r.app != null` 分支）到 `bringDownServiceLocked`，`fgRequired` 仍 true ⇒ 立即 `SERVICE_FOREGROUND_CRASH_MSG`（三次崩溃 uptime≈520ms，远小于 30s，可排除 timeout 路径）。
- **教训**：「某调用把标志设为 X」须回读到**赋值右值来源**，不能凭调用名/action 推断；崩溃归因用日志时间轴反向验证；修复方向被证伪后先改注释再改代码。

### 2026-10-18: 过早断言「受模型限制无法修」+ 把死字段当差距（A-083）
- **现象/根因**：判「订阅删除侧无法修，因 `SubscriptionEntity` 无『是否持久化授权』标志」，而 `ContentResolver.getPersistedUriPermissions()` 即权威来源；同轮差点把 `WhitelistStats.subscriptionTotal/Enabled` 复制到 `BlacklistStats`「补差距」，实测白名单侧这两个字段**从未被任何 UI 渲染**。
- **教训**：见铁律 5、7；未覆盖项要区分「确实做不到」（写进限制）与「当时没想到」（回头补）。

### 2026-10-18: 并发 Gradle 撞 KSP 缓存；期望错/代码错未分辨；行数口径错
- **现象/根因**：5 个子代理并行跑 `gradlew`，反复 `IllegalStateException: Storage for ...kspCaches\...\file-to-id.tab is already registered`，被误判为「代码坏」并各自重试；7 个首轮失败里 `DohUrlParserTest`（期望错）与 `LatestRequestGateTest`（代码错）处置相反；子代理用 `Measure-Object -Line`（**跳过空行**）统计行数，系统性偏低 6%–15%；我按「分支 9 兜底没生效」指挥修复，实际卡点在上游分支 5 把 `$~app=` 的 `=` 当重写箭头。
- **教训**：多代理共享工作区时**构建单点串行**由 Lead 统一跑，子代理只做静态自检与离屏单测；行数用 `(Get-Content $f).Count`；改前先定位**真实卡点分支**（同一输入会被多个前置分支截走）；分片修复出现「新用例反而红」常是抓到更上游的真缺陷，先归因再改。

### 2026-10-18: 身份判定误用 `==`（`LatestRequestGate`/`ActiveHealthEngineRegistry`）
- **现象/根因**：`isLatest` 用 `latest == request`，请求是 `data class` ⇒ 结构相等 ⇒ 同参请求互等 ⇒ **旧请求被判最新**，废掉 A-051 的修复；同型错误用 `ConcurrentHashMap.remove(k,v)`（走 `equals`）在 `clearIfCurrent` 再次出现。
- **教训**：「是不是我注册的那一份」必须用 `===`；`data class` 承载「请求/令牌/代际」时假定有人误用 `==`，KDoc 写明并补「等值但不同实例」测试。

### 2026-10-18: `gofmt -l` 以 CRLF 误报为「格式未过」
- **现象/根因**：`gofmt -l .` 在 `Android/tunnel` 列出 63/76 文件；实为工作区 CRLF（`core.autocrlf=true`），`git show HEAD:<file>` 基线同样被列出。
- **教训**：判据改为「CRLF→LF 归一化后单独 gofmt，与基线比真差异行数」；**禁止** `gofmt -w` 整目录（会翻掉全仓换行符）。

### 2026-10-18: 解析器负例缺失 + 二进制产物早于源码定稿
- **现象/根因**：`isIpLiteral` 正例全绿却把 `2001:db8::1::2`（双压缩）判成合法 IPv6；A-076 补集、A-086 退避测试首败是期望错（`224.0.0.0/4` 应为 `/3`；40 次退避最坏约 2.4s，超测试超时）；AAR 在 `gofmt` 未过时重建，返工两次。
- **教训**：注入 N 次失败须按重试预算折算时间，长退避要有「降级态单次尝试即丢」分支；`gomobile bind -work` 可把生成 Java 与 `tunnel-sources.jar` 对比，导出 API 未变则无需重生成。

### 2026-10-18: 先落笔后取证：legacy 路径误判高危 + Edit 锚点凭记忆
- **现象/根因**：A-067/068/070/074 引证全落在 `Engine.Start`/`SetTries`/原生 trie+bloom 旧拦截路径，caller grep（含 gomobile/Kotlin/test）仅命中定义行，复核后三条判不存在（A-067 写序缺陷真实，降 Low）；A-089 写完才核出 `Engine.Start` 零生产调用者（Kotlin 只用 `startFull`/`startStandalone`/`startStackMitm`）；A-095 收录含已证伪分支的「`$$` 转义 + sinkhole」组合主张（`dnsrewriteIsBlock` 并不置 `dnsrewriteTargetType`）；`old_string` 用记忆中的上节结尾，两次 not found。另有 O-119「.aar 定版」伪缺口、O-148/O-121 计数各少 1、13 条子代理批只完成 1 条、三份分级文档重复收录 A-059。
- **教训**：见铁律 2、3、5；可达性引证与 Edit 锚点 grep 都在落笔前完成（`serveDNS` 被 standalone 与 full-tunnel 多入口共用 ≠ 路径无生产者）。

### 2026-10-17~18: 子代理「高危」未收窄即采信；位表/控制流核验方向反了
- **现象/根因**：D-01 从「minSdk 24 存在 UPSERT」跳到「24–29 全设备流量历史丢失」，实际唯一写入链 `TrafficDatabaseSyncer.flushPendingDeltas` 仅经 NORMAL 模式、UI 硬拦 API 29+，且 `DnsCacheDao.kt` 注释已写明 UPSERT 需 API 30；D-03 被三条独立事实证伪。同型：称 `query[2]=0x01` 写进 Z 位、`byte3|=0x80` 无条件伪造 AD，逐位展开（byte2 QR 0x80/AA 0x04/TC 0x02/RD 0x01、byte3 RA 0x80/AD 0x20/CD 0x10/RCODE）后确认代码正确，属误报；Room `isException` 迁移 `DEFAULT 0` 被判「升级即崩」，但 `defaultValueEqualsCommon` 被 `aload_2; ifnull` 守卫，实体无默认值时跳过校验。
- **教训**：一手版本表取不到时降级为「收窄后的触发面 + 标注待定事实」，交真机 logcat 定版，不按原 severity 入库；多代理并行扫描先对汇总表去重（Express IPv6 死代码、订阅 kind 失效应分别命中 A-012/A-030）。

### 2026-10-17: 构建链路三坑：WSL 无 Go、embed 依赖环、Vue key 类型
- **现象/根因**：(1) deb 预检只查 `wsl` 不查 WSL 内 Go，`go.exe` 在 WSL PATH 中也不被 `command -v go` 解析。(2) `frontend/embed.go` 的 `//go:embed all:dist` 要求目录非空，而 `wails generate module` 先编译 Go 包，形成「产物 → 绑定 → 前端构建 → 产物」环。(3) `:key="row"` 违反 `PropertyKey` 类型，`vue-tsc` 报 TS2322 中止桌面打包，且该修复只做局部验证。
- **教训**：(1) 跨子系统构建在实际环境内跑 `command -v`；交叉编译放宿主（`GOOS=linux CGO_ENABLED=0 go build`），WSL 只做 `dpkg-deb` 组装，验证到包内 ELF 执行 `--version`。(2) 冷启动固定顺序 `go mod download` → `npm install` → 占位 `frontend/dist/index.html` → `wails generate module` → `npm run build` → `wails build`，验证落到真实产物起窗。(3) 按对象身份稳定的 key 用 `WeakMap<object, string>`（`createRowKey`），不塞对象或退回下标；`git update-index --really-refresh` 消除 CRLF 假变更。

### 2026-10-17: 工具脚本两例：双击闪退与版本号伪变更
- **现象/根因**：维护工具箱缺 `requirements.txt` 与依赖探测，`ModuleNotFoundError: webview` 随窗口立即关闭；`get_file_targets()` 硬编码 6 个桌面文件，漏 Android Gradle、前端锁文件与 NSIS 模板，且 `re.subn` 返回 `n>0` 即视为变更，重跑不幂等。
- **教训**：GUI 启动脚本先探测依赖、缺失按清单安装，非零退出 `pause` 保留窗口，双击故障先在终端复现拿 traceback；版本目标清单按全仓声明点维护并跑全量 dry-run，是否修改比较新旧内容，Android `versionCode` 取 `max(旧值, major*10000+minor*100+patch)`，锁文件只改根节点与 `packages[""]` 并验证 round-trip。

### 2026-10-17: 批量修复中的跨模块契约陷阱（实现）
- **现象/根因**：编译与单测全绿仍漏三类：持 `p.mu` 调 `ReloadEncrypted` 后 `wg.Wait()` 等在途查询，单次保存卡死数秒；流水线按值捕获 `groupResolver`，热替换不生效；`os.WriteFile(_, 0o600)`/`os.Chmod` 在 Windows 只切只读位不设 ACL，路径大小写、systemd 相对 `ExecStart`、XDG 转义亦然。
- **教训**：锁内只做快照，锁外做重活（持锁不调 `wg.Wait`/网络/`time.Sleep`/回调）；长生命周期对象不按值捕获可热替换字段，改 getter 或 atomic 指针并同步构造点与测试桩；权限/路径/编码在目标平台实机验证（`icacls`、读生成文件），无法 CI 的差异用 `//go:build` 分包 + no-op 桩；拆分逼近 550 行文件须确认同包、import 无遗漏并重跑构建测试。

### 2026-10-17: 复核旧「实证」先审期望（RFC 6052 / 计数 / 假阴性）
- **现象/根因**：BUG-44 把对 RFC 6052 的同一误读写进代码与断言，后用规范 Table 1/2 六例对账全中；BUG-66 grep 计 14 处未剔除前置 `MaxBytesReader` 的 1 处（实 13）；BUG-35 因 `CacheConfig.Enabled` 未置 true 在闸门早退，复现假阴性；子代理称 `DaysRemaining` 无消费者，实际前端 `CertificateCard` 在用；另有 DNS64 手算期望全错、常量表达式验溢出编译失败。
- **教训**：见铁律 1、3；计数逐点带上下文（前后 3 行）并抽查 2–3 点；复现失败先怀疑 harness，为每条早退分支加断言；「无消费者」须 Go 与前端 camelCase 两查；同鉴权族实现不一致先疑孤立一侧遗漏；溢出验证走运行期（`strconv.ParseInt`/变量乘法），临时 `zz_tmp_*` 用完即删。

### 2026-10-16: 页面级 max-w 致单列卡片宽度不足（布局）
- **现象/根因**：6 个页面根容器遗留 `max-w-7xl`（1280px）/`max-w-4xl`（896px），与「单列卡片延伸到内容区边缘」冲突，页面本身不报错。
- **教训**：页面根容器不设 `max-w-*`，宽度交给 `main` 的 padding；`pb-12` 由 `views/*.vue` 统一负责；布局缺陷用 `getBoundingClientRect()` 量宽与 x/w，不看截图；Web 模式 `ui_capturer.py` 只截登录页，可用 CDP 注入伪 `window.go.main.App` 并设 `diting_ipc_host/port` 截真实界面（仅本地核对，不入库）；未覆盖 1280/1920 与 768–1024 折叠侧栏。

### 2026-10-16: 呼吸灯 infinite 动画拖垮 WebView2 GPU（性能）
- **现象/根因**：`.seal-pulse` 对 `opacity` 逐帧插值的 `infinite` 动画使合成器每帧重绘整个窗口，GUI 空闲时 GPU 17%–28%；开销只与出帧频率相关，与动画元素数量/大小无关。证据：`Get-Counter '\GPU Engine(*)\Utilization Percentage'` 按 pid 归因，最小化归零；A/B 基线 27.8% → 关全部无限动画 1.7% → 仅关 `seal-pulse` 3.2%；保留动画但关键帧数值恒定仅 1.95%。
- **教训**：`will-change`/`translateZ(0)`/`contain:strict`/改 `transform`/改 `background-color`/延长周期均无效；唯一有效杠杆是降低出帧数：`steps()` 后 1.4%–4.0%（`steps(2)`≈1.5%、`steps(4)`≈3.3%、`steps(8)`≈7.1%）；对 `infinite` 动画（含 Tailwind `animate-spin`/`animate-pulse`、`md-circular-progress indeterminate`）保持怀疑；未覆盖高刷/多显示器，观感未经人眼确认。

### 2026-10-16: 托盘 SetWindowSubclass 静默失败与时序补丁链（Win32）
- **现象/根因**：`SetWindowSubclass` 在本进程 Wails 窗口恒返 FALSE（`ret=0`、`GetLastError=0`），返回值被丢弃，子类过程从未安装；历史补丁用时间防抖、前台句柄比对、异步派发等时序启发式规避消息语义，必然吞点击、失效或丢前台令牌。
- **教训**：绝不丢弃 Win32 返回值，改用 `SetWindowLongPtr(GWLP_WNDPROC)` + `CallWindowProcW` 链式转发，失败时回收已注册托盘图标；幂等动作替代时间去重（单击/键盘/双击/气泡统一为「显示并置顶」）；语义过滤替代时间防抖（`isV4` 忽略 `WM_RBUTTONUP`）；可见性判定替代前台句柄（`IsWindowVisible() && !IsIconic()`）；窗口显隐在窗口线程内同步调用，仅服务启停等阻塞操作异步；`EnumWindows` 按类名 `wailsWindow` 匹配并接受隐藏窗口；`gofmt -w <目录>` 会剥离无关文件 BOM，应逐文件格式化；`OnDomReady` 每次导航都触发，初始化必须幂等。
- **反例**：250ms 菜单防抖 + `isShowingMenu` 重入拦截；`keybd_event(VK_MENU)` 破焦点；`WM_ACTIVATE` 维护失活时间戳；`IsWindowActive` 仅比对前台句柄；兜底模式把 `wParam` 当 X 坐标（实为图标 ID 1，且未处理副屏负坐标）；菜单回调在窗口过程内同步阻塞。

