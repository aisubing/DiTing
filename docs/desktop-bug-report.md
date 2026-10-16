# 桌面端 Bug 报告 (desktop-bug-report)

> 本文档由自动化代码扫描持续追加，仅记录**可验证**的问题，不改动任何代码。
> 每条含：编号 / 模块 / 严重级别 / 代码位置 / 现象 / 根因 / 验证方法。
> 扫描范围：`Desktop/` 下 Go 桌面端与服务端代码、`frontend/src` 前端代码。

---

## 第 1 轮（2026-10-17）— 已扫描模块

已扫描：`app.go`、`main.go`、`platform_windows.go`、`internal/ipc/{server,server_ws,server_static,server_web,server_bg,server_mobileconfig,cors,routes}.go`、`internal/auth/auth.go`、`internal/config/{config,store}.go`、`cmd/service/{main,cli,controller_web,controller_dns,controller_pipeline,controller_metrics,controller_security}.go`、`internal/platform/windows/{tray,tray_wndproc,tray_menu,tray_helpers,tray_defs,autostart,aspect_ratio}.go`、`frontend/src/{App.vue,api/http.ts,api/ws.ts,composables/usePoller.ts}`。

### BUG-1 · IPC 鉴权 · 高 · 本机任意进程/Web 页面可绕过鉴权并获得完全管理权限
- **位置**：[internal/ipc/server.go:127-155](Desktop/internal/ipc/server.go#L127)、[internal/ipc/server.go:141](Desktop/internal/ipc/server.go#L141)、[internal/ipc/cors.go:14-25](Desktop/internal/ipc/cors.go#L14)
- **现象**：默认配置下（`cfg.IPC.AuthToken == ""`，见 [internal/config/config.go:252-255](Desktop/internal/config/config.go#L252) 且 `cmd/service/cli.go` 安装服务时从不生成 token），`verifyToken` 第 3 分支 `s.token == "" && isLoopbackRequest(r)` 对**任何源地址为 127.0.0.1/[::1] 的请求直接放行**。攻击者无需任何凭据即可调用改密码、关过滤、启停服务、接管网卡等全部 `/api/v1/*` 写接口。
- **根因**：回环免鉴权的设计前提「只有本机受信进程会连 loopback」不成立——本机浏览器访问 `http://127.0.0.1:15353/...` 时 RemoteAddr 同样是回环。叠加 `cors.go` 把 `Access-Control-Allow-Origin` 反射为请求 Origin 并置 `Allow-Credentials: true`，任意恶意网页可从浏览器跨域读写该管理 API（`/api/v1/auth/password` 走 loopback 时 `bypassOldAuth=true`，可直接改写管理员密码）。
- **验证方法**：本机起服务后，从一个非 `evil` 域页面的脚本 `fetch('http://127.0.0.1:15353/api/v1/status')`；或 `curl`（不带任何 Authorization）从 127.0.0.1 调用 `/api/v1/dns/stop`，预期均返回成功而非 401。可编写 Go 测试：`NewServer("127.0.0.1:0", "", ctrl)`，对 `httptest.NewRequest`（RemoteAddr 设为 `127.0.0.1:1`）断言 `verifyToken` 恒 true。

### BUG-2 · IPC WebSocket · 中 · 回环免鉴权导致本机任意进程实时窃取全部 DNS 查询日志
- **位置**：[internal/ipc/server_ws.go:83-88](Desktop/internal/ipc/server_ws.go#L83)、[internal/ipc/routes.go:96](Desktop/internal/ipc/routes.go#L96)、[frontend/src/api/ws.ts:34-37](Desktop/frontend/src/api/ws.ts#L34)
- **现象**：`/api/v1/events` 用 `verifyToken(r)` 自行鉴权；因 BUG-1 的空 token + loopback 放行，本机任意进程（含浏览器 `new WebSocket('ws://127.0.0.1:15353/api/v1/events')`）无需凭据即可订阅，实时接收 `runMetricsTicker` 每 3s 的 metrics 广播与热路径逐条 `query` 事件（含被解析域名、客户端 IP、命中规则）。
- **根因**：同 BUG-1；WebSocket 握手不受浏览器 CORS 约束，连反射 Origin 都不需要，只要 loopback + 空 token 即订阅成功。这是隐私泄露面（用户访问域名清单被本地恶意程序实时读取）。
- **验证方法**：本机执行 `wscat -c ws://127.0.0.1:15353/api/v1/events`（不带 token），持续发起 DNS 查询，观察是否收到 `type:"query"` 事件。

### BUG-3 · 服务生命周期 · 中 · `p.ipcServer` 存在未加锁的数据竞争
- **位置**：[cmd/service/controller_web.go:130](Desktop/cmd/service/controller_web.go#L130)（写，持 `p.mu`）、[cmd/service/main.go:255](Desktop/cmd/service/main.go#L255)（读，无锁）、[cmd/service/controller_metrics.go:128](Desktop/cmd/service/controller_metrics.go#L128)（读，无锁，DNS 热路径）、[cmd/service/main.go:290](Desktop/cmd/service/main.go#L290)（读，无锁）
- **现象**：`ConfigureWeb` 在 goroutine 中以 `p.mu.Lock()` 重写 `p.ipcServer`；而 `runMetricsTicker`、`Stop()`、指标中间件回调在无锁情况下读取同一字段。并发触发 `go test -race` 会报 data race；实运行中在「切换 Web 局域网开关触发平滑重启」与「定时广播/停机」同时发生时，可能读到半更新的指针或与旧 server 的 Shutdown 交叉。
- **根因**：`p.ipcServer` 的可变性（Web 重启会整体替换实例）与多处读取未统一经 `p.mu` 保护相矛盾；controller_schedule.go:90 用「先加锁取局部变量再解锁」的正确姿势，其余调用点未跟进。
- **验证方法**：`cd Desktop && go test -race ./cmd/service/...`，或在测试中并发调用 `ConfigureWeb` 与 `runMetricsTicker`，Go race detector 会报 `DATA RACE`。

### BUG-4 · 平台/Windows · 中 · 16:9 窗口比例锁定实际从未生效（调用已知恒失败的 SetWindowSubclass）
- **位置**：[internal/platform/windows/aspect_ratio.go:139-146](Desktop/internal/platform/windows/aspect_ratio.go#L139)、调用点 [platform_windows.go:69-71](Desktop/platform_windows.go#L69)
- **现象**：`OnDomReady` 起协程调用 `LockWindowAspectRatio(...)`，内部用 `procSetWindowSubclass.Call(...)` 并 `return ret != 0`。仓库自身经验（AGENT_MISTAKES.md 2026-10-16「SetWindowSubclass 静默失败」）已实测 `SetWindowSubclass` 在本进程 Wails 窗口上**恒返回 FALSE**，因此该比例锁定从未安装成功，返回值 `false` 又被调用方 goroutine 直接丢弃，无任何告警。窗口可被任意拉成非 16:9。
- **根因**：托盘已改用 `SetWindowLongPtr(GWLP_WNDPROC)+CallWindowProcW` 链式转发解决同类问题，但 `aspect_ratio.go` 的相同缺陷未一并修复，且调用点忽略返回值导致静默失效。
- **验证方法**：运行 GUI，尝试将窗口拉成接近正方形；若可维持非 16:9 则锁定未生效。或加临时日志打印 `LockWindowAspectRatio` 返回值（预期恒为 false）。

---

## 待复核 / 观察点（尚不确定，暂不计为 Bug）

- `internal/ipc/server_ws.go:39-81` runHub 慢客户端关闭路径：close(send) 均在 `mu.Lock` 下、broadcast 在 `mu.RLock` 下，互斥保证不会向已关闭 channel 发送。当前判定为安全，若后续引入 writePump 自注销需复核。
- `internal/ipc/cors.go` 反射任意 Origin + `Allow-Credentials: true`：是否应改为仅白名单 `wails://*` / `http(s)://<本机>` 待定，属加固建议而非独立缺陷。
