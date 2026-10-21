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
9. **测试红线的归因顺序**：`tap` 打不中（下层文字还在、命中测试落到别处）先查有没有全屏遮罩/弹窗，不要先改文案断言；`Expected 0` 与 `Expected 1` 之间要先问「期望值是不是写成了迁就实现」。改测试前必须能用一句话说清「产品行为错在哪」，说不出来就是改测试凑绿。
10. **全局副作用**：`dart format` / `flutter analyze` / 不带路径的 `git commit` 都是全局操作，会碰到别人的文件与索引；只对自己作用域跑。收尾必查 `git status --short` 里有没有不属于本轮的文件。

## 事件记录（时间倒序）

### 2026-10-21：真机复测 UI 效果时，探针每次都会重启 app，把「我设的那个开关」丢掉

- 现场：要验证 Liquid 玻璃是否生效，得先在外观页把档位切到「极致」，再看底栏。
  但 `ui_probe.mjs one/tail/all` 的 `connect()` 里第一件事就是
  `am force-stop` + `am start`——于是「切档位 → 用探针量」必然量到**重启后**的画面：
  玻璃档位回到默认「关闭」，底栏又是实色白胶囊。连续两轮都据此得出「玻璃没生效」，
  而这个结论在那一轮其实是**测量方法**造成的，不是产品缺陷（真正的缺陷另有其事，见下条）。
  更隐蔽的是：切档位那一步本身也要靠探针导航，于是「量一次 = 重启一次 = 设置清零一次」。
- 修法：给探针加 `go <route>` 分支——`connect({ attach: true })` 只附着不重启，
  然后 `gotoRoute` 换页。凡是「先改变内存态、再观察」的验证都必须走它。
  `now` 只量当前画面（连跳页都不做），`go` 量「附着 + 跳页」。
- 判据：**任何「设置 A 之后 B 应该变」的实机验证，先确认 A 的状态跨过了测量边界**。
  探针/截图工具如果会重启进程，而设置项不落盘，那这条链路从设计上就验不了。
  这类「量具污染被测状态」的问题要优先修量具，否则每一轮都会重复付出同样的代价。

- 同轮真实缺陷（与上面互为镜像，别把两者混为一谈）：Liquid 玻璃档位本来**只存内存**
  （`LiquidGlassModeNotifier.build() => none`，`select()` 只改 `state`），所以连
  「用户退出应用再进来，他选的档位没了」这个真问题也一直没被发现——因为每次复测
  都被重启掩盖，看到的永远是「关闭」。修法是把三档（玻璃 / 底栏形态 / tab 动画）
  一起落盘到 `dns_vpn_prefs`。**验证时的「设置丢失」和产品里的「设置不持久」
  长得一模一样**，先分清是哪一个，再决定改探针还是改代码。

- 关联的第三个坑：`LiquidGlassHost` 从未挂进 widget 树。`LiquidGlassScope` 只是
  InheritedWidget（决定「要不要走玻璃路径」），真正把玻璃背后的内容抓成离屏图的是
  `LiquidGlassHost`（负责 capture atlas）。只挂 Scope 不挂 Host 时，每个 pane 静默
  退到 `_addFrost` 兜底（只剩 tint + 描边），渲染结果与「关闭」逐像素相同。
  判据：**成对出现的 API 要去 grep 另一半的挂载点**，不能因为「上一半在」就认为整条路径通。
  上游 `theme_manager.dart` 里两者是 `LiquidGlassScope(child: LiquidGlassHost(child: ...))`。

### 2026-10-21：写文档时最容易犯的不是「写得少」，而是「把约定写成现状」

- 现场：把 DITING_flutter 的 32 份 Markdown 合并成一份核心文档时，两处把「已实现但没接线」
  和「旧版有、本仓没有」写成了当前行为，被独立核验抓出：
  ① 写「日志仪表盘四格来自 `dns_log` 当日聚合」——真实聚合
  `dnsLogDailyStatsProvider`（`log_providers.dart:64`）**零消费方**，页面实际读
  `LogDashboardSnapshot.mock()`；文档另一节又如实写着「概览块仍走演示数据」，**自相矛盾**。
  ② 写「旧版三条一次性迁移标记」——其中两条（`local_listen_port_migrated`、
  `log_queries_default_off`）只存在于旧版 Kotlin，本仓全无，读者会照着「顺手补一条」，
  而那正是文档自己禁止的重放。
- 判据：**任何一句话先问「这是现在的行为，还是我主张的行为」**。规范、口径、命名约定属于
  「主张」，必须与该行为的**唯一实现位置**（provider/表/通道）一起写，并说明它是否已被消费；
  删文档合并时尤其危险——原文的「待接线」「本轮暂不」这类限定词会在精简时被顺手删掉。
- 自查方式：对每句含「全部/都/统一/必须」的断言，去 grep 该行为的消费方；**消费方为零就是
  「未接线」，不是「已实现」**。文档里同时存在「X 已完成」与「X 仍是演示」两句时，
  必然有一句是错的。
- 同源反例：引用类型名也要 grep。本次文档凭空写了 `DnsLogResult` 这个**全仓不存在**的类型
  （Dart 侧 `dns_log.result` 就是字符串），并据此断言「`switch` 的 `_` 会把 ERROR 渲染成
  放行」——而两处 `switch` 其实都已显式处理 `ERROR`。旧文档里的符号在合并/精简时会被
  「记忆」补全成看起来合理的名字，只有 grep 能证伪。

### 2026-10-21：全局弹窗挂在 `builder` 里会吃掉所有测试的点击，而报错指向「点不到按钮」

- 现场：给应用补了首启「使用须知与免责声明」弹窗（`InitialAgreementGate` 包在
  `DitingApp.builder` 的 `child` 外）。`app_shell_test.dart` 里三条毫不相干的用例
  （电源按钮、底栏切页、浮层弹出）同时变红，失败信息是
  `Found 0 widgets with text "选择解析服务商"` + 一长串
  `the finder corresponds to this RenderBox` 命中测试警告——看起来像「浮层坏了」或
  「文案改了」，实际是**遮罩吃掉了点击**。
- 判据：下层 widget 树仍在（`find.text` 能找到），但 `tap` 打不中 → 先怀疑有一层
  全屏 `Stack`/`ModalBarrier` 盖在上面，而不是怀疑控件本身。用
  `tester.takeException()` 拿不到任何异常（点击失败只是 warning，不是 error）。
- 修法：测试侧把「同意」态做成默认前置，而不是逐个用例点掉弹窗。为此新增
  `test/support/test_hooks.dart` 的 `appTestOverrides()`，**所有挂 `DitingApp` 的
  测试统一用它**；要测弹窗本身的用例传 `skipInitialAgreement: false`。
  这样新增全局前置只需改一处，不会再出现「漏改的那个文件以点不到的形式失败」。
- 反例：**不要**把这条前置写成「测试里预置 store 里的 `initial_agreement_accepted`」——
  store 的实参在 `pumpWidget` 时才 override，来不及；用 provider override 才对。

### 2026-10-21：`dart format` / `flutter analyze` 是全局操作，且 `lib/ui` 冻结后一条格式化 diff 也不能留

- 现场：队友跑 `dart format lib` 一次性改了 150 个文件（含冻结的 `lib/ui`）。虽然全是
  纯格式化、`flutter analyze` 依然零告警，但 `git diff` 里 `lib/ui` 出现 24 个文件
  337 增 522 删 —— 审阅者无法分辨这是格式化还是语义改动，等于把「设计系统零改动」
  这条硬约束变成了口头承诺。
- 判据：`git diff -w --stat <base> -- lib/ui/` 仍显示非零增删时不能只看一眼「像是换行」
  就放过；要逐条读 `+`/`-` 行确认。确认是格式化后**整体还原**：
  `git checkout <base> -- lib/ui/`，不要手工挑。
- 铁律：只对自己作用域的路径跑 `format` / `analyze`。收尾前跑一次
  `git status --short lib/ui/ lib/app/theme/`，非空就要问「这处是不是我有意改的」。

### 2026-10-21：`indexWhere(location.startsWith)` 恒返回 0——`/` 是任何路径的前缀

- 现场：`branchIndexOf(String location)` 写成
  `_branchOrder.indexWhere(location.startsWith)`，而 `_branchOrder[0] == '/'`。
  `location.startsWith('/')` 对任何绝对路径都为真，于是 `/hub`、`/logs`、`/settings`
  全部被判成 0 号 branch。这个函数当时**只在测试里被调用**，所以线上不可见；一旦有人
  拿它做 `goBranch` 的入参，任何非首页位置点一下都会跳回首页。
- 修法：按**最长前缀**匹配，且前缀后必须紧跟 `/` 或结束（否则 `/logs` 会命中
  `/logsomething`）。注意队友提出的修法 `indexWhere((it) => location.startsWith(it))`
  只修了「参数传反」，**没修「`/` 抢先命中」**——照那个改仍然恒返回 0。
- 教训：`startsWith` 一族做前缀匹配时，永远先问「有没有一个空前缀/根前缀会抢先」。
  这类错误在被测试单独调用时表现为「断言期望值写成 0」，很容易被误改成迁就实现。

### 2026-10-21：编辑工具的一次换行丢失，靠 `compileDebugKotlin` 才抓到

- 现场：用编辑工具改 Kotlin 时，`val address = InetAddress.getByName(spec.host)` 与
  下一行 `DatagramSocket().use {` 被合成了一行，变成
  `InetAddress.getByName(spec.host)        DatagramSocket().use {`。Dart 侧完全正常，
  `flutter analyze` 也照过，**只有 `./gradlew compileDebugKotlin` 报**
  `Unresolved reference 'DatagramSocket'` + `Missing return statement`。
- 铁律：改过 `android/**/*.kt` 就必须跑一次
  `cd android; .\gradlew.bat compileDebugKotlin --console=plain -q`（失败时去掉 `-q`
  grep `^e:`）。`flutter analyze` 不覆盖 Kotlin，`flutter build apk` 太慢不适合内循环。
- 同类：Kotlin 里加通道方法后，Dart 侧的 `implements` 类会报
  `isn't a valid override`（少一个具名参数），`flutter analyze` 能抓到——所以两侧要
  **一起改、一起验**，不要先提交一侧。

### 2026-10-21：输入框只写 `TextEditingController`、不写回 provider，测试全绿但功能是错的

- 现场：网络诊断「测速」页把域名填进 `TextEditingController` 就直接在 `_run()` 里读
  provider 里的域名去测速。用户改了输入框，provider 里还是上一次的值，于是**测的是
  旧域名**。全部 298 个测试（含 diagnostic 面板测试）都是绿的——因为测试用
  `enterText` 之后点按钮，断言的是「结果渲染出来没有」，而桩 runner 不校验入参。
- 铁律：一个字段如果同时存在「输入框」和「状态源」，先写清谁是唯一真相。
  `controller` 只是显示层，业务逻辑读的必须是 provider；因此 `onChanged` 里要
  `setDomain(...)` 落回 provider（`_ToolField` 为此加了 `onChanged` 参数）。
  自查方式：grep 所有 `_run` / 提交动作里 `ref.read(...)` 的字段，逐个确认它
  在输入路径上也有写入口——「有写入口」指用户打字时就写，不是只在初始 `build`
  里灌一次。
- 另一条同源：默认值也别照枚举顺序猜。旧版 `NetworkToolMode` 枚举把 `SPEED_TEST`
  写在第一个，但 `NetworkToolsViewModel` 的初值是 `NetworkToolMode.PING`——页面
  打开停在 Ping 测试。默认值必须从 ViewModel 的 `MutableStateFlow` 初值读，
  不能按枚举声明顺序取 `first`。

### 2026-10-21：多人共用一个 git index，不带路径的 `git commit` 会把别人的改动卷进来

- 现场：本 agent 用 `git commit -m … -- <自己的路径>` 提交后，又跑了一次不带路径的
  `git commit -m …` 想「补一下说明」，结果把别人已暂存的 80 个文件一起提交了，提交
  信息还写成我自己的模块名。**同一工作区里多个 agent 共享 `.git/index`**，任何不带
  路径（或 `--only`）的 commit / `--amend` 都会吃下当时索引里的全部内容。
- 铁律：提交只用 `git commit -- <明确的文件列表>`；`--amend` 同样要带路径。改完用
  `git show --name-only --format='' HEAD` 回读一遍文件清单，确认范围就是自己那几个
  文件。发现卷进来了立刻 `git reset --soft HEAD~1` + `git reset`（mixed）把改动退回
  工作区，再用带路径的 commit 重做——不要试图 `git rebase -i` 去「摘」别人的 hunk。
- 另一条同源坑：`git commit -- path` 只提交**已跟踪**文件的改动，新建的未跟踪文件会
  被漏掉（本次漏了 6 个新页面，编译直接断）。提交前先 `git status --porcelain <我的
  路径>`，把 `??` 的也用 `git add` 显式加进去。

### 2026-10-21：`dart format lib` / `flutter analyze lib` 是全局操作，会改到别人的文件

- 本 agent 跑了一次 `dart format lib`，一次性改写了 115 个文件——绝大部分属于其他
  并行 agent 的作用域，把他们的 `git diff` 搅成无法审阅的一团。**只对自己作用域的
  路径跑 format / analyze**（任务描述里给的那串路径），不要图省事跑整棵树。
- 同理，`flutter analyze lib` 在有其他人半成品改动时会有大量「不是我造成」的 error。
  判据要落在**自己那组路径**上（`flutter analyze lib/pages/server lib/pages/config …`
  → `No issues found!`）；整棵树变绿不是我能保证、也不是我该等的验收条件。

### 2026-10-21：`part of` 的库根被删后，剩下的 part 会变成「全员编译失败」

- 删 `lib/data/mock_config.dart`（库根）后，`mock_config_general/network/override/dns`
  四个 part 全部报 `part_of_non_part`，报错位置却在**库根**上，看起来像是「我删错了」
  ——实际是那四个 part 文件成了孤儿。删库根必须同时删掉全部 `part` 文件，并且先
  `grep -rn "mock_config"` 双向确认没有页面还在 import 它们。

### 2026-10-21：浮条（`NavigationDock`）在场的页面不能用 `pumpAndSettle`

- 玻璃层有持续动画，`pumpAndSettle` 直接超时（不是 bug，真机上它就该一直动）。
  写这类页面的冒烟必须用 `pump()` + `pump(Duration)`。见 `test/support/test_hooks.dart`。
- 配套坑：`PageBody` 是懒构建 `ListView`，靠后的分组**还没被建**，`find.text('后台稳定性')`
  必然 `findsNothing`。断言视口外的分组要先 `drag` 把尾部顶上来，否则「找不到」既可能
  是没写、也可能只是没滚到——两种结论完全相反。
- 反过来，需要「整页入口同时存在」的目录页（如 `/developer`）就别用懒构建的 `PageBody`：
  改成 `AppBarClearance` + `SingleChildScrollView` + `Column`，一次性建完。代价可忽略，
  换来的是无障碍树、截图审核与可达性测试都看得到全部入口。

### 2026-10-21：`CommonScaffold.body` 不预留顶栏浮位是「零报错」缺陷，必须用源码扫描守住

- `CommonScaffold` 走 `extendBodyBehindAppBar` 语义：正文从屏幕 y=0 起排，顶栏浮在正文
  之上；compact 浮层更狠，`FloatingHeader`（拖拽把手 + 标题栏，高 `sheetAppBarHeight
  = 68`）直接盖在正文上方。**留白只由正文自己负责**：`PageBody` / `AppBarClearance`
  封好了，或者滚动件自己在 `padding` 里加 `context.contentTopPadding`
  （页面用 `context.appBarInset`）。
- 把 `ListView` / `Column` / `Center` / `SizedBox(height:)` / `Form` 直接塞给 `body:`
  完全合法：analyze 不报、widget 测试不失败、路由冒烟也过，**只有真机跑到那一屏才
  看得见**——首行被浮层标题压住。本轮一次性修掉 44 个文件里约 35 处，最早的用户
  反馈就是「顶部内容高度不对、被遮挡」的那张截图。
- 量化判据：探针报「内容画进顶栏区(y < 栏底)」。修前「请求详情」浮层里「域名」行
  y=437.5、浮层标题区 413.5–481.5；修后 y=505.5。判据必须是**实测几何**，不能是
  `findsOneWidget`——文本在不在屏幕上是两回事。
- 结构性护栏：`test/body_top_inset_test.dart` 扫 `lib/pages` 下每个 `body:` 表达式，
  顶对齐容器里没有 `contentTopPadding` / `appBarInset` / `PageBody` / `AppBarClearance`
  之一就失败。**加护栏时必须先做负向对照**：故意写一个漏留白的 body，确认测试报红，
  再删掉那个对照文件——否则无法区分「扫描真的生效」和「正则没匹配上所以永远绿」。
- 修法要成对地看清「留白加在哪一层」：`Column` 首件顶到最上时，留白必须加在**整列
  外面**（`AppBarClearance`），加在内层 `Expanded` 列表的 padding 里只把列表往下推，
  上面那行说明文字照旧被压；反过来，滚动件要加在**自己的 padding**里，外面套一层
  `Padding` 会把视口裁在顶栏下沿，滚动时内容被硬切断。同一个 `Column` 里这两种错法
  会互相抵消成「看起来只有一点点不对」。
- 排查这类「多处同源」的缺陷别一个个点过去：先按目录 grep `^\s*body:\s*`，再用脚本
  判定每个 body 的形态（首词是不是顶对齐容器、表达式里有没有留白符号），产出一张
  清单再动手。手工逐个看 100+ 个调用点必然漏。

### 2026-10-20：互斥清洗「先写 A 再读 A 做差集」会把用户的保存清空

- `_dropOverlaps` 最初写成 `setBlockedApps(packages)` 之后紧接
  `blockedAppPackages.difference(packages)`。`LegacySettings` 是 store 的直读视图，
  第二句读回来的**就是刚写进去的那一份**，差集恒为空 —— 用户点「保存」等于清空
  自己刚勾的选择，而 SnackBar 照样显示「已保存」。这类缺陷不抛异常、analyze 也看
  不出，只有「写完再断言该键仍是提交值」的测试能抓到。
- 根因是把互斥清洗当成「从四份名单里各删一次」，而归属方不能被删。修法是显式传
  归属方（`_Owner` 枚举）并跳过它，而不是靠读回来做差集。
- 推广：任何「写 X → 从 X 读 → 基于该值再写 X」的序列，都要先问「这一句读的是不是
  我自己刚写的」。有则改成「基于写之前抓的快照」或「显式排除自己」。
- 上游 Kotlin 在这里反而不会踩坑：`setBlockedAppPackages(context, getBlockedAppPackages(context) - selected)`
  是**先读后写**（参数求值先于调用）。Dart 里把这两步拆成两条语句就变了顺序，
  等价重写必须逐句核对求值时机，不能只看「逻辑一样」。

### 2026-10-20：`jumpTo(maxScrollExtent)` 在「刚追加内容的那一帧」拿到的是旧上界

- 面板跑完探测后把结果卡追加到 `PageBody` 的 `ListView`，随后 `jumpTo(maxScrollExtent)` 仍停在旧上界，尾部断言必然失败。`ListView` 懒构建，新 item 的布局发生在下一帧，`maxScrollExtent` 此时还没变。判据要落在「内容确实进了视口」而不是「我调了滚动」：用多次 `drag(anchor, Offset(0, -400))` + `pumpAndSettle` 把尾部顶上来，先在临时探针里 dump 全部 `Text.data` 确认再写断言。
- 同类护栏：断言「页面上没有某个 mock 数字」时，如果该数字可能在视口外，`findsNothing` 会因为没渲染而恒真——这种断言证明不了「已删除」，要么先滚到该区域，要么改断言同一位置的真实数据源。
- 真缺陷是读代码读出来的，不是测试报出来的：`updateOne` 从列表 provider 的 `.value` 缓存里找行，而「添加面板 insert 完立刻更新一次」时列表还没重建完，缓存在这一段窗口里不含新行，于是自动更新静默什么都不做。写操作接口要**从库实时取**（`repository.byId`），不要把 UI 缓存当写入口的输入。

### 2026-10-20：并行 `flutter test` 会锁住 `build/native_assets/windows/sqlite3.dll`

- 多个 agent 同目录并发跑 `flutter test` 时，先起的那次持有 `sqlite3.dll`，后来者直接 `Flutter failed to delete file ... cannot access`，与代码无关。判定方法：`[System.IO.File]::Open(path,'Open','ReadWrite','None')` 试独占打开，再用 `Get-Process | %{ $_.Modules }` 找出持有者 pid 与其 `ParentProcessId`；父进程还活着就是同事在跑，等而不是杀。
- 顺带一条归因教训：全量 `flutter test` 的失败集合**每次都不一样**（`express_mode` / `native_bridge` / `observability_pages` / `app_layer` 轮换）且单文件跑必过，说明是被并发编辑的邻居文件，不是自己的回归。把「我负责的文件 + 守门测试」单独跑一遍拿到 55/55 全绿，才是可交付的证据；报告里要写清全量红的是哪些、为什么判为他人范围。

### 2026-10-20：Dart→Go 的 JSON 字段类型由 Go 结构体决定，不由 Dart 的 `toString` 决定

- `OutboundProxyConfig.toEngineJson()` 把 `port` 写成了字符串（`"port":"7890"`），而 Go 侧 `outboundProxyConfig.Port int`（`Android/tunnel/flow_outbound.go:29`）由 `json.Unmarshal` 解析——整份配置解析失败，`Engine.configureOutboundProxy` 返回错误字符串，代理**静默不生效**，UI 上却显示「已保存」。判据不是「Dart 里 port 是 int」，而是「对端结构体的字段类型」：生成 JSON 的 switch 必须按类型分支（bool / int / 其余走引号），不能只特判 bool 然后把所有值 `'$value'` 塞进引号。
- 这类缺陷不会被 analyze 抓到（字符串拼接永远是 `String`），也不会被「保存成功」的 SnackBar 抓到。**它只能被形状断言抓到**：`toEngineJson` 的测试要断言整串逐字节相等，而不是 `contains('port')`。
- 上游旧实现是新旧对照的最省事证据：`OutboundProxyConfig.toNativeJson()` 用 `JSONObject.put("port", port)`（Int 重载）写的是数字。迁移时「Dart 侧自己拼 JSON」这个动作本身就值得单独 review 一遍每个字段的类型。
- 同一族陷阱：`json.Encode`/`jsonDecode` 能用的地方别手写拼串。这里手写是因为要保字段顺序（旧实现顺序一致），代价就是每个值都得自己定性。

### 2026-10-20：演示数据接线时，删掉 mock 符号比留着更安全

- 接完 `com.haoze.diting/apps` 后 `MockInstalledApp` / `mockInstalledApps` 已无人引用。留着它的下场很明确：下一个页面要应用清单时，grep 到「有现成的」就直接用，于是又长出一页假数据。**删掉符号（原位置留注释指向真实数据源）比留着更省后继者的判断成本**，而且 analyze 会立刻暴露任何漏改的引用。
- 但删之前要确认「零引用」是靠 `grep` 而不是靠 `analyze`：Dart 不会报未使用的顶层常量。三个入口都查过——`lib/`、`test/`、`docs/`（文档里那份清单要同步改，否则交接时别人按文档去找一个已删除的符号）。
- `part` 文件（`apps_rows.dart`）与主文件必须同时改：先改一边会编译不过，看着像「改坏了」，其实只是配对没跟上。

### 2026-10-20：测试里 `putStringSet` 的种子必须是 `List`，不是 `Set`

- `LegacyPrefsStore.putStringSet` 的存储形态是**字符串数组**（桥接层 `value.toList()`），`MemoryLegacyPrefsStore` 照此保存；读取侧的 `_stringSet` 只认 `List` 或 JSON 数组字符串，拿到 `Set` 会走不到解析分支直接返回 null。用它做测试种子会得到「读出空集」的假结果——第一次跑就是在这里误判成「互斥清洗没生效」。
- 判据：写测试种子之前先看**存储形态**（`putStringSet` / `putString` / `putBool`），别照着 Dart 侧 getter 的返回类型（`Set<String>`）抄。两者不一致正是这一层的设计。
- 同时暴露的另一个问题：`expect(map, {...})` 的深度比较对 `Map<String, Set<String>>` 是按值比 `Set`，顺序无关；但 `expect(list, [...])` 是**有序**比较。`AppListSort.packageAsc` 逐字符比字符串，`com.a.app` < `com.android.systemui` < `com.b.app`（`.`=46 < `n`=110），按「短前缀在前」的直觉写期望会错。

### 2026-10-20：互斥清洗 + 本地草稿 = 被删的规则会自我复活

- 四张选择页共用三份互斥名单（`blocked_app_packages` / `excluded_app_packages` / `http_inspection_app_packages`）外加 `app_allowlist_rules_json`。A 页删掉某应用的放行规则后，若 B 页（应用独立规则）还抱着进入页面时抄的草稿，用户看到一条已不存在的规则，点「保存」就把它写回去了——互斥清洗当场失效，而且没有任何报错。
- 修法：草稿必须能识别「别人改了同一份键」。`/apps` 用**集合深比较**（`_sameSet(persisted, _lastPrefs)`）；应用独立规则用**指纹字符串**（`appRulesKey(master, rules)`，包名与域名各自排序后拼接），因为那里是多层 Map。判据不是「我用 `ref.watch` 了」，而是「落盘值变了以后本地草稿会不会跟着让位」。
- `watch` 只保证**重建**，不保证**丢弃本地状态**。凡是「本地 draft + 远程真相源」的组合，都要显式写这个让位分支；只 `watch` 而不处理，等价于把 prefs 当成单向管道，用户的草稿反而成了权威。

### 2026-10-20：多个 agent 并行 `flutter test` 会锁住 `build/native_assets/windows/*.dll`

- 症状是 `flutter test` 直接失败并提示 `Flutter failed to delete file at ...build\native_assets\windows\sqlite3.dll`，看起来像权限问题或工程损坏，实际是**另一个 agent 的 `flutter_tester` 正持有那个 DLL**。用 `[System.IO.File]::Open($f,'Open','ReadWrite','None')` 试独占打开能立刻确诊，再 `Get-CimInstance Win32_Process`（含 `ParentProcessId` 与 `CommandLine`）就知道是哪个测试文件在跑：父进程还活着就是同事在跑，等而不是杀。
- 不要删 `build/`、不要 kill 别人的测试进程（会毁掉对方正在跑的几百条用例）。正确做法是等锁释放后重跑；等待期间去做不需要测试的活（读上游 Kotlin 源、补注释、核 line count），别反复重试同一命令。`flutter test --help` 里没有 `--build-dir`，换不出隔离目录；若要并行，只能约定「同一时刻只有一个 `flutter test`」。
- 归因教训：全量 `flutter test` 的失败集合**每次都不一样**（`express_mode` / `native_bridge` / `observability_pages` / `app_layer` 轮换）且单文件跑必过，说明是被并发编辑的邻居文件或抢锁，不是自己的回归。把「我负责的文件 + 守门测试」单独跑一遍拿到全绿，才是可交付的证据；报告里要写清全量红的是哪些、为什么判为他人范围。

### 2026-10-20：原生数据面「注册了回调」≠「表有数据」；UPSERT 语法与 SQLite 版本

- 引擎回调是**逐项开关**，不是「注册了一套」。`tunnel.Engine` 上 `setBatchLogCallback`/`setRaceLogCallback`/`setTrafficCallback`/`setHttpLogCallback` 各自独立；只注册前两个的后果是 `app_traffic_daily` 与 `http_request_log` 恒空，且 `dns_log.packageName` 恒 NULL——因为 `engine_dns.go` 的 `a` 字段来自 `setUIDResolver`+`setAppUidResolver` 这一对，缺任一个都走不进归因分支。判「某表没数据」先 grep 该表的**生产者回调**是否被注册，别只 grep 表名。
- `UIDResolver.resolveUID` 的参数方向是反的：Go 的 `resolveFlowUID` 把 `id.appIP` 传在第一位（Kotlin 侧名字叫 `localIP`），`id.serverIP` 传在 `remoteIP`。`ConnectivityManager.getConnectionOwnerUid(local=app, remote=server)` 要的是 **app 在前**。照名字直觉对调会让每次查询都返回 `INVALID_UID`，包名静默全空——这类「参数名撒不了谎但会误导」的接口，以 Go 侧的调用点为准而不是以 Java 形参名为准。
- `ON CONFLICT ... DO UPDATE` 需要 SQLite 3.24（Android 11 / API 30）。本 app `minSdk = 24`，在 API 24–29 上这不是「约束冲突」而是**语法错误**：Room DAO 里的写法能跑是因为旧版 minSdk 更高，照抄到 Flutter 侧会每 15 秒失败一次。改成 `UPDATE`（`rowcount == 0` 再 `INSERT`），并用差分脚本证明两种写法在 insert/累加/空名保留/跨日 rollover 四类输入上逐列一致——铁律 4 要求「等价重写」必须给差分证据，不能只靠推理。
- `app_name` 的 `CASE WHEN excluded.app_name != '' THEN ... ELSE <旧值> END` 不能简化成无条件覆盖：`PackageManager` 取不到 label 时返回空串，覆盖会把界面上已有的应用名擦成空白。同理，`packageName` 解析失败的行**跳过而不是造 `uid:10123` 假包名**——流量页按包名分组，假包名会渲染成一个不存在的应用。
- 批量写入器自己的 `closed` 标志只能挡**入口**（回调、提交），不能挡**写盘方法**。`close()` 的语义是「先把尾巴刷掉再关执行器」，一旦写盘方法也判 `closed`，`close()` 自己设完标志再调它就等于把尾巴整段丢掉——这个自伤写了两次才发现。
- 时区相关的日键要在**采样时**取，不能在**落盘时**取：批量缓冲会把零点前后的 delta 混进同一批，用写盘时刻的日期会把前一天的字节记到第二天。按 `date` 分桶（`LinkedHashMap<String, ...>`）而不是只存一个 pending map。
- 只给 `diting_express` 建了 writer 的表要**显式判存在**（`sqlite_master` 查询）。`ExpressRulesDatabase` 明确排除了 `app_traffic_daily` 与 `http_request_log`；极速模式注册这两个回调属于「永远写不进去」的死链路，正确做法是只注册 `setUIDResolver`/`setAppUidResolver`（`dns_log` 两库都有）。
- 三个服务的 `activeEngine` 都是 companion 私有。给诊断通道开口子时**只加 `internal fun engineForDiagnostics(): Engine?`**，不要提供 setter、也不要顺手合并那 4 处 `activeEngine = null`——它们是停机时刻意置空的，合并会让 `status()` 在停止后继续返回上一条隧道的计数。
- 不跑 Gradle 也能做真编译自检：`kotlin-compiler-embeddable` + `android.jar` + AAR 里的 `classes.jar` + `flutter_embedding_debug.jar` 直接 `K2JVMCompiler`。编译期还需要把 `kotlinx-coroutines-core-jvm` 放进**编译器自身**的 classpath（否则 `NoClassDefFoundError: kotlinx/coroutines/CoroutineScope`，看起来像代码错）。`R`/`MainActivity` 这类生成物用最小 stub 顶掉即可。这条链路能在 Lead 串行构建之前就抓到符号不存在、import 漏写、签名不匹配。

### 2026-10-20：仪表盘四个数字必须同窗口同口径；`ERROR` 不是「放行」

- 顶部四格（今日查询/缓存命中/已拦截/平均延迟）里只要有一格换了数据源，另外三格就当场失真：本轮把前三格改成「`dns_log` 当日聚合」后，平均延迟仍是「最近 200 行均值」，跨零点或日志量大时两列互相矛盾。凡是四条并排的统计条，先把窗口写进注释，再逐条对来源。
- 缓存命中率的分母要跟 Go 对齐：`dns_cache.go` 的 `hitRatio = totalHits/(totalHits+totalMisses)`，而上游失败（`ERROR`）行的缓存查找**发生在**上游调用之前，因此必须计入分母；被规则拦截的行从不查缓存，不能计入。用「放行行数」作分母会系统性偏高。
- 已知近似要写进代码注释而不是留在心里：stale-while-revalidate 命中在日志里是 `cached=1`，引擎却记进 `staleHits` 而非 `totalHits`，所以 DB 口径的命中率天然略高于引擎，别把它当缺陷去「修」。
- `DnsLogResult` 是四值（PASSED/REWRITTEN/BLOCKED/ERROR）。Dart 侧 switch 只写了前三个时，`ERROR` 会落进 `_` 分支被渲染成「放行」——语义正好相反。加处置枚举后要回头核对每个 `switch` 的 `default` 语义，并让筛选 chip 由枚举 `values` 生成，避免漏项。
- 引擎的 `stats` 是**会话计数**，重启隧道即归零；「今日」类数字只能来自落库表。两套计数并存时，UI 上标明各自窗口，不要混用。

### 2026-10-20：设置项接回旧版前，先分辨「数据集容器」与「全局容器」

- 1.4.3 的键分三类，写错容器就等于写进没人读的抽屉：**按数据集分仓**的 DNS 键（`dns_vpn_prefs` / `diting_express_prefs`，由 `RuleDataset.prefsName()` 决定）、**全局 UI 键**（`dns_vpn_prefs` 里的 `http3_inspection_enabled`、`address_rules_enabled`、`vpn_running`）、以及**独立运行标志**（`express_vpn_prefs/express_vpn_running`）。迁移前逐键 grep 旧版 setter，别按「都属于 DNS 域」归类；`excluded_app_packages` 就是全局键，误放进极速容器后极速模式读不到。
- 三份应用包名列表（禁止联网 / 排除应用 / HTTPS 检查）在旧版有互斥清洗：加入一份要从未选中的另两份删除。只写不删会让同一个应用同时被「禁止联网」和「排除」命中，引擎侧判定顺序决定结果，用户看到的是随机行为。
- 数值型策略键的夹取必须落在写盘处：动态拦截的 2–100 / 10–300 / 60–3600、TTL 秒数等，UI 控件能夹住不代表其他入口（自定义输入、配置导入）也夹住。夹在 `LegacySettings` 的 setter 里，一处生效全局。
- 「三档 preset」不是存一个名字：1.4.3 的缓存预设要**同时覆写 9 个 `dns_cache_*_v2` 键**，引擎只读这套键。只写 `dns_cache_preset_v3` 会让 UI 显示高命中、引擎仍按旧策略跑。反向也要做：旧安装没有 preset 键时，用 `fromPolicy` 从原始键反推档位，否则界面永远停在默认档。
- `SharedPreferences` 写入不可观察。页面 A 写盘、页面 B 已经 build 过就读到旧值，必须有一个显式的 revision provider 在写后自增，让所有读 `LegacySettings` 的 provider 失效重建；指望 `ref.watch(legacySettingsProvider)` 自己发现变化是行不通的。
- 预设服务商在 DNS/DoH/DoT 三组里同名（「腾讯云 DNSPod」出现三次）。换数据源后 `find.text('腾讯 DNSPod')` 这类旧断言会从「找不到」变成「命中多个」，两处都要按 `.first` 或唯一文案重写；这不是测试噪音，而是提醒 UI 上同名可点项本身需要上下文区分。
- 文件逼近 550 行时，`LegacySettings` 这类「一堆访问器」的类拆 part 用**同库 extension** 最省事：既能访问私有 store 与静态 helper，调用点也完全不变。拆完要同时跑 analyze 与全量 test，`part of` 漏写会让符号静默解析失败。

### 2026-10-20：缓存表与竞速排行要按旧版口径聚合，别把失败摊给某个服务商

- Go 的 DNS 缓存是纯内存分片 LRU（`dns_cache.go`），没有任何枚举接口；日志页「缓存表」只能读旧版 Room 写入的 `dns_cache` 表。表里的行是 1.4.3 留下的快照，Go 引擎不会往里写，所以升级后看到空表属正常——空状态文案必须如实说明，不能写「启动后会写入缓存表」。
- 旧版 `DnsCacheDao` 只展示 `expiresAt > now` 的行；Dart 侧查询漏了这条过滤会把过期条目当场显示成 TTL 0，看着像缓存坏掉。
- `RaceLogDao.winnerStats` 的口径是 `success = 1 AND winnerProviderId IS NOT NULL` 再按服务商分组。若直接 `GROUP BY winnerProviderId` 并顺手 `SUM(success = 0)`，失败行（winner 为 NULL）会被算到某个服务商头上；失败数应来自整表汇总，排行只统计胜出。
- 竞速回调对单服务商模式也会触发（`resolver_strategy.go` 里 single 走同一路径），因此排行数据不区分模式，只在 UI 上说明「单模式下这里是上次多路记录」即可。
- 原生侧只有 provider id，显示名要在 Dart 用 `defaultDnsProviders` + `parseUserProviders` 解析；用户自定义服务商的名字就来自 prefs。
- 三个服务（普通/极速/服务器）都要注册 `setRaceLogCallback`：漏一个模式，该模式下的竞速页就永远空白。
- 给设备插测试行时，`adb shell run-as ... sqlite3 "insert ... '...'"` 经多层引号会被吃掉；把 SQL 写到本地文件、`base64 -w0` 后 `echo $B64 | base64 -d | sqlite3 <db>` 最稳。验完必须删掉测试行（`dns_log`/`dns_race_log`/`dns_cache` 三张表一起清），并复原 `dns_resolution_mode`、`dns_log_mode`。

### 2026-10-20：日志页读真实库，但顶部统计不随查询变化；轮询要覆盖三种模式

- 日志列表改读 `dns_log` 后，顶部「今日查询/缓存命中/已拦截/平均延迟」仍长时间停在 0：统计来自 `status` 的 `stats`，而状态只在启动、回前台、手动操作时同步。服务持续运行期间必须定时轮询（5s），并在启动成功后补一次短延迟刷新（700ms）。
- 轮询要分别挂到 `PowerNotifier`（普通/极速）和 `ServerStatusNotifier`（服务器）两个通知器上，且 `dispose` 时取消 timer；只加一处会让另一模式继续显示旧值。
- 页面自身也要在首帧后主动 `syncStatus`，否则从别的 tab 进入时会先看到上一次的统计。
- 真机验收要「查询新域名 → DB 行数 +1 → 等过一个轮询周期 → 截图数字变化」三步都成立；只看到列表新行不能证明统计链路通。
- 清空日志要同时验 DB 与 UI：`select count(*)` 归零、列表进入空状态、平均延迟归零；清空后统计里的累计查询数仍保留属预期（引擎计数不清零）。
- 测试服务器模式日志会临时改 `diting_dns_mode_prefs/log_queries`，验完必须写回 `false` 并 force-stop 重启，否则用户下次启动会持续写日志。

### 2026-10-20：DNS 日志要直写旧库；三模式的日志开关并不同名

- Go 引擎的批量日志走 `setBatchLogCallback`，payload 是短字段 JSON 数组：`d` 域名、`b` 拦截、`t` 类型、`r` 耗时、`a` 应用、`i` 解析结果、`k` 命中来源、`e` 错误、`c` 缓存、`ts` 时间、`ttl`。字段名不要按直觉拼长名。
- 日志落库直接 `SQLiteDatabase.openDatabase` 写 `dns_log`，与 Flutter 的 sqflite 共用同一个文件；库不存在（全新安装）必须跳过而不是新建，否则会覆盖 Dart 侧的建库逻辑。
- 开关不是同一套：普通/极速读 `dns_log_mode`（`all`/`blocked_and_errors`/`off`），服务器模式读布尔 `log_queries`（默认 false）。极速日志写 `diting_express`，普通与服务器都写 `diting_database`。
- 运行统计用 `Engine.getStats()`（`total`/`blocked`）+ `getDNSCacheStats()`（`totalHits`/`totalMisses`/`entryCount`/`hitRatio`）；服务停止后主动把 `activeEngine` 置空，否则状态里会返回上一条隧道的计数。
- 从 adb shell 发起查询时 `app=RootProxy` 是 shell uid 的解析结果，不是引擎串包；判日志字段别把它当缺陷。
- `adb shell run-as pkg sh -c 'cat > /data/data/.../file'` 的重定向必须在 run-as 的 `sh -c` 内执行；写成 `run-as pkg sh -c "cat > 相对路径"` 会在 shell uid 下创建并失败。

### 2026-10-20：极速模式可复用 Go 引擎，但窄路由与模式切换顺序必须自己保证

- 极速模式不必移植 7.9k 行 Kotlin DNS 核心：同一 AAR 的 `startFull` 配合「只注册 DNS 地址路由」的 TUN（`10.0.0.0/30` + 22 个公共 DNS `/32` + 可选 8 个 IPv6 `/128`）即可获得相同语义。判据：`ip route get <非 DNS 地址>` 走 `wlan0`，向 `1.1.1.1:53` 发 UDP/TCP 查询都能拿到应答。
- 极速的 prefs 是拆开的：DNS 键在 `diting_express_prefs`（键名与普通模式相同），运行标志在 `express_vpn_prefs/express_vpn_running`，规则库在 `diting_express`。给 `LegacySettings` 加一个只替换 DNS 容器的视图，比复制整套 getter 稳。
- 切换工作模式时必须先停旧模式、再改 `workModeProvider`：`PowerNotifier` 用「当前模式」选 MethodChannel，先改状态会把 stop 发给新模式的控制器，旧隧道留在后台。`stop()` 内要先捕获 `express` 再 await。
- 极速模式同样会被 `am force-stop` 留下 `express_vpn_running=true`；启动时用原生 `status` 回写并清旗标，不能直接信任持久化值。
- 验证规则过滤要临时建 `diting_express` 并从正常库复制 schema，插入 `ads.example.com` 后通过 `1.1.1.1:53` 查询得到 rcode 3，正常域名仍 rcode 0；测试结束删库，别留测试域名。
- 极速模式的通知 ID/频道必须与普通/服务器分开（2003/`channel_express`），否则同一次启动里两个前台服务会互相覆盖通知。

### 2026-10-20：服务器模式首页必须换成服务器概览；standalone 验收要压到协议层

- 工作模式只改标题、正文仍是普通仪表盘时，首页电源按钮驱动的是 `powerProvider`（VPN），`start()` 会在模式检查处失败，界面只剩「启动失败」而看不到任何服务日志。服务器模式的首页应直接渲染服务器概览页，并保留「切换工作模式」入口，否则用户进了这个模式就出不去。
- 服务器模式的启停证据链：`dumpsys activity services` 有 `isForeground=true` 的 `DitingDnsServerService` → `ss -lun` 有 1053 → `diting_dns_mode_prefs/service_active` 与状态一致；停止后三者都要消失，ServiceRecord 同样有数秒延迟。
- `adb forward` 只转发 TCP；UDP 要验就在设备上用 `nc -u -q 1`，把查询/响应文件 push/pull 回来解析。TCP 查询要自己加 2 字节长度前缀，两条路径都验过才能说 DNS 服务可用。
- 广告拦截要同时验「拦截命中」和「正常域名不受影响」：本次用临时 `ads.example.com` 得到 rcode 3，`www.baidu.com` 仍 rcode 0。测试规则放 `diting_dns_rules` 的 `block_rule` + `block_rule_source(useradd)`，完事必须删库/删规则，别把测试域名留给用户。
- `adb shell sqlite3 "... select count(*) ..."` 的括号会被远端 shell 当语法；SQL 用远端双引号包住、本地单引号包住整条命令，路径转换再用 `MSYS_NO_PATHCONV=1`。
- Flutter 截图是 900×2000、设备是 1080×2400，坐标按 ×1.2 换算后再 `input tap`；滚动后行位置会变，点开关前先重新截图定位。

### 2026-10-20：arm64-only AAR 在 x86_64 模拟器装得上、跑不起来

- `abiList` 含 `arm64-v8a` 不代表模拟器能执行 arm64：APK 会装上 `lib/arm64-v8a/libgojni.so`，但进程是 x86_64，`System.loadLibrary` 报 `dlopen failed: library "libgojni.so" not found`。判「引擎不可用」前先 `unzip -l apk | grep lib/`，确认 ABI 与进程一致。
- 本地联调用 `gomobile bind -target=android/arm64,android/amd64` 生成多 ABI AAR，Gradle 用 `-PtunnelAar=libs/tunnel-debug.aar` 切换；测试 AAR `gitignore`，release 仍只带 arm64，避免 APK 多出约 14 MB。
- VPN 数据面验收要三层：`tun0` 出现 `10.0.0.2/30` → `ping 域名` 能解析（DNS 走 Go）→ `nc` 建 TCP 拿到 HTTP 200。用户态栈不回 ICMP 属预期，`ping` 的 100% loss 不能当失败。
- `am force-stop` 不走 `onDestroy`，`vpn_running` 会残留 true；启动/回前台必须以原生 `status` 回写，否则首页谎报运行中。停止后 `tun0` 与 ServiceRecord 要等 3–5 秒才消失，别在 1 秒内判残留。
- `MethodChannel.setMethodCallHandler` 在无 `WidgetsFlutterBinding` 的纯 provider 测试里会 assert；控制器把 handler 安装延迟到首次平台调用。
- Flutter 页面的 `uiautomator dump` 可能返回上一屏 XML（本次 dump 是主题页、截图却是首页）；冲突时以截图为准，按旧 XML 改布局必然误伤。
- 引擎日志在 logcat 的 `GoLog`（error 级别）；`ApplyRuleSnapshot`、`StartFull`、`HandleTCP` 是判断配置是否真正生效的最快证据。

### 2026-10-20：Room 库只能原文件打开；Maven 镜像要覆盖插件自带的 `buildscript`

- 兼容旧库不能 `openDatabase(..., version:)`：带上 version 会改写 Room 的 `user_version`/触发迁移。做法是 `databaseExists` → 直接 `openDatabase(path)`，打开后核对 `user_version` 仍为 3，`-wal` 仍在。文件名固定 `diting_database` / `diting_express` / `diting_dns_rules`。
- 预设白名单受 `default_whitelist_initialized` 与 `default_whitelist_seeded_version = versionCode*1000+2` 双重门控；升级版本会删 `source='preset'` 的孤儿再重种。`groupName` 取自资产里的分类注释（如「Google / Android 平台核心」），漏写会与旧库肉眼可辨地不一致。
- 本地 `repo.maven.apache.org` 返回 403（`curl` 实测，镜像 200）。只改 `settings.gradle.kts` 的 `pluginManagement` 不够：Flutter 插件（sqflite_android）的 `build.gradle` 自带 `buildscript { repositories { google(); mavenCentral() } }`，必须在 settings 里用 `gradle.beforeProject { buildscript.repositories { maven(...) } }` 抢先注入镜像，否则插件工程配置阶段就失败。
- 库层验收要「UI 操作 + 直接回读 SQLite(+WAL)」双证：只看界面无法证明写入了旧表，只看主库文件会漏掉尚在 WAL 里的行；同时核对 `*_source` 的 `useradd/preset` 标签与级联删除。

### 2026-10-20：旧版数据衔接不能用 `shared_preferences`；截图坐标要取 uiautomator bounds

- 插件的 Android 实现把键写进 `FlutterSharedPreferences` 并加 `flutter.` 前缀，旧版的 `dns_vpn_prefs` 等 11 个容器一个都读不到。同 applicationId 下必须用原生 `getSharedPreferences(<旧容器名>)` 建桥，键名/落盘值逐字保留（`gold→indigo`、`server→dns`、底栏 id、1053 端口）。
- 能否覆盖安装由 versionCode 决定，只改 versionName 会被判降级；按 `major*10000+minor*100+patch` 从 10403 升到 10404，并用 `apksigner verify --print-certs` 对 SHA-256 确认同签名。
- 会话里显示的截图会被等比缩放，按目测比例换算 `input tap` 会落进相邻行（本次把「浅色模式」点成「跟随系统」，落盘值 `system` 正好暴露了误点）。点击前用 `uiautomator dump` 读 bounds 取中心；Compose 的文案在 `content-desc`，`text` 常为空。
- 验证「旧值被读取」不能只看截图，要回读落盘文件；再在同一屏写入两个不同值（light→dark）并各回读一次，才能同时证明读、写两端都通。

### 2026-10-20：嵌套 `Scaffold` 把浮条高度灌进 `padding.bottom`，页面视口停在浮条上沿

- 浮条壳的 `Scaffold(extendBody: true)` 会把底栏高度写进正文的 `MediaQuery.padding.bottom`；内层页面的 `SafeArea` 又把它变成底部 `Padding`，滚动视口于是止于浮条上沿。浮条背后只剩页面背景，肉眼就是「悬浮底栏后面有一块矩形背景」。
- 修复放在 `CommonScaffold` 的**正文**而不是整个壳：正文的 `padding.bottom` 取 `min(padding.bottom, viewPadding.bottom)`。`SafeArea` / `DockSpacer` 拿到系统安全区，同一 `Scaffold` 里的 SnackBar 仍按浮条高度布局，不会被浮条盖住。
- 这类回归要量**滚动视口**的矩形（`ListView` 底部 == 屏高），不要量 `PageBody` 的 `MediaQuery.padding.bottom`：`SafeArea` 已经把 padding 消费掉了，读到恒为 0，用例会永远通过。
- 探针在路由切换动画未结束时截图，会出现所有块同向平移（本次为 0.04×屏宽 ≈ 16.5dp），并连带把卡片误报成贴边/缩进异常；看到整页同向偏移先等 1–2 秒重截，别改布局。

### 2026-10-20：`CommonCard` 默认没有内边距；绕过 `PageBody` 的滚动页会把正文顶进半透明栏

- `CommonCard` 的 `padding` 默认是 `EdgeInsets.zero`。列表卡片看起来有留白，是因为 `ListItem` 自带 16dp；自绘 `CommonCard(child: Text/Row)` 不传 `padding` 时正文会贴住圆角边缘。新增自定义卡先按 `EdgeInsets.all(16)` 起步，再在真机上量内容 x 是否与列表正文同为 32dp。
- 二级页必须走 `PageBody`（它负责 `appBarInset`、`MediaQuery.removePadding` 与浮层 scope）。裸 `ListView` 会让首屏正文滚到半透明顶栏下面，探针会报「内容画进顶栏区」。
- 探针只登记长度 <200 的 `RichText`，长段落会被跳过；相邻标题与卡片因此会被报成数百 dp 的假留白。看到「大段正文中间的留白」先核对截图，别改布局。
- `tail` 的 `layoutShift` 只能证明两次探针之间没动，不能证明滚到了底；长页要人工 swipe 后截图复核。Git Bash 下同一条命令里的后续 `node` 调用不会继承前一条的 `MSYS_NO_PATHCONV`，每个路由参数都要单独加。

### 2026-10-20：功能中心迁移时 `PageBody` 不在 `lib/ui`；Git Bash 会改写以 `/` 开头的参数

- `PageBody` 由 `lib/widgets/stat_strip.dart` 导出，不在 `lib/ui`。新增页面时先按符号查导出位置，再批量补 import；analyze 的「未定义」往往只是 import 猜错，不要因此改写共享组件。
- Git Bash 会把脚本参数里的 `/hub` 转成 `C:/Program Files/Git/hub`，路由探针要加 `MSYS_NO_PATHCONV=1`；探针 `go` 只截到首页时，改用 `adb shell input tap`（坐标按实测 dpr 换算）再截图验证。

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

- `.bat` 保持纯 ASCII，中文说明放 `.md`（本项目落在 `DITING_flutter/README.md` §2）；改完用「统计 >127 字节数 == 0」自检。把 `chcp 65001` 写进文件救不了，`cmd.exe` 按 OEM 代码页解析脚本，它执行前就已经乱了。
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
