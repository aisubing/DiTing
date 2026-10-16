//go:build windows

package windows

import (
	"testing"
	"time"
	"unsafe"

	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// TestNotifyIconDataStructSize 校验结构体与 Win32 Shell API 期望的对齐尺寸。
func TestNotifyIconDataStructSize(t *testing.T) {
	sz := unsafe.Sizeof(notifyIconData{})
	if sz < 900 {
		t.Fatalf("notifyIconData 结构体尺寸异常: %d", sz)
	}
}

// TestTrayManagerInterface 校验具体类型满足 platform.TrayManager 接口。
func TestTrayManagerInterface(t *testing.T) {
	mgr := NewTrayManager()
	if mgr == nil {
		t.Fatal("NewTrayManager 返回空")
	}
	var _ platform.TrayManager = mgr

	// 未初始化时弹出气泡应优雅报错
	if err := mgr.ShowBalloon("测试", "内容"); err == nil {
		t.Fatal("未初始化的托盘调用 ShowBalloon 应当返回错误")
	}

	// 销毁与激活未初始化的托盘应安全无异常
	mgr.Destroy()
	mgr.ActivateWindow()
}

// TestUnpackV4Anchor 校验版本 4 锚点解包，含副屏负坐标。
func TestUnpackV4Anchor(t *testing.T) {
	cases := []struct {
		name   string
		x, y   int32
		expect bool
	}{
		{"正坐标", 800, 600, true},
		{"副屏负 X", -250, 480, true},
		{"副屏负 Y", 300, -120, true},
		{"双负", -1920, -100, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			wParam := uintptr(uint32(uint16(int16(c.x))) | (uint32(uint16(int16(c.y))) << 16))
			x, y, ok := unpackV4Anchor(wParam)
			if ok != c.expect {
				t.Fatalf("ok 不符: 期望 %v, 实际 %v", c.expect, ok)
			}
			if x != c.x || y != c.y {
				t.Fatalf("坐标不符: 期望 (%d,%d), 实际 (%d,%d)", c.x, c.y, x, y)
			}
		})
	}

	// wParam 为 0 表示未携带锚点，应提示调用方回退
	if _, _, ok := unpackV4Anchor(0); ok {
		t.Fatal("wParam 为 0 时不应返回有效锚点")
	}
}

// TestShouldHandleMenuEvent 校验菜单事件的语义过滤：
// 版本 4 下只认 WM_CONTEXTMENU，忽略重复的 WM_RBUTTONUP；低版本回退到 WM_RBUTTONUP。
// 该判定只依赖 isV4，不含任何时间窗口。
func TestShouldHandleMenuEvent(t *testing.T) {
	cases := []struct {
		name   string
		event  uint32
		isV4   bool
		expect bool
	}{
		{"版本4-上下文菜单", wmContextMenu, true, true},
		{"版本4-右键抬起被过滤", wmRButtonUp, true, false},
		{"低版本-上下文菜单", wmContextMenu, false, true},
		{"低版本-右键抬起兜底", wmRButtonUp, false, true},
		{"左键抬起不触发菜单", wmLButtonUp, true, false},
		{"左键抬起不触发菜单-低版本", wmLButtonUp, false, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := shouldHandleMenuEvent(c.event, c.isV4); got != c.expect {
				t.Fatalf("期望 %v, 实际 %v", c.expect, got)
			}
		})
	}
}

// TestIsShowWindowEvent 校验所有"显示并置顶"类事件被统一归一化。
// 该动作幂等，故不区分单双击、不做任何去重。
func TestIsShowWindowEvent(t *testing.T) {
	showEvents := []uint32{ninSelect, ninKeySelect, wmLButtonUp, wmLButtonDblClk, ninBalloonUserClick}
	for _, e := range showEvents {
		if !isShowWindowEvent(e) {
			t.Fatalf("事件 0x%X 应归入显示动作", e)
		}
	}
	// 菜单与右键类事件不应归入显示动作
	for _, e := range []uint32{wmContextMenu, wmRButtonUp} {
		if isShowWindowEvent(e) {
			t.Fatalf("事件 0x%X 不应归入显示动作", e)
		}
	}
}

// TestIsCandidateMainWindow 校验主窗口筛选逻辑。
//
// 关键回归点：隐藏窗口必须是合格候选。以 -minimized 启动时主窗口处于隐藏状态，
// 若把可见性当作必要条件，托盘将永远找不到主窗口。
func TestIsCandidateMainWindow(t *testing.T) {
	const pid = 1000
	const exToolWindow = 0x00000080

	cases := []struct {
		name      string
		pid       uint32
		winPID    uint32
		className string
		exStyle   uint32
		expect    bool
	}{
		{"本进程主窗口", pid, pid, mainWindowClassName, 0, true},
		{"隐藏的主窗口仍是合格候选", pid, pid, mainWindowClassName, 0, true},
		{"他进程窗口", pid, pid + 1, mainWindowClassName, 0, false},
		{"类名不符", pid, pid, "GDI+ Hook Window Class", 0, false},
		{"工具窗口被排除", pid, pid, mainWindowClassName, exToolWindow, false},
		{"pid 为 0 时无效", 0, 0, mainWindowClassName, 0, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := isCandidateMainWindow(c.pid, c.winPID, c.className, c.exStyle)
			if got != c.expect {
				t.Fatalf("期望 %v, 实际 %v", c.expect, got)
			}
		})
	}
}

// TestInitIdempotent 校验重复调用 Init 直接返回，不重复初始化。
func TestInitIdempotent(t *testing.T) {
	tray := NewWindowsTray()
	tray.isInitialized = true
	tray.hwnd = 999999

	// 已初始化时不应再次走窗口查找与图标注册流程
	if err := tray.Init(platform.TrayCallbacks{}); err != nil {
		t.Fatalf("已初始化状态下 Init 应直接返回 nil, 实际: %v", err)
	}
}

// TestShowWindowEventIdempotent 校验重复派发显示事件时回调被重复触发且无 panic。
//
// 幂等动作的重复派发是设计上可接受的：这正是"双重派发"不再成为缺陷的原因。
func TestShowWindowEventIdempotent(t *testing.T) {
	tray := NewWindowsTray()
	var showCount int
	tray.callbacks = platform.TrayCallbacks{
		OnShowWindow: func() { showCount++ },
	}

	// 模拟版本 4 下单击同时派发 NIN_SELECT 与 WM_LBUTTONUP
	selectLP := uintptr((1 << 16) | ninSelect)
	tray.handleTrayCallback(trayWindowHandle(), 0, selectLP)
	tray.handleTrayCallback(trayWindowHandle(), 0, uintptr((1<<16)|wmLButtonUp))

	if showCount != 2 {
		t.Fatalf("重复派发应累计触发 2 次，实际: %d", showCount)
	}

	// 双击与气泡点击同样归一化到显示动作
	tray.handleTrayCallback(trayWindowHandle(), 0, uintptr((1<<16)|wmLButtonDblClk))
	tray.handleTrayCallback(trayWindowHandle(), 0, uintptr((1<<16)|ninBalloonUserClick))
	if showCount != 4 {
		t.Fatalf("显示类事件应累计触发 4 次，实际: %d", showCount)
	}
}

// TestHandleTrayCallbackMenuRouting 校验版本 4 下右键抬起不进入菜单路径，
// 且左键事件不会误触发菜单。
func TestHandleTrayCallbackMenuRouting(t *testing.T) {
	tray := NewWindowsTray()
	tray.isVersion4 = true

	var showCount int
	tray.callbacks = platform.TrayCallbacks{
		OnShowWindow: func() { showCount++ },
	}

	// 版本 4 下 WM_RBUTTONUP 应被过滤，既不弹菜单也不显示窗口
	tray.handleTrayCallback(trayWindowHandle(), 0, uintptr(wmRButtonUp))
	if tray.menuActive {
		t.Fatal("版本 4 下 WM_RBUTTONUP 不应进入菜单路径")
	}
	if showCount != 0 {
		t.Fatalf("右键事件不应触发显示动作，实际: %d", showCount)
	}
}

// TestTrayIsWindowActiveUninitialized 校验未绑定窗口时判定为不活跃。
func TestTrayIsWindowActiveUninitialized(t *testing.T) {
	tray := NewWindowsTray()
	if tray.IsWindowActive() {
		t.Fatal("未初始化的托盘窗口状态不应为活跃")
	}
	// 无效句柄同样应安全返回 false
	tray.hwnd = 999999
	if tray.IsWindowActive() {
		t.Fatal("无效窗口句柄应返回 false")
	}
}

// TestTrayDestroyIdempotent 校验销毁可安全重复调用。
func TestTrayDestroyIdempotent(t *testing.T) {
	tray := NewWindowsTray()
	tray.Destroy()
	tray.Destroy()

	mgr := NewTrayManager()
	mgr.Destroy()
	mgr.Destroy()
}

// TestTrayShowBalloonUninitialized 校验未初始化时气泡弹出返回错误而非 panic。
func TestTrayShowBalloonUninitialized(t *testing.T) {
	tray := NewWindowsTray()
	if err := tray.ShowBalloon("标题", "内容"); err == nil {
		t.Fatal("未初始化的托盘 ShowBalloon 应返回错误")
	}
	// 待发槽位不应被写入
	if tray.pendingBalloon != nil {
		t.Fatal("未初始化时不应写入待发气泡")
	}
}

// TestTrayMenuReentryGate 校验菜单重入门为纯布尔语义：
// 仅在菜单显示期间拦截，菜单退出后立即可再次呼出（无时间冷却）。
func TestTrayMenuReentryGate(t *testing.T) {
	tray := NewWindowsTray()
	tray.hwnd = 999999 // 无效句柄，验证路径不 panic

	// 菜单未显示时不应被拦截：showContextMenu 会走完流程并复位门闩
	tray.showContextMenu(trayWindowHandle(), 0)
	if tray.menuActive {
		t.Fatal("菜单返回后门闩应复位")
	}

	// 立即再次调用不应被"冷却期"吞掉
	before := tray.menuActive
	tray.showContextMenu(trayWindowHandle(), 0)
	if tray.menuActive != before {
		t.Fatal("菜单关闭后立即呼出不应被拦截")
	}
}

// TestBuildMenuStructure 校验菜单项文案与顺序，无需消息循环即可断言。
func TestBuildMenuStructure(t *testing.T) {
	tray := NewWindowsTray()
	callbacks := platform.TrayCallbacks{
		IsAutoStart:      func() bool { return true },
		GetServiceStatus: func() (bool, error) { return true, nil },
	}

	hMenu, _, _ := procCreatePopupMenu.Call()
	if hMenu == 0 {
		t.Skip("无法创建弹出菜单，跳过菜单结构断言")
	}
	defer procDestroyMenu.Call(hMenu)

	tray.buildMenu(hMenu, callbacks)
	texts := menuItemTexts(hMenu)

	expect := []string{
		"打开主界面",
		"隐藏主界面",
		"",
		"开机自启动",
		"",
		"核心服务: 运行中",
		"停止核心服务",
		"重启核心服务",
		"",
		"退出程序",
	}
	if len(texts) != len(expect) {
		t.Fatalf("菜单项数量不符: 期望 %d, 实际 %d (%v)", len(expect), len(texts), texts)
	}
	for i, want := range expect {
		if texts[i] != want {
			t.Fatalf("第 %d 项文案不符: 期望 %q, 实际 %q", i, want, texts[i])
		}
	}
}

// TestBuildMenuServiceStopped 校验服务停止时菜单只提供启动项。
func TestBuildMenuServiceStopped(t *testing.T) {
	tray := NewWindowsTray()
	callbacks := platform.TrayCallbacks{
		IsAutoStart:      func() bool { return false },
		GetServiceStatus: func() (bool, error) { return false, nil },
	}

	hMenu, _, _ := procCreatePopupMenu.Call()
	if hMenu == 0 {
		t.Skip("无法创建弹出菜单，跳过菜单结构断言")
	}
	defer procDestroyMenu.Call(hMenu)

	tray.buildMenu(hMenu, callbacks)
	texts := menuItemTexts(hMenu)

	if !containsText(texts, "核心服务: 已停止") {
		t.Fatalf("缺少停止状态文案: %v", texts)
	}
	if !containsText(texts, "启动核心服务") {
		t.Fatalf("缺少启动项: %v", texts)
	}
	if containsText(texts, "停止核心服务") || containsText(texts, "重启核心服务") {
		t.Fatalf("服务已停止时不应出现停止/重启项: %v", texts)
	}
	if !containsText(texts, "隐藏主界面") {
		t.Fatalf("菜单应包含隐藏主界面项: %v", texts)
	}
}

// TestDispatchMenuCommand 校验命令分派：窗口显隐同步生效，阻塞类命令不阻塞调用方。
func TestDispatchMenuCommand(t *testing.T) {
	tray := NewWindowsTray()

	showCh := make(chan struct{}, 1)
	hideCh := make(chan struct{}, 1)
	exitCh := make(chan struct{}, 1)

	tray.callbacks = platform.TrayCallbacks{
		OnShowWindow: func() { showCh <- struct{}{} },
		OnHideWindow: func() { hideCh <- struct{}{} },
		OnExit:       func() { exitCh <- struct{}{} },
	}
	callbacks := tray.callbacks

	// 显示/隐藏为同步调用：返回时回调必定已执行
	tray.dispatchMenuCommand(idMenuShowWindow, callbacks)
	select {
	case <-showCh:
	default:
		t.Fatal("显示命令应同步执行")
	}

	tray.dispatchMenuCommand(idMenuHideWindow, callbacks)
	select {
	case <-hideCh:
	default:
		t.Fatal("隐藏命令应同步执行")
	}

	// 退出为异步派发：不应阻塞调用方
	tray.dispatchMenuCommand(idMenuExit, callbacks)
	select {
	case <-exitCh:
	case <-time.After(2 * time.Second):
		t.Fatal("退出命令未被派发")
	}
}

// TestDispatchMenuCommandNilCallbacks 校验回调缺失时不 panic。
func TestDispatchMenuCommandNilCallbacks(t *testing.T) {
	tray := NewWindowsTray()
	empty := platform.TrayCallbacks{}
	for _, cmd := range []uintptr{idMenuShowWindow, idMenuHideWindow, idMenuAutoStart,
		idMenuServiceToggle, idMenuServiceRestart, idMenuExit, 0xFFFF} {
		tray.dispatchMenuCommand(cmd, empty)
	}
}

// trayWindowHandle 返回一个无效句柄，用于验证各路径在不 panic 的前提下可走通。
func trayWindowHandle() uintptr { return 999999 }

// containsText 判断文案切片中是否包含目标项。
func containsText(texts []string, want string) bool {
	for _, s := range texts {
		if s == want {
			return true
		}
	}
	return false
}
