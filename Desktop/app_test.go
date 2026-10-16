package main

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// mockServiceManager 模拟后台服务管理
type mockServiceManager struct {
	status   *platform.CoreServiceStatus
	startErr error
	stopErr  error
}

func (m *mockServiceManager) GetStatus(ctx context.Context) (*platform.CoreServiceStatus, error) {
	return m.status, nil
}
func (m *mockServiceManager) StartService(ctx context.Context) error {
	return m.startErr
}
func (m *mockServiceManager) StopService(ctx context.Context) error {
	return m.stopErr
}
func (m *mockServiceManager) RestartService(ctx context.Context) error {
	return nil
}
func (m *mockServiceManager) InstallService(ctx context.Context, exePath string) error {
	return nil
}
func (m *mockServiceManager) InstallAndStartService(ctx context.Context, exePath string) error {
	return nil
}
func (m *mockServiceManager) UninstallService(ctx context.Context) error {
	return nil
}
func (m *mockServiceManager) LocateExecutable() (string, error) {
	return "/bin/diting-service", nil
}

// mockAutoStartManager 模拟自启管理
type mockAutoStartManager struct {
	enabled bool
	setErr  error
}

func (m *mockAutoStartManager) IsEnabled() bool {
	return m.enabled
}
func (m *mockAutoStartManager) SetEnabled(enable bool) (bool, error) {
	if m.setErr != nil {
		return false, m.setErr
	}
	m.enabled = enable
	return enable, nil
}

// mockWindowCapturer 模拟截屏
type mockWindowCapturer struct {
	retPath string
	err     error
}

func (m *mockWindowCapturer) CaptureWindow(outputPath string) (string, error) {
	return m.retPath, m.err
}

// mockFirewallManager 模拟防火墙管理
type mockFirewallManager struct {
	err error
}

func (m *mockFirewallManager) CheckPort53(ctx context.Context) (bool, error) {
	return true, nil
}
func (m *mockFirewallManager) ConfigurePort53(ctx context.Context, enable bool) error {
	return m.err
}
func (m *mockFirewallManager) CheckWeb(ctx context.Context) (bool, error) {
	return true, nil
}
func (m *mockFirewallManager) ConfigureWeb(ctx context.Context, port int, enable bool) error {
	return nil
}

// mockStateStore 模拟状态存储
type mockStateStore struct {
	healed bool
	err    error
}

func (m *mockStateStore) Save(state *platform.TakeoverState) error { return nil }
func (m *mockStateStore) Load() (*platform.TakeoverState, error)   { return nil, nil }
func (m *mockStateStore) Clear() error                            { return nil }
func (m *mockStateStore) GetFilePath() string                     { return "" }
func (m *mockStateStore) CheckAndSelfHeal(ctx context.Context, restorer platform.Restorer) (bool, error) {
	return m.healed, m.err
}

type mockDNSManager struct{}

func (m *mockDNSManager) Takeover(ctx context.Context, adapters []platform.AdapterInfo) error {
	return nil
}
func (m *mockDNSManager) TakeoverSingle(ctx context.Context, adapter platform.AdapterInfo) error {
	return nil
}
func (m *mockDNSManager) Restore(ctx context.Context) error { return nil }
func (m *mockDNSManager) RestoreSingle(ctx context.Context, adapterID string) error {
	return nil
}
func (m *mockDNSManager) RestoreAdapters(ctx context.Context, adapters []platform.AdapterState) error {
	return nil
}
func (m *mockDNSManager) ResetResidualLoopbackDNS(ctx context.Context) error { return nil }
func (m *mockDNSManager) IsTakeoverActive() bool                             { return false }
func (m *mockDNSManager) GetTakenOverAdapters() []platform.AdapterState      { return nil }
func (m *mockDNSManager) FlushDNSCache(ctx context.Context) error            { return nil }

func TestAppOperations(t *testing.T) {
	svcMock := &mockServiceManager{
		status: &platform.CoreServiceStatus{
			Installed: true,
			Running:   true,
			State:     "running",
		},
	}
	autoStartMock := &mockAutoStartManager{enabled: false}
	capturerMock := &mockWindowCapturer{retPath: "/tmp/screenshot.png"}
	fwMock := &mockFirewallManager{}
	storeMock := &mockStateStore{healed: true}
	dnsMock := &mockDNSManager{}

	app := &App{
		serviceMgr: svcMock,
		autoStart:  autoStartMock,
		capturer:   capturerMock,
		firewall:   fwMock,
		stateStore: storeMock,
		dnsMgr:     dnsMock,
		version:    "1.3.5",
	}

	app.startup(context.Background())

	// Test Greet
	msg := app.Greet("Tester")
	if !strings.Contains(msg, "Tester") {
		t.Fatalf("Greet 返回不符合预期: %s", msg)
	}

	// Test CaptureWindow
	path, err := app.CaptureWindow("/tmp/test.png")
	if err != nil || path != "/tmp/screenshot.png" {
		t.Fatalf("CaptureWindow 失败: path=%s, err=%v", path, err)
	}

	// Test RunEmergencyRestore
	resMsg, err := app.RunEmergencyRestore()
	if err != nil || !strings.Contains(resMsg, "成功") {
		t.Fatalf("RunEmergencyRestore 失败: msg=%s, err=%v", resMsg, err)
	}

	storeMock.healed = false
	resMsg, err = app.RunEmergencyRestore()
	if err != nil || !strings.Contains(resMsg, "正常") {
		t.Fatalf("RunEmergencyRestore 无需修复提示不符合预期: msg=%s, err=%v", resMsg, err)
	}

	// Test AutoStart
	if app.IsAutoStartEnabled() {
		t.Fatal("预期初始状态为未启用")
	}
	enabled, err := app.SetAutoStart(true)
	if err != nil || !enabled || !app.IsAutoStartEnabled() {
		t.Fatalf("SetAutoStart 启用失败: enabled=%v, err=%v", enabled, err)
	}

	// Test Service Operations
	status, err := app.GetCoreServiceStatus()
	if err != nil || !status.Running {
		t.Fatalf("GetCoreServiceStatus 失败: status=%v, err=%v", status, err)
	}

	startRes, err := app.StartCoreService()
	if err != nil || !strings.Contains(startRes, "成功") {
		t.Fatalf("StartCoreService 失败: %v", err)
	}

	stopRes, err := app.StopCoreService()
	if err != nil || !strings.Contains(stopRes, "已停止") {
		t.Fatalf("StopCoreService 失败: %v", err)
	}

	restartRes, err := app.RestartCoreService()
	if err != nil || !strings.Contains(restartRes, "成功") {
		t.Fatalf("RestartCoreService 失败: %v", err)
	}

	instRes, err := app.InstallCoreService()
	if err != nil || !strings.Contains(instRes, "成功") {
		t.Fatalf("InstallCoreService 失败: %v", err)
	}

	instStartRes, err := app.InstallAndStartCoreService()
	if err != nil || !strings.Contains(instStartRes, "成功") {
		t.Fatalf("InstallAndStartCoreService 失败: %v", err)
	}

	uninstRes, err := app.UninstallCoreService()
	if err != nil || !strings.Contains(uninstRes, "成功") {
		t.Fatalf("UninstallCoreService 失败: %v", err)
	}

	// Test Firewall
	fwRes, err := app.ConfigureFirewallForLAN(true)
	if err != nil || !strings.Contains(fwRes, "放行") {
		t.Fatalf("ConfigureFirewallForLAN(true) 失败: %v", err)
	}
	fwRes, err = app.ConfigureFirewallForLAN(false)
	if err != nil || !strings.Contains(fwRes, "清除") {
		t.Fatalf("ConfigureFirewallForLAN(false) 失败: %v", err)
	}
}

func TestAppErrorHandling(t *testing.T) {
	appEmpty := &App{}

	if _, err := appEmpty.CaptureWindow(""); err == nil {
		t.Fatal("预期未初始化 capturer 时报错")
	}
	if _, err := appEmpty.RunEmergencyRestore(); err == nil {
		t.Fatal("预期未初始化 store 时报错")
	}
	if appEmpty.IsAutoStartEnabled() {
		t.Fatal("未初始化 autoStart 时应返回 false")
	}
	if _, err := appEmpty.SetAutoStart(true); err == nil {
		t.Fatal("未初始化 autoStart 时设置应报错")
	}
	if _, err := appEmpty.GetCoreServiceStatus(); err == nil {
		t.Fatal("未初始化 serviceMgr 时应报错")
	}
	if _, err := appEmpty.ConfigureFirewallForLAN(true); err == nil {
		t.Fatal("未初始化 firewall 时应报错")
	}

	// Test error propagation
	appErr := &App{
		serviceMgr: &mockServiceManager{startErr: errors.New("svc failed")},
		autoStart:  &mockAutoStartManager{setErr: errors.New("reg failed")},
		firewall:   &mockFirewallManager{err: errors.New("fw failed")},
		stateStore: &mockStateStore{err: errors.New("heal failed")},
		dnsMgr:     &mockDNSManager{},
	}

	if _, err := appErr.StartCoreService(); err == nil {
		t.Fatal("预期 StartCoreService 传递错误")
	}
	if _, err := appErr.SetAutoStart(true); err == nil {
		t.Fatal("预期 SetAutoStart 传递错误")
	}
	if _, err := appErr.ConfigureFirewallForLAN(true); err == nil {
		t.Fatal("预期 ConfigureFirewallForLAN 传递错误")
	}
	if _, err := appErr.RunEmergencyRestore(); err == nil {
		t.Fatal("预期 RunEmergencyRestore 传递错误")
	}
}

func TestNewAppConstruction(t *testing.T) {
	app := NewApp()
	if app == nil {
		t.Fatal("NewApp 返回 nil")
	}
	if app.version != Version {
		t.Fatalf("app.version 不匹配: %s != %s", app.version, Version)
	}
}

// mockTrayManager 模拟托盘管理器，记录被触发的窗口操作。
type mockTrayManager struct {
	initialized  bool
	activated    bool
	destroyed    bool
	windowActive bool
	balloonTitle string
	balloonText  string
	callbacks    platform.TrayCallbacks
}

func (m *mockTrayManager) Init(callbacks platform.TrayCallbacks) error {
	m.initialized = true
	m.callbacks = callbacks
	return nil
}

func (m *mockTrayManager) ShowBalloon(title, text string) error {
	m.balloonTitle = title
	m.balloonText = text
	return nil
}

func (m *mockTrayManager) ActivateWindow() {
	m.activated = true
}

func (m *mockTrayManager) IsWindowActive() bool {
	return m.windowActive
}

func (m *mockTrayManager) Destroy() {
	m.destroyed = true
}

// TestAppWindowOperations 验证缺少前端上下文时窗口操作安全无操作。
func TestAppWindowOperations(t *testing.T) {
	app := &App{}

	app.ShowWindow()
	app.HideWindow()
	app.ToggleWindow()
	app.QuitApplication()
}

// TestAppInitTrayCallbacks 验证托盘回调装配正确，且窗口显隐回调可正常转发。
func TestAppInitTrayCallbacks(t *testing.T) {
	trayMock := &mockTrayManager{}
	app := &App{tray: trayMock}

	app.initTray()
	if !trayMock.initialized {
		t.Fatal("initTray 未能初始化托盘")
	}

	cb := trayMock.callbacks
	for name, fn := range map[string]func(){
		"OnShowWindow": cb.OnShowWindow,
		"OnHideWindow": cb.OnHideWindow,
		"OnExit":       cb.OnExit,
	} {
		if fn == nil {
			t.Fatalf("托盘回调 %s 未装配", name)
		}
	}
	if cb.IsAutoStart == nil || cb.GetServiceStatus == nil ||
		cb.OnToggleAutoStart == nil || cb.OnToggleService == nil ||
		cb.OnRestartService == nil {
		t.Fatal("托盘回调存在未装配项")
	}

	// 无前端上下文时触发显隐回调应安全无 panic
	cb.OnShowWindow()
	cb.OnHideWindow()
}

// TestAppTrayWindowToggle 验证 ToggleWindow 依据托盘可见性判定选择显隐。
func TestAppTrayWindowToggle(t *testing.T) {
	trayMock := &mockTrayManager{windowActive: false}
	app := &App{tray: trayMock}

	// 窗口不活跃时 ToggleWindow 应唤醒并置顶
	app.ToggleWindow()
	if !trayMock.activated {
		t.Fatal("窗口不活跃时 ToggleWindow 应触发 ActivateWindow")
	}

	// 窗口活跃时 ToggleWindow 应转为隐藏（不再次激活）
	trayMock.activated = false
	trayMock.windowActive = true
	app.ToggleWindow()
	if trayMock.activated {
		t.Fatal("窗口活跃时 ToggleWindow 不应触发 ActivateWindow")
	}

	// QuitApplication 应释放托盘
	app.QuitApplication()
	if !trayMock.destroyed {
		t.Fatal("QuitApplication 未能销毁托盘")
	}
}

// TestAppInitTrayNilSafe 验证未注入托盘时 initTray 安全返回。
func TestAppInitTrayNilSafe(t *testing.T) {
	app := &App{}
	app.initTray()
}
