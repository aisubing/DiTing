# 安卓端 Bug 记录

> 文件名沿用项目既定约定（`docs/desktop-bug-report.md`），内容为安卓客户端扫描结果，不包含桌面端问题。
>
> - 扫描基线：`main` @ `6da118e`
> - 扫描范围：`Android/app/src/main/java/com/haoze/diting/`
> - 记录原则：只记录问题，不修改代码；每条给出代码位置、触发路径和验证方式。存疑但未达到确认标准的事项统一放在文末“观察”。
> - 验证状态：本轮结论来自代码路径静态核对。本机 SDK 缺少 `android-36.1` 平台且无连接设备，未能执行 JVM 单测或真机复现；每条附带的验证步骤可在具备对应 SDK/设备的环境直接执行。

## 汇总

| 编号 | 严重度 | 模块 | 问题 |
| --- | --- | --- | --- |
| A-001 | 中高 | 规则解析 | 通用元素隐藏规则（`##`、`#@#`、`#?#`、`#$#`）被当作注释整行丢弃 |
| A-002 | 高 | 元素隐藏 | 元素隐藏规则编译时忽略域名作用域，并把 `#@#` 例外反向编译为隐藏 |
| A-003 | 中 | DNS 工具 | DNS 查询未把国际化域名转成 Punycode，中文域名被编码为 `??` |
| A-004 | 中 | DNS 模式上游 | 自定义上游校验接受非法 IPv6 / `IPv4:端口` 字符串，保存后服务不可用 |
| A-005 | 中 | 极速模式启动 | 规则缓存异步加载完成前 TUN 已开始处理查询，连接初期的拦截/放行规则不生效 |
| A-006 | 中 | DNS 缓存清理 | 清理 DNS 缓存只清内存与数据库，未清待落盘队列，约 30 秒后缓存条目被重新写回 |
| A-007 | 低 | 快捷设置磁贴 | `requestListeningState` 使用拼接错误的组件名，运行状态变化时磁贴刷新请求全部失效 |

---

## A-001 通用元素隐藏规则被当作注释整行丢弃

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/AdGuardRuleParser.kt:177-183`
  - `Android/app/src/main/java/com/haoze/diting/core/rule/AdblockRuleLineParser.kt:9-12`、`:230-263`
  - `Android/app/src/main/java/com/haoze/diting/ui/BlacklistViewModel.kt:327-336`
- **问题**
  - `##.ad-banner`、`#@#.ad-banner`、`#?#div`、`#$#body{...}` 这类不带域名前缀的通用元素隐藏规则无法被解析，导入时被静默忽略，手动添加时固定提示“元素隐藏规则格式无效”。
  - 只有 `example.com##.ad-banner` 这类带域名前缀的规则可以正常解析。
- **机制**
  - `parseCategorizedLine` 在分发给具体解析器之前先做行级过滤：`line.startsWith("#")` 直接返回 `CategorizedLine(ignoredCount = 1)`，注释判断发生在 cosmetic 解析之前。
  - 但下游 `AdblockRuleLineParser.parseCosmeticLine` 明确支持无域名形式：`domainPart.isEmpty()` 时使用 `listOf("")` 生成全局规则（`AdblockRuleLineParser.kt:248-252`）；`ParsedCosmeticRule` 与 `CosmeticRuleEntity` 也都把空 `domain` 定义为全局规则。
  - 因此这是解析顺序造成的误判，而不是不支持该语法。`#` 同时是 hosts/Adblock 注释符，过滤逻辑没有先识别 `##`、`#@#`、`#?#`、`#$#` 分隔符。
- **用户可见影响**
  - 订阅导入：`CategorizedRuleStreamImporter` 只累加 `invalidCount`/`unsupportedCount`，从不读取 `ignoredCount`；通用规则既不计入 `parsedRules`/`cosmeticCount`，也不计入无效/不支持统计，用户在导入结果中完全看不到规则被丢弃。
  - 手动添加：黑名单输入 `##.ad-banner` 提示“元素隐藏规则格式无效”；白名单输入 `#@#.ad-banner` 同样提示“元素放行规则格式无效”（`WhitelistViewModel.kt:407-413`）。功能表现为“不支持通用元素隐藏”。
  - 现有 `AdGuardRuleParserTest` 只覆盖带域名前缀的 cosmetic 规则，未覆盖该分支，回归未暴露。
- **复现/验证**
  1. 普通模式 → 黑名单 → 手动输入 `##.ad-banner` → 添加；实际提示“元素隐藏规则格式无效”，期望添加成功并生成全局 CSS。
  2. 对 `AdGuardRuleParser.parseCategorizedLine("##.ad-banner")` 断言：实际 `ignoredCount == 1`、`cosmeticRules.isEmpty()`；对照 `parseCategorizedLine("example.com##.ad-banner")` 返回 1 条规则。
  3. 导入含 `##.ad-banner` 的规则文件，`RuleImportSummary.cosmeticCount` 为 0，且该行不会出现在任何无效/忽略计数中（`ignoredCount` 未被汇总），对比同一文件的 `example.com##.ad-banner` 会计入 `cosmeticCount`。
- **备注**：修复时需要先识别 cosmetic 分隔符，再判断整行是否为注释；不能简单放宽所有 `#` 开头的行。

---

## A-002 元素隐藏规则忽略域名作用域，`#@#` 例外被反向执行为隐藏

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/CosmeticRuleManager.kt:37-51`
  - `Android/app/src/main/java/com/haoze/diting/data/entity/CosmeticRuleEntity.kt:8-27`
  - `Android/app/src/main/java/com/haoze/diting/data/dao/CosmeticRuleDao.kt:24-25`
  - `Android/app/src/main/java/com/haoze/diting/core/rule/CategorizedRuleStreamImporter.kt:165-186`
  - `Android/app/src/main/java/com/haoze/diting/normal/GoTunnelRuleManager.kt:112-123`
  - `Android/app/src/main/java/com/haoze/diting/ui/BlacklistViewModel.kt:338-345`
  - `Android/tunnel/mitm_relay.go:160-162`、`Android/tunnel/mitm_local_server.go:31-40`
- **问题**
  - 添加 `example.com##.ad-banner` 后，访问任意其他站点，只要页面含 `.ad-banner` 也会被隐藏。
  - 导入含 `example.com#@#.ad-banner` 的列表后，`.ad-banner` 反而在所有站点被隐藏，与 `#@#`（例外/放行）的语义相反。
- **机制**
  - 解析阶段 `ParsedCosmeticRule` 保留 `domain` 与 `isException`（`AdGuardRuleModels.kt:27-36`），但持久化到 `CosmeticRuleEntity` 时只保留 `domain/selector/rawLine/enabled`；实体没有 `isException` 列，例外标记在写库时丢失。
  - `CosmeticRuleEntity` 的唯一索引只有 `(domain, selector)`（`CosmeticRuleEntity.kt:16-19`）；同域名、同选择器的普通规则与 `#@#` 例外会命中 `OnConflictStrategy.IGNORE`，复用同一条记录，例外无法独立存在。
  - `CosmeticRuleDao.enabledRules()` 只按 `r.enabled=1 AND s.enabled=1` 取规则，没有排除 `rawLine LIKE '%#@#%'` 的例外规则；UI 的 `blockRules()`/`allowRules()` 才用 `rawLine` 区分两者。
  - `CosmeticRuleManager.compileAllToCss()` 遍历所有启用规则，仅按 `rule.selector` 去重，统一生成 `selector { display: none !important; }`；完全没有读取 `rule.domain`，也没有判断例外。
  - `GoTunnelRuleManager.updateCosmeticRules()` 只把一份全局 CSS 字符串传给 `engine.setCosmeticCSS(css)`，没有按域名下发，Go 侧也没有域名映射。
  - Go 侧对所有被 MITM 的 HTML 响应注入同一个 `<link href="https://local.pwhs.app/cosmetic.css">`（`mitm_relay.go:160-162`），本地资源服务返回同一份全局 CSS（`mitm_local_server.go:31-40`），进一步确认域名作用域无法生效。
  - 结果：`domain` 字段实际只用于 UI 展示和去重键；`#@#` 被当成普通隐藏规则编译。
- **用户可见影响**
  - 作用域外溢：站点的通用 class（如 `.ad`、`.banner`）在无关网站被隐藏，可能破坏正常页面布局、按钮或内容。
  - 例外反转：本来用于放行的 `#@#` 规则会扩大隐藏范围，导入大型 AdGuard 列表时尤其明显。
  - 排查困难：UI 中规则显示为“允许”/带域名，但实际行为与之不符。
- **复现/验证**
  1. 普通模式（需开启 HTTPS 检查）→ 黑名单 → 添加 `example.com##.banner-ad`；访问另一个含 `.banner-ad` 元素的站点，该元素被隐藏。
  2. 导入含 `example.com#@#.banner-ad` 的规则文件；在 `CosmeticRuleDao.allowRules()` 中能看到该规则，但 `compileAllToCss()` 输出 `.banner-ad { display: none !important; }`。
  3. 单元测试：用假 `CosmeticRuleDao` 让 `enabledRules()` 返回 `domain="example.com", selector=".ad", rawLine="example.com##.ad"`，调用 `compileAllToCss()`，实际输出 `.ad { display: none !important; }`，没有任何域名限定；再把 `rawLine` 换成 `example.com#@#.ad`，输出仍然是隐藏而非例外。
- **备注**：修复需要按目标页面域名筛选规则，并单独维护 `#@#` 例外集合；当前只向 Go 引擎传一份 CSS，若引擎接口不支持按域名注入，需要先扩展协议。

---

## A-003 DNS 查询未支持国际化域名，中文域名被编码为 `??`

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/dns/DnsLookupTool.kt:44-53`、`:79`
  - `Android/app/src/main/java/com/haoze/diting/core/dns/DnsMessageUtils.kt:103-133`
  - `Android/app/src/main/java/com/haoze/diting/ui/NetworkToolsViewModel.kt:192-197`
  - `Android/app/src/main/java/com/haoze/diting/ui/DnsLookupSection.kt:63`
- **问题**
  - 在“网络工具 → DNS 查询”中输入 `中文.com` 等国际化域名，查询发不出去或返回 NXDOMAIN；实际查询的 QNAME 是 `??.com`。
- **机制**
  - `NetworkToolsViewModel.runDnsLookup()` 只校验空串，没有做 IDN 转换或域名格式校验。
  - `DnsLookupTool.lookup()` 仅 `host.trim()`，随后把原始字符串传给 `DnsMessageUtils.buildQuery(name, recordType.code)`。
  - `buildQuery()` 把 QNAME 按 `.` 切分后，对每个 label 调用 `label.toByteArray(Charsets.US_ASCII)`；非 ASCII 字符被替换为 `?`（0x3F），而不是转换成 Punycode（`xn--...`）。
  - 全链路没有 `IDN.toASCII`；只有规则导入路径的 `AdGuardDomainUtils.normalizeDomain` 做了正确转换。
- **用户可见影响**
  - 中文/日文/韩文等 IDN 域名无法通过内置 DNS 工具查询，用户会误以为域名不存在或 DNS 服务器故障。
  - `buildQuery` 还被 `DnsLatencyTester`、`BootstrapSelector` 等诊断路径复用，同类输入在这些入口也会得到错误查询名。
- **复现/验证**
  1. `中文.com` 的期望查询名是 `xn--fiq228c.com`（`IDN.toASCII` 结果），实际 wire QNAME 为 `??.com`。
  2. 代码/单测：`DnsMessageUtils.buildQuery("中文.com", 1)`，从偏移 12 开始读 label，第 13、14 字节为 `0x3F 0x3F`；`IDN.toASCII("中文.com") == "xn--fiq228c.com"`。
  3. UI：网络工具 → DNS 查询 → 输入 `中文.com` → A 记录 → 查询；实际失败/无结果，期望返回 `xn--fiq228c.com` 的 A 记录。
  4. 同类输入 `例子.中国` 的期望形式为 `xn--fsqu00a.xn--fiqs8s`。
- **备注**：修复时除转换 QNAME 外，Punycode 后的 label 字节数会变长，`questionLen` 必须按转换后的字节数计算，不能继续使用原始字符长度；`DnsLookupTool` 展示的 `queryName` 建议保留用户输入或同时显示 Punycode。

---

## A-004 上游地址校验接受非法 IPv6 / `IPv4:端口`，保存后 DNS 服务不可用

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/model/DnsUpstreamValidator.kt:60-67`
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:190-195`、`:207-209`
  - `Android/tunnel/dns_config.go:167-172`
  - `Android/app/src/test/java/com/haoze/diting/server/DnsModeTest.kt:200-212`
- **问题**
  - DNS/DOT 自定义上游地址填写 `1.1.1.1:53`、`:::`、`1:2`、`2001:db8::1::2` 等非法字符串时，保存校验全部通过；启动后 Go 引擎无法解析/连接，查询全部失败，但 UI 仍显示服务运行中。
- **机制**
  - `validateHost()` 只要字符串包含 `:`，就只用字符集正则 `^[0-9a-fA-F:.]+$` 判断，未做 IPv6 结构校验：
    - `1.1.1.1:53` 由数字、点、冒号组成，匹配；
    - `:::`、`1:2`、重复 `::` 等同样匹配。
  - 保存后 `DnsServerEngine.applyDnsConfig()` 对含 `:` 的地址统一加方括号：
    - `1.1.1.1:53` → `[1.1.1.1:53]:53`
    - `:::` → `[:::]:53`
  - Go 侧 `validateDNSProvider` 只用 `net.SplitHostPort` 校验（`Android/tunnel/dns_config.go:167-172`），`[1.1.1.1:53]:53` 会被解析为 `host=1.1.1.1:53, port=53` 并通过，`ApplyDNSConfig` 返回成功；直到首次查询拨号时，host 既不是合法 IP 也不是合法域名，查询才失败。
  - 由于配置应用阶段没有抛异常，`runCatching` 不会记录任何错误，UI 也不会收到提示。
  - 现有 `DnsModeTest` 只覆盖合法地址、空串和空白，没有覆盖畸形 IPv6 或“IP:端口”。
- **用户可见影响**
  - 上游配置看似保存成功，DNS 模式也能启动，但所有查询超时/失败，用户难以定位是地址写错。
  - 端口本应由独立输入框提供，地址里再写端口属于常见误操作，当前没有拦截。
- **复现/验证**
  1. DNS 模式 → 上游 → 自定义地址填 `1.1.1.1:53`，端口保持 `53` → 保存；无“地址格式不正确”提示。启动服务后查询任意域名均失败。
  2. 填 `:::` 同样保存成功；填 `2001:db8::1::2` 也通过。
  3. 单测：`DnsUpstreamValidator.validateAddress(DnsModeProtocol.DNS, "1.1.1.1:53")` 实际返回 `null`，期望 `"地址格式不正确"`；`":::"` 同理。
  4. 运行时探针（本机 Go 1.27）：`net.SplitHostPort("[1.1.1.1:53]:53")` 返回 `host="1.1.1.1:53", port="53", err=nil`；随后 `net.DialTimeout("udp", "[1.1.1.1:53]:53", ...)` 返回 `dial udp: lookup 1.1.1.1:53: no such host`，`[:::]:53`、`[1:2]:53`、`[2001:db8::1::2]:53` 同样失败，而合法 `[2001:db8::1]:53` 可拨通。
- **备注**：应拒绝 DNS/DOT 地址中的端口写法（端口有独立字段），并用 `InetAddress`/`parseNumericAddressSafe` 校验 IPv6；DoH 分支可另外校验 URL 端口与路径。

---

## A-005 极速模式启动时规则缓存异步加载，TUN 已开始处理查询

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressTunnelManager.kt:277-284`
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressTunnelManager.kt:343-345`、`:370-427`
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressVpnService.kt:98-104`、`:116-126`
  - `Android/app/src/main/java/com/haoze/diting/express/engine/ExpressDnsEngine.kt:94-117`
  - `Android/app/src/main/java/com/haoze/diting/core/rule/BlockRuleCache.kt:19-20`
  - `Android/app/src/main/java/com/haoze/diting/core/rule/DomainPolicyEngine.kt:52-71`
- **问题**
  - 极速模式启动时，`ExpressTunnelManager.start()` 先在 `scope.launch(Dispatchers.IO)` 中异步预热 block/allow 规则缓存，随后立即把 `isRunning` 置为 `true`、启动 TCP worker、重传任务和 `ExpressTunReader` 线程。
  - 规则缓存初始状态是空对象（`BlockRuleCache` 的 `state = BlockRuleCacheState()`），`refreshCache()` 完成前，`DomainPolicy.evaluate()` 找不到任何拦截/放行规则，统一走“默认放行”。
  - `start()` 没有等待预热任务完成，`ExpressVpnService` 也没有类似 `awaitRulesLoaded()` 的汇合点；因此从 VPN 建立到缓存加载完成之间的 A/AAAA 查询会绕过规则。
  - 加载 block 与 allow 是两个独立协程（`j1`、`j2`），只保证两者都结束后才 `invalidateCache()`；若 block 先完成而 allow 尚未完成，带白名单例外的域名会在这个窗口内被误拦截。
- **触发路径**
  - 首次安装、导入大订阅或重启服务后连接极速模式；规则越多，Room 查询和索引构建耗时越长，窗口越明显。默认放行的查询还会写入 Express 的 DNS 缓存，但规则判断在缓存查询之前执行，缓存加载完成后拦截会恢复，因此主要表现为“刚连接时规则不生效”。
- **影响**
  - 用户连接极速模式后最初一段时间内，广告/跟踪域名仍可正常解析；若同时存在全局拦截和全局放行规则，放行例外也可能短暂失效。
  - UI 在 `ExpressVpnService` 返回 `started=true` 后立即显示已连接，用户会认为规则已经生效，实际存在一个不可见的规则空窗期。
- **复现/验证**
  1. 在极速模式添加全局拦截 `||example.com^`，强制停止应用后重新连接；连接后立即连续查询 `probe-<时间戳>.example.com`。缓存加载完成前返回真实解析结果，加载完成后同一域名返回拦截响应。
  2. 同时添加 `||example.com^` 与 `@@||example.com^`，重复上述步骤；若 block 缓存先加载完成，窗口内会出现“已有放行规则但仍被拦截”。
  3. 断点/日志验证：在 `ExpressTunnelManager.kt:343` 与 `BlockRuleCache.reload()` 返回处打点，前者先于后者执行；给 `refreshCache()` 注入延迟即可稳定复现。
  4. 单测方向：用可控延迟的 fake DAO 调用 `ExpressTunnelManager.start()`，在 `refreshCache` 未完成时发送查询，断言 `DomainPolicy` 应拦截但实际放行。
- **备注**：应在启动 TUN 读取线程前 `join` 两个缓存加载任务，或用 `CompletableDeferred`/`isRulesReady` 门控 `engine.resolve()`；`ExpressVpnService` 也应等待默认规则种子任务和缓存就绪后再对外报告连接成功。

---

## A-006 清理 DNS 缓存后，待落盘队列会在约 30 秒后把条目写回

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/cache/DnsCacheController.kt:28-33`
  - `Android/app/src/main/java/com/haoze/diting/core/cache/DnsResponseCache.kt:118-122`、`:255-260`、`:285-298`、`:300-327`
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:83-95`
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnDatabaseComponents.kt:132-133`
  - `Android/app/src/main/java/com/haoze/diting/normal/ui/DataCleanupScreen.kt:111`
  - `Android/app/src/main/java/com/haoze/diting/data/dao/DnsCacheDao.kt:82-103`、`:111-112`
- **问题**
  - 正常模式的 DNS 缓存写入是延迟批处理：`put()` 成功解析后把 `DnsCacheEntity` 放入 `pendingWrites`，不足 200 条时只启动一个 30 秒后的 `pendingWriteFlushJob`，到点再调用 `dao.applyPendingWrites()`。
  - `DnsCacheController.clearAll()` 只做了三件事：`cache.clearMemory()`、调用 Go 引擎清缓存回调、`dao.clearAll()`；它没有调用 `DnsResponseCache.clear()`（该方法会同时清 `pendingWrites`、取消定时任务），也没有取消 `pendingWriteFlushJob`。
  - 因此清理时仍在 `pendingWrites` 中的条目会在定时器到期后重新落盘。`applyPendingWrites()` 对已不存在的 key 执行 `insertIfAbsent(e)`，把旧的响应字节、域名、TTL 一并插回 `dns_cache` 表。
  - 应用下次启动的 `warmUp()` 会从表中重新加载这些条目到内存，所以“清理 DNS 缓存”在跨进程重启后也不成立。
- **触发路径**
  - 正常模式 + 开启 DNS 缓存 + 最近 30 秒内解析过域名（尤其是几个新域名）→ 设置 → 数据清理 → 删除 DNS 缓存。清理后 30 秒内不做任何查询，等待定时器触发即可看到条目回来。
- **影响**
  - 用户为隐私清理访问记录时会得到“已删除”提示，但访问过的域名与被解析 IP 在约 30 秒后重新写入本地数据库，并在下次启动时重新进入缓存。
  - 缓存条目复活后仍会按旧 TTL 命中，用户以为清理后应重新查询的域名继续返回旧结果。
  - “清理全部本地数据”也会调用同一路径，同样存在残余缓存回流。
- **复现/验证**
  1. 打开正常模式，确认 DNS 缓存策略为开启；通过 VPN 访问若干新域名（确保产生待落盘写入）。
  2. 30 秒内进入“数据清理 → 删除 DNS 缓存”，确认提示成功；立即打开 DNS 缓存列表，条目为空。
  3. 保持应用在前台或后台等待超过 30 秒且不再产生新查询，重新打开 DNS 缓存列表；先前域名重新出现。
  4. 如需直接取证：debug 包用 `adb shell run-as com.haoze.diting` 复制 `databases` 下的缓存库，清理前后查询 `dns_cache` 行数；清理后行数应保持 0，实际会在定时器后恢复为非 0。
  5. 单测方向：用 `TestScope` 和 fake DAO 调用 `resolve()` 产生 pending 写入，再调用 `DnsCacheController.clearAll()`，推进 30 秒，断言 `applyPendingWrites` 不应被调用或 `insertIfAbsent` 不应恢复已清空的 key。
- **备注**：`DnsResponseCache` 已提供 `clear()`，但控制器未使用；应让 `clearAll()` 调用 `cache.clear()`（内部会清内存、取消并清空待写队列、清 DAO），再执行 Go 引擎清缓存回调，避免两处清理顺序竞争。

---

## A-007 快捷设置磁贴刷新使用了错误组件名，运行状态变化无法推送

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/tile/QuickSettingsTileUpdater.kt:15-25`
  - `Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:158-181`、`:189-191`
  - `Android/app/src/main/AndroidManifest.xml:82-85`
  - 调用方：`Android/app/src/main/java/com/haoze/diting/normal/DnsVpnStatusNotifier.kt:19-25`、`Android/app/src/main/java/com/haoze/diting/express/ExpressVpnController.kt:170`、`Android/app/src/main/java/com/haoze/diting/server/backend/DnsModeService.kt:95`、`:126`
- **问题**
  - `QuickSettingsTileUpdater.requestTileUpdate()` 用 `ComponentName(appContext.packageName, "${appContext.packageName}.tile.DitingTileService")` 构造组件。
  - `ComponentName` 的第二个参数要求完整类名。应用包名为 `com.haoze.diting`，因此实际得到的是 `com.haoze.diting.com.haoze.diting.tile.DitingTileService`，而清单中 `android:name=".tile.DitingTileService"` 对应的真实类名是 `com.haoze.diting.tile.DitingTileService`。
  - `TileService.requestListeningState()` 按精确组件匹配；组件名错误时要么抛出异常、要么找不到目标磁贴，两种情况都不会让真实的 `DitingTileService` 收到 `onStartListening()` 回调。调用处的 `runCatching` 又会吞掉异常，只留下一条 warning 日志。
- **触发路径**
  - 正常/极速/DNS 模式在服务启停或状态变化时都会调用该刷新方法：正常模式经 `DnsVpnStatusNotifier.sendStatusBroadcast()`，极速模式经 `ExpressVpnController`，DNS 模式经 `DnsModeService.onStartCommand()`。
  - 这些路径全部命中错误组件名；快捷设置面板已展开时，磁贴图标与副标题不会随服务状态更新，只有收起再展开（触发系统重新调用 `onStartListening()`）才恢复。
- **影响**
  - DNS 模式从磁贴启动后，`DnsModeManager.startService()` 先把状态置为 `STARTING`，`DitingTileService.toggleDnsService()` 随即按 `isRunning` 读取到“未运行”而保持 `STATE_INACTIVE`；服务启动完成后的刷新请求又因组件名错误失效，用户会看到“服务已启动但磁贴仍显示关闭”，直到重新展开面板。
  - 正常/极速模式在面板展开期间被通知栏、其他入口或系统事件停止时，磁贴也可能继续显示为已开启。
  - 该缺陷同时使 `DitingTileService.requestTileUpdate()` 这个公开入口完全无效。
- **复现/验证**
  1. 把磁贴添加到快捷设置，切到 DNS 模式，展开面板后点击磁贴启动服务；观察磁贴仍为关闭态，收起面板再展开后变为开启态。
  2. 展开面板，用通知栏中的停止按钮关闭正常模式 VPN（或让服务因权限/系统原因停止），观察磁贴在面板展开期间仍显示开启。
  3. 静态断言：`ComponentName("com.haoze.diting", "com.haoze.diting.tile.DitingTileService").flattenToString()` 应为 `com.haoze.diting/com.haoze.diting.tile.DitingTileService`；当前代码传入的类名多出一段包名。
  4. 在 `requestTileUpdate()` 的 `onFailure` 中临时打印 `Log.e(TAG, "tile component", e)`，或直接过滤 logcat 中的 `QuickSettingsTileUpdater`，可看到每次服务状态变化都记录一次失败。
- **备注**：应改为 `ComponentName(appContext, DitingTileService::class.java)`，或至少使用 `"${appContext.packageName}.tile.DitingTileService"` 作为完整类名而不是再拼一次包名；单元测试可直接断言 `ComponentName` 的 `className` 等于清单中的类名。

---

## 观察（未达到确认缺陷标准，供后续验证）

### O-001 含 `#` 的 Adblock 正则/修饰符规则会被提前截断

- `AdblockRuleLineParser.kt:14` 在识别 regex 之前执行 `line.substringBefore('#').trim()`。
- 例如 `/^https?:\/\/example\.com\/#/` 被截成 `/^https?:\/\/example\.com\/`，后续 `lastIndexOf('/')` 取出的正则体丢失结尾反斜杠，最终按 `invalidCount = 1` 丢弃。
- 实际影响可能有限：URL fragment 不会发往服务器，真实规则中的 `#` 多出现在 `$replace` 等当前本就不支持的修饰符里，因此暂不作为确认缺陷。

### O-002 dnsmasq `server=` 的语义与 dnsmasq 规范不一致

- `AdGuardRuleParser.kt:186` 把 `server=/...` 与 `address=/...` 一起交给 `HostsAndDnsmasqParser.parseDnsmasqLine`。
- 该解析器对两者统一处理：目标为空/`#` 视为 sinkhole 阻断，目标为 IP 视为 rewrite（`HostsAndDnsmasqParser.kt:7-30`）。
- dnsmasq 中 `server=/domain/1.2.3.4` 表示该域名改走指定上游，`server=/domain/#` 表示恢复默认上游，都不是改写或阻断；导入此类配置会得到相反的结果。
- 不确定是否为“Go 引擎只支持单一上游”下的有意简化，需产品确认，暂列观察。

### O-003 hosts 中单标签/下划线主机名被静默判为无效

- `AdGuardDomainUtils.normalizeDomain` 要求名称包含 `.`，且 label 只允许 `[a-z0-9-]`（`AdGuardDomainUtils.kt:70-84`）。
- 标准 hosts 中的 `localhost`、局域网 `nas`、`_dmarc.example.com` 等在导入时都会被计入 invalid；对广告过滤影响有限，且可能是有意收紧，暂列观察。
