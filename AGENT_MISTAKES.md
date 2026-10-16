# AGENT_MISTAKES.md

### 2026-10-16: SetWindowSubclass 静默失败与托盘时间防抖类缺陷的根治
- **问题现象**：托盘模块连续三轮修复仍不稳定；改用 `SetWindowSubclass` 从零重构后，托盘点击完全无响应，但 `Init` 返回成功、`Shell_NotifyIcon` 也成功。
- **根本原因**：
  1. **`SetWindowSubclass` 在本进程的 Wails 窗口上恒返回 FALSE**（实测 `ret=0` 且 `GetLastError` 为 0，即失败但不设错误码），而调用方丢弃了返回值，导致子类过程从未真正安装——这是一个**静默失败**。经验证，仓库中既有的 `aspect_ratio.go` 也曾因此从未生效（16:9 锁定实际长期未执行）。
  2. 历史多轮修复反复在"时间防抖 / 前台句柄比对 / 异步派发"上打补丁，其共同根因是：**用时间窗口与时序启发式去规避消息语义问题**。时间防抖必然吞掉边界内的正常点击；前台句柄比对在任务栏抢焦点时必然失效；异步派发必然丢失前台令牌。
- **经验教训与修复策略**：
  1. **绝不丢弃 Win32 返回值**，尤其是 `SetWindowSubclass`/`SetWindowLongPtr` 这类无错误码的布尔返回接口。本次改用 `SetWindowLongPtr(GWLP_WNDPROC)` + `CallWindowProcW` 链式转发（实测可用），并在失败时回收已注册的托盘图标。
  2. **用幂等动作替代时间去重**：把左键单击/键盘选择/双击/气泡点击统一归一化为"显示并置顶"这一个幂等动作，重复派发天然无害，整类"双重派发"缺陷从设计上消失，无需任何去抖。
  3. **用语义过滤替代时间防抖**：版本 4 下 Shell 对右键同时派发 `WM_RBUTTONUP` 与 `WM_CONTEXTMENU`，仅依据 `isV4` 忽略前者即可，判定不含时间窗口，不会吞掉菜单关闭后的正常点击。
  4. **用可见性判定替代前台句柄比对**：`IsWindowVisible() && !IsIconic()` 天然免疫任务栏抢焦点，彻底移除"失活时间戳"这类时序补丁。
  5. **窗口显隐必须在窗口线程内同步调用**：`wailsruntime.WindowShow` 在同线程时经 `Invoke` 同步执行并自行 `SetForegroundWindow`+`SetFocus`，前台令牌有效，故无需历史上用于绕过异步锁定的 `keybd_event(VK_MENU)` 取巧；只有服务启停等阻塞操作才异步派发。
  6. **`EnumWindows` 定位主窗口不得以可见性为筛选条件**：以 `-minimized` 启动时窗口本就隐藏，用可见性过滤将永远匹配不到；应改按窗口类名 `wailsWindow` 匹配并接受隐藏窗口。
  7. **注意工具的副作用范围**：`gofmt -w <目录>` 会顺带剥离不相关文件的 UTF-8 BOM，产生大量无关 diff。格式化应逐个文件进行，提交前须核对 `git status` 仅含预期文件。
  8. **`OnDomReady` 在每次页面导航（含热重载）时触发**，初始化逻辑必须幂等，否则会重复安装窗口过程与重复注册托盘图标。

### 2026-10-16: Windows 托盘过度防抖吞噬点击与前台焦点激活缺陷
- **问题现象**：菜单项点击后主窗口无法置顶唤醒（仅任务栏图标闪烁或无反应）、右键连续呼出或点击托盘关闭菜单后无法立即重开（必须点击第二次托盘）、且前台窗口无法通过托盘左键点击执行隐藏。
- **根本原因**：
  1. 上次修复错误地引入了 250ms 菜单防抖以及死锁式 `isShowingMenu` 拦截。在版本 4 下屏蔽 `WM_RBUTTONUP` 后，单次右键本身就不会双重派发；250ms 防抖反而导致用户在菜单刚关闭或试图重新呼出时点击被丢弃，造成“必须点第二次”的恶性回归。
  2. 将“打开主界面”等回调置于异步 goroutine 派发，脱离了 Win32 消息循环上下文。当新 goroutine 运行时，本进程早已失去前台输入令牌，导致 `SetForegroundWindow` 被系统静默拒绝，无法可靠唤醒置顶。
  3. `IsWindowActive()` 单纯比对 `GetForegroundWindow() == t.hwnd`。在用户点击系统托盘图标时，Windows 任务栏 (`Shell_TrayWnd`) 会抢占前台焦点，导致 `GetForegroundWindow()` 永远不是主窗口句柄，使得 `ToggleWindow()` 判定永远为 false，无法在窗口活跃时执行最小化隐藏。
  4. 坐标解析在兜底模式（非版本 4）下，`wParam` 实际为图标 ID（数值为 1），误当做 X 坐标导致菜单弹出在屏幕左上角 (1, 0) 处；且未考虑多显示器副屏负坐标。
- **经验教训与修复策略**：
  1. 彻底移除 250ms 人工延迟防抖，仅保留 50ms 硬件防抖；当已有菜单在显示时调用 `EndMenu` 平滑关闭并立即响应新菜单请求。
  2. 采用标准 Win32 技巧：在调用 `SetForegroundWindow` 之前模拟 `keybd_event(VK_MENU, 0, 0, 0)` 并随后释放，强制突破系统焦点锁定限制，确保置顶 100% 成功。
  3. 通过窗口拦截钩子监听 `WM_ACTIVATE` 消息维护窗口最近失活时间戳（<500ms），结合 `GetAncestor(fg, GA_ROOTOWNER)`，在任务栏夺取焦点的瞬间仍能精准判定主窗口是否原先正处于活跃状态。
  4. 严格仅在 `isVersion4 && wParam != 0` 时解构屏幕锚点，非版本 4 及异常点位统一回退至 `GetCursorPos`，完美支持多屏幕负坐标。

### 2026-10-16: Windows 托盘消息双重派发与菜单重入缺陷
- **问题现象**：任务栏托盘菜单点击功能无法生效、关闭后立即重新弹出、需要再次点击托盘才能响应，且托盘左键点击无法正常最小化/隐藏前台窗口。
- **根本原因**：
  1. 在 `NOTIFYICON_VERSION_4` 规范下，Windows Shell 对右键单击会依次派发 `WM_RBUTTONUP` 与 `WM_CONTEXTMENU`。若在回调处理中同时监听二者，会导致单次右键连续弹出两个上下文菜单；用户点击第一层菜单项后，第二层菜单立即顶出，造成点击失效、需要二次点击托盘才能关闭的假象。
  2. 同理，单次左键抬起在版本 4 下会同时派发 `WM_LBUTTONUP` 与 `NIN_SELECT`，双重触发导致单击切换被误判为双击唤醒。
  3. `WindowsTrayManager` 结构体遗漏了对 `IsWindowActive() bool` 的透传实现，导致 `app.ToggleWindow()` 的动态接口断言永远失败，无法在窗口活跃时执行最小化隐藏。
  4. 菜单回调（如打开主界面、退出等）在窗口过程内同步阻塞执行，阻碍 Win32 消息循环及时处理 `WM_NULL` 与释放菜单。
- **经验教训与修复策略**：
  - 在版本 4 激活时，必须屏蔽底层 `WM_RBUTTONUP` 与 `WM_LBUTTONUP`，严格仅监听语义层 `WM_CONTEXTMENU` 与 `NIN_SELECT`。
  - 为 `showContextMenu` 增加全局防重入标志 `isShowingMenu` 与 250ms 防抖区间，杜绝并发与幽灵菜单。
  - 在 `platform.TrayManager` 接口中统一规范 `IsWindowActive() bool`，确保适配器与接口类型对齐。
  - 菜单操作回调全部采用异步 goroutine 分发，确保 `TrackPopupMenu` 退出并投递 `WM_NULL` 后安全释放。

