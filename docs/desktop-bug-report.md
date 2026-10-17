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
- **验证方法**：已用临时测试实证（验证后删除）：`NewServer("127.0.0.1:0", "", &mockController{})`，`withAuth(handleDNSStop)` 收到 `RemoteAddr=127.0.0.1:54321` 且无任何凭据的请求返回 **200 `{"success":true,"message":"DNS 服务已停止"}`**；同一请求源地址改为 `192.168.1.50` 则 401。亦可实机验证：本机浏览器 `curl.exe http://127.0.0.1:15353/api/v1/dns/stop -X POST` 不带凭据直接生效。

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

### BUG-19 · Linux 服务安装 · 中 · locate 命中相对候选路径时写出的 systemd 单元 ExecStart 为相对路径，服务永远起不来
- **位置**：[internal/platform/linux/service_mgr.go:71-88](Desktop/internal/platform/linux/service_mgr.go#L71)（candidates 含 `./build/bin/diting-service`、`build/bin/diting-service`；commandExists 分支返回裸名 `"diting-service"`）、[service_mgr.go:295-297](Desktop/internal/platform/linux/service_mgr.go#L295)（`renderSystemdUnit(exePath)` 原样拼入 ExecStart）、[service_mgr.go:338-357](Desktop/internal/platform/linux/service_mgr.go#L338)
- **现象**：`InstallService` 用 `locate()` 的结果渲染单元文件。`fileExists("./build/bin/diting-service")` 以 GUI 进程 CWD 判定存在后，该**相对路径**被原样写入 `/etc/systemd/system/*.service` 的 `ExecStart=`；systemd 以 `/` 为工作目录解析相对路径 → 找不到可执行文件 → 单元进入 `failed`，`Restart=always` 变成每 10 秒失败重启一次。commandExists 分支同理返回裸命令名。用户只见「运行失败请查 journalctl」，看不到根因是路径。
- **根因**：locate 的「可执行」判定发生在 GUI 进程 CWD，而最终使用方（systemd）的 CWD 是 `/`；候选与返回值均未 `filepath.Abs` 归一。
- **验证方法**：Linux 上从含 `build/bin/diting-service` 的目录启动 GUI → 点安装服务 → `systemctl cat diting-dnsservice` 查看 ExecStart 是否为相对路径 → `systemctl start` 后单元 failed、journal 记录找不到文件。单测：注入 `locateExe` 返回相对路径，断言 renderSystemdUnit 输出含绝对路径（当前不含）。

### 观察项（Linux 层，暂不计为独立缺陷）
- `internal/platform/linux/restore_script.go:93`：`nmcli con mod %q ...` 用 Go `%q` 生成 shell 双引号串，Go 转义集与 sh 双引号语义不完全一致（`$`、反引号不转义），含 `$` 的连接名理论上会展开；Linux 连接名实际字符集受限，风险低于 BUG-12 的 Windows 对应面。
- `internal/platform/linux/dnsstate.go:76`（serversFromNmcli）：nmcli `-t` 输出对值内 `:` 会转义为 `\:`，解析处直接 `Split(":")` 未反转义——含冒号的连接名/值会错位；同样属实际难触发的窄路径。
- `internal/platform/linux/backend_networkmanager.go:49-72`：Restore 遍历**所有**活动连接，不在快照中的连接会被 `modifyConnection(conn, nil, nil, false)` 清空静态 DNS——接管后新激活的、手工配了静态 DNS 的连接会在还原时被抹掉配置；触发条件较苛刻，暂列观察。

---

## 第 5 轮（2026-10-17）— 已扫描模块

已扫描：`frontend/src/components/{rules/{RulesPanel,SafeBrowsingCard}.vue, overview/QueryHistoryPanel.vue, accel/CachePanel.vue, network/{UpstreamPanel,ClientsPanel,ClientGroupsCard}.vue, encrypted/{EncryptedListenersCard,ReverseProxyCard,EncryptedDNSPanel}.vue, rules/ScheduleEditor.vue}`、`frontend/src/composables/usePoller.ts`，并对照后端 `cmd/service/controller_dns.go`（GetStatus 的 upstreams 数据源）。本轮为**前端交互/状态管理**专项；工程无前端自动化测试工具链（package.json 仅 dev/build/preview），全部条目按代码路径静态核验并给出 UI 手动复现步骤。

### BUG-20 · 前端/规则面板 · 高 · 4 秒轮询无条件覆盖用户正在编辑的自定义规则与策略参数，未保存输入静默丢失
- **位置**：[frontend/src/components/rules/RulesPanel.vue:214](Desktop/frontend/src/components/rules/RulesPanel.vue#L214)（`usePoller(fetchData, 4000)`）、[:73](Desktop/frontend/src/components/rules/RulesPanel.vue#L73)（`config.value = cfg` 整体替换）、[:75](Desktop/frontend/src/components/rules/RulesPanel.vue#L75)（`customRulesText.value` 重写）；受影响的编辑绑定：textarea [:393](Desktop/frontend/src/components/rules/RulesPanel.vue#L393)、blockMode 单选 [:427/:440/:453](Desktop/frontend/src/components/rules/RulesPanel.vue#L427)、数值/地址输入 [:481/:493/:500](Desktop/frontend/src/components/rules/RulesPanel.vue#L481)
- **现象**：`fetchData` 每次轮询都用服务端快照整体替换 `config`（v-model 驱动策略配置页的三组单选与三个输入框）并重写 `customRulesText`（v-model 绑定自定义规则 textarea），全程无任何"用户正在编辑"判据。用户在 textarea 里输入新规则、尚未点「保存规则」，≤4 秒内文本即被服务器旧内容回卷；在策略配置页选中 NXDOMAIN 后等待 4 秒，单选回到服务器值。保存按钮（`saveCustomRules` [:179-194](Desktop/frontend/src/components/rules/RulesPanel.vue#L179)、`saveConfig` [:196-212](Desktop/frontend/src/components/rules/RulesPanel.vue#L196)）读取的正是这两个被覆写的 ref——若轮询恰好插在用户点保存之前落回，落库的是服务器旧值，用户输入无声消失。
- **根因**：面板把「展示用服务器状态」与「编辑草稿」合并为同一份响应式状态，而高频轮询只认前者；`usePoller` 也无「输入焦点/脏态期间暂停」语义。同组件的暂停倒计时等只读展示确有轮询必要，二者共用一份覆写路径。
- **验证方法**：手动复现：防护 → 自定义规则页签，在 textarea 输入一行 `||test.example^` 不点保存，等待 4–5 秒 → 文本回卷为服务器内容；策略配置页签选中「NXDOMAIN」单选，等 4 秒 → 选择回弹。静态核验点：[:73/:75](Desktop/frontend/src/components/rules/RulesPanel.vue#L73) 无任何 dirty/焦点守卫，全文件无 dirty 标志位。

### BUG-21 · 前端/加密 DNS 等 · 高 · 「状态回填」清除未保存草稿（同族四处）：任何状态对象刷新都把草稿字段无条件覆写回服务器值
- **位置**：① [frontend/src/components/encrypted/EncryptedListenersCard.vue:44-56](Desktop/frontend/src/components/encrypted/EncryptedListenersCard.vue#L44)（`watch(() => props.status)` 回填 6 个 v-model 字段，模板绑定 [:250-270](Desktop/frontend/src/components/encrypted/EncryptedListenersCard.vue#L250)），触发链 [EncryptedDNSPanel.vue:37-39](Desktop/frontend/src/components/encrypted/EncryptedDNSPanel.vue#L37)（`onChanged` 整体替换 status）＋本卡 `toggleMaster/toggleProtocol` [:73-105](Desktop/frontend/src/components/encrypted/EncryptedListenersCard.vue#L73) 的 `emit('changed')`；② [frontend/src/components/encrypted/ReverseProxyCard.vue:63-70](Desktop/frontend/src/components/encrypted/ReverseProxyCard.vue#L63)（`watch([sources, clientIpHeader])`，`sources` 为 computed [:33](Desktop/frontend/src/components/encrypted/ReverseProxyCard.vue#L33) 直取父状态内数组，父状态对象一经整体替换（任何卡片 `changed`/刷新）引用即变、watch 触发），本卡开关 [:89-97](Desktop/frontend/src/components/encrypted/ReverseProxyCard.vue#L89)；③ [frontend/src/components/rules/SafeBrowsingCard.vue:29-35](Desktop/frontend/src/components/rules/SafeBrowsingCard.vue#L29)（`apply()` 无条件重写 `timeoutMs/cacheSize/cacheTTLSeconds`，模板 v-model [:154-175](Desktop/frontend/src/components/rules/SafeBrowsingCard.vue#L154)），`toggleMaster` [:46-58](Desktop/frontend/src/components/rules/SafeBrowsingCard.vue#L46) 即调用；④ [frontend/src/components/network/ClientsPanel.vue:150-153,180-181](Desktop/frontend/src/components/network/ClientsPanel.vue#L150)（行内白/黑名单按钮成功后直接重写 `allowedText/blockedText` 草稿 textarea，且请求体由 `accessConfig` 组装、根本不含用户草稿——草稿既不会被保存还会被清空）。
- **现象**：四处共同模式：用户在输入框/textarea 中编辑尚未保存，此时**同一卡片自己的开关**、兄弟卡片的 `changed`、或面板「刷新」按钮任一发生，状态对象身份变化即触发回填，草稿被服务器旧值静默覆写，无任何提示或恢复途径。
- **根因**：草稿态与展示态未分离（无编辑标志/焦点判断/差异保留），且以对象引用变化而非"用户字段确实被外部改动"作为回填条件；ReverseProxyCard 的 computed 数组引用不稳定使误触发比①更频繁。
- **验证方法**：手动复现：设备 → 加密 DNS → 「服务器名」输入新值后拨动同卡 DoT 开关 → 输入回卷；反向代理卡点「编辑」→ textarea 加一行 → 拨同卡启用开关 → 新增行消失；防护 → 恶意网址库改「查询超时」→ 拨启用开关 → 数字回弹；设备 → 客户端 → 白名单 textarea 手输一行 → 点任一行「加入白名单」按钮 → textarea 被服务器列表重写。

### BUG-22 · 前端/查询历史 · 中 · `liveBuffer` 为非响应式 `let` 却被模板消费：「暂停期间新增 N 条」永不显示，缓冲事件在检索回包时被吞；回车重发检索无请求代次守卫
- **位置**：[frontend/src/components/overview/QueryHistoryPanel.vue:37](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L37)（`let liveBuffer: QueryLogRecord[] = []`）、[:145-152](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L145)（暂停/翻页/筛选态下事件仅 push 进该数组）、模板 [:285-287](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L285)（`v-if="liveBuffer.length > 0"`）；[:90](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L90)（`fetchPage` 成功后 `liveBuffer = []`）、[:83-96](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L83)（无请求代次/中止守卫）、[:234/:240](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L234)（筛选输入框 `@keyup.enter="applyFilters"` 不受 `loading` 门控）
- **现象**：(a) 停留在第 2 页或暂停实时刷新时产生新查询，`liveBuffer.push` 不触发任何重渲染，「暂停期间新增 N 条，检索后可见」提示永不出现/递增——该功能等于不存在。(b) 提示语承诺"检索后可见"，但 `fetchPage` 回包即 `liveBuffer = []`，把**本次请求快照之后、回包之前**到达的事件一并丢弃。(c) 翻页按钮虽以 `:disabled="loading"`（[:365/:374](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L365)）挡住连点，筛选输入框回车不受此门控：loading 期间按 Enter 发出第二个 `searchQueryLog`，乱序回包中后到者整体覆写 `entries/total`，表格内容与「第 x/y 页」页码错位。
- **根因**：Vue 模板对 `<script setup>` 普通 `let` 仅在重渲染时读取，push 不构成渲染依赖；分页请求缺 stale-response 守卫。
- **验证方法**：手动复现：总览 → 历史记录 → 下一页，随后持续产生 DNS 查询 → 提示条始终不出现。静态核验：`liveBuffer` 非 `ref`/`reactive`（[:37](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L37)）且组件内无任何其他响应式赋值伴随 push 路径（[:147](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L147) 直接 return）。回车乱序可在 DevTools 网络节流（Slow 3G）下：先输条件回车，立即改条件再回车，观察两请求响应乱序时表格与页码不符。

### BUG-23 · 前端/缓存面板 · 中 · 4 秒轮询与手动检索互相覆写列表，无请求代次守卫：过滤结果会被先到轮询的回包"闪回"全量
- **位置**：[frontend/src/components/accel/CachePanel.vue:247](Desktop/frontend/src/components/accel/CachePanel.vue#L247)（`usePoller(pollMetrics, 4000)`）、[:104-118](Desktop/frontend/src/components/accel/CachePanel.vue#L104)（`pollMetrics` 调用时读 `currentSearch.value`，回包无条件写 `entries/totalEntriesCount`）、[:120-129](Desktop/frontend/src/components/accel/CachePanel.vue#L120)（`handleSearch` 同样直接覆写，两路径互不感知）
- **现象**：轮询在 t 时刻发出（携带旧 `currentSearch`），用户在 t+ε 输入关键词点检索并发出新请求；若轮询回包晚于检索回包到达，过滤结果被旧参数的全量列表覆盖，4 秒后下一次轮询才恢复——用户看到"刚搜完结果闪回全部条目"，并可能误按清空/导出操作在错误列表上。
- **根因**：与 BUG-22(c) 同族的 stale-response 竞态，独立站点：`entries` 的写入者有两条并发路径而无数组代次标记（请求序号/AbortController 均缺）。`pollMetrics` 捕获 `currentSearch` 的时机是发请求时而非回包时，守卫无从比较。
- **验证方法**：手动复现：解析 → 加速缓存，DevTools 网络节流 Slow 3G，在轮询 tick 后约 100–300ms 内提交检索（网络面板可见两请求乱序），表格先显示过滤结果、随即闪回未过滤内容。

### BUG-24 · 前端/上游面板 · 中 · 展示列表 `upstreams` 与被编辑列表 `providers` 是两份数组、同一 index 语义错位；保存失败后编辑/删除命中错误行
- **位置**：[frontend/src/components/network/UpstreamPanel.vue:386-388](Desktop/frontend/src/components/network/UpstreamPanel.vue#L386)（`v-for="(node, idx) in upstreams"`）、[:460](Desktop/frontend/src/components/network/UpstreamPanel.vue#L460)（`openEditDialog(idx)`）、[:469-470](Desktop/frontend/src/components/network/UpstreamPanel.vue#L469)（`handleDeleteNode(idx)`、禁用阈值为 `upstreams.length <= 1`）；但 `openEditDialog` [:214-217](Desktop/frontend/src/components/network/UpstreamPanel.vue#L214)、`handleDeleteNode` [:220-239](Desktop/frontend/src/components/network/UpstreamPanel.vue#L220)（内部守卫是 `providers.value.length <= 1`）、`saveConfig` 落库 [:160-175](Desktop/frontend/src/components/network/UpstreamPanel.vue#L160) 全部寻址 `providers`；`providers` 仅在为空或 `forceSyncProviders` 时从 `getUpstreamConfig()` 重同步 [:75-84](Desktop/frontend/src/components/network/UpstreamPanel.vue#L75)
- **现象**：两个列表数据源不同：`upstreams` 来自 `getStatus()`——服务侧优先取 **resolver 实时统计**（[cmd/service/controller_dns.go:159-177](Desktop/cmd/service/controller_dns.go#L159)，DNS 运行中）或配置回退（[:177-196](Desktop/cmd/service/controller_dns.go#L177)）；`providers` 来自 `getUpstreamConfig()`。正常运行时二者当前恰好同源同序，但任何一次 `saveConfig` 失败（服务器拒绝参数、写入出错）后 `providers` 已含本地新增/删除/修改而 `upstreams` 停留在服务器旧列表且不会自动重同步（`forceSyncProviders` 恒 false，重同步条件 `providers.length===0` 不成立）：此时点击第 N 张可见卡片的「编辑」弹出的是 `providers[N-1]` 之类的错位条目，「删除」直接 splice 错误的服务器并落库。禁用阈值混用两套 `length`，进一步掩盖边界不一致。
- **根因**：同一 UI 实体的"展示"与"操作"各用一份状态、以数组下标隐式对齐，无任何按 `id` 的匹配或单源约束；失败路径缺少强制重同步。
- **验证方法**：手动复现：解析 → 上游，添加一个会被服务端拒绝的条目触发 `saveConfig` 失败（错误横幅出现、providers 已含该条），对照可见卡片数与编辑弹窗内容即见错位。静态核验：模板 `idx` 直接传入仅寻址 `providers` 的两个处理函数（[:388→460/469](Desktop/frontend/src/components/network/UpstreamPanel.vue#L388)），全文件无 `upstreams`↔`providers` 的对账代码。

### BUG-25 · 前端/上游面板 · 低 · 成功横幅定时器重复创建且不清理：两次快速保存后第二条横幅提前消失，卸载后定时器仍触发
- **位置**：[frontend/src/components/network/UpstreamPanel.vue:176-180](Desktop/frontend/src/components/network/UpstreamPanel.vue#L176)（每次 `saveConfig` 成功都新建 `setTimeout(3000)`，句柄未保存、`onUnmounted` 无清理；同组件模式亦见于 [components/accel/CachePanel.vue:145-152](Desktop/frontend/src/components/accel/CachePanel.vue#L145) 等横幅路径，以本处为样本）
- **现象**：3 秒内两次保存（如连续切模式）：第一次的回调在自身 3 秒到点即清空 `successMessage`，把第二次刚显示的横幅提前抹掉；面板卸载/切页后遗留定时器仍回调改写已无消费者的 ref。违背工程自身的清理规范（[useFlashMessage.ts:43-46](Desktop/frontend/src/composables/useFlashMessage.ts#L43) 有 `onUnmounted` 清理；对照 BUG-15 已记录的 useToast 同类缺陷）。
- **根因**：自动消失提示用裸 `setTimeout` 且未做"新调度先取消旧调度"。
- **验证方法**：手动复现：DevTools 网络节流使两次保存间隔可感，快速切换解析模式两次，第二条「已更新并即时生效」横幅存活不足 3 秒即消失。

### BUG-26 · 前端/客户端分组 · 低 · 可删除草稿列表以 `:key="index"` 渲染（嵌套计划表同）：删除分组后 DOM 原位复用，编辑焦点/输入串行到上移的分组
- **位置**：[frontend/src/components/network/ClientGroupsCard.vue:210-213](Desktop/frontend/src/components/network/ClientGroupsCard.vue#L210)（`v-for="(row, index) in drafts" :key="index"`）、[:119-128](Desktop/frontend/src/components/network/ClientGroupsCard.vue#L119)（`confirmDelete` 直接 `splice`）；嵌套 [frontend/src/components/rules/ScheduleEditor.vue:56](Desktop/frontend/src/components/rules/ScheduleEditor.vue#L56)（`v-for :key="index"`）与 [:46-51](Desktop/frontend/src/components/rules/ScheduleEditor.vue#L46)（计划行 splice）
- **现象**：`md-outlined-text-field` 为 `:value` + `@input` 受控自定义元素，其内部（shadow DOM）值与焦点并不随 key 重排而重置。删除第 1 组后，原第 2 组各行复用原 DOM 节点：光标仍停在删除行残留的焦点输入框上，继续输入写进的是**上移后占据该位置的另一分组**；嵌套的时间段行同样错位。分组无稳定 id（草稿为新建对象），删除后 `saveConfig`（[:130-153](Desktop/frontend/src/components/network/ClientGroupsCard.vue#L130)）把错位的草稿整批落库。
- **根因**：删除式可变列表用位置下标做 key；`newDraft`（[:53](Desktop/frontend/src/components/network/ClientGroupsCard.vue#L53)）本可生成稳定 uid。
- **验证方法**：手动复现：设备 → 客户端 → 开启分组 → 建两组各输一个可辨识名称 → 删除第 1 组 → 在原焦点输入框继续打字，观察文本进入错误的分组行；保存后服务器落库错位。

### 观察项（前端，暂不计为独立缺陷）
- [components/overview/OverviewPanel.vue:99-113](Desktop/frontend/src/components/overview/OverviewPanel.vue#L99)：`fetchStatus` 同样无 stale-response 守卫，轮询与 WS 突发可短暂显示旧状态，但 5 秒内自愈且无用户输入交互面，风险低于 BUG-22/23。
- [components/encrypted/MobileConfigCard.vue:36-55](Desktop/frontend/src/components/encrypted/MobileConfigCard.vue#L36)：异步二维码生成可乱序回写——与既有观察「mobileConfigURL 非响应式」同点位，等待同一修复。
- BUG-20/21 的根因（草稿与服务器状态未分离）为工程级模式问题，预计后续轮次在其他含内联表单的组件（RuleListsPanel 订阅参数、RewritePanel 表单等）仍会复现同族症状，届时并表不另立条目。

---

## 第 6 轮（2026-10-17）— 已扫描模块

已扫描：`internal/ipc/{server_filter,server_client_groups,routes}.go` 与 `cmd/service/{controller_dns,controller_cache,controller_security,controller_rewrite,controller_zone,controller_safesearch,controller_client_groups,controller_pipeline,controller_filter,controller_lan}.go`，并对照引擎侧 `internal/core/{client_groups,cache,cache_stats,cache_persist,rate_limiter,rule_engine_lists}.go`、`internal/dns/{filter_middleware,client_middleware,cache_middleware,upstream_route_middleware}.go`。本轮主题：**配置写路径的"热生效"语义与生命周期一致性**（代理报告 7 项，全部核验属实）。

### BUG-27 · 客户端分组热更新 · 高 · ConfigureClientGroups 换掉 p.groupResolver，但运行中流水线持有旧指针——新分组/成员变更对 DNS 转发路径完全不生效，API 却回复「已更新并生效」
- **位置**：[cmd/service/controller_client_groups.go:88-93](Desktop/cmd/service/controller_client_groups.go#L88)（`p.groupResolver = gr` 仅换字段）、[cmd/service/controller_pipeline.go:31,107,118,125,134](Desktop/cmd/service/controller_pipeline.go#L31)（`buildPipeline` 把**当时的** `p.groupResolver` 指针按值捕获进 client/filter/filterResponse/cache/upstreamRoute 五个中间件闭包）、[internal/dns/filter_middleware.go:19-37](Desktop/internal/dns/filter_middleware.go#L19)、[internal/dns/client_middleware.go:17-36](Desktop/internal/dns/client_middleware.go#L17)、[internal/dns/cache_middleware.go:20-36](Desktop/internal/dns/cache_middleware.go#L20)、[internal/dns/upstream_route_middleware.go:30-41](Desktop/internal/dns/upstream_route_middleware.go#L30)（闭包持旧指针读 `entries`）、[internal/core/client_groups.go:61-110](Desktop/internal/core/client_groups.go#L61)（`NewGroupResolver` 每次新建对象、`Resolve` 读 `r.entries`）、[internal/ipc/server_client_groups.go:37-40](Desktop/internal/ipc/server_client_groups.go#L37)（返回「客户端分组已更新并生效」）；`buildPipeline` 全工程唯一调用点 [cmd/service/controller_dns.go:28](Desktop/cmd/service/controller_dns.go#L28)（仅 `StartDNS`），`Server.pipeline` 装配后逐查询复用（[internal/dns/server.go:38,152,322-323](Desktop/internal/dns/server.go#L322)）
- **现象**：DNS 运行中新增/修改分组：规则引擎匹配器确有热更（`filterEngine.SetClientGroups`，controller_client_groups.go:84），但**转发侧**的分组归属（client 中间件写入 ctx 的 `attrClientGroup`、filter 中间件的 `MatchForGroup(domain,qtype,groupID)`、缓存隔离键、分组专属上游路由 `ExchangeForGroup`）全部仍由旧 `GroupResolver` 判定——新分组解析为 `default`，其专属规则集/上游/缓存隔离静默不生效，直到监听器重启。响应文案宣称"已生效"，GET `/api/v1/clients/groups` 也显示新配置，用户无从察觉。对照同工程 [cmd/service/controller_lan.go:59-68](Desktop/cmd/service/controller_lan.go#L59)：改监听地址明知中间件固化，故 StopDNS+StartDNS 平滑重建流水线；分组路径漏了这一步（或未改为 getter 惰性读取）。
- **根因**：指针按值捕获 vs 字段重赋值的生命周期错配；`SetClientGroups` 只重建了引擎侧分组匹配器，掩盖了 resolver 侧未重建的事实。
- **验证方法**：集成测试：装配真实 `buildPipeline()` 起 DNS（分组功能开启、含组 A），POST ConfigureClientGroups 增加组 B（CIDR 覆盖查询源 IP）→ `Exchange` 断言查询按组 B 规则集/上游处理——现状按 default 组。简易版：ConfigureClientGroups 后比较 `p.groupResolver` 与流水线中间件闭包捕获的指针（反射/包内测试构造两份断言不等）。实机：开启分组后新增分组即刻从成员 IP 发起命中该组规则的域名查询，日志 `filterRule` 为空且上游未切换，重启 DNS 后行为才变化。

### BUG-28 · 服务状态接口 · 高 · GetStatus 在释放 p.mu 后大范围读 p.cfg/p.resolver/p.takeoverMgr，与全部持锁 Configure* 写路径构成数据竞争
- **位置**：[cmd/service/controller_dns.go:155-157](Desktop/cmd/service/controller_dns.go#L155)（仅 `dnsRun` 在锁内取）、[:159-176](Desktop/cmd/service/controller_dns.go#L159)（无锁读 `p.resolver.GetProviderStats()`）、[:194-199](Desktop/cmd/service/controller_dns.go#L194)（无锁读 `p.takeoverMgr`）、[:201,215-248](Desktop/cmd/service/controller_dns.go#L201)（无锁读 `p.cfg.DNS/Upstream/Hosts/Rebind/Access/RateLimit/DNS64/Rewrite/Zone/SafeSearch/SafeBrowsing/ECS` 全量）；写侧全部持 `p.mu`：[cmd/service/controller_security.go:56](Desktop/cmd/service/controller_security.go#L56)（ConfigureRateLimit `p.cfg.RateLimit = cfg`）、[:95,126-127,159-162](Desktop/cmd/service/controller_security.go#L95)、[cmd/service/controller.go:112](Desktop/cmd/service/controller.go#L112)（ConfigureUpstream）、[cmd/service/controller_client_groups.go:99-100](Desktop/cmd/service/controller_client_groups.go#L99) 等
- **现象**：Web 控制台/托盘每 3–5s 轮询 `/api/v1/status`，与任意一次保存（限速、隐私、上游、分组…）并发即触发对同一 `config.Config` 结构体的无同步读写——Go 内存模型下是货真价实的数据竞争，不止"读到旧值"：`p.cfg.Upstream.Providers` 切片头读写撕裂可致 range 越界 panic 直接崩服务进程；`p.resolver.GetProviderStats()` 与 ConfigureUpstream 的重建并发同理。
- **根因**：`p.mu` 约定为"读 p.cfg 必须持锁"（`buildPipeline` 注释 [controller_pipeline.go:22](Desktop/cmd/service/controller_pipeline.go#L22) 明说"内部对 p.cfg 的读取依赖该保护"），GetStatus 却只锁了 `dnsRun` 一个字段。对照同文件 controller_schedule.go:90 的"锁内取值、锁外使用"姿势。
- **验证方法**：`cd Desktop && go test -race ./cmd/service/`：并发跑 `p.GetStatus(ctx)` 与 `p.ConfigureRateLimit(...)`，race detector 报 read controller_dns.go:240 vs previous write controller_security.go:56。实机：浏览器开着总览页连续点保存限速，观察偶发状态字段新旧混合渲染。

### BUG-29 · 缓存配置热更新 · 中 · maxEntries 修改被持久化并被 GET 回显，但运行期容量（分片上限/落盘上限/Stats）从不重算——「已更新并生效」实为重启才生效
- **位置**：[cmd/service/controller_cache.go:77-95](Desktop/cmd/service/controller_cache.go#L77)（`UpdateCacheConfig` → `p.cache.UpdateConfig(cfg)` + 落盘）、[internal/core/cache.go:78-95](Desktop/internal/core/cache.go#L78)（`UpdateConfig` 只换 `c.config`，不碰 `c.maxEntries` 与 `shard.maxEntries`）、[:44-77](Desktop/internal/core/cache.go#L44)（容量仅在 `NewDNSCache` 折算一次）、淘汰点 [:439](Desktop/internal/core/cache.go#L439)（`len(shard.entries) >= shard.maxEntries`）、[internal/core/cache_stats.go:36](Desktop/internal/core/cache_stats.go#L36) 与 [internal/core/cache_persist.go:63,114](Desktop/internal/core/cache_persist.go#L63)（读 `c.maxEntries`）
- **现象**：把缓存上限从 1024 调到 200000：POST 返回成功，`GET /api/v1/cache/config` 因回显 `GetConfig()` 显示 200000（[internal/core/cache.go:123-127](Desktop/internal/core/cache.go#L123)），但逐出阈值、落盘条数上限、`/cache/stats` 的 `MaxEntries` 全部还是开机值——用户以为扩容生效，实际命中率毫无变化；反向调低同样静默无效。与 BUG-27 同族：配置面"已生效"与运行面"要重启"脱节。
- **根因**：分片容量在构造期一次性折算进 64 个 shard 与两个字段，`UpdateConfig` 的更新面只覆盖 `config`；无重算/重建分片逻辑，也无一处注释声明"容量变更需重启"。
- **验证方法**：包内测试：`NewDNSCache(cfg{MaxEntries:64})` → `UpdateConfig(cfg{MaxEntries:4096})` → 写入 100 条，断言淘汰行为/`Stats().MaxEntries` 仍为 64（当前如此）——修复预期应为 4096 或返回明确错误。

### BUG-30 · 订阅源更新 · 中 · `POST /api/v1/filter/lists/update` 缺 URL 非空校验（与 add 不对称），省略 URL 字段即把在用订阅源清空并静默"更新成功"
- **位置**：[internal/ipc/server_filter.go:126-149](Desktop/internal/ipc/server_filter.go#L126)（update 处理无任何字段校验）对照 [:96-114](Desktop/internal/ipc/server_filter.go#L96)（add 明确拒绝空 URL）；[internal/core/rule_engine_lists.go:61-81](Desktop/internal/core/rule_engine_lists.go#L61)（`UpdateFilterList` 无条件 `e.cfg.Lists[idx].URL = list.URL` 后 `rebuildUnlocked`）、[cmd/service/controller_filter.go:82-96](Desktop/cmd/service/controller_filter.go#L82)（落库同一无校验值）
- **现象**：API 调用方（curl、自动化脚本、第三方集成）POST `{"id":"x","name":"X","enabled":true}` 省略 url → 反序列化为空串 → 该列表 URL 被清空并持久化，此后每轮定时刷新/手动刷新对空 URL 拉取恒失败，该订阅源的全部规则静默消失；HTTP 200「已成功更新」，前端仅在启用开关时（[RuleListsPanel.vue:90-102](Desktop/frontend/src/components/RuleListsPanel.vue#L90)）会带全字段，API 面才是缺口主体。add 有守卫、update 没有，属明显的对称性遗漏。
- **根因**：`FilterList` 全量覆盖式更新，缺"部分更新"语义（指针字段或空值豁免），入口校验又只在 add 落了地。
- **验证方法**：ipc 测试：add 合法列表 → update 不带 url 字段 → 断言 400（当前 200）；再 GET `/api/v1/filter/lists` 见 URL 为空串。

### BUG-31 · 限速热更新 · 低中 · 运行中把限速从关闭改为开启不会启动清理协程：闲置令牌桶只靠 16384 上限内联淘汰，与「启动即开启」行为不一致
- **位置**：[internal/core/rate_limiter.go:104-106](Desktop/internal/core/rate_limiter.go#L104)（`NewRateLimiter` 仅 `cfg.Enabled` 时 `go r.runJanitor(ctx, time.Minute)`）、[:112-147](Desktop/internal/core/rate_limiter.go#L112)（`UpdateConfig` 换 `r.cfg` 却从不(重)启动 janitor）、[:274-298](Desktop/internal/core/rate_limiter.go#L274)（`runJanitor`→`cleanupIdleBuckets` 是唯一按分钟回收闲置桶的路径）、[:217-240](Desktop/internal/core/rate_limiter.go#L217)（兜底为容量达 `maxBuckets=16384` 才内联全表扫描淘汰）、[cmd/service/controller_security.go:52-54](Desktop/cmd/service/controller_security.go#L52)（配置保存路径）
- **现象**：默认（关闭）启动后在界面开启限速：限流本身即刻生效（`Allow` 检查 `r.cfg.Enabled`），但 janitor 缺席——每个来过的客户端 IP 各占一个 `clientBucket` 直至 16384 才触发 O(n) 内联淘汰风暴；同样配置若"先开启再启动"则每分钟准时回收，内存驻留与淘汰抖动两种路径行为分叉。`Allow` 早退（disabled 时直接放行）意味着关闭期间的桶不会增长，但开启时刻的历史桶也无人回收。
- **根因**：janitor 生命周期绑定在构造期的 `cfg.Enabled` 判定，`UpdateConfig` 未纳入其启停（对照 `DNSCache.SyncPersistLoop`——落盘协程就做了按配置重启，注释还特意解释"只在启动时判定一次会同时出现两种不一致"，[internal/core/cache.go:96-98](Desktop/internal/core/cache.go#L96)）。
- **验证方法**：core 包测试：`NewRateLimiter(Enabled:false)` → `UpdateConfig(Enabled:true)` → 注入时钟驱动 100 个 IP 各一发后推进 5 分钟（手动调 `cleanupIdleBuckets` 前），断言桶数衰减——现状不衰减；对照构造即开启的用例则每分钟清空闲置桶。

### BUG-32 · 隐私配置保存 · 低中 · ConfigurePrivacy 先改 `p.cfg.Upstream` 再吞掉 `resolver.Configure` 错误，仍持久化新值并返回成功——磁盘与运行态分叉
- **位置**：[cmd/service/controller_security.go:121-130](Desktop/cmd/service/controller_security.go#L121)（`p.cfg.DNS/Upstream.EDNSPadding = padding` 后 `_ = p.resolver.Configure(p.cfg.Upstream)`），[:145-149](Desktop/cmd/service/controller_security.go#L145)（照常 SaveConfig、返回 nil→200）；引擎错误源 [internal/core/resolver.go:172-173](Desktop/internal/core/resolver.go#L172)（"至少需要一个上游"等校验）
- **现象**：上游处于引擎拒绝的中间状态时（如 BUG-30 清空 URL 后某校验路径、或 bootstrap 配置残缺），保存 EDNS 填充值：运行中的 resolver 保持旧 padding，config.json 已写入新值，UI 显示"已更新"且当前会话行为与重启后不一致。兄弟方法 ConfigureAccess/ConfigureDNS64 都传播引擎错误（[:24-27,:76-79](Desktop/cmd/service/controller_security.go#L24)），唯独此处用 `_ =` 吞掉。
- **根因**：`_ =` 吞错 + "先改共享 cfg 再同步引擎"的顺序使失败时状态半提交。
- **验证方法**：controller 测试：注入零 providers 的 `p.cfg.Upstream`（resolver 已建），`ConfigurePrivacy({ednsPadding:128})` → 断言返回错误且不落盘——当前返回 nil 且落盘。

### BUG-33 · TTL 配置接口 · 低 · Rewrite/Zone/SafeSearch/Hosts 四路 configure 对显式提交的 `ttl<=0` 静默丢弃后仍报「已成功更新」：既不应用也不拒绝，用户以为已保存
- **位置**：[cmd/service/controller_rewrite.go:75-77](Desktop/cmd/service/controller_rewrite.go#L75)、[cmd/service/controller_zone.go:55-57](Desktop/cmd/service/controller_zone.go#L55)、[cmd/service/controller_safesearch.go:40-42](Desktop/cmd/service/controller_safesearch.go#L40)、[cmd/service/controller_security.go:191-193](Desktop/cmd/service/controller_security.go#L191)——同型 `if req.TTL != nil && *req.TTL > 0 { cfg.TTL = *req.TTL }`
- **现象**：`*req.TTL != nil` 说明调用方**明确想改 TTL**，填 0/负数（例如想表达"不缓存/立即过期"，或前端 number 输入清空后提交 0）时该意图被无声吞掉：配置保持旧值、照常落盘、返回成功，GET 回读旧 TTL，用户无从得知请求未被应用。对照加密 DNS 路径（[cmd/service/controller_encrypted.go:121](Desktop/cmd/service/controller_encrypted.go#L121) Normalize 后回显生效值），至少让客户端看得见归一化结果。
- **根因**：`>0` 守卫把"非法值"与"未提供"合并处理；正确姿势是非法值报 400 或归一化后回显。
- **验证方法**：ipc 测试：GET 当前 rewrite TTL → POST `{"ttl":0}` → 期望 400/回显归一化，当前 200 且 GET 值不变（对 zone/safesearch/hosts 各重复一次，同族四处）。

### 观察项（第 6 轮）
- 代理复核清除项（未列缺陷，防后续重复排查）：routes.go 鉴权包裹完整（公开集仅 events/health/meta/auth*/background*/mobileconfig）；上游 weight/protocol 校验闭环（validateProviderList）；ACL 全放行双保险；广播 nil 处理；GetZoneConfig/GetBlockedServices 深拷贝正确。
- `cmd/service/controller_filter.go:94` `_ = config.SaveConfig`——引擎已热更、磁盘可能滞后，属"运行对/落盘错"反向分叉，面窄于 BUG-32，暂列观察。
- BUG-29 修复建议方向（仅记录不改码）：`UpdateConfig` 内按新 MaxEntries 重建分片容量或返回"需重启"明示，二者取其一并保持 API 回显诚实。

---

## 第 7 轮（2026-10-17）— 已扫描模块

已扫描：`internal/core/{rule_engine,rule_engine_build,rule_engine_pause,rule_engine_lists,cache,cache_prefetch,cache_cleaner,cache_types,cache_policy}.go`、`internal/dns/{server_doh,server_doh_writer,server,ddr,ddr_middleware,ede_middleware,edns0,private_ptr_middleware,pipeline,realip,client_id,context,encrypted_config,server_tls_params,filter_response_middleware,rebind_middleware}.go`、`internal/platform/windows/{portcheck_autofix,service_elevate}.go`、`internal/core/{mobileconfig,plist}.go`、`internal/config/store.go`、`cmd/service/{controller,controller_schedule,controller_bg,metrics}.go`。**本轮 8 项中 6 项已用临时 Go 测试实证**（`zz_tmp_*_verify_test.go`，运行后均已删除，不入库），栈/断言输出为直接证据。

### BUG-34 · 规则引擎 · 严重 · GetStats 在读锁内调用会二次取读锁的 currentTime()，与任意排队写者构成永久死锁——整条过滤流水线（进而全部 DNS 查询）冻结
- **位置**：[internal/core/rule_engine.go:155-156](Desktop/internal/core/rule_engine.go#L155)（`GetStats` 持 `e.mu.RLock()` 全程）、[:181](Desktop/internal/core/rule_engine.go#L181)、[:188](Desktop/internal/core/rule_engine.go#L188)（锁内调用 `e.currentTime()`）、[:269-277](Desktop/internal/core/rule_engine.go#L269)（`currentTime` 自身 `e.mu.RLock()/RUnlock()`）；写侧同锁：[internal/core/rule_engine_pause.go:13,30](Desktop/internal/core/rule_engine_pause.go#L13)（`PauseFor/ResumePause`）、[internal/core/rule_engine.go:90](Desktop/internal/core/rule_engine.go#L90)（`SetEnabled`）、UpdateConfig/AddFilterList 等全部 `e.mu.Lock()`
- **现象**：Go 的 `sync.RWMutex` 读者不可重入：一旦写者排队，后续 `RLock` 一律阻塞。`GetStats` 先持有读锁，再在 181/188 行经 `currentTime()` 请求第二把读锁——若此刻有写者排队（如用户拨拦截总开关/点定时暂停），第二把读锁永远等不到（写者又在等 `GetStats` 的第一把读锁释放），**三方环等待、永久死锁**。死锁后所有后续读者（`MatchForGroup`/`IsEnabled`/`CheckHost`——即每一条 DNS 查询的拦截判定）都排在写者之后，整条解析流水线冻结，服务只剩重启可救。触发窗口宽：`GetStats` 由 `/api/v1/status` 与 `/api/v1/filter/stats` 每 3–5 秒轮询一次（[cmd/service/controller_filter.go:19](Desktop/cmd/service/controller_filter.go#L19)、controller_dns.go:261），写者动作是 GUI 上的常规操作；181 行还要求「启用时间计划且有生效计划」、188 行要求「处于定时暂停中」——而暂停状态下的 GUI 恰好在高频轮询统计，两个条件在真实操作中同时常开。
- **根因**：注释（[:178](Desktop/internal/core/rule_engine.go#L178)、[:184](Desktop/internal/core/rule_engine.go#L184)「避免重入加锁，直接内联判定」）说明作者明知重入风险并已把 `pauseStateUnlocked` 内联，却漏掉 `currentTime()` 本身仍是重入点。工程内已有正确姿势：[internal/core/service_schedule.go:96](Desktop/internal/core/service_schedule.go#L96) 在取锁前先 `now := e.currentTime()`。
- **验证方法**：**已实证（临时测试验证后删除）**：启用全天时间计划建引擎，一协程循环 `PauseFor/ResumePause`，另一协程调 `GetStats`——5 秒超时不返回；栈转储显示 `GetStats` goroutine 停在 `sync.RWMutex.RLock`←`currentTime`（rule_engine.go:270）←`GetStats`（rule_engine.go:181），写者 goroutine 停在 `ResumePause` 的 `RWMutex.Lock`（rule_engine_pause.go:30）。可固化为 `internal/core` 带超时的回归测试。

### BUG-35 · 缓存剔除 · 高 · `DNSCache.Remove` 不分组：分组条目的投毒剔除是空操作，被拦应答持续从缓存重放
- **位置**：[internal/core/cache.go:462-481](Desktop/internal/core/cache.go#L462)（[:468](Desktop/internal/core/cache.go#L468) `key := CacheKey(...)` 恒为默认组键）、[internal/core/cache_policy.go:76-96](Desktop/internal/core/cache_policy.go#L76)（分组键为 `domain:qtype:qclass:group`）、调用方 [internal/dns/filter_response_middleware.go:80-82](Desktop/internal/dns/filter_response_middleware.go#L80)（响应侧别名链拦截后「同步剔除缓存中被投毒的条目」）、[internal/dns/rebind_middleware.go:205-208](Desktop/internal/dns/rebind_middleware.go#L205)（rebinding 拦截同样调 `c.Remove(ctx.Req)`）；写入侧分组感知：[internal/dns/cache_middleware.go:62,81](Desktop/internal/dns/cache_middleware.go#L62)（`PutForGroup`）
- **现象**：启用客户端分组后，非默认组的查询结果存在带组后缀的键下；两条安全语义的剔除路径（CNAME 换域投毒复检、rebinding 私网地址复检）都调无组参的 `Remove`，删的是默认组键上大概率不存在的条目——**被判定拦截的应答继续留在组缓存里，直到自然过期都在重放**，拦截只在未命中缓存时生效一次。与 BUG-27 同属「分组隔离在旁路功能上陆续漏配」。
- **根因**：`Put/Get` 组感知改造时，`Remove` 未跟进（无 `RemoveForGroup`，`cacheEntry` 也未存 group 供反查）。
- **验证方法**：**已实证（临时测试验证后删除）**：`PutForGroup(req,resp,"kids")` → `Remove(req)` 返回 **false** → `GetForGroup(req,"kids")` 仍命中。断言输出记录键形如 `"evil.example:1:1:kids"` vs `"evil.example:1:1"`。

### BUG-36 · 缓存预取 · 中 · 预取按分组键挑出候选、却用全局解析器回源并写进默认组键：分组热点永不刷新、默认组无端多收答案
- **位置**：[internal/core/cache_prefetch.go:112-118](Desktop/internal/core/cache_prefetch.go#L112)（`c.flight.Do(e.key, …)` 用分组键防抖，回调里 `c.Put(req, resp)` 写默认组键）、[:65-75](Desktop/internal/core/cache_prefetch.go#L65)（`buildPrefetchRequest` 不带组）、[:89](Desktop/internal/core/cache_prefetch.go#L89) 与 [cmd/service/main.go:141](Desktop/cmd/service/main.go#L141)（prefetcher 恒为全局 `CoreResolver`，不经 `ExchangeForGroup`）；对照正确姿势 [internal/dns/cache_middleware.go:62](Desktop/internal/dns/cache_middleware.go#L62)（SWR 刷新 `PutForGroup(reqCopy, freshResp, group)`）
- **现象**：开启主动预取+客户端分组后：(a) 分组热点条目每次 tick 都被选中、回源、然后把结果写到**别的键**上——原条目照常过期，预取对分组查询完全无效（每 30s 反复空耗一次上游）；(b) 默认组键被非默认组流量引发的预取无端写满，未启用分组时才有该条目内容的语义被打破；(c) 有分组专属上游时，预取拿到的是默认上游的答案，与「分组可能被路由到不同上游」（[internal/core/cache_policy.go:80-84](Desktop/internal/core/cache_policy.go#L80)）的隔离前提冲突。
- **根因**：`cacheEntry.key` 是完整分组键但条目不单独存 group，预取回调图省事走了 `Put`（默认组）而非解析/携带组信息。
- **验证方法**：**已实证（临时测试验证后删除）**：`kids` 组种一条临近过期热点 → `prefetchHotEntries` → 断言 `"hot.example:1:1:kids"` 未被刷新、`"hot.example:1:1"` 凭空出现新条目。

### BUG-37 · 规则引擎热更新 · 中 · UpdateConfig 的免重建判定只比订阅列表的**条数**：停用/改 URL/调序一律不重建匹配器，配置与运行态分叉
- **位置**：[internal/core/rule_engine.go:135-144](Desktop/internal/core/rule_engine.go#L135)（`len(old.Lists) == len(cfg.Lists)` 即视为未变，提前 `return nil` 跳过 `rebuildUnlocked`）；对照 :132-134 的注释——「服务选择必须逐项比对：勾一个换掉另一个时长度不变，只看长度会漏掉这次变更」（CustomRules/BlockedServices/BlockedServiceGroups 都用了 `equalStrings` 逐项比，唯独 `Lists` 退回比长度）；写库与回显路径 [cmd/service/controller_filter.go:37-51](Desktop/cmd/service/controller_filter.go#L37)
- **现象**：任何以「全量配置 POST」形式修改 `lists` 内容（同一列表 `enabled` 翻转、URL 替换、顺序调整——条数不变）的请求：`e.cfg` 被更新（UI 下次 GET 显示新状态）、config.json 落盘，但匹配器不重建——**界面显示已停用的订阅列表继续拦截、显示已启用的列表继续沉默**，直到小时级定时刷新或手动 `RefreshList/RefreshAllLists` 恰好触发重建才收敛。API 文档化的全量提交（curl/第三方自动化按 GET→改→POST 的自然用法）与任何未来的前端整表保存路径都会踩中。
- **根因**：变更检测用长度代理内容，与自己注释里刚批判过的错误同型；`FilterList` 无逐项比较器。
- **验证方法**：**已实证（临时测试验证后删除）**：建引擎含 1 条启用列表（规则文件落临时目录）→ `UpdateConfig` 仅把 `Lists[0].Enabled` 改为 false → `CheckHost("blocked.example")` 仍返回 `block`。

### BUG-38 · 加密 DNS/DoH · 高 · DoHPath 未做字符校验直入 http.ServeMux 模式注册，畸形路径同步 panic：当次保存毒化配置，服务下次启动即崩溃（启动即死循环）
- **位置**：[internal/dns/server_doh.go:155-160](Desktop/internal/dns/server_doh.go#L155)（`mux.HandleFunc("GET "+path+"/{ClientID}", …)` 等四条，Go≥1.22 模式语法对非法 pattern **panic**）、[:79-92](Desktop/internal/dns/server_doh.go#L79)（`normalizeDoHPath` 只补前导 `/`、去尾部 `/`，不收敛内部 `//`、不拒绝 `{`/`}`）、[:121-122](Desktop/internal/dns/server_doh.go#L121)（`startDoH` 内同步注册）；上游无归一化：[internal/core/encrypted_types.go:198-202](Desktop/internal/core/encrypted_types.go#L198)（仅 TrimSpace/补斜杠）、[cmd/service/controller_encrypted.go:110-112](Desktop/cmd/service/controller_encrypted.go#L110)（界面值原样写入）；触发链 [cmd/service/controller_encrypted.go:143-148](Desktop/cmd/service/controller_encrypted.go#L143)（先 `p.cfg.Encrypted = cfg`＋**持久化**，再 `reloadDNSWithCurrentConfig`）；崩溃面：[cmd/service/main.go:76-80](Desktop/cmd/service/main.go#L76)（`run()` 在裸 goroutine 中）→ [internal/dns/server.go:254-258](Desktop/internal/dns/server.go#L254)（启动路径 `startDoH` 的 panic 不被任何 recover 兜住——全仓 `recover()` 仅存在于 [internal/core/cache_flight.go](Desktop/internal/core/cache_flight.go)）
- **现象**：用户在加密 DNS 面板的 DoH 路径里填 `/dns//query` 或含 `{` 的名字并保存：保存请求的 HTTP 协程中 `ReloadEncrypted→startDoH` panic——net/http 对 handler panic 有兜底，当次只是连接中断、旧监听器已被关而新 DoH/DoQ 没起来（DoH 静默瘫痪）；**但坏值已经先写进 config.json**。此后服务每次启动走到 `Start()` 的「加密监听是附加能力，绑定失败只记日志」分支时，`startDoH` 不是返回 error 而是**同步 panic**，启动协程无人 recover → 进程崩溃；Windows 服务恢复策略会反复拉起再崩，表现为「更新一次路径设置后，DNS 服务再也起不来」，且 UI/托盘都进不去，只能手改配置文件。
- **根因**：把用户输入直接拼接进会 panic 的 API（`ServeMux` 模式串）；「加密监听失败不影响主链路」的容错设计只覆盖了返回 error 的路径，没覆盖 panic。
- **验证方法**：**已实证（临时测试验证后删除）**：`registerDoHRoutes(mux, "/a//b", …)` panic：`non-CONNECT pattern with unclean path can never match`；`"/dns{query"` panic：`bad wildcard segment`；`"/{ClientID}"` panic：`duplicate wildcard name "ClientID"`（第二条路由拼出 `{ClientID}/{ClientID}`）。实机等价路径：界面改 DoH 路径为 `/x//y` 保存 → 服务日志出现 panic 栈。

### BUG-39 · 加密 DNS/DoH · 中 · DoH GET 分支绕过自家 dohMaxBody 上限（仅 1 MiB 头部兜底），且两条分支都不按 RFC 8484 校验 QDCOUNT/QR
- **位置**：[internal/dns/server_doh.go:22-26](Desktop/internal/dns/server_doh.go#L22)（注释声明「不设上限的话…把内存吃光」，`dohMaxBody=65536+512`）、[:248-258](Desktop/internal/dns/server_doh.go#L248)（`readDoHQuery` GET 分支 `base64url(?dns=)` 解码**无任何尺寸检查**，直入 `Unpack`）、[:264-273](Desktop/internal/dns/server_doh.go#L264)（POST 才有 `LimitReader(dohMaxBody+1)`+超限报错）、[startDoH 的 http.Server :129-134](Desktop/internal/dns/server_doh.go#L129)（未设 `MaxHeaderBytes`，默认 1 MiB——即 GET 单请求实际可带约 750 KB 解码报文，约为目标上限的 12 倍）；报文合法性校验缺失：`serveDoH`/流水线各中间件仅判 `len(Question)==0` 早退放行，[internal/dns/forwarder.go:23](Desktop/internal/dns/forwarder.go#L23) 把**原样的**非法报文（0 题/多题/QR=1 的响应型报文）打包发往上游。
- **现象**：(a) 匿名 DoH 客户端用 GET 灌大报文，绕开代码自我声明的 64 KiB 上限，放大 Unpack/内存开销；(b) 多题查询只有 Question[0] 被过滤/缓存/改写，其余题被原样透传上游——上游多数会静默丢弃，但本机日志与拦截判定只覆盖第一题，形成「拦不住第二题」的假阴性；(c) `QR=1`/`OPCODE≠QUERY` 报文照常走完整流水线。RFC 8484 §4.1/§6 要求 DoH 服务器对不合语法报文返回 400。
- **根因**：尺寸守卫只写在了 POST 分支；协议合法性校验从未落地（各中间件的零题早退是给内部路径兜底，不构成入口防御）。
- **验证方法**：代码断言：`readDoHQuery` GET 分支无长度判据（对照 POST :264-270 有三行守卫）；构造 `SetQuestion` 后手工追加第二个 `Question` 的报文 POST 给包内 DoH，现状 200 且第二题随原报文出网（修复预期 400）。

### BUG-40 · 加密 DNS/DDR · 低中 · DDR 的 SVCB 应答不携带 EDNS(0) OPT——按 RFC 9460/6891 合规客户端将丢弃整条应答
- **位置**：[internal/dns/ddr.go:52-100](Desktop/internal/dns/ddr.go#L52)（`resp.SetReply(req)` 后只追加 SVCB；miekg/dns 的 `SetReply` 不复制 OPT——已实测）、[internal/dns/server.go:322-337](Desktop/internal/dns/server.go#L322)（收尾只借用 `r.IsEdns0()` 定截断尺寸，不回填 OPT）、[internal/dns/ede_middleware.go:23-28](Desktop/internal/dns/ede_middleware.go#L23)（唯一会补 OPT 的 EDE 中间件只在拦截/错误分支触发，DDR 成功应答不属于任何分支）
- **现象**：DoT/DoH 入口对 `_dns.resolver.arpa SVCB` 返回 NOERROR+ANSWER，**EXTRA 无 OPT**。SVCB(RRType 64) 按 RFC 9460 仅在 EDNS(0) 下有意义；RFC 6891 §6.2.1 把「应答缺 OPT」视为 responder 不支持 EDNS 的信号，严格实现的 DDR 消费方（Chrome/Android 的 automatic-secure-network 栈普遍要求带 OPT 的应答）会把这份 SVCB 当作不合规丢弃——本机明明开着 DoH/DoT 并在广播，客户端却探测不到、不升级。属可抓包实证的互操作性缺陷；代码事实（应答无 OPT）已由测试钉死，客户端侧后果为协议标准推断，故定级低中。
- **根因**：DDR 应答手工组装，没走「复制请求 OPT」或统一 EDNS 收尾路径。
- **验证方法**：**已实证（临时测试验证后删除）**：带 OPT 的请求进 `BuildDDRResponse`，返回报文 `resp.IsEdns0()==nil`。实机可在 DoH 端口抓包核对 SVCB 应答 EXTRA 段。

### BUG-41 · DNS/PrivatePTR · 低 · 私网反向查询的权威 NXDOMAIN 把 SOA 属主写成查询全名而非控制区顶点，负缓存语义被破坏
- **位置**：[internal/dns/private_ptr_middleware.go:179-197](Desktop/internal/dns/private_ptr_middleware.go#L179)（`soaZone := q.Name`——直接取 `1.2.168.192.in-addr.arpa.` 这种叶子名做 SOA 属主）
- **现象**：RFC 2308 §3/§4 要求否定应答的 AUTHORITY SOA 属主为「与查询名最佳匹配的区顶点」；把 SOA 安在查询名自身等于声称每个主机名都是一个区的起点，递归解析器做属主一致性校验时不会采纳该 TTL，私网 PTR 的 NXDOMAIN **无法负缓存**，每个客户端每条连接都重新打进来一次——功能上仍能拦，但把「本地权威应答」的省流量收益全数退掉。AA=1/NXDOMAIN 本身正确，属协议语义缺陷而非崩溃类。
- **根因**：合成本地权威应答时按查询名回填 SOA，未从命中的私网反解后缀（`privateReverseSuffixes`）推出区顶点。
- **验证方法**：包内测试：对 `1.2.168.192.in-addr.arpa. PTR` 取 `ctx.Resp.Ns[0].(*dns.SOA).Hdr.Name`，期望 `168.192.in-addr.arpa.`（修复后），现状等于查询名。

### 观察项（第 7 轮，暂不计为独立缺陷）
- [internal/platform/windows/portcheck_autofix.go:45-56](Desktop/internal/platform/windows/portcheck_autofix.go#L45)：ICS 自愈把 SharedAccess 启动类型改成「禁用」后**无任何恢复路径**，且失败被 `_ = errConfig` 吞掉；UI 文案只说「停止占用」，用户事后无法从本机恢复 ICS（要动注册表/服务管理）。语义是刻意的「防自动复活」，但不可逆+静默失败建议产品复核。
- [cmd/service/controller.go:183-195](Desktop/cmd/service/controller.go#L183)：TestUpstream 的 DOH 分支每次点击新建 `http.Transport` 且不 `CloseIdleConnections`——测试按钮触发的空闲连接与协程驻留到 GC；单次操作量级小，暂列观察。
- [internal/core/mobileconfig.go](Desktop/internal/core/mobileconfig.go) / [internal/core/plist.go](Desktop/internal/core/plist.go)：逐行核过——XML 转义完整（含 C0 控制字符丢弃）、DoH URL 前缀强校验、UUID 稳定复用，无缺陷。
- [internal/config/store.go:86-90](Desktop/internal/config/store.go#L86)：先 `os.Remove(path)` 再 `Rename`——两次写之间断电会留下「主文件缺失、`.tmp` 完整」的窗口，载入时按「文件不存在」静默回落默认配置（丢全部设置）。有 `storeMu` 与 0644 兜底，触发窗口极窄，列观察。
- 代理已排查并排除（防后续重复翻查）：`pipeline.go`（Execute 快照+递归形态正确）、`client_id.go`（越界与连字符位校验到位）、`realip.go`（TrustedProxy 构造后只读、XFF 右起扫描正确）、`context.go`、`server_doh_writer.go`（WriteMsg 已 Copy）、`server_tls_params.go`、`ratelimit_middleware.go`、`access_middleware.go`；`edns0.go` 的 v4-in-v6 自定义子网族错配与 `doq_conn.go` 的 writeMu 外 Close 均不够实锤，弃报。
- 代理报告中「预取导致跨组应答污染」的表述经复核**偏强**：预取回源走的是全局解析器，写入默认组的值与默认组自查一致，实际危害为「分组预取失效+无谓回源+隔离前提被架空」，已按修正后的表述记入 BUG-36。

---

## 第 8 轮（2026-10-17）— 已扫描模块

已扫描：`internal/auth/auth.go`（防爆破锁定键源）、`internal/ipc/{server_static,server_web,server_filter_pause,server_cache,server_rewrite,server_zone,server_security,server_services,server_safebrowsing,server_encrypted,server_safesearch,server_schedule,server_querylog,server_filter}.go`、`internal/core/{dns64,rule_engine_pause,safesearch,safesearch_rules,access_control,rule_list_fetch,schedule,rule_parser,rule_matcher,rule_modifiers,rule_trie,rule_bloom,custom_zone,ecs_types,tls_pin}.go`、`internal/dns/{dns64_middleware,realip,edns0,server_doq,server_dot,server_doh,safesearch_middleware,any_middleware,ipv6_middleware,sudn_middleware,unqualified_middleware,hosts_middleware,bogus_nxdomain_middleware,ecs_middleware,ech_middleware,zone_middleware}.go`、`cmd/service/{controller_schedule,controller_pipeline,controller_services,controller_portcheck,controller_security,controller_dot,controller_dns,controller,controller_filter,controller_cache}.go`、`internal/platform/{state,netutil,ports,executor}.go`、`internal/ipc/server_stamp.go`、`internal/ipc/server_ws.go`（runHub 复核维持第 2 轮判定）、`internal/platform/linux/{portcheck,portcheck_owner,portcheck_proc,portcheck_autofix,backend_resolved,autostart,takeover(增补),backend(增补),net,files,privilege,adapter}.go`（Linux 平台层深扫代理结果已逐条对照源码复核后并入，BUG-46~50）、`frontend/src/{api/{cache,screenshot,filter,ws,types}.ts,utils/env.ts,App.vue,main.ts,components/accel/CachePanel.vue,components/network/ClientGroupsCard.vue}`（前端 api/入口层代理深扫结果逐条源码复核后并入 BUG-53~55）、`internal/core/resolver_{dot,doh,doq}.go`＋`internal/core/tls_pin.go`（上游传输层，本轮自扫未见足以立条缺陷）。**本轮自扫项全部经临时 Go 测试实证**（`zz_tmp_*_verify_test.go`，运行后均已删除，不入库）；Linux/前端条目为对代理报告的源码复核 + 权威文档核验（systemd-resolved(8) 手册确认无 PIDFile），附实机/构建复现步骤。Windows 平台层代理深扫仍在进行，结果下一轮并入。

### BUG-42 · IPC/Web 鉴权 · 高 · Web 模式登录防爆破锁定键取自可伪造的 X-Forwarded-For：攻击者可无限次尝试口令，还可反向锁死真实用户
- **位置**：[internal/ipc/server_static.go:126-141](Desktop/internal/ipc/server_static.go#L126)（`getClientIP` 无条件采信 `X-Forwarded-For` 首段，其次 `X-Real-IP`，最后才回退 `RemoteAddr`——**没有任何可信代理判定**）、[internal/ipc/server_web.go:34](Desktop/internal/ipc/server_web.go#L34)（登录处理把该值直接作为 `clientIP` 传给 `Login`）、[internal/auth/auth.go:172-222](Desktop/internal/auth/auth.go#L172)（`ipAttempts`/`ipLockedUntil` 全部以传入的 clientIP 为键；阈值 MaxFailedAttempts=5、锁定 5 分钟，判定见 :183-198）
- **现象**：开启 Web 局域网模式后（该模式的存在意义就是让非本机设备访问），任意 LAN 客户端对 `/api/v1/auth/login` 的口令爆破**每次请求换一个 `X-Forwarded-For: <随机 IP>` 头**即可让失败计数永远落在不同的键上，5 次锁定阈值形同虚设，SHA-256+盐口令可离线节奏不受限地在线碰撞。反向同样成立：攻击者拿受害者真实 IP 当 XFF 值连错 5 次，就能把该局域网用户在 5 分钟窗口内锁在门外（针对特定机口的 DoS）。对照：[internal/dns/realip.go](Desktop/internal/dns/realip.go) 为 DNS 侧 DoH 实现的 TrustedProxy「默认不信、右起扫描」是正确姿势——同一仓库里两处对同一转发头的信任标准不一致，IPC 侧选择了完全信任。
- **根因**：登录锁定键直接采信可伪造头部，未复用/参照 DNS 侧已有的可信代理判定；IPC 服务在桌面/Web 模式下都是**直连**（无自有反代），本就不该解析任何转发头。
- **验证方法**：**已实证（临时测试验证后删除）**：`getClientIP` 收到 `X-Forwarded-For: 8.8.8.8, 10.0.0.1`（RemoteAddr=127.0.0.1:54321）返回 **`8.8.8.8`**，`X-Real-IP` 同理；结合 auth 侧实证（见 BUG-43：以 1000 个不同来源键各失败一次，`ipAttempts` 累积 1001 个键、无一键触发锁定）即构成完整绕过链。实机：`curl -X POST http://<host>:15353/api/v1/auth/login -H 'X-Forwarded-For: 1.2.3.4' -d '{"username":"admin","password":"wrong"}'` 每次换 XFF 值，观察 `GetStatus` 永不出现锁定标志。

### BUG-43 · IPC/Web 鉴权 · 中 · 登录失败计数与锁定表以任意可伪造字符串为键且无上限、无过期回收：内存无限增长（资源耗尽）
- **位置**：[internal/auth/auth.go:172-222](Desktop/internal/auth/auth.go#L172)（`ipAttempts[clientIP]++`、`ipLockedUntil[clientIP]=...`，两 map 无容量上限；仅登录**成功**时才 delete（:205-206），失败的键永不删除；`ipLockedUntil` 过期后下次读取该键才会覆盖，但无人读取的过期键**永不回收**）、键源同 BUG-42 的 `getClientIP`
- **现象**：与 BUG-42 同键源、不同缺陷：攻击者每次请求携带新的伪造 XFF，服务端就新增一个 map 项——每个唯一键一次失败登录即永久驻留一条 `int` 计数（外加锁定期一条时间戳）。长时间运行 + 任意速率的失败登录洪水使 auth 结构无上限膨胀（无淘汰、无 LRU、无定时清扫），且 IPC 服务进程与 DNS 核心同进程，最终拖垮整个桌面应用。修复 BUG-42（改用 RemoteAddr）可把键空间收敛到真实对端数，但**合法 LAN 用户规模下的过期键不回收问题仍在**，两处都需要治理。
- **根因**：把可伪造输入当身份键的同时又把它当**持久存储**键；缺少容量上限与过期清扫。
- **验证方法**：**已实证（临时测试验证后删除）**：`internal/auth` 包内对 `Login` 灌 1000 个不同 `clientIP` 各失败一次 → `ipAttempts` 长度 **1001**（含内部默认键），全部留存、无一被锁定回收；断言输出记录 map 长度。
- **关联**：键源缺陷见 BUG-42（修复顺序建议同源一并处理）。

### BUG-44 · DNS64 合成 · 中 · **问题不存在** · EmbedIPv4InIPv6 对 /40、/48、/56 前缀的字节布局违反 RFC 6052 Table 2：合成的 AAAA 指向错误 IPv4，NAT64 流量黑洞化

> **【第 10 轮复核：误报，无需修复】** 原判定把 RFC 6052 §2.2 读成「IPv4 紧随前缀连续、u 在其后」，实际规范规定 **u 字节固定在 bits 64–71（byte 8）**，/32–/64 前缀下 IPv4 本就被 u 分隔（代码注释的 case 描述与规范自洽）。以 RFC Table 1/2 官方样例向量（192.0.2.33×六种前缀）逐一对账，`EmbedIPv4InIPv6` 输出六例全部逐字命中——实现正确，缺陷不存在。原记录按「保留原有记录」原则不作删改，详见下文《第 10 轮》专节。

- **位置**：[internal/core/dns64.go:110-161](Desktop/internal/core/dns64.go#L110)（`EmbedIPv4InIPv6`：case 56 把 IPv4 拆成 `v6[7]=v4[0]`、零填充 `v6[8]`、`copy(v6[9:12], v4[1:4])`——**零字节插在 IPv4 中间**；case 48/case 40 同样以 `v6[8]=0` 把本应连续的 4 字节 IPv4 拦腰截断。RFC 6052 §2.2 Table 2 规定 IPv4 必须**紧随前缀连续放置**，u 字节位于 IPv4 **之后**（/56 为 byte11、/48 为 byte10、/40 为 byte9），且合成前缀已入排除集（:78），错误结果不会再被拦截修正）；调用方 [internal/core/dns64.go:248-262](Desktop/internal/core/dns64.go#L248)（`SynthesizeFromAWithTTL` 对所有已配置前缀逐一嵌入）与 [internal/dns/dns64_middleware.go:89](Desktop/internal/dns/dns64_middleware.go#L89)
- **现象**：使用非默认前缀长度（自定义 NAT64 部署常见的 /64 之外的 /48、/40、/56，以及运营商级 /32）时：/32、/64、/96 三种布局正确；/40、/48、/56 合成出的 AAAA 与 NAT64 网关按 RFC 6052 反解出的 IPv4 **不是同一个地址**——IPv6-only 客户端拿到“看似正确格式、实为错址”的合成记录，连接黑洞且无任何日志提示（合成链路本身成功）。默认 `64:ff9b::/96` 不受影响，故定级中。工程内既有测试只断言「byte8==0」（[internal/core/dns64_test.go:122-127](Desktop/internal/core/dns64_test.go#L122)），恰好被错误实现满足（代码正是在 byte8 塞零），所以单测全绿掩盖了布局错误。
- **根因**：把「u 必须为 0」误写成「IPv4 拆两半、中间垫 0」；/56、/48、/40 三个 case 的注释与实现均按错误布局自述（如 case 56 注释「IPv4[0] | u(8) | IPv4[1-3]」），属对 Table 2 的系统性误读而非笔误。
- **验证方法**：**已实证（临时测试验证后删除）**：`EmbedIPv4InIPv6(192.0.2.1, …)`：/40 得 `2001:0db8:00c0:0002:0001:0000:0000:0000`，RFC 6052 Table 2 期望 `2001:0db8:00c0:0002:0100:…`；/48 得 `2001:0db8:0001:c000:0002:0100:0000:0000`，期望 `2001:0db8:0001:c000:0201:0000:0000:0000`；/56 得 `2001:0db8:0001:00c0:0000:0201:0000:0000`，期望 `2001:0db8:0001:00c0:0002:0100:0000:0000`（三例 u 均在 byte8 而非 IPv4 之后）；/32、/64、/96 三例与期望一致。

### BUG-45 · 拦截暂停 · 中低 · SetFilterPause 对 durationSec 零校验：负值与乘算溢出值被静默解释为「暂停至手动恢复」，定时暂停变成事实上的永久关过滤
- **位置**：[internal/ipc/server_filter_pause.go:24-36](Desktop/internal/ipc/server_filter_pause.go#L24)（POST 仅反序列化，无范围校验）、[cmd/service/controller_schedule.go:97-98](Desktop/cmd/service/controller_schedule.go#L97)（`engine.PauseFor(time.Duration(req.DurationSec) * time.Second)`，int64 秒→纳秒乘算可溢出为负）、[internal/core/rule_engine_pause.go:20-24](Desktop/internal/core/rule_engine_pause.go#L20)（`d <= 0` 一律落到「100 年哨兵值＝暂停至手动恢复」）；对照语义契约 [internal/ipc/types.go:385-387](Desktop/internal/ipc/types.go#L385)（仅 **0** 被文档化为「暂停至手动恢复」）
- **现象**：`durationSec` 为负数（如客户端笔误 `-1`）或大到溢出（≥ 约 9.22e9，如 `18446744073`、`10000000000`）时，换算出的 Duration ≤0，与“永久暂停”的 0 值语义**不可区分**：API 返回成功、UI 显示「拦截已暂停」，但到期自动恢复永不发生——过滤整体关闭直到手动恢复或进程重启（fail-open，且 [frontend/src/components/rules/RulesPanel.vue:286](Desktop/frontend/src/components/rules/RulesPanel.vue#L286) 的 GUI 只发合法值，受害面是文档化全量 API/第三方自动化脚本）。附带：暂停后 `GetFilterPause` 回显剩余 ≈876000 小时，前端 [RulesPanel.vue:85](Desktop/frontend/src/components/rules/RulesPanel.vue#L85) 显示「36500 天」的荒谬倒计时，也是该状态的可见信号缺失。与 BUG-1 叠加时（本机任意进程/恶意网页免鉴权可调 API），“恶意永久关过滤”路径已经存在，本条的独立价值是：**合法调用方的错误输入也会静默退化成安全关闭**，应返回 400 而非 100 年。
- **根因**：把「0＝永久」的实现便利当成了对所有非正 Duration 的输入契约；入口没有 `durationSec >= 0 && 不溢出` 的校验。
- **验证方法**：**已实证（临时测试验证后删除）**：`internal/core` 包内对新建引擎依次 `PauseFor(time.Duration(n)*time.Second)`（运行时乘法，n∈{-1, 0, 18446744073, 10000000000}）→ `PauseState()` 四例全部 `paused=true、remaining≈876000h（100 年哨兵）`，断言输出记录 `-1s/0s/-709.55ms/-2346317h` 四种溢出形态均落入同一永久分支。

### BUG-46 · 平台/Linux 端口检测 · 中 · inode→PID 归属表构建时把本进程整体排除，`isSelf` 判定永不为真：自身监听被诊断为「无法定位的第三方冲突」
- **位置**：[internal/platform/linux/portcheck_owner.go:25-35](Desktop/internal/platform/linux/portcheck_owner.go#L25)（`pid == self → continue`——本进程的 socket fd 从不登记进 owners 表）、[internal/platform/linux/portcheck.go:83-103](Desktop/internal/platform/linux/portcheck.go#L83)（`pid := owners[s.Inode]` 对自身 socket 恒得 0 → `isSelf := pid == selfPID` 恒 false → 落入 `default:`「占用进程无法定位」）、[internal/platform/linux/portcheck.go:137-153](Desktop/internal/platform/linux/portcheck.go#L137)（`hasSelfListener` 永不置真，`socketsFree` 又因自身占用为 false → `Available=false` 且计入 `hasThirdPartyConflict`）
- **现象**：DNS 服务运行中（自身监听 127.0.0.1:53）时点 GUI「检测端口冲突」（`/api/v1/portcheck` → [cmd/service/controller_portcheck.go:10-24](Desktop/cmd/service/controller_portcheck.go#L10)）：应用把自己的监听诊断为「占用进程无法定位（可能属于其他用户或已退出）」的第三方冲突，`Available=false、CanAutofix=false`——用户被告知端口被不明程序抢走；同状态下点「一键自动修复」更直接返回错误「检测到第三方程序占用 53 端口，无法自动修复」（portcheck_autofix.go:31-33 判 HasICS=false 即报错）。代码里 `case isSelf:` 的「谛听核心服务监听中」分支（portcheck.go:101-103）与 `hasSelfListener` 兜底（:151）是永久死代码。排除自身若是为省全盘扫描开销，正确做法至少是对 `/proc/self/fd` 单独采集登记——现状是「先把自己抹掉、再指望检出自己」的自相矛盾。
- **根因**：用「跳过 self」优化扫描，却把 self 的 socket 归属信息一并抹掉，下游 `pid == selfPID` 判定因此永远失去输入。
- **验证方法**：Linux 实机：`sudo diting-service -run`（起 53 监听）后调用 `/api/v1/portcheck`，127.0.0.1:53 条目显示 PID 0/「无法定位」而非「谛听核心服务监听中」；或在 Linux 上写临时测试绑定 127.0.0.1:53 后调 `inspectPort53Listeners()`，断言 `conflict.IsSelf`（现状恒 false，owners 表无自身 inode）。

### BUG-47 · 平台/Linux stub 检测 · 中低 · systemd-resolved 的 PID 取自它从不创建的 `/run/systemd/resolve/resolved.pid`：pidfile 检测路径恒零
- **位置**：[internal/platform/linux/portcheck_owner.go:82-93](Desktop/internal/platform/linux/portcheck_owner.go#L82)（`os.ReadFile("/run/systemd/resolve/resolved.pid")`，失败即返回 0）；消费方 [internal/platform/linux/portcheck.go:71,86-88](Desktop/internal/platform/linux/portcheck.go#L71)（`resolvedPID != 0 && pid == resolvedPID` 分支永不成立）、[internal/platform/linux/portcheck_autofix.go:77-86](Desktop/internal/platform/linux/portcheck_autofix.go#L77)（`stopResolvedStubProcess` 首行 `pid == 0 → return nil`——回退终止恒空操作且**返回成功**，与 BUG-49 联动）
- **现象**：systemd-resolved 是 Type=notify 服务，**不写 PIDFile**；其运行时目录仅含 `stub-resolv.conf`、`resolv.conf` 与 Varlink socket（systemd-resolved(8) 手册核实无任何 .pid 产物，本次已在线核对）。于是 resolvedPID 恒 0：stub 识别只剩「地址字面量 127.0.0.53/54」与进程名比对两条路——而进程名比对需要 owners 表命中，恰被 BUG-46（无权限扫他人进程时 owners 为空、或本进程被排除）削弱；兜底 kill 路径整体失效。后果链见 BUG-49：自动修复在 WSL/无 systemd 单元环境下谎报成功。
- **根因**：对 resolved 的实现形态（notify 服务无 pidfile）判断错误，选择了不存在的文件作为 PID 来源。健壮来源应为 Varlink/`systemctl show --property=MainPID systemd-resolved` 或owners 表内的进程名命中。
- **验证方法**：Linux 实机：`ls /run/systemd/resolve/` 无 resolved.pid；`sudo systemctl show systemd-resolved -p MainPID` 有值而代码路径恒 0。包内测试：`systemdResolvedPID()` 在 resolved 运行中的机器上断言非零——恒失败。

### BUG-48 · 平台/Linux resolved 接管 · 中 · resolvedBackend.Apply 中途失败时回退范围漏掉「dns 已改、domain 未改」的当前网卡；单卡接管路径还整体缺回退
- **位置**：[internal/platform/linux/backend_resolved.go:33-51](Desktop/internal/platform/linux/backend_resolved.go#L33)（`resolvectl dns iface 127.0.0.1 ::1` 成功后 `resolvectl domain iface ~.` 失败 → `rollbackApplied(ctx, applied)` 只回退**之前已完成**的网卡，当前 `a` 要两条命令都成功才进 applied——已改 DNS 的它恰好不在内）、[:54-66](Desktop/internal/platform/linux/backend_resolved.go#L54)（回退仅遍历入参列表）、[internal/platform/linux/backend.go:44](Desktop/internal/platform/linux/backend.go#L44)（接口契约明文「保证 Apply 失败时不留下半成品状态」）、[internal/platform/linux/takeover.go:147-172](Desktop/internal/platform/linux/takeover.go#L147)（**TakeoverSingle 路径**：Apply 失败只回滚内存状态与 stateStore，不调 `backend.Restore`——多卡 Takeover 在 :96-98 有 `m.backend.Restore(ctx, states)` 兜底，单卡路径连这层补偿都没有）
- **现象**：dbus 瞬断等使 `domain` 调用失败时，该网卡 DNS 永久指向 127.0.0.1/::1；单卡接管场景下这个半成品状态就是终态——**该链路的系统解析直接黑洞化**（本机监听器若还没起或已停，域名全挂），且 Apply 返回的是「设置域名路由失败」而非还原失败，用户无从察觉 DNS 已被改走。违反自述契约。
- **根因**：`applied` 以「网卡全完成」为登记粒度而非「每条已生效的系统变更」，回退粒度与变更粒度不一致；TakeoverSingle 又依赖了多卡路径才有的上层补偿。
- **验证方法**：Linux 实机：`resolvectl dns eth0 127.0.0.1 ::1` 成功、包装器让随后的 `domain` 失败后触发单卡接管 → `resolvectl dns eth0` 仍显示 127.0.0.1。包内测试：注入 CommandExecutor 使 `domain ~.` 调用报错，断言对当前 iface 有 `revert`/dns 还原命令下发（现状无）。

### BUG-49 · 平台/Linux 端口自愈 · 中 · resolved stub 修复失败被链式吞成「成功」：配置已改写而服务未重启，UI 报已修复
- **位置**：[internal/platform/linux/portcheck_autofix.go:49-66](Desktop/internal/platform/linux/portcheck_autofix.go#L49)（`systemctl restart systemd-resolved` 失败 → 走回退；回退 `stopResolvedStubProcess` 因 BUG-47 恒返回 nil → `fallbackErr == nil` → 函数 `return nil` 谎报成功）、[internal/platform/linux/portcheck_autofix.go:18-47](Desktop/internal/platform/linux/portcheck_autofix.go#L18)（上层据 nil 继续复检，`after.Available` 仍 false 时返回 `Available=false` **但 error==nil**）、[cmd/service/controller_portcheck.go:28-55](Desktop/cmd/service/controller_portcheck.go#L28)（`err==nil` → 不报「自动修复失败」，`startDNS` 因 !Available 静默不启动）
- **现象**：WSL2/无 systemd 单元容器中点「一键自动修复」：`/etc/systemd/resolved.conf.d/diting.conf`（DNSStubListener=no）已被写进系统（:55，副作用先于一切验证），restart 失败、回退空转、整体返回成功——stub 仍在监听 127.0.0.53:53，修复动作事实上**从未生效也从未报告失败**；遗留的 drop-in 是对用户系统的、无人知晓的持久改动（卸载说明只写在注释里）。日志/UI 得到的是「端口不可用」的平静结论而非「修复失败」。与 Windows 侧 BUG-10 的吞错清扫同型。
- **根因**：回退函数把「无法定位目标进程」编码成 `nil`（成功语义），与调用方「回退失败才报错」的组合逻辑相矛盾；变更系统配置的步骤又排在可失败性验证之前。
- **验证方法**：Linux 包内测试：注入 executor 使 `systemctl restart` 报错、`systemdResolvedPID()`==0（无需 root）→ 断言 `disableResolvedStubListener` 返回非 nil（现状返回 nil，且 drop-in 写入已发生）。实机：WSL2 GUI 点一键修复，观察 resolved 仍在监听且无错误提示。

### BUG-50 · 平台/Linux 自启 · 低中 · XDG 自启条目 Exec 值不转义不引号：安装路径含空格/`%` 时自启静默失败，UI 仍显示「已启用」
- **位置**：[internal/platform/linux/autostart.go:71](Desktop/internal/platform/linux/autostart.go#L71)（`fmt.Sprintf(...Exec=%s\n..., exePath)` 原样拼入 `os.Executable()`）、[:42-54](Desktop/internal/platform/linux/autostart.go#L42)（`IsEnabled`/`xdgAutoStartPresent` 只 `Stat` 文件存在性，不解析内容）、[:72](Desktop/internal/platform/linux/autostart.go#L72)（`os.WriteFile` 非原子，直接覆写目标）
- **现象**：按 Desktop Entry 规范，Exec 值中空格是 argv 分隔符、`%` 是字段码占位符（`d`/`f`/`F`/`i`/`U` 等）须以 `%%` 转义；路径如 `/home/u/My Apps/diting/diting-service` 会被切成执行 `/home/u/My`，含 `%` 的路径（如镜像目录 `%temp%` 风格命名）被字段码吞掉——桌面会话静默不启动该条目。而 `IsEnabled` 只看文件存在，GUI 自启开关显示「已启用」，用户以为已开机自启。主路径 `/usr/local/bin`、`~/.local/bin` 无空格时不触发，故定级低中。
- **根因**：把可执行路径当安全字面量拼入需要专属转义语法（GSEsc：`\`、`` ` ``、`$`、空格须反斜杠转义）的桌面条目字段；状态判定用存在性代替有效性。
- **验证方法**：Linux 实机：二进制放含空格目录，GUI 开自启 → `grep '^Exec=' ~/.config/autostart/diting.desktop` 看到未加引号空格路径，`journalctl --user | grep -i "no such file"` 可见启动失败，而界面仍显示已启用。包内测试：构造 fake exePath 断言 Exec 行符合规范转义（现状不合规）。

### BUG-51 · 规则解析 · 高 · ParseRuleLine 的行末注释剥离排在 cosmetic 规则过滤之前：`域名##选择器` 类网页过滤规则被降级成「整域 DNS 拦截」规则
- **位置**：[internal/core/rule_parser.go:97-103](Desktop/internal/core/rule_parser.go#L97)（先 `strings.SplitN(line, "#", 2)[0]` 无条件截断第一个 `#` 之后的一切）、[:123-126](Desktop/internal/core/rule_parser.go#L123)（`##`/`#@#`/`#?#` 网页过滤规则的丢弃判定**排在截断之后**，此时 `#` 已不存在，判定恒不成立）；批量入口 [internal/core/rule_parser.go:47-79](Desktop/internal/core/rule_parser.go#L47) 自身仅过滤**行首**为 `!`/`#`/`[` 的注释行，中缀 `##` 原样传入 `ParseRuleLine`，无二次防线
- **根因**：把「行末注释」与「AdGuard 分隔符 `#`」当成同一件事——AdGuard 语法里注释只在**行首**（`!`/`#`/`[`），中缀 `#` 属于元素隐藏/程序规则的分隔标记；顺序颠倒后 `youtube.com##.video-ads` 被截成 `youtube.com`，落进默认分支（:241-244）成为 `||` 同效的全域黑名单。
- **验证方法**：**已实证（临时测试验证后删除）**：`ParseRuleLine("youtube.com##.video-ads","list")` 返回 `ok=true、Pattern=youtube.com、IsAllow=false`；`RuleMatcher.Match("www.youtube.com", A)` 返回 **Blocked=true, Reason=blacklist, MatchedRule="youtube.com##.video-ads"**。`#@#`（重要元素隐藏）与 `#?#`（程序规则）两形式同样漏网并被拦。
- **现象**：订阅任何含元素隐藏/程序规则的列表（EasyList、AdGuard 基础筛选器等主流「广告过滤」列表大量包含 `##` 行；仓库内 [internal/core/safesearch_rules.go](Desktop/internal/core/safesearch_rules.go) 这类 `$dnsrewrite` 写法也提示项目直接消费 AdGuard 格式列表）时，每条 cosmetic 规则都会变成一条**全域拦截规则**：`youtube.com##...` → `youtube.com` 及其全部子域 DNS 被拦。表现为「加了个列表后整站打不开」，且日志里命中规则原文写着带 `##` 的行，用户与运维都无法从界面推断真实原因；这类误杀规模与列表条目数成正比，属高影响正确性缺陷（默认列表为空故出厂不受影响，用户一经订阅即触发）。修复方向：cosmetic/程序规则判定必须在截断注释**之前**，且 AdGuard 语义下应只剥「空格 + `#`」形态的行末注释。

### BUG-52 · IPC 请求体 · 中低 · 17 处 POST 处理器用无上限 `io.ReadAll(r.Body)` 读请求体，服务端又未设任何报文尺寸闸门：本机进程/恶意网页可用大体积请求耗尽内存
- **位置**：无上限读取点（17 处）——[internal/ipc/server_rewrite.go:25,46,77,120,146](Desktop/internal/ipc/server_rewrite.go#L25)、[internal/ipc/server_zone.go:25,62](Desktop/internal/ipc/server_zone.go#L25)（区文本 POST，业务上限 1 MiB 在**读完之后**才校验）、[internal/ipc/server_security.go:15,41,67,93,119,145,171](Desktop/internal/ipc/server_security.go#L15)、[internal/ipc/server_encrypted.go:98](Desktop/internal/ipc/server_encrypted.go#L98)、[internal/ipc/server_safebrowsing.go:23](Desktop/internal/ipc/server_safebrowsing.go#L23)、[internal/ipc/server_services.go:23](Desktop/internal/ipc/server_services.go#L23)；有上限的对照面（13 处）——[internal/ipc/server_filter.go:52,101,131,157,183,213,243](Desktop/internal/ipc/server_filter.go#L52)、[internal/ipc/server_cache.go:118](Desktop/internal/ipc/server_cache.go#L118)、[internal/ipc/server_client_groups.go:22](Desktop/internal/ipc/server_client_groups.go#L22)、[internal/ipc/server_filter_pause.go:25](Desktop/internal/ipc/server_filter_pause.go#L25)、[internal/ipc/server_querylog.go:110](Desktop/internal/ipc/server_querylog.go#L110)、[internal/ipc/server_safesearch.go:27](Desktop/internal/ipc/server_safesearch.go#L27)、[internal/ipc/server_schedule.go:22](Desktop/internal/ipc/server_schedule.go#L22)；服务器无全局闸门：[internal/ipc/server.go:81-85](Desktop/internal/ipc/server.go#L81)（`http.Server` 只设 Read/WriteTimeout，`MaxHeaderBytes` 缺省，且 net/http 本就无请求体上限）
- **现象**：同一 IPC 面内两种姿势并存说明「限量读取」是既定约定，17 处属漏配：POST 任意大的请求体都会被先整块读进内存再进校验（区文本/证书/规则行等所有配置类接口皆如此）。叠加 BUG-1（默认空 token + 回环免鉴权 + CORS 反射），本机任意进程或任意恶意网页（`fetch(url,{method:'POST',body:new Blob([new Uint8Array(512*1024*1024)]),mode:'no-cors'})` 式简单请求即可到达；带自定义头会触发预检、但 Blob 体简单请求无需预检）可用中等速率在 10 s ReadTimeout 窗口内持续灌体积，服务与 DNS 核心同进程，内存峰值完全由攻击者决定。属纵深防御缺失而非必崩缺陷（单次灌满需局域网带宽支撑，Web 模式下跨设备放大面更大），定级中低。
- **根因**：`withAuth` 之后没有统一的 body 尺寸闸门，各 handler 自行其是；`http.MaxBytesReader` 从未被使用。
- **验证方法**：代码断言：`grep -c "io.ReadAll(r.Body)" internal/ipc/server_*.go`（去测试后）得 17 处无 LimitReader 直读，同文件族 13 处用 `io.LimitReader`——同仓库自相矛盾的约定即证据。实机（Web 模式/关鉴权）：`curl --data-binary @bigfile http://host:15353/api/v1/dns/zone/config -X POST`，观察进程 RSS 与体长成比例增长（区内容上限校验在 ReadAll 之后）。修复预期：统一 `io.ReadAll(io.LimitReader(r.Body, N))` 或在 withAuth 层套 `http.MaxBytesReader`。

### BUG-53 · 前端/缓存面板 · 中 · 缓存条目搜索的参数名前后端不一致（发 `q=`、读 `query=`）：搜索框永远返回全量
- **位置**：[frontend/src/api/cache.ts:19](Desktop/frontend/src/api/cache.ts#L19)（`params.set('q', query)`）、[internal/ipc/server_cache.go:35](Desktop/internal/ipc/server_cache.go#L35)（`r.URL.Query().Get("query")`，注释 :29 亦写明 `?query=...`）；后端筛选语义 [internal/core/cache_stats.go:43-63](Desktop/internal/core/cache_stats.go#L43)（`query == ""` 即放行全部条目）
- **现象**：缓存加速页搜索框（[frontend/src/components/accel/CachePanel.vue:120-129](Desktop/frontend/src/components/accel/CachePanel.vue#L120) `handleSearch`，以及 :86/:108 的加载/轮询同样把 `currentSearch` 传下去）输入任何关键字，请求携带 `?q=xxx` 而后端读不到 → 按空串处理 → 列表与「共 N 条」恒为全量；用户以为过滤生效实则每次都是全表，条数不变。轮询路径同样带着永不生效的 search，掩盖问题（刷新后看似正常）。跨端 API 参数名漂移属静默功能失效——两侧各自「正确」，无人报错。
- **根因**：前端封装与后端 handler 无契约测试/共享类型生成，`q` 与 `query` 一字之差无编译期或运行期校验。
- **验证方法**：静态核验两侧字面量（上行引用）即可实证；手动复现：Web 模式打开缓存面板，DevTools Network 观察 `/api/v1/cache/entries?q=example`，列表条数不随输入变化；后端改为读 `q`（或前端改发 `query`）后过滤立即生效。

### BUG-54 · 前端构建 · 中 · screenshot.ts 静态 import 被 gitignore 的 wailsjs 生成绑定且 main.ts 无条件引入：无 `wails build/generate` 的纯 npm 构建（CI/web-only 打包）必失败
- **位置**：[frontend/src/api/screenshot.ts:6](Desktop/frontend/src/api/screenshot.ts#L6)（`import { CaptureWindow } from '../../wailsjs/go/main/App'`——静态 import，模块不存在时 `vue-tsc --noEmit` 报 TS2307、`vite build` 解析失败）、[frontend/src/main.ts:4](Desktop/frontend/src/main.ts#L4)（无条件 `import './api/screenshot'`，无平台条件、无懒加载）、[.gitignore:22](Desktop/.gitignore#L22)（`Desktop/frontend/wailsjs/` 不入库；`git ls-files frontend/wailsjs` 为 0 条，即全新检出必无此目录）、[frontend/package.json:8](Desktop/frontend/package.json#L8)（`build = vue-tsc --noEmit && vite build`——纯 npm 构建链不含 wails 代码生成步骤）
- **现象**：函数体内其实已有运行期守卫（`window.go?.main?.App?.CaptureWindow` 判空后才调用），但**模块级静态 import 不受运行期守卫保护**：任何不先跑 `wails build`/`wails generate module` 的构建（CI 上的 `npm run build`、脱离 Wails 的 web-only 打包、新环境检出后直接构建）在类型检查第一步即失败，且报错指向 `api/screenshot` 这个与截图功能无关的入口，排查成本高。仓库当前能构建仅因本机开发环境已生成过 wailsjs——典型的「依赖未被版本化、只在老开发者机器上成立」的构建脆弱性。
- **根因**：把「生成产物」当「源码依赖」静态引用；正确姿势是运行期动态访问 `window.go.main.App.CaptureWindow`（守卫已具备），或把 screenshot 封装改为按需 `import()` 并把 wailsjs 纳入生成脚本/入库。
- **验证方法**：`rm -rf frontend/wailsjs && cd frontend && npm run build` → TS2307 `Cannot find module '../../wailsjs/go/main/App'`。

### BUG-55 · 前端路由 · 低 · App.vue 的 `?tab=` 查询参数优先级恒压过 hash 且导航从不清除：URL 一旦带上 ?tab=，点侧栏切换大类被锁死
- **位置**：[frontend/src/App.vue:50](Desktop/frontend/src/App.vue#L50)（`const rawTab = (url.searchParams.get('tab') || hashTab || '')`——query 优先于 hash）、[:53](Desktop/frontend/src/App.vue#L53)（`?sub=` 同型）、[:79-89](Desktop/frontend/src/App.vue#L79)（`handleNavigate` 只写 `window.location.hash`，从不 `searchParams.delete('tab'/'sub')`）、[:152](Desktop/frontend/src/App.vue#L152)（hashchange 后再次 `parseRoute` 重读同一 URL 的 query，恒解析回旧 tab）
- **现象**：以 `http://127.0.0.1:15353/?tab=system` 形态打开（手工输入、外部集成、分享链接均可能——仓库自身工具链用的是 hash 形态 `#/{tab}/{sub}`（maintenance/core/ui_capturer.py:144），故**默认路径不触发**，定级低），此后点击侧栏任何大类：hash 变成 `#overview`，`parseRoute` 重读 `?tab=system` 又把视图拉回系统页——导航事实上锁死，且无任何提示。同一 URL 的 theme/palette 参数是一次性应用（:63-71 不在 hashchange 重复路径上改写），tab/sub 却被当作常驻优先级来源，语义不一致。
- **根因**：query 形态深链的读取点放在每次 hashchange 都会执行的解析函数里，却没有「消费后失效」的设计。
- **验证方法**：手动复现：浏览器访问带 `?tab=system` 的桌面端/ Web 控制台地址，点「总览」，视图不变而地址栏 hash 已变。静态核验：handleNavigate 全文无 searchParams 清理代码。

### 观察项（第 8 轮，暂不计为独立缺陷）
- [frontend/src/api/types.ts:424](Desktop/frontend/src/api/types.ts#L424)：`WebSocketEvent.type` 联合缺 `'safesearch'`，而后端 [internal/ipc/server_safesearch.go:41](Desktop/internal/ipc/server_safesearch.go#L41) 广播该类型（`Type: "safesearch"`）——事件类型联合与广播集（dns/filter/takeover/upstream/safesearch/background/query/metrics）不同步，前端无 safesearch 消费者，其它客户端修改强制安全搜索后本面板仅靠轮询追平。功能新鲜度问题而非正确性缺陷，列观察；同时 [frontend/src/components/overview/OverviewPanel.vue:292-301](Desktop/frontend/src/components/overview/OverviewPanel.vue#L292) 等消费分支只覆盖联合内类型，新增广播类型时无编译期提醒。
- [frontend/src/api/http.ts:15-17](Desktop/frontend/src/api/http.ts#L15)：`HttpTransport` 构造即 `loadConfig()`（ipc.ts 单例在 import 期创建），环境判定 `isDesktopApp()`（[frontend/src/utils/env.ts:4](Desktop/frontend/src/utils/env.ts#L4)）读 `window.go?.main?.App`——依赖「Wails 运行时先于 bundle 注入」的隐式顺序（AGENT_MISTAKES 2026-10-16 第 4 条的反向利用正是这一顺序）。当前交付路径顺序稳定、不复现，但无重试/延迟判定，若注入时序变化会静默错选 origin 并把 token 发往错误地址；列观察。
- 前端 api/入口层深扫已排查并排除（防后续重复翻查）：`utils/switch.ts`（md-switch 在派发 change 前已同步 `selected`，extractSwitchValue 读 host.selected 正确）、`utils/format.ts`（全本地方法无 UTC 偏移，0 值守卫与调用侧一致）、`ws.ts`（固定 3s 重连 + reconnectTimer 去重，OPEN/CONNECTING 判重，JSON.parse 有 try/catch）、`useSubTab/usePlatform/useAuthForm`（watch 正确、单例幂等、定时器有 onUnmounted 清理）、`components/ui/**`（AppCard/MetricStrip/InlineAlert/CopyRow/SegmentedTabs/PageHeader/Panel/CardTile 干净；MetricStrip `:key="stat.label"` 在重复 label 时才会撞 key，当前调用方恒唯一，未触发）、`clipboard.ts`（execCommand 降级路径）、`validators.ts`（IPv6 校验偏松但非安全面）、`imageCompressor.ts`（超时/配额容灾）；LiveQueryPanel/OverviewPanel/QueryHistoryPanel/LoginView/AppModal 的事件订阅与监听器均有配对注销，无泄漏。
- [internal/platform/windows/tray_defs.go:172-182](Desktop/internal/platform/windows/tray_defs.go#L172)：`appendMenuItem` 丢弃 `AppendMenuW` 返回值——AGENT_MISTAKES 2026-10-16「绝不丢弃 Win32 返回值」条目的同型残留。现状失败仅表现为菜单项静默缺失（文本恒为常量、UTF16 转换必成），无历史缺陷那样的静默失效面，列观察。
- [cmd/service/controller_web.go:116-134](Desktop/cmd/service/controller_web.go#L116)：ConfigureWeb 平滑重启的异步 goroutine 在 :124 **不持 `p.mu`** 读 `p.cfg.IPC.AuthToken`——与 BUG-3 同型（可变字段裸读）。当前 AuthToken 在全部代码路径中只由持锁的改密流程写入、重启 goroutine 读到的新旧值语义相同，实际无害，列观察待与 BUG-3 一并治理。
- [cmd/service/controller_dns.go:146-151](Desktop/cmd/service/controller_dns.go#L146)：GetAdapters 惰性写 `p.adapterScan` 不加锁；生产路径 main.go:110 恒先初始化，属死分支，列观察。
- [internal/dns/dns64_middleware.go:100-116](Desktop/internal/dns/dns64_middleware.go#L100)：DNS64 **原地改写 ctx.Resp**（追加合成 AAAA/CNAME）。当前安全的前提是上游 filterResponse/rebind 两个中间件不改写应答只剔除缓存，且 cache 的 Get 每命中都 `entry.msg.Copy()`——前提脆弱但现状无缺陷，列观察。
- [internal/core/safesearch.go:191-202](Desktop/internal/core/safesearch.go#L191) + [internal/dns/safesearch_middleware.go:44-48](Desktop/internal/dns/safesearch_middleware.go#L44)：命中强制安全搜索域名时返回 `AA=1 + 单条 CNAME（如 www.google.com → forcesafesearch.google.com）`且**不再解析目标链**——严格语义下权威服务器不应返回跨链未终结的 CNAME；部分 stub 解析器会对目标重新发起查询、再次命中同一改写形成放大循环的风险存在但未经实证（需特定客户端行为），列观察。
- [internal/ipc/server_ws.go:17-24](Desktop/internal/ipc/server_ws.go#L17)：`CheckOrigin` 恒 true。浏览器 WS 握手本不受 CORS 约束，该函数只挡「跨源页面携带凭据订阅」的二次防线；结合 BUG-1 的空 token 回环放行，它扩大了恶意网页面的可达性但非独立根因；runHub 的 close(send) 与 broadcast 互斥关系复查无回归（维持第 2 轮判定）。
- Linux 平台层深扫已排查并排除（防后续重复翻查）：`net.go`（/proc/net/route 字段序与十六进制小端还原正确；仅解析 IPv4 默认路由属既有设计——解析器绑 127.0.0.1）、`files.go`、`privilege.go`（euid==0 闸门无 TOCTOU）、`portcheck_proc.go`（/proc/net/{tcp,tcp6,udp,udp6} 字段 [1]/[3]/[9] 与 8/32 位十六进制换算逐位核过，正确）、`adapter.go`、`firewall_mgr.go`（薄透传）、`backend.go`（commandExists 的 PATH 切分与 detectBackend 兜底非 nil 成立）；`tray_mgr.go`/`aspect_ratio_mgr.go` 空桩——main_linux.go 在 Wails 之前即退出，交付路径不可达，**不**沿用 Windows BUG-4 的定级逻辑。已收录的 BUG-17/18/19 与第 4 轮三条 Linux 观察项不重复计。
- [internal/platform/linux/portcheck.go:88](Desktop/internal/platform/linux/portcheck.go#L88)：`isSystemdResolvedProcess(pid)` 依赖 owners 表命中，无 root 时他人进程 fd 不可读 → 非 stub 地址形态的 resolved 占用退化为 pid=0「无法定位」；与 BUG-46 同根（owners 表覆盖面）但触发条件不同（需非回环 stub 地址，实际难见），暂不单列。

---

## 第 9 轮（2026-10-17）— 已扫描模块

已扫描：`internal/querylog/{reader,stats,types,writer,ring,querylog}.go`＋`cmd/service/{controller_querylog,controller_metrics,main}.go`（查询历史链路全新深扫）、`internal/core/{cert_manager,cert_generate,hosts_resolver,rewrite,rewrite_records,rewrite_lookup,rule_engine,rule_engine_group_policy,rule_engine_response,scheduler,resolver_providers}.go`、`internal/platform/windows/{adapter,adapter_native,service_scm,firewall,portcheck_native,aspect_ratio}.go`＋`platform_windows.go`＋`service_privilege/screenshot/window_capturer`（代理深扫结果逐条源码复核）、`internal/ipc/{routes,server_bg,server_querylog}.go`＋`cmd/service/{controller_bg,controller_lan,controller_encrypted}.go`、`internal/ipc/{server_bootstrap,server_stamp,server_lan,server_portcheck,server_web}.go`（JSON 解码姿势普查）。**本轮 BUG-56/59/61/62/65 共 5 项经临时 Go 测试实证**（`zz_tmp_*_verify_test.go`，运行后即删，工作区保持干净），BUG-57 含实机 `icacls` 取证（真实部署落点 `%ProgramData%\DITING\certs`），`queryStartType` NULL 缓冲探测候选实机证伪后剔除。核心引擎批次 A 代理仍在进行，结果下一轮并入。

### BUG-56 · 查询历史 · 中 · 「清空查询历史」报成功但落盘文件删除失败被静默吞掉（Windows）/ 写入器落入孤儿句柄整日静默丢历史（POSIX）
- **位置**：[internal/querylog/querylog.go:254-258](Desktop/internal/querylog/querylog.go#L254)（`Clear(removeFiles)` 对 `writer.listFiles()` 逐个 `_ = os.Remove(p)`，错误全吞）、[:239-259](Desktop/internal/querylog/querylog.go#L239)（`Clear` 签名不返回 error）、[cmd/service/controller_querylog.go:53-61](Desktop/cmd/service/controller_querylog.go#L53)（控制器恒返回 nil）、[internal/ipc/server_querylog.go:85-88](Desktop/internal/ipc/server_querylog.go#L85)（HTTP 恒回「查询历史与统计已成功清空」）；根因面 [internal/querylog/writer.go:164-182](Desktop/internal/querylog/writer.go#L164)（`ensureFileLocked` 仅当 `file==nil || curDay!=day` 才重开句柄——当天句柄一旦持有，被删也不会重建）
- **现象**：写入器 goroutine 全天持有当天 `querylog-YYYYMMDD.jsonl` 句柄（`O_APPEND`，flush 周期 1s）。用户点「清空查询历史」：内存环与统计桶被清，但**Windows 上 `os.Remove` 因共享冲突直接失败**（实证报错 `The process cannot access the file because it is being used by another process`），错误被 `_ =` 丢弃，接口照样报成功；随后的 `GET /querylog/search`（`includeFile` 默认开）把 5 条「已清空」的落盘记录原样返回（实证：清空后 `Total=5 Entries=5`）。POSIX 分支更隐蔽：删除成功但句柄悬空，`ensureFileLocked` 不重建，之后整个白天的记录写进「已删除」的孤儿 inode，关进程即彻底消失（实证：删除句柄后目录无任何 jsonl，b/c 两连条写入均报成功不落盘）。
- **根因**：`Clear` 删文件的与持有者（writer goroutine）跨线程且无协议——既不请求 writer 关句柄，也不检查/传播删除错误。
- **验证方法**：已实证（临时测试两条，验证后已删）：① `New(FileEnabled)` 记录 5 条 → 等 1s flush → `Clear(true)` → `Search({IncludeFile:true})` → `Total=5`；② 手写 `writer` 直接调 `writeRecord/flush` → `os.Remove` 当天文件（Windows 报共享冲突）→ 继续写 2 条+flush 均报成功 → `closeFile()` 后磁盘无残留。可固化回归：`Clear` 应改为向 writer 发「关句柄+删文件」请求并返回聚合 error。

### BUG-57 · 加密 DNS 证书 · 中 · Windows 上私钥 0600 权限是空操作，默认数据目录 %ProgramData%\DITING 继承 Users 读权限——同机任意低权用户可窃取 DoT/DoH/DoQ 私钥
- **位置**：[internal/core/cert_manager.go:419-435](Desktop/internal/core/cert_manager.go#L419)（`writeFilePrivate` 注释自陈「私钥一旦可被同机其他用户读取，这套加密监听就只剩传输加密而没有身份认证」，用 `os.WriteFile(_,0o600)`+`os.Chmod(_,0o600)`——**Go 在 Windows 上两者都只切换只读属性，不设置任何 ACL**）、[internal/platform/paths.go:73-79](Desktop/internal/platform/paths.go#L73)＋[internal/platform/windows/paths_windows.go:11-23](Desktop/internal/platform/windows/paths_windows.go#L11)（证书目录 = `%ProgramData%\DITING\certs`，ProgramData 默认 ACL 授予 `BUILTIN\Users:(RX)`）
- **现象**：桌面端主交付平台（Windows）上，`MkdirAll(_,0o700)` 与 `WriteFile(_,0o600)` 全部落空，`server.key` 实际继承目录 ACL。实机取证（本机 Windows 11 26300，已部署过服务的真实落点）：`icacls server.key` → `NT AUTHORITY\SYSTEM:(I)(F) / BUILTIN\Administrators:(I)(F) / BUILTIN\Users:(I)(RX)`——**Users 含读取**。同机任意标准用户/低权进程可直接读出私钥，冒充本机的加密 DNS 服务；代码注释里明确防御的威胁模型在该平台从未成立。
- **根因**：以 POSIX mode 语义表达 Windows 权限意图，且无平台分支（应落 ACL：`SetNamedSecurityInfo` 授予仅 SYSTEM/管理员，或改放受 ACL 保护的私有目录）。
- **验证方法**：实机 `icacls %ProgramData%\DITING\certs\server.key`（本条即当场取证）。Linux 对照：同代码 0600 有效，属 Windows 专属缺陷。

### BUG-58 · 加密 DNS 证书 · 中 · 自签证书到期后无续期与检出路径：到期不报错、Loaded 恒真、Ensure 见文件即短路，825 天到点全量客户端握手失败
- **位置**：[internal/core/cert_manager.go:201-204](Desktop/internal/core/cert_manager.go#L201)（`EnsureSelfSigned` 只判 `fileExists` 即复用，不验 NotAfter）、[:87-108](Desktop/internal/core/cert_manager.go#L87)（`Reload`→`loadCertMaterial`→`tls.X509KeyPair` **不校验有效期**）、[:122-131](Desktop/internal/core/cert_manager.go#L122)（`TLSConfig` 只判 `loaded/cert!=nil`，无 NotAfter 闸门）、[internal/core/cert_generate.go:44-46](Desktop/internal/core/cert_generate.go#L44)（默认 825 天，Apple 上限）；[cmd/service/controller_encrypted.go:28-30](Desktop/cmd/service/controller_encrypted.go#L28)（状态查询仅 `!Loaded` 才 Reload，过期时 Loaded 恒真永不触发）
- **现象**：开启自签加密监听的部署在第 825 天起对全部客户端 TLS 握手失败（客户端拒绝过期证书），而本端一切「正常」：`Loaded=true`、监听器不报错、`Info().DaysRemaining` 为负仅在前端 CertificateCard 红色文本「已过期 N 天」展示（[frontend/src/components/encrypted/CertificateCard.vue:53-65](Desktop/frontend/src/components/encrypted/CertificateCard.vue#L53)——**展示而非动作**），无自动重签、无事件告警、总览/状态页不消费该值。用户唯一出路是手工点「重新签发」，而重签又使已装描述文件信任旧证书的移动端全部失效。
- **根因**：证书生命周期管理止步「存在且可解析」，缺「将到期主动续期 + 过期主动暴露故障」闭环。
- **验证方法**：包内测试：向 dir 写入 NotAfter 已过期的自签对 → `Reload()` → 断言 `Info().Loaded==true` 且 `DaysRemaining<0`、`TLSConfig()` 无错（现状全过）；grep 确认除 CertificateCard 显示外无任何 `DaysRemaining<0` 行为分支。

### BUG-59 · Hosts 解析 · 中 · UpdateConfig 先清空映射后解锁再逐文件重填，重填窗口内所有内网域名失去命中与权威 NODATA 保护，被原样转发公网上游
- **位置**：[internal/core/hosts_resolver.go:100-123](Desktop/internal/core/hosts_resolver.go#L100)（锁内 :108-111 清 `v4Map/v6Map/ptrMap/loadedFiles` → :112 Unlock → :114-121 逐个 `LoadFile` 重填，每个文件含 `os.Open`+全量解析）；消费方 [internal/dns/hosts_middleware.go:28-51](Desktop/internal/dns/hosts_middleware.go#L28)（`Lookup` 无命中且 `HasDomain` 为 false 时不再给权威 NODATA，放行去上游）
- **现象**：每次保存 hosts 配置（IPC `POST /dns/hosts/configure`，哪怕只改 TTL/开关）都存在一个「映射全空」窗口；实证（30 万行 hosts 文件，一 goroutine 连续 `UpdateConfig`、主 goroutine 连续 `Lookup`）：4586 次查询中 **4340 次（94.6%）命中空映射**——期间内网主机名既解析不出、也不被判定「属于本地权威」，直接查询公网 DoH/DoT 上游，正是该模块注释宣称要杜绝的局域网域名泄露。文件规模线性放大窗口（系统 hosts + 每个自定义文件逐个重读）。
- **根因**：热重载采用「就地清空再填充」而非「构建新映射后原子换指针」（对照 cache/规则引擎的换代模式）。`Reload()`（:126-143）同型，当前无调用方（死代码），修复时应一并原子化。
- **验证方法**：已实证（临时测试验证后删除）：构造大文件+并发 UpdateConfig/Lookup，统计空返回比例。可固化为压测型回归。

### BUG-60 · 规则引擎响应侧 · 低中 · MatchResponse 只判全局分时计划，请求侧 MatchForGroup 判分组分时：两闸相位不一致时任一方向都出错（分组漏检 CNAME 换域 / 分组静默期仍被响应侧拦）
- **位置**：[internal/core/rule_engine_response.go:73-76](Desktop/internal/core/rule_engine_response.go#L73)（`MatchResponse` 门控用 `e.IsBlockingActive()`——全局语义 [:226-240](Desktop/internal/core/rule_engine.go#L226)）、对照 [internal/core/rule_engine.go:348-357](Desktop/internal/core/rule_engine.go#L348)（`MatchForGroup` 用 `IsBlockingActiveForGroup(groupID)`，组级计划优先，[rule_engine_group_policy.go:18-30](Desktop/internal/core/rule_engine_group_policy.go#L18)）；调用点 [internal/dns/filter_response_middleware.go:60](Desktop/internal/dns/filter_response_middleware.go#L60) 传入 groupID 却只用于取 matcher，门控不看组
- **现象**：全局计划当前静默、某分组计划活跃时：该分组请求侧正常拦截，但 CDN 换域投毒（CNAME 目标黑名单）的响应侧复检被整体跳过——漏拦；反向（全局活跃、组静默）：请求侧 `ReasonScheduleInactive` 放行，响应侧却仍对别名链复检并可拦下——同一查询在请求/响应两侧对「该分组此刻该不该拦」的判定互相矛盾。
- **根因**：分组分时（第 3 轮引入）只改造了请求侧门控，响应侧复检函数是后加的，沿用了全局闸。
- **验证方法**：包内测试注入时钟：全局 Schedules 窗口外 + 组 Schedules 窗口内，同一含黑名单 CNAME 的响应分别走 `MatchForGroup`（blocked）与 `MatchResponse`（pass），断言二者一致——现状不一致即证。

### BUG-61 · DNS 重写 · 低 · 显式 AAAA 记录的类型闸门用 `To16()`（对 IPv4 字面量恒非 nil），接受 IPv4 并合成 `::ffff:x.x.x.x` 伪 AAAA 应答
- **位置**：[internal/core/rewrite_records.go:132-137](Desktop/internal/core/rewrite_records.go#L132)（`ip == nil || ip.To16() == nil`——`net.ParseIP("10.0.0.5").To16()` 返回 v4-mapped 非 nil，校验放行），对照 A 分支 :125-130 正确用 `To4()==nil` 拒收；编译期探针 [internal/core/rewrite.go:213](Desktop/internal/core/rewrite.go#L213) 同用此函数，同样放行
- **现象**：已实证：`buildRewriteRR("x.lan.", dns.TypeAAAA, {Type:"AAAA",Value:"10.0.0.5"}, 60)` 返回合法 `dns.AAAA`，应答内容 `::ffff:10.0.0.5`。IPv6-only 客户端直接丢弃或连不通；A/AAAA 校验强度不对称。
- **根因**：`To16` 对任何合法 IP 都非 nil，应改为「`To4()!=nil` 即拒」或 `ip.To16()!=nil && ip.To4()==nil`。
- **验证方法**：已实证（临时测试验证后已删）。

### BUG-62 · DNS 重写 · 低 · 同一 owner 名同时返回 CNAME 与其他类型记录，违反 RFC 1034 §3.6.2；注释明确鼓励快捷字段与 Records 并存，属常规配法
- **位置**：[internal/core/rewrite_lookup.go:105-106](Desktop/internal/core/rewrite_lookup.go#L105)（`matchShortcutRecords` 与 `matchExplicitRecords` 结果直接串接进同一 `resp.Answer`，无互斥检查）；`Records` 内 CNAME 型免 qtype 过滤 [rewrite_records.go:111-114](Desktop/internal/core/rewrite_records.go#L111)；并存设计见 [internal/core/rewrite.go:22-27](Desktop/internal/core/rewrite.go#L22) 注释（「两类同时配置时都会被返回」）
- **现象**：已实证：规则 `{Domain:dual.lan, Records:[CNAME→final.lan., A→10.1.2.3]}`，`Lookup(dual.lan, TypeA)` 返回 `[CNAME, A]` 两条同名异型记录；严格 stub/校验器会丢弃非 CNAME 或判报文异常，宽松者行为二义（取 CNAME 链还是取 A）。快捷 CNAME+MX 组合下 TypeMX 查询只见 MX（快捷分支 qtype 隔离），但 Records 同含 CNAME+A 时同 owner 并存成立。
- **根因**：重写引擎按「字段拼接」构造应答，未按 DNS 属主名做 CNAME 独占约束归并。
- **验证方法**：已实证（临时测试验证后已删）；RFC 1034 §3.6.2 / RFC 1034 图 8。

### BUG-63 · Windows 网卡扫描 · 低 · scanAdaptersNative 完全忽略 ctx、NewAdapterScanner 丢弃 executor 参数：调用方超时/取消对原生枚举无效
- **位置**：[internal/platform/windows/adapter_native.go:15-36](Desktop/internal/platform/windows/adapter_native.go#L15)（函数收 ctx 但全程不查 `ctx.Done()`：最多 5 轮 `GetAdaptersAddresses` 重试 + 逐网卡注册表双键读）、[internal/platform/windows/adapter.go:19-26](Desktop/internal/platform/windows/adapter.go#L19)（executor 形参未用；ScanAll 直通）
- **现象**：[cmd/service/controller.go:279](Desktop/cmd/service/controller.go#L279)、[cmd/service/controller_dns.go:121,150](Desktop/cmd/service/controller_dns.go#L121) 以带超时的请求 ctx 调 ScanAll，ctx 取消/到期后扫描照跑完整轮才返回；接管/还原循环里的「按 ctx 中止」语义对枚举段是空承诺。单轮耗时短（百毫秒级）故实害小，但接口契约（ctx 参数）形同虚设，且 Linux 侧 `ScanAll` 若未来加 cmd 执行同样会踩「executor 参数被静默丢弃」的配置漂移。
- **根因**：原生 API 循环无取消点；构造函数签名与实现脱节。
- **验证方法**：windows build-tag 测试：传入已 cancel 的 ctx 调 `ScanAll`，断言立即返回 `context.Canceled`——现状返回完整列表。

### BUG-64 · 加密 DNS 证书 · 低 · ImportPEM 与自签证书共用固定文件名 server.crt/server.key，来源切换互相踩踏：改回 self_signed 后永不生成自签（复用导入件），点重签即覆写导入证书
- **位置**：[internal/core/cert_manager.go:261-266](Desktop/internal/core/cert_manager.go#L261)（`ImportPEM` 落盘目标直接取 `SelfSignedCertFileName/SelfSignedKeyFileName` 常量，:282-287 再把 Source 记为 file 指向同一路径）、[:363-371](Desktop/internal/core/cert_manager.go#L363)（`Source=self_signed|""` 的解析路径 = 同一对固定名）、[:201-204](Desktop/internal/core/cert_manager.go#L201)（`EnsureSelfSigned` 见文件即短路）；触发 UI：CertificateCard 导入/重签按钮并存
- **现象**：导入 CA 证书后把 Cert.Source 改回 `self_signed`（或清空），启动/配置路径（[cmd/service/controller_encrypted.go:128-140](Desktop/cmd/service/controller_encrypted.go#L128)、main.go:184-196）见文件存在 → 直接复用**导入证书**、`created=false`、永不生成自签；反之点「重新签发」把自签新对覆写进同一路径，导入证书（若 Source 仍指向该路径）被静默换掉。两种来源共用一份文件，「在用哪张」的记账与注释里「固定命名防孤儿」的初衷相互矛盾——正是注释警告的同名不同期问题，发生在导入与自签之间。
- **根因**：导入落点未与自签固定名隔离（应落 `imported.crt/key` 或用户指定路径）。
- **验证方法**：包内序列测试：`ImportPEM(A)` → `Configure(Source:self_signed)` → `EnsureSelfSigned` → 断言 `created==true` 且磁盘内容仍为 A（现状 `created==false` 且用的是导入件）→ `RegenerateSelfSigned` → 断言导入件未被覆盖（现状被覆盖）。

### BUG-65 · 查询历史分页 · 中低 · 落盘回退检索的 Total 被 `Offset+Limit` 提前截断：同一数据集翻页时「共 N 条」随页码变化，页数算错、尾页翻不到
- **位置**：[internal/querylog/querylog.go:141-157](Desktop/internal/querylog/querylog.go#L141)（`searchFiles` 的 `need := sq.Offset + sq.Limit`，采足 need 条即 `return len(hits) >= need` 提前停止，返回的 `fileTotal=len(hits)` 至多为 need）、[:119](Desktop/internal/querylog/querylog.go#L119)（`total := memTotal + fileTotal` 直接把这个"本页候选数"当总数）、[:111](Desktop/internal/querylog/querylog.go#L111)（`needFile` 仅在 `memTotal < Offset+Limit+1` 时才回退文件）；消费方 [frontend/src/components/overview/QueryHistoryPanel.vue:48](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L48)（`pageCount = ceil(total/PAGE_SIZE)` 用后端返回的 Total 定页数，:301 显示「共 {{ total }} 条」）
- **现象**：内存环空、历史全在落盘文件（≥100 条）时实证：`Limit=10` 下 `Offset=0→Total=10`、`Offset=50→Total=60`、`Offset=200→Total=100`——正确恒应为 100。前端据每次不同的 Total 计算 `pageCount`：停在第 1 页只显示「共 10 条 · 第 1/1 页」，压根没有「下一页」可点，用户看不到第 10 条之后的全部历史；即便手动改了 offset，每翻一页「共 N 条」都在跳变，末页判定与"当前页是否最后"自相矛盾。`ring.search` 的 Total 是全量命中数（正确，[ring.go:124-131](Desktop/internal/querylog/ring.go#L124) 命中满时仍 `continue` 计数），唯独文件回退路径用"采满即停"冒充总数，两处口径不一致。
- **根因**：把分页窗口宽度 `Offset+Limit` 当采样上限，却让该上限同时充当对外报告的 `Total`——为省扫描做的早停在"候选收集"上合理，在"计数"上就是错的。
- **验证方法**：已实证（临时测试验证后已删）：`New(FileEnabled)` 写 100 条 → 等 1s flush → `Clear(false)` 清空内存环保留文件 → 三次 `Search({IncludeFile:true,Limit:10,Offset:0/50/200})` 得 Total 10/60/100。

### BUG-66 · IPC 请求体 · 中低 · 14 处 POST 处理器用无上限 `json.NewDecoder(r.Body).Decode` 直读请求体：BUG-52 的第三类读法，本机进程/恶意网页可用超大 JSON 耗尽内存
- **位置**：无上限解码点（14 处）——[internal/ipc/server.go:259,284,306](Desktop/internal/ipc/server.go#L259)（takeover/upstream configure/upstream test）、[internal/ipc/server_lan.go:28,46](Desktop/internal/ipc/server_lan.go#L28)（LAN configure/firewall）、[internal/ipc/server_portcheck.go:33](Desktop/internal/ipc/server_portcheck.go#L33)（autofix，`_ =` 吞错但已全额读入）、[internal/ipc/server_stamp.go:21](Desktop/internal/ipc/server_stamp.go#L21)（stamp 解析）、[internal/ipc/server_web.go:29,61,79,116,134](Desktop/internal/ipc/server_web.go#L29)（login/setup/password/web configure/firewall）、[internal/ipc/server_bootstrap.go:17](Desktop/internal/ipc/server_bootstrap.go#L17)（bootstrap configure）；闸门缺位同 BUG-52：[internal/ipc/server.go:81-85](Desktop/internal/ipc/server.go#L81)（`http.Server` 不设请求体上限）
- **现象**：BUG-52 已录「17 处裸 `io.ReadAll(r.Body)` vs 13 处 `io.LimitReader`」的两种读法，此处为**第三种读法**——`json.NewDecoder(r.Body)` 直接对未截断的 body 解码，`encoding/json` 边流式读边构建 `map[string]any`/切片，一个 2GB 的深层 JSON 数组会把对应内存全额吃掉再落进结构体字段；`/auth/login`、`/auth/setup` 更在鉴权之前（BUG-42 场景下恶意网页可直接 POST 巨body），放大 DoS 面。与 BUG-52 同根（`http.Server` 无全局闸门），但读法不同、文件不同，是 BUG-52 计数之外的补充。
- **根因**：项目内请求体读取有三种并存姿势（`LimitReader`／裸 `ReadAll`／裸 `NewDecoder`），唯 `server_bg.go` 用 `http.MaxBytesReader` 立了正样板；缺一个统一在 mux/中间件层的 `MaxBytesReader` 闸门。
- **验证方法**：静态核验（14 处调用点 + server.go:81-85 无上限），与 BUG-52 合并修复即可：`handleXxx` 前统一 `r.Body = http.MaxBytesReader(w, r.Body, N)`。

### 观察项（第 9 轮，暂不计为独立缺陷）
- [internal/core/resolver_doh3.go:129-135](Desktop/internal/core/resolver_doh3.go#L129)：DoH3 自定义 `Dial` 每次 `net.ListenUDP` 新建私有 socket 并包进一次性 `&quic.Transport{Conn: udpConn}`（`createdConn=false`、`isSingleUse=false`）——核对 quic-go v0.48.2 源码：失败路径调用的 `tr.Close()` 仅在 `createdConn` 时 `t.Conn.Close()`（transport.go:306-317），成功路径连接关闭回调 `onClose` 也因 `isSingleUse=false` 恒为 nil（transport.go:343-345），即**该 socket 在任何路径都不会被显式关闭**，只能依赖 Go netpoll 对 poll.FD 的 finalizer 兜底回收。实测（临时测试，验证后已删）：200 次失败拨号后进程句柄数 +36（120→156，GC+多轮 sleep 后残余）——非 1:1，说明部分被 finalizer 回收、部分滞留窗口不定，不足以断言无界泄漏，但「重连风暴期间 socket 释放滞后于 GC」确定成立；DoH3 上游每次回退重连都新建一个这样的 socket（旧 http3.Transport 的 Close 也只关各 QUIC 连接、同样不关 socket，因 createdConn=false）。修复姿势与包级 `quic.Dial` 的合同一致：调用方自建 PacketConn 须自行在连接关闭后 Close。列观察（需成功路径接真实 QUIC 服务才能定量）。
- [internal/querylog/ring.go:15-16](Desktop/internal/querylog/ring.go#L15)：`total uint64`（累计写入条数）注释称「用于淘汰与展示」，但全仓无任何读取点（grep `.total` 仅 append 处自增）——内存环清空/进程重启后既不回填也不回读落盘历史计数。仅死字段，无行为缺陷。
- [internal/platform/windows/firewall.go:25-35,117-121](Desktop/internal/platform/windows/firewall.go#L25)：`CheckFirewall*` 把 netsh **执行失败**（服务停/权限不足）与「规则未放行」同等返回 `(false,nil)`；且 [isFirewallRuleActive:38-61](Desktop/internal/platform/windows/firewall.go#L38) 的 `enabled/actionAllow` 是全文「末行覆盖」布尔——`netsh show rule` 同名多规则时逐块打印，判定取最后一条而非「任一有效」。调用方 [cmd/service/controller_lan.go:24](Desktop/cmd/service/controller_lan.go#L24) 本就以 `_` 丢 error，UI 仅显示 FirewallAllowed 布尔。误导路径存在（防火墙服务异常→提示「未放行需重新配置」）但实害难评级。
- [internal/platform/windows/portcheck_native.go:167-171](Desktop/internal/platform/windows/portcheck_native.go#L167)：`procOpenServiceW` 失败（含策略拒绝打开 SharedAccess，非「服务不存在」）统一返回 `(false,0,nil)` 吞掉 err → ICS 占用静默漏报、一键修复资格判定退化。触发需服务 ACL 异常，罕见。
- [platform_windows.go:68-74](Desktop/platform_windows.go#L68)：`OnDomReady` 每次导航/热重载都 `go LockWindowAspectRatio(...)`，无幂等守卫（同回调内的 `app.initTray` 有）——AGENT_MISTAKES「OnDomReady 须幂等」同型残留：每次新 `syscall.NewCallback` + 最长 3s 轮询协程；因 BUG-4 已证 `SetWindowSubclass` 在本进程恒 FALSE，重复挂载的实际效果只是泄漏回调，不单列。
- [internal/platform/windows/adapter_native.go:100-105](Desktop/internal/platform/windows/adapter_native.go#L100)：`if len(v4DNS)==0 && v4DHCP { v4DHCP = true }` 为恒真赋值死代码（v6 同型），疑似「运行时无 DNS→回退 DHCP」意图写反；当前注册表为准，输出仍正确，属误导型残留。
- [cmd/service/controller_encrypted.go:28-30](Desktop/cmd/service/controller_encrypted.go#L28)：证书处于「存在但解析失败」态（PKCS#12 口令错/容器损坏）时，每次 `GET /encrypted/dns/status` 都重跑一遍 `pkcs12.Decode` 的 PBKDF2（十万级迭代）且永不自愈——但代理所称「前端 3-5s 轮询」不实：EncryptedDNSPanel 仅 onMounted 加载一次，无轮询；实害限于反复手动刷新，降级为观察。
- [internal/core/resolver_plain.go:178-179](Desktop/internal/core/resolver_plain.go#L178)：`respLen > 65535` 为死分支（`binary.BigEndian.Uint16` 值域 ≤65535）；同文件 `respLen==0` 有意义。对照 [resolver_dot.go:309](Desktop/internal/core/resolver_dot.go#L309) 同型死检。无害，记录防清理时误删 `==0` 分支。
- [internal/ipc/routes.go:109-110](Desktop/internal/ipc/routes.go#L109)：`GET /api/v1/auth/background` 与 `/auth/background/image` 不经 `withAuth`（登录页未鉴权渲染所需，属设计面）；响应仅含 type/url/opacity/blur/updatedAt（[controller_bg.go:74-110](Desktop/cmd/service/controller_bg.go#L74)），不含口令与图片内容外的信息。POST/DELETE 有 `verifyBackgroundPermission` 且正确使用 `RemoteAddr`（[server_bg.go:46-49](Desktop/internal/ipc/server_bg.go#L46)，与 BUG-42 的 XFF 采信形成同工程不一致——同一鉴权族内一处防伪造一处不防，佐证 BUG-42 属遗漏而非设计）。恶意网页可匿名枚举自定义背景 URL/时间戳，暴露面小，列观察。
- Windows 平台层代理深扫已排查并排除（防后续重复翻查）：`portcheck_native.go` 四张 MIB 表 rowSize/offset 与 iprtrmib 逐字段比对正确、句柄全 defer 关闭；`service_privilege.go` SHELLEXECUTEINFOW 字段偏移 amd64 对齐正确、伪令牌免 CloseHandle/FreeSid defer 齐；`screenshot.go` GDI 对象/DC 逆序释放无泄漏；`firewall_mgr.go/window_capturer.go/aspect_ratio_mgr.go` 薄委托干净；`autostart.go` 键均 Close、DeleteValue 对「本已缺失」容忍合理。
- 核心引擎批次 B 与 Windows 平台层两份代理报告经源码复核后的**修正与降级**：批次 B 称「`DaysRemaining` 计算后全仓无消费者」不实（前端 [CertificateCard.vue:53-65](Desktop/frontend/src/components/encrypted/CertificateCard.vue#L53) 以 error/warning 色显示之，故本表 BUG-58 改述为「展示而非动作」——缺的是续期动作而非展示）；批次 B 称「前端 3-5s 轮询 `/encrypted/dns/status` 每次重跑 PKCS12 PBKDF2」的轮询前提不实（EncryptedDNSPanel 仅 onMounted 加载一次），相应内容降为观察；Windows 代理称 `queryStartType` NULL 缓冲探测可能返回非 INSUFFICIENT_BUFFER 错误——本机实机证伪（见下剔除节）。

---

## 第 10 轮（2026-10-17）— BUG-1~66 逐项二次排查（复核轮）

> 复核方式：全部 66 条逐项对照当前源码复验，行号按当前代码重新锚定；其中 **15 条用临时 Go 测试当场重跑实证**（`zz_tmp_*`，运行后即删，本轮工作区只含文档改动）：BUG-5/34/35/37/38/40/44/45/51/56/57/59/61/62/65。前端集群（BUG-20~26/53~55）与 Linux 平台层（BUG-17~19/46~50）先由两路只读子代理定位，再对本会话未亲眼核对的每条断言与全部"纠偏"逐一回读源码后才采信。**结论汇总：65 条确认存在，待修复；1 条（BUG-44）为误报，无需修复**。观察项/已剔除项非立条缺陷，不在本次复核范围。

### 逐项结论（〔〕内为复核判定）

- **BUG-1** 〔确认存在，待修复〕`server.go:141-143` 空 token+回环放行原样存在；默认 `AuthToken:""`（config.go）；`cors.go:14/25` 反射 Origin+Credentials；`server_web.go:86` loopback 改密 `bypassOldAuth=true`。
- **BUG-2** 〔确认存在，待修复〕`server_ws.go:84` 用同一 `verifyToken`，`CheckOrigin` 恒 true（:20-23）。
- **BUG-3** 〔确认存在，待修复〕写 `p.ipcServer` 持锁于 controller_web.go:129-131；无锁读点 controller_metrics.go:128、main.go:255（runMetricsTicker 全程不取 p.mu）、main.go:290、controller_dns.go:90 均在。
- **BUG-4** 〔确认存在，待修复〕aspect_ratio.go:139-146 仍用 `procSetWindowSubclass`；platform_windows.go:69-71 goroutine 丢弃返回值；AGENT_MISTAKES 实测该方法在本进程恒 FALSE。
- **BUG-5** 〔确认存在，待修复〕**本轮实证**：内存记 10 条、`Search{Limit:3,Offset:5}` → entries=0（期望 3），与第 2 轮数字一致。
- **BUG-6** 〔确认存在，待修复〕`acceptLoop`（server_dot.go:94-123）仍只判 `s.srv.serving()`，`d.stop` 在 accept 路径无读取方；对照 DoQ :105 显式 `errors.Is(err, quic.ErrServerClosed)`。
- **BUG-7** 〔确认存在，待修复〕`ReloadEncrypted` server.go:77 解锁后 :93-114 调 start*，`s.dot=dl`（server_dot.go:80）无锁写 vs `DoTListenAddress` :21-23 持锁读；:97 解锁后裸读 `s.encrypted` 可被并发 `ReloadEncrypted(nil)` 置空。
- **BUG-8** 〔确认存在，待修复〕flight fn 仍返回 `ctx.Resp` 原指针（cache_middleware.go:82）；跟随者 `c.val.Copy()`（cache_flight.go:44）在领导者 `Resp.Id/Truncate`（server.go:327/336）之前即被 `wg.Done()` 放行。
- **BUG-9** 〔确认存在，待修复〕server_dot.go:140 握手后清全部期限；dot_conn.go:91 `d.conn.Write(framed)` 无任何期限；serve 只续读期限（:132）。
- **BUG-10** 〔确认存在，待修复〕takeover.go:220-226 `Restore` 无论 err 均 `m.adapters=nil`+`stateStore.Clear()`；resetResidualLoopbackDNSNative 逐卡 `_ =` 吞错恒返 nil（dns_native.go:128-134）。
- **BUG-11** 〔确认存在，待修复〕TakeoverSingle 失败路径（:173-189）仍只回滚簿记不调 restore；`a.ID==adapter.ID || a.Name==adapter.Name` 先命中即覆盖（:146-156）；RestoreSingle 同名多条目丢其余（:237-246）。子代理所称「Windows 侧先命中后 break 故不覆盖」经回读不成立——break 只停扫描，`m.adapters[i]=state` 本身就把同名的第一块卡快照覆盖了。
- **BUG-12** 〔确认存在，待修复〕restore_script.go 仍把 `a.Name` 原样内插进 `echo` 与 `name="%s"`。
- **BUG-13** 〔确认存在，待修复〕cli.go 仅显式 `-config` 才解析 StateFilePath；platform_windows.go:21 仍 `NewFileStateStore("")`。
- **BUG-14** 〔确认存在，待修复〕service_mgr.go:325 `_ = stopServiceNative`；:329 硬编码 `defaultSCMQuery`（对照 :142-144 的可注入姿势）。
- **BUG-15** 〔确认存在，待修复〕useConfirmModal.ts:38-40 二次 ask 覆写 `resolvePromise` 悬挂前一个 Promise，确证；useToast 复核修正：show() 其实有 clearTimeout 配对、dismiss 也清理，缺陷仅剩「无 onUnmounted 清理」（原验证方法中"无 setTimeout 被 clearTimeout 配对"一句不准确）。
- **BUG-16** 〔确认存在，待修复〕ConfigureEncryptedDNS/ACL 全程持 `p.mu`（controller_encrypted.go:79-80、controller_acl.go:16-17）→ reloadDNSWithCurrentConfig（函数注释自述「在持有 p.mu 的前提下」）→ ReloadEncrypted→`oldDot.close()` 内 `wg.Wait()` 3s；在途查询经 controller_pipeline.go:34-43 等 getter 阻塞在同一把 `p.mu` 上。锁序倒置成立。
- **BUG-17** 〔确认存在，待修复〕本轮 Grep 全仓 `diting.orig`：仅 restore_script.go:102/104 两处读取、零写入点；实际备份落 `DefaultDataDir()/backups/resolv.conf`（resolvconf.go:106-108），死分支确证。
- **BUG-18** 〔确认存在，待修复〕RestoreSingle 匹配循环（takeover.go:199-208）无 break、命中项不进 remaining，确证；TakeoverSingle「先命中先覆盖」为快照覆盖语义（有 break 但 `m.adapters[i]=state` 即覆盖），原报告表述成立，子代理纠偏驳回。
- **BUG-19** 〔确认存在，待修复〕service_mgr.go:71-88 候选含 `./build/bin/...` 相对路径且原样返回、commandExists 分支返回裸名；renderSystemdUnit 直拼 ExecStart，Linux 侧无 filepath.Abs（Windows 侧有，佐证遗漏）。
- **BUG-20** 〔确认存在，待修复〕RulesPanel.vue:73/75 轮询整体覆写 `config`/`customRulesText`，全文件 dirty/焦点守卫检索为 0；usePoller 有 clearInterval（定时器清理不是本条缺陷点）。
- **BUG-21** 〔① ② ④ 确认存在，待修复；③ 触发路径不成立〕①EncryptedListenersCard watch(props.status) 无条件回填 6 字段＋父 `onChanged` 整体替换，确证；②ReverseProxyCard computed 数组引用不稳，确证；④ClientsPanel 行内按钮成功后覆写 textarea 且请求体不含草稿，确证；**③SafeBrowsingCard 复核修正**：apply() 只在 onMounted 与自身保存回读时调用（注释明言"以回传值为准"属有意设计），父 PrivacyPanel 无轮询/ref/外部刷新路径——「外部状态刷新清草稿」在该处不可达，③ 不计。
- **BUG-22** 〔确认存在，待修复〕QueryHistoryPanel.vue:37 普通 `let liveBuffer` 被 :285-286 模板消费、:147 push 无响应式伴随；:90 回包清空；回车路径无代次守卫。三点全部复现。
- **BUG-23** 〔确认存在，待修复〕pollMetrics/handleSearch 双路径无守卫覆写 entries，确证；措辞修正：轮询请求其实携带当前 `currentSearch`，"闪回全量"应为"旧参数回包乱序覆写新参数结果"（竞态本体不变）。
- **BUG-24** 〔确认存在，待修复〕`v-for idx→upstreams` 与 `providers` 双数组按 index 对齐、失败路径不重同步，确证。措辞修正：「forceSyncProviders 恒 false」不实——saveConfig **成功**路径有 `loadData(true)` 强制重同步（UpstreamPanel.vue:177），错位仅发生在失败路径；子代理据此判"根因成立"，采信。
- **BUG-25** 〔确认存在，待修复〕UpstreamPanel.vue:178-180 裸 `setTimeout` 无句柄、全文件无 clearTimeout/onUnmounted，确证。
- **BUG-26** 〔确认存在，待修复〕`:key="index"`+splice 属实；子代理"值不会粘错行"就 Vue 数据绑定而言正确，但报告所述症状本就以 shadow-DOM 焦点/内容错位为形态（删行后光标原位、后续输入写进上移分组），维持确认。
- **BUG-27** 〔确认存在，待修复〕ConfigureClientGroups:88-93 换 `p.groupResolver` 字段，buildPipeline 按值捕获进五个中间件闭包（controller_pipeline.go，client/filter/filterResponse/cache/upstreamRoute），唯一调用点仍在 StartDNS；对照 controller_lan 的 Stop+Start。
- **BUG-28** 〔确认存在，待修复〕GetStatus 锁内只取 `dnsRun`（controller_dns.go:155-157），随后 :159-248 无锁读 `p.resolver`/`p.cfg` 全量/`p.takeoverMgr`。
- **BUG-29** 〔确认存在，待修复〕`UpdateConfig`（cache.go:81-95）仍不碰 `c.maxEntries`/分片容量（仅 :48-72 构造期折算）；淘汰点 :439、Stats :36、落盘 :63/:114 读旧值。
- **BUG-30** 〔确认存在，待修复〕update 处理器（server_filter.go:127-149）无 URL 校验，add（:110-114）有；UpdateFilterList 无条件覆写（rule_engine_lists.go:76-78）。
- **BUG-31** 〔确认存在，待修复〕janitor 仅构造期按 `cfg.Enabled` 启动（rate_limiter.go:104-106），UpdateConfig（:112-147）无启停；兜底为 maxBuckets=16384 内联淘汰。
- **BUG-32** 〔确认存在，待修复〕controller_security.go:129-131 先改 `p.cfg.Upstream` 再 `_ = p.resolver.Configure(...)`，照常落盘返 nil。
- **BUG-33** 〔确认存在，待修复〕四处 `req.TTL != nil && *req.TTL > 0` 原样在（rewrite:75、zone:55、safesearch:40、security:191）。
- **BUG-34** 〔确认存在，待修复〕**本轮实证复现死锁**：全天计划+写者（PauseFor/ResumePause）并发下，第 2 次 `GetStats` 1.5s 未返回，栈转储 `GetStats`(rule_engine.go:181)→`currentTime`(rule_engine.go:270) 卡在 `sync.RWMutex.RLock`，与第 7 轮实证栈形一致。
- **BUG-35** 〔确认存在，待修复〕**本轮实证复现**：`PutForGroup(kids)=true` → `Remove()=false` → 组内仍命中=true（首轮 harness 因未置 `Enabled:true` 假阴性，修正后确证）。
- **BUG-36** 〔确认存在，待修复〕prefetch 回调 `c.Put(req,resp)` 写默认组键、`flight.Do(e.key)` 用分组键防抖（cache_prefetch.go:112-118），buildPrefetchRequest 不带组。
- **BUG-37** 〔确认存在，待修复〕**本轮实证复现**：Lists[0].Enabled 翻转（条数不变）后 `CheckHost` 停用前=block、停用后=block。
- **BUG-38** 〔确认存在，待修复〕**本轮实证复现**三种 panic：`/dns//query`「unclean path」、`/dns{query`「bad wildcard」、`/{ClientID}`「duplicate wildcard」；`normalizeDoHPath` 仍不收敛内部 `//`、不拒 `{`；全仓 `recover()` 仅 cache_flight.go 一处，main.go:76 `go p.run()` 裸协程 → 启动期 panic 即进程崩溃，崩溃链确证。
- **BUG-39** 〔确认存在，待修复〕GET 分支（server_doh.go:248-258）解码无尺寸判据、POST 有；serveDoH 与流水线仅 `len(Question)==0` 早退，无 QDCOUNT==1/QR==0 校验。
- **BUG-40** 〔确认存在，待修复〕**本轮实证复现**：带 OPT 请求进 `BuildDDRResponse` → `respIsEdns0=false、Extra=0、Answer=2`。
- **BUG-41** 〔确认存在，待修复〕`soaZone := q.Name`（private_ptr_middleware.go:179）原样在。
- **BUG-42** 〔确认存在，待修复〕`getClientIP`（server_static.go:126-141）无条件采信 XFF/X-Real-IP；server_web.go:34 直接作 Login 键；对照 realip.go 可信代理姿势。
- **BUG-43** 〔确认存在，待修复〕`ipAttempts`/`ipLockedUntil` 仅登录成功 delete（auth.go:205-206），失败键无上限无回收。
- **BUG-44** 〔**误报，无需修复**〕见下文专节。
- **BUG-45** 〔确认存在，待修复〕**本轮实证复现**：`PauseFor(time.Duration(n)*time.Second)` n∈{-1,0,18446744073,10000000000} 四例全部 paused=true、remaining=876000h（100 年哨兵），溢出形态 -709.55ms/-2346317h 与第 8 轮记录逐字一致；n=300 正常 5m。
- **BUG-46** 〔确认存在，待修复〕`pid == self → continue`（portcheck_owner.go）与 `isSelf` 判定链复核在；`case isSelf:` 与 hasSelfListener 为死代码成立（自身 socket 在 owners 表恒缺失）。
- **BUG-47** 〔确认存在，待修复〕`/run/systemd/resolve/resolved.pid` 读取点与 `pid==0 → return nil` 短路复核在；措辞修正：isStub 仍有「stub 地址字面量」「进程名」两条子条件，准确的缺陷表述是「经此 pidfile 恒拿不到 PID、回退终止恒空操作返成功」，非「stub 识别整体废」。
- **BUG-48** 〔确认存在，待修复〕`applied=append(applied,a)` 在 dns+domain 两命令全成功后才执行（backend_resolved.go:39-47），rollbackApplied 不含当前卡；TakeoverSingle（takeover.go:147-162）Apply 失败不调 backend.Restore，多卡路径（:96-99）有——两点均确证。
- **BUG-49** 〔确认存在，待修复〕drop-in 先写（:55）→ restart 失败 → 回退因 BUG-47 恒 nil → 函数返 nil 谎报成功，链路复核在。
- **BUG-50** 〔确认存在，待修复〕`Exec=%s` 原样拼 os.Executable()（autostart.go:71）、IsEnabled 仅 Stat 存在性，复核在。
- **BUG-51** 〔确认存在，待修复〕**本轮实证复现**：`youtube.com##.video-ads` → 保留，Pattern="youtube.com"，Match(www.youtube.com) **Blocked=true Reason=blacklist**；`#@#`/`#?#` 同样漏网。
- **BUG-52** 〔确认存在，待修复〕**本轮重新计数**：裸 `io.ReadAll(r.Body)` 恰 17 处、`io.ReadAll(io.LimitReader` 恰 13 处，与第 8 轮逐一吻合；http.Server 仍无请求体闸门（server.go:81-85）。
- **BUG-53** 〔确认存在，待修复〕cache.ts:20 `params.set('q', query)` vs server_cache.go:35 `Get("query")`，字面量核对无误。
- **BUG-54** 〔确认存在，待修复〕screenshot.ts:6 静态 import、main.ts 无条件引入、build 脚本无 wails 生成步、`git ls-files frontend/wailsjs` 为 0，全部复核在；引用路径修正：忽略规则在**仓库根** `.gitignore:22`（Desktop/ 下无独立 .gitignore），效果一致。
- **BUG-55** 〔确认存在，待修复〕query 优先（App.vue:50）、handleNavigate 只写 hash、全文无 searchParams 清理，复核在；可达性与原报告「默认路径不触发、定级低」一致（应用内导航不产生 ?tab=，仅外部深链触发）。
- **BUG-56** 〔确认存在，待修复〕**本轮实证复现（Windows）**：记 5 条→flush→`Clear(true)`→Search 仍 `Total=5 Entries=5`；且测试自身清理 TempDir 时报 `unlinkat ...jsonl: being used by another process`——写入器持句柄、删除失败当场二次取证。
- **BUG-57** 〔确认存在，待修复〕**本轮实证复现**：原部署 certs 目录已不在本机，改以同构实验重跑——`MkdirAll(0700)+WriteFile(0600)+Chmod(0600)` 于 `C:\ProgramData` 下生成文件后 `icacls` 显示 `BUILTIN\Users:(I)(RX)`（继承 ProgramData 的 `(OI)(CI)(RX)`），与原报告取证完全一致；`writeFilePrivate`（cert_manager.go:424-435）仍无任何 Windows ACL 分支。
- **BUG-58** 〔确认存在，待修复〕`EnsureSelfSigned` 见文件即短路（cert_manager.go:201-205）、TLSConfig 无 NotAfter 闸门（:123-131）、Go `X509KeyPair` 确不校验有效期；DaysRemaining 仅 CertificateCard 展示无动作分支。
- **BUG-59** 〔确认存在，待修复〕**本轮实证复现**：30 万行文件、连续 UpdateConfig×Lookup 3 秒 → 20285 次查询 19585 次空返（**96.5%**，与第 9 轮 94.6% 同量级）；清空→锁外重填结构未变（hosts_resolver.go:100-123）。
- **BUG-60** 〔确认存在，待修复〕MatchResponse 门控仍 `e.IsBlockingActive()`（rule_engine_response.go:74，全局语义），MatchForGroup 用 `IsBlockingActiveForGroup`（rule_engine.go:355）；调用方传 groupID 仅用于取 matcher，确证。
- **BUG-61** 〔确认存在，待修复〕**本轮实证复现**：`buildRewriteRR(...,AAAA,{Value:"10.0.0.5"})` 返回 `x.lan. 60 IN AAAA ::ffff:10.0.0.5`；对照 A 分支拒收 `::1`，不对称复现。
- **BUG-62** 〔确认存在，待修复〕**本轮实证复现**：`Lookup("dual.lan.", TypeA)` 应答 = `[CNAME(dual.lan.) A(dual.lan.)]` 同名并存。
- **BUG-63** 〔确认存在，待修复〕scanAdaptersNative 全程无 `ctx.Done()` 检查（5 轮重试+逐卡解析）、NewAdapterScanner 弃用 executor 形参，复核在。
- **BUG-64** 〔确认存在，待修复〕ImportPEM 落盘目标仍取 `SelfSignedCertFileName/SelfSignedKeyFileName`（cert_manager.go:264-265），与自签共用固定名，复核在。
- **BUG-65** 〔确认存在，待修复〕**本轮实证复现**：内存空、落盘 100 条时 `Limit=10` 下 Offset=0/50/200 → Total=**10/60/100**，与第 9 轮记录逐字一致。
- **BUG-66** 〔确认存在，待修复〕**本轮重新计数**：全仓 `json.NewDecoder(r.Body)` 共 14 处，其中 `server_bg.go:79` 前置 `MaxBytesReader`（有闸门），**无闸门实为 13 处**——原报告标题"14 处"与其列点清单（13 处）本就差一，本次以"14 读法、13 无闸"更正口径；缺陷本体（无统一 body 闸门 + login/setup 在鉴权前）不受影响。

### BUG-44 误报判定专节（DNS64 EmbedIPv4InIPv6）

- **判定**：误报，无需修复。原报告（第 8 轮）把 RFC 6052 §2.2 Table 2 读成「IPv4 必须紧随前缀连续放置、u 字节位于 IPv4 之后」，据此判 /40//48//56 三个分支把零字节插进了 IPv4 中间。
- **复核依据（权威原文）**：RFC 6052 §2.2 规定 **u 字节固定在 bits 64–71（byte 8）**，对 /32–/64 前缀 IPv4 本就被该保留字节拦腰分隔（/40：IPv4 前 24 位在 bits 40–63 + 后 8 位在 bits 72–79；/48、/56 同型）；「IPv4 连续」只对 /64（u 在前）与 /96（无 u）成立——恰是原报告自认"正确"的两例。
- **本轮实证（决定性）**：临时测试以 RFC 6052 Table 1/2 公布的官方样例（IPv4=192.0.2.33）逐一对账 `EmbedIPv4InIPv6` 输出，**六种前缀长度全部逐字命中规范样例**：/32→`2001:db8:c000:221::`、/40→`2001:db8:1c0:2:21::`、/48→`2001:db8:122:c000:2:2100::`、/56→`2001:db8:122:3c0:0:221::`、/64→`2001:db8:122:344:c0:2:2100::`、/96→`2001:db8:122:344::c000:221`。
- **连带结论**：原报告「既有单测只断言 byte8==0、恰好被错误实现满足」同样反了——`v6[8]=0` 正是 RFC 对 u 字节的强制要求（"MUST be set to zero"），该单测断言的是正确性质；代码注释（如 case 56「IPv4[0] | u(8) | IPv4[1-3]」）与实现自洽且与规范一致。
- **防重复翻查**：本条已含完整反证，后续轮次勿再以"连续布局"口径重报 DNS64 嵌入。

### 复核中的表述修正汇总（缺陷本体均维持原判定，除所注降级/剔除点）

1. BUG-44 整体误报（唯一剔除项，见专节）。
2. BUG-21 的 ③（SafeBrowsingCard）外部刷新触发路径不可达，四同族点按三处计。
3. BUG-15 useToast 的"定时器不清理"应限定为"缺 onUnmounted"（重弹/dismiss 均有 clearTimeout 配对）；useConfirmModal 部分原样成立。
4. BUG-23 "闪回全量"应为"旧参数回包乱序覆写"（轮询携带的是当前过滤词）。
5. BUG-24 括注「forceSyncProviders 恒 false」不实：成功路径 `loadData(true)` 会重同步，错位只在失败路径——报告现象段本就以失败为条件，根因不变。
6. BUG-47 「stub 识别只剩两条路」偏强：isStub 的地址字面量与进程名子条件独立于 pidfile，准确口径是"pidfile 取 PID 恒败、回退终止恒空操作谎报成功"。
7. BUG-54 gitignore 规则位于仓库根 `.gitignore`，非 `Desktop/.gitignore`（链接目标不存在），忽略效果一致。
8. BUG-66 计数口径更正为"14 处 NewDecoder 读法、其中 13 处无闸门"（原文标题 14 与列点 13 自相矛盾）。
9. 两条子代理纠偏经回读源码**驳回**：①「Windows TakeoverSingle 有 break 故同名覆盖不成立」——break 前 `m.adapters[i]=state` 已完成覆盖；②「BUG-24 根因不成立」——失败路径不重同步仍成立（该代理自己也据失败路径维持了确认）。

### 复核残留处置

本轮全部临时测试（`internal/querylog/zz_tmp_reverify_test.go`、`internal/core/zz_tmp_reverify2_test.go`、DoH panic 与 DNS64 样例临时 module、权限取证目录 `C:\ProgramData\DITING_PERMTEST`）验证后均已删除，`git status` 仅含本文档与 AGENT_MISTAKES.md。

---

## 已核实但予以剔除的代理报告项（防重复上报）

- 「`queryStartType` 的 `QueryServiceConfig(svc, nil, 0, &needed)` NULL 缓冲探测在部分 Windows 返回非 INSUFFICIENT_BUFFER 错误 → 自启状态误报」——**本机实机证伪**（Windows 11 Pro 26300，临时测试验证后已删）：对 `dnscache`/`DitingDNSService`/`SharedAccess` 三个真实服务调用均 `err=<nil>` 且 startType 正确（2/2/3）。NULL+size0 是 MSDN 认可的能力探测形态，担忧路径不成立。
- 「`/api/v1/service/status` 不返回 `autoStart`」——**不实**：`platform.CoreServiceStatus` 含 `autoStart,omitempty`（[internal/platform/types.go:134](Desktop/internal/platform/types.go#L134)），`ServiceManager.GetStatus` 恒填充（service_mgr.go:155）；Web 模式自启开关本就隐藏不可操作。
- 「`RestoreAdapters` 持锁再入自死锁」——**不实**：该方法及其下游均不取 `m.mu`。
- 「`useCopyFeedback` 跨实例串扰」——**不实**：`copiedValue/timer` 为每次调用新建的闭包变量，非模块级共享。
- 「netsh `name=X` 单 token 参数引号失效」——代理自验后撤回，add 路径确有 `err` 检查。
- 「QueryHistoryPanel 连点下一页造成分页竞态」——**触发路径不实**：上/下页按钮 `:disabled="!canPrev||loading"`（[QueryHistoryPanel.vue:365,374](Desktop/frontend/src/components/overview/QueryHistoryPanel.vue#L365)）已门控；真实可达路径是筛选框回车（不受 loading 门控），已按修正后的触发方式并入 BUG-22(c)。
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
