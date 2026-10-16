//go:build windows

package windows

import (
	"unsafe"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// showContextMenu 构建并弹出托盘右键菜单，随后分派被选中的命令。
//
// 该方法运行在窗口线程上，TrackPopupMenu 会在此进入嵌套模态循环。因此：
//   - 绝不在持有 t.mu 的情况下调用 TrackPopupMenu；
//   - 可能阻塞数秒的命令（服务启停、注册表写入、退出）一律异步派发。
func (t *WindowsTray) showContextMenu(hwnd, wParam uintptr) {
	t.mu.Lock()
	if hwnd == 0 {
		t.mu.Unlock()
		return
	}
	// 纯布尔门：仅在菜单显示期间阻止重入。菜单退出即清除，不会吞掉用户
	// 在菜单关闭后立即发起的下一次呼出（这是历史时间防抖缺陷的反面）。
	if t.menuActive {
		t.mu.Unlock()
		return
	}
	t.menuActive = true
	isV4 := t.isVersion4
	callbacks := t.callbacks
	t.mu.Unlock()

	defer func() {
		t.mu.Lock()
		t.menuActive = false
		t.mu.Unlock()
	}()

	hMenu, _, _ := procCreatePopupMenu.Call()
	if hMenu == 0 {
		return
	}
	defer procDestroyMenu.Call(hMenu)

	t.buildMenu(hMenu, callbacks)

	x, y := t.resolveAnchor(wParam, isV4)

	// Win32 要求：弹出菜单前先将宿主窗口置为前台，菜单退出后发送 WM_NULL
	// 以清除菜单的任务栏状态。
	procSetForegroundWindow.Call(hwnd)

	cmd, _, _ := procTrackPopupMenu.Call(
		hMenu,
		tpmReturnCmd|tpmNoNotify|tpmRightButton,
		uintptr(x),
		uintptr(y),
		0,
		hwnd,
		0,
	)
	procPostMessageW.Call(hwnd, wmNull, 0, 0)

	t.dispatchMenuCommand(cmd, callbacks)
}

// buildMenu 依据当前状态构建菜单项。
//
// IsAutoStart 与 GetServiceStatus 为快速返回的同步查询（注册表读 / 服务查询），
// 以便勾选态与菜单文案能与菜单同时呈现。
func (t *WindowsTray) buildMenu(hMenu uintptr, callbacks platform.TrayCallbacks) {
	// 1. 打开主界面
	appendMenuItem(hMenu, mfString, idMenuShowWindow, "打开主界面")
	procSetMenuDefaultItem.Call(hMenu, idMenuShowWindow, 0)

	// 2. 隐藏主界面
	appendMenuItem(hMenu, mfString, idMenuHideWindow, "隐藏主界面")
	appendMenuItem(hMenu, mfSeparator, 0, "")

	// 3. 开机自启动（带勾选态）
	isAuto := false
	if callbacks.IsAutoStart != nil {
		isAuto = callbacks.IsAutoStart()
	}
	autoFlags := uintptr(mfString)
	if isAuto {
		autoFlags |= mfChecked
	} else {
		autoFlags |= mfUnchecked
	}
	appendMenuItem(hMenu, autoFlags, idMenuAutoStart, "开机自启动")
	appendMenuItem(hMenu, mfSeparator, 0, "")

	// 4. 核心服务状态与快捷启停
	serviceRunning := false
	if callbacks.GetServiceStatus != nil {
		if running, err := callbacks.GetServiceStatus(); err == nil {
			serviceRunning = running
		}
	}

	statusText := "核心服务: 已停止"
	if serviceRunning {
		statusText = "核心服务: 运行中"
	}
	appendMenuItem(hMenu, mfString|mfDisabled|mfGrayed, idMenuServiceStatus, statusText)

	if serviceRunning {
		appendMenuItem(hMenu, mfString, idMenuServiceToggle, "停止核心服务")
		appendMenuItem(hMenu, mfString, idMenuServiceRestart, "重启核心服务")
	} else {
		appendMenuItem(hMenu, mfString, idMenuServiceToggle, "启动核心服务")
	}
	appendMenuItem(hMenu, mfSeparator, 0, "")

	// 5. 退出程序
	appendMenuItem(hMenu, mfString, idMenuExit, "退出程序")
}

// resolveAnchor 解析菜单弹出坐标。
//
// 版本 4 会在 wParam 中打包屏幕锚点（支持副屏负坐标）；无有效锚点时回退到光标
// 位置，兼容低版本与异常点位。
func (t *WindowsTray) resolveAnchor(wParam uintptr, isV4 bool) (int32, int32) {
	if isV4 {
		if x, y, ok := unpackV4Anchor(wParam); ok {
			return x, y
		}
	}
	var pt point
	procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	return pt.X, pt.Y
}

// dispatchMenuCommand 分派菜单命令。
//
// 分派策略严格区分两类：
//   - 窗口显隐为幂等且必须保住前台令牌的轻量操作 => 在窗口线程内同步执行；
//   - 服务启停/重启、注册表写入、退出等可能阻塞数秒的操作 => 异步派发，
//     避免阻塞消息循环导致界面卡死。
func (t *WindowsTray) dispatchMenuCommand(cmd uintptr, callbacks platform.TrayCallbacks) {
	switch cmd {
	case idMenuShowWindow:
		t.activateViaCallbacks()
	case idMenuHideWindow:
		t.hideViaCallbacks()
	case idMenuAutoStart:
		if callbacks.OnToggleAutoStart != nil {
			go callbacks.OnToggleAutoStart()
		}
	case idMenuServiceToggle:
		if callbacks.OnToggleService != nil {
			go callbacks.OnToggleService()
		}
	case idMenuServiceRestart:
		if callbacks.OnRestartService != nil {
			go callbacks.OnRestartService()
		}
	case idMenuExit:
		if callbacks.OnExit != nil {
			go callbacks.OnExit()
		}
	}
}
