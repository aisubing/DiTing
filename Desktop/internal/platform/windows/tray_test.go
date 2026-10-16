//go:build windows

package windows

import (
	"errors"
	"testing"
	"time"
	"unsafe"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

func TestNotifyIconDataStructSize(t *testing.T) {
	var nid notifyIconData
	sz := unsafe.Sizeof(nid)
	// 在 64 位 Windows 系统下，notifyIconData 结构体对齐后尺寸应符合 Win32 Shell API 期望
	if sz < 900 {
		t.Fatalf("notifyIconData 结构体尺寸异常: %d", sz)
	}
}

func TestTrayManagerInterface(t *testing.T) {
	mgr := NewTrayManager()
	if mgr == nil {
		t.Fatal("NewTrayManager 返回空")
	}

	var _ platform.TrayManager = mgr

	// 托盘在未完成 HWND 绑定的情况下调用 ShowBalloon 应优雅报错
	err := mgr.ShowBalloon("测试", "内容")
	if err == nil {
		t.Fatal("未初始化的托盘调用 ShowBalloon 应当返回错误")
	}

	// 销毁未初始化的托盘应安全无异常
	mgr.Destroy()
	mgr.ActivateWindow()
}

func TestWindowsTrayDirect(t *testing.T) {
	tray := NewWindowsTray()
	if tray.IsWindowActive() {
		t.Fatal("未初始化的托盘窗口状态不应为活跃")
	}

	// 测试 Callbacks 结构装载
	var toggled, shown, exited bool
	var autoStartVal bool

	cb := platform.TrayCallbacks{
		OnToggleWindow: func() {
			toggled = true
		},
		OnShowWindow: func() {
			shown = true
		},
		OnToggleAutoStart: func() bool {
			autoStartVal = !autoStartVal
			return autoStartVal
		},
		IsAutoStart: func() bool {
			return autoStartVal
		},
		GetServiceStatus: func() (bool, error) {
			return true, nil
		},
		OnToggleService: func() error {
			return nil
		},
		OnRestartService: func() error {
			return nil
		},
		OnExit: func() {
			exited = true
		},
	}

	tray.callbacks = cb

	if tray.callbacks.OnToggleWindow != nil {
		tray.callbacks.OnToggleWindow()
	}
	if !toggled {
		t.Fatal("OnToggleWindow 未成功调用")
	}

	if tray.callbacks.OnShowWindow != nil {
		tray.callbacks.OnShowWindow()
	}
	if !shown {
		t.Fatal("OnShowWindow 未成功调用")
	}

	if tray.callbacks.OnToggleAutoStart != nil {
		tray.callbacks.OnToggleAutoStart()
	}
	if !autoStartVal {
		t.Fatal("OnToggleAutoStart 未成功切换状态")
	}

	running, err := tray.callbacks.GetServiceStatus()
	if err != nil || !running {
		t.Fatalf("GetServiceStatus 返回异常: running=%v, err=%v", running, err)
	}

	if tray.callbacks.OnExit != nil {
		tray.callbacks.OnExit()
	}
	if !exited {
		t.Fatal("OnExit 未成功调用")
	}

	tray.Destroy()
}

func TestTrayCallbacksServiceError(t *testing.T) {
	expectedErr := errors.New("service check failed")
	cb := platform.TrayCallbacks{
		GetServiceStatus: func() (bool, error) {
			return false, expectedErr
		},
	}

	running, err := cb.GetServiceStatus()
	if !errors.Is(err, expectedErr) || running {
		t.Fatalf("错误透传不符合预期: running=%v, err=%v", running, err)
	}
}

func TestHandleTrayCallbackSingleAndDoubleClick(t *testing.T) {
	tray := NewWindowsTray()

	var toggleCount, showCount int
	tray.callbacks = platform.TrayCallbacks{
		OnToggleWindow: func() {
			toggleCount++
		},
		OnShowWindow: func() {
			showCount++
		},
	}

	// 1. 测试标准/旧版单个左键抬起 (wmLButtonUp)
	tray.handleTrayCallback(0, uintptr(wmLButtonUp))
	if toggleCount != 1 {
		t.Fatalf("预期触发 OnToggleWindow 1 次，实际: %d", toggleCount)
	}

	// 2. 模拟 NOTIFYICON_VERSION_4 规范：(uID << 16) | ninSelect 单击
	// 人工重置时间以模拟非双击的独立单击
	tray.lastClickTime = tray.lastClickTime.Add(-1 * time.Second)
	lParamV4Select := uintptr((1 << 16) | ninSelect)
	tray.handleTrayCallback(0, lParamV4Select)
	if toggleCount != 2 {
		t.Fatalf("预期触发 OnToggleWindow 2 次，实际: %d", toggleCount)
	}

	// 3. 模拟极短时间（<50ms）内的硬件或系统冗余事件，应当防抖丢弃
	tray.handleTrayCallback(0, lParamV4Select)
	if toggleCount != 2 {
		t.Fatalf("预期极短时间冗余事件被忽略，toggleCount 实际: %d", toggleCount)
	}

	// 4. 模拟双击阈值内（如 100ms 后）再次点击，确认为双击，触发 OnShowWindow
	tray.lastClickTime = time.Now().Add(-100 * time.Millisecond)
	tray.handleTrayCallback(0, lParamV4Select)
	if showCount != 1 {
		t.Fatalf("双击应触发 OnShowWindow 1 次，实际: %d", showCount)
	}

	// 5. 模拟原生双击事件 (wmLButtonDblClk)
	tray.handleTrayCallback(0, uintptr((1<<16)|wmLButtonDblClk))
	if showCount != 2 {
		t.Fatalf("原生双击应触发 OnShowWindow 累加至 2 次，实际: %d", showCount)
	}

	// 6. 模拟气泡通知点击 (ninBalloonUserClick)
	tray.handleTrayCallback(0, uintptr((1<<16)|ninBalloonUserClick))
	if showCount != 3 {
		t.Fatalf("气泡通知点击应触发 OnShowWindow 累加至 3 次，实际: %d", showCount)
	}
}

