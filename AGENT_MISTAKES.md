# AGENT_MISTAKES.md

> 现象和根因已删，只留能改变后续决策的教训与修法。同源条目已合并，被证伪的做法以「反例」并入，最新的排在最前面。

## 通用铁律（跨条目去重）

1. **期望源**：协议和布局以规范样例为准；测试报红先分清是期望错还是代码错，绝不能改被测代码把测试改绿；位段先手写逐位表（含跨字节拆分）；解析器先列「像但不合法」的负例（`[::1]:53`、`256.1.1.1`、`2001:db8::1::2`）。
2. **可达性**：严重度 = 缺陷机制 × 可达面。双向 grep 调用链（Go 导出方法 → gomobile → Kotlin 调用点，含接口注入与默认构造），并查设备、模式门；legacy 或平行实现要先证明「生产上真会执行」。判「会执行」得走完整控制流（`if`、循环守卫、跳转目标）；崩溃类高危先找「现场为什么没炸」的反证。
3. **代理结论零权重**：子代理说的「已确认 / 高危」要逐条回读源码到调用链两端，组合主张拆开验；计数和规模自己数，「实测 N」必须出自本会话的工具输出；核验的是它的位表和判据本身。报告没到手等于没有信息；复核按 6–12 条分批，出现「待定」立即拆小批重派。
4. **归因顺序**：先用 `git show HEAD:<file>` 确认基线，别把「我以为它没做」当事实，据错判写下的改动整体回退。判「问题不存在」要显式走一遍发生路径——「代码保留了 X」通常说明 X 会被后续流程消费，恰恰不说明无害；「机制成立但修它不划算」记「本轮不改」，不能记「证伪」。
5. **交付自证**：多文档分类用脚本做集合差集，证明互斥；清单要声明口径和扩展名；误报、撤回都留痕，编号不复用；补「对称性差距」之前先确认被对标的那一半真被消费——没人渲染的字段照抄过去只会放大死代码。
6. **产物时序**：AAR、jar、exe 只在源码定稿后重建，顺序是改源码 → `gofmt`/`go vet`/`go test` → 构建 → 目标平台编译、单测、启动验证；退出码 0 或单个文件能读都不算完成；`.vue` 改动要跑含 `vue-tsc` 的完整构建。
7. **仓内优先**：列「需要外部取证」之前先搜源码、测试和仓库注释，作者注释比记忆可靠；判「无法修」之前把平台 API 查完（「模型缺字段」往往意味着「该换判据」）；以「要加 DB 字段或迁移」为由放弃的，必须附上「已排除的替代判据」。
8. **改动方式**：改代码一律用编辑工具，不要用 `sed -i`、PowerShell `-replace` 或 Python 脚本做文本替换。同类事故已经出了三次：`-replace` 把 `$1`、`$&` 当反向引用、多行替换里 `\r\n` 还会错位，`sed -i` 直接把脚本改出 `SyntaxError`。不能因为某一次没出事就认为这条路安全。文件改坏了别试图修补，`git checkout --` 回基线重做更快。

## 事件记录（时间倒序）

### 2026-10-20：半透明顶栏要求「栏位留白放进滚动容器」；`EdgeInsets.horizontal` 是左右之和

- `EdgeInsets.horizontal` 是 left+right 的**和**（对称 20 时是 40），按「取一半」的意图除以 2 得到的是整条单边距。要单边就用 `.left/.right`；更不要用「先减半再叠一层内边距」的做法——图与文字各留 10/20 会在卡片两侧留下一条 10dp 的白边，肉眼就是「缩进错了」。出血图要么真贴边（左右 0，文字块自己让出 20），要么与正文同为 20，中间值最像 bug。验收时量同一屏多张卡片的标题 x 与图形 x，别只看卡片外框。
- 半透明顶栏能被看见，前提是**滚动视口从 y=0 开始**。留白放在滚动容器外面（`Padding` 包 `ListView`）会把视口裁在栏底，滚动时内容被硬切断，顶栏永远是实的；必须把栏高加进 `ListView.padding`，同时 `MediaQuery.removePadding(removeTop)` + `FloatingBarScope(inset: 0)`，否则内容里会再算一次留白。共享件（`PageBody`，67 个调用点）改这个属性等于一次改全站，同轮必须真机抽查首页/设置/通用/连接/代理/流量等不同结构的页。
- 「半透明」的验收标尺是标题行可读：渐隐从状态栏下就开始时，滚动中的大号数字会以约四成不透明度叠在标题上。把 `FloatingHeader.fadeStart` 推到工具栏约 72% 高处（`(top + 72*0.72)/(top+72)`），标题干净、栏底仍透出内容，才算两头都满足。
- 编辑态徽标不要骑卡片边缘，改为在卡片内部加高出一行专用位：通过 InheritedWidget 由 `DashboardCard` 注入操作条（`SizedBox(height: 28)` + 10dp 间距），徽标与内容互不遮挡，也不用改十张卡的构造函数。注意 `DisabledMask` 是 `ColorFiltered` 灰度+提亮，若包住整张卡会把操作条一起洗淡——遮罩只能罩正文，操作条留在遮罩外。
- 探针的 `shot <route>` 传 `/` 会写成时间戳文件名；`tap` 的 dpr 可能停留在默认 3.25（本例真机 2.625），坐标会打偏。点击用 `adb shell input tap <dpr×逻辑坐标>`，dpr 从探针的 `screen` 宽度现算；路由切换后立刻 `input swipe` 常不生效（过渡动画），改成「导航 → sleep 1.5–2s → 手动 swipe → screencap」。探针 `connect()` 会 force-stop 重启应用，编辑态等内存状态会被清空，点按钮前先确认当前模式。

### 2026-10-19：全站卡片贴边，改共享件一次修好 46 页，也把 4 页推成双重缩进

- 仓库级的布局不变量（比如「所有卡片左边距 16」）别靠静态枚举调用点来验证。157 个点里的嵌套关系，肉眼和正则都数不准；改完共享件跑一遍真机量 x 分布，一轮就能列出全部违规页。
- 改共享件的默认值等于「一次改全站」，回归必须同轮做完，不能留给下一轮。把 16 加在 `generateSection` 的「卡片列」上是对的，加在外层会让组头缩进 32——`ListHeader`/`ListFooter` 自带 16，同一屏混用两种边距就是这么来的。
- 判据的参照物要选设计常量，而不是某个 widget 的矩形。后者的坐标系口径（通栏容器还是文字列）随时会骗人。

### 2026-10-19：「顶栏下空档」的判据分不清「居中设计」和「布局塌陷」

- 判「留白异常」要能区分「上下对称的居中」和「上方空、下方挤」。加一条 `gapAbove/gapBelow` 比值判据，报告里把两个数都打出来，人眼复核才有依据。
- 双端各存一份 widget 名单的结构，改一处必须同轮改另一处；更省事的做法是让 JS 只按 Dart 输出的名单过滤。
- 凡是「距离屏幕底」的量，先问清楚这块内容属于哪个视口。
- 报告要带上判定所用的原始数字（首块 y、栏底、内容区底、下方余量），否则假阳性在离线复检里识破不了。

### 2026-10-19：`FilledInputTheme` 的胶囊圆角套到高框上，画成一个巨大的圆

- 有些组件参数「默认值只在某个尺寸下成立」，换个尺寸用就是缺陷。`FilledInputTheme` 的 `borderRadius` 默认 `AppRadius.full`（=1000）是为单行胶囊设计的，套到 `SizedBox(height: 360)` 的输入框上就画成一个占满半屏的圆。给这类默认值写注释时，把成立前提一并写进去。
- 判断主题类缺陷的影响面，要看字段是否自己覆盖了该属性（`decoration.border` 非空即覆盖，`InputDecoration.applyDefaults` 会让字段覆盖主题同名属性），不能按「尺寸像不像」归类。当初只看 `minLines≥5` 就外推，把三处显式写了 `border: OutlineInputBorder()` 的地方也列进了清单。
- 写进本文档的每一条影响面清单都要有引证（读到的那行代码）。没有引证的条目比不写更坏，它会被后续轮次当成事实复述。

### 2026-10-19：真机 UI 体检的三类假阳性，以及 `StackFit.expand` 让空状态整棵子树消失

- 诊断通道的 `FlutterError.onError` 过滤要放宽，`RenderBox`、`infinite`、断言失败都留痕。只筛 `overflowed`，会把「同样让内容消失」的错误全丢掉。
- 判「留白」要能区分「背景是空的」和「子树没布局」。后者只能靠错误流发现，光看文本数量会漏。
- 量空档要看「第一个画上屏幕的块」，文本和容器都算。只按第一行文本量，卡片外壳、图片、输入框都不在名单里，就会把紧贴顶栏的页面报成几百 dp 空档——结构名单里要登记 `Card`/`Tile`/`Image`/`Chart`/`EditableText`/`NullStatus`。
- 缩略图上肉眼判断 y 坐标不可靠。怀疑数字时，把矩形叠加回截图自证，别凭印象推翻测量。
- 体检判据一律按「像素是否真的上屏」写：视口裁剪、浮层遮挡、动画中间帧都算没上屏。探针连打两次，同名文本位移超过 2dp 就重截图，保证 PNG 与 JSON 出自同一静止画面。
- 换页面栈不会关掉上一页留下的浮层（`PopupRoute`）。跳路由前先 `popUntil((route) => route is! PopupRoute)`。
- 给设计系统补的回归测试要做反向验证：把修复临时改回去，用例必须变红，否则它可能只是一条恒真断言。
- 修法备忘：`NullStatusSwitcher` 这类空状态组件放进可滚动容器时，用 `LayoutBuilder` 读父级约束，`hasBoundedHeight` 才 `expand`，否则用 `loose`；`Row(crossAxisAlignment: CrossAxisAlignment.stretch)` 直接放进 `ListView` 的 `Column` 时，外面套一层 `IntrinsicHeight`（仓内 `connection_stats_card.dart` 就是这么写的），卡片仍然等高。

### 2026-10-19：`.bat` 里写中文会截断解析器；`set /p` 空 stdin 死循环；直接 `gradlew` 编 Flutter 是空壳

- `.bat` 保持纯 ASCII，中文说明放 `.md`（本项目落在 `android/SIGNING.md`）；改完用「统计 >127 字节数 == 0」自检。把 `chcp 65001` 写进文件救不了，`cmd.exe` 按 OEM 代码页解析脚本，它执行前就已经乱了。
- 所有 `set /p` 重试分支都要设上限，否则无终端场景（管道、CI、重定向）必炸；错误信息里直接给出 `adb install -r <apk>` 这类补救命令，比让用户重试有用。
- Flutter 的构建入口只能是 `flutter build apk`，直调 Gradle 只编 Android 壳，Dart 代码不会进 APK。迁移脚本先改入口再谈其它，`-PsignDebugWithRelease` 这类 Gradle 参数要原样透传（`flutter build apk --debug -PsignDebugWithRelease=true` 是有效的）。
- 签名验收靠证书指纹比对，不靠退出码——`--release` 在密钥缺失时会静默回退 debug 签名，构建照样成功。比对 `keytool -list -v` 的 SHA256 与 `apksigner verify --print-certs` 的 SHA-256，并确认 DN 不是 `CN=Android Debug`。
- 密钥文件先 `git check-ignore` + `git ls-files` 双确认，再提交。

### 2026-10-19：「并行流停滞 2 小时零页面」，`searchState.query` 让整页隐身，widget 测试断言选错标尺

- 子代理的交付判据是「有消费方 + 交互测试跑过」，不是「文件存在 + analyze 绿」。`dart analyze lib` 全绿只证明能解析，运行时行为可能一次都没执行过；停滞一轮就主动去查它卡在哪，必要时直接 `interrupt_agent` 止损，别等它自己报。
- `AppBarSearchState.query` 是「模式开关」而不是「初值」（`CommonScaffold` 用 `searchState.query != null` 判当前是否在搜索模式）。把 provider 里的当前搜索词回灌给顶栏，一进页面就展开搜索框、标题和所有分组全不渲染，而 analyze 和路由可达测试都是绿的。代码里写注释挡住复发。
- 先读承载文案的 widget 再写断言，别顺手拿一个在场字符串当标尺；断言要用只可能由目标控件承载的字符串。
- 折叠或裁剪类容器里的 `findsNothing`，先确认是「没渲染」还是「折进去了」。顶栏 `iconActions` 会被静默折进「更多」菜单（`_maxBarButtons`/`_maxGroupedActions` = 2），页面自己占一个动作后，加进去的图标就不在栏上了，这时 `find.byTooltip` 找不到属于设计行为。无头测试里 `find.bySemanticsLabel` 比 `find.byTooltip` 稳。
- 中间态用定步 `pump()` 观察，终态才交给 `pumpAndSettle`——后者会一路推帧到静止，短暂的「进行中」状态永远看不到。
- 探测脚本（`test/probe*_test.dart`）用完立刻删，遗留文件会让全量 `flutter test` 变红。

### 2026-10-19：三类「analyze 全绿、运行时才炸」的缺陷，加上 GoRouter 未匹配路由静默放行

- **永不手写三角函数或超越函数的近似**。`dart:math` 就在标准库里，「省一个 import」换来的是 analyze 查不出、只在 paint/test 阶段才炸的数值缺陷。凡是写数学近似，都要问一句「参数域上界是多少，近似在那里还成立吗」。
- **演示用的永动动画必须有全局关闭开关**。本仓约定用 `debugDisableDashboardLiveUpdates`（`lib/state/dashboard_providers.dart`），测试统一走 `test/support/test_hooks.dart` 的 `installGlobalTestHooks()`。新增任何 `repeat()` 或自循环定时器之前，先想「`pumpAndSettle` 还能过吗」。
- **「没抛异常」不等于「路由存在」**。GoRouter 对未匹配路径不抛异常，只渲染 `errorBuilder`，没设就是一片空白；「每条路由都能 build 且不 throw」这类用例还会对漏注册的路由静默放行。给路由器加 `errorBuilder: UnknownRoutePage`，断言里同时写 `find.byType(UnknownRoutePage) == findsNothing`，漏注册才会硬失败。
- **固定尺寸容器 + 可放大文字 = 潜在溢出**。高度按 `textScaler` 线性放大，横向多列一律 `Expanded` + `ellipsis`，别指望 `Text` 自己收缩。
- 长测跑完看到一堆 `pumpAndSettle timed out`，先 `grep -r "\.repeat("` 和「自循环 `Future.delayed`」，比逐页找布局问题快得多。

### 2026-10-19：并行流里跑 `dart format` 误伤同伴文件

- 并行阶段禁止任何目录级的格式化或批量改写命令，只对自己负责的文件列表显式逐个跑。`dart format`、`dart fix`、代码生成器都按目录工作，工具层不会替你守住写域。

### 2026-10-19：把「网络不可达、Android 构建跑不通」当成事实引用了三轮

- 判「网络不可达」要用 `curl` 或 `Invoke-WebRequest` 打真实构件 URL，不能打域名根路径。根路径 404/400 是正常的，把 404 当「不可达」会直接得出反向结论。
- 文档里的环境类结论有保质期，引用前必须重测。「上轮记录的失败」不等于「本轮仍然失败」。
- 长任务跟进度一律写日志文件 + `Get-Content -Tail`（或 `Start-Process -RedirectStandardOutput`），禁止用 `Select-Object -Last`、`Tee-Object` 这类会缓冲的过滤器——它们会让「慢」看起来像「死」。
- 首次 Flutter Android 构建要下约 3 GB（Gradle + NDK + SDK + 依赖），得区分「一次性环境准备」和「真的卡死」。判据是看 Gradle 守护进程的 CPU 是否在动、`build/app/intermediates/` 是否在长。

### 2026-10-19：枚举上屏变源码字形；分组标题与滑杆标签同名

- 把枚举或对象插值进 `Text` 之前，先确认它的 `toString` 被覆写过，或者显式取 `.label`。`ProviderProtocol` 没覆写 `toString`，UI 上就真的显示 `ProviderProtocol.doh · https://…`，而编译器、analyze、路由冒烟三类检查都拦不住；同仓 `home_page.dart` 早就写对了（`provider.protocol.label`），照「同一工具函数」复用才带进来。
- 复用「现成的工具函数」之前读它的实现，别只看名字。
- 自测时把整页 `Text` dump 一遍（`for (final e in find.byType(Text).evaluate())`），比只断言几个关键文案更容易抓到字面错误。
- 同一屏内的标题文案必须唯一，分组名要给控件标签让位。

### 2026-10-19：长设置页自测，`scrollUntilVisible` 三重失效加浮条遮挡

- 长页自测统一用「每次循环重新取 `ScrollableState.position` → `jumpTo(pixels ± step)` → `pumpAndSettle`」的粗扫，别缓存 position。底栏项一改 shell 就重建，缓存的 position 会静默失效，`jumpTo` 不报错但也不动。
- 命中后再按 `tester.getRect(row).center.dy - 视口中线` 微调一次，把行挪到中部。滚到视口边缘时 `tap()` 会落在固定浮条上，`ensureVisible` 认为「已在视口内」不会再挪。
- `find.text` 会同时命中页面行和底栏标签，断言前先用 `find.descendant(of: find.byType(ListView), …)` 排除浮条。
- 自测脚本放 `tool/` 下（不进 `test/`），跑完即删，避免污染交付的测试集。

### 2026-10-19：设计系统 API 三处「按直觉写就报错」

- 写组件之前先用 `Select-String` 读构造签名，别按「应该是 Widget」推断。`CommonScaffold.primaryAction` 收的是 `IconButtonData`，需要可见文案的主按钮得放进 `body`，顶栏只能放图标加 `tooltip`。
- 泛型类的具名构造，类型实参一律前移到类名（`ListItem<RuleKind>.options(...)`）。写到构造名后面报的错不会提示该改位置。
- 空状态文案与计数头文案必须分工，一个报数字、一个说原因。两处写同一句，既视觉重复又让 `findsOneWidget` 失败。

### 2026-10-19：Flutter 页面自测的几个坑

- 同屏文案唯一性既是可用性前提，也是可测性前提。`find.text` 命中多个时不要用 `.first` 掩盖，改文案。
- 浮层里读 scope 会 assert，因为 `showSheet`/`showFloatingDialog` 的监听器挂在根 `Navigator` 上，是与 `home:` 平级的兄弟路由。scopes 要装 `MaterialApp.builder`，它的 `child` 就是 `Navigator` 本身。
- 「能弹出 / 浮层能渲染」类用例必须用真实 App 路由壳（`DitingApp(initialLocation:)`）或在 `builder` 里装 scopes。
- 断言「某 scope 缺失」之前先读它的 `of()` 是不是空安全——空安全的 scope 永远不会 assert，别把它当元凶。
- 临时测试文件要放进 `test/`，放仓根会让 `import 'support/...'` 解析失败。
- `tester.pageBack()` 找的是 `CupertinoNavigationBarBackButton`，本工程 sheet 的关闭按钮是 `GlyphIcon`，一律用 `Navigator.of(element).maybePop()`。
- `scrollUntilVisible` 在 finder 命中多个可滚动区时抛 `Bad state: Too many elements`；限高后直接断言可见项更快。
- 面板内容超出首屏时（比如 6 行服务商列表把「发起查询」挤下去），把次要选项改成横向 chip 行，别指望用户滚动。
- 并发工作区里编译错误先归因到文件归属——是不是别人正在改的文件，再决定等 30–60s 重试还是动手改。
- 行数统计用 `(Get-Content $f).Count`，`Measure-Object -Line` 会跳过空行。

### 2026-10-19：宿主层级结论两次翻车；zh_CN 缺 MaterialLocalizations

- **「对照实验没复现」不等于「缺陷不存在」**。探针必须先证明自己处在会被触发的路径上——要用会 assert 的读法，而不是「能渲染就算过」。负结果要连同「探针为什么足以触发」一起写，否则假阴性会被当成证据写进文档，比不测更坏。
- 同一个结论被推翻两次之后，不要再靠推理定论，直接把不变量写成正例 + 反例两条测试钉住（`test/scope_placement_test.dart`）。
- 凡 `MaterialApp` 带非英文 `locale`，先确认用了 `GlobalMaterialLocalizations`。`DefaultMaterialLocalizations` 只有 en_US，zh_CN 下 `AppBar` 会直接抛 `No MaterialLocalizations found`。
- `LocalizationsDelegate.load` 是异步的，`pumpWidget` 后首帧是空的，要补一次 `pump()`；`lib/ui` 的 `UiLocalizations.of` 是 assert 而非默认值，缺 delegate 会在 build 期崩。
- 测试宿主 `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 的 scopes 装法必须一致，改一处就要同步另一处。
- 构建失败先用 `curl` 逐个探域名，把「环境不可达」和「代码坏」分开写进交付说明，不拿退出码当结论。

### 2026-10-18：三次「问题不存在」的初判被自己推翻

- 结论若是「因此不会发生」，先把发生路径写出来走一遍（见铁律 4）。像「`finally` 只删本线程 temp」这类说法，要读到无条件 `delete()` 那一行；拿「代码保留了 X」当反证时，往往正说明 X 会被后续流程消费。

### 2026-10-18：照抄别人的 `Stop()` 早退守卫，回归了同轮刚修的问题

- 采纳外部修复建议之前，先算它对其他已修项的影响面。守卫条件要表达「是谁」（代际、身份），而不是会被下个会话重置为真的状态位（`running`）。

### 2026-10-18：词法截断改「搜索起点」换来新回归；死分支用「单原子」近似

- 词法缺陷的判据是「什么字符序列构成注释」，不是「从哪里开始找」。改起点等于重新定义词法，先列「旧行为必须保持」的回归用例。
- 声称有缺陷之前，用差分用例证明两版确实不等价。0 差异的「优化」属于等价重写，应当回退。
- 判断 `when` 的可达性要逐原子蕴含且 `text` 参数同一，先排除 `||`、`in`、正则等非原子内容。口径不同会得出 8 / 13 / 14 三个互异的数字。

### 2026-10-18：先入为主复述「`fgRequired` 被重新武装」的相反结论

- 「某个调用把标志设成 X」必须回读到赋值右值的来源，不能凭调用名或 action 推断。
- 崩溃归因用日志时间轴反向验证。三次崩溃的 uptime 都在 520ms 左右，就足以排除 30s timeout 路径。
- 修复方向被证伪之后，先改注释再改代码。

### 2026-10-18：过早断言「受模型限制无法修」，把死字段当差距

- 判「做不到」之前先把平台 API 查完。`ContentResolver.getPersistedUriPermissions()` 就是「是否持久化授权」的权威来源，不需要加 DB 字段。
- 区分「确实做不到」（写进限制）和「当时没想到」（回头补）。
- 补差距之前先确认被对标的那一半真被消费，复制没人渲染的字段只会放大死代码。

### 2026-10-18：并发 Gradle 撞 KSP 缓存；期望错与代码错未分辨；行数口径错

- 多代理共享工作区时，构建单点串行由 Lead 统一跑，子代理只做静态自检和离屏单测。
- 同一批失败里，期望错要改期望、代码错要改代码，两者处置相反。先分辨再动手。
- 行数用 `(Get-Content $f).Count`。`Measure-Object -Line` 跳过空行，系统性偏低 6%–15%。
- 改之前先定位真实卡点分支，同一输入会被多个前置分支截走。
- 分片修复出现「新用例反而红」，常常是抓到了更上游的真缺陷，先归因再改。

### 2026-10-18：身份判定误用 `==`

- 「是不是我注册的那一份」必须用 `===`。`data class` 结构相等，同参请求会互等，旧请求被判最新，`ConcurrentHashMap.remove(k,v)` 同理。
- `data class` 承载请求、令牌、代际时，要假定有人误用 `==`。KDoc 写明，并补「等值但不同实例」的测试。

### 2026-10-18：`gofmt -l` 把 CRLF 误报成「格式未过」

- 判据改成「CRLF→LF 归一化后单独 gofmt，再和基线比真实差异行数」。
- 禁止 `gofmt -w` 整目录，那会翻掉全仓换行符；它还会剥离无关文件的 BOM，应当逐文件格式化。

### 2026-10-18：解析器负例缺失 + 二进制产物早于源码定稿

- 解析器的正例全绿说明不了问题。`2001:db8::1::2` 这种双压缩地址会被判成合法 IPv6，负例必须成组补上。
- 注入 N 次失败要按重试预算折算时间，长退避要有「降级态单次尝试即丢」的分支。
- `gomobile bind -work` 可以把生成的 Java 与 `tunnel-sources.jar` 对比，导出 API 没变就不用重新生成。

### 2026-10-18：先落笔后取证：legacy 路径误判高危，Edit 锚点凭记忆

- 可达性引证要在落笔前完成（见铁律 2、3、5）。`Engine.Start` 这类方法可能零生产调用者（Kotlin 只用 `startFull`/`startStandalone`/`startStackMitm`），caller grep 只命中定义行说明不了「会被执行」；反过来，`serveDNS` 被 standalone 与 full-tunnel 多入口共用，也不等于路径没有生产者。
- `old_string` 要现场 grep 确认，不能凭记忆写下节结尾。

### 2026-10-17~18：子代理「高危」未收窄即采信；位表和控制流的核验方向反了

- 一手版本表拿不到时，降级为「收窄后的触发面 + 标注待定事实」，交真机 logcat 定版，不按原 severity 入库。
- 逐位展开核实之前不要断言位段写错（byte2 QR 0x80 / AA 0x04 / TC 0x02 / RD 0x01，byte3 RA 0x80 / AD 0x20 / CD 0x10 / RCODE）。很多「写进 Z 位」「无条件伪造 AD」都是误报。
- Room 迁移的 `DEFAULT 0` 校验有 `ifnull` 守卫，实体无默认值时会被跳过，不是「升级即崩」。
- 多代理并行扫描先对汇总表去重。

### 2026-10-17：构建链路三坑：WSL 无 Go、embed 依赖环、Vue key 类型

- 跨子系统构建要在实际环境里跑 `command -v`。WSL 里没有 Go，`go.exe` 也不会被 `command -v go` 解析。交叉编译放宿主（`GOOS=linux CGO_ENABLED=0 go build`），WSL 只做 `dpkg-deb` 组装，验证到包内 ELF 能执行 `--version`。
- 冷启动固定顺序：`go mod download` → `npm install` → 占位 `frontend/dist/index.html` → `wails generate module` → `npm run build` → `wails build`。验证落到真实产物起窗。
- 按对象身份稳定的 key 用 `WeakMap<object, string>`（`createRowKey`），不要塞对象或退回下标；`git update-index --really-refresh` 消除 CRLF 假变更。

### 2026-10-17：工具脚本两例：双击闪退与版本号伪变更

- GUI 启动脚本先探测依赖、缺失就按清单安装，非零退出要 `pause` 保留窗口。双击故障先在终端复现拿 traceback。
- 版本目标清单按全仓声明点维护并跑全量 dry-run。是否修改要比较新旧内容，而不是看 `re.subn` 的计数——`n>0` 不等于有变更，重跑必须幂等。
- Android `versionCode` 取 `max(旧值, major*10000+minor*100+patch)`；锁文件只改根节点与 `packages[""]`，并验证 round-trip。

### 2026-10-17：批量修复中的跨模块契约陷阱

- 锁内只做快照，锁外做重活。持锁不调 `wg.Wait()`、网络、`time.Sleep` 或回调，否则单次保存能卡死数秒。
- 长生命周期对象不按值捕获可热替换的字段，改用 getter 或 atomic 指针，并同步构造点和测试桩。
- 权限、路径、编码要在目标平台实机验证（`icacls`、读生成文件）。`os.WriteFile(_, 0o600)`/`os.Chmod` 在 Windows 上只切只读位、不设 ACL，路径大小写、systemd 相对 `ExecStart`、XDG 转义同理；没法 CI 的差异用 `//go:build` 分包加 no-op 桩。
- 拆分逼近 550 行的文件要确认同包、import 无遗漏，并重跑构建测试。

### 2026-10-17：复核旧「实证」先审期望

- 规范类结论先对规范原文（RFC 6052 的 Table 1/2 六例）。
- 计数要逐点带上下文（前后 3 行）并抽查 2–3 点。未剔除前置 `MaxBytesReader`，14 处会数成 13 处。
- 复现失败先怀疑 harness。闸门早退（`CacheConfig.Enabled` 未置 true）造成的假阴性比代码缺陷更常见，为每条早退分支加断言。
- 「无消费者」要 Go 与前端 camelCase 两查。同鉴权族的实现不一致，先怀疑孤立一侧遗漏。
- 溢出验证走运行期（`strconv.ParseInt` 或变量乘法），常量表达式会直接编译失败；临时 `zz_tmp_*` 文件用完即删。

### 2026-10-16：页面级 max-w 导致单列卡片宽度不足

- 页面根容器不设 `max-w-*`，宽度交给 `main` 的 padding；`pb-12` 由 `views/*.vue` 统一负责。
- 布局缺陷用 `getBoundingClientRect()` 量宽和 x/w，不看截图。
- Web 模式 `ui_capturer.py` 只截登录页。可以用 CDP 注入伪 `window.go.main.App` 并设 `diting_ipc_host/port` 截真实界面（仅本地核对，不入库）。
- 注意 1280/1920 与 768–1024 折叠侧栏这几档还没覆盖。

### 2026-10-16：呼吸灯 infinite 动画拖垮 WebView2 GPU

- 这类开销只和出帧频率相关，与动画元素的数量、大小无关。所以 `will-change`、`translateZ(0)`、`contain:strict`、改 `transform`、改 `background-color`、延长周期统统无效，唯一有效的杠杆是降低出帧数。
- `steps()` 之后降到 1.4%–4.0%（`steps(2)`≈1.5%、`steps(4)`≈3.3%、`steps(8)`≈7.1%）。对 `infinite` 动画（含 Tailwind 的 `animate-spin`/`animate-pulse`、`md-circular-progress indeterminate`）保持怀疑。
- 性能归因用 `Get-Counter '\GPU Engine(*)\Utilization Percentage'` 按 pid 定位，最小化后归零可佐证。
- 高刷和多显示器还没覆盖，观感也未经人眼确认。

### 2026-10-16：托盘 `SetWindowSubclass` 静默失败与时序补丁链

- 绝不丢弃 Win32 返回值。`SetWindowSubclass` 在本进程 Wails 窗口恒返 FALSE 且 `GetLastError=0`，返回值一丢就查不出子类过程从未安装。改用 `SetWindowLongPtr(GWLP_WNDPROC)` + `CallWindowProcW` 链式转发，失败时回收已注册的托盘图标。
- 用幂等动作替代时间去重（单击、键盘、双击、气泡统一为「显示并置顶」），用语义过滤替代时间防抖（`isV4` 忽略 `WM_RBUTTONUP`），用可见性判定替代前台句柄（`IsWindowVisible() && !IsIconic()`）。
- 窗口显隐在窗口线程内同步调用，只有服务启停这类阻塞操作才异步。
- `EnumWindows` 按类名 `wailsWindow` 匹配并接受隐藏窗口。
- `OnDomReady` 每次导航都触发，初始化必须幂等。
- **反例**：250ms 菜单防抖加 `isShowingMenu` 重入拦截；`keybd_event(VK_MENU)` 破焦点；用 `WM_ACTIVATE` 维护失活时间戳；`IsWindowActive` 只比对前台句柄；兜底模式把 `wParam` 当 X 坐标（实为图标 ID 1，且没处理副屏负坐标）；菜单回调在窗口过程里同步阻塞。
