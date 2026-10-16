//go:build windows

package windows

// trayWindowProc 是替换到 Wails 主窗口上的窗口过程。
//
// 该过程运行在 GUI 线程（窗口线程）上，因此可以在此同步调用窗口操作——这正是
// 前台置顶能够拿到前台令牌的前提。所有未处理的消息一律经 CallWindowProcW
// 转发给 Wails 的原窗口过程，保证其自身消息处理不受影响。
func trayWindowProc(hwnd uintptr, msg uint32, wParam uintptr, lParam uintptr) uintptr {
	t := globalTray.Load()
	if t == nil {
		return callOriginalProc(hwnd, msg, wParam, lParam)
	}

	switch msg {
	case wmTrayCallback:
		t.handleTrayCallback(hwnd, wParam, lParam)
		return 0

	case wmTrayShowBalloon:
		t.showBalloonNow()
		return 0

	case wmClose:
		// 首次关闭时提示已最小化到托盘；随后照常转发，由 Wails 的
		// HideWindowOnClose 完成窗口隐藏。
		t.notifyFirstClose()
	}

	// 注意：TaskbarCreated 是运行时注册的消息 ID（> 0xC000），不能放在
	// switch 的常量分支中比较，故在此单独判定。
	t.mu.Lock()
	taskbarCreated := t.msgTaskbarCreated
	t.mu.Unlock()
	if taskbarCreated != 0 && uintptr(msg) == taskbarCreated {
		// 资源管理器重启后重新注册托盘图标。
		_ = t.addNotifyIcon()
		return 0
	}

	return callOriginalProc(hwnd, msg, wParam, lParam)
}

// callOriginalProc 将消息转发给被替换前的原窗口过程。
func callOriginalProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
	t := globalTray.Load()
	var orig uintptr
	if t != nil {
		t.mu.Lock()
		orig = t.origWndProc
		t.mu.Unlock()
	}
	if orig == 0 {
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}
	ret, _, _ := procCallWindowProcW.Call(orig, hwnd, uintptr(msg), wParam, lParam)
	return ret
}

// notifyFirstClose 在首次关闭主窗口时弹出一次"最小化到托盘"气泡。
func (t *WindowsTray) notifyFirstClose() {
	t.mu.Lock()
	firstClose := !t.hasShownBalloon
	t.hasShownBalloon = true
	t.mu.Unlock()

	if firstClose {
		_ = t.ShowBalloon(
			DefaultWindowTitle,
			"谛听已最小化到系统托盘，并在后台继续运行。\n点击托盘图标可重新打开主界面。",
		)
	}
}

// handleTrayCallback 处理托盘图标上报的用户交互事件。
//
// 版本 4 下 LOWORD(lParam) 为通知事件码，HIWORD(lParam) 为图标 ID。
func (t *WindowsTray) handleTrayCallback(hwnd, wParam, lParam uintptr) {
	event := uint32(lParam & 0xFFFF)

	t.mu.Lock()
	isV4 := t.isVersion4
	t.mu.Unlock()

	// 菜单路径：版本 4 下只认语义消息 WM_CONTEXTMENU，忽略重复的 WM_RBUTTONUP。
	if shouldHandleMenuEvent(event, isV4) {
		t.showContextMenu(hwnd, wParam)
		return
	}

	// 显示路径：幂等动作，重复派发无害，因此无需任何去重或时间去抖。
	if isShowWindowEvent(event) {
		t.activateViaCallbacks()
	}
}

// activateViaCallbacks 同步执行"显示并置顶"回调。
//
// 必须保持同步：回调最终进入 wailsruntime.WindowShow，其在本线程（窗口线程）时
// 同步执行并自行完成 SetForegroundWindow + SetFocus。若改由 goroutine 异步派发，
// 进程已失去前台令牌，置顶会被系统静默拒绝——这正是历史缺陷的根因。
func (t *WindowsTray) activateViaCallbacks() {
	t.mu.Lock()
	callback := t.callbacks.OnShowWindow
	t.mu.Unlock()
	if callback != nil {
		callback()
	}
}

// hideViaCallbacks 同步执行"隐藏主窗口"回调。
//
// 与显示同理，保持在窗口线程内执行以避免额外的线程切换与状态竞争。
func (t *WindowsTray) hideViaCallbacks() {
	t.mu.Lock()
	callback := t.callbacks.OnHideWindow
	t.mu.Unlock()
	if callback != nil {
		callback()
	}
}
