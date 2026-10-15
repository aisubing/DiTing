//go:build windows

package windows

import (
	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// WindowsTrayManager 适配器，实现 platform.TrayManager 接口
type WindowsTrayManager struct {
	tray *WindowsTray
}

// NewTrayManager 构造 Windows 托盘管理器
func NewTrayManager() platform.TrayManager {
	return &WindowsTrayManager{
		tray: NewWindowsTray(),
	}
}

// Init 初始化系统托盘
func (m *WindowsTrayManager) Init(callbacks platform.TrayCallbacks) error {
	return m.tray.Init(callbacks)
}

// ShowBalloon 弹出托盘气泡提示
func (m *WindowsTrayManager) ShowBalloon(title, text string) error {
	return m.tray.ShowBalloon(title, text)
}

// ActivateWindow 唤醒并置顶窗口
func (m *WindowsTrayManager) ActivateWindow() {
	m.tray.ActivateWindow()
}

// Destroy 销毁托盘
func (m *WindowsTrayManager) Destroy() {
	m.tray.Destroy()
}
