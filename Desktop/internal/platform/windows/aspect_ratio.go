//go:build windows

package windows

import (
	"math"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

// aspectState 保存比例锁定所需的窗口句柄、原窗口过程与回调地址。
//
// 不用 comctl32 的 SetWindowSubclass：实测它在 Wails 主窗口上恒返回 FALSE
// （失败且不设 GetLastError），托盘模块已因此改用 SetWindowLongPtr 链式替换，
// 这里沿用同一方案。原窗口过程必须保留并在其余消息上转发，否则 Wails 自身的
// 消息处理（含托盘模块后挂的窗口过程）会被整体顶掉。
var aspectState struct {
	mu        sync.Mutex
	hwnd      uintptr
	orig      uintptr
	proc      uintptr
	installed bool
}

const (
	wmSizing = 0x0214

	wmszLeft        = 1
	wmszRight       = 2
	wmszTop         = 3
	wmszTopLeft     = 4
	wmszTopRight    = 5
	wmszBottom      = 6
	wmszBottomLeft  = 7
	wmszBottomRight = 8
)

// AdjustRectForAspectRatio 根据给定的 16:9 等比例与最小宽高调整拖拽窗口尺寸
func AdjustRectForAspectRatio(r *rect, edge uintptr, aspect float64, minW, minH int32) {
	if aspect <= 0 {
		aspect = 16.0 / 9.0
	}

	w := r.Right - r.Left
	h := r.Bottom - r.Top

	switch edge {
	case wmszLeft, wmszRight:
		// 拖拽左右边缘：依据宽度计算高度
		if w < minW {
			w = minW
		}
		newH := int32(math.Round(float64(w) / aspect))
		if newH < minH {
			newH = minH
			w = int32(math.Round(float64(newH) * aspect))
		}
		if edge == wmszLeft {
			r.Left = r.Right - w
		} else {
			r.Right = r.Left + w
		}
		r.Bottom = r.Top + newH

	case wmszTop, wmszBottom:
		// 拖拽上下边缘：依据高度计算宽度
		if h < minH {
			h = minH
		}
		newW := int32(math.Round(float64(h) * aspect))
		if newW < minW {
			newW = minW
			h = int32(math.Round(float64(newW) / aspect))
		}
		if edge == wmszTop {
			r.Top = r.Bottom - h
		} else {
			r.Bottom = r.Top + h
		}
		r.Right = r.Left + newW

	case wmszTopLeft, wmszTopRight, wmszBottomLeft, wmszBottomRight:
		// 拖拽四角：根据高度主导计算宽度
		if h < minH {
			h = minH
		}
		newW := int32(math.Round(float64(h) * aspect))
		if newW < minW {
			newW = minW
			h = int32(math.Round(float64(newW) / aspect))
		}

		if edge == wmszTopLeft || edge == wmszBottomLeft {
			r.Left = r.Right - newW
		} else {
			r.Right = r.Left + newW
		}

		if edge == wmszTopLeft || edge == wmszTopRight {
			r.Top = r.Bottom - h
		} else {
			r.Bottom = r.Top + h
		}
	}
}

// aspectRatioWindowProc 替换到主窗口上的窗口过程，拦截 WM_SIZING 强制纵横比。
//
// 返回 TRUE 表示已处理该消息；其余消息一律经 CallWindowProcW 转发给原过程。
// 原过程可能已是托盘模块挂上的转发过程，链式转发保证两者互不覆盖。
func aspectRatioWindowProc(hwnd uintptr, msg uint32, wParam uintptr, lParam uintptr) uintptr {
	if msg == wmSizing && lParam != 0 {
		r := (*rect)(unsafe.Pointer(lParam))
		AdjustRectForAspectRatio(r, wParam, 16.0/9.0, 1280, 720)
		return 1
	}

	aspectState.mu.Lock()
	orig := aspectState.orig
	aspectState.mu.Unlock()
	if orig == 0 {
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}
	ret, _, _ := procCallWindowProcW.Call(orig, hwnd, uintptr(msg), wParam, lParam)
	return ret
}

// LockWindowAspectRatio 查找目标标题的窗口并挂载 16:9 比例锁定窗口过程。
//
// 幂等：同一窗口重复调用直接返回 true，不会叠加多层回调
// （OnDomReady 在每次导航/热重载都会触发）。返回值必须被调用方检查——
// 静默失败正是该功能历史上从未生效的原因。
func LockWindowAspectRatio(windowTitle string, aspect float64) bool {
	_ = aspect // 比例固定为 16:9，与窗口最小尺寸 1280x720 保持一致

	titlePtr, err := syscall.UTF16PtrFromString(windowTitle)
	if err != nil {
		return false
	}

	var hwnd uintptr
	// 尝试轮询查找窗口（等待 Wails 窗口完全初始化显示）
	for i := 0; i < 30; i++ {
		h, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(titlePtr)))
		if h != 0 {
			hwnd = h
			break
		}
		time.Sleep(100 * time.Millisecond)
	}

	if hwnd == 0 {
		return false
	}

	aspectState.mu.Lock()
	defer aspectState.mu.Unlock()

	if aspectState.installed && aspectState.hwnd == hwnd {
		return true
	}

	callback := syscall.NewCallback(aspectRatioWindowProc)
	orig := setWindowLongPtr(hwnd, gwlpWndProc, callback)
	if orig == 0 {
		return false
	}

	aspectState.hwnd = hwnd
	aspectState.orig = orig
	aspectState.proc = callback
	aspectState.installed = true
	return true
}
