//go:build windows

package windows

import (
	"os"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

// unpackV4Anchor 解析 NOTIFYICON_VERSION_4 打包在 wParam 中的屏幕锚点坐标。
//
// 高/低 16 位分别为 X / Y，按有符号短整型解读以支持多显示器副屏的负坐标。
// ok 为 false 表示 wParam 未携带有效锚点，调用方应回退 GetCursorPos。
func unpackV4Anchor(wParam uintptr) (x, y int32, ok bool) {
	if wParam == 0 {
		return 0, 0, false
	}
	x = int32(int16(wParam & 0xFFFF))
	y = int32(int16((wParam >> 16) & 0xFFFF))
	return x, y, true
}

// shouldHandleMenuEvent 判断某个托盘通知事件码是否应触发上下文菜单。
//
// 关键语义过滤（非时间防抖）：在 NOTIFYICON_VERSION_4 生效时，Shell 会对单次
// 右键同时派发 WM_RBUTTONUP 与 WM_CONTEXTMENU。若两者都消费，用户选中菜单项后
// 会立刻弹出第二个菜单，表现为"点击无效/需点第二次"。故版本 4 下只认语义消息
// WM_CONTEXTMENU，忽略原始鼠标消息；低版本无 WM_CONTEXTMENU 时才回退到
// WM_RBUTTONUP。此判定只依赖 isV4，不依赖任何时间窗口，不会吞掉菜单关闭后的
// 正常点击。
func shouldHandleMenuEvent(event uint32, isV4 bool) bool {
	if event == wmContextMenu {
		return true
	}
	if event == wmRButtonUp {
		return !isV4
	}
	return false
}

// isShowWindowEvent 判断某个托盘通知事件码是否属于"显示并置顶"动作。
//
// 该动作是幂等的，因此左键单击、键盘选择、双击与气泡点击可无差别地全部映射到
// 同一动作上，无需区分单双击、也无需做任何重复派发过滤——重复派发对幂等动作
// 无害，这正是历史上"双重派发"整类缺陷被消除的方式。
func isShowWindowEvent(event uint32) bool {
	switch event {
	case ninSelect, ninKeySelect, wmLButtonUp, wmLButtonDblClk, ninBalloonUserClick:
		return true
	default:
		return false
	}
}

// mainWindowClassName Wails 在 Windows 上创建的主窗口类名。
const mainWindowClassName = "wailsWindow"

// findMainWindow 按进程 ID 枚举顶层窗口定位主窗口，失败则回退到按标题查找。
//
// 两条路径都能发现隐藏窗口，故以 -minimized 启动时同样可用。带截止时间的轮询
// 用于等待 Wails 完成窗口创建。
func findMainWindow(timeout time.Duration) uintptr {
	deadline := time.Now().Add(timeout)
	for {
		if hwnd := findMainWindowOnce(); hwnd != 0 {
			return hwnd
		}
		if !time.Now().Before(deadline) {
			return 0
		}
		time.Sleep(100 * time.Millisecond)
	}
}

func findMainWindowOnce() uintptr {
	if hwnd := findWindowByPID(uint32(os.Getpid())); hwnd != 0 {
		return hwnd
	}
	titlePtr, err := syscall.UTF16PtrFromString(DefaultWindowTitle)
	if err != nil {
		return 0
	}
	hwnd, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(titlePtr)))
	return hwnd
}

// isCandidateMainWindow 判断某个顶层窗口是否是本进程的 Wails 主窗口。
//
// 纯函数，便于在无消息循环的环境下直接断言。
//
// 注意：刻意不要求窗口可见——以 -minimized 启动时主窗口处于隐藏状态，
// 若以可见性作为筛选条件将永远匹配不到，导致托盘初始化失败。
// 同时排除工具窗口，避免误取隐藏的辅助窗口。
func isCandidateMainWindow(pid, winPID uint32, className string, exStyle uint32) bool {
	if pid == 0 || winPID != pid {
		return false
	}
	if className != mainWindowClassName {
		return false
	}
	const wsExToolWindow = 0x00000080
	if exStyle&wsExToolWindow != 0 {
		return false
	}
	return true
}

// enumWindowsArgs 承载 EnumWindows 的输入与输出。
//
// 以包级变量承载而非经 lParam 传递指针，既避免 uintptr→unsafe.Pointer 转换，
// 也避开 go vet 的 unsafeptr 告警；enumMu 串行化访问。
var (
	enumMu   sync.Mutex
	enumArgs enumWindowsArgs
)

type enumWindowsArgs struct {
	targetPID uint32
	found     uintptr
}

// enumWindowsCallback 由 EnumWindows 逐窗口回调，收集本进程的 Wails 主窗口。
func enumWindowsCallback(hwnd uintptr, _ uintptr) uintptr {
	var pid uint32
	procGetWindowThreadProcessId.Call(hwnd, uintptr(unsafe.Pointer(&pid)))

	var classBuf [128]uint16
	procGetClassNameW.Call(hwnd, uintptr(unsafe.Pointer(&classBuf[0])), uintptr(len(classBuf)))
	className := syscall.UTF16ToString(classBuf[:])

	exStyle := getWindowLongPtr(hwnd, gwlExStyle)

	if !isCandidateMainWindow(enumArgs.targetPID, pid, className, uint32(exStyle)) {
		return 1 // 继续枚举
	}
	enumArgs.found = hwnd
	return 0 // 停止枚举
}

// findWindowByPID 枚举顶层窗口，返回本进程的 Wails 主窗口句柄。
func findWindowByPID(pid uint32) uintptr {
	enumMu.Lock()
	defer enumMu.Unlock()

	cb := syscall.NewCallback(enumWindowsCallback)
	enumArgs = enumWindowsArgs{targetPID: pid}
	procEnumWindows.Call(cb, 0)
	return enumArgs.found
}

// loadTrayIcon 加载托盘图标，并返回该句柄是否归本模块所有（需在销毁时释放）。
//
// 优先从可执行文件抽取图标（所有权归本模块）；抽取失败时回退到系统共享的
// IDI_APPLICATION 图标——该句柄由系统持有，绝不能 DestroyIcon。
func loadTrayIcon() (hIcon uintptr, owned bool) {
	exePath, err := os.Executable()
	if err != nil {
		return fallbackIcon()
	}
	exePtr, err := syscall.UTF16PtrFromString(exePath)
	if err != nil {
		return fallbackIcon()
	}
	var hSmallIcon uintptr
	ret, _, _ := procExtractIconExW.Call(
		uintptr(unsafe.Pointer(exePtr)),
		0,
		0,
		uintptr(unsafe.Pointer(&hSmallIcon)),
		1,
	)
	if ret != 0 && hSmallIcon != 0 {
		return hSmallIcon, true
	}
	return fallbackIcon()
}

// fallbackIcon 返回系统共享应用图标（非本模块所有）。
func fallbackIcon() (uintptr, bool) {
	hIcon, _, _ := procLoadIconW.Call(0, 32512) // IDI_APPLICATION
	return hIcon, false
}

// menuItemTexts 读取菜单内各项文案，供测试断言菜单结构。
func menuItemTexts(hMenu uintptr) []string {
	count, _, _ := procGetMenuItemCount.Call(hMenu)
	texts := make([]string, 0, count)
	for i := uintptr(0); i < count; i++ {
		var buf [64]uint16
		ret, _, _ := procGetMenuStringW.Call(
			hMenu,
			i,
			uintptr(unsafe.Pointer(&buf[0])),
			uintptr(len(buf)),
			mfByPosition,
		)
		if ret == 0 {
			texts = append(texts, "")
			continue
		}
		texts = append(texts, syscall.UTF16ToString(buf[:]))
	}
	return texts
}
