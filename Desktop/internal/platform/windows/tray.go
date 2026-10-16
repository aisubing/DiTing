//go:build windows

package windows

import (
	"fmt"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// WindowsTray 管理 Windows 任务栏托盘图标及其交互，直接实现 platform.TrayManager。
//
// 设计要点（针对历史缺陷）：
//   - 显示动作幂等：左键单击/键盘选择/双击/气泡点击统一映射为"显示并置顶"，不做
//     单双击判定、不做时间防抖，从设计上消除"双重派发"整类问题。
//   - 前台判定只依赖窗口可见性，不与 GetForegroundWindow 比对，天然免疫任务栏
//     抢焦点导致的判定失效。
//   - 窗口消息通过替换 Wails 主窗口的窗口过程（SetWindowLongPtr + CallWindowProcW
//     链式转发）拦截。该过程运行在 GUI 线程，故窗口操作可在窗口线程内同步执行，
//     前台令牌有效。
type WindowsTray struct {
	mu sync.Mutex

	hwnd               uintptr
	hIcon              uintptr
	ownsIcon           bool
	callbacks          platform.TrayCallbacks
	msgTaskbarCreated  uintptr
	windowProcCallback uintptr
	origWndProc        uintptr

	hasShownBalloon bool
	isInitialized   bool
	isVersion4      bool

	// menuActive 仅在 TrackPopupMenu 生存期内为真，用于阻止菜单重入。
	// 这是纯布尔门，与历史上的时间防抖有本质区别：菜单退出即清除，
	// 不会吞掉菜单关闭后的正常点击。
	menuActive bool

	// pendingBalloon 缓存待由窗口线程投递的气泡文案。ShowBalloon 可能被异步
	// goroutine 调用，而 Shell_NotifyIcon 必须发生在图标所属线程。
	pendingBalloon *balloonContent
}

// balloonContent 承载一次待投递的气泡内容。
type balloonContent struct {
	title string
	text  string
}

// globalTray 窗口过程只能取得 hwnd，故以包级指针保存当前实例。
var globalTray atomic.Pointer[WindowsTray]

// NewTrayManager 构造 Windows 托盘管理器，直接满足 platform.TrayManager 接口。
func NewTrayManager() platform.TrayManager {
	return &WindowsTray{}
}

// NewWindowsTray 构造具体类型的 Windows 托盘实例，便于内部与测试使用。
func NewWindowsTray() *WindowsTray {
	return &WindowsTray{}
}

// Init 查找主窗口、安装窗口过程拦截并注册托盘图标。
//
// 应在 Wails 的 OnDomReady 阶段调用（此时主窗口必定已创建）。
// 该方法幂等：OnDomReady 在每次页面导航（含开发模式热重载）时都会触发，
// 重复调用将直接返回，避免重复安装窗口过程与重复注册图标。
func (t *WindowsTray) Init(callbacks platform.TrayCallbacks) error {
	t.mu.Lock()
	if t.isInitialized {
		t.mu.Unlock()
		return nil
	}
	t.callbacks = callbacks
	t.mu.Unlock()

	hwnd := findMainWindow(5 * time.Second)
	if hwnd == 0 {
		return fmt.Errorf("未能查找到主窗口，托盘初始化失败")
	}

	t.mu.Lock()
	t.hwnd = hwnd
	t.mu.Unlock()

	// 注册 TaskbarCreated 消息，以便资源管理器重启后自动重绘托盘图标。
	tbMsgPtr, _ := syscall.UTF16PtrFromString("TaskbarCreated")
	msgTaskbarCreated, _, _ := procRegisterWindowMessageW.Call(uintptr(unsafe.Pointer(tbMsgPtr)))

	t.mu.Lock()
	t.msgTaskbarCreated = msgTaskbarCreated
	t.mu.Unlock()

	// 放行 UIPI 消息过滤：以管理员特权运行时，允许 Explorer.exe（中完整性级别）
	// 向主窗口投递托盘消息。
	if procChangeWindowMessageFilter.Find() == nil {
		procChangeWindowMessageFilter.Call(uintptr(wmTrayCallback), msgfltAdd)
		if msgTaskbarCreated != 0 {
			procChangeWindowMessageFilter.Call(msgTaskbarCreated, msgfltAdd)
		}
	}

	hIcon, owned := loadTrayIcon()
	t.mu.Lock()
	t.hIcon = hIcon
	t.ownsIcon = owned
	t.mu.Unlock()

	if err := t.addNotifyIcon(); err != nil {
		return fmt.Errorf("添加系统托盘图标失败: %w", err)
	}

	// 挂载窗口消息拦截过程。
	//
	// 此处替换窗口过程（SetWindowLongPtr + CallWindowProcW 链式转发），而非使用
	// comctl32 的 SetWindowSubclass：实测 SetWindowSubclass 在本进程的 Wails 窗口上
	// 恒返回失败（包括 aspect_ratio.go 中既有的同类调用），而替换 WndProc 的方案
	// 已被历史版本验证可用。原窗口过程通过 CallWindowProcW 转发，保证 Wails 自身
	// 的消息处理不受影响。
	globalTray.Store(t)
	t.windowProcCallback = syscall.NewCallback(trayWindowProc)
	t.origWndProc = setWindowLongPtr(t.hwnd, gwlpWndProc, t.windowProcCallback)
	if t.origWndProc == 0 {
		// 回滚已注册的托盘图标，避免残留
		t.removeNotifyIcon(hwnd)
		globalTray.Store(nil)
		return fmt.Errorf("挂载窗口过程失败")
	}

	t.mu.Lock()
	t.isInitialized = true
	t.mu.Unlock()
	return nil
}

// addNotifyIcon 注册托盘图标并协商 NOTIFYICON_VERSION_4 行为。
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

	// 协商版本 4：图标不会在进程退出后残留，且能收到语义化的
	// NIN_SELECT / WM_CONTEXTMENU 通知。
	nid.uTimeoutOrVer = notifyIconVersion4
	retV, _, _ := procShell_NotifyIconW.Call(nimSetVersion, uintptr(unsafe.Pointer(&nid)))

	t.mu.Lock()
	t.isVersion4 = retV != 0
	t.mu.Unlock()
	return nil
}

// ShowBalloon 弹出托盘气泡通知。
//
// 可由任意 goroutine 调用：文案先入待发槽位，再 PostMessage 交由窗口线程执行
// Shell_NotifyIcon，保证图标操作始终发生在图标所属线程上。
func (t *WindowsTray) ShowBalloon(title, text string) error {
	t.mu.Lock()
	if !t.isInitialized || t.hwnd == 0 {
		t.mu.Unlock()
		return fmt.Errorf("托盘尚未初始化")
	}
	hwnd := t.hwnd
	t.pendingBalloon = &balloonContent{title: title, text: text}
	t.mu.Unlock()

	// 已在窗口线程时同步执行，否则投递到窗口线程。
	if procPostMessageW.Find() != nil {
		return fmt.Errorf("PostMessageW 不可用")
	}
	procPostMessageW.Call(hwnd, wmTrayShowBalloon, 0, 0)
	return nil
}

// showBalloonNow 在窗口线程内执行气泡弹出，消费待发槽位。
func (t *WindowsTray) showBalloonNow() {
	t.mu.Lock()
	content := t.pendingBalloon
	t.pendingBalloon = nil
	hwnd := t.hwnd
	t.mu.Unlock()

	if content == nil || hwnd == 0 {
		return
	}

	var nid notifyIconData
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = hwnd
	nid.uID = 1
	nid.uFlags = nifInfo
	nid.dwInfoFlags = niifInfo

	titleUTF16, _ := syscall.UTF16FromString(content.title)
	copy(nid.szInfoTitle[:], titleUTF16)

	textUTF16, _ := syscall.UTF16FromString(content.text)
	copy(nid.szInfo[:], textUTF16)

	procShell_NotifyIconW.Call(nimModify, uintptr(unsafe.Pointer(&nid)))
}

// ActivateWindow 将主窗口还原并置顶。
//
// 会在窗口线程内被同步调用，前台令牌有效，故直接使用 SetForegroundWindow 即可，
// 无需历史上的 keybd_event(VK_MENU) 取巧（那是为绕过异步派发导致的前台锁定）。
func (t *WindowsTray) ActivateWindow() {
	t.mu.Lock()
	hwnd := t.hwnd
	t.mu.Unlock()
	if hwnd == 0 {
		return
	}
	procShowWindow.Call(hwnd, swRestore)
	procSetForegroundWindow.Call(hwnd)
	procBringWindowToTop.Call(hwnd)
}

// IsWindowActive 判断主窗口当前是否可见且未最小化。
//
// 刻意不与 GetForegroundWindow 比对：点击托盘图标时 Windows 任务栏
// (Shell_TrayWnd) 会抢占前台焦点，使前台句柄比对恒为 false。改用可见性判定后
// 天然免疫该问题，也彻底移除了"失活时间戳"这类时序补丁。
func (t *WindowsTray) IsWindowActive() bool {
	t.mu.Lock()
	hwnd := t.hwnd
	t.mu.Unlock()
	if hwnd == 0 {
		return false
	}
	visible, _, _ := procIsWindowVisible.Call(hwnd)
	if visible == 0 {
		return false
	}
	iconic, _, _ := procIsIconic.Call(hwnd)
	return iconic == 0
}

// removeNotifyIcon 从任务栏移除托盘图标。
func (t *WindowsTray) removeNotifyIcon(hwnd uintptr) {
	if hwnd == 0 {
		return
	}
	var nid notifyIconData
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = hwnd
	nid.uID = 1
	procShell_NotifyIconW.Call(nimDelete, uintptr(unsafe.Pointer(&nid)))
}

// Destroy 移除托盘图标、卸载窗口过程拦截并释放图标资源。可安全重复调用。
func (t *WindowsTray) Destroy() {
	t.mu.Lock()
	if !t.isInitialized && t.hwnd == 0 {
		t.mu.Unlock()
		return
	}
	hwnd := t.hwnd
	hIcon := t.hIcon
	ownsIcon := t.ownsIcon
	origWndProc := t.origWndProc

	// 先落标记，保证重复调用直接返回。
	t.isInitialized = false
	t.hwnd = 0
	t.hIcon = 0
	t.ownsIcon = false
	t.origWndProc = 0
	t.windowProcCallback = 0
	t.mu.Unlock()

	t.removeNotifyIcon(hwnd)

	// 还原原窗口过程，卸载消息拦截
	if hwnd != 0 && origWndProc != 0 {
		setWindowLongPtr(hwnd, gwlpWndProc, origWndProc)
	}

	// 仅销毁本模块从可执行文件抽取的图标；系统共享的 IDI_APPLICATION 不可销毁。
	if hIcon != 0 && ownsIcon {
		procDestroyIcon.Call(hIcon)
	}

	globalTray.Store(nil)
}
