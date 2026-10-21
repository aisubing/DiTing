# AGENT_MISTAKES.md

> 只留能改变后续决策的教训与修法，按时间倒序。收录门槛：**当初不知道就会做错下一步**。
> 一次性环境数字、已修且不会复现的单点细节、能从铁律推导出的复述，一律不留。

## 通用铁律（跨条目去重）

1. **期望源**：协议和布局以规范样例为准；测试报红先分清是期望错还是代码错，绝不能改被测代码把测试改绿；位段先手写逐位表（含跨字节拆分）；解析器先列「像但不合法」的负例（`[::1]:53`、`256.1.1.1`、`2001:db8::1::2`）。
2. **可达性**：严重度 = 缺陷机制 × 可达面。双向 grep 调用链（Go 导出方法 → gomobile → Kotlin 调用点，含接口注入与默认构造），并查设备、模式门；legacy 或平行实现要先证明「生产上真会执行」。判「会执行」得走完整控制流（`if`、循环守卫、跳转目标）；崩溃类高危先找「现场为什么没炸」的反证。
3. **代理结论零权重**：子代理说的「已确认 / 高危」要逐条回读源码到调用链两端，组合主张拆开验；计数和规模自己数，「实测 N」必须出自本会话的工具输出；核验的是它的位表和判据本身。报告没到手等于没有信息；复核按 6–12 条分批，出现「待定」立即拆小批重派。
4. **归因顺序**：先用 `git show HEAD:<file>` 确认基线，别把「我以为它没做」当事实，据错判写下的改动整体回退。判「问题不存在」要显式走一遍发生路径——「代码保留了 X」通常说明 X 会被后续流程消费，恰恰不说明无害；「机制成立但修它不划算」记「本轮不改」，不能记「证伪」。
5. **交付自证**：多文档分类用脚本做集合差集，证明互斥；清单要声明口径和扩展名；误报、撤回都留痕，编号不复用；补「对称性差距」之前先确认被对标的那一半真被消费——没人渲染的字段照抄过去只会放大死代码。
6. **产物时序**：AAR、jar、exe 只在源码定稿后重建，顺序是改源码 → `gofmt`/`go vet`/`go test` → 构建 → 目标平台编译、单测、启动验证；退出码 0 或单个文件能读都不算完成；`.vue` 改动要跑含 `vue-tsc` 的完整构建。
7. **仓内优先**：列「需要外部取证」之前先搜源码、测试和仓库注释，作者注释比记忆可靠；判「无法修」之前把平台 API 查完（「模型缺字段」往往意味着「该换判据」）；以「要加 DB 字段或迁移」为由放弃的，必须附上「已排除的替代判据」。
8. **改动方式**：改代码一律用编辑工具，不要用 `sed -i`、PowerShell `-replace` 或 Python 脚本做文本替换。同类事故已出三次：`-replace` 把 `$1`、`$&` 当反向引用、多行替换里 `\r\n` 还会错位，`sed -i` 直接把脚本改出 `SyntaxError`。文件改坏了别试图修补，`git checkout --` 回基线重做更快。
9. **测试红线的归因顺序**：`tap` 打不中（下层文字还在、命中测试落到别处）先查有没有全屏遮罩/弹窗，不要先改文案断言；`Expected 0` 与 `Expected 1` 之间要先问「期望值是不是写成了迁就实现」。改测试前必须能用一句话说清「产品行为错在哪」，说不出来就是改测试凑绿。
10. **全局副作用**：`dart format` / `flutter analyze` / 不带路径的 `git commit` 都是全局操作，会碰到别人的文件与索引；只对自己作用域跑。收尾必查 `git status --short` 里有没有不属于本轮的文件。

## 事件记录（时间倒序）

### 2026-10-21：同一个职责被两层各做一次，量出来就是两倍

- 日志仪表盘卡片左右各留 32.4dp，首页同款卡片是 16dp：`_CardColumn` 的 `Padding` 与每张卡片外的
  `_card()` 各调了一次 `dashboardMobileSideOf(width)`。加新组件时把「留横向边距」写进了它的注释，
  却忘了旧包装还在，调用点全是 `_card(context, X)` 形式，看起来一切正常。
- 判据：**每加一层容器，就去 grep 它想负责的属性的既有施加点**。间距、内边距、对齐重复后视觉上
  只是「更大」而不是「坏掉」，analyze 与单测都抓不到，只有量像素能抓到——前提是对照组是同类页面。
  修法：卡片自身不带外边距，横向边距只有一个来源。

### 2026-10-21：量具会污染被测状态——「设置丢失」可能出在测量方法上

- 探针 `ui_probe.mjs` 的 `connect()` 开头就 `am force-stop` + `am start`，于是「切玻璃档位 → 用量」
  必然量到**重启后**的画面：档位回默认「关闭」，底栏又是实色白胶囊。连续两轮据此判「玻璃没生效」，
  这个结论是测量方法造成的。修法是 `go <route>` 走 `connect({ attach: true })` 只附着不重启，
  `now` 只量当前画面——**凡是「先改变内存态、再观察」的验证都必须走它**。
- 判据：任何「设置 A 之后 B 应该变」的实机验证，先确认 A 的状态跨过了测量边界。量具会重启进程而
  设置不落盘时，这条链路从设计上就验不了，优先修量具。
- 与之互为镜像的真缺陷（别混为一谈）：玻璃档位本来只存内存（`select()` 只改 `state`），所以
  「退出再进来档位没了」也一直没被发现；修法是把三档一起落盘到 `dns_vpn_prefs`。
  **验证时的「设置丢失」和产品里的「设置不持久」长得一模一样**，先分清是哪一个。
- 成对 API 的同源坑：`LiquidGlassScope` 只决定「要不要走玻璃路径」，真正把背景抓成离屏图的是
  `LiquidGlassHost`；只挂前者时每个 pane 静默退到 `_addFrost` 兜底，渲染结果与「关闭」逐像素相同。
  **成对出现的 API 要去 grep 另一半的挂载点**（当前两者成对挂在 `lib/app/app.dart`）。

### 2026-10-21：真机判据只能落在实测几何上，且要先排除假阳性

- 正确形态是「内容画进顶栏区(y < 栏底)」这类**几何**判据，不是 `findsOneWidget`——文本在不在屏幕
  上是两回事。报告必须带原始数字（首块 y、栏底、内容区底、下方余量），否则离线复检无法识破假阳性。
- 已知假阳性：路由切换动画未结束就截图 → 整页同向平移（约 0.04×屏宽），等 1–2s 重截；`tail` 的
  `layoutShift` 只证明两次探针之间没动，不证明滚到了底；探针只登记长度 <200 的 `RichText`，长段落
  被跳过会报出数百 dp 的假留白；`uiautomator dump` 可能返回上一屏的 XML，与截图冲突时以截图为准。
- 「留白异常」要能区分「上下对称的居中」和「上方空、下方挤」，加 `gapAbove/gapBelow` 比值。
- 工具侧：Git Bash 会把脚本参数里的 `/hub` 改写成 `C:/Program Files/Git/hub`，每个路由参数都要
  单独带 `MSYS_NO_PATHCONV=1`（同一条命令里的后续调用不继承）；`input tap` 的 dpr 要按探针实测
  屏宽现算（默认 3.25，真机 2.625 就会点到隔壁行）；坐标取 `uiautomator` 的 bounds 中心。
- 换页面栈不会关掉上一页留下的浮层（`PopupRoute`），跳路由前先
  `popUntil((route) => route is! PopupRoute)`。

### 2026-10-21：写文档最容易犯的不是「写得少」，而是「把约定写成现状」

- 合并 32 份 Markdown 时，两处把「已实现但没接线」和「旧版有、本仓没有」写成了当前行为：
  ① 写「仪表盘四格来自当日聚合」——真实聚合 `dnsLogDailyStatsProvider`（`log_providers.dart:64`）
  **至今零消费方**，页面实际读 `LogDashboardSnapshot.mock()`，文档另一节又如实写着「概览块仍走演示
  数据」，**自相矛盾**；② 写「旧版三条一次性迁移标记」，其中两条只存在于旧版 Kotlin、本仓全无。
- 判据：**任何一句话先问「这是现在的行为，还是我主张的行为」**。「全部/都/统一/必须」这类断言要去
  grep 消费方；**消费方为零就是「未接线」，不是「已实现」**。规范属于「主张」，必须与唯一实现位置
  一起写。精简时尤其危险：原文的「待接线」「本轮暂不」这类限定词会被顺手删掉。
- 同源反例：引用类型名也要 grep。曾经凭空写过 `DnsLogResult` 这个**全仓不存在**的类型
  （`dns_log.result` 就是字符串，四值 `PASSED`/`REWRITTEN`/`BLOCKED`/`ERROR`），并据此断言
  `switch` 的 `_` 会把 ERROR 渲染成放行——而两处 `switch` 其实都显式处理了。旧文档里的符号在合并/
  精简时会被「记忆」补全成看起来合理的名字，只有 grep 能证伪。
- 代码侧同源决定：接完真源后**删掉零引用的 mock 符号**（原位置留一行注释指向真实数据源）比留着
  安全，否则下一个人 grep 到「有现成的」就长出一页假数据。删之前用 grep 覆盖 `lib/`、`test/`、
  `docs/`（Dart 不报未使用的顶层常量），并同步改掉引用它的文档。

### 2026-10-21：全局弹窗挂在 `builder` 里会吃掉所有测试的点击，而报错指向「点不到按钮」

- 首启「使用须知」弹窗（`InitialAgreementGate` 包在 `DitingApp.builder` 的 `child` 外）上线后，
  三条毫不相干的用例同时变红，失败信息是 `Found 0 widgets with text "…"` + 一长串命中测试警告——
  看起来像「浮层坏了」或「文案改了」，实际是**遮罩吃掉了点击**（`takeException()` 拿不到异常，
  点击失败只是 warning）。
- 判据：下层 widget 树仍在（`find.text` 能找到）但 `tap` 打不中 → 先怀疑有一层全屏
  `Stack`/`ModalBarrier`，而不是怀疑控件本身。
- 修法：把「同意」态做成默认前置而非逐用例点弹窗——`test/support/test_hooks.dart` 的
  `appTestOverrides()`，**所有挂 `DitingApp` 的测试统一用它**；要测弹窗本身传
  `skipInitialAgreement: false`。反例：**不要**预置 store 里的 `initial_agreement_accepted`
  ——store 实参在 `pumpWidget` 时才 override，来不及；用 provider override。

### 2026-10-21：`format` / `analyze` / `commit` 都是全局操作，会碰到别人的文件与索引

- 只对自己作用域的路径跑 `dart format` / `flutter analyze`。队友跑 `dart format lib` 一次改了
  150 个文件（含冻结的 `lib/ui`），`git diff` 因此无法分辨格式化与语义改动，等于把「设计系统零
  改动」变成口头承诺。`git diff -w --stat <base> -- lib/ui/` 仍非零时要逐条读 `+`/`-` 行，确认是
  格式化后**整体还原** `git checkout <base> -- lib/ui/`，不要手工挑。并行阶段禁止任何目录级格式化。
- **多人共用一个 `.git/index`**：不带路径（或 `--only`）的 `commit` / `--amend` 会吃下索引里的全部
  内容，把别人已暂存的几十个文件卷进来。只用 `git commit -- <明确文件列表>`，改完用
  `git show --name-only --format='' HEAD` 回读清单。卷进来了就 `git reset --soft HEAD~1` +
  `git reset`（mixed）退回工作区重做，**不要** `git rebase -i` 去「摘」别人的 hunk。
- `git commit -- path` 只提交**已跟踪**文件，新建文件会被漏掉（漏过 6 个新页面，编译直接断）。
  提交前先 `git status --porcelain <我的路径>`，把 `??` 的显式 `git add`。

### 2026-10-21：`indexWhere(location.startsWith)` 恒返回 0——`/` 是任何路径的前缀

- `_branchOrder[0] == '/'`，于是 `indexWhere(location.startsWith)` 让 `/hub`、`/logs` 全被判成
  0 号 branch。修法是**最长前缀**匹配且前缀后必须紧跟 `/` 或结束（否则 `/logs` 命中
  `/logsomething`）。注意「修参数传反」的写法 `indexWhere((it) => location.startsWith(it))`
  仍恒返回 0——**没修「`/` 抢先命中」**。
- 教训：`startsWith` 做前缀匹配时先问「有没有一个空前缀/根前缀会抢先」。这类错误在单独调用时表现
  为「断言期望值写成 0」，很容易被误改成迁就实现。

### 2026-10-21：编辑工具的一次换行丢失，只有 `compileDebugKotlin` 抓得到

- 改 Kotlin 时两行被合成一行，Dart 侧正常、`flutter analyze` 照过，只有 `compileDebugKotlin` 报
  `Unresolved reference` + `Missing return statement`。
- 铁律：改过 `android/**/*.kt` 就必须跑
  `cd android; .\gradlew.bat compileDebugKotlin --console=plain -q`（失败时去掉 `-q` 并 grep
  `^e:`）。`flutter analyze` 不覆盖 Kotlin，`flutter build apk` 太慢不适合内循环。
- 同类：Kotlin 通道方法加参数后，Dart 侧 `implements` 类会报 `isn't a valid override`，所以两侧
  要**一起改、一起验**，不要先提交一侧。

### 2026-10-21：输入框只写 `TextEditingController`、不写回 provider，测试全绿但功能是错的

- 测速页把域名填进 `TextEditingController`，`_run()` 却读 provider，于是**测的是旧域名**。
  298 个测试全绿——桩 runner 不校验入参，断言只看「结果渲染出来没有」。
- 铁律：一个字段同时存在「输入框」和「状态源」时，先写清谁是唯一真相。`controller` 只是显示层，
  业务逻辑读 provider，因此 `onChanged` 里要落回 provider。自查：grep 所有提交动作里的
  `ref.read(...)` 字段，确认它在「用户打字」路径上也有写入口（只在 `build` 里灌一次不算）。
- 同源：默认值别照枚举声明顺序猜（旧版 `NetworkToolMode` 第一个是 `SPEED_TEST`，页面初值却是
  `PING`），要从 ViewModel 的 `MutableStateFlow` 初值读。

### 2026-10-21：`part of` 的库根被删后，剩下的 part 会「全员编译失败」

- 删库根后四个 part 全部报 `part_of_non_part`，报错位置却在**库根**上，看起来像「我删错了」。
- 删库根必须同时删掉全部 `part` 文件，并先 `grep -rn "<库文件名>"` 双向确认没有页面 import。
  `part` 与主文件必须同时改，只改一边会编译不过，看着像「改坏了」。

### 2026-10-21：滚动与动效的测试配方

- 浮条（`NavigationDock`）在场的页面不能用 `pumpAndSettle`：玻璃层持续动画会直接超时。用
  `pump()` + `pump(Duration)`；中间态用定步 `pump()` 观察，终态才交给 `pumpAndSettle`。
- `PageBody` 是懒构建 `ListView`，靠后的分组**还没被建**，`find.text` 必然 `findsNothing`。
  断言视口外内容要先 `drag` 把尾部顶上来；反之，断言「页面上没有某个数字」若该数字可能在视口外，
  `findsNothing` 恒真。需要「整页入口同时存在」的目录页别用懒构建，改
  `AppBarClearance` + `SingleChildScrollView` + `Column`。
- `jumpTo(maxScrollExtent)` 在「刚追加内容的那一帧」拿到的是旧上界（新 item 布局在下一帧）。判据要
  落在「内容确实进了视口」：多次 `drag` + `pumpAndSettle`。
- 长页粗扫每轮重新取 `ScrollableState.position`，别缓存（底栏一改 shell 就重建，缓存的 position
  静默失效）。命中后按 `getRect(row).center.dy - 视口中线` 微调：滚到视口边缘时 `tap()` 会落在固定
  浮条上，而 `ensureVisible` 认为「已在视口内」不会再挪。`find.text` 会同时命中页面行与底栏标签，
  断言前用 `descendant(of: find.byType(ListView))` 排除浮条。

### 2026-10-21：`CommonScaffold.body` 不预留顶栏浮位是「零报错」缺陷，必须用源码扫描守住

- `CommonScaffold` 走 `extendBodyBehindAppBar` 语义：正文从 y=0 起排，顶栏浮在正文之上；compact
  浮层更是把高 `sheetAppBarHeight = 68` 的 `FloatingHeader` 直接盖在正文上。**留白只由正文自己
  负责**：用 `PageBody` / `AppBarClearance`，或滚动件自己在 `padding` 里加 `contentTopPadding`
  （页面用 `appBarInset`）。
- 把 `ListView` / `Column` / `Center` / `SizedBox(height:)` / `Form` 直接塞给 `body:` 完全合法：
  analyze 不报、widget 测试不失败、路由冒烟也过，**只有真机跑到那一屏才看得见**（一次修掉 44 个
  文件里约 35 处）。
- 结构性护栏：`test/body_top_inset_test.dart` 扫 `lib/pages` 下每个 `body:` 表达式，顶对齐容器里
  没有留白符号就失败。**加护栏必须先做负向对照**：故意写一个漏留白的 body 确认报红，再删掉。
- 留白加在哪一层要成对看清：`Column` 首件顶到最上时留白加在**整列外面**（`AppBarClearance`），
  加在内层 `Expanded` 列表的 padding 里只把列表往下推，上面那行说明照旧被压；滚动件则要加在
  **自己的 padding** 里，外面套 `Padding` 会把视口裁在顶栏下沿。同一 `Column` 里这两种错法会互相
  抵消成「看起来只有一点点不对」。
- 排查「多处同源」别一个个点：先按目录 grep `^\s*body:\s*`，用脚本判定每个 body 的形态产出清单再
  动手，手工看 100+ 调用点必然漏。

### 2026-10-20：互斥清洗「先写 A 再读 A 做差集」会把保存清空；草稿还会让被删规则复活

- `_dropOverlaps` 写成 `setBlockedApps(packages)` 之后紧接 `blockedAppPackages.difference(packages)`。
  `LegacySettings` 是 store 的直读视图，第二句读回来**就是刚写进去的那一份**，差集恒为空——用户
  点「保存」等于清空自己刚勾的选择，SnackBar 照样显示「已保存」。不抛异常、analyze 也看不出。
- 修法：显式传归属方（`_Owner` 枚举）并跳过它。上游 Kotlin 不踩坑是因为
  `setBlockedAppPackages(context, getBlockedAppPackages(context) - selected)` 是**先读后写**；
  Dart 拆成两条语句就变了顺序，等价重写必须逐句核对求值时机。推广：任何「写 X → 从 X 读 → 再写
  X」的序列，先问「这一句读的是不是我自己刚写的」。
- 第二形态：四张选择页共用三份互斥名单，B 页若抱着进入时抄的草稿，A 页删掉的规则会被 B 页「保存」
  写回去。修法是草稿能识别「别人改了同一份键」——集合深比较或指纹字符串。**`ref.watch` 只保证
  重建，不保证丢弃本地状态**：凡是「本地 draft + 远程真相源」，都要显式写让位分支。

### 2026-10-20：并行 `flutter test` 会锁住 `build/native_assets/windows/*.dll`

- 症状是 `Flutter failed to delete file ... sqlite3.dll`，像是权限问题或工程损坏，实际是**另一个
  agent 的 `flutter_tester` 正持有那个 DLL**。用 `[System.IO.File]::Open($f,'Open','ReadWrite',
  'None')` 试独占打开可确诊，再用 `Get-CimInstance Win32_Process`（含 `ParentProcessId`）找出是
  谁。父进程还活着就是同事在跑，等而不是杀；不要删 `build/`。`flutter test` 没有 `--build-dir`，
  要并行只能约定「同一时刻只有一个 `flutter test`」。
- 归因教训：全量测试的失败集合**每次都不一样**（`express_mode` / `native_bridge` /
  `observability_pages` 轮换）且单文件跑必过，说明是被并发编辑的邻居文件或抢锁，不是自己的回归。
  把「我负责的文件 + 守门测试」单独跑一遍拿到全绿才是可交付的证据。

### 2026-10-20：跨语言契约以对端结构体的字段类型为准，不以本侧的 `toString` 为准

- `toEngineJson()` 把 `port` 写成字符串，而 Go 侧 `outboundProxyConfig.Port int` 由 `json.Unmarshal`
  解析——整份配置解析失败，代理**静默不生效**，UI 却显示「已保存」。生成 JSON 的 switch 必须按类型
  分支（bool / int / 其余走引号），不能只特判 bool。
- 这类缺陷 analyze 抓不到（拼接永远是 `String`），「保存成功」也抓不到，**只能被形状断言抓到**：
  测试要断言整串逐字节相等，而不是 `contains('port')`。能 `jsonEncode` 就别手写拼串；上游用
  `JSONObject.put("port", port)`（Int 重载）写的是数字，这是最省事的新旧对照证据。

### 2026-10-20：原生数据面「注册了回调」≠「表有数据」；参数方向与 SQLite 版本

- 引擎回调是**逐项开关**：`setBatchLog/Race/Traffic/HttpLogCallback` 各自独立，漏注册的表恒空；
  `dns_log.packageName` 来自 `setUIDResolver` + `setAppUidResolver` 这一对，缺任一个都走不进归因
  分支。判「某表没数据」先 grep 该表的生产者回调是否注册。三个服务（普通/极速/服务器）都要注册
  `setRaceLogCallback`，漏一个模式该模式的竞速页就永远空白。普通与极速已收敛为
  `EngineDataPlane.attachResolvers/attachTraffic/attachHttp` 三个入口，**服务器模式仍是各自直调**
  （只注册了 batch/race，别以为它也有归因与流量表）。
- `UIDResolver.resolveUID` 的参数方向是反的：Go 把 `id.appIP` 传在第一位（Kotlin 形参名叫
  `localIP`），而 `getConnectionOwnerUid(local=app, remote=server)` 要的是 app 在前。照名字直觉
  对调会让每次查询都返回 `INVALID_UID`，包名静默全空——**以 Go 侧调用点为准**。
- `ON CONFLICT ... DO UPDATE` 需要 SQLite 3.24（API 30），本 app `minSdk = 24`，在 API 24–29 上
  这是**语法错误**且每 15 秒失败一次。改成 `UPDATE`（`rowcount == 0` 再 `INSERT`），并用差分脚本
  证明两种写法在 insert / 累加 / 空名保留 / 跨日 rollover 四类输入上逐列一致。
- `app_name` 的 `CASE WHEN excluded.app_name != ''` 不能简化成无条件覆盖（`PackageManager` 取不到
  label 时返回空串，会擦掉界面上已有的应用名）；`packageName` 解析失败的行**跳过而不是造
  `uid:10123` 假包名**（流量页按包名分组，假包名会渲染成不存在的应用）。
- 批量写入器的 `closed` 标志只能挡**入口**，不能挡写盘方法：`close()` 的语义是「先刷尾巴再关执行
  器」，写盘方法也判 `closed` 等于把尾巴整段丢掉（这个自伤写了两次才发现）。时区日键要在**采样时**
  取，不能落盘时取：批量缓冲会把零点前后的 delta 混进同一批。
- 只给 `diting_express` 建表的 writer 要显式判表存在（`sqlite_master`）：`ExpressRulesDatabase`
  排除了 `app_traffic_daily` 与 `http_request_log`，极速模式注册这两个回调属于死链路。
- 三个服务的 `engineForDiagnostics()` 是刻意加的只读口子（companion 的 `activeEngine` 私有，反射会
  被 R8 改名而静默失效）。**不要**加 setter、也不要合并那几处 `activeEngine = null`——它们是停机
  时刻意置空的，合并会让 `status()` 返回上一条隧道的计数。
- 旧库写入：`SQLiteDatabase.openDatabase` 直写与 sqflite 共用同一文件，库不存在（全新安装）必须
  跳过而不是新建；批量日志 payload 是短字段 JSON 数组（`d`/`b`/`t`/`r`/`a`/`i`/`k`/`e`/`c`/`ts`/`ttl`），
  别按直觉拼长名。插测试行用 `base64 -w0` + `echo $B64 | base64 -d | sqlite3 <db>`（多层引号会
  被吃掉）；验完必须删测试行并复原 `dns_resolution_mode`、`dns_log_mode`。

### 2026-10-20：仪表盘四个数字必须同窗口同口径；`ERROR` 不是「放行」

- 顶部四格只要有一格换数据源，另外三格就当场失真：把前三格改成「`dns_log` 当日聚合」后，平均
  延迟仍是「最近 200 行均值」，跨零点时两列互相矛盾。四条并排的统计条先把窗口写进注释再对来源。
- 缓存命中率的分母要跟 Go 对齐（`hitRatio = totalHits/(totalHits+totalMisses)`）：上游失败
  （`ERROR`）行的缓存查找发生在上游调用之前，必须计入分母；被规则拦截的行从不查缓存，不能计入；
  用「放行行数」作分母会系统性偏高。stale-while-revalidate 命中在日志里是 `cached=1`，引擎却记进
  `staleHits`，所以 DB 口径天然略高于引擎——这是已知近似，写进注释，别当缺陷去「修」。
- `dns_log.result` 是四值字符串（`PASSED`/`REWRITTEN`/`BLOCKED`/`ERROR`）。`switch` 只写前三个
  时 `ERROR` 会落进 `_` 被渲染成「放行」，语义正好相反。加处置枚举后要回头核对每个 `switch` 的
  `default`，并让筛选 chip 由枚举 `values` 生成。
- 引擎的 `stats` 是**会话计数**，重启隧道即归零；「今日」类数字只能来自落库表。两套计数并存时要
  在 UI 上标明各自窗口。

### 2026-10-20：设置项接回旧版前，先分辨「数据集容器」与「全局容器」

- 1.4.3 的键分三类，写错容器就等于写进没人读的抽屉：**按数据集分仓**的 DNS 键
  （`dns_vpn_prefs` / `diting_express_prefs`；Kotlin 侧权威映射是 `RuleDataset.prefsName()`，三值
  `NORMAL`/`EXPRESS`/`DNS_MODE` → 第三个是 `diting_dns_mode_prefs`；Dart 侧只镜像前两份，靠
  `LegacySettings(dnsContainer:)` 切容器、常量见 `LegacySettings.expressContainer`）、
  **全局 UI 键**（`http3_inspection_enabled`、`address_rules_enabled`、`vpn_running`）、
  **独立运行标志**（`express_vpn_prefs/express_vpn_running`）。`excluded_app_packages` 就是全局键，
  误放进极速容器后极速模式读不到。
- 三份应用包名列表（禁止联网 / 排除应用 / HTTPS 检查）在旧版有互斥清洗，只写不删会让同一应用
  同时命中两份，引擎判定顺序决定结果，用户看到的是随机行为。
- 数值型策略键的夹取必须落在**写盘处**（动态拦截 2–100 / 10–300 / 60–3600、TTL 秒数）：UI 控件
  夹住不代表自定义输入与配置导入也夹住，夹在 setter 里一处生效全局。
- 「三档 preset」不是存一个名字：缓存预设要**同时覆写 9 个 `dns_cache_*_v2` 键**（引擎只读这套），
  只写 `dns_cache_preset_v3` 会让 UI 显示高命中、引擎仍按旧策略跑；反向也要做——旧安装没有 preset
  键时用 `fromPolicy` 从原始键反推档位。
- `SharedPreferences` 写入不可观察：A 页写盘、B 页已 build 过就读到旧值，必须有一个显式的
  revision provider 在写后自增，让所有读 `LegacySettings` 的 provider 失效重建。
- 预设服务商在 DNS/DoH/DoT 三组里同名（「腾讯云 DNSPod」出现三次），换数据源后 `find.text` 会从
  「找不到」变成「命中多个」——这不是测试噪音，而是提醒同名可点项需要上下文区分。
- 文件逼近 550 行时，`LegacySettings` 这类「一堆访问器」的类拆 part 用**同库 extension** 最省事：
  能访问私有 store 与静态 helper，调用点不变。拆完同时跑 analyze 与全量 test。

### 2026-10-20：旧表口径与三模式差异，按旧版口径聚合

- `dns_cache` 表是 1.4.3 留下的快照，Go 引擎（纯内存分片 LRU，无枚举接口）不会往里写，升级后
  空表属正常——空状态文案必须如实说明。旧版 `DnsCacheDao` 只展示 `expiresAt > now` 的行，漏了这条
  过滤会把过期条目显示成 TTL 0。
- `RaceLogDao.winnerStats` 的口径是 `success = 1 AND winnerProviderId IS NOT NULL` 再分组；失败行
  （winner 为 NULL）应来自整表汇总，排行只统计胜出。竞速回调对单服务商模式也会触发，所以排行不
  区分模式，只在 UI 说明「单模式下这里是上次多路记录」。原生侧只有 provider id，显示名要在 Dart 用
  `defaultDnsProviders` + `parseUserProviders` 解析。
- 日志开关不是同一套：普通/极速读 `dns_log_mode`（`all`/`blocked_and_errors`/`off`），服务器模式
  读布尔 `log_queries`（默认 false）；极速日志写 `diting_express`，普通与服务器写 `diting_database`。
- 统计轮询要同时挂到 `PowerNotifier`（普通/极速）和 `ServerStatusNotifier`（服务器）并在 `dispose`
  时取消，只加一处会让另一模式显示旧值；页面自身也要在首帧后主动 `syncStatus`。真机验收三步：
  查询新域名 → DB 行数 +1 → 等过一个轮询周期 → 截图数字变化；只看到列表新行不能证明链路通。
- 从 adb shell 发起查询时 `app=RootProxy` 是 shell uid 的解析结果，不是引擎串包。

### 2026-10-20：模式切换必须「先停旧的、再改状态」；每种模式的首页要能自己出去

- 切换工作模式时先停旧模式、再改 `workModeProvider`：`PowerNotifier` 用「当前模式」选
  MethodChannel，先改状态会把 stop 发给新模式控制器，旧隧道留在后台。
- 工作模式只改标题、正文仍是普通仪表盘时，首页电源按钮驱动的是 `powerProvider`（VPN），`start()`
  在模式检查处失败，界面只剩「启动失败」且看不到服务日志。服务器模式首页必须直接渲染服务器概览，
  并保留「切换工作模式」入口，否则用户进了这个模式就出不去。
- 极速模式可复用同一 AAR 的 `startFull`，靠「只注册 DNS 地址路由」的窄 TUN
  （`10.0.0.0/30` + 22 个公共 DNS `/32` + 可选 8 个 IPv6 `/128`）获得相同语义，不必移植 7.9k 行
  Kotlin 核心；判据是 `ip route get <非 DNS 地址>` 走 `wlan0` 且向 `1.1.1.1:53` 的 UDP/TCP 查询
  都能拿到应答。各模式的通知 ID/频道必须分开（极速 2003/`channel_express`），否则同一次启动里
  两个前台服务互相覆盖通知。
- `am force-stop` 不走 `onDestroy`，`vpn_running` / `express_vpn_running` 会残留 true：启动与回
  前台必须以原生 `status` 回写。停止后 `tun0` 与 ServiceRecord 要等 3–5 秒才消失，别在 1 秒内判残留。

### 2026-10-20：旧数据衔接与 Android 构建的硬约束

- **不能用 `shared_preferences` 接旧数据**：插件把键写进 `FlutterSharedPreferences` 并加
  `flutter.` 前缀，旧版容器一个都读不到。必须用原生 `getSharedPreferences(<旧容器名>)` 建桥，键名
  与落盘值逐字保留（`gold→indigo`、`server→dns`、底栏 id、1053 端口）。验证要「写入两个不同值各
  回读一次」，才能同时证明读、写两端都通。
- **Room 库只能原文件打开**：带 version 的 `openDatabase` 会改写 `user_version`/触发迁移。做法是
  `databaseExists` → `openDatabase(path)`，打开后核对 `user_version` 与 `-wal` 未变。预设白名单受
  `default_whitelist_initialized` 与 `default_whitelist_seeded_version` 双重门控，`groupName` 取自
  资产里的分类注释，漏写会与旧库肉眼可辨地不一致。
- **Maven 镜像要覆盖插件自带的 `buildscript`**：只改 `settings.gradle.kts` 的 `pluginManagement`
  不够，Flutter 插件的 `build.gradle` 自带 `buildscript { repositories { google(); mavenCentral() } }`，
  要用 `gradle.beforeProject { buildscript.repositories { maven(...) } }` 抢先注入。
- **arm64-only AAR 在 x86_64 模拟器装得上、跑不起来**：进程是 x86_64，`dlopen` 报 not found。
  判「引擎不可用」前先 `unzip -l apk | grep lib/` 核对 ABI。本地联调用
  `gomobile bind -target=android/arm64,android/amd64`，测试 AAR 不入库。
- VPN 数据面验收三层：`tun0` 出现 `10.0.0.2/30` → `ping 域名` 能解析 → `nc` 建 TCP 拿到 200。
  用户态栈不回 ICMP 属预期，`ping` 的 100% loss 不能当失败。
- `adb forward` 只转发 TCP；UDP 要在设备上用 `nc -u -q 1` 把请求/响应文件 push/pull 回来解析，
  TCP 查询要自己加 2 字节长度前缀。

### 2026-10-20：留白与边距只能有一个来源，改共享件等于一次改全站

- 嵌套 `Scaffold`：外层 `Scaffold(extendBody: true)` 把底栏高度写进正文的
  `MediaQuery.padding.bottom`，内层 `SafeArea` 又把它变成底部 `Padding`，滚动视口于是止于浮条
  上沿。修复放在 `CommonScaffold` 的**正文**（`padding.bottom` 取 `min(padding.bottom,
  viewPadding.bottom)`）。量「滚动视口」的矩形（`ListView` 底部 == 屏高），不要量 `PageBody` 的
  `MediaQuery.padding.bottom`——`SafeArea` 已把 padding 消费掉，读到恒为 0，用例会永远通过。
- `CommonCard` 的 `padding` 默认是 `EdgeInsets.zero`。列表卡片看起来有留白是因为 `ListItem` 自带
  16dp；自绘 `CommonCard(child: Text/Row)` 不传 `padding` 会贴住圆角边缘。新增自定义卡按
  `EdgeInsets.all(16)` 起步，再真机量内容 x 是否与列表正文同为 32dp。
- 二级页必须走 `PageBody`；裸 `ListView` 会让首屏正文滚到半透明顶栏下面。
- 半透明顶栏能被看见的前提是**滚动视口从 y=0 开始**：留白要放进滚动容器的 `padding`，同时
  `MediaQuery.removePadding(removeTop)` + `FloatingBarScope(inset: 0)`，否则内容里会再算一次。
  留白放在滚动容器外面会把视口裁在栏底，滚动时内容被硬切断。共享件（`PageBody`，67 个调用点）
  改这个属性等于一次改全站，同轮必须真机抽查多种结构的页。
- `EdgeInsets.horizontal` 是 left+right 的**和**（对称 20 时是 40），按「取一半」的意图除以 2 得到
  的是整条单边距。出血图要么真贴边，要么与正文同边距，中间值最像 bug。验收时量同一屏多张卡片的
  标题 x 与图形 x，别只看外框。
- 仓库级布局不变量别靠静态枚举调用点验证。改共享件默认值**等于一次改全站**，回归必须同轮做完：
  「卡片左边距 16」加在「卡片列」上是对的，加在外层会让组头缩进 32（`ListHeader`/`ListFooter`
  自带 16）。判据参照物要选设计常量，不要用某个 widget 的矩形。
- 主题默认值可能「只在某个尺寸下成立」：`FilledInputTheme.borderRadius` 默认 `AppRadius.full`
  （=1000）是为单行胶囊设计的，套到高框上会画成一个占满半屏的圆。给这类默认值写注释时把成立前提
  一并写进去。判断影响面要看字段是否自己覆盖了该属性（`decoration.border` 非空即覆盖）。

### 2026-10-19：上屏内容必须唯一可读，测试标尺必须只可能由目标承载

- 把枚举或对象插值进 `Text` 之前，确认 `toString` 被覆写过或显式取 `.label`。`ProviderProtocol`
  没覆写，UI 上就真显示 `ProviderProtocol.doh · https://…`，而编译器、analyze、路由冒烟全拦不住
  （`home_page.dart` 用的是 `provider.protocol.label`）。复用「现成的工具函数」前先读实现。
- 同屏文案必须唯一（可用性与可测性的共同前提）；`find.text` 命中多个时不要用 `.first` 掩盖，改
  文案。空状态文案与计数头文案分工，一个报数字一个说原因。
- 写组件之前先读构造签名，别按「应该是 Widget」推断（`CommonScaffold.primaryAction` 收的是
  `IconButtonData`）；泛型具名构造的类型实参一律前移到类名
  （`ListItem<RuleKind>.options(...)`），写到构造名后面报的错不会提示该改位置。
- 自测时把整页 `Text` dump 一遍（`for (final e in find.byType(Text).evaluate())`），比断言几个
  关键文案更容易抓到字面错误。顶栏 `iconActions` 会被静默折进「更多」菜单
  （`_maxBarButtons`/`_maxGroupedActions` = 2），这时 `find.byTooltip` 找不到属于设计行为。
- `AppBarSearchState.query` 是「模式开关」而不是「初值」：把 provider 里的当前搜索词回灌给顶栏，
  一进页面就展开搜索框、标题和所有分组全不渲染，而 analyze 和路由可达测试都是绿的（代码里已写
  注释挡住复发）。
- 浮层里读 scope 会 assert：监听器挂在根 `Navigator` 上，是与 `home:` 平级的兄弟路由，所以 scopes
  要装进 `MaterialApp.builder`（它的 `child` 就是 `Navigator`）。「能弹出/浮层能渲染」类用例必须用
  真实 App 路由壳。断言「某 scope 缺失」之前先读它的 `of()` 是否空安全。
- `tester.pageBack()` 找的是 `CupertinoNavigationBarBackButton`，本工程 sheet 的关闭按钮是
  `GlyphIcon`，用 `Navigator.of(element).maybePop()`。`scrollUntilVisible` 在 finder 命中多个可滚动
  区时抛 `Bad state: Too many elements`。临时测试文件要放进 `test/`；探测脚本用完立刻删，遗留文件
  会让全量 `flutter test` 变红。
- 行数统计用 `(Get-Content $f).Count`，`Measure-Object -Line` 跳过空行，系统性偏低 6%–15%。

### 2026-10-19：三类「analyze 全绿、运行时才炸」的缺陷

- **不手写三角函数或超越函数的近似**：`dart:math` 就在标准库里，写近似先问「参数域上界上还成立
  吗」——analyze 查不出，只在 paint/test 阶段炸。
- **永动动画必须有全局关闭开关**：本仓约定 `debugDisableDashboardLiveUpdates`
  （`lib/state/dashboard_providers.dart`），测试走 `test/support/test_hooks.dart` 的
  `installGlobalTestHooks()`。新增任何 `repeat()` 或自循环定时器前先想「`pumpAndSettle` 还能过
  吗」。看到一堆 `pumpAndSettle timed out`，先 `grep -r "\.repeat("`。
- **「没抛异常」不等于「路由存在」**：GoRouter 对未匹配路径不抛异常，只渲染 `errorBuilder`，没设
  就是一片空白，而「每条路由都能 build 且不 throw」的用例还会对漏注册静默放行。给路由器加
  `errorBuilder: UnknownRoutePage`，断言里同时写 `find.byType(UnknownRoutePage) == findsNothing`。
- **固定尺寸容器 + 可放大文字 = 潜在溢出**：高度按 `textScaler` 线性放大，横向多列一律 `Expanded`
  + `ellipsis`。`Row(crossAxisAlignment: .stretch)` 放进 `ListView` 的 `Column` 时外面套
  `IntrinsicHeight`，卡片才等高。
- `MaterialApp` 带非英文 `locale` 时必须用 `GlobalMaterialLocalizations`（否则 zh_CN 下 `AppBar`
  直接抛 `No MaterialLocalizations found`）。delegate 的 `load` 是异步的，`pumpWidget` 后首帧是空
  的，要补一次 `pump()`；`lib/ui` 的 `UiLocalizations.of` 是 assert 而非默认值。
  `test/support/app_host.dart` 与 `lib/app/bootstrap.dart` 的 scopes 装法必须一致。

### 2026-10-19~16：构建与工具链——环境结论有保质期

- 判「网络不可达」要用 `curl`/`Invoke-WebRequest` 打真实构件 URL，不能打域名根路径（404 是正常
  的）；文档里的环境类结论引用前必须重测。构建失败先这样拆开「环境不可达」与「代码坏」。
- 长任务跟进度一律写日志文件 + `Get-Content -Tail`，禁用 `Select-Object -Last`、`Tee-Object` 这类
  会缓冲的过滤器——它们让「慢」看起来像「死」。首次 Flutter Android 构建要下约 3 GB。
- 多代理共享工作区时构建单点串行由 Lead 跑，子代理只做静态自检（并发 Gradle 会撞 KSP 缓存）。
  同一批失败里期望错要改期望、代码错要改代码，处置相反；分片修复出现「新用例反而红」常常是抓到
  了更上游的真缺陷。
- `.bat` 保持纯 ASCII，中文说明放 `.md`，改完自检「>127 字节数 == 0」（`chcp 65001` 救不了，
  `cmd.exe` 在执行前已按 OEM 代码页解析）。所有 `set /p` 重试分支要设上限。
- Flutter 的构建入口只能是 `flutter build apk`，直调 Gradle 只编 Android 壳。签名验收靠证书指纹
  比对（`keytool -list -v` 的 SHA256 对 `apksigner verify --print-certs`，并确认 DN 不是
  `CN=Android Debug`）——`--release` 在密钥缺失时会静默回退 debug 签名。密钥文件先
  `git check-ignore` + `git ls-files` 双确认再提交。
- `gofmt -l` 会把 CRLF 误报成「格式未过」：判据改成「CRLF→LF 归一化后单独 gofmt，再比差异行数」。
  禁止 `gofmt -w` 整目录，那会翻掉全仓换行符并剥离无关文件的 BOM。

### 2026-10-18~17：先算影响面、先做差分；Go/Desktop 的跨模块契约陷阱

- 采纳别人的修复建议之前先算它对其他已修项的影响面。守卫条件要表达「是谁」（代际、身份），不要
  用会被下个会话重置为真的状态位（`running`）——照抄别人的 `Stop()` 早退守卫就回归了同轮刚修的问题。
- 声称某处有缺陷之前，用差分用例证明两版确实不等价；0 差异的「优化」属于等价重写，应当回退。改
  词法的判据是「什么字符序列构成注释」，不是「从哪里开始找」——改起点等于重新定义词法。
- 锁内只做快照，锁外做重活：持锁不调 `wg.Wait()`、网络、`time.Sleep` 或回调。长生命周期对象不按值
  捕获可热替换的字段，改用 getter 或 atomic 指针。
- 权限、路径、编码要在目标平台实机验证：`os.WriteFile(_, 0o600)`/`os.Chmod` 在 Windows 上只切只读
  位、不设 ACL；没法 CI 的差异用 `//go:build` 分包加 no-op 桩。
- Desktop 冷启动顺序固定：`go mod download` → `npm install` → 占位 `frontend/dist/index.html` →
  `wails generate module` → `npm run build` → `wails build`，验证落到真实产物起窗。跨子系统构建
  先在实际环境 `command -v`（WSL 没有 Go，`go.exe` 也不会被它解析），交叉编译放宿主。
- 托盘：**绝不丢弃 Win32 返回值**。`SetWindowSubclass` 在本进程 Wails 窗口恒返 FALSE 且
  `GetLastError=0`，一丢返回值就查不出子类过程从未安装；改用 `SetWindowLongPtr(GWLP_WNDPROC)` +
  `CallWindowProcW` 链式转发。用幂等动作替代时间去重，用语义过滤替代时间防抖，用可见性判定替代
  前台句柄。`OnDomReady` 每次导航都触发，初始化必须幂等。
- WebView2 呼吸灯开销只和出帧频率相关，与元素数量、大小无关：`will-change`、`translateZ(0)`、
  `contain:strict` 统统无效，唯一杠杆是降出帧数（`steps(2)`≈1.5%、`steps(4)`≈3.3%）。归因用
  `Get-Counter '\GPU Engine(*)\Utilization Percentage'` 按 pid 定位。
- 版本目标清单按全仓声明点维护并跑全量 dry-run；是否修改要比较新旧内容，而不是 `re.subn` 的计数
  （`n>0` 不等于有变更），重跑必须幂等。Android `versionCode` 取
  `max(旧值, major*10000+minor*100+patch)`。
