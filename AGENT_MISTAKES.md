# AGENT_MISTAKES.md

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
