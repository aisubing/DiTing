//go:build linux

package main

import (
	"github.com/haoze-evolluling/diting/desktop/internal/platform"
	"github.com/haoze-evolluling/diting/desktop/internal/platform/linux"
)

// NewApp 为 Linux 平台构造带有系统实现与存根的 App 实例。
func NewApp() *App {
	exec := platform.NewDefaultExecutor()
	// 与服务端同源解析状态文件路径（见 platform.ResolveStateFilePath）。
	store := platform.NewFileStateStore(platform.ResolveStateFilePath("", ""))
	dnsMgr := linux.NewDNSManager(exec, store, Version)
	serviceMgr := linux.NewServiceManager(exec, nil)
	autoStart := linux.NewAutoStartManager()
	capturer := linux.NewWindowCapturer()
	aspectRatio := linux.NewAspectRatioManager()
	firewall := linux.NewFirewallManager(exec)
	trayMgr := linux.NewTrayManager()

	return &App{
		serviceMgr:  serviceMgr,
		autoStart:   autoStart,
		capturer:    capturer,
		aspectRatio: aspectRatio,
		firewall:    firewall,
		dnsMgr:      dnsMgr,
		stateStore:  store,
		tray:        trayMgr,
		version:     Version,
	}
}
