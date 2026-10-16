//go:build windows

package windows

import (
	"fmt"
	"os"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// WindowsTray 负责管理 Windows 系统托盘图标及其交互
type WindowsTray struct {
	hwnd              uintptr
	hIcon             uintptr
	callbacks         platform.TrayCallbacks
	msgTaskbarCreated uintptr
	subclassCallback  uintptr
	origWndProc       uintptr
	lastClickTime     time.Time
	lastMenuTime      time.Time
	lastDeactiveTime  time.Time
	mu                sync.Mutex
	hasShownBalloon   bool
	isInitialized     bool
	isShowingMenu     bool
	isVersion4        bool
	isCurrentlyActive bool
}

var globalTray *WindowsTray


// NewWindowsTray 创建 Windows 系统托盘实例
func NewWindowsTray() *WindowsTray {
	return &WindowsTray{}
}

// Init 初始化系统托盘图标并挂载窗口消息拦截
func (t *WindowsTray) Init(callbacks platform.TrayCallbacks) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.callbacks = callbacks

	// 查找主窗口 HWND
	titlePtr, err := syscall.UTF16PtrFromString(DefaultWindowTitle)
	if err != nil {
		return fmt.Errorf("转换窗口标题失败: %w", err)
	}

	for i := 0; i < 50; i++ {
		h, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(titlePtr)))
		if h != 0 {
			t.hwnd = h
			break
		}
		time.Sleep(100 * time.Millisecond)
	}

	if t.hwnd == 0 {
		return fmt.Errorf("未能查找到主窗口，托盘初始化延后或失败")
	}

	// 注册 TaskbarCreated 消息，以便资源管理器重启后自动重绘托盘图标
	tbMsgPtr, _ := syscall.UTF16PtrFromString("TaskbarCreated")
	t.msgTaskbarCreated, _, _ = procRegisterWindowMessageW.Call(uintptr(unsafe.Pointer(tbMsgPtr)))

	// 放行 UIPI 消息过滤规则：当以管理员特权运行客户端时，允许 Explorer.exe（中完整性级别）向主窗口发送托盘消息
	if procChangeWindowMessageFilterEx.Find() == nil {
		procChangeWindowMessageFilterEx.Call(t.hwnd, uintptr(wmTrayCallback), msgfltAllow, 0)
		if t.msgTaskbarCreated != 0 {
			procChangeWindowMessageFilterEx.Call(t.hwnd, t.msgTaskbarCreated, msgfltAllow, 0)
		}
	}
	if procChangeWindowMessageFilter.Find() == nil {
		procChangeWindowMessageFilter.Call(uintptr(wmTrayCallback), msgfltAdd)
		if t.msgTaskbarCreated != 0 {
			procChangeWindowMessageFilter.Call(t.msgTaskbarCreated, msgfltAdd)
		}
	}

	// 加载图标
	t.loadIcon()

	// 添加托盘图标
	if err := t.addNotifyIcon(); err != nil {
		return fmt.Errorf("添加系统托盘图标失败: %w", err)
	}

	// 挂载窗口消息拦截过程（SetWindowLongPtr 支持跨线程安全挂载）
	globalTray = t
	t.subclassCallback = syscall.NewCallback(trayWindowHookProc)
	t.origWndProc = setWindowLongPtr(t.hwnd, gwlpWndProc, t.subclassCallback)
	if t.origWndProc == 0 {
		return fmt.Errorf("挂载窗口过程失败")
	}

	t.isInitialized = true
	return nil
}


func (t *WindowsTray) loadIcon() {
	exePath, err := os.Executable()
	if err == nil {
		exePtr, err := syscall.UTF16PtrFromString(exePath)
		if err == nil {
			var hSmallIcon uintptr
			ret, _, _ := procExtractIconExW.Call(
				uintptr(unsafe.Pointer(exePtr)),
				0,
				0,
				uintptr(unsafe.Pointer(&hSmallIcon)),
				1,
			)
			if ret != 0 && hSmallIcon != 0 {
				t.hIcon = hSmallIcon
				return
			}
		}
	}

	// 兜底使用系统标准应用程序图标 (IDI_APPLICATION = 32512)
	hIcon, _, _ := procLoadIconW.Call(0, 32512)
	t.hIcon = hIcon
}

func (t *WindowsTray) addNotifyIcon() error {
	var nid notifyIconData
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = t.hwnd
	nid.uID = 1
	nid.uFlags = nifMessage | nifIcon | nifTip
	nid.uCallbackMessage = wmTrayCallback
	nid.hIcon = t.hIcon

	tip, _ := syscall.UTF16FromString(DefaultWindowTitle)
	copy(nid.szTip[:], tip)

	ret, _, err := procShell_NotifyIconW.Call(nimAdd, uintptr(unsafe.Pointer(&nid)))
	if ret == 0 {
		return fmt.Errorf("Shell_NotifyIconW(NIM_ADD) 失败: %v", err)
	}

	// 设置托盘版本行为 (NOTIFYICON_VERSION_4)
	nid.uTimeoutOrVer = 4
	retV, _, _ := procShell_NotifyIconW.Call(nimSetVersion, uintptr(unsafe.Pointer(&nid)))
	t.mu.Lock()
	t.isVersion4 = retV != 0
	t.mu.Unlock()
	return nil
}

// ShowBalloon 弹出系统托盘气泡通知
func (t *WindowsTray) ShowBalloon(title, text string) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	if t.hwnd == 0 {
		return fmt.Errorf("托盘尚未初始化")
	}

	var nid notifyIconData
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = t.hwnd
	nid.uID = 1
	nid.uFlags = nifInfo
	nid.dwInfoFlags = niifInfo

	titleUTF16, _ := syscall.UTF16FromString(title)
	copy(nid.szInfoTitle[:], titleUTF16)

	textUTF16, _ := syscall.UTF16FromString(text)
	copy(nid.szInfo[:], textUTF16)

	ret, _, err := procShell_NotifyIconW.Call(nimModify, uintptr(unsafe.Pointer(&nid)))
	if ret == 0 {
		return fmt.Errorf("Shell_NotifyIconW(NIM_MODIFY) 弹出气泡失败: %v", err)
	}
	return nil
}

// ActivateWindow 唤醒并置顶窗口
func (t *WindowsTray) ActivateWindow() {
	if t.hwnd == 0 {
		return
	}
	procShowWindow.Call(t.hwnd, swRestore)
	forceSetForegroundWindow(t.hwnd)
	procBringWindowToTop.Call(t.hwnd)
}

// IsWindowActive 判断主窗口当前是否可见且正处于活跃状态
func (t *WindowsTray) IsWindowActive() bool {
	if t.hwnd == 0 {
		return false
	}
	visible, _, _ := procIsWindowVisible.Call(t.hwnd)
	if visible == 0 {
		return false
	}
	iconic, _, _ := procIsIconic.Call(t.hwnd)
	if iconic != 0 {
		return false
	}

	fg, _, _ := procGetForegroundWindow.Call()
	if fg == t.hwnd || isWindowOrChildOf(t.hwnd, fg) {
		return true
	}

	// 当用户点击系统托盘图标时，Windows Explorer (Shell_TrayWnd) 会瞬间夺取前台焦点。
	// 若主窗口在此之前处于活跃状态（500ms 内失活），判定为主窗口当前处于活跃状态，应当执行隐藏。
	t.mu.Lock()
	recentlyActive := t.isCurrentlyActive || (!t.lastDeactiveTime.IsZero() && time.Since(t.lastDeactiveTime) < 500*time.Millisecond)
	t.mu.Unlock()

	return recentlyActive
}

// Destroy 释放托盘图标与窗口消息拦截
func (t *WindowsTray) Destroy() {
	t.mu.Lock()
	defer t.mu.Unlock()

	if !t.isInitialized {
		return
	}

	var nid notifyIconData
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = t.hwnd
	nid.uID = 1
	procShell_NotifyIconW.Call(nimDelete, uintptr(unsafe.Pointer(&nid)))

	if t.origWndProc != 0 && t.hwnd != 0 {
		setWindowLongPtr(t.hwnd, gwlpWndProc, t.origWndProc)
		t.origWndProc = 0
		t.subclassCallback = 0
	}

	if t.hIcon != 0 {
		procDestroyIcon.Call(t.hIcon)
		t.hIcon = 0
	}

	t.isInitialized = false
	globalTray = nil
}

// trayWindowHookProc Win32 窗口消息拦截处理过程
func trayWindowHookProc(hwnd uintptr, msg uint32, wParam uintptr, lParam uintptr) uintptr {
	t := globalTray
	if t == nil || t.origWndProc == 0 {
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}

	switch msg {
	case wmTrayCallback:
		t.handleTrayCallback(wParam, lParam)
		return 0

	case wmActivate:
		loword := uint16(wParam & 0xFFFF)
		t.mu.Lock()
		if loword == waActive || loword == waClickActive {
			t.isCurrentlyActive = true
		} else if loword == waInactive {
			t.isCurrentlyActive = false
			t.lastDeactiveTime = time.Now()
		}
		t.mu.Unlock()

	case wmClose:
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
		// 由原窗口过程（Wails）接管 WM_CLOSE 并隐藏窗口 (HideWindowOnClose: true)
		ret, _, _ := procCallWindowProcW.Call(t.origWndProc, hwnd, uintptr(msg), wParam, lParam)
		return ret

	default:
		if t.msgTaskbarCreated != 0 && uintptr(msg) == t.msgTaskbarCreated {
			// Windows Explorer 重启，重新注册托盘图标
			_ = t.addNotifyIcon()
			return 0
		}
	}

	ret, _, _ := procCallWindowProcW.Call(t.origWndProc, hwnd, uintptr(msg), wParam, lParam)
	return ret
}

// handleTrayCallback 处理来自托盘图标的用户交互事件
func (t *WindowsTray) handleTrayCallback(wParam, lParam uintptr) {
	// 在 NOTIFYICON_VERSION_4 规范下，LOWORD(lParam) 为通知事件代码，HIWORD(lParam) 为图标 ID
	event := uint32(lParam & 0xFFFF)

	t.mu.Lock()
	isV4 := t.isVersion4
	t.mu.Unlock()

	switch event {
	case ninSelect, ninKeySelect:
		t.handleLeftClick()

	case wmLButtonUp:
		// 当 NOTIFYICON_VERSION_4 生效时，Windows Shell 会在单次左键抬起时同时派发 WM_LBUTTONUP 与 NIN_SELECT；
		// 为避免双重派发导致误判为双击，版本 4 下忽略 WM_LBUTTONUP，仅以 NIN_SELECT 为准。
		if !isV4 {
			t.handleLeftClick()
		}

	case wmLButtonDblClk:
		t.mu.Lock()
		t.lastClickTime = time.Now()
		t.mu.Unlock()
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}

	case wmContextMenu:
		// NOTIFYICON_VERSION_4 标准上下文菜单请求（鼠标右键或键盘 Shift+F10 / Apps Key）
		t.showContextMenu(wParam)

	case wmRButtonUp:
		// 仅在低版本兜底模式下响应 WM_RBUTTONUP；版本 4 下忽略该原始鼠标消息以防菜单重复弹出
		if !isV4 {
			t.showContextMenu(0)
		}

	case ninBalloonUserClick:
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}
	}
}

func (t *WindowsTray) handleLeftClick() {
	t.mu.Lock()
	now := time.Now()
	elapsed := now.Sub(t.lastClickTime)
	t.lastClickTime = now
	t.mu.Unlock()

	doubleClickMs := 500 * time.Millisecond
	if procGetDoubleClickTime.Find() == nil {
		if ms, _, _ := procGetDoubleClickTime.Call(); ms > 0 {
			doubleClickMs = time.Duration(ms) * time.Millisecond
		}
	}

	// 极短时间（<50ms）内的硬件或系统重复抖动事件直接忽略
	if elapsed < 50*time.Millisecond {
		return
	}

	if elapsed <= doubleClickMs {
		// 双击：唤醒并置顶主界面
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}
	} else {
		// 单击：切换窗口显隐
		if t.callbacks.OnToggleWindow != nil {
			t.callbacks.OnToggleWindow()
		}
	}
}

// showContextMenu 弹出右键菜单
func (t *WindowsTray) showContextMenu(wParam uintptr) {
	t.mu.Lock()
	if t.hwnd == 0 {
		t.mu.Unlock()
		return
	}
	// 极短时间（<50ms）内的硬件或系统抖动重复事件直接忽略
	if !t.lastMenuTime.IsZero() && time.Since(t.lastMenuTime) < 50*time.Millisecond {
		t.mu.Unlock()
		return
	}
	if t.isShowingMenu {
		procEndMenu.Call()
	}
	t.isShowingMenu = true
	t.mu.Unlock()

	defer func() {
		t.mu.Lock()
		t.isShowingMenu = false
		t.lastMenuTime = time.Now()
		t.mu.Unlock()
	}()

	hMenu, _, _ := procCreatePopupMenu.Call()
	if hMenu == 0 {
		return
	}
	defer procDestroyMenu.Call(hMenu)

	// 1. 打开主界面
	appendMenuItem(hMenu, mfString, idMenuShowWindow, "打开主界面")
	procSetMenuDefaultItem.Call(hMenu, idMenuShowWindow, 0)
	appendMenuItem(hMenu, mfSeparator, 0, "")

	// 2. 开机自启动
	isAuto := false
	if t.callbacks.IsAutoStart != nil {
		isAuto = t.callbacks.IsAutoStart()
	}
	autoFlags := uintptr(mfString)
	if isAuto {
		autoFlags |= mfChecked
	} else {
		autoFlags |= mfUnchecked
	}
	appendMenuItem(hMenu, autoFlags, idMenuAutoStart, "开机自启动")
	appendMenuItem(hMenu, mfSeparator, 0, "")

	// 3. DNS 核心服务状态与快捷启停
	serviceRunning := false
	if t.callbacks.GetServiceStatus != nil {
		if running, err := t.callbacks.GetServiceStatus(); err == nil {
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

	// 4. 退出程序
	appendMenuItem(hMenu, mfString, idMenuExit, "退出程序")

	// 坐标解析：NOTIFYICON_VERSION_4 在 wParam 中打包了光标 X, Y 锚点（支持多显示器负坐标）
	t.mu.Lock()
	isV4 := t.isVersion4
	t.mu.Unlock()

	var x, y int32
	if isV4 && wParam != 0 {
		x = int32(int16(wParam & 0xFFFF))
		y = int32(int16((wParam >> 16) & 0xFFFF))
	}
	if !isV4 || (x == 0 && y == 0) {
		var pt point
		procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
		x = pt.X
		y = pt.Y
	}

	// Win32 标准要求：调用 TrackPopupMenu 之前必须将托盘宿主窗口置为前台，菜单退出后发送 WM_NULL 清除任务状态
	forceSetForegroundWindow(t.hwnd)

	cmd, _, _ := procTrackPopupMenu.Call(
		hMenu,
		tpmReturnCmd|tpmNoNotify|tpmRightButton,
		uintptr(x),
		uintptr(y),
		0,
		t.hwnd,
		0,
	)
	procPostMessageW.Call(t.hwnd, wmNull, 0, 0)

	switch cmd {
	case idMenuShowWindow:
		t.ActivateWindow()
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}
	case idMenuAutoStart:
		if t.callbacks.OnToggleAutoStart != nil {
			go t.callbacks.OnToggleAutoStart()
		}
	case idMenuServiceToggle:
		if t.callbacks.OnToggleService != nil {
			go t.callbacks.OnToggleService()
		}
	case idMenuServiceRestart:
		if t.callbacks.OnRestartService != nil {
			go t.callbacks.OnRestartService()
		}
	case idMenuExit:
		if t.callbacks.OnExit != nil {
			go t.callbacks.OnExit()
		}
	}
}
