---
章节: 10-go-tunnel-engine（续 3/3）
主题: Flutter 重构注意、重写风险清单、死代码候选、待定项
最后校验: 2026-10-18
---

# 10.7 Flutter 重构注意

## 10.7.1 必须逐字冻结的接口面（gomobile ABI + JSON 契约）

若 Go 引擎保留为库、Kotlin/Flutter 侧重写，以下任一改动都要求 AAR 重生成与两端联调：

1. **Engine 导出方法名与参数类型**（10.4.1 全表）。gomobile 把 `GetDNSCacheStats` 绑定为 `getDNSCacheStats` 的反射取用（GoInspectionTunnel.kt:118-120）已经脆弱，改名即断。
2. **7 个回调接口的参数顺序与数量**：`RaceLogCallback` 13 参、`LogCallback` 9 参、`BatchLogCallback` 的 JSON 键名 `d,b,t,r,a,i,k,e,c,ts,ttl`（ttl 无 omitempty 的语义必须保留）。
3. **JSON 契约**：规则快照（15 顶层键）、dnsConfig（mode 枚举含 `race/prediction/brute_force_parallel` 别名）、rewrite map 值 string|array 混容、appAllowlist 键为 UID 字符串、outbound 配置 host 回环校验。
4. **二进制格式**：DTRI（Kotlin 写、Go 读，头 36B、node/edge 12B、内嵌 bloom 7 哈希 FNV 变体）、旧 TRIE v2/BLOOM v1——哈希函数任何一端改动即静默失配（domain_bloom_filter.go:17 头注释明言此约束）。
5. **fd 语义**：`StartFull(fd)` 内部 `dupFd` 建立独立所有权；调用方关闭原 fd 不影响 Go 侧。`Stop()+ReleaseTun()` 两段式析构顺序（GoInspectionTunnel.kt:105-110）不可交换。
6. **`local.pwhs.app` + 198.51.100.1**：用户可能已在规则/白名单里引用该主机名；合成 IP 落在 TEST-NET-2，若改段需同步 MITM 本地服务、DNS 合成、Kotlin 侧任何硬编码。
7. **隐式默认**：`blockEncryptedDNS` 默认 true、`filterDNS` 默认 true、`responseType` 默认 CustomIP、MTU 1400、DoT 空闲 15s、UDP 空闲 30s、流拨号 10s —— Kotlin 依赖"启动前必须推 SetBlockEncryptedDns"的约定（engine.go:145-148 注释），Flutter 重写时漏推 = 行为不变但用户开关失效。

## 10.7.2 gomobile 类型约束（重写时最容易踩的）

- 导出 API 只用 string/int/int64/bool/[]byte/error 与接口；一切结构化数据走 JSON 字符串——这是本包 `ApplyRuleSnapshot` 返回**错误串而非 error**（engine_config.go:51）而 `ApplyDNSConfig` 返回 **error**（dns_config.go:107）风格分裂的根因：gomobile 两者都可绑，历史选择不同。Flutter/Dart 侧 FFI 重写时建议统一为 error 或返回结构。
- `ServeDNS(w dns.ResponseWriter, r *dns.Msg)` 虽导出但不可过 JNI（非可绑类型），只作为包内 Handler 适配点（engine_standalone.go:24-26）——判"导出=在用"时必须排除这类。
- `ResolveApp(ip []byte, port []byte)` 用 []byte 是为绕开 cgocheck 对 String 参数转换的开销/告警（engine_types.go 注释），Dart FFI 无此约束但也无零拷贝语义。

## 10.7.3 运行时形态迁移

- 会话线程模型：`StartFull` 阻塞整会话（Kotlin 在专属线程跑），`Stop` 从任意线程重入安全；Dart isolate 重写时注意 done-channel 语义对应。
- CA 助手（GoInspectionCaManager.kt:24-27）**每次铸证新建 Engine**：依赖"idle Stop 也回收 ticker"这一修复；若重写引擎省略 idle 释放，将重新泄漏 goroutine/线程（A-017 回归面）。
- 包级全局 `cosmeticCSS`（mitm_cosmetic_inject.go:30-46）跨 Engine 实例共享：多实例场景下最后一个 `SetCosmeticRules` 生效；Dart 重写若改为实例字段，CA 助手那种临时实例注入空 CSS 的行为会变成"清空全局"→需要显式设计。
- `logf` 写 stderr + `[DITING/Go]` 前缀（engine.go:401-404）：现有日志采集按此前缀过滤，重写要保留或同步改采集。

# 10.8 重写风险清单（按危险度排序）

1. **TUN 写路径自愈**（engine_full_tunnel.go:88-170）：`Write 永不报错 + 满队列丢弃 + drain 重试保活 + healthy 单探` 四件事缺一回归旧 bug（网络切换永久黑洞 / gVisor 丢错误语义）。注释完整，务必整段移植。
2. **sessionGen 代际协议**（O-104/A-017 耦合）：新引擎若给 Stop 加 `!running` 早退会回归缓存泄漏，若去掉代际会回归 TUN 栈泄漏——两个反例都有测试钉住（engine_session_race_test.go、engine_lifecycle_test.go），重写后这两个测试必须等价迁移。
3. **serveDNS 单流水线双入口**：全隧道 UDP/TCP:53 与 standalone 共用；任何"按入口分叉"的重构都会造成行为漂移（AGENT_MISTAKES:55 明确警告过）。`effectiveBlockResponseType` 的动态升级（dns_config.go:58-90 阈值→NXDOMAIN 临时拉黑）两条流水线必须一致（engine_config.go:410-415 注释）。
4. **应用白名单 netd 扇出与缓存命中续授权**（engine_app_allowlist.go:105-116 修复史）：改动 getFast 返回形状极易回归"永久拦截"。
5. **DNS 缓存 wire 原位改写**：TTL 偏移表跳过 OPT、命中改 ID+剩余 TTL（下限 1）、拒 Truncated、负缓存强制开——用结构体重建会破坏 byte-exact 转发语义与性能。
6. **MITM 自动拉黑阈值**（3/2 次、10min 窗口、7 天 TTL、文件持久化）与 client-first 握手顺序（省电设计，mitm_relay.go）。
7. **DoH 403=rate limited、EOF 单重试、DoT 空闲探活、DoQ 帧协议、Plain TC=1 TCP 重试**等传输怪癖，都是真实上游行为沉淀，重写时逐项对照。
8. **validateDNSResponse 把非 NOERROR/NXDOMAIN 记 provider 失败**：竞速正确性的根，放宽即污染评分。
9. **bootstrap 串行 failover**（非并发）：改并发竞速会放大 DNS 放大攻击面且打分模型失效（Kotlin UI 镜像同公式）。
10. **规则快照原子发布顺序**：先 resolver/cache 配置成功、后 publish blockResponse/dynamic/dnsConfig（A-023），颠倒即出现"配置半新半旧"窗口。
11. **文件行数红线 550**：engine_standalone.go(548)、engine_dns.go(503)、flow_outbound.go(503)、policy_engine.go(498) 已贴顶，拆分需同包并复查 import 与构建（AGENT_MISTAKES:71）。

# 10.9 死代码 / 不可达候选（均经双向 grep 取证）

**判定口径**：Go 导出方法 → 生成 Java（tunnel-sources.jar 内 tunnel/Engine.class 绑定）→ Kotlin/Java 调用点 + 反射字符串；内部函数 → 包内调用链。

- **`Engine.Start(fd, protector)`**（engine.go:154-213）及其整条 legacy 拦截链：`DnsInterceptor`（dns_interceptor.go:66 调 handleDNSQuery）、`handleDNSQuery`（engine_dns.go:21，仅经 interceptor 可达）、`Router`/`NewRouter`、`tcpStackPipe`/`packet_pipe.go`、`useTcpStack` 读取点（engine.go:200）、`dns_packet.go` 的 `Build*Response`/`buildIPUDPPacket`（**仅** engine_dns.go 使用）、`ParseTUNPacket`、`Engine.SetDNS`（engine_config.go:378）、`SetFirewallChecker`（:278）、`SetAppResolver`（:282）、`FirewallChecker`/`AppResolver` 接口注入点。AGENT_MISTAKES.md:54（A-089）独立确认零调用；注意 `SetUseTcpStack` 被 Kotlin 调用但效果只作用于 legacy `Start`，属"活调用打死路径"。
- **原生 trie+bloom 规则路径**：`SetTries`/`SetImportantTries`（engine_rules.go 或 engine_config.go 系）、`CompileFilterList*`、`hasNativeRules/hasImportantRules` 的全部置真点，及 `engine_dns.go`/`engine_standalone.go:197-247` 中读 `adTries/secTries/adBlooms/secBlooms/importantTries` 的扫描块。`LoadMmapTrie/CheckDomainInTrieFile`（engine.go:414-424）同样无 Kotlin 调用者。`domain_trie.go` 文件本身被 `rule_compiler.go`（DTRI 生成的中间结构）复用，不可随分支一起删。
- **纯导出零调用**（可安全从绑定面移除，但 `GetStats/IsRunning/GetRouter` 等需保留或迁移 UI 用途前先确认）：`GetStats`（engine.go:376，Stats JSON 无消费者）、`IsRunning`（:370）、`GetRouter`（engine_config.go:39，返回不可绑类型本就绑不过去）、`SetOutboundAdapter`（:43，`OutboundAdapter` 接口整族）、`IsDomainBlocked/IsDomainBlockedForApp`（Kotlin 零调用，**但** mitm MITM 流水线经 `adBlockChecker` 接口消费 Engine 自身方法——不可删实现，只可解除绑定）、`IsMitmActive`、`GetMitmCACert`、`ClearMitmBlacklist`、`SetHttpsBypassRules`（已被 `SetExtraPassthroughSuffixes` 取代，二者同实现）、`IsUsingTcpStack`、包级 `NewEngine/NewResolver/NewRouter/NewTcpIpStack/NewMitmFilter/NewCertManager/NewDirectOutbound/NewInjectingReader/NewWildcardPattern/ParseProtocol/ParseResponseType/ServeLocalAsset/IsLocalAssetHost/ShouldInjectHTML`（Go 内部或测试使用，gomobile 侧无 Kotlin 调用者）。
- **`mitm_local_server.go` /health 端点**：Go 内注释与 Kotlin 均无调用者（诊断遗留），随本地资产整体保留或整体移除均可，属低危。
- 规模参考：上述死面集中在 dns_interceptor.go、dns_packet.go、engine_dns.go、packet_pipe.go、router.go、ip_stack 旁路及 engine.go 前半，粗估 1200-1500 行可退役（未逐行核算，见待定）。

# 10.10 待定（本轮未能取证）

1. **AAR 构建脚本缺位**：仓内无 gomobile 调用脚本（build_apk.bat 不含绑定步骤），构建流程在维护者本机；Flutter 化前需先固化 bind 命令与 `gomobile bind -work` 差分验证流程（AGENT_MISTAKES.md:51）。
2. **`claimFullTunnelSession` 注释引用**（engine.go:93）指向不存在的符号：是历史上被内联的重命名遗漏，无法从 git 单文件读取确证原始设计意图。
3. **cosmeticCSS 包级全局是否有意**：多 Engine 并发（CA 助手临时实例）与主引擎生命周期重叠时是否造成过实际错误，静态无法定论，需运行期日志。
4. **Kotlin `DomainChecker` 其余 6 方法**：Go 只调 `CheckDomain`，其余可能是历史版本 Go 曾调用的残留契约（engine_types.go 接口注释不足以定版）。
5. **bootstrap "racing" 头注释 vs 串行实现**（bootstrap_resolver.go）：按铁律 4 记为「文档与实现不一致，本轮不改」，不判"不存在"也不判"缺陷"——串行本身可能是修复 failover 风暴后的有意行为。
6. **Express 模式独立 DNS 栈** 与本文 Go 引擎的行为差异清单（属相邻章节职责）。
7. **死代码行数**为区间估计：逐文件退役清单建议以「先解除 gomobile 绑定→差分构建→再删实现」三步走，删除前每处再跑一次本会话口径的双向 grep。
