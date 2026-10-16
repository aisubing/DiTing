package main

import (
	"context"
	"fmt"
	"runtime"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
	wailsruntime "github.com/wailsapp/wails/v2/pkg/runtime"
)

// App 结构体，提供供前端 Wails 绑定的跨平台桌面应用核心能力。
//
// 架构设计：App 仅依赖 platform 跨平台抽象接口，由平台工厂注入具体的 Windows / Linux 实现，
// 从而消除桌面层与特定操作系统原生 API（注册表、Win32、systemd）的直接耦合。
type App struct {
	ctx         context.Context
	serviceMgr  platform.ServiceManager
	autoStart   platform.AutoStartManager
	capturer    platform.WindowCapturer
	aspectRatio platform.AspectRatioManager
	firewall    platform.FirewallManager
	dnsMgr      platform.DNSManager
	stateStore  platform.StateStore
	version     string
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// Greet 测试方法
func (a *App) Greet(name string) string {
	return fmt.Sprintf("Hello %s, 来自谛听 (DITING) 桌面控制台!", name)
}

// GetPlatform 返回当前桌面客户端运行的操作系统标识（如 windows / linux），
// 供前端做平台自适应 UI 显示。
func (a *App) GetPlatform() string {
	return runtime.GOOS
}

// CaptureWindow 截取当前客户端自身窗口界面并保存为 PNG 图像文件
func (a *App) CaptureWindow(outputPath string) (string, error) {
	if a.capturer == nil {
		return "", fmt.Errorf("当前平台未初始化窗口截屏能力")
	}
	return a.capturer.CaptureWindow(outputPath)
}

// RunEmergencyRestore 执行离线应急恢复
func (a *App) RunEmergencyRestore() (string, error) {
	if a.stateStore == nil || a.dnsMgr == nil {
		return "", fmt.Errorf("系统状态存储或 DNS 管理器未就绪")
	}
	healed, err := a.stateStore.CheckAndSelfHeal(context.Background(), a.dnsMgr)
	if err != nil {
		return "", fmt.Errorf("应急恢复失败: %w", err)
	}
	if healed {
		return "已成功恢复网络 DNS 设置！", nil
	}
	return "网络 DNS 状态正常，无需修复。", nil
}

// IsAutoStartEnabled 获取当前是否已开启开机自启
func (a *App) IsAutoStartEnabled() bool {
	if a.autoStart == nil {
		return false
	}
	return a.autoStart.IsEnabled()
}

func (a *App) hasFrontendContext() bool {
	return a.ctx != nil && a.ctx.Value("frontend") != nil
}

// SetAutoStart 设置或取消开机自启
func (a *App) SetAutoStart(enable bool) (bool, error) {
	if a.autoStart == nil {
		return false, fmt.Errorf("当前平台不支持开机自启配置")
	}
	result, err := a.autoStart.SetEnabled(enable)
	if err == nil && a.hasFrontendContext() {
		wailsruntime.EventsEmit(a.ctx, "autostart-changed", result)
	}
	return result, err
}

// GetCoreServiceStatus 获取后台核心服务状态
func (a *App) GetCoreServiceStatus() (*platform.CoreServiceStatus, error) {
	if a.serviceMgr == nil {
		return nil, fmt.Errorf("后台服务管理器未就绪")
	}
	return a.serviceMgr.GetStatus(context.Background())
}

// StartCoreService 按需启动后台核心服务
func (a *App) StartCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.StartService(context.Background()); err != nil {
		return "", err
	}
	return "后台核心服务已成功启动！", nil
}

// StopCoreService 按需停止后台核心服务
func (a *App) StopCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.StopService(context.Background()); err != nil {
		return "", err
	}
	return "后台核心服务已停止。", nil
}

// RestartCoreService 按需重启后台核心服务
func (a *App) RestartCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.RestartService(context.Background()); err != nil {
		return "", err
	}
	return "后台核心服务已成功重启！", nil
}

// InstallCoreService 按需安装注册后台核心服务
func (a *App) InstallCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.InstallService(context.Background(), ""); err != nil {
		return "", err
	}
	return "后台核心服务已成功安装注册为系统服务！", nil
}

// InstallAndStartCoreService 按需一键安装并启动后台核心服务
func (a *App) InstallAndStartCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.InstallAndStartService(context.Background(), ""); err != nil {
		return "", err
	}
	return "后台核心服务已成功安装并启动！", nil
}

// UninstallCoreService 按需卸载注销后台核心服务
func (a *App) UninstallCoreService() (string, error) {
	if a.serviceMgr == nil {
		return "", fmt.Errorf("后台服务管理器未就绪")
	}
	if err := a.serviceMgr.UninstallService(context.Background()); err != nil {
		return "", err
	}
	return "后台核心服务已成功卸载。", nil
}

// ConfigureFirewallForLAN 按需配置局域网 53 端口防火墙规则
func (a *App) ConfigureFirewallForLAN(enable bool) (string, error) {
	if a.firewall == nil {
		return "", fmt.Errorf("当前平台未初始化防火墙管理")
	}
	err := a.firewall.ConfigurePort53(context.Background(), enable)
	if err != nil {
		return "", fmt.Errorf("配置防火墙规则失败: %w", err)
	}
	if enable {
		return "已成功放行局域网 53 端口防火墙入站规则！", nil
	}
	return "已成功清除局域网 53 端口防火墙入站规则。", nil
}

// ShowWindow 显示并置顶主窗口
func (a *App) ShowWindow() {
	if a.hasFrontendContext() {
		wailsruntime.WindowShow(a.ctx)
		wailsruntime.WindowUnminimise(a.ctx)
	}
}

// HideWindow 隐藏主窗口
func (a *App) HideWindow() {
	if a.hasFrontendContext() {
		wailsruntime.WindowHide(a.ctx)
	}
}

// ToggleWindow 切换主窗口显示与隐藏。
//
// 无托盘常驻形态下，隐藏的窗口只能通过显示唤回，故此处语义为唤醒并置顶。
func (a *App) ToggleWindow() {
	a.ShowWindow()
}

// QuitApplication 安全退出应用
func (a *App) QuitApplication() {
	if a.hasFrontendContext() {
		wailsruntime.Quit(a.ctx)
	}
}
