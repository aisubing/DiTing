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

var (
	procShell_NotifyIconW           = modShell32.NewProc("Shell_NotifyIconW")
	procExtractIconExW              = modShell32.NewProc("ExtractIconExW")
	procCreatePopupMenu             = modUser32.NewProc("CreatePopupMenu")
	procAppendMenuW                 = modUser32.NewProc("AppendMenuW")
	procDestroyMenu                 = modUser32.NewProc("DestroyMenu")
	procTrackPopupMenu              = modUser32.NewProc("TrackPopupMenu")
	procGetCursorPos                = modUser32.NewProc("GetCursorPos")
	procSetForegroundWindow         = modUser32.NewProc("SetForegroundWindow")
	procPostMessageW                = modUser32.NewProc("PostMessageW")
	procDestroyIcon                 = modUser32.NewProc("DestroyIcon")
	procLoadIconW                   = modUser32.NewProc("LoadIconW")
	procRegisterWindowMessageW      = modUser32.NewProc("RegisterWindowMessageW")
	procIsWindowVisible             = modUser32.NewProc("IsWindowVisible")
	procGetForegroundWindow         = modUser32.NewProc("GetForegroundWindow")
	procShowWindow                  = modUser32.NewProc("ShowWindow")
	procBringWindowToTop            = modUser32.NewProc("BringWindowToTop")
	procSetMenuDefaultItem          = modUser32.NewProc("SetMenuDefaultItem")
	procChangeWindowMessageFilter   = modUser32.NewProc("ChangeWindowMessageFilter")
	procChangeWindowMessageFilterEx = modUser32.NewProc("ChangeWindowMessageFilterEx")
	procSetWindowLongPtrW           = modUser32.NewProc("SetWindowLongPtrW")
	procSetWindowLongW              = modUser32.NewProc("SetWindowLongW")
	procCallWindowProcW             = modUser32.NewProc("CallWindowProcW")
	procDefWindowProcW              = modUser32.NewProc("DefWindowProcW")
	procGetDoubleClickTime          = modUser32.NewProc("GetDoubleClickTime")
)

const (
	wmTrayCallback = 0x8000 + 200 // WM_APP + 200
	msgfltAdd      = 1            // MSGFLT_ADD
	msgfltAllow    = 1            // MSGFLT_ALLOW
	gwlpWndProc    = ^uintptr(3)  // -4 (GWLP_WNDPROC)

	nimAdd        = 0x00000000
	nimModify     = 0x00000001
	nimDelete     = 0x00000002
	nimSetVersion = 0x00000004

	nifMessage = 0x00000001
	nifIcon    = 0x00000002
	nifTip     = 0x00000004
	nifInfo    = 0x00000010

	niifInfo = 0x00000001

	wmLButtonDown       = 0x0201
	wmLButtonUp         = 0x0202
	wmLButtonDblClk     = 0x0203
	wmRButtonDown       = 0x0204
	wmRButtonUp         = 0x0205
	wmRButtonDblClk     = 0x0206
	wmContextMenu       = 0x007B
	ninSelect           = 0x0400 // WM_USER + 0
	ninKeySelect        = 0x0401 // WM_USER + 1
	ninBalloonUserClick = 0x0405 // WM_USER + 5
	wmClose             = 0x0010
	wmNull              = 0x0000

	mfString    = 0x00000000
	mfGrayed    = 0x00000001
	mfDisabled  = 0x00000002
	mfChecked   = 0x00000008
	mfUnchecked = 0x00000000
	mfSeparator = 0x00000800

	tpmRightButton = 0x0002
	tpmReturnCmd   = 0x0100
	tpmNoNotify    = 0x0080

	swRestore = 9

	idMenuShowWindow     = 1001
	idMenuAutoStart      = 1002
	idMenuServiceStatus  = 1003
	idMenuServiceToggle  = 1004
	idMenuServiceRestart = 1005
	idMenuExit           = 1006
)


type point struct {
	X int32
	Y int32
}

type notifyIconData struct {
	cbSize           uint32
	hWnd             uintptr
	uID              uint32
	uFlags           uint32
	uCallbackMessage uint32
	hIcon            uintptr
	szTip            [128]uint16
	dwState          uint32
	dwStateMask      uint32
	szInfo           [256]uint16
	uTimeoutOrVer    uint32
	szInfoTitle      [64]uint16
	dwInfoFlags      uint32
	guidItem         [16]byte
	hBalloonIcon     uintptr
}

// WindowsTray 负责管理 Windows 系统托盘图标及其交互
type WindowsTray struct {
	hwnd              uintptr
	hIcon             uintptr
	callbacks         platform.TrayCallbacks
	msgTaskbarCreated uintptr
	subclassCallback  uintptr
	origWndProc       uintptr
	lastClickTime     time.Time
	mu                sync.Mutex
	hasShownBalloon   bool
	isInitialized     bool
}

var globalTray *WindowsTray

func setWindowLongPtr(hwnd uintptr, nIndex uintptr, newLong uintptr) uintptr {
	if procSetWindowLongPtrW.Find() == nil {
		ret, _, _ := procSetWindowLongPtrW.Call(hwnd, nIndex, newLong)
		return ret
	}
	ret, _, _ := procSetWindowLongW.Call(hwnd, nIndex, newLong)
	return ret
}

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

	// 设置托盘版本行为
	nid.uTimeoutOrVer = 4
	procShell_NotifyIconW.Call(nimSetVersion, uintptr(unsafe.Pointer(&nid)))
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
	procSetForegroundWindow.Call(t.hwnd)
	procBringWindowToTop.Call(t.hwnd)
}

// IsWindowActive 判断主窗口当前是否可见且正处于前台
func (t *WindowsTray) IsWindowActive() bool {
	if t.hwnd == 0 {
		return false
	}
	visible, _, _ := procIsWindowVisible.Call(t.hwnd)
	if visible == 0 {
		return false
	}
	fg, _, _ := procGetForegroundWindow.Call()
	return fg == t.hwnd
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
	// 兼容标准/旧版托盘模式，统一提取低 16 位事件代码
	event := uint32(lParam & 0xFFFF)

	switch event {
	case ninSelect, ninKeySelect, wmLButtonUp:
		// 单击或键盘选择：支持单击切换显示与双击判定防抖
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

		// 极短时间（<50ms）内的重复事件为系统或鼠标冗余派发，直接忽略
		if elapsed < 50*time.Millisecond {
			return
		}

		if elapsed <= doubleClickMs {
			// 在双击时间阈值内再次触发：确认为双击，确保窗口唤醒并置顶
			if t.callbacks.OnShowWindow != nil {
				t.callbacks.OnShowWindow()
			}
		} else {
			// 单击触发窗口切换（显示/最小化）
			if t.callbacks.OnToggleWindow != nil {
				t.callbacks.OnToggleWindow()
			}
		}

	case wmLButtonDblClk:
		// 原生双击消息：强制唤醒并置顶窗口
		t.mu.Lock()
		t.lastClickTime = time.Now()
		t.mu.Unlock()
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}

	case wmRButtonUp, wmContextMenu:
		// 右键单击或上下文菜单请求：弹出托盘右键功能菜单
		t.showContextMenu()

	case ninBalloonUserClick:
		// 用户点击气泡通知，打开主界面
		if t.callbacks.OnShowWindow != nil {
			t.callbacks.OnShowWindow()
		}
	}
}


// showContextMenu 弹出右键菜单
func (t *WindowsTray) showContextMenu() {
	hMenu, _, _ := procCreatePopupMenu.Call()
	if hMenu == 0 {
		return
	}
	defer procDestroyMenu.Call(hMenu)

	// 1. 打开主界面
	titlePtr, _ := syscall.UTF16PtrFromString("打开主界面")
	procAppendMenuW.Call(hMenu, mfString, idMenuShowWindow, uintptr(unsafe.Pointer(titlePtr)))
	// 设置为加粗默认项
	procSetMenuDefaultItem.Call(hMenu, idMenuShowWindow, 0)

	// 分隔线
	procAppendMenuW.Call(hMenu, mfSeparator, 0, 0)

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
	autoTextPtr, _ := syscall.UTF16PtrFromString("开机自启动")
	procAppendMenuW.Call(hMenu, autoFlags, idMenuAutoStart, uintptr(unsafe.Pointer(autoTextPtr)))

	// 分隔线
	procAppendMenuW.Call(hMenu, mfSeparator, 0, 0)

	// 3. DNS 核心服务状态与快捷启停
	serviceRunning := false
	if t.callbacks.GetServiceStatus != nil {
		if running, err := t.callbacks.GetServiceStatus(); err == nil {
			serviceRunning = running
		}
	}

	var statusText string
	if serviceRunning {
		statusText = "核心服务: 运行中"
	} else {
		statusText = "核心服务: 已停止"
	}
	statusTextPtr, _ := syscall.UTF16PtrFromString(statusText)
	procAppendMenuW.Call(hMenu, mfString|mfDisabled|mfGrayed, idMenuServiceStatus, uintptr(unsafe.Pointer(statusTextPtr)))

	if serviceRunning {
		stopTextPtr, _ := syscall.UTF16PtrFromString("停止核心服务")
		procAppendMenuW.Call(hMenu, mfString, idMenuServiceToggle, uintptr(unsafe.Pointer(stopTextPtr)))

		restartTextPtr, _ := syscall.UTF16PtrFromString("重启核心服务")
		procAppendMenuW.Call(hMenu, mfString, idMenuServiceRestart, uintptr(unsafe.Pointer(restartTextPtr)))
	} else {
		startTextPtr, _ := syscall.UTF16PtrFromString("启动核心服务")
		procAppendMenuW.Call(hMenu, mfString, idMenuServiceToggle, uintptr(unsafe.Pointer(startTextPtr)))
	}

	// 分隔线
	procAppendMenuW.Call(hMenu, mfSeparator, 0, 0)

	// 4. 退出程序
	exitTextPtr, _ := syscall.UTF16PtrFromString("退出程序")
	procAppendMenuW.Call(hMenu, mfString, idMenuExit, uintptr(unsafe.Pointer(exitTextPtr)))

	// 定位并弹出菜单
	var pt point
	procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	procSetForegroundWindow.Call(t.hwnd)

	cmd, _, _ := procTrackPopupMenu.Call(
		hMenu,
		tpmReturnCmd|tpmNoNotify|tpmRightButton,
		uintptr(pt.X),
		uintptr(pt.Y),
		0,
		t.hwnd,
		0,
	)
	procPostMessageW.Call(t.hwnd, wmNull, 0, 0)

	switch cmd {
	case idMenuShowWindow:
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
			t.callbacks.OnExit()
		}
	}
}
