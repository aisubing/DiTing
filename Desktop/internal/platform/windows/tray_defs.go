//go:build windows

package windows


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

func setWindowLongPtr(hwnd uintptr, nIndex uintptr, newLong uintptr) uintptr {
	if procSetWindowLongPtrW.Find() == nil {
		ret, _, _ := procSetWindowLongPtrW.Call(hwnd, nIndex, newLong)
		return ret
	}
	ret, _, _ := procSetWindowLongW.Call(hwnd, nIndex, newLong)
	return ret
}
