# AGENT_MISTAKES.md

> 记录原则：每条含「现象 → 根因 → 教训」，只保留能改变后续决策的信息；同源条目合并，已证伪做法以「反例」并入。

## 通用铁律（跨条目去重）

1. **期望源**：协议/布局以规范公布的样例向量为准；测试失败先分辨「期望错」还是「代码错」，禁止改被测代码让测试变绿；位段类先手写逐位表（含跨字节拆分）再对照代码。
2. **可达性**：严重度 = 缺陷机制 × 可达面。定级前双向 grep caller（Go 导出方法 → gomobile 绑定 → Kotlin 调用点，含接口注入/默认构造），并查设备/模式门；legacy/old 或平行实现必须证明「在生产被执行」。
3. **代理结论零权重**：子代理的「已确认/高危」逐条回读源码到调用链两端；组合主张拆条验；计数、规模自己数，「实测 N」须来自本会话工具输出。
4. **交付自证**：多文档分类用脚本 set 差集证明互斥；清单声明口径与扩展名；误报/撤回留痕，编号不复用。
5. **产物时序**：AAR/jar/exe 只在源码定稿后重建：改源码 → `gofmt`/`go vet`/`go test` → 构建 → 目标平台编译/单测/启动验证；不以外观、退出码 0 或单文件可读作为完成标准。
6. **仓内优先**：列「需外部取证」前先搜源码、测试、仓库注释——作者注释是比记忆更硬的期望源。

## 事件记录（时间倒序）

### 2026-10-18: 过早断言「受模型限制无法修」+ 把死字段当差距（判断/验证）
- **现象/根因**：A-083 我判定「订阅删除侧无法修，因为 `SubscriptionEntity` 没有『是否持久化授权』标志」，于是写进文档「需先加字段」。实际 `ContentResolver.getPersistedUriPermissions()` 本身就是权威来源——只释放本 App 真正持有的授权即可，根本不需要改表。同轮我还差点把 `WhitelistStats.subscriptionTotal/Enabled` 复制到 `BlacklistStats` 去「补齐计数差距」，实测这两组字段在白名单侧也**从未被任何 UI 渲染**，复制过去只会多两处死字段。
- **教训**：(1) 判「无法修」前先把平台 API 面查完——「模型缺字段」往往意味着「该换判据」而不是「该改模型」；以「需要加 DB 字段/迁移」为由放弃修复，必须附上「已排除的替代判据」。(2) 补「对称性差距」前先确认被对标的那一半是否真的被消费——计算出来但无人渲染的字段不是参照物，照抄只会放大死代码。(3) 未覆盖项要区分「确实做不到」与「当时没想到」，前者写进限制、后者必须回头补。

### 2026-10-18: 并发 Gradle 撞 KSP 缓存 + 期望错/代码错未先分辨 + 度量口径错（构建/验证/度量）
- **现象/根因**：5 个子代理并行跑 `gradlew`，反复 `IllegalStateException: Storage for ...kspCaches\...\file-to-id.tab is already registered`，多人误判为「代码坏」并各自重试，浪费数轮；7 个首轮失败里 2 个（`DohUrlParserTest`、`LatestRequestGateTest`）分别是**期望错**与**代码错**，处置方向完全相反，靠实测 OkHttp 行为才定案；子代理用 `Measure-Object -Line` 统计行数（**跳过空行**）导致全部行数系统性偏低 6%～15%；我一度按「分支 9 兜底没生效」指挥修复，实际卡点在上游分支 5 把 `$~app=` 的 `=` 当重写箭头。
- **教训**：(1) 多代理共享工作区时**构建必须单点串行**，由 Lead 统一跑，子代理只做静态自检与离屏单测；(2) 测试红点先实测第三方库真实行为再判「期望错 vs 代码错」，禁止为过测试改被测代码（`https:///dns-query` 经 OkHttp 解析成 `https://dns-query/` 是合法结果，不是解析器缺陷）；(3) 行数一律用 `(Get-Content $f).Count`（含空行），`Measure-Object -Line` 不可用于合规计数；(4) 改前先定位**真实卡点分支**——同一输入会被多个前置分支截走（`hasArrow` 的 `=` 匹配在 cosmetic/URL 判定之前），只修末端分支等于没修；(5) 分片修复出现「新用例反而红」常是它抓到了更上游的真缺陷，应先归因再改。

### 2026-10-18: 共享可变对象用 `==` 做「是不是同一份」判定（并发正确性）
- **现象/根因**：`LatestRequestGate.isLatest` 用 `latest == request`，而请求是 `data class` ⇒ 结构相等 ⇒ 两次同参数请求互相相等 ⇒ **旧请求被判成最新**，恰好把 A-051 的并发修复废掉；同型错误在 `ActiveHealthEngineRegistry.clearIfCurrent` 独立出现一次（`ConcurrentHashMap.remove(k,v)` 用 `equals`）。
- **教训**：「是不是我注册的那一份」必须用 `===` 身份比较，不能用 `==`；凡带可变状态的守卫/注册表，值相等永远不是要问的问题。用 `data class` 承载「请求/令牌/代际」时，默认就要假定有人会误用 `==`，在 KDoc 里写明为何必须是 `===`，并补一条「等值但不同实例」的测试锁住。

### 2026-10-18: gofmt 以 CRLF 误报为「格式未过」（工具判据）
- **现象/根因**：`gofmt -l .` 在 `Android/tunnel` 列出 63/76 文件，一度以为本次改动全不合规；实为工作区 CRLF（`core.autocrlf=true`），`git show HEAD:<file>` 基线同样被列出。
- **教训**：`gofmt -l` 在 CRLF 仓库不可直接用。判据改为「CRLF→LF 归一化后单独 gofmt，与 `git show HEAD:<file>` 比真差异行数」，只看「是否比基线更差」；**禁止** `gofmt -w` 整目录（会把全仓换行符翻掉，产生海量噪声 diff）。

### 2026-10-18: 解析器负例缺失 + 二进制产物早于源码定稿（验证/流程）
- **现象/根因**：`isIpLiteral` 正例全绿，却把 `2001:db8::1::2`（双压缩）判成合法 IPv6；A-076 补集、A-086 退避测试首次失败，错的是期望而非代码（`224.0.0.0/4` 应为 `/3`；40 次退避最坏约 2.4s，超出测试超时）；AAR 在 `gofmt` 未过时重建，返工两次。
- **教训**：解析器/校验器先列负例（`[::1]:53`、`256.1.1.1`、`8.8.8.8:53` 等「像但不合法」输入），文档点名的错误输入必须进测试；注入 N 次失败须按重试预算折算时间，长退避要有「降级态单次尝试即丢」分支；`gomobile bind -work` 可把生成 Java 与 `tunnel-sources.jar` 对比，导出 API 未变则无需重生成。

### 2026-10-18: legacy 子系统被当在用路径 + 交付集合未自证（验证/流程）
- **现象/根因**：A-067/068/070/074 四条「高危」引证全落在 `Engine.Start`/`SetTries`/原生 trie+bloom 旧拦截路径，caller grep（含 gomobile/Kotlin/test）仅命中定义行，复核后三条判不存在（A-067 写序缺陷真实，降 Low）；O-119 的「.aar 定版」实为仓内源码与 `engine_rewrite_test.go` 可自证的伪缺口；O-148/O-121 计数各少 1；13 条子代理批只完成 1 条；三份分级文档重复收录 A-059。
- **教训**：复核批按 6–12 条切，prompt 写明「必须全部完成再输出」，交回含「待定」立即拆小批重派；计数与规模自算（A-076「约 1 亿 IP」按 6×2²⁴ 吻合），不引用报告数字。

### 2026-10-18: Edit 锚点凭记忆 + 先入库后核引证（工具/流程）
- **现象/根因**：`old_string` 用记忆中的上节结尾，两次 not found；A-089 写完才核出 `Engine.Start` 零生产调用者（Kotlin 只用 `startFull`/`startStandalone`/`startStackMitm`）；A-095 收录了含已证伪分支的「`$$` 转义 + sinkhole」组合主张（`dnsrewriteIsBlock` 并不置 `dnsrewriteTargetType`）。
- **教训**：Edit 前先 grep 现值再复制锚点，长文档多轮追加尤其如此；可达性引证在落笔前完成——`serveDNS` 同被 standalone 与 full-tunnel 使用（多入口共用）与「路径整体无生产者」是相反情形，判据都是 caller grep，不能凭函数名猜；子代理组合主张拆条验。

### 2026-10-18: 子代理「高危触发面」未经收窄即采信（验证不充分）
- **现象/根因**：D-01 从「minSdk 24 工程存在 UPSERT」跳到「24–29 全设备流量历史丢失」，实际唯一写入链 `TrafficDatabaseSyncer.flushPendingDeltas` 仅经 NORMAL 模式、UI 硬拦 API 29+，受害面收窄到 API 29/30；仓库 `DnsCacheDao.kt` 注释已写明 UPSERT 需 API 30；D-03 被三条独立事实证伪。
- **教训**：优先用仓库自身注释当反证；一手版本表（AOSP SQLite）取不到时，降级为「记录收窄后的触发面 + 标注待定版事实」，交真机 logcat 定版，不按子代理原 severity 入库。

### 2026-10-18: 位段/线格式断言未先列规范位表（验证不充分）
- **现象/根因**：子代理称 `query[2]=0x01` 写进 Z 位、`byte3|=0x80` 无条件伪造 AD；逐位展开（byte2：QR 0x80/AA 0x04/TC 0x02/RD 0x01；byte3：RA 0x80/AD 0x20/CD 0x10/RCODE）后确认代码正确，属误报。
- **教训**：核验对象是子代理的位表本身，不是它对代码的引用；多代理并行扫描先对汇总表去重（Express IPv6 死代码、订阅 kind 失效应分别命中 A-012/A-030）。

### 2026-10-17: 半截字节码误记高危崩溃 + 子代理「已确认」（验证不充分）
- **现象/根因**：Room `isException` 迁移 `DEFAULT 0` 被判「升级即 `IllegalStateException`」，但 `defaultValueEqualsCommon` 的比较被 `aload_2; ifnull` 守卫——实体无默认值时跳过，迁移校验通过；同型 `enabled DEFAULT 1` 漂移长期共存却零崩溃报告，本可先作反证。
- **教训**：判「会不会执行」必须走完整控制流，定位进入断言/比较/校验的所有 `if`/循环守卫及跳转目标，确认本例取值可达；崩溃类高危优先找「为何现场没炸」的反证。

### 2026-10-17: Windows 有 Go 但 WSL 无 Go 致 deb 打包失败（构建环境）
- **现象/根因**：预检只查 `wsl` 不查 WSL 内 Go；`go.exe` 在 WSL PATH 中也不被 `command -v go` 解析。
- **教训**：跨子系统构建在实际执行环境内跑 `command -v`；交叉编译放宿主（`GOOS=linux CGO_ENABLED=0 go build`），WSL 只做 `dpkg-deb` 组装；验证到包内 ELF 执行 `--version`，不只看 `.deb` 存在。

### 2026-10-17: 行对象直接作 Vue key 中断桌面构建（构建/前端）
- **现象/根因**：`:key="row"` 违反 `PropertyKey` 类型，`vue-tsc` 报 TS2322，桌面端打包中止；该修复只做局部验证，未跑完整桌面端构建。
- **教训**：需按对象身份稳定的 key 用 `WeakMap<object, string>`（`createRowKey`），不要塞对象或退回下标；改 `.vue` 模板必须跑 `npm run build`（含 `vue-tsc --noEmit`）；构建/模板类修复合入前至少跑一次目标平台完整流水线；`git update-index --really-refresh` 消除 CRLF 假变更，禁止提交噪音。

### 2026-10-17: 维护工具箱双击闪退（环境/启动）
- **现象/根因**：缺 `requirements.txt` 与依赖探测，`ModuleNotFoundError: webview` 随窗口立即关闭。
- **教训**：GUI 启动脚本先探测依赖，缺失按清单自动安装；非零退出 `pause` 保留窗口；双击故障先在终端复现拿真实 traceback；运行依赖清单随代码入库，README 同步安装命令。

### 2026-10-17: 版本号统一范围遗漏与伪变更（发布工具）
- **现象/根因**：`get_file_targets()` 硬编码 6 个桌面文件，漏 Android Gradle、前端锁文件与 NSIS 模板；`re.subn` 返回 `n>0` 即视为变更，重跑不幂等。
- **教训**：目标清单按全仓版本声明点维护并跑全量 dry-run；是否修改比较新旧内容；Android `versionCode` 取 `max(旧值, major*10000+minor*100+patch)`；锁文件只改根节点与 `packages[""]`，JSON 解析回写并验证 round-trip。

### 2026-10-17: 批量修复中的跨模块契约陷阱（实现）
- **现象/根因**：编译与单测全绿仍漏三类：持 `p.mu` 调 `ReloadEncrypted` 后 `wg.Wait()` 等在途查询，单次保存卡死数秒；流水线按值捕获 `groupResolver`，热替换不生效；`os.WriteFile(_, 0o600)`/`os.Chmod` 在 Windows 只切只读位不设 ACL，路径大小写、systemd 相对 `ExecStart`、XDG 转义亦然。
- **教训**：锁内只做快照，锁外做重活（持锁不调 `wg.Wait`/网络/`time.Sleep`/回调）；长生命周期对象不按值捕获可热替换字段，改 getter 或 atomic 指针并同步所有构造点与测试桩；权限/路径/编码在目标平台实机验证（`icacls`、读生成文件），无法 CI 的差异用 `//go:build` 分包 + no-op 桩；拆分逼近 550 行文件须确认同包、import 无遗漏并重跑构建测试。

### 2026-10-17: 桌面端冷启动依赖环（构建引导）
- **现象/根因**：`frontend/embed.go` 的 `//go:embed all:dist` 要求目录非空，而 `wails generate module` 先编译 Go 包，形成「产物 → 绑定 → 前端构建 → 产物」环。
- **教训**：冷启动固定顺序 `go mod download` → `npm install` → 占位 `frontend/dist/index.html` → `wails generate module` → `npm run build` → `wails build`；环境完好时让 `wails build` 自动完成，手工分步仅用于定位；验证落到真实产物起窗（`[WebView2] Environment created successfully`），不看退出码 0。

### 2026-10-17: 验证方法论：期望源、计数与代理结论（验证不充分）
- **现象/根因**：BUG-44 把对 RFC 6052 的同一误读写进代码与断言，后用规范 Table 1/2 六例对账全中；BUG-66 grep 计 14 处未剔除前置 `MaxBytesReader` 的 1 处（实 13）；BUG-35 因 `CacheConfig.Enabled` 未置 true 在闸门早退，复现假阴性；子代理称 `DaysRemaining` 无消费者，实际前端 `CertificateCard` 在用；另有 DNS64 手算期望全错、常量表达式验溢出编译失败、压缩摘要把在途代理写成已完成。
- **教训**：复核旧「实证」先审期望再审代码；计数逐点带上下文（前后 3 行）并抽查 2–3 点；复现失败先怀疑 harness，为每条早退分支加断言；代理报告未到手=零信息，「无消费者」须 Go 与前端 camelCase 两查；同鉴权族实现不一致先疑孤立一侧遗漏；跨平台文件语义先实机取证（`icacls`、并发临时测试、`t.TempDir` 占用旁证）；溢出验证走运行期（`strconv.ParseInt`/变量乘法），临时 `zz_tmp_*` 用完即删。

### 2026-10-16: 页面级 max-w 致单列卡片宽度不足（布局）
- **现象/根因**：6 个页面根容器遗留 `max-w-7xl`（1280px）/`max-w-4xl`（896px），与「单列卡片延伸到内容区边缘」冲突，页面本身不报错。
- **教训**：页面根容器不设 `max-w-*`，宽度交给 `main` 的 padding；`pb-12` 由 `views/*.vue` 统一负责，面板内重复写会叠加；布局缺陷用 `getBoundingClientRect()` 量宽与 x/w，不看截图；Web 模式 `ui_capturer.py` 只截登录页，可用 CDP 注入伪 `window.go.main.App` 并设 `diting_ipc_host/port` 截真实界面（仅本地核对，不入库）；未覆盖 1280/1920 与 768–1024 折叠侧栏。

### 2026-10-16: 呼吸灯无限动画拖垮 WebView2 GPU（性能）
- **现象/根因**：`.seal-pulse` 对 `opacity` 逐帧插值的 `infinite` 动画使合成器每帧重绘整个窗口，GUI 空闲时 GPU 17%–28%；开销只与出帧频率相关，与动画元素数量/大小无关。
- **证据**：`Get-Counter '\GPU Engine(*)\Utilization Percentage'` 按 pid 归因，最小化归零；A/B 基线 27.8% → 关全部无限动画 1.7% → 仅关 `seal-pulse` 3.2%；保留动画但关键帧数值恒定仅 1.95%。
- **教训**：`will-change`/`translateZ(0)`/`contain:strict`/改 `transform`/改 `background-color`/延长周期均无效；唯一有效杠杆是降低出帧数：`steps()` 后 1.4%–4.0%（`steps(2)`≈1.5%、`steps(4)`≈3.3%、`steps(8)`≈7.1%）；对 `infinite` 动画（含 Tailwind `animate-spin`/`animate-pulse`、`md-circular-progress indeterminate`）保持怀疑；未覆盖高刷/多显示器，观感未经人眼确认。

### 2026-10-16: 托盘 SetWindowSubclass 静默失败与时序补丁链（Win32）
- **现象/根因**：`SetWindowSubclass` 在本进程 Wails 窗口恒返 FALSE（`ret=0`、`GetLastError=0`），返回值被丢弃，子类过程从未安装；历史补丁用时间防抖、前台句柄比对、异步派发等时序启发式规避消息语义，必然吞点击、失效或丢前台令牌。
- **教训**：绝不丢弃 Win32 返回值，改用 `SetWindowLongPtr(GWLP_WNDPROC)` + `CallWindowProcW` 链式转发，失败时回收已注册托盘图标；幂等动作替代时间去重（单击/键盘/双击/气泡统一为「显示并置顶」）；语义过滤替代时间防抖（`isV4` 忽略 `WM_RBUTTONUP`），可见性判定替代前台句柄（`IsWindowVisible() && !IsIconic()`）；窗口显隐在窗口线程内同步调用，仅服务启停等阻塞操作异步；`EnumWindows` 按类名 `wailsWindow` 匹配并接受隐藏窗口；`gofmt -w <目录>` 会剥离无关文件 BOM 产生大量 diff，应逐文件格式化；`OnDomReady` 每次导航都触发，初始化必须幂等。
- **反例**：250ms 菜单防抖 + `isShowingMenu` 重入拦截；`keybd_event(VK_MENU)` 破焦点；`WM_ACTIVATE` 维护失活时间戳；`IsWindowActive` 仅比对前台句柄；兜底模式把 `wParam` 当 X 坐标（实为图标 ID 1，且未处理副屏负坐标）；菜单回调在窗口过程内同步阻塞。
