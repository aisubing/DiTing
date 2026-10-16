//go:build windows

package windows

import (
	"syscall"
	"unsafe"
)

// Win32 过程地址：本模块为纯 syscall 实现，不引入任何托盘相关三方库。
//
// modUser32 与 modComctl32 复用 screenshot.go / aspect_ratio.go 中已有的声明，
// 避免同包重复定义。
var (
	procShell_NotifyIconW         = modShell32.NewProc("Shell_NotifyIconW")
	procExtractIconExW            = modShell32.NewProc("ExtractIconExW")
	procCreatePopupMenu           = modUser32.NewProc("CreatePopupMenu")
	procAppendMenuW               = modUser32.NewProc("AppendMenuW")
	procDestroyMenu               = modUser32.NewProc("DestroyMenu")
	procTrackPopupMenu            = modUser32.NewProc("TrackPopupMenu")
	procGetMenuItemCount          = modUser32.NewProc("GetMenuItemCount")
	procGetMenuStringW            = modUser32.NewProc("GetMenuStringW")
	procSetMenuDefaultItem        = modUser32.NewProc("SetMenuDefaultItem")
	procGetCursorPos              = modUser32.NewProc("GetCursorPos")
	procSetForegroundWindow       = modUser32.NewProc("SetForegroundWindow")
	procShowWindow                = modUser32.NewProc("ShowWindow")
	procBringWindowToTop          = modUser32.NewProc("BringWindowToTop")
	procIsWindowVisible           = modUser32.NewProc("IsWindowVisible")
	procIsIconic                  = modUser32.NewProc("IsIconic")
	procPostMessageW              = modUser32.NewProc("PostMessageW")
	procRegisterWindowMessageW    = modUser32.NewProc("RegisterWindowMessageW")
	procDestroyIcon               = modUser32.NewProc("DestroyIcon")
	procLoadIconW                 = modUser32.NewProc("LoadIconW")
	procChangeWindowMessageFilter = modUser32.NewProc("ChangeWindowMessageFilter")
	procGetWindowThreadProcessId  = modUser32.NewProc("GetWindowThreadProcessId")
	procEnumWindows               = modUser32.NewProc("EnumWindows")
	procSetWindowLongPtrW         = modUser32.NewProc("SetWindowLongPtrW")
	procSetWindowLongW            = modUser32.NewProc("SetWindowLongW")
	procCallWindowProcW           = modUser32.NewProc("CallWindowProcW")
	procDefWindowProcW            = modUser32.NewProc("DefWindowProcW")
	procGetClassNameW             = modUser32.NewProc("GetClassNameW")
	procGetWindowLongPtrW         = modUser32.NewProc("GetWindowLongPtrW")
	procGetWindowLongW            = modUser32.NewProc("GetWindowLongW")
)

// 托盘回调消息（WM_APP + 200，与 Wails 自用的
// RegisterWindowMessage("WincV0.InvokeCallback") 无冲突）。
const (
	wmTrayCallback    = 0x8000 + 200
	wmTrayShowBalloon = 0x8000 + 201
	msgfltAdd         = 1 // MSGFLT_ADD
)

// gwlpWndProc 为 Get/SetWindowLongPtr 的窗口过程索引。
const gwlpWndProc = ^uintptr(3) // -4 (GWLP_WNDPROC)

// gwlExStyle 为窗口扩展样式索引。
const gwlExStyle = ^uintptr(19) // -20 (GWL_EXSTYLE)

// getWindowLongPtr 读取窗口属性，64 位优先使用 GetWindowLongPtrW。
func getWindowLongPtr(hwnd uintptr, nIndex uintptr) uintptr {
	if procGetWindowLongPtrW.Find() == nil {
		ret, _, _ := procGetWindowLongPtrW.Call(hwnd, nIndex)
		return ret
	}
	ret, _, _ := procGetWindowLongW.Call(hwnd, nIndex)
	return ret
}

// setWindowLongPtr 设置窗口过程，64 位优先使用 SetWindowLongPtrW。
func setWindowLongPtr(hwnd uintptr, nIndex uintptr, newLong uintptr) uintptr {
	if procSetWindowLongPtrW.Find() == nil {
		ret, _, _ := procSetWindowLongPtrW.Call(hwnd, nIndex, newLong)
		return ret
	}
	ret, _, _ := procSetWindowLongW.Call(hwnd, nIndex, newLong)
	return ret
}

// Shell_NotifyIcon 相关常量。
const (
	nimAdd        = 0x00000000
	nimModify     = 0x00000001
	nimDelete     = 0x00000002
	nimSetVersion = 0x00000004

	nifMessage = 0x00000001
	nifIcon    = 0x00000002
	nifTip     = 0x00000004
	nifInfo    = 0x00000010

	niifInfo = 0x00000001

	notifyIconVersion4 = 4
)

// 托盘通知事件码（NOTIFYICON_VERSION_4 下为 LOWORD(lParam)）。
const (
	wmLButtonUp         = 0x0202
	wmLButtonDblClk     = 0x0203
	wmRButtonUp         = 0x0205
	wmContextMenu       = 0x007B
	ninSelect           = 0x0400 // WM_USER + 0
	ninKeySelect        = 0x0401 // WM_USER + 1
	ninBalloonUserClick = 0x0405 // WM_USER + 5
)

// 窗口消息。
const (
	wmClose = 0x0010
	wmNull  = 0x0000
)

// 菜单标志。
const (
	mfString     = 0x00000000
	mfGrayed     = 0x00000001
	mfDisabled   = 0x00000002
	mfChecked    = 0x00000008
	mfUnchecked  = 0x00000000
	mfSeparator  = 0x00000800
	mfByPosition = 0x00000400
)

// TrackPopupMenu 标志。
const (
	tpmRightButton = 0x0002
	tpmReturnCmd   = 0x0100
	tpmNoNotify    = 0x0080
)

// 菜单项命令 ID。
const (
	idMenuShowWindow     = 1001
	idMenuHideWindow     = 1002
	idMenuAutoStart      = 1003
	idMenuServiceStatus  = 1004
	idMenuServiceToggle  = 1005
	idMenuServiceRestart = 1006
	idMenuExit           = 1007
)

// swRestore 还原窗口并激活。
const swRestore = 9

// notifyIconData 对应 Win32 NOTIFYICONDATAW 结构体。
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

// point 对应 Win32 POINT 结构体。
type point struct {
	X int32
	Y int32
}

// appendMenuItem 向菜单追加一个菜单项，分隔符无需文本。
func appendMenuItem(hMenu uintptr, flags uintptr, id uintptr, text string) {
	if flags&mfSeparator != 0 {
		procAppendMenuW.Call(hMenu, flags, id, 0)
		return
	}
	ptr, err := syscall.UTF16PtrFromString(text)
	if err != nil {
		return
	}
	procAppendMenuW.Call(hMenu, flags, id, uintptr(unsafe.Pointer(ptr)))
}
