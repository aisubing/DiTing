//go:build windows

package main

import (
	"context"
	"fmt"
	"os"

	"github.com/haoze-evolluling/diting/desktop/frontend"
	"github.com/haoze-evolluling/diting/desktop/internal/platform"
	"github.com/haoze-evolluling/diting/desktop/internal/platform/windows"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

// NewApp 为 Windows 平台构造带有完整原生实现的 App 实例。
func NewApp() *App {
	exec := platform.NewDefaultExecutor()
	store := platform.NewFileStateStore("")
	dnsMgr := windows.NewDNSManager(exec, store, Version)
	serviceMgr := windows.NewServiceManager(exec, nil)
	autoStart := windows.NewAutoStartManager()
	capturer := windows.NewWindowCapturer()
	aspectRatio := windows.NewAspectRatioManager()
	firewall := windows.NewFirewallManager(exec)
	trayMgr := windows.NewTrayManager()

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

// runGUI 启动 Windows 平台 Wails GUI 窗口应用。
func runGUI(app *App, startMinimized bool) {
	err := wails.Run(&options.App{
		Title:             "谛听 (DITING) DNS 控制台",
		Width:             1280,
		Height:            720,
		MinWidth:          1280,
		MinHeight:         720,
		StartHidden:       startMinimized,
		HideWindowOnClose: true,
		SingleInstanceLock: &options.SingleInstanceLock{
			UniqueId: "diting-dns-gui-single-instance-lock",
			OnSecondInstanceLaunch: func(secondInstanceData options.SecondInstanceData) {
				if app != nil {
					app.ShowWindow()
				}
			},
		},
		AssetServer: &assetserver.Options{
			Assets: frontend.Assets,
		},
		BackgroundColour: &options.RGBA{R: 17, G: 20, B: 24, A: 1},
		OnStartup: func(ctx context.Context) {
			app.startup(ctx)
			go func() {
				if app.tray != nil {
					_ = app.tray.Init(platform.TrayCallbacks{
						OnToggleWindow: func() {
							app.ToggleWindow()
						},
						OnShowWindow: func() {
							app.ShowWindow()
						},
						OnToggleAutoStart: func() bool {
							current := app.IsAutoStartEnabled()
							newVal, _ := app.SetAutoStart(!current)
							return newVal
						},
						IsAutoStart: func() bool {
							return app.IsAutoStartEnabled()
						},
						GetServiceStatus: func() (bool, error) {
							st, err := app.GetCoreServiceStatus()
							if err != nil {
								return false, err
							}
							return st.Running, nil
						},
						OnToggleService: func() error {
							st, err := app.GetCoreServiceStatus()
							if err != nil {
								return err
							}
							if st.Running {
								_, err = app.StopCoreService()
							} else {
								_, err = app.StartCoreService()
							}
							return err
						},
						OnRestartService: func() error {
							_, err := app.RestartCoreService()
							return err
						},
						OnExit: func() {
							app.QuitApplication()
						},
					})
				}
			}()
		},
		OnDomReady: func(ctx context.Context) {
			go func() {
				windows.LockWindowAspectRatio(windows.DefaultWindowTitle, 16.0/9.0)
			}()
		},
		OnShutdown: func(ctx context.Context) {
			if app.tray != nil {
				app.tray.Destroy()
			}
		},
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "运行 GUI 失败: %v\n", err)
		os.Exit(1)
	}
}
