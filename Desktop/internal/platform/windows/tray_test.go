//go:build windows

package windows

import (
	"errors"
	"testing"
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
