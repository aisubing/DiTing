# AGENT_MISTAKES.md

> 记录原则：每条须含「现象 → 根因 → 可复用教训」，只保留能改变后续决策的信息；同源条目已合并，已被证伪的做法以「反例」并入，不单独成篇。

### 2026-10-17: 依据子代理「已确认」结论与半截字节码误记高危崩溃项（验证不充分类）
- **现象**：Room 数据层子代理报「`isException` 迁移的 `DEFAULT 0` 与实体 schema 漂移 → 升级即 `IllegalStateException`」，自评「certain / HIGH」。我据此加读 `TableInfoKt.equalsCommon` 的反汇编，看到确有 `defaultValueEqualsCommon` 调用点，遂记为确认缺陷 A-011 并提交。回读完整控制流后发现 ENTITY↔DATABASE 方向的默认值比较被 `aload_2; ifnull <跳过>` 守卫：仅当**实体侧默认值非空**才比较，本例实体无 `@ColumnInfo(defaultValue)` 即跳过，迁移校验通过，结论翻转为误报，撤回降级为卫生观察。
- **根因**：
  1. 反汇编里「存在一条比较指令」≠「该比较被执行」；只看比较体、不追进它的分支守卫（`ifnull`/`if_icmpne` 跳到哪），把「可能比较」读成「必然比较」。
  2. 子代理自评置信度被当成证据；其报告自带的反证（同型 `enabled DEFAULT 1` 漂移自 schema v2 起每次发布共存却零崩溃报告）我没加权，本可先据此质疑「真会崩早该有反馈」。
- **教训**：
  1. **判定「会不会执行」必须走完整控制流**：看到某段断言/比较/校验代码存在时，先定位进入它的所有 `if`/循环守卫与其跳转目标，确认在**本例具体取值**下确能到达，再谈结果；条件断言类（Room 校验、权限检查、超时）尤其如此。
  2. **崩溃类高危项优先找「为何现场没炸」的反证**：若该路径据称在既有发布中长期存在却无人报崩溃，默认怀疑判定本身，而非假设「一直潜伏未触发」。
  3. **子代理「confirmed/certain」标签零权重**：严重度 ≥ 中高的结论，逐条回读源码到调用链两端（本项目还须核到 Room/Go 框架侧真实语义，不能凭记忆），与本次字节码核对同级对待——记忆中的框架行为是最易出错的期望源。
  4. 误报入库也要留痕：保留「曾拟记录 → 复核撤回 → 编号不复用」说明（见 `docs/desktop-bug-report.md` 头部），防止后续轮次把同一被证伪结论再翻出来。

### 2026-10-17: Windows 有 Go 但 WSL 无 Go 导致 deb 打包失败（构建环境类）
- **现象**：`build_deb.bat` / `build_manager.py -t deb` 通过 WSL 存在性预检后，`build_linux.sh` 报「未找到 Go 工具链」，`.deb` 未生成；Windows 侧 `go version` 正常。
- **根因**：deb 流程把编译与打包都交给 WSL，但预检只查 `wsl` 不查 WSL 内 Go；Windows 的 `C:\Program Files\Go\bin` 虽在 WSL PATH 中，Linux 不会自动解析 `go.exe`，`command -v go` 仍失败。
- **教训**：
  1. **宿主与 WSL 的工具链分别取证**：跨子系统构建不能以宿主 `go`/`node` 可用推断 WSL 可用，预检须在实际执行环境内跑 `command -v`。
  2. **交叉编译优先放宿主**：`GOOS=linux GOARCH=... CGO_ENABLED=0 go build` 可在 Windows 完成，WSL 只承担 `dpkg-deb` 组装；`build_linux.sh --prebuilt` 复用产物。
  3. 产物验证落到包内 ELF 与运行输出（`dpkg-deb -x` 后执行 `--version`），不能只看 `.deb` 文件存在。

### 2026-10-17: 行对象直接作 Vue key 中断桌面端构建（构建/前端类型类）
- **现象**：`Desktop/build.bat` / `build_manager.py -t exe` 在 Wails 前端编译阶段失败：`ClientGroupsCard.vue(213,14)`、`ScheduleEditor.vue(57,40)` 均报 `TS2322: Type '...' is not assignable to type 'PropertyKey | undefined'`，整个桌面端打包中止。
- **根因**：`a9a2c0d` 为修复「下标 key 删除中间行后 DOM 原位复用、焦点串行」把 `:key="index"` 改成 `:key="row"`；Vue 的 `:key` 类型为 `PropertyKey`，对象在 `vue-tsc` 严格检查下非法。该提交只做了局部验证，未跑完整桌面端构建，因此回归直到本次打包才暴露。
- **教训**：
  1. 需要「按对象身份稳定」的列表 key 时，用 `WeakMap<object, string>` 生成稳定字符串（`frontend/src/utils/rowKey.ts` 的 `createRowKey`），不要直接把对象塞进 `:key`，也不要退回下标 key。
  2. 改 `.vue` 模板后必须跑 `npm run build`（含 `vue-tsc --noEmit`）；只跑 `vite build`、热重载或浏览器观看会漏掉模板类型错误。
  3. 涉及构建/模板的「修复」提交合入前，至少跑一次目标平台完整流水线（`python maintenance/core/build_manager.py -t exe`），不要以单文件可读或 dev 模式正常作为完成标准。
  4. 构建工具会因 CRLF 规范化让 `go.mod` 出现「哈希相同但 status 显示 M」的假变更；`git update-index --really-refresh` 可消除，禁止把此类噪音提交。

### 2026-10-17: 维护工具箱双击闪退（环境/启动类）
- **现象**：双击 `maintenance/run_maintenance.bat` 窗口一闪而过；终端复现为 `ModuleNotFoundError: No module named 'webview'`。
- **根因**：仓库缺少依赖清单，启动脚本直接执行 `python app.py`；Python 3.15 环境仅有 pip，缺 `pywebview`/`dnspython`/`Pillow` 时 traceback 随窗口立即关闭。
- **教训**：
  1. GUI 启动脚本先探测依赖，缺失时按 `requirements.txt` 自动安装；非零退出必须 `pause` 保留窗口。
  2. 运行依赖清单随代码入库，README 同步给出 `python -m pip install -r ...`，不要依赖口头环境说明。
  3. 双击脚本类故障先在终端直接复现，拿到真实 traceback 再谈修复，避免被「闪退」表象误导。

### 2026-10-17: 版本号统一范围遗漏与伪变更（发布工具类）
- **现象**：桌面端已到 1.3.10，Android 仍为 1.2.12；`package-lock.json`、`wails_tools.nsh` 曾靠另起 chore 提交手工补；工具箱对同一版本重跑仍报「已更新」。
- **根因**：`get_file_targets()` 硬编码 6 个桌面文件，未覆盖 Android Gradle、前端锁文件与生成的 NSIS 模板；`re.subn` 返回 `n>0` 即视为变更，未比较新旧内容。
- **教训**：
  1. 版本工具的目标清单按全仓版本声明点维护（Go/Wails/NSIS/package+lock/Android/脚本/README 示例），新增平台时同步扩充并跑全量 dry-run。
  2. 是否修改必须比较新旧内容，不能只看正则命中数，否则 sync 不幂等并可能产生空提交。
  3. Android `versionCode` 由 `major*10000+minor*100+patch` 推导并取 `max(旧值, 新值)`，兼顾单调递增与重复执行。
  4. 锁文件只改根节点与 `packages[""]`，用 JSON 解析回写避免改依赖版本；回写前先验证 round-trip 与 npm 原始格式逐字节一致。

### 2026-10-17: 批量修复中的跨模块契约陷阱（实现类）
- **现象**：按 `docs/desktop-bug-report.md` 修复 60+ 项，编译与单测全绿仍漏三类：持 `p.mu` 调 `ReloadEncrypted` 后 `wg.Wait()` 等在途查询、查询经 getter 再取 `p.mu`，单次保存卡死解析数秒；流水线按值捕获 `groupResolver`，热替换不生效却回「已生效」；`os.WriteFile(_, 0o600)`/`os.Chmod` 在 Windows 只切只读位不设 ACL，路径大小写、systemd 相对 `ExecStart`、XDG `Exec` 转义亦然。
- **根因**：锁归属、状态所有权、路径解析等跨模块契约未在类型系统表达，单模块单测照不到。
- **教训**：
  1. **锁内只做快照，锁外做重活**：持锁调用 `wg.Wait`、网络写、`time.Sleep`、回调注入点前，先确认不会回到同一把锁。
  2. **长生命周期对象不得按值捕获会被热替换的字段**，改注入 getter 或 atomic 指针，并同步所有构造点与测试桩。
  3. **权限/路径/编码断言在目标平台实机验证**：Windows 用 `icacls`，systemd/XDG 读生成文件，无法 CI 覆盖的差异用 `//go:build` 分包 + no-op 桩；改完跑一次 `GOOS=linux go build ./...`。
  4. **拆分逼近 550 行的文件**须确认同包、import 无遗漏，并重跑构建与测试，不能只看行数。

### 2026-10-17: 桌面端冷启动依赖环（构建引导类）
- **现象**：全新机器无 `node_modules`/Go 缓存/`frontend/dist` 时，`go build ./...` 与 `wails generate module` 报 `pattern all:dist: no matching files found`；绑定生成失败又让 `vue-tsc` 缺 `wailsjs` 类型。
- **根因**：`frontend/embed.go` 的 `//go:embed all:dist` 要求目录至少一个文件，而 `generate module` 先编译 Go 包，形成「产物 → 绑定 → 前端构建 → 产物」的环。
- **教训**：
  1. 冷启动顺序固定为 `go mod download` → `npm install` → 放占位 `frontend/dist/index.html` → `wails generate module` → `npm run build` → `wails build`；占位文件随后被覆盖。
  2. 环境完好时 `wails build` 会自动完成绑定/安装/前端编译；手工分步仅用于定位失败环节。
  3. 依赖验证必须落到真实产物（如 `build/bin/diting-gui.exe` 起窗、`[WebView2] Environment created successfully`），不能只看退出码 0。
  4. `package-lock.json` 与 `package.json` 版本不一致会在首次 `npm install` 产生无关 diff，应单独提交或还原。

### 2026-10-17: 验证方法论：期望源、计数与代理结论（验证不充分类，原三则合并）
- **现象**：BUG-44 被误判误报——第 8 轮把对 RFC 6052 的同一误读写进代码预期与断言，第 10 轮用规范 Table 1/2 样例向量对账，六例全中；BUG-66 grep 计 14 处未剔除前置 `MaxBytesReader` 的 1 处（实为 13）；BUG-35 因 `CacheConfig.Enabled` 未置 true 在闸门早退，复现假阴性；子代理称 `DaysRemaining` 无消费者，实际前端 `CertificateCard` 在显示；另有 DNS64 手算期望全错、常量表达式验溢出编译失败、压缩后把在途代理当成已完成。
- **根因**：期望值从记忆/手算推导，与实现同源；grep 命中 ≠ 缺陷点；复现未证明走到被测路径；压缩摘要爱把「进行中」写成「已完成」；Go 字段常经 JSON 扩散到前端。
- **教训**：
  1. **协议布局以规范公布的样例向量为唯一期望源**；首轮全红先怀疑期望。复核旧「实证」先审期望再审代码——「代码 ≠ 期望」不等于「期望 = 规范」。
  2. **计数类缺陷逐点带上下文核**（前后各 3 行），提交后抽查 2–3 点回读原文。
  3. **复现失败先怀疑 harness**：为被测函数每条早退分支加断言（如 `PutForGroup` 须返回 true），确认走进去再谈复现。
  4. **代理报告未到手 = 零信息**；代理结论（含纠偏）逐条回读源码；「无消费者」须 Go 与前端 camelCase 两查。
  5. **跨平台文件语义先实机取证**（`icacls`、并发临时测试把「逻辑空窗」变命中率数字）；同鉴权族实现不一致（`RemoteAddr` vs `XFF`）先疑孤立一侧遗漏；`t.TempDir` 清理报「being used by another process」可作占用旁证。
  6. **溢出验证走运行期**（`strconv.ParseInt`/变量乘法），不用编译期常量；临时 `zz_tmp_*` 用完即删，提交前 `git status` 只含预期改动。

### 2026-10-16: 页面级 max-w 导致单列卡片宽度不足（布局类）
- **现象**：6 个页面（DNS64/重写/加密 DNS/安全隐私/应用拦截/自定义规则）卡片宽 1080px 或 756px，其余 1337px，左右留白且与标题栏不齐。
- **根因**：面板根容器遗留 `max-w-7xl`（1280px）/`max-w-4xl`（896px），与「单列卡片延伸到内容区边缘」规范冲突，页面本身不报错。
- **教训**：
  1. **页面根容器不设 `max-w-*`**，宽度交给 `main` 的 padding；基准为总览/状态总览（双列满宽）、系统/外观主题（单列满宽）。
  2. **`pb-12` 由 `views/*.vue` 统一负责**，面板内重复写会叠加；各页尾部留白 13–14px 一致即正确。
  3. **布局缺陷必须用 `getBoundingClientRect()` 量宽与 x/w**，不能看截图（「都居中好看但宽度不一致」）。
  4. Web 模式 `ui_capturer.py` 只截到登录页；可用 CDP 注入伪 `window.go.main.App` 并设 `diting_ipc_host/port` 指向回环后台截真实界面，仅限本地核对，不入库。
  5. 未充分验证：仅 1600×1000 单视口，未覆盖 1280/1920 与 768–1024 折叠侧栏。

### 2026-10-16: 呼吸灯无限动画拖垮 WebView2 GPU（性能类）
- **现象**：GUI 空闲时 WebView2 GPU 进程持续 17%–28%（1080p/60Hz）。
- **根因**：`.seal-pulse` 对 `opacity` 逐帧插值的 `infinite` 动画使合成器每帧重绘整个窗口；开销只与出帧频率相关，与动画元素数量/大小无关。
- **证据链**：`Get-Counter '\GPU Engine(*)\Utilization Percentage'` 按 pid 归因，最小化归零；A/B 基线 27.8% → 关全部无限动画 1.7% → 仅关 `seal-pulse` 3.2%；保留动画但关键帧数值恒定仅 1.95%，证明开销来自属性逐帧变化。
- **教训**：
  1. **无效手段勿再试**：`will-change`/`translateZ(0)`/`contain:strict`/改 `transform`/改 `background-color`（27.7/25.6/23.4/24.7/24.0%），以及延长周期（18s 仍 23.6%）。
  2. **唯一有效杠杆是降低出帧数**：`steps()` 后 1.4%–4.0%（约 -95%）；`steps(2)`≈1.5%、`steps(4)`≈3.3%、`steps(8)`≈7.1%，按视觉重要性分级。
  3. 对所有 `infinite` 动画（含 Tailwind `animate-spin`/`animate-pulse`、`md-circular-progress indeterminate`）保持怀疑。
  4. 纯 CSS 逐帧平滑动画无法兼顾平滑与低占用，这是合成模型固有取舍。
  5. 未充分验证：仅 60Hz/1080p 单环境，未覆盖高刷/多显示器，修复后观感未经人眼确认。

### 2026-10-16: 托盘 SetWindowSubclass 静默失败与时序补丁链（Win32 类）
- **现象**：托盘连续三轮修复仍不稳定；用 `SetWindowSubclass` 重构后点击完全无响应，但 `Init`、`Shell_NotifyIcon` 均返回成功。
- **根因**：`SetWindowSubclass` 在本进程 Wails 窗口上恒返 FALSE（`ret=0`、`GetLastError=0`），返回值被丢弃，子类过程从未安装（`aspect_ratio.go` 同因此长期未生效）；历史补丁用时间防抖、前台句柄比对、异步派发等时序启发式规避消息语义问题，必然吞点击、失效或丢前台令牌。
- **教训**：
  1. **绝不丢弃 Win32 返回值**，尤其无错误码的布尔接口；改用 `SetWindowLongPtr(GWLP_WNDPROC)` + `CallWindowProcW` 链式转发，失败时回收已注册托盘图标。
  2. **幂等动作替代时间去重**：单击/键盘/双击/气泡统一为「显示并置顶」，重复派发无害。
  3. **语义过滤替代时间防抖**：版本 4 仅依 `isV4` 忽略 `WM_RBUTTONUP`；**可见性判定替代前台句柄比对**（`IsWindowVisible() && !IsIconic()` 免疫任务栏抢焦点）。
  4. **窗口显隐在窗口线程内同步调用**（`WindowShow` 同线程经 `Invoke` 自带 `SetForegroundWindow`+`SetFocus`）；仅服务启停等阻塞操作异步。
  5. **`EnumWindows` 按类名 `wailsWindow` 匹配并接受隐藏窗口**，`-minimized` 启动时窗口本就不可见。
  6. `gofmt -w <目录>` 会剥离无关文件 BOM 产生大量 diff，应逐文件格式化；`OnDomReady` 每次导航（含热重载）都触发，初始化必须幂等。
- **历史反例（勿重蹈）**：250ms 菜单防抖 + `isShowingMenu` 重入拦截（吞掉菜单关闭后的点击）；`keybd_event(VK_MENU)` 破焦点；`WM_ACTIVATE` 维护失活时间戳；`IsWindowActive` 仅比对前台句柄；兜底模式把 `wParam` 当 X 坐标（实为图标 ID 1，且未处理副屏负坐标）；菜单回调在窗口过程内同步阻塞。
