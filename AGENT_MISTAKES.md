# AGENT_MISTAKES.md

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

