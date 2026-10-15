//go:build linux

package linux

import (
	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// LinuxTrayManager Linux 平台系统托盘存根。
type LinuxTrayManager struct{}

// NewTrayManager 构造 Linux 托盘管理器。
func NewTrayManager() platform.TrayManager {
	return &LinuxTrayManager{}
}

// Init 在 Linux 无头/服务模式下为空操作。
func (m *LinuxTrayManager) Init(callbacks platform.TrayCallbacks) error {
	return nil
}

// ShowBalloon 在 Linux 环境下为空操作。
func (m *LinuxTrayManager) ShowBalloon(title, text string) error {
	return nil
}

// ActivateWindow 在 Linux 环境下为空操作。
func (m *LinuxTrayManager) ActivateWindow() {}

// Destroy 在 Linux 环境下为空操作。
func (m *LinuxTrayManager) Destroy() {}
