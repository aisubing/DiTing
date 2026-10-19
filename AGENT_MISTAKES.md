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

### 2026-10-19: 宿主层级「结论」被证伪 + zh_CN 缺 MaterialLocalizations + 构建产物受网络所限
- **现象/根因**：(1) **反例（本条旧版写错，已证伪）**：旧版称「scopes 装进 `MaterialApp.builder` 会让 `CommonPopupBox`/`showFloatingDialog`/`showSheet` 报 `Navigator operation requested with a context that does not include a Navigator`，必须放 `home:` 或路由内」。本会话用两个对照 probe 复测（`builder` 装 scopes vs `home:` 装 scopes，各弹一次 `showFloatingDialog` + 内容含 `CommonCard`），**两种装法都无异常、都渲染成功**。真因是当时的 scopes 放在了 `MaterialApp` 之外（或 `MaterialApp` 之上的 `Builder` 里），`builder` 的 `child` 恰是 Navigator 本身、`Navigator.of(context)` 取的是上层 context，所以「装 builder」反而是拿到 Navigator 的正确位置。结论：**scopes 必须装在 `MaterialApp.builder`（Navigator 之上、MaterialApp 之下）**，浮层路由才能拿到 scope；放 `home:` 只是碰巧也能用（浮层不经过 `home:` 的 scope），不可依赖。(2) `DefaultMaterialLocalizations` 只带 en_US：`locale: zh_CN` 时 `AppBar` 直接抛 `No MaterialLocalizations found`（先有一条 "locale not supported by all delegates" 警告）。zh_CN 必须用 `material_ui` 里 intl 生成的 `GlobalMaterialLocalizations.delegates`（它同时含 Cupertino/Widgets 三个 delegate）。(3) `LocalizationsDelegate.load` 是异步的，`pumpWidget` 后首帧渲染为空，直接 `expect(find.text(...))` 必红；补一次 `pump()`。(4) `lib/ui` 的 `UiLocalizations.of` 是 `assert` 而非默认值，缺 delegate 时在 build 期崩溃。(5) `flutter build apk` 失败真因是 `services.gradle.org`/`repo1.maven.org`/`plugins.gradle.org` 全不可达（仅腾讯镜像 200），本地缓存的 gradle-9.4.1-bin 与 flutter 插件所需的 `kotlin-dsl 6.5.2` 都不全；把 wrapper 指向镜像属改工程配置，未获授权不得自行改。
- **教训**：(a) 写「某装法导致 X」前必须做**对照实验**并把两边结果都贴出来；被证伪的旧结论要原地改成「反例」而不是删掉——它本身就是后续判断的陷阱。(b) 凡 `MaterialApp` 带非英文 `locale`，先确认用了 `GlobalMaterialLocalizations`，否则整个 AppBar 层在 build 期就炸。(c) 测试宿主复用 `test/support/app_host.dart`；断言文本前先想「首帧是否已异步就绪」。(d) 构建失败先 `curl` 逐个探域名，把「环境不可达」与「代码坏」分开写进交付说明，不拿退出码当结论。

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
