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

## 第 2 轮（2026-10-17）— 已扫描模块

已扫描：`internal/querylog/*`（全部非测试文件）、`internal/dns/{server,server_dot,dot_conn,cache_middleware,server_doh,server_doq}.go`、`internal/platform/windows/{takeover,dns_native,restore_script,firewall,service_mgr}.go`、`internal/core/cache_flight.go`、`cmd/service/{cli,controller_querylog,controller_service}.go`、`frontend/src/{composables/{useConfirmModal,useToast,useServiceControl},api/{http,web,native,encrypted,filter},components/ConfirmModal.vue,components/AppModal.vue,components/encrypted/MobileConfigCard.vue}`。

### BUG-5 · 查询日志 · 高 · Search 双重应用 offset，翻页永远丢半页且翻不到底
- **位置**：[internal/querylog/querylog.go:113](Desktop/internal/querylog/querylog.go#L113) + [internal/querylog/ring.go:125-127](Desktop/internal/querylog/ring.go#L125) + [internal/querylog/querylog.go:125-133](Desktop/internal/querylog/querylog.go#L125)
- **现象**：`ring.search` 内部已按 `Offset` 跳过条目（`if total <= q.Offset { continue }`），`QueryLog.Search` 又把（已含文件补齐的）结果整体再截 `[Offset : Offset+Limit]`。内存 10 条、`limit=3 offset=5` 时正确应返回第 6–8 条共 3 条，实测返回 **0 条**。前端 [QueryHistoryPanel.vue:87](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L87) 以 `page*50` 传 offset，第 2 页起每页实际跳过 2×offset，UI 显示「共 N 条 / 第 x/y 页」但点下一页迅速空页。
- **根因**：两段分页语义叠加。`ring.search` 返回的 `matched` 已是「跳过 offset 后的第一页」，外层 `combined[start:end]` 再次偏移；文件检索 `searchFiles` 的 `need = Offset+Limit` 同样把双重偏移传染给文件补齐数量。
- **验证方法**：已实证。临时测试（验证后已删除）：`New`（纯内存）记录 10 条 → `Search({Limit:3, Offset:5, IncludeFile:false})` → `len(Entries)==0`（期望 3）。可固化为 `internal/querylog` 回归测试。

### BUG-6 · 加密 DNS/DoT · 高 · ReloadEncrypted 后旧 acceptLoop 永久泄漏（协程+唤醒循环不退出）
- **位置**：[internal/dns/server_dot.go:94-108](Desktop/internal/dns/server_dot.go#L94)（acceptLoop 只看 `d.srv.serving()`）、[internal/dns/server_dot.go:172-176](Desktop/internal/dns/server_dot.go#L172)（close 置 `d.stop=true`）、[internal/dns/server.go:68-90](Desktop/internal/dns/server.go#L68)（ReloadEncrypted 关旧监听器但不改 started/closed）
- **现象**：热重载加密配置（启用/改端口/换证书）时旧 `dotListener.close()` 关闭监听器并置 `d.stop=true`，但 `acceptLoop` **从不读取 `d.stop`**，只判断进程级的 `serving()`（仍为 true）。此后 `Accept()` 每轮立即返回 "use of closed network connection"，走 `time.Sleep(50ms); continue` 分支永久循环。该协程不在 `d.wg` 中，`close()` 的 `wg.Wait()` 也收不掉它。每次 DoT 热重载泄漏一个 20 次/秒唤醒的僵尸协程，长期运行（证书到期自动重载等场景）累积明显。
- **根因**：与 DoQ 对照即见疏漏——[server_doq.go] 的循环显式 `errors.Is(err, quic.ErrServerClosed)` 退出；DoT 的 `stop` 字段定义了却没有任何读取方在 accept 路径使用。
- **验证方法**：包内测试：构造 `serving()==true` 的 Server，绑定 `127.0.0.1:0` 后 `go dl.acceptLoop(...)`，`dl.ln.Close()`，断言 500ms 内协程退出——现状不退出；`runtime.NumGoroutine()` 前后对比恒定多 1。

### BUG-7 · 加密 DNS · 高 · ReloadEncrypted 解锁后写 s.dot/s.doh/s.doq 与持锁读者构成数据竞争
- **位置**：[internal/dns/server.go:68-77](Desktop/internal/dns/server.go#L68)（解锁后于 93-114 调用 start*）、[internal/dns/server_dot.go:80](Desktop/internal/dns/server_dot.go#L80)、[internal/dns/server_doh.go:138](Desktop/internal/dns/server_doh.go#L138)、[internal/dns/server_doq.go:95](Desktop/internal/dns/server_doq.go#L95)（均无锁赋值）、对照 [internal/dns/server_dot.go:20-28](Desktop/internal/dns/server_dot.go#L20)（DoTListenAddress 持锁读 `s.dot`）
- **现象**：`Start()` 在持锁路径调用 start*，而 `ReloadEncrypted` 先 `s.mu.Unlock()` 再调 `startDoT/startDoH/startDoQ`，其中 `s.dot = dl`、`s.encrypted` 读取完全无锁；同时 DDR 查询回调（[controller_pipeline.go:64-71](Desktop/cmd/service/controller_pipeline.go#L64)）在 DNS 热路径经 `DoTListenAddress()` 等**持锁**读同一批字段。一边持锁一边不持锁＝数据竞争。解锁后 96-97 行还直接读 `s.encrypted.DoTListenAddress()`，并发传入 `ReloadEncrypted(nil)` 时空指针 panic。
- **根因**：ReloadEncrypted 为避免 close/start 期间持锁阻塞查询而提前解锁，但 start* 内部对共享字段的写入没有对应的锁段。
- **验证方法**：`go test -race ./internal/dns/`，编写并发测试：一路循环 `ReloadEncrypted(cfg)`，一路循环调用 `DoTListenAddress()/EncryptedEnabled()`，race detector 即报 write@server_dot.go:80 vs read。

### BUG-8 · 缓存/并发回源 · 高 · singleflight 跟随者 Copy 与领导者回包改写竞态（-race 可实锤）
- **位置**：[internal/dns/cache_middleware.go:78-85](Desktop/internal/dns/cache_middleware.go#L78)（flight fn 原样返回 `ctx.Resp` 指针）、[internal/core/cache_flight.go:41-44](Desktop/internal/core/cache_flight.go#L41)（跟随者 `c.val.Copy()`）、[internal/dns/server.go:322-337](Desktop/internal/dns/server.go#L322)（Execute 返回后对 `dnsCtx.Resp` 写 `Id`、UDP 路径 `Truncate(maxSize)`）
- **现象**：同一 qname/qtype/group 并发未命中时，领导者把 `ctx.Resp` 的**同一指针**发布进 flight；`wg.Done()` 只保证 `c.val` 写入对跟随者可见，不约束领导者随后的 `Resp.Id = r.Id` 与 `Truncate`（会改写 Compress/Truncated/Answer 切片）——跟随者此刻正 `Copy()` 同一对象，构成对 `*dns.Msg` 的并发读写。TTL=0 / 未入缓存条目必走该共享路径（缓存命中路径走不到 Copy，恰好掩盖了问题）。
- **根因**：flight 的契约是「发布后值不可变」，缓存中间件返回的是活的响应对象而非副本。
- **验证方法**：`go test -race ./internal/dns/`：起一个 TTL=0 的桩上游，N 个 goroutine 并发投同一查询命中 flight 共享分支，race detector 报 `Resp.Id/Truncate 写 @server.go:327/336` vs `Copy 读 @cache_flight.go:44`。

### BUG-9 · 加密 DNS/DoT · 中 · DoT 应答写出无写超时，零窗口客户端可永久钉住协程与连接
- **位置**：[internal/dns/server_dot.go:140](Desktop/internal/dns/server_dot.go#L140)（握手后 `SetDeadline(time.Time{})` 清空全部期限）、[internal/dns/dot_conn.go:127-146](Desktop/internal/dns/dot_conn.go#L127)（serve 只续读期限）、[internal/dns/dot_conn.go:74-100](Desktop/internal/dns/dot_conn.go#L74)（`d.conn.Write(framed)` 无任何期限；对照 DoQ 在 server_doq.go:190 设置了写期限）
- **现象**：客户端发一条查询后停止读取（TCP 零窗口 / `shutdown(SHUT_RD)`），服务器的 `Write` 永久阻塞——`queryCtx` 超时从未传导到 socket 写出。单连接一个协程加一整条流水线状态被无限占用，批量构造即可耗尽服务进程。
- **验证方法**：包内测试起 DoT：完成 TLS 后发一条查询、随后不再读取（或半关闭），断言 serve 在有界时间内返回——现状永不返回。

### BUG-10 · 网卡接管 · 高 · Restore 失败仍无条件清空状态与快照，且兜底清扫会把静态 DNS 抹成 DHCP
- **位置**：[internal/platform/windows/takeover.go:208-229](Desktop/internal/platform/windows/takeover.go#L208)（`err = RestoreAdapters(...)` 后无论成败都 `m.adapters=nil`、`stateStore.Clear()`）、[internal/platform/windows/dns_native.go:122-135](Desktop/internal/platform/windows/dns_native.go#L122)（逐卡 `resetAdapterDNSNative` 错误全吞、恒返回 nil）、[internal/platform/state.go](Desktop/internal/platform/state.go#L105)（自愈须 `Active && len(Adapters)>0`）
- **现象**：还原失败（如 `SetInterfaceDnsSettings` 瞬时 ERROR_ACCESS_DENIED）时，`dns_state.json` 已被删除、内存快照已清空——下次启动自愈无从检出残留；网卡 DNS 仍指向 127.0.0.1。唯一兜底 `ResetResidualLoopbackDNS` 既上报恒成功（吞错），又会把**原本配置静态 DNS** 的网卡重置为 DHCP——原始地址（8.8.8.8 等）在快照已毁的情况下永久丢失。用户侧结果：本地服务停止后整机断网且无恢复依据。
- **根因**：违背本项目 AGENT_MISTAKES 已确立的「不得丢弃返回值/失败即回滚状态」原则：清理动作没有以还原成功为前提。
- **验证方法**：单测：注入 `dnsSetter` 接管成功、还原必错的桩；`Restore()` 后断言 `stateStore.Load()` 非 nil（当前返回 nil，即缺陷）。

### BUG-11 · 网卡接管 · 高 · TakeoverSingle 失败不回滚已生效的单栈修改，且按名匹配覆盖/丢弃同名网卡记录
- **位置**：[internal/platform/windows/takeover.go:173-189](Desktop/internal/platform/windows/takeover.go#L173)（失败仅回滚簿记，未调 restoreSingleAdapter；对照批量 Takeover 的 109-113 有回滚）、[internal/platform/windows/takeover.go:146-156](Desktop/internal/platform/windows/takeover.go#L146)（`a.ID==adapter.ID || a.Name==adapter.Name` 先命中先替换）、[internal/platform/windows/takeover.go:237-246](Desktop/internal/platform/windows/takeover.go#L237)（同名多条目时无 break，target 取最后一个、其余匹配全部从 remaining 消失）
- **现象**：(a) 双栈接管 IPv4 已设 127.0.0.1 成功、IPv6 失败 → 返回错误并回滚簿记，但网卡仍被劫持而状态文件称「未接管」，UI 显示关闭态流量却仍被截获。(b) Windows 两块同 FriendlyName 网卡（双 USB 网卡皆「以太网」）：接管第二块会把第一块的原始快照**覆盖丢失**；还原按名匹配时其余同名条目被静默移出状态却从未还原，且返回成功。
- **根因**：以显示名作身份匹配（GUID 才是唯一键）；失败路径缺 restore 调用。
- **验证方法**：单测：`m.adapters=[{ID:G1,Name:以太网},{ID:G2,Name:以太网}]`，`TakeoverSingle(G2)` 后断言 G1 快照仍在（当前丢）；`RestoreSingle("以太网")` 断言 dnsResetter 调用次数==匹配数（当前 1）。

### BUG-12 · 应急恢复 · 中 · restore-dns.bat 直接内插网卡显示名，特殊字符破坏脚本乃至命令注入
- **位置**：[internal/platform/windows/restore_script.go:35,37,41,43,49,53,55](Desktop/internal/platform/windows/restore_script.go#L35)（`a.Name` 原样进 `echo` 行与 `name="%s"`），写入点 [takeover.go:105,171](Desktop/internal/platform/windows/takeover.go#L105)（`_ = GenerateRestoreScript(...)` 吞错）
- **现象**：网卡 FriendlyName 由驱动/安装程序决定（TAP/虚拟网卡可自定义），含 `"` 会破坏 netsh 引号使应急还原静默失效；含 `&`、`%` 等批处理元字符时，README/托盘提示「以管理员身份运行 restore-dns.bat」即成为提权命令执行面。生成失败还被静默吞掉，应急时刻脚本可能压根不存在。
- **验证方法**：单测模式已存在（`takeover_test.go TestGenerateRestoreScript_FilterLoopback`）：构造 Name=`WLAN" & calc &` 断言生成内容被转义或拒绝——当前原样内插。

### BUG-13 · 应急恢复 · 中 · `-restore` 与 GUI 应急恢复只读默认状态路径，与服务自定义路径脱节
- **位置**：[cmd/service/cli.go:22-31](Desktop/cmd/service/cli.go#L22)（仅显式传 `-config` 才解析 `StateFilePath`）、[platform_windows.go:21](Desktop/platform_windows.go#L21)（GUI 恒 `NewFileStateStore("")` 默认路径）、[cmd/service/main.go:108](Desktop/cmd/service/main.go#L108)（服务按配置自定义路径写）
- **现象**：配置了自定义 `takeover.stateFilePath` 并以 `-config` 安装服务后：服务把状态写到自定义路径；崩溃后 GUI「应急恢复」与 `diting-service.exe -restore`（不带 -config）读默认路径 → 报「未检测到残留接管状态文件」，网卡实际仍被劫持。读写双方路径不一致，应急通道在最需要时失效。
- **验证方法**：config.json 设自定义 stateFilePath → 接管 → 强杀服务 → 运行 `-restore`（不带 -config）观察提示语与 `netsh interface ipv4 show dnsservers` 实际值矛盾。

### BUG-14 · 服务管理 · 低 · RestartService 吞掉停止失败并以硬编码 defaultSCMQuery 轮询，掩盖原始错误且绕过测试注入点
- **位置**：[internal/platform/windows/service_mgr.go:323-344](Desktop/internal/platform/windows/service_mgr.go#L323)（325 `_ = stopServiceNative(...)`；329 硬编码 `defaultSCMQuery` 而非可注入的 `m.scmQuery`）
- **现象**：停止失败（依赖服务占用等）被丢弃 → 固定轮询最多 3s（GUI/HTTP 同步路径上的停顿）→ 启动大概率仍失败 → 回退提权再跑一次同样失败，用户最终只看到笼统「退出代码 n」，真实原因（1058/依赖冲突）无从知晓。329 行是重启路径中唯一绕过注入点的 SCM 查询，单测对该轮询不可观测。
- **验证方法**：注入 `m.scmQuery` 恒报 running 后调用 RestartService，断言注入函数从未被调用且耗时 ≥3s。

### BUG-15 · 前端 · 中 · useToast 的定时器不清理，卸载后仍回调改写状态；useConfirmModal 二次 ask 悬挂前一个 Promise
- **位置**：[frontend/src/composables/useToast.ts:13-22](Desktop/frontend/src/composables/useToast.ts#L13)（`timer` 无 `onUnmounted` 清理；同工程 [useFlashMessage.ts:43-46](Desktop/frontend/src/composables/useFlashMessage.ts#L43) 有清理，可对照）、[frontend/src/composables/useConfirmModal.ts:38-40](Desktop/frontend/src/composables/useConfirmModal.ts#L38)（新 `ask` 覆写 `resolvePromise`，前者永不 settle）
- **现象**：(a) toast 弹出后立即切换面板/关闭弹窗，3–4 秒后定时器仍触发；虽各实例状态为闭包私有不至于串扰 UI，但违背工程自身的清理规范（useFlashMessage/useAuthForm 均有 onUnmounted）。(b) 若第一个确认框未点确定/取消而代码再次 `ask()`（如错误处理路径里连发两次确认），首个 `await confirm.ask(...)` 永不返回，其后的 `saving/deleting` 标志永久卡 true，按钮失活直至刷新。当前 UI 模态遮挡使连点难以发生，属潜在缺陷。
- **验证方法**：单测：`const p=ask({message:'a'}); ask({message:'b'}); handleConfirm();` → `p` 仍 pending。组件测试：mount→show→unmount→`vi.advanceTimersByTime(4000)`→断言无 setTimeout 被 clearTimeout 配对。

---

## 第 3 轮（2026-10-17）— 已扫描模块

已扫描：`cmd/service/{controller,controller_encrypted,controller_acl}.go`（reloadDNSWithCurrentConfig 锁链）、`internal/dns/{ede_middleware,server}.go`（getter 锁依赖与 close 等待）、`internal/platform/windows/dns_native.go`。

### BUG-16 · 加密 DNS 配置保存 · 高 · 保存设置时持 p.mu 等待在途查询退出，而在途查询正阻塞在同一把 p.mu 上——整条解析流水线停顿 3~9 秒
- **位置**：[cmd/service/controller_encrypted.go:78-80,148](Desktop/cmd/service/controller_encrypted.go#L78)、[cmd/service/controller_acl.go:16-17,45](Desktop/cmd/service/controller_acl.go#L16)、[cmd/service/controller_dot.go:89-100](Desktop/cmd/service/controller_dot.go#L89)、[internal/dns/server.go:79-87](Desktop/internal/dns/server.go#L79)、[internal/dns/server_dot.go:188-197](Desktop/internal/dns/server_dot.go#L188)、[cmd/service/controller_pipeline.go:34-43,75-106](Desktop/cmd/service/controller_pipeline.go#L34)
- **现象**：`ConfigureEncryptedDNS / GenerateEncryptedCert / ImportEncryptedCert / ConfigureEncryptedACL` 全程持 `p.mu`（`defer Unlock`），末尾调用 `reloadDNSWithCurrentConfig → server.ReloadEncrypted`；后者在**不释放** `p.mu` 的情况下 `oldDot.close()`（内含 `d.wg.Wait()` 最多 3s）、`closeHTTP(oldDoH.srv, 3s)`、`oldDoQ.close()` 等待在途查询协程退出。而在途查询进入流水线后，EDE/ECH/IPv6/PrivatePTR/Unqualified/ANY/DDR 等**每查询必过**的 getter 回调都要 `p.mu.Lock()`（controller_pipeline.go:36 等处）——它们阻塞在配置保存者手里的那把锁上，永远等不到自己「退出」。
- **根因**：锁序倒置：配置线程持 p.mu → 等查询退出；查询线程 → 等 p.mu。两侧只能靠 3 秒超时打破，等价于每次保存加密设置/证书/ACL 时本机 DNS 强制停顿至多 3×3=9 秒，且旧监听器上的在途请求被超时强行放弃（连接被关，客户端收到截断应答）。若 TLS 证书生成（GenerateEncryptedCert 持锁做密钥生成+落盘）耗时长，停顿从保存点击起就覆盖整个生成过程。
- **验证方法**：集成测试：装配真实 `buildPipeline()` 的 Server 起 DoT；另起 goroutine 持续发 DoT 查询；主线程调用 `ConfigureEncryptedDNS`（改端口），记录查询 RTT——现状每次保存出现秒级尖刺且伴随查询超时。单元级：对 `p.mu` 加 `TryLock` 断言 getter 在 reload 期间拿不到锁即阻塞。

---

## 第 4 轮（2026-10-17）— 已扫描模块

已扫描：`internal/platform/linux/{takeover,backend,backend_resolvconf,backend_networkmanager,resolvconf,restore_script,dnsstate,firewall}.go`（Linux 平台层，全新模块）。

### BUG-17 · Linux 应急恢复 · 中 · restore-dns.sh 读取的原始备份 `/etc/resolv.conf.diting.orig` 从未被任何代码写入，首选还原路径为死分支
- **位置**：[internal/platform/linux/restore_script.go:102-104](Desktop/internal/platform/linux/restore_script.go#L102)（脚本判定并 cat `.orig`）对照 [internal/platform/linux/backend_resolvconf.go:28-33](Desktop/internal/platform/linux/backend_resolvconf.go#L28)（接管时仅把备份写到 `DefaultDataDir()/backups/resolv.conf`）；全仓库检索 `diting.orig` 仅此两读、无任何写入点。
- **现象**：接管走 resolv.conf 后端时，原始文件内容（含 search 域、options 等）备份到数据目录，但离线脚本只会去 `cat /etc/resolv.conf.diting.orig`——该文件永不存在，脚本恒落入 else 分支，按快照中的 nameserver 列表重建。快照经 `CleanAdapterState` 会剥掉回环地址（netutil.go:78-88），若用户原配置为 `nameserver 127.0.0.53`（resolved stub）等回环地址会被过滤成空 → 脚本落到硬编码 `223.5.5.5/119.29.29.29`。search 域与 options 全部丢失。
- **根因**：备份写入路径与脚本读取路径是两套常量，改备份机制时未同步脚本模板。
- **验证方法**：Linux 下接管（resolvconf 后端）后 `ls /etc/resolv.conf.diting.orig` 必然不存在；对照 `~/.diting`（或 ProgramData 等价目录）`backups/resolv.conf` 存在。执行生成的 restore-dns.sh 输出恒为「写入接管前记录的解析服务器」分支。

### BUG-18 · Linux 网卡接管 · 中 · RestoreSingle 按名匹配无 break：同名多条目时其余匹配被静默移出状态且从未还原，仍返回成功
- **位置**：[internal/platform/linux/takeover.go:199-212](Desktop/internal/platform/linux/takeover.go#L199)（`a.ID == adapterID || a.Name == adapterID` 命中不 break，其余命中项既不进 target 也不进 remaining）、同型 [internal/platform/linux/takeover.go:120-130](Desktop/internal/platform/linux/takeover.go#L120)（TakeoverSingle 先命中先覆盖）
- **现象**：与 Windows 版 BUG-11 同族但代码独立（Linux 实现自有一份）：快照中存在两条 Name 相同的记录（如设备名与连接显示名混用）时，`RestoreSingle("eth0")` 只还原最后一条，前面的条目从 `remaining` 消失且 `backend.Restore` 未收到它 → 该网卡 DNS 停留在 127.0.0.1，函数返回 nil（成功），状态文件与实况脱节，重启后自愈无从恢复该网卡。
- **根因**：循环以「排除式」构建 remaining，命中即替换 target，未把未选中的命中项放回 remaining，也未在多条命中时显式报错。
- **验证方法**：包内测试（Linux tag 下跑或抽纯函数）：预置 `m.adapters=[{ID:"a1",Name:"eth0"},{ID:"a2",Name:"eth0"}]`，mock backend 记录 Restore 调用；`RestoreSingle("eth0")` → 断言 backend.Restore 收到 2 条（当前 1 条）、`GetTakenOverAdapters()` 为空（a2 被静默丢弃）。

### 观察项（Linux 层，暂不计为独立缺陷）
- `internal/platform/linux/restore_script.go:93`：`nmcli con mod %q ...` 用 Go `%q` 生成 shell 双引号串，Go 的转义集与 sh 双引号语义不完全一致（`$`、反引号不转义），含 `$` 的接口名理论上会展开；Linux 接口名实际字符集受限，风险低于 BUG-12 的 Windows 对应面。
- `internal/platform/linux/dnsstate.go:76`（serversFromNmcli）：nmcli `-t` 输出对值内 `:` 会转义为 `\:`，解析处直接 `Split(":")` 未反转义——含冒号的连接名/值会错位；同样属实际难触发的窄路径。
- `internal/platform/linux/backend_networkmanager.go:49-72`：Restore 遍历**所有**活动连接，不在快照中的连接会被 `modifyConnection(conn, nil, nil, false)` 清空静态 DNS——接管后新激活的、手工配了静态 DNS 的连接会在还原时被抹掉配置；触发条件较苛刻，暂列观察。

---

## 已核实但予以剔除的代理报告项（防重复上报）

- 「`/api/v1/service/status` 不返回 `autoStart`」——**不实**：`platform.CoreServiceStatus` 含 `autoStart,omitempty`（[internal/platform/types.go:134](Desktop/internal/platform/types.go#L134)），`ServiceManager.GetStatus` 恒填充（service_mgr.go:155）；Web 模式自启开关本就隐藏不可操作。
- 「`RestoreAdapters` 持锁再入自死锁」——**不实**：该方法及其下游均不取 `m.mu`。
- 「`useCopyFeedback` 跨实例串扰」——**不实**：`copiedValue/timer` 为每次调用新建的闭包变量，非模块级共享。
- 「netsh `name=X` 单 token 参数引号失效」——代理自验后撤回，add 路径确有 `err` 检查。
- 「`filter.checkHost` 数字 qtype 传错」——当前唯一调用方 RuleTestPanel 的 select 值恒为字符串助记符，`number` 仅为签名冗余，无实际错误路径，降为观察项。
- 「web 模式 `setAutoStart` 静默空操作」——入口开关在 Web 模式已被 `v-else-if="webMode"` 隐藏，不可达，降为观察项。

## 待复核 / 观察点（尚不确定，暂不计为 Bug）

- `internal/ipc/server_ws.go:39-81` runHub 慢客户端关闭路径：close(send) 均在 `mu.Lock` 下、broadcast 在 `mu.RLock` 下，互斥保证不会向已关闭 channel 发送。当前判定为安全，若后续引入 writePump 自注销需复核。
- `internal/ipc/cors.go` 反射任意 Origin + `Allow-Credentials: true`：是否应改为仅白名单 `wails://*` / `http(s)://<本机>` 待定，属加固建议而非独立缺陷。
- `frontend/src/composables/useServiceControl.ts:31-37`：`status/loading/operating` 为模块级共享单例。CoreServiceCard 与 ServiceAlertModal 共用可能是有意设计（操作互斥），但 `opError/opMessage` 跨组件残留（A 面板失败文本会显示在新挂载的 B 面板）是否为预期需产品确认。
- `frontend/src/api/http.ts:22` 与 `clearSession`：登出只清 `diting_session_token`，手工配置的 `diting_ipc_token` 留存并在重载后经 `loadConfig` 重新武装（ws.ts 见 token 即自动重连）。影响面限于桌面端手工配置过 token 的场景，等级低。
- `frontend/src/api/encrypted.ts:58-68`：`mobileConfigURL` 拼入非响应式的 `http.token/baseURL`，`MobileConfigCard` 的 computed 只在 `enabled/protocol` 变化时重算；若 token 在面板打开**之后**才到达，URL 缺 `?token=`。时序窗口很窄（登录先于面板挂载），暂列观察。
- `internal/platform/windows/takeover.go:201-203`：`!IsDefaultExecutor → return nil` 使非默认执行器下接管成为「返回成功的空操作」；生产路径恒传 DefaultExecutor，暂无实际影响，属脆弱守卫。
- `cmd/service/cli.go executeEmergencyRestore` 在自愈未检出残留时仍打印「[成功] 已完成全网卡 DNS 状态排查与兜底重置」，与 BUG-10 的吞错清扫联动可能虚报成功；根因已并入 BUG-10。
