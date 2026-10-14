//go:build linux

package linux

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// LinuxAutoStartManager 通过 XDG autostart 规范管理 Linux 桌面的自启配置。
type LinuxAutoStartManager struct{}

// NewAutoStartManager 构造 Linux 自启管理器。
func NewAutoStartManager() platform.AutoStartManager {
	return &LinuxAutoStartManager{}
}

func (m *LinuxAutoStartManager) desktopFilePath() string {
	return desktopFilePath()
}

// desktopFilePath 返回 XDG 桌面自启条目的绝对路径（无法定位时为 ""）。
func desktopFilePath() string {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		home := os.Getenv("HOME")
		if home == "" {
			return ""
		}
		configDir = filepath.Join(home, ".config")
	}
	return filepath.Join(configDir, "autostart", "diting.desktop")
}

// xdgAutoStartPresent 判断 XDG 桌面自启条目是否已存在。
//
// 供服务状态查询复用：当核心服务由桌面应用而非 systemd 托管时，
// 该条目才是开机自启的实际生效依据。
func xdgAutoStartPresent() bool {
	p := desktopFilePath()
	if p == "" {
		return false
	}
	_, err := os.Stat(p)
	return err == nil
}

// IsEnabled 检查 Linux 桌面自启条目是否存在。
func (m *LinuxAutoStartManager) IsEnabled() bool {
	return xdgAutoStartPresent()
}

// SetEnabled 创建或移除 ~/.config/autostart/diting.desktop。
func (m *LinuxAutoStartManager) SetEnabled(enable bool) (bool, error) {
	p := m.desktopFilePath()
	if p == "" {
		return false, fmt.Errorf("无法获取用户配置目录 (HOME/XDG_CONFIG_HOME 未设置)")
	}

	if enable {
		exePath, err := os.Executable()
		if err != nil {
			return false, fmt.Errorf("获取执行路径失败: %w", err)
		}
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			return false, fmt.Errorf("创建自启目录失败: %w", err)
		}
		entry := fmt.Sprintf("[Desktop Entry]\nType=Application\nName=谛听 DNS\nExec=%s\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\n", exePath)
		if err := os.WriteFile(p, []byte(entry), 0o644); err != nil {
			return false, fmt.Errorf("写入自启桌面条目失败: %w", err)
		}
		return true, nil
	}

	if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
		return false, fmt.Errorf("移除自启桌面条目失败: %w", err)
	}
	return false, nil
}
