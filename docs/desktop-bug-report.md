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
