# 安卓端缺陷分级 · High

> 本文档由对 `docs/desktop-bug-report.md`（扫描基线 `main @ 3a048c5`）的逐条复核产出的**高严重度**缺陷构成。分级依据为**复核后严重度**（可能与原文档标注不同）：严重度 = 缺陷机制 × 可达面，两者分别经源码回读、caller/write 点 grep 与（适用时）实机复算核实。
>
> - 基线 `3a048c5` 之后 Android 与 Go 源码零改动（`git diff --name-only 3a048c5..HEAD -- Android/` 为空），故本批不存在「已修复」项；复核焦点是每条的机制与触发面是否被证实。
> - 「判定」列取值：**存在**（机制与触发面均核实无误）／**存在但需修正**（机制成立，文档的引证、触发面或影响叙述有偏差，已在「与文档不符处」订正）。
> - High 门槛：崩溃、数据丢失、凭据外泄、安全门被绕过、默认生产路径上功能完全失效。
> - 每条的详细正文、位置引证与修复方向见原文档对应小节；本表为复核后的分级视图。

## 汇总表

| 编号 | 复核后严重度 | 模块 | 问题（复核后口径） | 判定 |
| --- | --- | --- | --- | --- |
| A-026 | 高 | 配置导出 | 出站代理用户名/密码经 KeyStore 加密存储，却在导出环节被解密后**明文**写入 JSON，且导出文件整体不再加密——凭据随备份外泄 | 存在 |
| A-033 | 高 | QS 磁贴 | 磁贴启停 VPN/DNS 服务不走 `isLocked/unlockAndRun`（`isSecure` 全仓未设=默认非安全）：锁屏面板可直接启停服务，静默解除全部域名过滤/应用管控 | 存在 |
| A-043 | 高 | DNS 查询工具 | `isIpLiteral`「含冒号即 IP 字面量」放行 `8.8.8.8:53`，`InetAddress.getByName` 裸调无保护 → 常规入口必崩 `UnknownHostException` | 存在 |
| A-062 | 高 | Go MITM 分帧 | 元素隐藏注入后响应删光 Content-Length/TE 且 `Uncompressed=true`：HTTP/1.1 keep-alive 下 body 无任何定界 → 浏览器文档永不结束、代理双向互等 | 存在 |
| A-076 | 高 | VPN 路由覆盖 | 默认开启的「绕过局域网」IPv4 补集漏 116–119/8 与 122–123/8（约 1 亿在用公网 IP）：这些直连流量完全绕过 TUN，域名规则/MITM/QUIC·DoT 阻断/禁止联网/流量统计对其全部失效 | 存在 |
| A-086 | 高 | Go 全隧道出站 | `bufferedTun.drain` 首次 TUN 写错误即永久 `return`，而 `Write` 恒返 `len(p), nil` 向 gVisor 谎报成功 → 网络切换一次瞬断后整个隧道输出黑洞化，只能重启 VPN 会话恢复 | 存在 |

---

## A-026 出站代理凭据明文导出

- **机制**：存储侧 `OutboundProxySettingsStore.kt:61-62` 以 AndroidKeyStore AES/GCM（`diting_outbound_proxy`）加密保存用户名/密码；导出侧 `ConfigExporter.kt:137-138` 先 `decryptProxySecret` 再 `put("password", proxyConfig.password)` 写原文，`ConfigTransferViewModel.kt:82-86` 经 `openOutputStream(uri, "wt")` 原文落盘——全导出链无任何再加密/信封步骤。导入侧会重加密（`NetworkFeatureConfigImporter.kt:87-98`），故往返正确，缺陷纯在导出面。
- **可达面**：NORMAL 设置页配代理 → 配置导出（`normal/ui/ConfigTransferScreen.kt` 勾选代理）。模式门：EXPRESS 被 `ConfigExporter.kt:130` 排除；NORMAL minApi 29。
- **证据**：`Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:137-138`
- **与文档不符处**：无。

## A-033 QS 磁贴启停服务绕过设备认证

- **机制**：`tile/DitingTileService.kt:51-55` 的 `onClick` 按工作模式直达 `toggleDnsService`/`DnsVpnService.startIntent`/`ExpressVpnController`，三个 toggle（`:58-127`）均无锁检查；锁检查 `isLocked/unlockAndRun` 仅存在于 `:155-156` 的「打开主界面」路径。`isSecure` 全仓（main+test）零命中 → 磁贴默认非安全，锁屏可交互。
- **可达面**：`TileService` since=24，三模式磁贴均在锁屏可达面内。`:96-98` 的 `startForegroundService` 失败回退才走锁检查，成功路径仍绕锁（部分缓解）。
- **证据**：`Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:51-55`、`:155-156`
- **与文档不符处**：无。修复无障碍（`isLocked/unlockAndRun` 与 `TileService` 同为 API 24）。

## A-043 DNS 查询工具自定义服务器必崩

- **机制**：`core/dns/DnsProvider.kt:378` `if (trimmed.contains(":")) return true`（「含冒号即 IP」判据）放行 `8.8.8.8:53` 类带端口输入；`ui/NetworkToolsViewModel.kt:246` 随后裸调 `listOf(InetAddress.getByName(customServer))`，处于 `:204 viewModelScope.launch(Dispatchers.IO)` 无 `runCatching`——同分支 SYSTEM 路径 `:230` 却用 `runCatching{...}.getOrNull()`，不对称坐实。异常沿未捕获链杀进程。
- **可达面**：网络工具 → DNS 查询 → 服务器「自定义」→ 粘带端口 IP → 查询。无设备门、无模式门（工具页独立于 VPN 状态）。`isIpLiteral` 还喂 `isValidDnsHost`/`isValidDotHost`。
- **证据**：`Android/app/src/main/java/com/haoze/diting/core/dns/DnsProvider.kt:373-381`；`ui/NetworkToolsViewModel.kt:240,246`
- **与文档不符处**：仅行号微偏（SYSTEM 分支 `runCatching` 在 `:230`，文档作 `:231`），机制与后果全部成立。

## A-062 元素隐藏注入后 HTTP/1.1 响应零定界

- **机制**：`Android/tunnel/mitm_common.go:64-73` 注入后 `resp.Header.Del("Content-Length")`、`.Del("Transfer-Encoding")`、`resp.TransferEncoding=nil`、`resp.Uncompressed=true`——Go `net/http` `response.go:296` 的 `!r1.Uncompressed` 条件使 `Connection: close` 不被自动补，keep-alive 下 body 无任何定界。真实 stdlib 实测 `resp.Write` 产出「`HTTP/1.1 200 OK` + 无 CL/TE/close + body」三无形态。`mitm_relay.go:160-177` 循环不关连接回头读下一请求 → 双向互等、浏览器文档永不结束。
- **可达面**：NORMAL 明文 HTTP 与 HTTPS 解密流；门 = 任一启用元素隐藏规则（`cosmeticRulesEmpty()==false`）+ `text/html`。一旦启用命中面为**全部**注入响应。HEAD 子缺陷实测同现。
- **证据**：`Android/tunnel/mitm_common.go:64-73`；`mitm_relay.go:160-161`
- **与文档不符处**：无（行号、stdlib 引用、修复建议均独立复现成立）。

## A-076 「绕过局域网」IPv4 补集漏公网大段

- **机制**：`normal/DnsVpnTunnelManager.kt:329-332` 的 `IPV4_BYPASS_LAN_ROUTES` 枚举 112/6、120/7、124/7、126/8，未覆盖 **116–119/8 与 122–123/8**（中国电信/联通/阿里云/腾讯云在用段）；`SystemSettingsStore.kt:12 DEFAULT_BYPASS_LAN_ENABLED=true`，`:172-175` 在 bypassLan 时 `addRoute` 这些直连段。逐 route 按 /24 自算并集：未覆盖恰为 {0,10,116,117,118,119,122,123,127,169.254,172.16–31,192.168,224–255}，除漏段外均为有意私网/回环/组播。漏段规模 6×2²⁴ = 100,663,296 ≈「约 1 亿」。
- **可达面**：默认开启、NORMAL 全量生效（Express 走窄路由+劫持 IP /32、DNS_MODE 无 TUN，均不相干）。IP 直连流量的域名复核/MITM/QUIC·853 阻断/UID 阻断/Go 计流五类管控同时静默失效、用户不可感知。v6 侧 `2000::/3` 整体捕获，形成 v4/v6 不对称反证「手写疏漏」。
- **证据**：`Android/app/src/main/java/com/haoze/diting/normal/DnsVpnTunnelManager.kt:329-332`、`:172-175`
- **与文档不符处**：无实质不符。改 `112.0.0.0/4` 补集需与 `128.0.0.0/3` 起点协同（无冲突），改完须全 0–255 回归。

## A-086 bufferedTun 一次写错误永久黑洞化出站面

- **机制**：`Android/tunnel/engine_full_tunnel.go:56-67` 的 `Write` 在入队满时 `tunPacketPool.Put(bufp); return len(p), nil`——丢弃数据包却恒报写成功，gVisor 据此认为已送达而无限重传；`:77-79` `drain` 首次 TUN 写错误即 `logf + return`（永久退出、无重启），`halt` 仅在 `:176/:198` 会话收尾调用。出站包进 2048 队列→满→静默丢弃，一次网络 handover 瞬断后整个隧道输出黑洞化。
- **可达面**：Android 网络切换/接口 flap 期间 ENETDOWN/EINVAL 为现实来源；legacy packetPipe `engine_mitm.go:124-137` 同型首错 return。触发中频，仅重启 VPN 会话恢复且无自愈。
- **证据**：`Android/tunnel/engine_full_tunnel.go:56-67`、`:77-79`
- **与文档不符处**：无。
