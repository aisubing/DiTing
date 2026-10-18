# 安卓端缺陷分级 · High

> 本文档由对安卓端缺陷报告（扫描基线 `main @ 3a048c5`）逐条复核产出的**高严重度**缺陷构成。源报告 `docs/desktop-bug-report.md` 已于 2026-10-18 删除，后续重建该报告时不参考旧版本，本文档各分节的机制/可达面/证据即为现存一手记录。分级依据为**复核后严重度**（可能与原报告标注不同）：严重度 = 缺陷机制 × 可达面，两者分别经源码回读、caller/write 点 grep 与（适用时）实机复算核实。
>
> - 复核完成时（基线 `3a048c5` 至 `fa972e7`）Android 与 Go 源码零改动，故当时本批不存在「已修复」项。**本批 6 条随后全部确认成立并已全部修复**，逐条修复内容见各分节「修复」行与下方汇总表「修复」列；无一条被推翻，故无「问题不存在」标记。
> - 「判定」列取值：**存在**（机制与触发面均核实无误）／**存在但需修正**（机制成立，文档的引证、触发面或影响叙述有偏差，已在「与文档不符处」订正）／**问题不存在**（复核或修复过程中证伪）。
> - High 门槛：崩溃、数据丢失、凭据外泄、安全门被绕过、默认生产路径上功能完全失效。
> - 本表为复核后的分级视图；每条的详细机制、可达面与证据见下方分节，修复方向与修复结果随证据行给出。

## 汇总表

| 编号 | 复核后严重度 | 模块 | 问题（复核后口径） | 判定 | 修复 |
| --- | --- | --- | --- | --- | --- |
| A-026 | 高 | 配置导出 | 出站代理用户名/密码经 KeyStore 加密存储，却在导出环节被解密后**明文**写入 JSON，且导出文件整体不再加密——凭据随备份外泄 | 存在 | 已修复：导出不再写入凭据（V10 格式），导入保留本机已有凭据 |
| A-033 | 高 | QS 磁贴 | 磁贴启停 VPN/DNS 服务不走 `isLocked/unlockAndRun`（`isSecure` 全仓未设=默认非安全）：锁屏面板可直接启停服务，静默解除全部域名过滤/应用管控 | 存在 | 已修复：`onClick` 统一走 `isLocked` → `unlockAndRun` |
| A-043 | 高 | DNS 查询工具 | `isIpLiteral`「含冒号即 IP 字面量」放行 `8.8.8.8:53`，`InetAddress.getByName` 裸调无保护 → 常规入口必崩 `UnknownHostException` | 存在 | 已修复：按 IPv4/IPv6 结构判定字面量，查询侧 `runCatching` 兜底 |
| A-062 | 高 | Go MITM 分帧 | 元素隐藏注入后响应删光 Content-Length/TE 且 `Uncompressed=true`：HTTP/1.1 keep-alive 下 body 无任何定界 → 浏览器文档永不结束、代理双向互等 | 存在 | 已修复：注入响应置 `resp.Close=true`，以连接关闭定界并保持流式 |
| A-076 | 高 | VPN 路由覆盖 | 默认开启的「绕过局域网」IPv4 补集漏 116–119/8 与 122–123/8（约 1 亿在用公网 IP）：这些直连流量完全绕过 TUN，域名规则/MITM/QUIC·DoT 阻断/禁止联网/流量统计对其全部失效 | 存在 | 已修复：补齐 116–119/8、122–123/8 直连段，并集回归全 0–255 |
| A-086 | 高 | Go 全隧道出站 | `bufferedTun.drain` 首次 TUN 写错误即永久 `return`，而 `Write` 恒返 `len(p), nil` 向 gVisor 谎报成功 → 网络切换一次瞬断后整个隧道输出黑洞化，只能重启 VPN 会话恢复 | 存在 | 已修复：写失败退避重试并自愈，不再退出写协程 |

---

## A-026 出站代理凭据明文导出

- **机制**：存储侧 `OutboundProxySettingsStore.kt:61-62` 以 AndroidKeyStore AES/GCM（`diting_outbound_proxy`）加密保存用户名/密码；导出侧 `ConfigExporter.kt:137-138` 先 `decryptProxySecret` 再 `put("password", proxyConfig.password)` 写原文，`ConfigTransferViewModel.kt:82-86` 经 `openOutputStream(uri, "wt")` 原文落盘——全导出链无任何再加密/信封步骤。导入侧会重加密（`NetworkFeatureConfigImporter.kt:87-98`），故往返正确，缺陷纯在导出面。
- **可达面**：NORMAL 设置页配代理 → 配置导出（`normal/ui/ConfigTransferScreen.kt` 勾选代理）。模式门：EXPRESS 被 `ConfigExporter.kt:130` 排除；NORMAL minApi 29。
- **证据**：`Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:137-138`
- **与文档不符处**：无。
- **修复**：导出改为不写凭据——`ConfigExporter` 的 `outboundProxy` 节点只保留 `enabled/protocol/host/port/proxyAppPackage` 并置 `credentialsOmitted=true`，KeyStore 里的用户名/密码不再有明文副本落盘；配置格式 `FORMAT_VERSION` 由 9 升至 10，解析侧仍接受 V9 文件里的 `username/password`（旧备份可导入），`NetworkFeatureConfigImporter` 在凭据缺省时沿用本机已存凭据而非清空，避免导入即丢代理认证。回归测试 `ui/transfer/ConfigTransferParserOutboundProxyTest.kt` 覆盖 V10 无凭据解析、V9 带凭据兼容与字段缺省三种形态。

## A-033 QS 磁贴启停服务绕过设备认证

- **机制**：`tile/DitingTileService.kt:51-55` 的 `onClick` 按工作模式直达 `toggleDnsService`/`DnsVpnService.startIntent`/`ExpressVpnController`，三个 toggle（`:58-127`）均无锁检查；锁检查 `isLocked/unlockAndRun` 仅存在于 `:155-156` 的「打开主界面」路径。`isSecure` 全仓（main+test）零命中 → 磁贴默认非安全，锁屏可交互。
- **可达面**：`TileService` since=24，三模式磁贴均在锁屏可达面内。`:96-98` 的 `startForegroundService` 失败回退才走锁检查，成功路径仍绕锁（部分缓解）。
- **证据**：`Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:51-55`、`:155-156`
- **与文档不符处**：无。修复无障碍（`isLocked/unlockAndRun` 与 `TileService` 同为 API 24）。
- **修复**：`onClick` 拆为「认证闸门 + `performTileAction()`」两段，锁屏时统一走 `unlockAndRun { performTileAction() }`，解锁后原样执行（含初始协议检查与按工作模式分发）。磁贴上的启停、VPN 授权弹窗引导、跳转主界面三条路径现在同受设备认证保护。

## A-043 DNS 查询工具自定义服务器必崩

- **机制**：`core/dns/DnsProvider.kt:378` `if (trimmed.contains(":")) return true`（「含冒号即 IP」判据）放行 `8.8.8.8:53` 类带端口输入；`ui/NetworkToolsViewModel.kt:246` 随后裸调 `listOf(InetAddress.getByName(customServer))`，处于 `:204 viewModelScope.launch(Dispatchers.IO)` 无 `runCatching`——同分支 SYSTEM 路径 `:230` 却用 `runCatching{...}.getOrNull()`，不对称坐实。异常沿未捕获链杀进程。
- **可达面**：网络工具 → DNS 查询 → 服务器「自定义」→ 粘带端口 IP → 查询。无设备门、无模式门（工具页独立于 VPN 状态）。`isIpLiteral` 还喂 `isValidDnsHost`/`isValidDotHost`。
- **证据**：`Android/app/src/main/java/com/haoze/diting/core/dns/DnsProvider.kt:373-381`；`ui/NetworkToolsViewModel.kt:240,246`
- **与文档不符处**：仅行号微偏（SYSTEM 分支 `runCatching` 在 `:230`，文档作 `:231`），机制与后果全部成立。
- **修复**：`isIpLiteral` 改为结构化判定——IPv4 按 `^(\d{1,3}\.){3}\d{1,3}$` 且逐段 0–255；IPv6 支持压缩式、8 组 hextet、IPv4 内嵌尾段与 `%zone`，方括号仅在 `[<ipv6>]` 整体成对时接受，故 `8.8.8.8:53`、`[::1]:53`、`example.com:853` 均判否；`isValidDotHost` 补拒 IP 字面量与冒号，`isValidDnsHost` 接受 IP 但拒 host:port。查询侧对 `InetAddress.getByName` 加 `runCatching`，失败改为提示「无法解析自定义 DNS 服务器地址」。回归测试 `core/dns/DnsProviderIpLiteralTest.kt` 覆盖 7 类正反例。

## A-062 元素隐藏注入后 HTTP/1.1 响应零定界

- **机制**：`Android/tunnel/mitm_common.go:64-73` 注入后 `resp.Header.Del("Content-Length")`、`.Del("Transfer-Encoding")`、`resp.TransferEncoding=nil`、`resp.Uncompressed=true`——Go `net/http` `response.go:296` 的 `!r1.Uncompressed` 条件使 `Connection: close` 不被自动补，keep-alive 下 body 无任何定界。真实 stdlib 实测 `resp.Write` 产出「`HTTP/1.1 200 OK` + 无 CL/TE/close + body」三无形态。`mitm_relay.go:160-177` 循环不关连接回头读下一请求 → 双向互等、浏览器文档永不结束。
- **可达面**：NORMAL 明文 HTTP 与 HTTPS 解密流；门 = 任一启用元素隐藏规则（`cosmeticRulesEmpty()==false`）+ `text/html`。一旦启用命中面为**全部**注入响应。HEAD 子缺陷实测同现。
- **证据**：`Android/tunnel/mitm_common.go:64-73`；`mitm_relay.go:160-161`
- **与文档不符处**：无（行号、stdlib 引用、修复建议均独立复现成立）。
- **修复**：`wrapResponseForInjection` 在清空 CL/TE 后显式置 `resp.Close = true`，由 `Response.Write` 输出 `Connection: close` 完成定界——不缓冲整包算 Content-Length，保留大页面流式注入；`mitm_relay.go:175` 本就在 `resp.Close` 时结束该流并关连接，语义自洽。回归测试 `Android/tunnel/mitm_wrap_test.go` 断言注入响应必带 `Connection: close`／chunked／Content-Length 之一、HEAD 子缺陷、以及注入仍为流式（不整体缓冲）。

## A-076 「绕过局域网」IPv4 补集漏公网大段

- **机制**：`normal/DnsVpnTunnelManager.kt:329-332` 的 `IPV4_BYPASS_LAN_ROUTES` 枚举 112/6、120/7、124/7、126/8，未覆盖 **116–119/8 与 122–123/8**（中国电信/联通/阿里云/腾讯云在用段）；`SystemSettingsStore.kt:12 DEFAULT_BYPASS_LAN_ENABLED=true`，`:172-175` 在 bypassLan 时 `addRoute` 这些直连段。逐 route 按 /24 自算并集：未覆盖恰为 {0,10,116,117,118,119,122,123,127,169.254,172.16–31,192.168,224–255}，除漏段外均为有意私网/回环/组播。漏段规模 6×2²⁴ = 100,663,296 ≈「约 1 亿」。
- **可达面**：默认开启、NORMAL 全量生效（Express 走窄路由+劫持 IP /32、DNS_MODE 无 TUN，均不相干）。IP 直连流量的域名复核/MITM/QUIC·853 阻断/UID 阻断/Go 计流五类管控同时静默失效、用户不可感知。v6 侧 `2000::/3` 整体捕获，形成 v4/v6 不对称反证「手写疏漏」。
- **证据**：`Android/app/src/main/java/com/haoze/diting/normal/DnsVpnTunnelManager.kt:329-332`、`:172-175`
- **与文档不符处**：无实质不符。改 `112.0.0.0/4` 补集需与 `128.0.0.0/3` 起点协同（无冲突），改完须全 0–255 回归。
- **修复**：直连段由 `112.0.0.0/6` 细分为 `112/7 + 114/8 + 115/8`，补 `116.0.0.0/6`（覆盖 116–119/8）与 `122.0.0.0/7`（覆盖 122–123/8），其余段不变。回归测试 `normal/DnsVpnTunnelManagerBypassRoutesTest.kt` 按位运算求补集，断言补集恰为 {0/8,10/8,127/8,169.254/16,172.16/12,192.168/16,224/3}、原已覆盖公网段无回归、且 116–119/8 与 122–123/8 已进入隧道。

## A-086 bufferedTun 一次写错误永久黑洞化出站面

- **机制**：`Android/tunnel/engine_full_tunnel.go:56-67` 的 `Write` 在入队满时 `tunPacketPool.Put(bufp); return len(p), nil`——丢弃数据包却恒报写成功，gVisor 据此认为已送达而无限重传；`:77-79` `drain` 首次 TUN 写错误即 `logf + return`（永久退出、无重启），`halt` 仅在 `:176/:198` 会话收尾调用。出站包进 2048 队列→满→静默丢弃，一次网络 handover 瞬断后整个隧道输出黑洞化。
- **可达面**：Android 网络切换/接口 flap 期间 ENETDOWN/EINVAL 为现实来源；legacy packetPipe `engine_mitm.go:124-137` 同型首错 return。触发中频，仅重启 VPN 会话恢复且无自愈。
- **证据**：`Android/tunnel/engine_full_tunnel.go:56-67`、`:77-79`
- **与文档不符处**：无。
- **修复**：`drain` 不再因写错误退出。新增 `writeWithRetry`：单包最多 40 次尝试、5ms 起指数退避封顶 100ms，全部失败才丢该包并计数，写协程继续存活；连续失败后进入降级态（`healthy=false`，后续包单次尝试即丢，避免每包付满退避阻塞队列），任一写成功即恢复并记日志。`halt` 改 `sync.Once` 关闭（多路径收尾不再重复 close 崩溃）。`bufferedTun` 增加可注入 `writer` 以便测试。回归测试 `Android/tunnel/engine_full_tunnel_test.go` 覆盖瞬断自愈、退避预算耗尽后仍存活并恢复、降级态不付满退避、`halt` 幂等与队列满不阻塞。同时重新生成 `Android/app/libs/tunnel.aar`。
