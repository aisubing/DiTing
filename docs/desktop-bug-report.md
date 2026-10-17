# 安卓端 Bug 记录

> 文件名沿用项目既定约定（`docs/desktop-bug-report.md`），内容为安卓客户端扫描结果，不包含桌面端问题。
>
> - 扫描基线：`main` @ `3a048c5`（含修复提交 `18319ed`）
> - 扫描范围：`Android/app/src/main/java/com/haoze/diting/` 与 `Android/tunnel/`
> - 记录原则：只记录问题，不修改代码；每条给出代码位置、触发路径和验证方式。存疑但未达到确认标准的事项统一放在文末“观察”。
> - 前一轮（基线 `6da118e`）的 A-001…A-010 已由 `18319ed` 修复并从本文档删除，本轮确认缺陷自 A-012 起编号（A-011 曾提交后于复核中撤回，编号不复用，避免与历史编号重复）。
> - 验证状态：本轮 Room 校验语义依据本机 Gradle 缓存中的 `room-runtime 2.7.0` 字节码（`TableInfoKt.equalsCommon`/`defaultValueEqualsCommon`/`RoomOpenHelper.onUpgrade`）与 KSP 生成代码（`app/build/generated/ksp/debug/.../AppDatabase_Impl.kt`）逐项核对。
> - 撤回复核：曾拟记录的「`isException` 迁移 DEFAULT 0 与实体 schema 漂移导致升级崩溃」（暂编 A-011，见提交 99c559d）经回读 `equalsCommon` 完整控制流后确认为**误报**：ENTITY(1)↔DATABASE(2) 方向的默认值比较仅在**实体侧默认值非空**时执行（偏移 106 `aload_2; ifnull 125` 判空跳过，`astore_2` 存的是接收者即期望/实体侧列），本例实体未声明 `@ColumnInfo(defaultValue)`，Room 容忍该漂移，迁移校验通过。关键旁证：同型的 `enabled DEFAULT 1` 漂移自 schema v2 起随每次发布共存而未有任何崩溃报告。该漂移作为规范卫生问题降级至 O-101。

## 汇总

| 编号 | 严重度 | 模块 | 问题 | 状态 |
| --- | --- | --- | --- | --- |
| A-012 | 中 | VPN IPv6 探测 | AUTO 模式的网关/路由检查是死代码：只要接口有 GUA 地址就启用 IPv6，与函数文档「地址 AND 路由」相反（normal 与 Express 两份拷贝同犯） | 待处理 |
| A-013 | 中 | 数据清理 | 「清理下载与临时缓存」删除 `filesDir/updates`，但更新安装包实际写入 `filesDir/app-update`，清理承诺落空且残留 APK 永久泄漏 | 待处理 |
| A-014 | 中高 | 流量统计保留 | `app_traffic_daily` 只被「DNS 日志保留天数」（默认 7）清理，专属的「流量保留 30 天」设置无任何清理消费者；降低日志保留会静默销毁数周流量历史 | 待处理 |
| A-015 | 中 | 流量实时速度 | Go 隧道模式（唯一生产路径）下每应用实时网速恒为 0：「按实时网速」排序与逐项 ↑/↓ 速度永不生效，而页面文案承诺展示 | 待处理 |
| A-016 | 中 | 数据清理 | 「清除自定义背景缓存」删除 `appearance_settings` 偏好文件中的键，但背景设置实际存于 `dns_vpn_prefs`，清理后背景设置原样保留并继续生效 | 待处理 |
| A-017 | 中 | Go 引擎生命周期 | `dnsCache` 清理协程无停止路径，且 CA 管理器每次调用新建一个 `Engine` 且从不 `Stop()`：每次证书校验/导出泄漏一个后台 ticker 协程与全套缓存内存 | 待处理 |
| A-018 | 中高 | Go 引擎并发 | `SetBlockResponseType`/`SetDomainChecker` 等 setter 不加锁写 `Engine` 字段，服务中的查询协程同样不加锁读；`e.mu` 不构成 happens-before → 数据竞争（可撕裂接口值/读到旧响应类型） | 待处理 |
| A-019 | 中 | Go DNS | UDP 上游响应从不检查 TC（截断）位、无 TCP 重试，截断响应被原样转发且写入缓存，客户端 TCP 重试命中同一份截断缓存，高记录数域名在 TTL 内持续返回残缺答案 | 待处理 |
| A-020 | 高 | DNS 模式总开关 | 「启用域名过滤」在 DNS 模式完全失效：standalone 服务路径从不读取 `filterDNS`，且 `DnsQueryFilter` 的策略提供器硬编码恒真，关闭开关后 LAN 查询仍被拦截 | 待处理 |
| A-021 | 高 | DNS 模式生命周期 | ACTION_STOP 与启动协程竞态：`engine.start()` 阻塞段无取消点，销毁后仍回填 `dnsServerEngine` 并置 RUNNING → 孤儿引擎继续占端口应答，UI 显示停止，再启动报「端口可能被占用」直至杀进程 | 待处理 |
| A-022 | 中高 | DNS 模式端口 | `loadConfig` 每次读取都把 5353/5354 强制改写为 1053（非一次性迁移），验证器与 UI 却允许保存 5353；重启或切换开关后端静默漂移并持久化 1053 | 待处理 |
| A-023 | 中 | DNS 模式动态拦截 | DNS 模式 `applyDnsConfig` 的 JSON 从未包含 `dynamicResponse` 键，Go 侧零值即禁用：动态拦截策略在该模式是死功能，UI 副标题却宣称生效 | 待处理 |
| A-024 | 中 | DNS 模式启动窗口 | STARTING 窗口内的配置/上游修改被丢弃：引擎用启动瞬间的快照绑定，`refreshEngineIfRunning` 只认 RUNNING，完成后不再回读 | 待处理 |
| A-025 | 高 | 配置导入 | 未勾选「禁止联网名单」导出的备份再导入，会把本地已开启的禁止联网总开关静默关闭（`optBoolean` 缺省 false + 不等即写） | 待处理 |
| A-026 | 中高 | 配置导出 | 出站代理用户名/密码在加密存储的前提下被解密后明文写入导出 JSON，凭据随备份文件外泄 | 待处理 |
| A-027 | 中 | 配置往返 | `latencyTestProviderRefs` 被导出、被解析进 DTO，但任何导入器都不应用它：测速节点选择迁移后静默丢失 | 待处理 |
| A-028 | 中 | 批量添加 | 批量导入丢弃 `appInverted`（分类模型无字段、校验/提交硬编码 false），`~app=` 排除规则的 enforcement 方向被反转 | 待处理 |
| A-029 | 中 | 批量添加 | 批量 URL 规则绕过 `GoUrlRuleManager.parse` 归一化直接存原文：含查询串/大小写主机的批量规则永不匹配或产生重复行 | 待处理 |
| A-030 | 中 | 规则导入 | `CategorizedRuleStreamImporter` 的 `kind` 参数从未参与过滤，`typeSkipped` 无任何写入点：类型不符文件被六表全量摄入，「没有${kind}规则，请确认导入类型」分支永不可达 | 待处理 |
| A-031 | 中 | 规则缓存 | `AllowRuleCache.reloadCustomRules` 仅按 pattern 去重订阅 special 规则（模型缺 `source`），与自定义同 pattern 的订阅修饰规则在每次白名单编辑后被逐出活动缓存，至下次全量 reload 才恢复 | 待处理 |
| A-032 | 高 | AI 密钥存储 | API 24/25（Express 模式唯一可达设备）上 `KeyObfuscator` 调 `java.util.Base64`（API 26+，未开 desugaring）→ 保存/查看 AI 密钥必崩 `NoClassDefFoundError` | 待处理 |
| A-033 | 中高 | QS 磁贴 | 磁贴启停 VPN/DNS 服务不走 `unlockAndRun`，安全锁屏下可直接启停服务与局域网 DNS 服务器（仅打开主界面路径做了锁检查） | 待处理 |
| A-034 | 中 | 通知渠道 | 「规则导入与更新」存在两个同名 channel：注册表 `diting_rule_operations_channel` 只被死代码 `RuleUpdateNotifier` 引用，实际通知走 Worker 硬编码的 `rule_operations`；系统设置出现两条同名通道，静音可能落错通道 | 待处理 |
| A-035 | 中 | 配置导入 | 通知栏自定义文案要求运行/停止两条**都**非空才写入：只填一条（UI 明示合法）导出后导入，已填的一条也静默丢失；且「清空文案」永远无法经导入传播 | 待处理 |
| A-036 | 低 | 通知设置入口 | `openNotificationSettings` 用 API 26+ 的 `ACTION_APP_NOTIFICATION_SETTINGS` 且 `runCatching` 吞异常：Android 7.x（Express 模式 minSdk 24 可达）点「系统通知权限」毫无反应 | 待处理 |
| A-037 | 低 | 应用内语言 | 磁贴标签/常驻监控通知/规则渠道名用未包装 context 的 `getString`（跟随系统语言），同屏其它文案走 `localizedText`（应用内语言）：中英混杂 | 待处理 |
| A-038 | 高 | 订阅暂存隔离 | `staging_sub_*` 不匹配 `NOT LIKE 'sub_%'`：更新窗口内暂存规则被全链路当作「手动规则」显示/计数，「清空手动」误删在途暂存 → 订阅静默缺规则且计数虚报 | 待处理 |
| A-039 | 高 | 订阅崩溃恢复 | `recoverInterruptedImports` 只清 block/allow/rewrite 三表（漏 goUrl/cosmetic），`deleteSubscription` 从不清 staging → 半导入订阅的 URL/元素隐藏规则永久生效且成孤儿 | 待处理 |
| A-040 | 高 | Express 生命周期 | Express start↔stop 竞态：`stop()` 关 pfd 但不取消 start 协程，`FileInputStream` 重开已关 fd、`isRunning` 复活 true、读线程一次 EBADF 即死，`start()` 仍返回 true → UI 显示运行、DNS 全黑洞 | 待处理 |
| A-041 | 高 | 网络诊断 | `TunnelDiagnosticsResolver.tunnelResolver` 自 `58ca123` 重构后从无赋值点：经隧道 DNS 查询/Ping/Traceroute 恒报「VPN 未运行」（`DnsVpnService.resolveThroughTunnel` 成孤儿函数） | 待处理 |
| A-042 | 中高 | DNS 测速 | `DnsLatencyTester.testDoh` 的 `provider.url.toHttpUrl()` 在 try 外，DoH 校验仅前缀匹配：畸形但过校验的 URL 测速 → 未捕获 `IllegalArgumentException` → 进程崩溃 | 待处理 |
| A-043 | 中高 | DNS 查询工具 | `isIpLiteral` 以「含冒号即 IP 字面量」放行 `8.8.8.8:53` 类输入，`InetAddress.getByName` 无保护调用 → `UnknownHostException` 未捕获崩溃；`1.2.3.4:80` 还会被当字面量误报解析成功 | 待处理 |
| A-044 | 中 | DNS 缓存 | `DnsResponseCache.clear()` 与 `flushPendingWrites` 锁外写库交错：drain 后、apply 前执行 clearAll → 最多 200 行「已清空」缓存复活 | 待处理 |
| A-045 | 中 | DNS 测速 | 测速计时窗口包含 bootstrap/系统域名解析（DoT/DoH/Plain 三路径同犯）：未预热主机名的上游被冤枉慢数百 ms~秒，竞速排序据此误导选优 | 待处理 |
| A-046 | 中 | 日志写入 | `RaceLogger/HttpRequestLogger` 批量插入无 `runCatching`（对照 DnsLogger 有）：SQLITE_FULL 等 → 服务作用域未捕获崩溃，且停机 flush 链中断丢弃后续日志与流量统计 | 待处理 |
| A-047 | 中高 | 应用更新 | 下载进度仅按 256KB 字节节流、无时间下限：快网每 5–50ms 一次 runOnUiThread+notify IPC，通知风暴/掉帧 | 待处理 |
| A-048 | 中高 | Express 悬浮窗 | Express 的前后台状态写入被 `isRunning` 门控（NORMAL 侧无条件写）：服务停止期间所有前后台切换丢失 → 偏好陈旧 → 悬浮球该出不出/该隐藏却盖在自身 UI 上 | 待处理 |
| A-049 | 中 | 日志仪表盘 | 仪表盘把防火墙拦截的连接行标「旁路」：`resultLabel = if (isConn) "旁路"` 忽略 `result==BLOCKED`，红色拦截状态配「旁路」文字；同屏另两处渲染器均正确分流 | 待处理 |
| A-050 | 中 | 悬浮窗兼容 | `TYPE_APPLICATION_OVERLAY`（API 26+）无 SDK 分支硬编码，minSdk 24：Android 7.x（只能跑 Express）addView 必抛 → 悬浮日志永久不可用+反复失败 toast | 待处理 |
| A-051 | 中 | 规则列表 | 黑/白/重写列表 `loadPage` 无任务取消：仅搜索防抖，筛选切换/翻页/ON_RESUME 并发加载可旧覆新，列表与计数显示上一筛选数据 | 待处理 |
| A-052 | 中 | 黑名单筛选 | 黑名单「规则订阅」页签漏掉订阅携带的 URL 拦截规则（仅域名+元素隐藏），计数同缺；白名单同位置显式注释承认此不对称 | 待处理 |
| A-053 | 中高 | 崩溃备份 | 连崩阈值用 `>=` 且自动导出成功后不置抑制标志：第 3 次起每崩一次向系统 Download 刷一份全量备份文件并重复弹提示 | 待处理 |
| A-054 | 中 | 崩溃计数 | `collectMinimalReport` 无保护在先、`onCrashOccurred` 在后：StackOverflowError/OOM 深栈使计数步骤永不执行——恰是最需自动备份的崩溃循环计数恒 0 | 待处理 |
| A-055 | 中 | 原生崩溃收集 | 批量收集的水位线在整循环结束后才 apply：中途进程死亡 → 下轮整批重采、报告重复且计数虚增 | 待处理 |
| A-056 | 低 | 统计边界 | `dayStartMillis` 用当前 UTC 偏移折算固定 86400s 网格：DST 切换日「今日」窗口偏 1 小时，且与同文件 `dayStringAt` 真历法矛盾 | 待处理 |
| A-057 | 低 | 流量页时钟 | 「已连接 HH:MM:SS」仅组合期取值，空闲时上游 StateFlow 不发射→无重组：时长冻结在最后流量时刻 | 待处理 |
| A-058 | 低 | 崩溃导出 | 手动导出成功标记由可取消的 `rememberCoroutineScope` 在 IO 完成后执行：写完即切页 → 已导出但阈值仍武装 | 待处理 |
| A-059 | 低 | 密钥混淆 | `KeyObfuscator` 把 UTF-16 code unit 截成单字节：非 ASCII 密钥 seal/open 往返静默损坏/返回空串（与 A-032 不同机制） | 待处理 |
| A-060 | 低 | 更新清理 | 下载失败 catch 无条件清全局单槽位记录：新版本失败抹掉已下载旧版本记录 → 旧 APK 成孤儿并强制全量重下 | 待处理 |
| A-061 | 低 | 本地化 | 「当前筛选下暂无 DNS 请求日志」（Express 空态文案）无字典条目，落入前缀替换模板 → 英文界面输出半中半英拼接串 | 待处理 |
| A-062 | 高 | Go MITM 分帧 | 元素隐藏注入后响应删光 Content-Length/TE 且 `Uncompressed=true`：stdlib 不再补 `Connection: close`，HTTP/1.1 keep-alive 下 body 无任何定界 → 浏览器文档永不结束/挂死，代理双向互等 | 待处理 |
| A-063 | 中 | Go 元素隐藏 | `buildCosmeticCss` 从不把 `rules.GlobalException` 并入 exceptions（只填按域 entry.Exception）：全局 `#@#` 例外静默失效，误隐藏无法豁免 | 待处理 |
| A-064 | 低中 | Go MITM 注入器 | `InjectingReader` EOF/提前返回路径丢弃 `carry` 中残留的 ≤5 字节 `<head` 前缀：无 `<head>` 且恰以该前缀结尾的文档输出被截断 | 待处理 |
| A-065 | 中 | Express 缓存统计 | Express `dns_cache` 每次 put 用 `OnConflictStrategy.REPLACE` 整行覆盖：hitCount/lastHitAt 在重缓存时归零，仪表盘 totalHitCount 系统性偏低（NORMAL 侧注释明确防此问题） | 待处理 |
| A-066 | 低 | 数据清理计数 | 「清理全部域名规则」删 HOSTS 订阅的 v4/v6 覆写但保留订阅行且不复位 ruleCount：徽标数与实际规则持续不符；为此准备的 `resetAfterRuleCleanup` 全仓零调用 | 待处理 |
| A-067 | 高 | Go DNS v6 应答 | `buildIPv6UDPPacket` 在校验和**之后**才写入 payload：所有合成 IPv6 UDP 应答（拦截/NXDOMAIN/重写/转发）校验和恒错，内核强校验下整包丢弃 | 待处理 |
| A-068 | 高 | Go 规则热更新 | `SetTries` 锁内 `Close()` 旧 trie（munmap），读者锁外解引用同一 `*MmapTrie`：规则重载与 DNS 流量并发 → use-after-unmap SIGSEGV（不可 recover） | 待处理 |
| A-069 | 中 | Go DNS 缓存 | `dnsCache.clear()` 用 `lruList.Init()` 而不 `Remove`：并发命中提升把 `elem.list` 仍指向本表的孤儿元素重新链回 → LRU 与 map 失同步 | 待处理 |
| A-070 | 中 | Go 规则装载 | trie 与 bloom 各自「成功才 append」按下标配对：任一 bloom 加载失败即整体错位一格，预过滤假阴性令整个 trie 被跳过 → 静默漏拦 | 待处理 |
| A-071 | 中 | Go MITM 证书缓存 | `CertManager.certCache` 为无上限 `sync.Map`、仅过期命中时删除，与文件头注释「LRU 512 entries」不符：长会话拦截多子域内存单调增长 | 待处理 |
| A-072 | 低中 | Go MITM 流关闭 | gzip/deflate 注入路径替换 `resp.Body` 后原始 body 永不 Close/排空：同连接 keep-alive 下一轮 `ReadResponse` 因 chunk 终结符未消费而错位 | 待处理 |
| A-073 | 低中 | Go 连接日志 | 包级全局 `connLogSeen sync.Map` 仅在 `StartFull` 清空：standalone/inspection 模式无回收点，去重键单调增长（内存缓涨+跨引擎实例压制新会话日志） | 待处理 |
| A-074 | 低 | Go bloom 加载 | `LoadBloomFilter` 不校验 `bitCount/hashCount > 0`：`bitCount=0` 的畸形文件通过尺寸校验，首个 `MightContain` 触发 `%0` integer divide by zero panic | 待处理 |
| A-075 | 中 | Express 规则添加 | Express 黑名单可添加元素隐藏规则（仅 DNS_MODE 被拦）：写入 `diting_express` 却提示成功；`CosmeticRuleManager` 硬编码只从 NORMAL 库编译 CSS，且 Express 列表又不显示 cosmetic 行 → 不可见、不生效、无法删除的幽灵规则 | 待处理 |
| A-076 | 高 | VPN 路由覆盖 | 默认开启的「绕过局域网」IPv4 补集枚举漏掉 116–119/8 与 122–123/8（电信/联通/阿里云/腾讯云在用公网段）：这些直连 IP 流量完全绕过 TUN，域名规则/MITM/QUIC·DoT 阻断/禁止联网/流量统计对其全部失效 | 待处理 |
| A-077 | 中 | HTTPS 检查证书 | 本会话是否 MITM 由**缓存位** `isHttpsInspectionReady` 决定，异步真校验失败后只写偏好、不重启隧道：根证书已被卸载仍继续 MITM → 目标 App TLS 握手失败/证书告警，与设置页显示矛盾至下次重连 | 待处理 |
| A-078 | 中 | 会话统计归零 | 编辑排除/禁止联网/检查名单或数据清理触发 `restartVpnLocked` → `TrafficStatsManager.start()` 无条件清 sessionTx/Rx/时长：本地列表编辑使「本会话↑↓」与「已连接」静默归零并瞬断（对照 allowlist 走热更新不重启，口径不一致） | 待处理 |
| A-079 | 高 | 缓存设置串档 | 极速模式「缓存设置」屏四处调用 `DnsCacheSettingsStore` 全部漏传 dataset（默认 NORMAL）：读写的其实是普通模式策略——极速缓存开关永不生效、改动却偷改普通模式防护（引擎端只认 diting_express_prefs） | 待处理 |
| A-080 | 高 | AI 分析串库 | `AgentAnalysisSheet` 硬编码 `AppDatabase`+NORMAL 广播：极速模式 DNS 缓存页的 AI 流量分析读普通模式旧日志，「加白/黑名单并热更生效」提示为假（写进 NORMAL 库且 `isNormalRunning=false` 直接早退，极速引擎收不到同步） | 待处理 |
| A-081 | 中 | 动态拦截极速侧 | 极速模式「动态拦截策略」可开可存，`express/` 全包无任何读取端（引擎只用静态 `blockResponseModeProvider`）：开关纯空转、副标题谎报生效（与 A-023 同文案不同库，本条为 EXPRESS 面） | 待处理 |
| A-082 | 中 | 保留天数热更新 | 普通模式改「日志保留天数」不触发 `onRuntimeDnsSettingsChanged`：运行中引擎继续按旧 volatile 快照 prune（缩短不省空间、加长照样删数据）直到下次其它刷新；同屏日志模式项却正确触发（对照即证据） | 待处理 |
| A-083 | 中 | SAF 授权泄漏 | 全仓 5 处 `takePersistableUriPermission`、0 处 `releasePersistableUriPermission`：删除背景图/订阅本地文件/全面清理后，对应用户文件的持久读授权永不撤销（系统可见「可访问的文件」只增不减） | 待处理 |
| A-084 | 中 | 服务器模式向导 | DNS 模式「使用向导」接入信息把监听端口**硬编码为 1053**（5 处），从不读 `config.localListenPort`：用户改端口（验证器允许 1024–65535、设置页实时显示真实端口）后，向导仍指示「将 DNS 改为 IP:1053」，照做即把所有局域网设备指向无监听端口 → 全员解析超时 | 待处理 |
| A-085 | 中高 | Go 全隧道半关闭 | `countingConn` 内嵌 `net.Conn` **接口**致 `CloseWrite` 方法不被提升，`bidiCopyFlow` 的类型断言恒 false：应用侧（被包装的一边）永远收不到 FIN，EOF 定界协议（无 Content-Length 应答/SSE/FTP/邮件）双向僵死直到 App 超时，文件头「支持 half-close」承诺对已归因 UID 流量失效 | 待处理 |
| A-086 | 中 | Go 全隧道出站 | `bufferedTun.drain` 首次 TUN 写错误即 `return` 永久退出且永不重启，而 `Write` 恒 `return len(p), nil` 向 gVisor 谎报成功：出站包进 2048 队列→满→静默丢弃，网络 handover 一次瞬断后整个隧道输出黑洞化，只能重启 VPN 会话恢复 | 待处理 |
| A-087 | 中 | DoT 阻断开关 | `SetBlockEncryptedDns` 是死开关：`blockEncryptedDNS` 全仓只有 Store 无 Load，`engine_full_tunnel.go` UDP/TCP:853 处理**无条件**丢弃并记 `blocked_encrypted_dns`；Kotlin 默认 false 而 UI 提供「阻断加密 DNS (DoT)」开关——关闭后 Private DNS(strict) 应用照样全部解析失败，开关与日志归因双双失真 | 待处理 |
| A-088 | 中高 | 极速 bootstrap | `BootstrapSelector` 两处 Store 调用漏传 dataset（`BootstrapSelector.kt:25-26`，签名默认 NORMAL）：极速模式运行时永远读 `dns_vpn_prefs` 的 bootstrap 配置，而极速设置页写 `diting_express_prefs`——极速里开关/自定义 IP 全部失效，且普通模式关 bootstrap 会让极速 DoT/DoH 退化（与 A-079 同族、不同文件） | 待处理 |
| A-089 | 中 | 应用放行闸门 | `rememberAppAllowlistResponse` 只在 `serveDNS` 新鲜解析尾部调用（`engine_standalone.go:384`），缓存命中/stale 分支提前 return 不续期，stale 后台刷新也绕开该函数：白名单应用的 IP 授权按 rrTTL 过期而缓存应答可远久于此 → 「DNS 解析成功但 TCP/UDP 连接恒被 app_allowlist_blocked」直至缓存彻底过期 | 待处理 |
| A-090 | 中 | Go DNS 配置原子性 | `ApplyDNSConfig` 先提交 `responseType`/`dynamicResponse`/`dynamicBlocks.reset()` 再校验 providers（`dns_config.go:133-150`）：provider 校验失败返回 error 时 Kotlin 视为整份拒绝，Go 却保留新拦截应答类型并清空动态计数——UI 与引擎行为漂移且无自愈点 | 待处理 |
| A-091 | 中 | 服务商健康页 | `ProviderHealthEngine` 全仓零实例化（grep 构造点仅命中类声明）、`recordResult` 零调用者 → `activeEngine` 恒 null：健康页 `flushActive` 恒 false、`loadAll` 恒空，「智能预测权重」显示 `?: 1.0` 兜底的均匀编造值（与 A-041 同族：重构后接线缺失，但本条表面是 UI 谎报而非功能报错） | 待处理 |
| A-092 | 中 | bootstrap 健康双源 | `BootstrapHealthEngine` 三处并存实例（VPN 服务/测速 VM/Express 隧道）各自持内存快照，`flush→saveAll` **全表 JSON 覆盖** `dns_vpn_prefs` 单键，进程级单槽 `activeEngine` 被最后构造者顶掉：测速页 15s 定时/退出 flush 会整体抹掉服务引擎期间新记的成绩与冷却（及反向），健康统计随机倒退、冷却 IP 状态丢失 | 待处理 |
| A-093 | 中 | regex 规则大小写 | Kotlin `BlockRuleMatcher`/`AllowRuleMatcher` 用 `Regex(pattern).containsMatchIn(domain)` **不注入 (?i)**（查询域名已 lowercased，但模式大小写保留），Go `policy_engine.go:112` 恒前置 `(?i)`：同一订阅 `/Ads\..*/` 在 VPN（Go 判定）命中、在服务器/回调兜底（Kotlin 判定）不命中，两模式拉黑结果相反；`$match-case` 还被 Kotlin 当 web-only 修饰 ignore（大小写敏感无法表达） | 待处理 |
| A-094 | 中 | `#$@#` 例外解析 | `COSMETIC_DELIMITERS` 缺 `#$@#`（AdGuard 例外型元素隐藏=带域名的 `#@#`）：`example.com#$@#.ad` 不识别定界符→`substringBefore('#')` 得 `example.com`→**生成为整域 block 规则**——导入含例外行的列表反而把该域整站拉黑 | 待处理 |
| A-095 | 低 | regex 注释截断 | `AdblockRuleLineParser:24` 的无差别 `substringBefore('#')` 早于 regex 提取（`:33+`）：`/banner#1/` 被截成 `/banner`，`lastSlash==0` 不落 regex 分支、域名分支 `normalizeDomain("/banner")` 判 invalid——regex 体内的 `#` 合法（模式字符），规则整条静默丢失（Go `rule_compiler.go:193` 同收 `#` 且拒 `/` 开头行，两端一致地丢） | 待处理 |
| A-096 | 低中 | 规则索引残留 | `MappedSubscriptionRuleIndex.compileAndLoad` 的 `finally` 只删本线程 temp；进程被杀后 `block.trie.<nano>.tmp` 永久堆积——`RuleIndexLayout.deleteAll` **全仓零调用者**（grep 实证），无任何清理路径；`renameTo` 失败时退化 `temp.copyTo(overwrite=true)` 非原子，读端（Go `openDTRI`/Kotlin `load`）可读到半写文件→该轮订阅索引失效 | 待处理 |
| A-097 | 低 | AI 报告渲染 | `MarkdownInlineAnnotator.kt:26` 斜体分支 `(?<!_)_(?!_)…(?<!_)_(?!_)` 未排除**词内下划线**：`dns_vpn_prefs` 中的 `_vpn_` 被匹配，两个下划线定界符被吃掉并以斜体输出 `vpn`（本机 Python re 等价复算实证 8 例中 5 例词内误中：`_vpn_`/`_haoze_`/`_LOG_` 等）；AI 分析报告正文里的配置键名/包名全部被改写变形 | 待处理 |

---

## A-012 AUTO 模式的 IPv6 路由/网关检查是死代码，仅有 GUA 地址即启用 IPv6

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnTunnelManager.kt:114-136`（`hasPhysicalIpv6Support`）
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressTunnelManager.kt:169-186`（同一逻辑的 Express 拷贝，同样短路）
  - 调用方：`normal/DnsVpnService.kt:281`（`SystemSettingsStore.getIpv6Mode`）、`normal/DnsVpnTunnelManager.kt:151-154`（`Ipv6Mode.AUTO -> hasPhysicalIpv6Support(...)`）、`express/ExpressVpnService.kt:98`、`express/ExpressTunnelManager.kt:197-202`；默认值 `SystemSettingsStore.kt:14` `DEFAULT_IPV6_MODE = Ipv6Mode.AUTO`
- **问题**
  - 函数文档（`DnsVpnTunnelManager.kt:67-69`）声明探测「有效的公网 IPv6 地址 **和** 网关路由」；实现里路由检查 `hasIpv6Route` 恒不影响返回值：
    - `:114-127` 计算 `hasGlobalIpv6`（严格 2000::/3）；
    - `:128` `if (!hasGlobalIpv6) return@any false` —— 能走到 `:130` 的候选网络必有 `hasGlobalIpv6 == true`；
    - `:130-135` 计算 `hasIpv6Route`（v6 默认路由 / `hasGateway()` / prefixLength==0）；
    - `:136` `hasIpv6Route || hasGlobalIpv6` —— 右操作数恒真，整个表达式恒真，`hasIpv6Route` 是死代码。Express 拷贝 `ExpressTunnelManager.kt:180-186` 逐行相同。
- **用户可见影响**
  - 触发条件真实存在：SLAAC RA 下发前缀但默认路由 router-lifetime=0（或被 DHCPv6 覆盖失败）、以及只配了站点内 v6 前缀、出口 v6 网关缺失的企业网络 —— 这类网络接口上会有 GUA 地址但没有可用 v6 默认路由。
  - AUTO（默认档）在这种网络上返回 true 后，`establishVpnInterface` 添加 `addAddress(VPN_ADDRESS_V6,64)`、`addDnsServer(DNS_SERVER_V6)`、`allowFamily(AF_INET6)`（`:166-170`）并下发 `2000::/3`（bypassLan=true，`:187`）或 `::/0`（`:200`）路由。系统据此偏好 AAAA/IPv6，流量进 TUN 后物理侧无 v6 网关，表现为仅开启 VPN 时 IPv6 目的地黑洞/超时（双栈站点变慢或部分打不开），关闭 VPN 或切到 IPv6=禁用即恢复。
  - 仅影响建立时刻：`hasPhysicalIpv6Support` 只在 `establishVpnInterface`（`Ipv6Mode.AUTO` 分支）调用一次，会话期间物理网络变化不会重新评估（`DnsVpnNetworkMonitor.scheduleIpv6AdaptationCheck` 只回调 `onNetworkChanged`，而该回调在 `DnsVpnService.kt:57` 构造时未赋值即为 null）。因此错误的 IPv6 启用状态在整个 VPN 会话内保持，直至重连。
- **复现/验证**
  1. JVM 单测方向：向 `hasPhysicalIpv6Support` 注入/构造含 `2000::/64` 链路地址、routes 仅有 IPv4 默认路由的 `LinkProperties`，断言应为 false；当前实现返回 true（`:136` 恒真）。
  2. 真机：路由器关闭 v6 前缀的默认路由（RA 里 router-lifetime=0 或只发前缀不发路由），手机获得 GUA；AUTO 档开启 VPN，`logcat | grep establishVpnInterface` 显示 `enableIpv6=true`；对比 v6-only 目标（如 `curl -6 https://[2606:4700:4700::1111]`）经 VPN 黑洞、直连正常。
- **备注**
  - 意图明显是让 `&&`（地址且有路由）或至少以 `hasIpv6Route` 为决定项；按函数文档修正即可。两份拷贝必须同步修复，或将探测抽成共用函数（`core/diagnostic/NetworkInfoProbe.kt:15` 已引用其语义注释）。
  - `hasIpv6Route` 中 `route.hasGateway()` 对 on-link 直写路由同样为 true 的宽松性属另一层语义问题，修正短路后建议一并复核（未单列）。

---

## A-013 「清理下载与临时缓存」删除的更新目录名与实际写入目录不一致，安装包残留无法清除

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:406-414` — `clearDownloadAndTempCache()` 第 1 步删除 `File(context.filesDir, "updates")`
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:52` — `updateDirectory = File(context.filesDir, UPDATE_DIRECTORY)`
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:167` — `const val UPDATE_DIRECTORY = "app-update"`；下载产物为 `app-update/update-<ver>.apk` 与 `.update-<ver>.apk.part`（`:75-76`）
  - UI 承诺文案：`normal/ui/DataCleanupScreen.kt:89` — 「清理下载与临时缓存 / 删除更新安装包、下载临时文件及应用临时缓存」；Express 侧 `express/ui/ExpressDataCleanupScreen.kt:150` 同文案，走同一函数（`:202`）
- **问题**
  - 清理函数删的是 `filesDir/updates`，而全仓库没有任何代码创建或写入 `updates` 目录（grep `File(context.filesDir, "updates")` 仅此一处命中）；真实 APK 目录 `filesDir/app-update` 从未被清理逻辑引用。
  - 同函数顺带调用的 `SystemSettingsStore.clearAppUpdateDownload(context)`（`:409`）会清掉记录安装包路径的偏好，即清理后 UI 连“已下载 vX”的入口都消失，但 `app-update/` 下的 APK（约 10–30 MB/版）仍留在内部存储，用户无任何途径删除。
  - `clearAllLocalData` 的 NORMAL/EXPRESS 全面清理分支（`:483`、`:450` 起）也复用该函数，同样漏删。
- **用户可见影响**
  - 用户在「数据清理」页点「清理下载与临时缓存」或执行全面清理并确认后，更新 APK 实际未被删除：磁盘占用不降；反复下载多个版本时残留累积。属于清理承诺与实现不一致的功能缺陷（非单纯低效）。
- **触发路径**
  1. 设置 → 检查更新 → 下载 vX APK（落盘 `filesDir/app-update/update-X.apk`）。
  2. 数据清理 → 清理下载与临时缓存 → 确认。
  3. 期望：`app-update/` 为空；实际：APK 仍在（`adb shell run-as com.haoze.diting ls -l files/app-update`），仅偏好记录被清。
- **复现/验证**
  1. 静态：对比 `DataCleanupManager.kt:408` 的 `"updates"` 与 `AppUpdateManager.kt:167` 的 `"app-update"`，并 grep 全仓确认 `"updates"` 无写入方。
  2. 真机/模拟器按上述 3 步取证；或 JVM 单测：Robolectric 下写入 `files/app-update/x.apk`，调用 `clearDownloadAndTempCache` 后断言文件仍存在（当前实现如此），修复后应断言被删除。
- **备注**
  - 修复方向：`clearDownloadAndTempCache` 应删除 `File(context.filesDir, AppUpdateManager.UPDATE_DIRECTORY)`（需把常量提为 public/internal），或至少两处目录都清；`UPDATE_DIRECTORY` 常量与清理路径应收敛到单一来源，避免再次漂移。

---

## A-014 应用流量历史被「DNS 日志保留天数」清理，专属「流量保留 30 天」设置无任何清理消费者

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/log/LogMaintenanceManager.kt:50-63` — `pruneExpiredLogs(database, retentionDays)` 在 `:62` 执行 `database.appTrafficDao().deleteOlderThan(cutoffDate)`，cutoff 由传入的 `retentionDays` 推导
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnDatabaseComponents.kt:119` — `LogMaintenance.start(scope, db) { activeLogRetentionDays() }`；`:125` 启动即 `pruneExpiredLogs(db, activeLogRetentionDays())`（全仓唯二驱动流量清理的调用）
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnRuntimeConfigManager.kt:70` — `activeLogRetentionDays = SystemSettingsStore.logRetentionDays(context)` → 键 `log_retention_days`（`SystemSettingsStore.kt:9,47-50`，默认 7、钳制 1..30）
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/SystemSettingsStore.kt:27,31,120-130` — `traffic_stats_retention_days`（默认 30、钳制 1..90）的 get/set
- **问题**
  - `app_traffic_daily` 表的删除路径全仓仅两处：`AppTrafficDao.deleteOlderThan`（`dao/AppTrafficDao.kt:87`）唯一被 `LogMaintenanceManager.kt:62` 调用，其 cutoff 永远来自 **日志** 保留键。`getTrafficStatsRetentionDays` 的消费者仅 `ui/transfer/ConfigExporter.kt:326`（导出配置）与 `PreferenceConfigImporter.kt:109`（导入回填），无任何清理逻辑读取；`setTrafficStatsRetentionDays` 也只有导入器一个调用点（无 UI 写入方）。
  - 结果：两个设置互不相干，流量历史的真实保留期 = `log_retention_days`（默认 7 天），而配置导出/导入却在往返一个从未生效的 30 天值。
- **用户可见影响**
  - 用户在「日志保留」里把保留调小（1–3 天，常规省空间操作）→ 每小时一次的 `MAINTENANCE_INTERVAL_MS` 周期（`LogMaintenanceManager.kt:24`）或服务启动即按 7/3/1 天 cutoff 删除 `app_traffic_daily`；「应用流量统计」的「本月/全部历史」视图（`normal/ui/AppTrafficStatsViewModel.kt:182-201` 按 30 天/全时段查询）只剩几天的数据，历史总量少报，且不可恢复。
  - 反向亦然：用户期望流量统计独立保留 30–90 天（键与默认值即此语义），实际随日志设置漂移。
- **触发路径**
  1. 正常使用 VPN 数天，`app_traffic_daily` 已有 >7 天记录。
  2. 设置 → 日志保留改为 1 天。
  3. 等待周期清理或重启 VPN 服务 → 打开「应用流量统计 → 本月」：只剩 1–2 天记录。
- **复现/验证**
  1. 静态：`grep -rn "appTrafficDao().deleteOlderThan"` 全仓仅 `LogMaintenanceManager.kt:62`；`grep -rn getTrafficStatsRetentionDays` 仅导出/导入两处。
  2. 单测方向：向 Room in-memory `AppDatabase` 插入 `day = today-10` 的 `app_traffic_daily` 行，以 `retentionDays=7` 调 `pruneExpiredLogs`，断言行被删（当前实现如此）；修复后应以流量专属保留期（`traffic_stats_retention_days`）推导其 cutoff，与日志 cutoff 分离。
- **备注**
  - 修复方向：`pruneExpiredLogs` 把 `appTrafficDao().deleteOlderThan` 的 cutoff 改为 `getTrafficStatsRetentionDays` 推导；或为流量清理单列周期任务。同时应提供该值的 UI 入口（当前无写入方）或在文档层面移除「独立 30 天」的暗示，避免导出往返幽灵配置。
  - Express 分支 `pruneExpiredLogs(dataSources, null, …)`（`ExpressTunnelManager.kt:283` 起）不含流量 DAO（Express 无 `AppTrafficDailyEntity`），本条仅影响 NORMAL 库。

---

## A-015 Go 隧道模式（唯一生产路径）下每应用实时网速恒为 0，排序与速度展示永不生效

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/traffic/TrafficStatsManager.kt:96-100` — `fun start(context, isGoTunnelActive)`；`:113-115` `if (!isGoTunnelActive) { startSamplingLoop(appContext) }`
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnService.kt:321` — 全仓唯一 `TrafficStatsManager.start` 调用点：`start(this, true)`（字面量 true；Express 侧从不调用它）
  - `TrafficStatsManager.kt:231-269` — `startSamplingLoop` 内 `:255` `speedEstimator.updateSingleAppSpeedEma(...)` 是全仓唯一写入每应用 EMA 的地方（`onAppIdle` 的 `decaySingleAppSpeed` 同在此循环）
  - `TrafficStatsManager.kt:167-206` — Go 路径 `onGoTrafficTick`：`recordAppTraffic`（`:285-297`，只加总字节/会话/DB 增量，不碰速度）与 `:200` `updateSpeedEma(totalTxDelta, totalRxDelta, …)`（只更新总量 EMA）
  - `core/traffic/TrafficSpeedEstimator.kt:15,20` — `appSpeedEma` 仅由 `updateSingleAppSpeedEma` 填充；`getAppSpeed` 读它
  - `TrafficStatsManager.kt:397-400,411-412` — `buildAppStatsList` 用 `getAppSpeed(pkg)` 生成 `currentTxSpeedBps/currentRxSpeedBps`，Go 模式下恒为 null → 0
  - 消费方：`normal/ui/AppTrafficStatsViewModel.kt:350` `REALTIME_SPEED -> sortedByDescending { it.currentTotalSpeedBps }`；`ui/traffic/AppTrafficRankItem.kt:122,152`（速度行仅 `>0` 时渲染）；`ui/traffic/TrafficAttributionDialog.kt:114` 文案承诺「本页面展示的各应用实时网速…」
- **问题**
  - 生产唯一入口 `start(this, true)` ⇒ `isGoTunnelActive` 恒 true ⇒ `startSamplingLoop` 永不运行 ⇒ `appSpeedEma` 永不被写入 ⇒ 每应用速度恒 0。Go 的 `onGoTrafficTick` 明明拿到逐 uid 的 `tx/rx` 增量（`:184-190`），却只喂总队列，丢弃了计算每应用 EMA 所需的数据。
  - `ensureGoDecayWatchdog`/`decayIdleSpeeds`（`:215-229`、`TrafficSpeedEstimator.kt:62-71`）只衰减已有的每应用 map，空 map 时无效。
  - 「按实时网速」是用户可选排序项（`AppTrafficStatsModels.kt:17`），排序键恒全 0 ⇒ 排序静默无操作；逐项 ↑/↓ 速度文本因 `>0` 门槛永不出现；说明页对「各应用实时网速」的承诺落空。总量仪表不受影响（`updateSpeedEma` 在 tick 路径有调用）。
- **触发路径**
  1. 启动 VPN（Go 隧道，即普通模式正常路径），让 2 个以上应用产生流量。
  2. 打开「应用流量统计」，切换排序为「按实时网速」：列表顺序与「总流量」排序一致（全 0 稳定排序不重排）；任何应用条目下都不出现速度行。
- **复现/验证**
  1. 静态：`grep -rn updateSingleAppSpeedEma` → 仅 `TrafficStatsManager.kt:255`（采样循环内部）；`grep -rn "TrafficStatsManager.start("` → 仅 `DnsVpnService.kt:321` 字面 `true`。
  2. 单测方向：以 `start(context, isGoTunnelActive = true)` 后调用 `onGoTrafficTick(json)`（两条 uid 增量），断言 `buildAppStatsList` 中 `currentTxSpeedBps > 0` ——当前实现返回 0，复现缺陷。
- **备注**
  - 修复方向：`onGoTrafficTick` 的循环内（`:188` 附近）对每个 `appInfo` 调用 `speedEstimator.updateSingleAppSpeedEma(appInfo.packageName, tx, rx, elapsedSeconds)`（`elapsedSeconds` 用同一 tick 间隔），并对无增量应用走 `decaySingleAppSpeed`；或让 UI 在 Go 模式下隐藏「实时网速」项。两种都要同步核对 `TrafficAttributionDialog` 文案。

---

## A-016 「清除自定义背景缓存」清空错误的偏好文件，背景设置与 URI 列表原样保留并继续生效

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:429-438` — `clearCustomBackground()`：先 `CustomBackgroundManager.clearActiveCache(context)`，再对 `context.getSharedPreferences("appearance_settings", …)` 执行 `remove("custom_background_enabled") / remove("custom_background_uri") / remove("custom_background_uris")`，最后 `onBackgroundSettingsChanged(context, false, null)`
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/AppearanceSettingsStore.kt:1`（package `com.haoze.diting.ui.settings`）+ `:23-25`（键定义）+ `:121,127,133,171`（读写全部走 `PREFS_NAME`）
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt:8` — `internal const val PREFS_NAME = "dns_vpn_prefs"`：即 `AppearanceSettingsStore` 与同包 `StartupSelfCheck.kt:22` 实际使用的偏好文件是 **dns_vpn_prefs**，全仓没有任何代码读写名为 `appearance_settings` 的偏好文件（该字符串只出现在清理器 `:431` 与导航路由常量 `AppNavigationRoutes.kt:56`，后者是页面路由名，与 SharedPreferences 无关）
  - UI 承诺：`normal/ui/DataCleanupScreen.kt:121` 与 `express/ui/ExpressDataCleanupScreen.kt:203` 的 `CUSTOM_BACKGROUND` 项 →「清除自定义背景缓存」
- **问题**
  - `remove` 打在空文件 `appearance_settings` 上，真实设置仍完整留在 `dns_vpn_prefs` 中。
  - `onBackgroundSettingsChanged(context, false, null)`（`ui/background/CustomBackgroundManager.kt:265-271`）只做 `clearActiveCache`（丢弃已解码位图），**不写回** `custom_background_enabled`；因此下一次 `applyWindowBackground`（`:278-280`）仍从 `AppearanceSettingsStore.isCustomBackgroundEnabled()` 读到 true，随即按原 URI 重新加载背景。
  - 与 A-013 同族：清理器对目标路径/键的引用与实现方各自硬编码字符串，无共享常量约束。
- **用户可见影响**
  - 用户点「清除自定义背景缓存」并确认后，当前会话中背景短暂消失（缓存被清），随后任意 Activity 创建/重建（切后台回前台、旋转、重进应用）背景即恢复；重启应用后背景完全如旧。设置页中的开关与图片列表也原样保留，用户感知「清理项无效」。
  - `clearAllLocalData` 的全量清理（NORMAL `:533` 与 EXPRESS `:484`）同样调用该函数，「全面数据清理」后自定义背景仍在。
- **触发路径**
  1. 外观设置 → 开启自定义背景并选择图片。
  2. 数据清理 → 清除自定义背景缓存 → 确认。
  3. 回到桌面再重新打开应用：期望恢复默认背景，实际自定义背景仍在。
- **复现/验证**
  1. 静态：`DataCleanupManager.kt:431` 的 `"appearance_settings"` 与 `SettingsPreferencesExtensions.kt:8` 的 `"dns_vpn_prefs"` 对比；grep 全仓确认无任何 store 以 `appearance_settings` 为名调用 `getSharedPreferences`。
  2. 真机：`run-as com.haoze.diting cat shared_prefs/dns_vpn_prefs.xml | grep custom_background` 在清理前后均含 `custom_background_enabled=true` 与 URI 列表（`appearance_settings.xml` 要么不存在、要么为空）。
  3. 单测方向：Robolectric 下 `AppearanceSettingsStore.setCustomBackground(ctx, true, "content://x")` → `DataCleanupManager.clearCustomBackground(ctx)` → 断言 `isCustomBackgroundEnabled(ctx)` 为 false；当前实现返回 true，复现缺陷。
- **备注**
  - 修复方向：`clearCustomBackground` 应改用 `context.getSharedPreferences(PREFS_NAME, …)`（或直接调用 `AppearanceSettingsStore.setCustomBackground(context, false, null)` / 新增 `AppearanceSettingsStore.clearCustomBackground`，把键名与文件名的来源收敛到 store 内部）；同时核对 `custom_background_uris`（列表键）一并清理。
  - 对照：同函数体内 `StartupSelfCheck.kt:52-61` 清理同名 JSON 键时用的就是 `PREFS_NAME`（`dns_vpn_prefs`），可见清理器此处属笔误而非设计。

---

## A-017 `dnsCache` 清理协程无停止路径 + CA 管理器按调用新建 `Engine`，每次证书校验泄漏一个常驻 goroutine 与缓存对象图

- **位置**
  - `Android/tunnel/dns_cache_policy.go:95-108` — `startCleaner()` 启动 `go func(){ for { select { case <-c.stopCleaner: …; case now := <-ticker.C: c.cleanupExpired(now) } } }()`（30s ticker），唯一退出通道是 `c.stopCleaner`
  - `Android/tunnel/dns_cache.go:66` — `newDNSCache()` 内即调用 `cache.startCleaner()`；`:101` `func (c *dnsCache) close()` 关闭 `stopCleaner`，**但全仓 `close()` 的调用方只有 `dns_cache_test.go`（5 处），生产代码零调用**
  - `Android/tunnel/engine.go:120-134` — `NewEngine()` 固定 `dnsCache: newDNSCache(...)`；`Stop()`（`:209-329`）逐项拆解 interceptor/router/tunFile/flowOutbound/standalone servers/blooms/logAggregator/trafficTracker/policyEngine —— **没有 `dnsCache` 一行**（逐行 grep 确认）
  - `Android/app/src/main/java/com/haoze/diting/core/cert/GoInspectionCaManager.kt:18-24` — `certificatePem()` 每次调用 `val engine = Engine()`，只 `startStackMitm`/`stopStackMitm`，从不调 `engine.stop()`；`fingerprintSha256`/`isInstalled`/`exportCertificateToUri` 全部经由它
  - `Android/tunnel/engine_mitm.go:44-49` — `StopStackMitm()` 仅置空 `stackCertMgr`/`stackMitmFilter` 两字段，无任何缓存/协程回收
- **机制**
  - 每构造一个 `Engine`（含仅取一次证书 PEM 的临时 Engine），其 `dnsCache` 的 cleaner goroutine 就永久存活：`select` 只在 `stopCleaner` 关闭时退出，而生产路径无人能关闭它；goroutine 引用 → `dnsCache`（64 个分片 map、flight map、entry 对象）永远不可 GC。
  - `Engine.Stop()` 也不回收，意味着**即使是正常跑完的 VPN 会话**，每启动一次也滞留一个 cleaner goroutine + 缓存对象图（Go 绑定对象本身可被 GC，但 goroutine 持有 `stopCleaner`/`ticker.C` 通道与 `c`，整个 `dnsCache` 逃逸于 GC）。
  - CA 场景放大：`isInstalled` 的调用面 —— `normal/DnsVpnTunnelManager.kt:58-64`（`verifyHttpsInspectionCertificateAsync`，VPN 启动/配置刷新时异步校验证书）、`CaCertificateSettingsScreen.kt` 的界面状态检查与导出/指纹路径。每次调用 = 一个 `newDNSCache` = 一个永不退出的 goroutine + 每 30 秒一次的空转唤醒。
- **用户可见影响**
  - 长时间保持 VPN 运行、频繁进入证书设置页/触发证书校验的设备：goroutine 数与常驻内存随调用次数线性增长（每千次约 1000 个空转 timer goroutine）；30s 周期唤醒对功耗有轻微持续影响。单进程寿命内不至于 OOM，但属于「可验证的无界泄漏」。
- **触发路径**
  1. 打开 CA 证书设置页并反复点「检查是否已安装」N 次（或反复重启 VPN）。
  2. 观察 Go 侧运行时统计。
- **复现/验证**
  1. 静态：`grep -rn "dnsCache" tunnel/engine.go` 确认 `Stop()` 无 `dnsCache` 回收；`grep -rn "\.close()" tunnel/*.go`（排除 _test）无 dnsCache 命中。
  2. 运行取证：在 Go 单测或临时调试构建里循环调用 `NewEngine()` N 次后 `runtime.NumGoroutine()` 断言增量 ≈ N（当前实现如此）；修复方向：`Engine.Stop()` 调用 `e.dnsCache.close()`，`GoInspectionCaManager.certificatePem` 复用单例引擎或改用不建缓存的轻量入口（`startStackMitm` 本身并不使用 `dnsCache`）。
- **备注**：修复必须同时处理「Stop 不回收」与「CA 管理器按调用 new Engine」两处；只改其一仍留另一半泄漏面。

---

## A-018 引擎 setter 与查询协程对同一字段均不加锁：`e.mu` 不建立 happens-before，构成数据竞争

- **位置**
  - 写侧（无锁）：`Android/tunnel/engine_config.go:47-49` `SetDomainChecker`（`e.domainChecker = checker`）、`:273-287` `SetFirewallChecker`/`SetAppResolver`/`SetAppUidResolver`/`SetLogCallback` 全部裸赋值；`:385-387` `SetBlockResponseType`（`e.responseType = ParseResponseType(responseType)`）
  - 写侧（持锁对照，证明字段语义上属于 `e.mu` 域）：`Android/tunnel/dns_config.go:133-136` — `applyDNSConfig` 写同一 `e.responseType` 时是 `e.mu.Lock()` … `Unlock()`
  - 读侧：`Android/tunnel/engine_dns.go:260`、`:280` `switch e.responseType`（查询处理协程内，**无锁**）；`engine_standalone.go:247-249` 的读在 `e.mu.Lock()` 内（有锁侧）。接口字段两侧均无锁：`e.domainChecker` 写于 `engine_config.go:47-49`（无锁），读于 `engine_standalone.go:158-159`、`:176-177` 与 `engine_dns.go:106-107`（均无锁）——这是可撕裂 2 字接口值的最实证的一对。
  - 字段声明：`Android/tunnel/engine.go:45` — `responseType ResponseType`（普通 int，非 atomic）；接口字段同为普通字段
  - 并发运行时可达性：`Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:95-105` — `syncRules()` 在引擎**已服务**期间调用 `engine.setRewriteRules(...)`、`engine.setBlockResponseType(...)`；触发源 `DnsModeService.kt:159-171`（`ACTION_REFRESH` → `refreshDnsEngine()` → `syncRules()`）：用户在 DNS 模式运行中改一条规则即命中
- **机制**
  - Go 内存模型：`responseType` 的无锁写（`SetBlockResponseType`）与无锁读（engine_dns 两处）之间没有任何同步边；同时它与 `ApplyDNSConfig`/`Start` 的持锁写互相竞争（一方不持锁即破坏互斥语义），`e.mu` 对该字段不构成 happens-before。接口字段（双 2 字：类型指针+数据指针）写读两侧均无锁，可能观察到不配对的两半，一旦发生即调度进错误的 Kotlin 回调对象或崩溃；至少 `go test -race` 会判 UB。
  - 与 Express/VPN 启动路径不同：那条链路 setter 都在 `startFull` 之前完成（`GoInspectionTunnel.kt:91-99` 先 `configureEngine` 后 launch），不构成竞争；本条的竞争窗口在 **DNS 模式运行中刷新**（`syncRules` 与 serve goroutine 并发）与 `DnsServerEngine.applyDnsConfig`（`:214` `engine.applyDNSConfig(json)` 运行中调用）。
- **用户可见影响**
  - 概率性、非确定：表现为 DNS 模式改规则/改封锁响应类型瞬间偶发错误响应类型（如设 NXDOMAIN 却回 0.0.0.0）、回调串线或（接口撕裂时）进程崩溃。静态上这是对共享字段的未同步并发读写，属必须修的缺陷类别。
- **复现/验证**
  1. `cd Android/tunnel && go test -race ./...` 配一个并发压测：一个 goroutine 循环 `SetBlockResponseType`，另一路查询流量（本机 `go1.27.2` 可跑；现有测试不覆盖该并发，当前套件绿不代表安全）。
  2. 静态核对：`e.responseType` 的全部读点（engine_dns.go:260/280、engine_standalone.go:248）与 `SetBlockResponseType` 写点（engine_config.go:385）均不在 `e.mu` 临界区。
- **备注**
  - 修复方向：把 `responseType` 改为 `atomic.Int32`（或全部读写统一进 `e.mu`）；`domainChecker` 等接口字段统一 `atomic.Value`/带锁 getter 快照（项目经验教训「长生命周期对象不得按值捕获会被热替换的字段」同源）。`SetBlockResponseType` 至少应像 `dns_config.go:133` 一样持锁。

---

## A-019 UDP 上游截断（TC=1）响应既不重试 TCP 也不拒缓存：客户端 TCP 重试命中同一截断缓存，残缺答案在 TTL 内固化

- **位置**
  - `Android/tunnel/resolver_plain.go:70-107` — `queryPlainContext` UDP 读 `buf := make([]byte, 4096)`，`return buf[:n]` 前无任何 TC 检查/转 TCP；全包 `grep Truncated` 零命中（非 _test）
  - 对照组（证明并非无人手滑）：`Android/app/src/main/java/com/haoze/diting/express/transport/ExpressPlainDnsTransport.kt:48-52`（Kotlin Express 路径）**有**截断转 TCP 逻辑 `if (ExpressDnsMessageUtils.isTruncatedResponse(response)) { queryTcp(...) }` —— 同功能在 Go 主 VPN 路径缺失
  - `Android/tunnel/dns_cache.go:242-278` — `putMsg` 仅按 rcode/answer 数/TTL 决定入库，从不看 `respMsg.Truncated`；`dns_cache_flight.go:74-79` 把原样响应喂进 `put`
  - `Android/tunnel/engine_standalone.go:295-304` — 命中缓存后 `w.Write(cachedResp)` 原样回给客户端（含 TC=1）
- **机制**
  1. 上游对大应答（多记录 CDN、DNSSEC、长 TXT）置 TC=1 截断 UDP 返回（默认 512B 截断，Go 查询未带 EDNS0 bufsize —— 全包 `grep Edns0` 零命中）。
  2. 引擎不重试 TCP，把截断响应返回客户端并缓存。
  3. 解析器客户端（Android bionic/Chrome）见 TC=1 按 RFC 5966 走 **TCP** 重查同一问题 → `serveDNS`（TCP 也进同一函数）→ `dnsCache.getFast` 命中刚存的**截断 UDP 报文** → 回写残缺答案，且 TCP 通道本可拿全量也被截断缓存短路。
  4. TTL 内每次查询（UDP 直接命中缓存、TCP 命中截断缓存）都拿不到完整记录集。
- **用户可见影响**
  - 记录数多的域名（大型 CDN 轮换、DNSSEC 签名区）在 VPN/DNS 模式下间歇性解析不全：连接变慢（客户端耗尽残缺列表后重查）、多栈偏好下 IPv6 记录恰好被截掉时回退 v4 甚至失败。日志表现为同一域名反复「解析成功但连接异常」。
- **触发路径**
  1. VPN 或 DNS 模式运行，上游选普通 53 端口 UDP。
  2. 查询一个应答 >512B 且上游未启 EDNS0 的域名（如部分 DNSSEC 签名域的 ANY/TXT，或多记录 CDN 域）。
  3. `dig +tcp @<手机> <域名>` 与 `dig +udp` 对比：TCP 本应拿全量，实际两者都返回同一份 TC=1 截断结果。
- **复现/验证**
  1. 静态：resolver_plain.go 无 TC 分支、无 `queryPlainTCPContext` 的截断后调用（`:47` 那处调用是显式 `forceTCP` 策略路径，非 TC 触发）；`putMsg`/`getFast` 路径无 `Truncated` 判断。
  2. 运行：`go test` 构造 TC=1 假上游，断言 (a) resolver 应转 TCP 重查（当前不转）；(b) `putMsg` 应拒收截断报文（当前入库）。
- **备注**
  - 修复方向（任一即可断链，建议双做）：`queryPlainContext` 读包后 `msg.Header.Truncated` 为真时走 `queryPlainTCPContext`；`putMsg` 对 `respMsg.Truncated` 直接返回 false 不缓存。Express Kotlin 侧已有正确实现可作语义参照。

---

## A-020 DNS 模式「启用域名过滤」总开关完全失效：standalone 路径从不读取 `filterDNS`，快照 `filterEnabled` 恒真

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:69,88,130`（`engine.setFilterDNS(config.adBlockEnabled)`，值经 `engine_config.go:67` `e.filterDNS.Store(enabled)` 存入 Go）
  - `Android/tunnel/engine_standalone.go` — 全文件 `grep -c filterDNS` = **0**：standalone 的 `serveDNS`（`:147`）在 `policyEngine.isActive() && hasRules()` 时直接评估拦截，从不查询 `e.filterDNS`
  - 对照 VPN 路径确实有闸门：`Android/tunnel/engine_dns.go:83-86` `if !e.filterDNS.Load() { e.handleForward(...) }`
  - 两道后备闸门同时失效：
    - 快照 `filterEnabled`：`core/rule/DomainPolicyEngine.kt:120` `root.put("filterEnabled", isEnabledProvider())`；而 DNS 模式构造点 `server/backend/DnsQueryFilter.kt:57` `DomainPolicy(allowListManager, blockListManager)` **未传提供器**，落入默认值 `DomainPolicyEngine.kt:41` `{ true }`（对照普通模式 `normal/DnsVpnDatabaseComponents.kt:93` 传 `{ isDomainRulesEnabled() }`）→ Go `policy_snapshot.go:147` `if s == nil || !s.filterEnabled` 永不触发
    - Kotlin `DomainChecker` 回调（`DnsServerEngine.kt:106-134`）调用同一恒真策略
  - UI 承诺：`normal/ui/RuleControlScreen.kt:126-128`（DNS dataset 经 `server/ui/DnsSettingsScreen.kt:89` 进入）关闭时显示「已关闭恶意域名过滤，查询将直接放行」；`ui/settings/RuleSettingsAccess.kt:23,30-33` 读写 `DnsModeConfig.adBlockEnabled`
- **问题**：DNS 模式下把总开关拨到关，prefs、StateFlow、Go `filterDNS` 三层都正确置了关，但第四层（真正做拦截决策的 standalone 评估路径）不看任何一层开关，规则继续拦截。
- **用户可见影响**：局域网客户端经手机 DNS 解析被拦截域名仍返回 NXDOMAIN/REFUSED/0.0.0.0，与 UI 明示的「直接放行」相反；用户无法在不删规则的前提下临时停用过滤。
- **触发路径**：DNS 模式添加 `||example.org^` → 运行 → 规则控制关闭「启用域名过滤」→ LAN 客户端 `dig @手机 example.org` → 仍被拦截。
- **复现/验证**：静态核对上述 grep 计数；或给 `DnsServerEngine` 增加断言：`adBlockEnabled=false` 时 `buildRuleSnapshotJson()` 的 `filterEnabled` 应为 false（当前恒 true）。
- **备注**：修复需两处任选其一并保持 VPN/DNS 语义一致——`DnsQueryFilter` 构造 `DomainPolicy` 时传入 `{ DnsModeManager.config.value.adBlockEnabled }`（走快照闸门），或 Go `serveDNS` 增加 `e.filterDNS.Load()` 检查（与 `engine_dns.go:83` 对齐）。

---

## A-021 DNS 模式停止/启动竞态：`engine.start()` 无取消点，销毁后回填引擎并置 RUNNING，孤儿引擎霸占端口直到进程死亡

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModeService.kt:111-152` — `startDnsEngine()` 协程：`:117` `loadRules(filter)`（挂起点）→ `:139` `engine.start()`（阻塞 bind，**无挂起点**）→ `:140` `dnsServerEngine = engine` → `:143` `DnsModeManager.onServiceStarted()`
  - `:89-99` `onDestroy()`：`startJob?.cancel()`、`stopDnsEngine()`（`:187-190`，此时 `dnsServerEngine` 仍为 null——仅在 `:140` 赋值）、`onServiceStopped()`
  - `server/backend/DnsModeManager.kt:88-103` `stopService()` 仅拦截 STOPPED/STOPPING，**STARTING 状态可以停止**；`:115-118` `onServiceStarted()` 无条件置 RUNNING；`:130-135` `onServiceError()` 无条件覆盖状态
  - 停止入口：通知「停止」按钮（`DnsModeService.kt:262-270` `ACTION_STOP` PendingIntent → `onStartCommand:52-55` `stopSelf()`）或模式切换（`core/WorkModeLifecycleRegistry` → `DnsModeManager.stopService`）
  - 端口占用错误面：`DnsModeService.kt:146-150` `start()` 失败 → ERROR「DNS 服务启动失败，监听端口可能被占用」；Go bind 失败点 `tunnel/engine_standalone.go:444-451`
- **机制**（两条交错均有实证）
  1. **孤儿引擎**：取消是协作式的；协程在 `:139` 的 gomobile 阻塞调用内，`cancel()` 无效，恢复执行后把引擎赋给**已销毁服务实例**的字段并置 RUNNING。此后：LAN 查询照常应答（端口仍被持有），UI 已显示停止；再点启动 → 新 `Engine` bind 同端口失败 → 永久 ERROR，直至杀进程。
  2. **停止被误报为失败**：取消落在 `:117` `loadRules` 挂起点时，`runCatching`（`:182-185`）会把 `CancellationException` 一并吞掉 → `loadRules` 返回 false → `:118` `onServiceError("DNS 规则加载失败，请重试")`，且 `onServiceError` 无条件覆盖 `onDestroy` 刚设的 STOPPED——用户主动停止却看到红色失败卡片。
- **触发路径**：导入大订阅（`reloadSync` 耗时数秒）→ DNS 模式点启动 → 加载期间点通知「停止」（或切换工作模式）→ 观察：UI 停止但 `adb shell ss -ulpn | grep 1053` 仍有 socket；重新点启动报端口占用。
- **复现/验证**：`:139` 之后加 `currentCoroutineContext().isActive` 检查即可消除交错 1；`loadRules` 改为 `runCatching` 前单独放行 `CancellationException`（`if (e is CancellationException) throw e`）消除交错 2。
- **备注**：`refreshDnsEngine()`（`:159-174`）同样在 `loadRules` 后直接取 `dnsServerEngine`，服务销毁竞态同型，修复时一并覆盖。

---

## A-022 DNS 模式端口 5353/5354 在每次 `loadConfig` 被强制改写为 1053（迁移逻辑常驻化），与验证器/UI 承诺矛盾且会持久化

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModePreferences.kt:41-42` — `val rawPort = prefs.getInt(KEY_LOCAL_PORT, 1053); val port = if (rawPort == 5353 || rawPort == 5354) 1053 else rawPort`（无任何一次性迁移标志守护；同文件 `:46-51` 的 `logQueries` 迁移恰恰示范了正确写法——用 `KEY_LOG_QUERIES_MIGRATED` 只迁一次）
  - `server/model/DnsListenPortValidator.kt:10-17` — 允许 1024–65535 全区间（含 5353/5354）；`server/ui/DnsPortEditDialog.kt:35-41` 校验通过即原样保存；测试 `app/src/test/.../DnsModeTest.kt:310` 断言 `validate("5353")` 通过
  - 全仓 `grep 5353` 除测试外仅此一处：UI 没有任何「5353/5354 不可用」提示
  - 持久化路径：`ui/settings/RuleSettingsAccess.kt:30-33` 以 `loadConfig().copy(...)` 重建整份配置 → `DnsModeManager.updateConfig`（`server/backend/DnsModeManager.kt:196-200`）→ `DnsModePreferences.saveConfig`（`:65-69`）把改写后的 1053 **写回 prefs**；随后 `refreshEngineIfRunning` → `DnsServerEngine.updateConfig` `:73-77` 检出 `portChanged` → `stop(); start()` 实际改绑
- **问题**：本应只作用于历史安装的一次性迁移每次读取都执行；用户显式选择 5353 合法且可保存，但 (a) 拨动「启用域名过滤」等任何经 `RuleSettingsAccess` 全量重建配置的写操作，(b) 每次重启/START_STICKY 重建（`DnsModeService.kt:46` → `DnsModeManager.initialize` → `loadConfig`），端口都会静默变为 1053，且 (a) 还会把 1053 持久化，用户选择被销毁。
- **用户可见影响**：手动把 LAN 设备 DNS 指到手机:5353 的用户，在重启手机或切换过滤开关后解析全部超时（服务已在 1053）；设置页此后显示的也是 1053。
- **触发路径**：端口设为 5353 → 运行 → 规则控制拨一次总开关 → `adb shell ss -ulpn` 见监听 1053，prefs `local_listen_port`=1053。
- **复现/验证**：单测：`saveConfig(port=5353)` 后 `loadConfig().localListenPort` 应为 5353，当前返回 1053；或按上述真机步骤。
- **备注**：修复方向——迁移加一次性标志（仿 `KEY_LOG_QUERIES_MIGRATED`），或从验证器同步禁掉 5353/5354 并在迁移后清除；两处必须口径一致。

---

## A-023 DNS 模式动态拦截策略从未下发：`applyDnsConfig` JSON 缺 `dynamicResponse` 键，Go 零值即禁用

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsServerEngine.kt:165-211` — `applyDnsConfig()` 仅写 `mode/blockResponse/cache/providers/bootstrap`，**无 `dynamicResponse`**
  - 对照普通模式有该键：`normal/HttpsDnsConfigSnapshot.kt:51-55`
  - Go 侧解析：`tunnel/dns_config.go:36` `DynamicResponse dynamicBlockConfig json:"dynamicResponse"`，`:110` `DisallowUnknownFields()`（键名不可能拼错，是根本没发）；缺省 → 零值 → `Enabled=false` → `dns_config.go:58-60` `responseFor` 恒返回静态响应；`engine_standalone.go:251` 的调用因此永远是直通
  - 存储与 UI 全链路都在：`server/backend/DnsRuleSettings.kt:37`（prefs 读取）→ `ui/settings/RuleSettingsAccess.kt:67-74` → `normal/ui/RuleControlScreen.kt:170-177` 副标题「动态策略：先 NODATA，高频请求后 NXDOMAIN」→ `ui/BlockResponseSettingsScreen.kt:52-55` 保存并 `refreshIfRunning`
  - `server/backend` 内 `dynamicBlockResponseConfig` 除 `RuleSettingsAccess` 外零读取（grep 实证）
- **问题**：用户在 DNS 模式开启动态拦截并设定阈值/窗口/时长，全部持久化成功，但引擎侧永远收不到，拦截响应始终静态。
- **用户可见影响**：UI 明示「动态策略」生效中，实际被拦截域名永远按固定 NXDOMAIN/0.0.0.0 应答，高频查询不再升级 NODATA→NXDOMAIN；功能是死的。
- **触发路径**：DNS 模式 → 规则控制 → 拦截响应 → 开动态、阈值 2 → LAN 客户端连续 >2 次查询被拦截域名 → 应答与阈值无关。
- **复现/验证**：在 `applyDnsConfig` 打印 JSON：无 `dynamicResponse`；或 Go 单测以该 JSON 调 `ApplyDNSConfig`，断言 `e.dynamicResponse.Enabled == false`。
- **备注**：`updateConfig` 的变更检测（`DnsServerEngine.kt:66-72`）也忽略动态配置，即使补发 JSON 还需把 `DnsRuleSettings.dynamicBlockResponseConfig` 纳入 `applyDnsConfig` 与变更触发。

---

## A-024 DNS 模式 STARTING 窗口内的配置/上游修改被丢弃：引擎以启动瞬间快照绑定，RUNNING 前的一切编辑不重放

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/server/backend/DnsModeService.kt:111-114` — 协程开头一次性捕获 `config`/`upstream`；`:117` 挂起于 `loadRules`（大规则库时可达秒级）；`:125-137` 用**捕获值**构造 `DnsServerEngine`；`:139` bind
  - `server/backend/DnsModeManager.kt:137-142`（`selectUpstream`）/`:196-200`（`updateConfig`）→ `:202-208` `refreshEngineIfRunning`：`if (!_status.value.isRunning) return` — STARTING 不算 running，**不下发 ACTION_REFRESH**
  - `:115-118` `onServiceStarted()` 置 RUNNING 后没有任何重读 StateFlow/补发刷新的代码（`DnsModeService.kt:141-145` 直接结束）
- **问题**：启动加载期间在主线程改上游（如 Cloudflare → 自建 DoH）或改缓存预设/端口：`DnsModeManager` 的 StateFlow 与 prefs 已更新、UI 立即显示新选项，但引擎用旧快照 bind；RUNNING 后无人再对账。
- **用户可见影响**：服务器以旧上游解析（LAN 客户端拿到旧 DNS 的应答），设置页显示新上游——直到下一次任意设置变更（触发 ACTION_REFRESH）或重启服务才自愈；端口同窗修改还会出现 UI 显示 1053 实际监听旧端口。
- **触发路径**：导入数万条规则 → 点启动（进入 STARTING 转圈）→ 立即在服务器设置切换上游 → 启动完成 → `dig` 验证仍走旧上游。
- **复现/验证**：单测方向：以可延迟的 fake `reloadSync` 断言在 STARTING 中 `updateConfig` 后 `dnsServerEngine.config` 未变；或真机 logcat `applyDNSConfig provider id`。
- **备注**：修复可与 A-021 一并进行：`onServiceStarted()` 后比对 StateFlow 现值与引擎持有值，不一致则补发 `refreshDnsEngine()`；或把「捕获」改为 bind 前一刻重读。

---

## A-025 导入未勾选「禁止联网名单」的备份会静默关闭本机禁止联网总开关（缺省 false + 不等即写）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:272-276` — `blockedAppsEnabled` 仅在 `selection.blockedApps` 勾选时写出
  - `ui/transfer/ConfigTransferParser.kt:236` — `root.optBoolean("blockedAppsEnabled", false)`：键缺失 → `false`
  - `ui/transfer/TransferConfigDto.kt:38` — `val blockedAppsEnabled: Boolean = false`（非空，缺失与关闭不可区分）
  - `ui/transfer/AppRuleConfigImporter.kt:59-64` — `if (isBlockedAppsEnabled(context) != config.blockedAppsEnabled) setBlockedAppsEnabled(...)`：不等即写 → 本机开(→文件缺省关) 时被关闭
  - 同族对照（作者明知该模式的反证）：`ConfigTransferParser.kt:277-279,291` `domainRulesEnabled/addressRulesEnabled/encryptedDnsBlockingEnabled/allowEditDefaultWhitelist` 全部按 `if (root.has(...)) … else null` 解析为**可空**，缺失=不改；`AppRuleConfigImporter.kt:109` `appAllowlistEnabled` 亦只做 truthy 开启不做关闭。`blockedAppsEnabled` 是唯一「硬 false 缺省 + 不等即写」的主开关。
  - 旁证：`express/config/ExpressConfigAdapter.kt:60-66` 注释明确「为避免改动用户既有的禁止联网偏好」而在 Express 侧对齐本地状态——NORMAL/DNS_MODE 导入路径没有这层防护。
- **用户可见影响**：用户刻意不勾选「禁止联网名单」做部分备份（`ui/transfer/ConfigTransferScreen.kt:226` 的正常选择）→ 在已开启禁止联网的设备上导入 → 总开关被静默关掉：名单还在，但所有被禁应用恢复联网；家长控制/管控语义直接失效。摘要仅显示一行「开关 -> 已禁用」的良性文案。
- **触发路径**：A 机开启禁止联网并加入若干应用 → 备份页取消勾选「禁止联网名单」→ 导出 JSON（确认文件无 `blockedAppsEnabled` 键）→ 导入该文件 → `AppRulesSettingsStore.isBlockedAppsEnabled` 变 false。
- **复现/验证**：Robolectric 单测：预置 `setBlockedAppsEnabled(true)`，导入 `{"formatVersion":9}` 最小文件，断言仍为 true（当前实现为 false）。
- **备注**：修复方向：解析改 `if (root.has(...)) … else null` + DTO 改 `Boolean?` + 导入器 null 时跳过；与兄弟开关口径统一。

---

## A-026 出站代理用户名/密码被解密后明文写入导出 JSON（加密存储承诺被导出环节降级）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/settings/OutboundProxySettingsStore.kt:61-62,169-188` — 落盘经 `encryptProxySecret`（AES/GCM）刻意加密
  - `:44-45` — `getOutboundProxyConfig` 返回**解密后**的 username/password（并缓存明文 `cachedConfig`）
  - `ui/transfer/ConfigExporter.kt:131-140` — 导出直接 `put("username", proxyConfig.username)`、`put("password", proxyConfig.password)`，无掩码/无警告区分
  - `ui/transfer/ConfigTransferScreen.kt:266-268` — 仅提示「包含个人自定义设置，请妥善保管」，未说明凭据为明文
  - 往返本身正确（`NetworkFeatureConfigImporter.kt:87-98` 导入时重新加密），问题只在导出面
- **用户可见影响**：备份 `.json` 经微信/网盘/云备份流转时，任何拿到文件的人可直接读出代理账号密码——与「密钥加密存储」的设计承诺相悖；这是本模块中唯一把受保护秘密落到可分享介质的路径。
- **触发路径**：配置带认证的 SOCKS5/HTTP 出站代理 → 备份与迁移 → 勾选「出站代理」导出 → 打开 JSON 见 `"password": "<明文>"`。
- **复现/验证**：设置代理密码后导出，比对 JSON 值与 `getOutboundProxyConfig().password`（明文）而非 prefs 密文。
- **备注**：属安全缺陷而非功能缺陷；修复至少应 (a) 导出时显著警示含凭据、(b) 提供不含机密的导出选项，或 (c) 用用户口令对导出文件内凭据字段再信封加密。

---

## A-027 `latencyTestProviderRefs` 导出与解析齐备，但任何导入器都不应用：测速节点选择迁移后静默丢失

- **位置**
  - 写：`Android/app/src/main/java/com/haoze/diting/ui/transfer/ConfigExporter.kt:96` `root.put("latencyTestProviderRefs", serializeProviderIds(ResolutionSettingsStore.getLatencyTestProviderIds(context, dataset)))`
  - 读：`ui/transfer/ConfigTransferParser.kt:83` 解析、`:348` 装入 DTO；`TransferConfigDto.kt:22` 字段存在
  - 消费缺失：`ui/transfer/ProviderConfigImporter.kt:57-125` 仅应用 selected/race/smartPrediction/parallelRace/primaryBackup 五族；全仓 grep `latencyTestProviderRefs` 无任何 importer 命中；写入 API `ResolutionSettingsStore.setLatencyTestProviderIds`（`ui/settings/ResolutionSettingsStore.kt:82`）在 transfer 包零调用
  - 该值真实在用：`ui/RaceModeSettingsViewModel.kt:114` 读取回显、`:145` 用户修改后保存
- **用户可见影响**：用户在测速设置选定的节点被写进备份、用户看得到它在文件里，导入后设置回到默认——「迁移不可靠」，且无错误提示。
- **触发路径**：选测速节点 → 导出 → 清数据/新机导入 → 重开测速设置：选择为空。
- **复现/验证**：导入含 `latencyTestProviderRefs: ["a","b"]` 的文件，比对 `getLatencyTestProviderIds` 前后不变（当前行为）。

---

## A-028 批量添加丢弃 `appInverted`：`~app=` 排除规则被反转为「仅这些应用」拦截，且与既有倒置规则产生重复行

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/batch/BatchRuleModels.kt` — `ClassifiedLine.Domain` 字段集为 pattern/isAllow/rawLine/appScope/important/isWildcard/denyallow/isRegex/dnsType，**无 appInverted**
  - `ui/batch/BatchRuleClassifier.kt:318-329,345-356,366-379` — 三个域规则分支构造 `ClassifiedLine.Domain(...)` 时均不传递 `parsed.appInverted`（`AdblockRuleLineParser.kt:70-95` 已解析出该值）
  - `ui/batch/BatchRuleValidator.kt:104` — 批内去重键 `"$prefix:pattern:important:appScope:dnsType:denyallow:isRegex"` 不含 appInverted；`:116,125` 存在性检查 `idByPattern(appInverted = false)`；`:293,315` 提交实体硬编码 `appInverted = false`
  - 对照单条路径保留：`ui/BlacklistViewModel.kt:396` `appInverted = ... parsed.appInverted`；UI 徽章 `normal/ui/AppRuleComponents.kt:248`；传输路径保留：`ConfigExporter.kt:201,213` 写出、`RuleConfigImporter.kt:138,165` 按 rawLine 重推导
  - 唯一索引含 appInverted：`data/entity/BlockRuleEntity.kt:20` → 强制 false 同时改变**存储身份**与**求值语义**（`BlockRuleMatcher.findInSpecialRules:216-224` 依据 appInverted 决定「除…之外」还是「仅…」）
- **用户可见影响**：批量粘贴 `||example.com^$app=~com.android.chrome`（除 Chrome 外都拦）→ 提交后规则变成「仅拦 Chrome」，方向反转；若已有真倒置规则，还会因 `idByPattern(false)` 查不到而**再插一条反语义行**；批内两条仅 `~` 不同的行第二条被误报「已存在」丢弃。
- **触发路径**：黑名单 → 批量添加 → 粘贴 `$app=~` 行 → 完成 → 列表详情查看：无 `~` 徽章、语义翻转。
- **复现/验证**：单测 `BatchRuleValidator` 提交后读回 `BlockRuleEntity.appInverted`，rawLine 含 `app=~` 时期望 true、实际 false。
- **备注**：修复需给 `ClassifiedLine.Domain` 补 `appInverted` 字段并贯通分类/去重键/存在性检查/提交四处；与 A-029 同一文件可一并处理。

---

## A-029 批量 URL 规则绕过归一化直接入库：大小写主机/查询串/默认端口导致永不匹配或重复行

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/batch/BatchRuleClassifier.kt:88-97` — 显式 `http(s)://` 行仅 `isValidUrl` 宽松校验（`BatchRewriteParser.kt:68-72`：前缀+长度+无空格），`urlPattern = cleaned` **原文**入批
  - `ui/batch/BatchRuleValidator.kt:330-354` — 提交 `GoUrlRuleEntity(pattern = item.urlPattern, ...)` 直接写库
  - 对照单条路径：`core/rule/GoUrlRuleManager.kt:14-21` `addRule` → `parse`（`:41-53`：scheme/host 小写、剥离 `:80/:443`、拒绝 `*`/`$`/userInfo/fragment、保留 rawPath）；`ui/BlacklistViewModel.kt:368`、`RuleConfigImporter.kt:232` 都走这条
  - 匹配端归一化：`tunnel/engine_request_filter.go:32` 规则串 `strings.ToLower(TrimSpace(Pattern))`、`:44,53` 实际请求按 `scheme://host+path`（**无查询段**）拼串比较
- **机制/影响**（三个后果，均可静态推断）
  1. 含查询串的批量规则（`https://a.com/x?y=1`）：Go 匹配串永不含 `?y=1` → **规则永不命中**，而列表显示与「成功导入 N 条」提示都声称已添加；单条路径同输入会拒绝或归一。
  2. 大写主机：Go 只小写规则串（`:32`），`HTTPS://A.COM/x` 批量入库后被小写化能匹配，但与对话框存储的 `https://a.com/x` 在唯一索引 `(pattern,kind)`（`GoUrlRuleEntity.kt:10`，存原文）下成为**两行重复**；批内去重 `idByPattern(raw)`（Validator `:171`）查询原文形态，与已存归形态互不可见。
  3. 显式默认端口 `https://a.com:443/x` 批量保留、单条剥除 → 同类分裂。
- **触发路径**：对话框添加 `https://a.com/x` → 批量添加 `HTTPS://a.com/x` → 地址规则列表出现两条同义规则；批量添加 `https://a.com/x?y=1` → 规则显示存在但请求永不拦截。
- **复现/验证**：单测对 `GoUrlRuleDao`：批量与单条各插一次同一 URL，`enabledRules()` 返回 2 行（当前实现）。
- **备注**：修复：Batch 提交前过 `GoUrlRuleManager.parse`，parse 失败的行按「无效」归类而不是原文入库（顺带把 `?query` 明确化为拒绝理由文案）。

---

## A-030 规则导入器 `kind` 参数从不参与过滤，`typeSkipped` 无写入点：类型不符文件被全类别摄入，专用报错分支永不可达

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/CategorizedRuleStreamImporter.kt:63` — `kind: String` 入参；函数体内 `kind` 无任何读取（`:127/:150` 的 `GoUrlRuleKind` 为无关常量）
  - `:89` — `var typeSkipped = 0` 声明；`:254` `if (parsedRules == 0) onEmpty(typeSkipped > 0)`、`:270` `typeSkippedCount = typeSkipped` 两处读取；全文件（含 `importTwoPass`）**没有写入点**（grep 实证）
  - `:199-252` — block/allow/rewrite/urlBlock/urlAllow/cosmetic 六类无条件收集、无条件 flush
  - `data/entity/SubscriptionEntity.kt:52-64` — `SubscriptionKind` 仅 DOMAIN/HOSTS 两值；hosts 类订阅有专用路径 `countHostsRules`/`importHostsRules`（`RuleOperationWorker.kt:355-365`，`HostsAndDnsmqParser` 只解析 hosts 行），该路径**正确**按类型过滤
  - 依赖不可达分支的调用方：`core/rule/RuleOperationWorker.kt:433-440` 与 `core/rule/SubscriptionManager.kt:270-278` 的 `onEmpty(typeMismatchOnly)` 均抛「文件中没有${displayName(kind)}，请确认导入类型是否正确」
- **机制/影响**：以 `kind=DOMAIN`（黑白名单）身份添加/导入一个纯 hosts 文件时，hosts 行被解析为 rewrite 规则**原样入库**并计入订阅规则数（删除/停用订阅会连带清掉这些 rewrite，`SubscriptionRuleStorage.removeRulesBySource` 全表清理，无孤儿）；反之域名文件以 HOSTS 订阅导入走 `importHostsRules`，`countHostsRules` 恒 0 触发的是通用的「没有可导入的有效规则」，也不是类型提示。两个用户后果：(1) 选错类型没有任何纠错提示，内容直接污染另一类规则集；(2) 代码里明确写好的「请确认导入类型」错误分支是死代码，测试即使覆盖 `onEmpty` 也只测到 false 分支。
- **触发路径**：添加订阅 → 类型选「黑白名单规则」→ 粘贴 `127.0.0.1 localhost` 类 hosts 文件 → 导入成功且「改写规则」列表新增条目。
- **复现/验证**：单测：`import(kind=DOMAIN)` 输入纯 hosts 行，期望 `rewriteCount == 0` 且 `typeSkippedCount > 0`、`onEmpty(true)`；实际 rewrite 全部入库、`onEmpty` 不触发。
- **备注**：修复方向：按 `kind` 跳过不匹配类别并计入 `typeSkipped`（同时确认产品预期是「报错拒导」还是「静默忽略」）；`parsedRules` 应只统计匹配类别，令 `onEmpty(typeMismatchOnly=true)` 可达。

---

## A-031 `AllowRuleCache.reloadCustomRules` 仅按 pattern 保活订阅 special 规则：与自定义同 pattern 的订阅修饰规则在每次白名单编辑后被逐出活动缓存

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/AllowRuleCache.kt:142` — `val subSpecial = state.specialRules.filter { sub -> !result.specialRules.any { it.pattern == sub.pattern } }`（比较仅 `pattern`）
  - `core/rule/AllowRuleModels.kt:41-50` — `ExportedSpecialAllowRule` 字段：pattern/important/appScope/appInverted/isWildcard/denyallow/isRegex/dnsType，**无 `source`**；对照 block 侧 `BlockRuleModels.kt:59-69` 有 `source`
  - `core/rule/BlockRuleCache.kt:184` — 块侧孪生用 `state.specialRules.filter { it.source.startsWith("sub_") }`（来源判定，pattern 冲突不误删）
  - 触发面（每次单条白名单变更都会调用）：`core/rule/AllowListManager.kt:195-196`（`syncCachedPattern` → `cache.reloadCustomRules(dao)`）；调用方含 `ui/WhitelistViewModel.kt:479,551,553`、`ui/batch/BatchRuleValidator.kt:326`、`normal/DnsVpnRuleSyncManager.kt:56`
  - `AllowRuleCacheLoader.kt:193` — 全量 `load` 的 `specialRules = customResult.specialRules + subSpecialRules` 正常合并：被逐出的规则在下次全量 reload 自动恢复，缺陷仅存于 `reloadCustomRules` 增量路径
  - 消费点：`core/rule/AllowRuleMatcher.findInSpecialRules:168-212` ← `findAppMatch:31`/`findGlobalMatch:52` ← `DomainPolicyEngine.evaluateInternal:88,94`（Go 回调线程实际命中）
- **机制/影响**：自定义 special `||ex.com^$denyallow=ok.com` 与订阅 special `||ex.com^$app=com.foo` 同 pattern 不同修饰。用户改动任意白名单条目 → `reloadCustomRules` 重拉 custom special → 订阅 special 因 pattern 相同被过滤丢弃 → 该订阅规则的 `$app` 放行作用在快照/回调匹配中消失（其 denyallow/appScope 差异不被考虑），误拦依赖该例外的域名；直到下次全量 reload 才自愈。块侧以 `source` 判定不受影响——缺陷是该文件特有的近似复制。
- **触发路径**：订阅含 `||ex.com^$app=com.foo`（special）→ 手动添加 `||ex.com^$denyallow=ok.com` → 随便编辑另一条白名单 → com.foo 对 ex.com 的放行不再命中（`adb` 日志/快照 JSON 中 `specialAllow` 少一条）。
- **复现/验证**：单测：state 预置两条同 pattern 特殊规则（一 useradd 一 sub_），调 `reloadCustomRules`（loader 只返回 useradd 那条），断言 `state.specialRules` 仍含 sub 条目；当前实现删除。
- **备注**：修复方向：给 `ExportedSpecialAllowRule` 补 `source` 与块侧对齐（推荐），或去重键改全字段比较。

---

## A-032 Android 7.0/7.1（API 24/25）上配置/查看 AI 密钥必崩：`KeyObfuscator` 使用 `java.util.Base64`（API 26+）且未启用 core library desugaring

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/util/KeyObfuscator.kt:27`（`java.util.Base64.getEncoder()`）、`:33`（`getDecoder()`）
  - `Android/app/build.gradle.kts:79` — `minSdk = 24`；全文件及 `gradle/libs.versions.toml` 无 `coreLibraryDesugaringEnabled`/`desugar_jdk_libs`（grep 实证，plugins 仅 AGP+Compose+KSP）
  - 本机 SDK 取证：`%LOCALAPPDATA%/Android/Sdk/platforms/android-36.1/data/api-versions.xml` — `<class name="java/util/Base64" since="26"`
  - 异常传播：`:37` `catch (_: Exception)` 拦不住 `NoClassDefFoundError`（是 Error）；`seal` 无任何 try
  - 调用链：`ui/settings/AgentApiSettingsStore.kt:332`（`open`/revealApiKey）、`:336`（`seal`/sealApiKey）、`:359`+`performInitialMigration`（`:350`，迁移时 seal 非空明文旧键）；`ui/settings/AiProviderManageScreen.kt:212`（reveal）、`:252,263`（save→seal）
  - 可达性：`ui/mode/AppWorkMode.kt:25,34,43` — NORMAL/DNS 模式 `minApiLevel=29`，**EXPRESS=24**：API 24/25 设备唯一可用模式即 Express；`express/ui/ExpressMainScreen.kt:249` → `LogRouteActivity.kt:120` DNS_CACHE → `ui/DnsCacheScreen.kt:150` AI 分析入口无模式门槛 → `:272` `Routes.AGENT_API_SETTINGS` → `SettingsRouteActivity.kt:396-397` AI 设置/管理页
  - 内部先例（证明是失误而非平台要求）：`ui/settings/OutboundProxySettingsStore.kt:6,175,182` 同类需求用的正是 API 1 即有的 `android.util.Base64`
  - 测试遮蔽：`app/src/test/.../AiProviderTest.kt` 在 JVM 上跑 `seal/open`（桌面 JVM 有 `java.util.Base64`）恒绿
- **机制/影响**：`java.util.Base64` 在 API 24/25 运行时不存在，首次**真实调用**（非空密钥的 seal/open）抛 `NoClassDefFoundError` → 直达全局 `CrashHandler`（`crash/CrashHandler.kt` 处理 Throwable）→ 进程崩溃并留崩溃报告。空白输入短路（`:22,31`）只推迟不避免：用户「输入 API Key 并保存」或「点开显示已保存密钥」即触发。
- **触发路径**：Android 7 设备 → 启动（强制 Express 模式）→ DNS 缓存页 → AI 分析设置 → AI 供应商管理 → 填入任意 Key → 保存 → 应用崩溃。
- **复现/验证**：API 24/25 模拟器走上述路径必现；静态取证三件套已齐（`since=26` × `minSdk=24` × 无 desugaring）。修复任选：改用 `android.util.Base64`（对齐 OutboundProxySettingsStore，**注意** `android.util.Base64` 默认换行需 `NO_WRAP`），或开启 `coreLibraryDesugaring`。
- **备注**：修复后请给 JVM 单测加 `Base64` 类来源断言不可行（JVM 恒有），应以 Android Lint 规则/NewApi 检查防回归（该处本应被 lint `NewApi` 标出——检查 CI 是否关闭了 lint 或 `Kotlin/未标注 API level` 检测未覆盖 `util/`）。

---

## A-033 QS 磁贴的启停操作绕过设备认证：锁屏上可直接启停 VPN/DNS 服务，仅打开主界面路径做了锁检查

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:41-56` — `onClick()` 按当前工作模式直接分发 `toggleDnsService()`/`toggleExpressVpnService()`/`toggleVpnService()`，全程无 `isLocked`/`unlockAndRun`
  - 对照同文件 `:155-159`（`openMainActivity`）：`if (isLocked) { unlockAndRun(launchAction) } else { launchAction.run() }` —— 作者知道并实现了认证要求，toggle 路径遗漏
  - 启停实体：`:58-69`（`DnsModeManager.startService/stopService`）、`:71-105`（`:96-98` `ContextCompat.startForegroundService(this, DnsVpnService.startIntent(this))`，`VpnService.prepare` 已授权时直接拉起）、`:107-127`（Express 同型）
  - `toggleVpnService:85` 的 `VpnService.prepare(this)` 只防「首次系统授权」，已授权后锁屏直启；磁贴未设置 `Tile.isSecure`
- **机制/影响**：快捷设置面板默认在安全锁屏上可用（下拉两次即可达）。他人捡起锁屏手机即可：关闭 VPN（静默解除全部域名过滤/应用管控——家长控制场景直接失守）；或反向开启服务器模式 DNS 服务，把锁屏设备变成局域网 1053 DNS 服务器对外应答。操作本身应在解锁后才被允许，属可见的越权控制面。磁贴状态与真实状态一致性不是问题，问题是未经认证就能改变。
- **触发路径**：设置锁屏密码 → 锁屏 → 下拉打开快捷设置 → 点「谛听」磁贴 → VPN/服务直接切换（无需解锁）。
- **复现/验证**：真机两步即证；静态：`grep -n "unlockAndRun\|isLocked" tile/DitingTileService.kt` 仅命中 `openMainActivity`（`:155-156`）。
- **备注**：修复方向：三个 toggle 与 `onClick` 分发整体包进 `unlockAndRun`（锁屏时先认证再执行），或磁贴设 `isSecure=true`（API 29+）使点击直接跳解锁。Express/NORMAL/DNS 三模式同修。

---

## A-034 「规则导入与更新」通知渠道重复注册：注册表 channel 是幽灵（仅死代码引用），实际通知走 Worker 硬编码的另一个 id

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/notification/AppNotificationChannels.kt:18` `const val CHANNEL_RULE_OPERATIONS = "diting_rule_operations_channel"`；`:56-63` 创建该渠道（名称 `R.string.rule_update_channel`）；注册表由 `main/MainStartupCoordinator.kt:48` 每次启动调用
  - `core/rule/RuleOperationWorker.kt:566` `const val CHANNEL_ID = "rule_operations"`（另一个 id）；`:556-563` worker 自建同名渠道；`:141` 每次 `doWork` 调 `createNotificationChannel()`；实际通知全部发往 `"rule_operations"`（`:525`、`:536`）
  - 唯一引用注册表 id 的 `core/rule/RuleUpdateNotifier.kt:62` —— 该类全仓无实例化点（grep `RuleUpdateNotifier` 仅命中其声明 `:17`），死代码
  - 两条渠道共用同一显示名：`res/values/strings.xml:195` 「规则导入与更新」（注册表 `:58` 与 worker `:560` 都取这个串）
- **机制/影响**：系统「设置→应用→通知」里出现**两条同名**「规则导入与更新」渠道（id 不同、名字相同），用户无法分辨哪条真实生效。通知面板长按实际通知选「静音/不再显示此类通知」时按通知所属渠道静音——若用户从渠道列表操作，极易静音到幽灵渠道：规则导入通知照旧弹出且再也关不掉（以为已关），或反过来真实渠道被关而设置页显示「已关闭」的却是没在用的那条。渠道级偏好（声音/横幅/免打扰联动）永久分裂。
- **触发路径**：任一订阅更新（`RuleOperationScheduler.enqueue` → worker `:141` 自建渠道）+ 应用启动（注册表创建幽灵渠道）→ 打开系统通知设置可见两条同名渠道。
- **复现/验证**：静态 grep 上述四处即闭环；单测断言 `RuleOperationWorker` 的通知 channel id 与注册表一致（当前必失败）。修复：worker 改用 `AppNotificationChannels.CHANNEL_RULE_OPERATIONS` 并删除自建逻辑，或至少删除 `RuleUpdateNotifier` 死代码并把 worker 硬编码串并入注册表；注意旧 id 渠道在升级后需 `deleteNotificationChannel("rule_operations")` 清理，否则同名幽灵反转。
- **备注**：同文件其余四个渠道（VPN 服务/监控/订阅自动更新/应用更新）经查通知端均正确使用注册表常量，唯规则渠道分裂。

---

## A-035 通知栏自定义文案导入要求两条**都**非空才写入：只填一条（UI 明示合法）时该条也静默丢失

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/transfer/PreferenceConfigImporter.kt:115-117` — `if (sys.customRunningNotificationText != null && sys.customStoppedNotificationText != null) { setCustomTexts(...) }`
  - `ui/transfer/ConfigTransferParser.kt:331-332` — `obj.optString(..., "").takeIf { it.isNotEmpty() }`：文件里的**空串**被解析为 `null`
  - `ui/transfer/ConfigExporter.kt:332-333` — 两键无条件 `put`（空串照写）
  - 「空=用默认」是产品语义：`notification/NotificationSettingsStore.kt:59-71`（kdoc 明写 empty means default）；UI 承诺：`normal/ui/NotificationSettingsScreen.kt:146`、`express/ui/ExpressNotificationSettingsScreen.kt:138` 「两项内容均可留空；留空后对应通知栏会使用默认状态文案」
  - `NotificationSettingsStore.setCustomTexts`（`:76-81`）是两键一起写的原子接口（无单写入口），但导入器可以在 null 侧传 `""` 恢复默认
- **机制/影响**：用户按 UI 指引只填「运行文案」、停止留空 → 导出文件 `{"customRunningNotificationText":"我的DNS","customStoppedNotificationText":""}` → 解析后前者有值、后者 null → `&&` 判定整条不执行 → 换机/重装导入后**已填的文案也没恢复**（回到空/默认），且无任何提示。次生：想通过导入「清空某条文案」永远不可能（清空=空串=null=跳过写入）。与同文件兄弟字段的正确写法对照：`sys.*?.let { ... }` 逐字段可空跳过（`:101-114`），唯独这两条文案被捆成对。
- **触发路径**：通知设置→只填运行文案→确定→导出配置→（重装/新机）导入→回通知设置：两条均为空；比对导出 JSON 可见文案明明在文件里。
- **复现/验证**：JVM 单测：DTO 置 `customRunning="X", customStopped=null`，调导入，断言 `getCustomRunningText` == "X"（当前实现返回 ""）。修复：逐字段写入（null 侧传当前本地值或空串恢复默认），解析端区分「键缺失」与「空串」。
- **备注**：修复时注意与 `takeIf{isNotEmpty()}` 的缺省语义联动：若要支持「导入清空」，解析应改 `if (obj.has(...)) obj.getString(...) else null`（键在即取值，空串合法）。

---

## A-036 Android 7.x 上「系统通知权限」入口点击无反应：`ACTION_APP_NOTIFICATION_SETTINGS`（API 26+）缺失且异常被 `runCatching` 吞掉

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/notification/NotificationPermissionHelper.kt:34-40` — `Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)` + `putExtra(Settings.EXTRA_APP_PACKAGE, ...)` + `runCatching { context.startActivity(intent) }`（无成功判定、无回退）
  - SDK 取证：`api-versions.xml`（android-36.1）`ACTION_APP_NOTIFICATION_SETTINGS since=26`、`EXTRA_APP_PACKAGE since=26`（本次复核本机文件确认）
  - 可达性：`ui/mode/AppWorkMode.kt:43` EXPRESS `minApiLevel = 24`，`build.gradle.kts:79` `minSdk = 24` —— API 24/25 设备唯一可用模式（Express）的设置页就有该入口：`express/ui/ExpressNotificationSettingsScreen.kt:149`；NORMAL 侧 `normal/ui/NotificationSettingsScreen.kt:157`（该模式 minSdk 29 不触发，但共用同一 helper）
- **机制/影响**：Android 7.0/7.1 系统无 Activity 响应此 action → `ActivityNotFoundException`（属 Exception）→ `runCatching` 静默吞掉 → 点击「系统通知权限」毫无反应：不跳转、不报错。用户被告知前往系统设置管理通知（副标题文案）却找不到路，且无任何提示该设备不支持跳转；`hasPermission`（`:20-28`）在 <33 恒真显示「已授予」，入口仍渲染可点。
- **触发路径**：Android 7.x 真机/模拟器（API 24–25）→ 极速模式 → 通知设置 → 点「系统通知权限」→ 无响应。
- **复现/验证**：真机即现；Robolectric：SDK=25 下调用后断言 `shadowOf(context).getNextStartedActivity() == null`（startActivity 抛出）且无 toast/回退。修复方向：`SDK_INT >= O` 走原 intent，否则回退 `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`（API 1+，`Uri.fromParts("package", pkg, null)`），或 <26 直接隐藏该入口。
- **备注**：与 A-032 同属「Express 模式把 minSdk 24 设备带进只在 API 26+ 成立的假设」一族，修复时建议对 Express 可达面做一次 NewApi 全扫。

---

## A-037 磁贴标签、监控常驻通知与规则/更新渠道名跟随**系统**语言，同屏其它文本走应用内语言：中英混杂

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/tile/DitingTileService.kt:165` `tile.label = getString(R.string.quick_settings_tile_label)` vs 紧邻 `:166` `val stateText = localizedText(this, if (running) "已开启" else "已关闭")` —— 同一函数两种语言源
  - `notification/VpnMonitorService.kt:119,124,127` — `getString(R.string.vpn_disconnected / app_name / vpn_start)`（标题、正文、按钮三处）
  - `notification/AppNotificationChannels.kt:58,78` — `context.getString(R.string.rule_update_channel / app_update_channel)` 而同一注册表其余渠道（`:34,37,46,49,61,68,71,81`）用 `localizedText(context, ...)`
  - 语言源分叉的根：应用内语言独立于系统（`ui/AppLanguageManager.kt:22-36` 存 `dns_vpn_prefs`，`wrap()` `:38-50` 造 wrapper context）；`localizedText(context, …)`（`ui/LocalizedTextHelper.kt:28-35`）经 wrap 生效，而 Service/TileService 未包装 base context，`getString` 直接读系统 locale
  - 双语资源真实存在：`res/values/strings.xml:3` 「谛听」/`res/values-en/strings.xml:4` "DITING"；`rule_update_channel` 中文「规则导入与更新」/英文 "Rule import and updates"（`:195/:196`）
  - 正确先例：同为 Service 的 `server/backend/DnsModeService.kt:273-286,297-300` 全部用 `localizedText(this, ...)`；`core/rule/RuleOperationWorker.kt:560` 恰又用裸 `getString`（同文件内不一）
- **机制/影响**：用户在应用内把语言设为 English（系统仍 zh-CN）后：QS 磁贴一行内标签「谛听」（应 DITING）+ 副标题「已开启」被译成英文——中英混杂；VPN 停止时的常驻监控通知整条中文（标题应用名、正文「未连接」、按钮「开启」），与其下方应用内生成的其它通知语言不一致；系统通知设置里「规则导入与更新」「应用更新」两条渠道名不随应用语言切换。
- **触发路径**：设置→语言→English（保持系统中文）→ 下拉看磁贴；停止 VPN 看监控通知；打开系统通知渠道列表。
- **复现/验证**：静态即证（同函数混用两种 API）；真机改语言后磁贴 label 仍「谛听」而 subtitle 为 "On"/"Off" 对应译文。修复方向：Service/Tile 侧统一 `localizedText(context, ...)` 或 `AppLanguageManager.wrap(this).getString(...)`；渠道名注意仅创建时生效，修复后对已存在渠道无效（需版本化渠道 id 或接受旧装机不刷新）。
- **备注**：注意 `AppLanguageManager.wrap` 在 SYSTEM 模式下把非中文系统 locale 归一为 ENGLISH（`:39-46`），对显式系统跟随场景与资源限定符行为等价，不构成额外偏差。

---

## A-038 订阅暂存规则 `staging_sub_*` 不被任何「排除订阅」查询识别：更新窗口内暂存规则以「手动规则」身份显示、计数并可被「清空手动」误删

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/SubscriptionRuleStorage.kt:35` — `stagingSourceTag(id) = "staging_sub_$id"`
  - `core/rule/SubscriptionDownloader.kt:136-138,190-199` — 下载即向全部规则表插入 `source = staging_sub_<id>`、`enabled = subscription.enabled` 的行，整个导入窗口（大列表数十秒~分钟）存在
  - 识别谓词全部只看前缀 `sub_`：`data/dao/BlockRuleDao.kt:201`（`enabledCustomRules NOT LIKE 'sub_%'`）、`:362-375`（`userRulesPaged/userRulesCount`）、`:426`（`deleteUserSources: DELETE … WHERE source NOT LIKE 'sub_%'`）；`AllowRuleDao.kt:187,370`；`RewriteRuleDao.kt:33`（`NOT GLOB 'sub_*'` → `RewriteRuleManager.kt:28` `manualRules`）——SQLite `_` 是单字符通配但 `sub_` 必须从串首匹配，`"staging_sub_5"` 不匹配 `LIKE 'sub_%'` → 被归为**非订阅**
  - 消费面：`ui/BlacklistViewModel.kt:106,191,257`（「手动添加」页签与统计）、`:480-483` `clearUserBlacklist()`、`WhitelistViewModel.kt` 同型、`core/rule/BlockRuleCacheLoader.kt:199`/`AllowRuleCacheLoader.kt:197`（`enabledCustomRules` 进自定义桶 → Go 快照/回调）、`ui/BlocklistViewModel.kt:232`（`!source.startsWith("sub_")` 判「用户规则」徽章）
  - 删除执行者：`BlockRuleDao.kt:426-431`（`deleteUserRules` → `deleteUserSources`）——在途 `staging_sub_*` 行连 `block_rule_source` 带 `block_rule` 一起删
- **机制/影响**：任一次订阅更新（手动「更新」或后台自动更新，`SubscriptionAutoUpdateEngine` 亦走 staging）期间：
  1. 黑名单「手动添加」页签与「手动 N 条」统计混入数千条订阅规则（正常模式下这些行还会进 custom 桶参与匹配——好在 staging 与 sub_ 内容相同，行为暂时无差，但身份/展示全错）；
  2. 用户此刻点「清空手动屏蔽规则」→ staging 行被删 → 更新继续走 `publishStagedRules`（`SubscriptionRuleStorage.kt:65-83`，promote 剩余行）并 `ruleCount = summary.importedCount`（`SubscriptionManager.kt:475` 报告导入前计数）→ **订阅静默缺规则、计数虚报，无任何错误**；
  3. 更新结束后 staging 清空，症状消失——用户只看到「规则莫名少了」。
- **触发路径**：添加大订阅（数万条）→ 点「更新」→ 更新进行中打开黑名单→筛选「手动添加」→ 可见成排订阅规则；点「清空手动规则」→ 等待更新完成 → 订阅卡片仍显示旧 ruleCount，实际生效规则缺失。
- **复现/验证**：Robolectric：`insert(source="staging_sub_1")` 后 `userRulesCount()` 应 0、现 ≥1；或导入中途调 `deleteUserRules()` 后断言 staging 行数下降。
- **备注**：根治在 SQL：判定应排除 `sub_%` **与** `staging_sub_%`（两 DAO 家族 6+ 处谓词逐一同步），或改 staging 命名为 `sub_staging_<id>` 使既有前缀谓词天然覆盖（推荐，改动面最小）。A-030 的 `kind` 缺陷与本条独立。

---

## A-039 崩溃恢复只清 5 张表中的 3 张，`deleteSubscription` 又从不触 staging：半导入订阅的 URL/元素隐藏规则永久生效，订阅删除后成无主孤儿

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/rule/SubscriptionImportRecovery.kt:17-28` — `recoverInterruptedImports` 仅 `blockRuleDao/allowRuleDao/rewriteRuleDao.deleteBySource(stagingSource)`；同函数初始导入分支（`:25-28`）同样只删三表；`RuleDataSources` 明明暴露 `goUrlRuleDao()/cosmeticRuleDao()`（调用点 `SubscriptionManager.kt:45-46,53-54` 证明可得）
  - 对照正常失败路径清理**五表**：`SubscriptionRuleStorage.kt:38-44` `removeRulesBySource`（含 `goUrlRuleDao?.deleteBySource` / `cosmeticRuleDao?.deleteBySource`）——作者知道完整集合，恢复路径漏两张
  - staging 确实写这两表：`CategorizedRuleStreamImporter`（urlBlock/cosmetic 类别无条件收集，见 A-030）以 `source = staging_sub_<id>` 入 `go_url_rule_source`/`cosmetic_rule_source`
  - 生效通道不看 source 前缀：`GoUrlRuleDao.enabledRules()`（`WHERE r.enabled=1 AND s.enabled=1`，任意 source）→ `GoUrlRuleManager.jsonSnapshot()` → `engine.setRequestRules`（`normal/GoTunnelRuleManager.kt:104-110`）；`CosmeticRuleDao.enabledRules()` → `CosmeticRuleManager.compileScopedCss()`（`:77`）
  - `SubscriptionManager.kt:521-526` `deleteSubscription` → 仅 `removeSubscriptionRules(id)` = `removeRulesBySource("sub_$id")`——**从不**清 `staging_sub_$id`；删除后行消失，恢复器 `importing()` 再也看不到它，staging 行永久残留（且按 A-038 还以「手动规则」身份出现在列表）
- **机制/影响**：更新中途进程死亡（崩溃/重启/划掉，WorkManager 停止）→ `importState=IMPORTING` 残留 + 部分行落库。下次任何规则操作触发恢复（`RuleOperationWorker.kt:192`、`SubscriptionAutoUpdateEngine.kt:69/147`）：block/allow/rewrite 被清，**goUrl/cosmetic 的 staging 行 enabled=1 存活并立即参与 HTTPS 拦截**——订阅卡片还显示旧 ruleCount/「保留原有规则」，实际半个残包在生效。若用户随后删除该订阅：恢复器无从触发（订阅行没了），staging 残留成无主孤儿——URL/隐藏规则持续生效，UI 显示为「手动」，普通用户无从按订阅清理。
- **触发路径**：大订阅开自动更新 → 导入中途强杀应用 → 重启 → 更新另一订阅（触发恢复）→ `SELECT count(*) FROM go_url_rule_source WHERE source LIKE 'staging_sub_%'` >0 且 HTTPS 检查命中半包规则；再删除原订阅 → 残留永久。
- **复现/验证**：单测：预置 IMPORTING 订阅 + goUrl/cosmetic staging 行，跑 `recoverInterruptedImports`，断言五表 staging 全清（当前两表不清）。修复：恢复器补齐两 DAO 删除（与非初始导入分支同样处理 sub_ 前缀），`deleteSubscription` 改调 `removeRulesBySource(stagingSourceTag)` 一并清。
- **备注**：与 A-038 是同族（staging 生命周期治理），但触发面、代码位置、后果都独立。

---

## A-040 Express start↔stop 竞态：`stop()` 关闭 pfd 却不取消 start 协程，`FileInputStream` 在已关 fd 上重建、`isRunning` 复活，读线程一次 EBADF 即永久退出而 `start()` 返回 true → UI 报运行、DNS 全黑洞

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressVpnService.kt:99`（`establishVpnInterface` 拿 pfd）→ `:110-122`（`serviceScope.launch` 调挂起 `tunnelManager.start(service, pfd, …)`）；`:40` `serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)`——**不随协程树取消**，仅 `:214` onDestroy `serviceScope.cancel()`
  - `:188-197` `stopVpn()`：`ExpressVpnController.onServiceStateChanged(false)` → `tunnelManager.stop()` → `stopSelf()`；**不取消 start 协程、不置任何 start 侧可见标志**
  - `express/ExpressTunnelManager.kt:301-309`：挂起窗口（规则加载）后仅 `currentCoroutineContext().ensureActive()`——协程未被取消即放行（stopVpn 从不取消它）
  - `:364-368`：`FileInputStream(pfd.fileDescriptor)` 包**刚被 stop() 关闭的同一 fd**（`:493-512` `stop()`：`inputStream?.close()`/`vpnInterface?.close()`——两者是同一 fd），随后 `isRunning = true` 复活 stop 刚置的 false
  - `:395-403`：读线程 `while(isRunning){ inStream.read … catch(_:Exception){ break } }`——对 EBADF 读一次即 break，线程静默死亡，无 supervisor/重试
  - 回到 Service `:123`：`start()` 照常**返回 true**（它不知道 stop 发生过）→ `:132-135` `updateForegroundNotification()/floatingLogOverlay.setVpnRunning(true)/VpnMonitorManager.onVpnStarted/ExpressVpnController.onServiceStateChanged(true)`——在 stopVpn 已广播 false **之后**把 UI 翻回运行
- **两个失败窗口**（都经源码确认）：
  1. stop 落在挂起窗口（`:301-307` 规则加载 / 首启 `defaultsSeedJob.join()`）：如上，重开已关 fd → 读线程瞬死 → 「运行中 + 零响应」。
  2. stop 落在 `:368` 之后：stop 把 `inputStream/outputStream/vpnInterface` 置 null 并 close——`FileInputStream.close()` 关闭**底层 fd**（不依赖 finalizer；ParcelFileDescriptor 非 auto-close，fd 归 PFD 所有），所以读线程拿到异常 break、`writePacket`（`:457-464`）见 null 静默丢——同样黑洞，且 `isRunning` 停在 false 与 UI 的 true 分裂。
- **反证检查（为何现场不炸）**：Express 是 minSdk 24/25 设备唯一模式，用户基数小；窗口需「启动后秒级内停止」——通知栏快速连点电源键/模式切换/`onRevoke` 都能给；START_STICKY 重启走 ACTION_STOP 分支？不：重启 intent 为 null（`:66` 直接 return START_STICKY），黑洞持续到用户手动停一次再开（第二次 start 的 `if (isRunning) stop()` `:265-267` 此时 isRunning=false 不再伤新 fd）。全部不矛盾。
- **用户可见影响**：极速模式显示「已开启」（通知/主页/磁贴三处一致为运行），实际所有 DNS 查询无人应答 → 断网假象；用户反复开关才自愈。
- **触发路径**：Express 首启（种子化+规则加载数秒）→ 立即下拉通知点「停止」→ 再开再停复现。或：规则多时每次开机自动拉起后手动秒停。
- **复现/验证**：Instrumentation 测试：start 后 100ms 发 ACTION_STOP，断言 `ExpressVpnController.isRunning.value`（期望 false）实际 true 且 tunThread 已死。修复方向：stopVpn 取消专属 startJob（或 `serviceScope.coroutineContext` 内建 stop 检查点）；`start()` 内每次重资源前校验 `stopGeneration`；读线程 break 后回报服务置停止。
- **备注**：`ensureActive()` 的注释（`:308`「A stop during the rule load must not be undone」）证明作者意图正是防这个，但选择了取消语义而 stop 从不取消——修复只需 stopVpn 持有并 cancel startJob，与注释意图一致。O-104（normal 模式同类微窗口）不重复。

---

## A-041 `TunnelDiagnosticsResolver.tunnelResolver` 从无赋值点：「通过 Go 隧道解析」的 DNS 查询/Ping/Traceroute 在 VPN 运行时也恒报「VPN 未运行」（`58ca123` 重构回归）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/diagnostic/TunnelDiagnosticsResolver.kt:13`（`@Volatile var tunnelResolver … = null` 声明）与 `:40`（`val json = tunnelResolver?.invoke(…) ?: return null` 唯一读取）——**全仓 grep `tunnelResolver` 仅此两处，无任何赋值**
  - `git show 58ca123`：重构把原 `DnsVpnService.resolveThroughTunnel(domain, preferIpv4)` 直调改成钩子，但没有在任何 `onCreate/init/Application` 补接线；`normal/DnsVpnService.kt:557` `resolveThroughTunnel` 现为**零调用**孤儿
  - 消费链：`ui/NetworkToolsViewModel.kt:211`（DNS 查询 viaTunnel→resolve() null→`:217` 提示「VPN 未运行，无法通过 Go 隧道解析」）、`:301-302` `resolveTargetForProbe`→`TunnelProbeResolution.Failed("VPN 未运行…")`→ `runPing:180-184`、`runTraceRoute:277-281` 中止
  - 开关持久化 ON 则跨重启保持（`ui/settings/NetworkToolsSettingsStore.kt:25-31`，默认 false——用户手动开启后受害）
- **机制/影响**：钩子恒 null → `resolve()` 恒 null → 三个诊断工具的「经隧道」路径 100% 失败，文案还指向错误原因（VPN 明明在跑）。非隧道路径不受影响。用户结论只能是「这功能坏了」。
- **触发路径**：网络工具→打开「通过 Go 隧道解析」→ 启动 VPN → 域名目标 Ping/追踪/DNS 查询 → 恒「VPN 未运行」。
- **复现/验证**：静态 grep 即闭环；修复 = 在 `DnsVpnService` 启动路径赋值 `tunnelResolver = { d, v -> resolveThroughTunnel(d, v) }` 并停机时置 null，或干脆恢复直调。
- **备注**：属「重构引入的死功能」——`58ca123` 提交本意是解耦，缺了半个接线。同时 `Result.errorLabel()` 的 `"tunnel resolver not active"` 分支（`:32-35`）也从不可达，可一并复核语义。

---

## A-042 `DnsLatencyTester.testDoh` 的 `toHttpUrl()` 在 try 之外：过校验的畸形 DoH URL 测速 → 未捕获异常直接杀进程

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/dns/DnsLatencyTester.kt:118` — `val httpUrl = provider.url.toHttpUrl()`（okhttp 对非完整 http(s) URL 抛 `IllegalArgumentException`），而 `return try {` 在 `:149`——**构造期抛错落在 catch(`:169`) 之外**
  - 校验放行了非完整 URL：`core/dns/DnsProvider.kt:339-342` `isValidDohUrl = trimmed.startsWith("https://")` 前缀匹配；`https://dns alidns.com/dns-query`（空格）、`https:///x`（空 host）、`https://a.dns:99999/`（非法端口）均过校验并被持久化（调用点 `ui/ProviderManagementViewModel.kt:165`、`ui/ProviderManagementScreen.kt:182,204`、导入路径 `ui/transfer/ConfigTransferParser.kt:46` 同）
  - 逃逸路径：`test():61`/`testAverage():83`（`(1..n).map{ test(…) }` 无 runCatching）→ `ui/RaceModeSettingsViewModel.kt:276-290` `viewModelScope.launch(Dispatchers.IO){ async … deferreds.map{await()} }` 无 try——`async` 的失败经 await 抛出，`Dispatchers.IO` 协程未捕获异常 → 默认 handler → 进程崩溃
- **机制/影响**：用户输入带空格的 DoH 地址（复制粘贴常见）保存成功 → 测速/竞速页点测速 → **App 直接闪退**；同文件其余错误路径全部刻意降级为 `Result(success=false)`（`:169-178`），唯 `:118` 破功。
- **触发路径**：供应商管理→添加 DoH→`https://a b/dns-query`→保存→测速设置选它→开始测速。
- **复现/验证**：JVM 单测：`runCatching { testDoh(provider with url="https://a b/c", …) }` 现抛 `IllegalArgumentException`，期望返回失败 Result。修复：`toHttpUrlOrNull()` + 失败 Result，或并入 try。
- **备注**：`testDot/testPlainDns` 不用 toHttpUrl 不受影响；但同样的前缀校验还喂给别处（如 bootstrap），修复时顺带审。

---

## A-043 `isIpLiteral` 把任何含冒号串当 IP 字面量放行，`InetAddress.getByName("8.8.8.8:53")` 无保护调用 → 崩溃；`1.2.3.4:80` 更被当字面量答案误报解析成功

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/dns/DnsProvider.kt:373-381` — `if (trimmed.contains(":")) return true`（IPv6 判定被写成「有冒号就是 IP」，`::1`、`fe80::`、`http://`、`8.8.8.8:53` 一律 true）
  - 崩溃消费点：`ui/NetworkToolsViewModel.kt:239-246` `DnsServerMode.CUSTOM` 分支——`!isIpLiteral` 即拒；通过后 `listOf(InetAddress.getByName(customServer))` **裸调用**（`viewModelScope.launch(Dispatchers.IO)` `:204`，无 runCatching；同函数另一分支 `:231` 反而 `runCatching` 包了 getByName——不对称即意图证据）
  - 误报消费点：`core/dns/DnsLookupTool.kt:58-72` 查询名先过 `isIpLiteral` → `1.2.3.4:80` 被直接当答案返回 `success=true, value="1.2.3.4:80"`
- **机制/影响**：用户在 DNS 查询工具自定义服务器粘 `8.8.8.8:53`（带端口是极常见直觉）→ `UnknownHostException` 未捕获 → 进程崩溃；查 `1.2.3.4:80` 显示解析成功且值离谱。`18319ed` 修的是 Go 侧 provider 地址端口拒绝，Kotlin 侧此路没动。
- **触发路径**：网络工具→DNS 查询→服务器选「自定义」→输入 `8.8.8.8:53`→点查询。
- **复现/验证**：JVM：`isIpLiteral("8.8.8.8:53")` 现 true（期望 false）；`InetAddress.getByName("8.8.8.8:53")` 抛 `UnknownHostException`。修复：字面量判定改真解析（`android-text.util`/`InetAddress.getAllByName` 对纯字面量不触网可 try 包），或至少显式拒绝带端口形态并给提示。
- **备注**：修一处谓词全链受益（`isValidDnsHost/isValidDotHost` 也用它）。

---

## A-044 `DnsResponseCache.clear()` 与 30 秒批量 flush 交错：drain 后、DAO 写库前执行 clearAll → 「已清空」的缓存行复活并继续显示为缓存

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/cache/DnsResponseCache.kt:118-122` — `clear() = clearMemory(); clearPendingWrites(); dao.clearAll()`（只能撤**还在队列里**的）
  - `:300-308` — `flushPendingWrites`：`pendingWriteMutex.withLock{ 快照并清空两个 map }` 后**在锁外** `dao.applyPendingWrites(writes, hits)`；`:291-296` `markPendingLocked` 排 30s `WRITE_FLUSH_DELAY_MS` 尾随 flush
  - `applyPendingWrites` 是 `insertIfAbsent/updateMetadata` 语义（恢复重放分支 `:308-315` 亦证明写入会复活行）
  - 消费点：`data/cleanup/DataCleanupManager.kt:93`（「清空 DNS 缓存」按钮）→ `DnsCacheController.clearAll`
- **机制/影响**：flush 协程已 drain（队列空）正跑 Room 事务时，用户点清空：`clearPendingWrites()` 无事可清 → `dao.clearAll()` 先完成或后完成均无排序保证 → 并发 `applyPendingWrites` 把最多 `WRITE_BATCH_SIZE=200` 行重新写回 → 缓存页刷新后条目复活，且这些行仍带旧 expiresAt 继续算「有效缓存」。`18319ed` 修的是队列未 drain 场景，本 in-flight 窗口未覆盖。
- **触发路径**：批量解析制造几十条缓存 → 等 30s flush 定时器触发瞬间（大 WAL 写耗时）点「清空 DNS 缓存」→ 条目仍在。
- **复现/验证**：现有 `FakeDnsCacheDao` 测试基建：让 `applyPendingWrites` drain 后挂起等信号 → 并发调 `clear()` → 断言表非空（当前实现）；修复 = `clear()` 与 flush 共享一把写锁（仿 `DnsLogger.writeMutex` `:172-183` 的正确形状）。

---

## A-045 DNS 测速把 bootstrap/系统域名解析计时进窗口（DoT/DoH/Plain 三路径同犯）：未预热上游被系统性冤枉「慢数百 ms~秒」，竞速选优被误导

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/dns/DnsLatencyTester.kt:186-193`（testDot：`start` 后才 `bootstrapSelector.resolveHost(provider.host)`）、`:148-155`（testDoh 同型）、`:220-230`（testPlainDns：`bootstrapSelector?.resolveHost ?: InetAddress.getAllByName(provider.host)` 在 start 后）
  - `core/dns/BootstrapSelector.kt:161-163` — 每次尝试 3s 超时×多回退、主机名缓存 60s：attempt1 背解析成本、attempt2/3 不背 → `testAverage`（`DnsLatencyTester.kt:82-102`）平均**基线不一致**的样本
  - 消费：`ui/RaceModeSettingsViewModel.kt:291-296` 按 elapsedMs 排序展示并指导用户选竞速集合；类文档（`DnsLatencyTester.kt:22-29`）承诺测的是「发送单条 A 查询的往返时间」
- **机制/影响**：域名形态上游（`doh.dns.sb`、`dns.alidns.com`）首测必然包含一次公网域名解析（数十 ms ~ 3s），与 IP 直连上游同屏比较时恒被排到「慢」端——用户按测速结果换掉实际更快的上游；`resolveHost` 失败还把 bootstrap 错误记成该上游的错误消息。
- **触发路径**：竞速设置里同时选 `1.2.3.4`（IP 上游）与 `dns.alidns.com`（域名 DoH）测速，清冷启动后第一组对比。
- **复现/验证**：单测注入 sleep 1s 的 fake `BootstrapSelector` 对秒回 DoT：`elapsedMs ≥ 1000`（当前实现）；修复 = 解析提到 `start` 之前（预热语义）并在失败时单列原因。

---

## A-046 `RaceLogger/HttpRequestLogger` 批量 DAO 插入无 runCatching（同族 DnsLogger 刻意包了）：磁盘满即未捕获崩溃，停机 flush 链还把后续日志/流量统计一起带崩

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/core/log/RaceLogger.kt:132-138` — `flushLocked()` 裸 `dao.insertAll(batch)`（对比 `core/log/DnsLogger.kt:116-131` 两处 `runCatching{ insertAll }`——同需求不同防护，意图证据）
  - `core/log/HttpRequestLogger.kt:100` 同型裸插入
  - 崩溃面：`normal/GoInspectionTunnel.kt:286-292` `scope.launch{ raceLogger.log(...) }` 跑在**服务作用域**（`normal/DnsVpnService.kt:47` `SupervisorJob+Dispatchers.IO`，无 handler）→ Room 抛（`SQLITE_FULL`/DB 损坏）→ 未捕获 → 进程杀
  - 停机链：`normal/DnsVpnDatabaseComponents.kt:147-163` `flushLoggers` 顺序 `raceLogger.flush()`（`:158`）→ `bootstrapLogger.flush()`（`:161`）→ `TrafficStatsManager.flush()`（`:163`），第一步抛则后两步不执行；调用点 `stopVpn()/onDestroy`（`DnsVpnService.kt:380,407`）——**每次停止丢一批竞速日志+bootstrap 日志+本会话流量统计**
- **机制/影响**：数据分区写满（DNS 日志本身能写满它——讽刺但真实）后：VPN 运行中随机崩；每次停止静默丢日志与流量数据。用户表现：流量排行莫名缩水、应用频繁重启。
- **触发路径**：填满 /data（或 `adb shell` 把 DB 设只读模拟 SQLITE_CORRUPT）→ 正常跑竞速解析 → 崩；或停止 VPN → logcat 见 flush 异常、重启后流量页缺口。
- **复现/验证**：单测：fake DAO 抛 `SQLiteFullException`，断言 `flushLoggers` 后 bootstrapLogger/TrafficStats 仍被 flush（当前不执行）。修复：两处 insertAll 包 runCatching（对齐 DnsLogger）+ flushLoggers 各步独立 runCatching。

---

## A-047 应用更新下载进度仅按 256KB 字节节流、无时间下限：快网下每 5–50ms 一次主线程回调 + `NotificationManager.notify`，通知风暴/掉帧

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:89-95` — `reportProgress` 判据 `downloadedBytes - lastReportedBytes >= PROGRESS_UPDATE_BYTES`（`:169` = 256KB），无「距上次上报 ≥N ms」维度；读循环每 chunk 调（`:97-111`）
  - `update/AppUpdateHost.kt:82-98` — 回调体 `activity.runOnUiThread { state = state.copy(…) ; notifier.showProgress(…) }` → `update/AppUpdateNotifier.kt:28` `notificationManager.notify` 每次一条系统 IPC + Compose 全对象重组
  - 50MB/s ≈ 每 5ms 一次（~195 次/s）；10MB/s ≈ 40 次/s；且 `SettingsRouteActivity` 路径（`:153`）触发下载后 `onStop` 不取消，回前台照打
- **机制/影响**：下载期间主线程被高频 binder call/重组挤占 → 界面掉帧、发热；OEM 通知限流导致进度条跳变/通知被静默丢弃的次生怪象。属性能/稳定性缺陷（用户可感知）。
- **触发路径**：Wi-Fi 快网，设置→检查更新→下载。
- **复现/验证**：logcat 统计下载窗口 `NotificationManager.notify` 频次（当前 ≈ 速度/256KB；修复后 ≈ 1/s）。修复 = 加 `&& now - lastReportedAt >= 1000`（或双条件取严）。
- **备注**：与 A-013（清理目录错位）同文件域但不同缺陷。

---

## A-048 Express 的前后台状态只在服务运行时下发：服务停止期所有 Activity onStart/onStop 被丢弃，悬浮球偏好陈旧 → 「该显示不显示」或「盖在自己 UI 上」

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/express/ExpressVpnController.kt:150-155` — `updateFloatingLogAppState`：`if (isRunning(context)) { startService(…) }` ——**不运行即整条丢弃**
  - 唯一写偏好点在服务侧：`express/ExpressVpnService.kt:74-77`（ACTION_FLOATING_LOG_APP_STATE → `setMainActivityForeground`）；全仓 grep `setMainActivityForeground` 无 Activity 侧直写（`normal/DnsVpnService.kt:525-533`、`core/WorkModeLifecycleRegistry.kt:43-52`、本条服务分支）
  - 对照 NORMAL 孪生路径**先无条件写偏好再判运行**：`normal/DnsVpnService.kt:525-526`——不对称即 bug 证据
  - 陈旧偏好消费者：`ui/floating/FloatingLogOverlayController.kt:62` — `appInForeground` 在**构造时**读 `isMainActivityForeground`（默认 true，`ui/settings/SystemSettingsStore.kt:84-87`）；`:141` `if (!vpnRunning || appInForeground || …) removeWindow()`
  - 分发方：`MainActivity.kt:214/232`、`LogRouteActivity.kt:68/77`、`SettingsRouteActivity.kt:183/196`（ON_START/ON_STOP）；服务构造点 `ExpressVpnService.kt:54`
  - 产品承诺：`ui/LogRetentionSettingsScreen.kt:183-188`「VPN 运行且应用在后台时显示悬浮球，回到应用前台时悬浮窗会自动隐藏」
- **机制/影响**（两症状）：
  1. 用户离开应用（onStop→false **被丢**，偏好停在上次运行期的 true 或默认 true）→ 从磁贴启 Express（无 Activity 经历 onStart）→ 服务构造 controller `appInForeground=true` → 永隐藏，悬浮球不出现直至进出一次应用；
  2. 反相：最后一次运行中后台过（偏好=false），停止 Express，期间进出应用（true 被丢，偏好仍 false）→ 应用内启 Express → controller 以 `appInForeground=false` 构造 → 悬浮球直接叠在当前页面之上，违背承诺文案。
- **触发路径**：上述两步序。
- **复现/验证**：静态：grep 写偏好仅服务分支 + Express 分发门控；真机按序两步。修复 = `updateFloatingLogAppState` 对齐 NORMAL：先 `setMainActivityForeground`，再按运行态决定是否 startService；controller 构造读偏好处亦可改实时查 Activity 生命周期更稳。

---

## A-049 日志仪表盘把「被防火墙拦截的连接」标成「旁路」：`resultLabel = if (isConn) "旁路"` 完全忽略 `result==BLOCKED`，红色拦截配「旁路」字样

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/ModernLogDashboardViewModel.kt:293-296`（isConn：`queryType==0 || "TCP "/"UDP " 前缀 || blocked_by=connection`）与 `:322` — `resultLabel = if (isConn) "旁路" else resultLabel(log.result)`（`status` 字段 `:318-321` 正确算出 blocked，**label 不看它**）
  - 生产者：Go `tunnel/engine_connection_log.go:102-105` 对拦截连接 `notifyLog("TCP ip:port", blocked=true, queryType=0, …)` → `normal/GoTunnelLogProcessor.kt:33`（t=0）`:43-47`（blocked→LogResult.BLOCKED）入库
  - 渲染：`ui/dashboard/ModernLogDashboardComponents.kt:349-365` — `tagColor` 按 status 取红色 error，`tag = localizedText(item.resultLabel)` → **红点+「旁路」**
  - 两处正确孪生证明意图：`ui/floating/FloatingLogMapper.kt:42-43`（`拦截/直连` 分流）、`ui/RequestLogItem.kt:47-51`（同）；仪表盘自身 SQL 也把 firewall 行排除出旁路桶：`data/repository/RequestLogRepository.kt:69`（`NOT LIKE '%blocked_by=firewall:%'`）
- **机制/影响**：禁止联网/加密 DNS 拦截触发一条连接日志后，主仪表盘（NORMAL/EXPRESS 共用本 VM：`express/ui/ExpressLogDashboardScreen.kt:57-60`）显示成「红色·旁路」——向用户**断言**该连接被放行，实际被拦死；同一条日志在请求日志页显示「TCP拦截」，两页互相矛盾。安全语义误导。
- **触发路径**：开禁止联网含某应用 → 该应用发起 TCP → 看主页仪表盘最近请求。
- **复现/验证**：单测 mapper：输入 blocked+queryType=0，期望 label 走 blocked 文案（当前恒「旁路」）。修复 = `resultLabel = if (isConn && log.result != BLOCKED) "旁路" else resultLabel(log.result)` 或按 FloatingLogMapper 的 `proto+拦截/直连` 拆法对齐。

---

## A-050 悬浮窗 `TYPE_APPLICATION_OVERLAY`（API 26+）硬编码且无 SDK 回退：Android 7.x（Express 唯一模式设备）addView 必抛 → 悬浮日志永久失效+失败 toast 循环

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/floating/FloatingLogOverlayController.kt:297-301` — `WindowManager.LayoutParams(..., TYPE_APPLICATION_OVERLAY, ...)` 常量直用；`:172-178` `runCatching{ windowManager.addView(…) }.onFailure { 置 null + toast「悬浮窗日志启动失败」 }`
  - 全仓 grep `TYPE_APPLICATION_OVERLAY` 仅此一处，`TYPE_PHONE` 等旧常量零出现（无回退分支）；`app/build.gradle.kts:79` `minSdk = 24`
  - 可达面：Express 服务构造 controller（`ExpressVpnService.kt:54`）；开关 UI 在共用设置页 `ui/LogRetentionSettingsScreen.kt:183-188`（经 `SettingsRouteActivity.kt:431` LOG_RETENTION_SETTINGS 路由，Express 可达——`MainActivity.kt:221` `updateFloatingLogAppState` 亦按模式分发）
  - API 24/25 上 `addView` 对未知 type 抛（SecurityException/IllegalArgumentException 族），runCatching 吞后功能静默死
- **机制/影响**：Android 7 设备开启悬浮日志：每次同步可见性（亮屏/VPN 切换）重试→再抛→再 toast，**永久不可用且骚扰性弹窗循环**；而极速模式宣传（`AppWorkMode.kt:41`「支持 Android 7+」）包含悬浮能力。与 A-036/A-032 同族（Express 把 API 26+ 假设带进 minSdk 24 面）。
- **触发路径**：7.x 设备→悬浮窗权限授予→开悬浮日志→启 Express→退后台。
- **复现/验证**：API 24 模拟器即现。修复 = `SDK_INT >= O ? TYPE_APPLICATION_OVERLAY : @Suppress("DEPRECATION") TYPE_PHONE`。
- **备注**：建议与 A-032/036/43 合并做一轮「Express 可达面 NewApi 全扫」，此族已四条。

---

## A-051 黑/白/重写列表 `loadPage` 无任务句柄与取消：筛选/翻页/ON_RESUME 并发加载竞写，旧任务完成在后把旧筛选的列表/计数刷进现视图

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/BlacklistViewModel.kt:124-126`（`fun loadPage(page) { viewModelScope.launch(IO) { …` **无 job 字段**）、`:241-246`（尾部 `withContext(Main){ _items/_currentPage/_totalPages/_totalCount = … }` 盲写）；`WhitelistViewModel.kt:149 + :325-330`、`RewriteListViewModel.kt:155 + :247-252` 同型
  - 仅搜索有防抖：`BlacklistViewModel.kt:88`/`WhitelistViewModel.kt:103` `searchJob?.cancel()`；`setFilter`（`:78-82`/`:93-97`/`RewriteListViewModel.kt:106-110`）直接再 launch 一个；翻页 `BlacklistScreen.kt:258` `onLoadPage = viewModel::loadPage`；`ON_RESUME → refreshAll`（`BlacklistScreen.kt:113-117`）
  - 各源延迟不等（域名单查 vs URL+cosmetic+订阅计数多查 vs 大表分页），完成序不保
- **机制/影响**：快速切筛选（全部→手动）、后台回前台撞上在飞 refreshAll、订阅更新完成触发的刷新与手动翻页并发——先发的旧任务后完成，列表行与「共 N 条」显示的是**上一个筛选/页**的数据，而筛选 chip/页码状态显示新值；点进去编辑的行不属于当前筛选。无 job 句柄所以无法取消，只有搜索路径承认了这个需求（证据）。
- **触发路径**：数万条规则库 + 慢盘：连点两个筛选 chip。
- **复现/验证**：单测：fake DAO 让第一页查询延迟 1s、第二查询即回，并发 loadPage 后断言 `_items` 属于最后一次筛选（当前可旧覆新）。修复 = 学 searchJob 各 VM 存 `loadJob` 先 cancel 再启，或写回前校验快照代数。

---

## A-052 黑名单「规则订阅」页签丢失订阅内 URL 拦截规则且计数同缺：白名单同位置注释自认此不对称

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/BlacklistViewModel.kt:133-136` — URL 取数白名单仅 `ALL/USER_ADDED/URL`，`SUBSCRIPTION → emptyList()`
  - 同函数 cosmetic 取数 `:154-159` **含** SUBSCRIPTION、域名计数 `:193-194` 走 `subscriptionRulesCount()`；`:180` `SUBSCRIPTION → cosmeticItems`（urlItems 缺席）；`:199` `total = nonDomainCount + domainCount` 同缺 URL 数
  - 订阅确实产生 URL 规则：`core/rule/SubscriptionManager.kt:45/53` 把 `goUrlRuleDao()` 接进 importer/storage，`core/rule/SubscriptionImportModels.kt:13/24` 统计 `urlBlockCount`，A-030 已证六类全收
  - 有意不对称的反证：`ui/WhitelistViewModel.kt:169-178` SUBSCRIPTION 页签**取** url entities，`:256-259` 注释原文「unlike the blacklist (whose URL list is empty for that filter) … belong in this tab」——白名单作者知晓并处理，黑名单侧没做
- **机制/影响**：含 `http(s)://` 拦截行的订阅（Anti-AD 类常见）更新后：规则**实际生效**（Go 快照吃 enabledRules 全量），但黑名单页签「规则订阅」看不到这些行、总数也少——用户以为订阅没带 URL 规则，去重复添加/换订阅。展示/计数与实际执行面不一致。
- **触发路径**：导入含 URL 行的订阅 → 黑名单 → 规则订阅 chip → 搜索该 URL 串：查无（对比「全部」页签可见）。
- **复现/验证**：Robolectric：插 `source=sub_1` 的 goUrl BLOCK 行，`setFilter(SUBSCRIPTION)` 后断言 items 含之（当前不含）。修复 = `:133-136` 分支加 SUBSCRIPTION 并按 `sub_*` 过滤 urlItems，计数同步。

---

## A-053 连崩自动备份用 `>=` 且成功后不置任何抑制标志：第 3 次起每崩一次就往系统下载目录刷一份全量备份、重复弹提示

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/crash/CrashLogManager.kt:118` — `if (newCount >= CONSECUTIVE_THRESHOLD && !hasExported)`，`newCount` 24h 窗口内单调涨（`:103-107`），`hasExported` 仅 `markManuallyExported:141-147` 或 `clearCrashLogs:354-361` 置位——**自动导出成功分支（`:124-129`）只写 `KEY_PENDING_AUTO_EXPORT_NOTICE`，从不写抑制位**
  - 每次满足即 `generateExportContent`（全量读 ≤8 份报告）→ `exportToDownloads` 新文件名（`:121-122` 秒级时戳，互不覆盖）→ 下次启动 `consumePendingAutoExportNotice` 再弹 toast（`main/MainStartupCoordinator.kt` 消费点）
- **机制/影响**：崩溃循环（如 A-032 的 API24 Base64 必崩路径）第 3、4、5…次各写一份几百 KB 重复大文件到用户下载目录并反复提示；「自动备份」语义应为一次性，现在是每崩必刷。
- **触发路径**：24h 内让 app 崩 4 次（不手动导出）→ 下载目录 2 份 `DITING-crash-auto-backup-*.txt`。
- **复现/验证**：Robolectric：预置 count=2 连调两次 `onCrashOccurred`，断言 `resolver.insert` 第二次不应发生（现发生）。修复 = 成功后记 `last_auto_export_count`，条件加 `newCount > lastAuto…` 或直接把阈值判定改「恰好跨过且未再导出」。
- **备注**：与 A-054/055 同文件域，三者共同决定备份触发时机的正确性，修复建议一并做。

---

## A-054 `CrashHandler` 里 `collectMinimalReport` 裸调用在前、`onCrashOccurred` 在后：恰是 StackOverflowError/OOM 时计数步骤永不执行——最该触发自动备份的崩溃循环计数恒 0

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/crash/CrashHandler.kt:30-46` — `CrashBreadcrumbs.record` 与 `:40` `collectMinimalReport(…)` **不在任何 runCatching 内**（对照 `:55-63` collectReport 有）；`:78` `CrashLogManager.onCrashOccurred(appContext)` 位于同一 try 尾部；`:79` `catch (e: Throwable)` 吞一切后 `finally` 交还系统 handler
  - `crash/CrashCollector.kt:320` 附近 `collectMinimalReport` 含 `throwable.stackTraceToString()`——SOE 栈帧数万条时构造巨型字符串可再抛 OOME/自身失败
- **机制/影响**：SOE/OOM 类崩溃（天然连环、最需要 3 连崩自动备份把证据带出下载目录）：minimal 段一抛即跳到 `:79`，`onCrashOccurred` 不执行 → `consecutive_crash_count` 恒 0 → A-053 的阈值永不触发，用户永远拿不到自动备份；崩溃文件本身也可能没落（record 先抛则无 minimal）。普通异常栈浅不炸，故长期无人报——正是「为何现场没炸」反证成立的解释。
- **触发路径**：写递归溢出函数进启动路径，循环 3 次 → `diting_crash_state` 的 count 仍 0。
- **复现/验证**：单测：mock `collectMinimalReport` 抛 OOME，断言 `onCrashOccurred` 被调用（当前不会）。修复 = 计数挪进 `finally`（或最早执行）。

---

## A-055 原生崩溃批量收集的水位线在整循环结束后才 `apply()`：收集途中进程再死 → 下次冷启动整批重采，重复报告+连崩计数虚增

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/crash/CrashLogManager.kt:313-345` — 循环 `:320-341` 逐条 `saveCrashReport`（含 fsync）+ `onCrashOccurred`（binder+fsync，窗口大），`:343-344` 才 `putLong(KEY_LAST_RECORDED_NATIVE_EXIT_TIME, maxTimestamp).apply()`（异步落盘，进程立死可丢）
  - 过滤条件 `:314` `timestamp > lastRecordedTime`；调用点 `DitingApp.kt:45-47` 裸线程冷启动并发跑（与主线程 Java 崩溃可交错——A-053 计数竞争面另列观察）
- **机制/影响**：收集 10 条历史原生崩溃期间再崩/被划掉 → 水位线未动 → 重启后已入库的几条**再收一遍**：重复 crash_*.log（还触发 O-105 覆盖窗口）+ 每次重复都调 `onCrashOccurred` → count 虚增提前/反复触发自动备份风暴（A-053 放大）。
- **触发路径**：预置 ≥2 条 REASON_CRASH_NATIVE → 启动后立即制造 Java 崩溃 → 重启看 count 与文件数翻倍。
- **复现/验证**：单测：mock ActivityManager 两条 exitInfo，第二条处理前抛/退出，断言水位线已含第一条（当前为旧值）。修复 = 每条 `commit()` 增量水位线。

---

## A-056 `dayStartMillis` 用当前 UTC 偏移折算固定 86400s 网格：DST 切换日「今日」统计起点偏 1 小时，与同文件 `dayStringAt` 真历法互相矛盾

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/util/DateTimeUtils.kt:10-14` — `(now + zoneOffset)/86_400_000*86_400_000 - zoneOffset`，`zoneOffset = TimeZone.getDefault().getOffset(now)`（假设本地日与 UTC 日网格对齐且全天恒定）
  - 消费：`statsRangeStartMillis(TODAY)`（`:17-21`）→ `ui/ModernLogDashboardViewModel.kt:168,183` dailyStats「今日」窗口；对照 `:24-25` `dayStringAt` 用 `SimpleDateFormat` 真历法——同文件两把尺
- **机制/影响**：DST 起始日（春季拨快）本地零点真实偏移 ≠ 当前偏移，TODAY 起点偏 ±3600s：切换日凌晨~次日，仪表盘「今日」少/多算一小时窗口内的 DNS/HTTP 日志，且按日聚合字符串分组与「今日」数对不上。Asia/Shanghai 无 DST——主用户群恒不可见，这就是不炸原因；验证须换 `TZ=America/New_York`。
- **触发路径**：纽约时区设备 3 月第二个周日 00:30 本地看「今日」统计与逐日表对账。
- **复现/验证**：JVM 单测：`TimeZone.setDefault(NY)` + 固定 now=切换日 01:30 EDT，断言 `dayStartMillis()` == 真本地零点（当前差 1h）。修复 = `Calendar.set(Y,M,D,0,0,0)` 或 `atStartOfDay` 语义。
- **备注**：文件小、函数纯，修复几乎零成本。

---

## A-057 流量页「已连接 HH:MM:SS」只在组合期取 `currentTimeMillis`，空闲无流量时不重组 → 时钟冻结在最后流量时刻

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/traffic/TrafficGaugeCard.kt:144-146` — 组合中直接 `System.currentTimeMillis() - sessionStartTimeMs`，无 ticker/produceState
  - 上游节流：`core/traffic/TrafficStatsManager.kt:339-351` 「无变化快路径」比较字段不含 `updatedAt`（`:364` 才写）→ 空闲会话速度 0/字节不变 → StateFlow 不发射 → 无重组
  - 页面采集：`normal/ui/AppTrafficStatsScreen.kt:74` 仅 `collectAsStateWithLifecycle`；grep 证实该屏无秒级 ticker
- **机制/影响**：开流量页静置 2 分钟，「已连接」秒针纹丝不动；随便来点后台流量它跳变追平——用户误判页面卡死或会话异常。纯显示新鲜度问题，数据无害。
- **复现/验证**：Compose UI 测试：冻结 StateFlow 发射 + 推进时钟，断言文本变化（当前不变）。修复 = `LaunchedEffect { while(true){ delay(1000); now.value=… } }`。

---

## A-058 崩溃日志「已手动导出」标记由可取消的 `rememberCoroutineScope` 在 IO 完成后才写：写完文件即切页 → 文件已导出但阈值仍武装（A-053 的抑制器漏写窗口）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/LogRetentionSettingsScreen.kt:74-94` — CreateDocument 回调 `scope.launch { runCatching{ withContext(IO){…write…} } ; if (success) markManuallyExported(context) }`；`scope = rememberCoroutineScope()`（`:72`）随组合销毁取消
  - `crash/CrashLogManager.kt:141-147`（markManuallyExported 语义：置位+清零）、`:118`（消费方）
- **机制/影响**：用户在导出 SAF 写盘完成的瞬间返回/旋转/杀页 → launch 被取消，`markManuallyExported` 未执行 → prefs 无手动导出记录、计数不清 → 下次第 3 连崩自动备份照常刷文件+弹提示（用户「明明导出过」）。窗口窄但机制确定；与 A-053 叠加时表现为「关不掉的自动备份」。
- **复现/验证**：单测：模拟 `result.isSuccess` 后协程取消路径，断言 prefs `has_manually_exported`（当前 false）。修复 = 标记挪进 `withContext(IO)` 成功分支同一事务点，或用 `NonCancellable`。

---

## A-059 `KeyObfuscator` 把 UTF-16 code unit 截成单字节：非 ASCII 密钥 seal/open 往返静默损坏，open 失败又以空串吞掉

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/util/KeyObfuscator.kt:23-27` — `plain[i].code.toByte()`：'中'(U+4E2D)→0x2D('-')，高位信息丢失；非 ASCII 序列产出的字节多半非法 UTF-8，`:36` `decodeToString()` 以 U+FFFD 静默替换
  - `:37-39` `catch (_: Exception) return ""`：base64 解码失败与真空密钥不可区分；调用方 `ui/settings/AgentApiSettingsStore.kt:331-337` revealApiKey/sealApiKey 直接透传
  - 与 A-032（`java.util.Base64` API-26 崩溃）不同机制：这条是数据完整性，全 API 等级都犯
- **机制/影响**：用户在 AI 供应商里贴含非 ASCII 的密钥/服务名衍生键（少见但合法——密钥字段无字符集提示）→ 保存成功、回显变味、AI 请求 401 且无法解释；`syncProviderToConfig`（`:339-347`）把损坏明文再写进 agent config，污染面扩大。ASCII 常规 `sk-…` 安全，故主路径不炸（反证成立）。
- **复现/验证**：JVM：`open(seal("密钥abc")) != "密钥abc"`（现真）；`open(seal("日本語キー"))` 含 U+FFFD。修复 = 用 UTF-8 字节流做异或掩码（`plain.toByteArray()` 后按原样长度还原，格式不变），或入口拒绝非 ASCII 并提示。

---

## A-060 下载失败 catch 无条件清全局单槽位下载记录：检查到新版失败会抹掉**已下载旧版**记录 → 磁盘旧 APK 成孤儿、回到同版本强制全量重下

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/update/AppUpdateManager.kt:125-129` — catch 分支 `finalFile.delete(); SystemSettingsStore.clearAppUpdateDownload(context)`（删的是**本次尝试版本**的 finalFile，但清的是 prefs **全局唯一**记录）
  - `ui/settings/SystemSettingsStore.kt:161-166` — `KEY_APP_UPDATE_DOWNLOAD_PATH/VERSION` 单槽位，无版本维度
  - `update/AppUpdateHost.kt:69-79` — 再点同版本下载先 `finalFile.delete()` → 全量重下
- **机制/影响**：v1 下载完成（记录在案，APK 在 `app-update/`）→ 服务器发 v2 → 用户下 v2 失败（断网）→ prefs 里 v1 记录被清 → v1 APK 磁盘残留但 UI 不可见（又叠加 A-013 清理目录错位=永久孤儿）；用户回头装 v1 需重下整包，耗流量。
- **复现/验证**：依次完成一次下载、制造一次不同版本下载失败，查 prefs（路径键消失）与 `files/app-update/`（v1 文件仍在）。修复 = clear 前比较记录版本==本次版本，或改按版本键存多槽。
- **备注**：触发需「旧版已下+新版检查失败」两步，中频场景。

---

## A-061 「当前筛选下暂无 DNS 请求日志」（Express 请求日志空态）无任何字典/模板覆盖，前缀替换吐出半英文拼接串

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/express/ui/ExpressRequestLogScreen.kt:252` — `localizedText("当前筛选下暂无 DNS 请求日志")`
  - 精确表无此条：`ui/localization/LogsAndStatsLocalization.kt:54` 只有「当前筛选下暂无**请求日志**」、`:107` 模板只接「暂无请求记录」；`ui/localization/CommonLocalization.kt:436` 又是另一近义句——该句唯独漏收
  - 落入兜底：`ui/localization/DynamicPatternLocalization.kt:150` — `startsWith("当前筛选下") → replace("当前筛选下","No records for the current filter")` → 输出 `"No records for the current filter暂无 DNS 请求日志"`
  - 资源侧无注册：全仓 grep `localized_text_2081635827`（该串哈希名）在 `values/values-en` 均 0 命中
- **机制/影响**：英文界面下 Express 请求日志空态显示中英杂交串，其余近义空态全部正常——明显是词表维护漏行而非设计。
- **复现/验证**：JVM：`translate("当前筛选下暂无 DNS 请求日志", ctx)` 结果含未替换中文；修复 = LogsAndStats 精确表补一行。
- **备注**：扫描词表时发现 `DynamicPatternLocalization.kt` 有 14 处 when 分支永不命中（`:63,74,119-120,132,136,138-139,142-143,151,172` 等，重复前缀被更早前分支吞并），其中 `:151` 的 `startsWith("成功 ")` 兜底分支正是防「导入失败：成功 2 项」这类嵌套串的最后防线，删重复分支时**必须保留它**（`:57` 先命中，无害）。

---

## A-062 元素隐藏注入后的 HTTP/1.1 响应没有任何 body 定界：浏览器文档永不结束（挂死/转圈），代理与客户端双向互等

- **位置**
  - `Android/tunnel/mitm_common.go:65-73`（`wrapResponseForInjection` 尾部）— `resp.Body = io.NopCloser(NewInjectingReader(bodyReader, host))`；`resp.ContentLength = -1`；`Header.Del("Content-Length")`；`Header.Del("Transfer-Encoding")`；`resp.TransferEncoding = nil`；**`resp.Uncompressed = true`**
  - 调用点 `Android/tunnel/mitm_relay.go:160-173`：`if ShouldInjectHTML(...) { wrapResponseForInjection }` → `resp.Write(clientConn)` → keep-alive 循环回 `http.ReadRequest`
  - stdlib 判定（**本机 Go 源码逐字核对**，`C:\Program Files\Go\src\net\http\response.go:296`）：`if r1.ContentLength == -1 && !r1.Close && r1.ProtoAtLeast(1, 1) && !chunked(r1.TransferEncoding) && !r1.Uncompressed { r1.Close = true }` —— `Uncompressed=true` 使 `Close` **不被补齐**；于是 writeHeader 既不发 `Content-Length`（字段 -1）、不发 `Transfer-Encoding: chunked`（nil）、也不写 `Connection: close`
- **机制/影响**：命中「非空 cosmetic 规则 + `Content-Type: text/html` + 域名闸门」的每一个响应，在线上是一个「HTTP/1.1 200 且零定界」：客户端只能等到连接关闭才知道 body 结束，而代理不关闭并回头等下一个请求 → **双向互等**。浏览器表现为页面一直转圈、文档不结束、SPA 卡死。
- **触发路径**：启用 HTTPS 检查 → 添加任意元素隐藏规则（如 `example.com##.banner`）→ 访问返回 text/html 的拦截域 → 浏览器挂死（curl 会挂到超时）。
- **复现/验证**：Go 单测：构造非空 cosmetic 规则，对注入后 `resp` 调 `resp.Write(&buf)`，断言 buf 含 `Transfer-Encoding: chunked`、`Content-Length:`、`Connection: close` **三者之一**（当前三者皆无 → 失败）。修复二选一：`resp.TransferEncoding = []string{"chunked"}`（保 keep-alive，推荐）或删去 `Uncompressed=true`（接受 close-delimited 断连）。
- **备注**：附带同一函数未特判 HEAD（`noResponseBodyExpected`）——HEAD 也会删掉真实 CL；修 [1] 时一并处理。反证（为何现场少报）：元素隐藏默认关闭、命中面仅 text/html；对照 `writeBlockedHTTPResponse` 未设 Uncompressed 因而被 stdlib 正确补 close，本地 asset 走 `buildTextResponse` CL 一致不受影响——已逐一核过非误报。

---

## A-063 全局元素隐藏例外（`#@#`，域为空）被 `buildCosmeticCss` 静默丢弃：无法取消隐藏、也不产生 `display: revert`

- **位置**
  - `Android/tunnel/mitm_local_server.go:61-79`（`buildCosmeticCss`）— `hide` 有 `for _, selector := range rules.GlobalHide` 填充循环；`exceptions := make(map[string]struct{}, len(rules.GlobalException))` **只用作容量**，随后仅有按域循环 `entry.Exception → exceptions[selector]`，**无任何 `range rules.GlobalException`**
  - 消费：`:81-89` `hidden` 过滤与 `:91-105` excepted 输出都只读 `exceptions` map → 全局例外两条通道皆空
  - Kotlin 侧确实在填该字段：`core/rule/CosmeticRuleManager.kt:36,45,59` — `domain.isEmpty() && rule.isException → globalException`，JSON 键 `globalException`
  - 遮蔽证据：`mitm_cosmetic_test.go:16` fixture `globalException:[]` 恒空、`CosmeticRuleManagerTest.kt:37` 断言长度 0——两侧都用空值覆盖，测试恒绿
- **机制/影响**：用户添加全局取消隐藏规则（`#@#.ad-banner`）后：该选择器**既不豁免**按域隐藏，**也不输出** `display: revert !important`——凡被任何 hide 规则命中的同名元素一律误隐藏且无法解除。方向性错误发生在用户明确尝试「解封」时。
- **触发路径**：加 `##.ad` 与 `#@#.ad` 两规则 → 浏览器访问任意页 → `.ad` 仍隐藏。
- **复现/验证**：Go 单测 `buildCosmeticCss(`{"globalHide":[".x"],"globalException":[".x"]}`, "a.com")` 输出应不含 `.x { display: none`（当前含）；修复 = 补 `for _, s := range rules.GlobalException { exceptions[s] = struct{}{} }`。

---

## A-064 `InjectingReader` 在 EOF/短读路径丢弃 `carry` 中的 ≤5 字节 `<head` 前缀：特定文档输出截尾

- **位置**
  - `Android/tunnel/mitm_cosmetic_inject.go:111-113` — `n, err := r.upstream.Read(p); if n == 0 || r.injected { return n, err }`：**返回前从不检查/写出 `r.carry`**
  - `:145-158` — 末块尾部命中 `<h`/`<he`/… 前缀时 `r.carry = …` 留待拼接；若该块即 EOF（`len(outData)==0 → return 0, err`），下一次 Read `n==0` 直接走 `:112`，carry 永不输出
- **机制/影响**：文档 ≤scanLimit 且不含完整 `<head>`、且恰以 `<head` 前缀（`<h`、`<he`…）结尾时，尾部 1–5 字节被吞。正常 HTML `<head>` 在前 16KB 内完整匹配走 `doInject` 即不再用 carry——这正是现场不现形的反证；触发面极窄但数据损坏确定发生（静态可证）。
- **复现/验证**：单测 `io.ReadAll(NewInjectingReader(strings.NewReader("x<he"), "a.com"))`（配非空 cosmetic 规则）期望 `"x<he"`，当前返回 `"x"`。修复 = 在 `n==0 || r.injected` 早退前把残留 carry 排入 pending/输出。

---

## A-065 Express DNS 缓存写入用 `OnConflictStrategy.REPLACE` 整行覆盖：命中计数在重缓存时归零（NORMAL 侧注释明确防的就是这件事）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/express/cache/ExpressRoomDnsCache.kt:112-126` — 每次 `put` 都以 `hitCount = 0, lastHitAt = null` 构造实体 → `dao.insert(entity)`（`:126`）
  - `data/dao/DnsCacheDao.kt:33-34` — `@Insert(onConflict = OnConflictStrategy.REPLACE) insert`（REPLACE = 删旧行+插新行；`DnsCacheEntity.kt:18` 以 `key` 为唯一 `@PrimaryKey`，同 key 必然触发删除重插）
  - 读取侧确在累加：`ExpressRoomDnsCache.kt:86` `dao.recordHit(key, now)`（`DnsCacheDao.kt:74`）
  - **同库的自证**：`DnsCacheDao.kt:40-47` `updateMetadata` KDoc 原文——「deliberately does NOT touch `hitCount`/`lastHitAt`, so a batched response refresh can never clobber the counters accumulated by addHits」；NORMAL 走 `applyPendingWrites`（update→0 行→insertIfAbsent）保计数，Express 的 put 没走这条路
- **机制/影响**：热域名每次 TTL 过期重解析后再 put → 命中数归零；`totalHitCount()`（`DnsCacheDao.kt:30-31` SUM(hitCount) → `ui/ModernLogDashboardViewModel.kt:200`）系统性偏低、缓存页各条目命中数失实、`lastHitAt` 排序退化（`index_dns_cache_lastHitAt` 的 ORDER 退到 createdAt 序）。仅统计/展示失真，不影响解析正确性；只犯 Express 库（`diting_express`，`ExpressRulesDatabase.kt:61`）——与「共享 DnsResponseCache 死代码」的 O-107 不同库不同机制，不重复。
- **触发路径**：Express 开 DNS 缓存 → 对同一域名命中数次 → 等 TTL 过期再命中触发 put → 该域名 hitCount 从 N 跳回 0。
- **复现/验证**：单测：同 key 连调 `put` 两次（前置 `recordHit` 一次），断言 `hitCount` 仍 ≥1（当前 =0）。修复 = put 改走 `updateMetadata` + 0 行回落 `insertIfAbsent`（`applyPendingWrites` 的 entities 半可直接复用）；或改 `@Upsert`。

---

## A-066 「清理全部域名规则」删除 HOSTS 订阅的 v4/v6 覆写却不复位其 ruleCount：专用复位函数 `resetAfterRuleCleanup` 全仓零调用

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt:193-208`（`clearDomainRulesData`）— `rewriteDao.clearByTargetTypes(listOf(IPV4, IPV6))`（连删其 source 行，`RewriteRuleDao.kt:121-124` 同事务自洽）→ `subscriptionDao.deleteByKind(SubscriptionKind.DOMAIN)` **只删域名类订阅**：HOSTS 订阅行保留，`ruleCount/lastUpdated` 原样
  - `data/dao/SubscriptionDao.kt:92-96` — `resetAfterRuleCleanup()` 正为本场景准备；grep 全仓（含测试）**除声明外零调用**
  - 不自愈：下次成功更新才修；304 命中走 `markNotModified`（`core/rule/SubscriptionManager.kt:462-470`）只刷新 `lastAttemptAt/etag`，ruleCount 永不重算
- **机制/影响**：清理后 HOSTS 订阅徽标/「规则数」显示的是删除前的数量，而库里实际可解析覆写已为空/部分为空——直到下一次真更新前持续失真。无崩溃、无额外丢数据（丢的正是承诺删的），纯陈旧计数。
- **触发路径**：订阅列表含 hosts 订阅 → 设置→清理全部域名规则 → 打开订阅列表看 hosts 项规则数与实际（`select count(*) … source='sub_<id>'`）不符。
- **复现/验证**：Robolectric：造 hosts 订阅（ruleCount=10）+10 条 v4 覆写 → `clearDomainRulesData` → 断言 `ruleCount==0` 或订阅被删（当前保留 10）。修复 = 清理流程调 `resetAfterRuleCleanup`（或 `deleteByKind(HOSTS)` 一并删）。

---

## A-067 `buildIPv6UDPPacket` 先算校验和后写 payload：所有合成 IPv6 UDP 应答校验和恒错，内核强校验整包丢弃

- **位置**
  - `Android/tunnel/dns_packet.go:305-328` — `:322` `csum := calculateUDPIPv6Checksum(srcIP.To16(), dstIP.To16(), packet, udpOffset, udpLen)`；`:323` 写入；**`:325` `copy(packet[udpOffset+udpHeaderSize:], payload)` 在校验和计算之后**——计算时 payload 区还是 `make` 出的全零
  - `:362-364` 累加范围 `udpOffset..udpOffset+udpLen` 含 payload 区（伪首部 + UDP 全段，RFC 1071/2460 8.1 正确写法，只是时序错）
  - 唯一入口 `:275`（`queryInfo.IsIPv6` 分支）→ `BuildBlockedResponse/BuildNXDomainResponse/BuildRefusedResponse/BuildServfailResponse/BuildRedirectResponse/buildRewriteIPResponse/BuildForwardedResponse` 的 v6 路径全部受害
  - 对照 IPv4：UDP 校验和写 0（RFC 允许不校验），所以只有 v6 出错——「现场不炸」的一半解释
- **机制/影响**：IPv6 下 UDP 校验和为强制（内核不允许 0/错误值），错误校验和的包在 TUN/路由出口被静默丢弃。客户端表现为：v6 查询无应答直到超时，Happy Eyeballs 回退 v4 后被误记成「解析慢/偶发重试」；IPv6-only 网络或把手机当 v6 DNS 上游（DNS 模式）则**全部失败**。
- **触发路径**：普通模式开拦截，`nsquery -6` AAAA 被拦域名（或 DNS 模式 LAN 客户端走 v6）→ `tcpdump ip6` 见校验和错误、客户端收不到。
- **复现/验证**：Go 单测：`buildIPv6UDPPacket(..., payload=[…非零])` 后用独立 RFC1071 实现重算，断言与 `packet[udpOffset+6:8]` 相等（当前必不等）。修复 = 把 `:325` 的 copy 移到 `:322` 之前。
- **备注**：与 A-019（TC 截断）、O-104（start/stop 交错）无关；`calculateUDPIPv6Checksum` 内 saved/restore 逻辑本身正确。

---

## A-068 `SetTries` 锁内 Close 旧 trie（munmap）、读者锁外解引用：规则热重载与活跃 DNS 流量并发 → use-after-unmap SIGSEGV

- **位置**
  - `Android/tunnel/domain_trie.go:79-88` — `Close()`：`unmapFile(m.buffer); m.buffer = nil`（`mmap_unix.go` 的 `unix.Munmap`），自身无任何锁
  - `Android/tunnel/engine_rules.go:17-47` — `SetTries` 在 `e.mu` 下对旧 `adTries/secTries/adBlooms/secBlooms` 逐个 `Close()` 后重建
  - 读取侧模式（三处同构）：`engine_rules.go:140-148`（`hasImportantMatch`：锁内只拷 slice → 锁外 `trie.ContainsOrParent`）、`engine_dns.go:132-160`、`engine_standalone.go:201-226`——`ContainsOrParent`（`domain_trie.go:90-96`）检查 `m.buffer == nil` 后进入 `matchWithWildcard/findChildOffset` 对 buffer 的长期裸读；即使躲过 nil 检查，munmap 已在读中途发生
  - 触发者（Kotlin）：`GoTunnelRuleManager.kt`/`BlockRuleCache` 重载路径在**服务运行中**调 `SetTries`（规则/订阅更新、启停刷新），与 serve goroutine 并发
- **机制/影响**：`e.mu` 只保护指针数组的替换，不保护被指向对象的生命周期。读者持有的旧 `*MmapTrie` 被并发 `Close()` → 页解除映射 → 后续偏移读取落在无效 VMA：**SIGSEGV 是信号而非 Go panic，`recover()` 无法捕获，进程直接死**（ gomobile 侧表现为原生崩溃，进 A-055 的批量收集路径）。次生：`m.buffer=nil` 与读取竞态本身即数据竞争（`go test -race` 可报）。
- **现场不炸反证**：重载频率低且多发生在会话边界；munmap 后页常短暂仍在 RSS，读出旧值不崩（掩盖成「规则延迟生效」）；Windows 测试路径 `mmap_windows.go` 用 `io.ReadFull` 读堆内存，天然不复现。
- **触发路径**：大规则库 + 持续 DNS 流量下点「更新订阅」（触发 SetTries）→ 偶发进程原生崩溃。
- **复现/验证**：`go test -race`：goroutine A 循环 `trie.ContainsOrParent`，B 循环 `LoadMmapTrie+Close`，必报竞争。修复 = 整套 tries 用 `atomic.Pointer[trieSet]` 快照替换、旧集合延迟/引用计数后再 Close；或 per-trie RWMutex（读侧开销略增）。
- **备注**：与 A-018（Engine 字段 setter 无锁）同属「e.mu 不构成对嵌套对象生命周期的保护」，但本条是**释放后使用**（崩溃级），A-018 是值撕裂，机制与修复均不同，分立记录。

---

## A-069 `dnsCache.clear()` 用 `lruList.Init()` 不 `Remove`：并发命中提升把孤儿元素重新链回，LRU 与 map 永久失同步

- **位置**
  - `Android/tunnel/dns_cache.go:108-120` — `clear()`：`shard.mu.Lock()` 下把 `e.elem=nil`、重建 entries、`shard.lruList.Init()`
  - 本机 Go 源码逐字核对：`container/list/list.go:54-59` `Init()` 只重置 `root/len`，**不动任何 element 的 `.list/.prev/.next`**；仅 `Remove()`（`:113` `e.list = nil`）会断开归属
  - `:175-188` 命中提升分支：RLock 下快照 `elem` → RUnlock → 再 Lock → `if elem.Value != nil && Front() != elem { MoveToFront(elem) }`——clear 插队后，孤儿 elem 的 `Value` 未被 Init 清空、`e.list == l` 仍成立，`MoveToFront` 把它重新链进刚清空的表
  - 消费点：`ClearDNSCache` 被 Kotlin 运行期热调用（`normal/GoInspectionTunnel.kt:115`、`server/backend/DnsServerEngine.kt:104`）
- **机制/影响**：清缓存后 `lruList.Len() ≠ 0` 且 Front/Back 指向已不在 map 的 entry；后续 `putMsg` 淘汰（`:321-331`）从 Back 取 `*cacheEntry` delete 不存在的 key（空转），真实热点条目被错误提升/淘汰，LRU 次序失真持续影响命中率，直到下次全量 clear 再叠加。
- **复现/验证**：Go 单测：put 两条 → 手工模拟提升窗口（先捕获 elem，再 `clear()`，然后在 Lock 内执行与 `:181-187` 相同的判断+`MoveToFront`），断言 `lruList.Len()==0`（当前 =1）。修复 = clear 内逐个 `shard.lruList.Remove(e.elem)` 替代 `Init()`（或提升前重查 `entries` 归属）。
- **备注**：与 A-017（清理协程泄漏）、O-107（TTL=0 镜像行）无关；`elem.Value != nil` 守卫说明作者知道要防悬挂，但防的是 Remove 场景，Init 场景漏防。

---

## A-070 trie 与 bloom 各自「成功才 append」按下标配对：单个 bloom 加载失败即整体错位一格，预过滤假阴性跳过整个 trie → 静默漏拦

- **位置**
  - `Android/tunnel/engine_rules.go:49-108`（`SetTries`）— adTries/adTrieIDs 在 trie 循环内成功才 append，adBlooms 在**另一个独立循环**里成功才 append（失败仅 `logf` 跳过）；sec 侧同型
  - 判定端 `:205-218`：`for i, adTrie := range adTries { adBloom := adBlooms[i]（若 i < len）; if adBloom == nil || adBloom.MightContainDomainOrParent(host) { adTries[i].ContainsOrParent… } }`；`engine_dns.go:132-160`、`engine_standalone.go:201-226` 同构
- **机制/影响**：第 k 个 bloom 文件损坏/缺失而 trie 全在时，`adBlooms` 短一格且**索引前移**：`adBlooms[j]` 被拿去预过滤 `adTries[j+1]` 的词表。bloom 预过滤说「不含」→ 该 trie 整个被跳过 → 命中它的域名**不再被拦**（假阴性漏拦）。注意 bloom 正常假阳性不会误拦（仍要 trie 复核，fail-safe）——危害只来自错位。错位后 `adTrieIDs[i]` 与 `adTries[i]` 仍对齐（同循环 append），所以日志归因看着正常，更难发现。
- **现场不炸反证**：Kotlin 侧（`MappedSubscriptionRuleIndex`）同批成对产出 bloom+trie，缺件属断电/清理半截等异常态。
- **触发路径**：手工删除 `/data/data/…/rule-index/domain/` 下任一 bloom 文件 → 重启服务 → 对应列表规则静默失效。
- **复现/验证**：Go 单测：2 trie + 1 bloom（仅覆盖 trie#1 词表）调 `SetTries`，查「在 trie#0、不在 bloom#0」的域名，断言应命中（当前被跳过）。修复 = (trie, bloom, id) 三元组同进同退：任一失败丢弃整对，或按文件名配对一次性 append。

---

## A-071 MITM `CertManager.certCache` 无上限无淘汰（文件头注释承诺的「LRU 512 entries」不存在）：拦截子域越多内存单调增长

- **位置**
  - `Android/tunnel/mitm_cert_manager.go:6-7`（头注释「LRU Cache: Maintains an in-memory certificate cache (512 entries) …」）对照实现 `:41` `certCache sync.Map`、`:326` `Store`——全文件无容量检查、无 LRU 结构、无周期清扫；仅 `:84-87`/`:271-274` 在同 host 再次命中**且证书已过期**时 `Delete` 单条
  - 每条含 ECDSA 私钥 + 两张 DER（叶证书+链）
- **机制/影响**：被拦截过但不再访问的 host，其过期/未过期证书**永久驻留**直至整个 CertManager 废弃（即 Engine 重建，A-017 场景反而顺带清了它）。长时间开启 HTTPS 检查、遍历大量不同子域（CDN 域名爆炸）时内存单调增长；注释与实现相悖会误导容量规划与排查方向。
- **现场不炸反证**：单会话唯一 host 数有限、单条几 KB，短时不 OOM；本条独立于 A-017（那里是「每调用新建 Engine 不 Stop」，这里是「缓存自身无 cap」）。
- **复现/验证**：Go 单测：循环 `getCertForHost("hN.example.com")` N=1000 后 `certCache.Range` 计数，断言 ≤512（当前 =1000）。修复 = 实现真 LRU（heap/list + 锁）或至少 `len>cap` 时随机/最旧驱逐；退一步改注释亦可消除误导，但建议实现补齐。

---

## A-072 MITM 注入的 gzip/deflate 路径替换 `resp.Body` 后原始 body 永不 Close/排空：同连接 keep-alive 下一轮 `ReadResponse` 错位

- **位置**
  - `Android/tunnel/mitm_common.go:43-49`（`gzip.NewReader(resp.Body)` 无 defer Close，随后 `:65` `resp.Body = io.NopCloser(...)` 顶掉原 body）、`:52-60`（deflate/zlib 分支 `io.ReadAll` 后同样丢弃原 body）
  - `mitm_relay.go:173` `resp.Body.Close()` 此刻关的是 **NopCloser**（no-op），上游 `*http.body` 的 chunked 终结块/trailer 永不消费；`mitmTLSFlow` 同一 serverConn 上循环 `http.ReadResponse`（`:153`）
- **机制/影响**：上游响应未读到协议层结束即开始下一请求的解析 → 剩余字节被当作下个响应头，解析错位/报错，该连接上后续请求失败（视站点表现为「第二页起打不开」）。与 A-062 叠加时客户端本就挂死，用户难以归因，属独立的「流未排空」缺陷。
- **现场不炸反证**：多数站点每连接单请求即 close，`resp.Close` 分支提前断开掩盖 desync。
- **复现/验证**：Go 单测：mock 上游对同连接两个连续 GET 返回 chunked gzip HTML，过 relay 断言第二响应解析成功（当前失败/错位）。修复 = 保留原 body 引用，注入读完后 `orig.Close()`（或 gzip Reader 包一层 `Close = gr.Close + orig.Close`）。
- **备注**：顺带记录：`wrapResponseForInjection` 对 HEAD 响应也会删真实 CL/TE（无 `noResponseBodyExpected` 特判），归入 A-062 的修复注记。

---

## A-073 包级全局 `connLogSeen sync.Map` 仅在 `StartFull` 清空：非全隧道模式无回收点，去重键单调增长且跨引擎实例互相压制

- **位置**
  - `Android/tunnel/engine_connection_log.go:31` — `var connLogSeen sync.Map`（**包级**，非 Engine 字段）；`:56`/`:99` `LoadOrStore(key)` 去重，键 `app|ip|port|proto` 与 `blk|…|reason`
  - 全仓唯一清理点：`engine_full_tunnel.go:102`（`StartFull` 内 `Range+Delete`）——standalone（DNS 模式）与 inspection-only 会话从不经过
- **机制/影响**：① CDN/P2P/随机高端口的长会话持续产生新键，Map 只增不减 → 内存缓涨（低-中，非崩溃级）；② 键永不过期 + 全局共享：同一设备第二个 Engine 实例（A-017 的 CA 管理器路径）的新会话日志会被**旧实例遗留键压制**，连接日志漏记。
- **复现/验证**：Go 基准：对不同 dest 反复 `logConnection`，`Range` 计数不回落（当前）。修复 = 移入 Engine 实例字段 + TTL/LRU 清理，或至少 Start/Stop 钩子成对清空。

---

## A-074 `LoadBloomFilter` 不校验 `bitCount/hashCount` 下界：`bitCount=0` 的畸形文件通过尺寸校验，首个 `MightContain` 触发 `%0` panic

- **位置**
  - `Android/tunnel/domain_bloom_filter.go:170-186` — 读 `bitCount`（8:16）/`hashCount`（16:20）后仅校验 `size < bloomHeaderSize + bitCount/8`；`bitCount=0, hashCount=4` 的 24 字节头文件恰好 `expectedSize=24` 被 Accept
  - `:199-215` — `MightContain` 内 `:205` `idx := (h1 + uint64(i)*h2) % bf.bitCount` → runtime error **integer divide by zero**（Go 里是 panic，可被 recover，但发生在 gomobile 回调热路径 → Kotlin 崩溃链）
- **机制/影响**：规则索引文件被写坏/写满/半截落盘（与 O-116/A-068 的崩溃-重建窗口呼应）后，下一次域名判定即 panic；不像 C 级损坏只影响单列表，这里炸的是解析热线程。
- **现场不炸反证**：`BloomBuilder.SaveToFile` 经 `OptimalBloomParams` 产出的 `bitCount ≥ 64`（expectedItems=1 也抬到 %8 补齐），正常文件恒非零——仅损坏/截断文件命中。
- **复现/验证**：Go 单测：手写 24 字节头（magic+ver+bitCount=0+hashCount=4）调 `LoadBloomFilter` 断言返回错误（当前成功），`MightContain` 断言不 panic。修复 = Load 内 `bitCount==0 || hashCount==0 || hashCount>64` 即报错；顺带校验 `bitCount/8 ≤ size-headerSize` 的整段覆盖。

---

## A-075 Express 模式可添加元素隐藏规则并提示成功，但该库的规则永不参与 CSS 编译、列表也不显示：产生不可见、不生效、无法删除的幽灵规则

- **位置**
  - 入口可达：`Android/app/src/main/java/com/haoze/diting/main/MainModeDispatcher.kt:49` — `onNavigateToBlacklist = { onNavigateToSettings(Routes.BLACKLIST_MANAGEMENT, RuleDataset.EXPRESS) }`（极速模式主屏确实把黑名单页以 EXPRESS dataset 挂载）
  - 校验只拦 DNS_MODE：`ui/BlacklistViewModel.kt:331-333` — 元素隐藏分支仅 `if (dataset == RuleDataset.DNS_MODE) return failure("元素隐藏规则仅普通模式支持")`；EXPRESS 直通
  - 写入 EXPRESS 库：`:340-347` — `cosmeticRuleDao.insertForSource(entity, "useradd", …)`，该 `cosmeticRuleDao` 来自 dataset 路由（EXPRESS → `ExpressRulesDatabase`，`data/DnsRulesDatabase.kt:137` 家族），随后返回 `Result.success("已添加元素隐藏规则")`
  - 编译端只读 NORMAL 库：`core/rule/CosmeticRuleManager.kt:22-28` — `getInstance` 硬编码 `AppDatabase.getInstance(...).cosmeticRuleDao()`，与 VM 中 `CosmeticRuleManager.getInstance(getApplication()).compileScopedCss()`（`:348`）编译的是 **NORMAL 库**，刚写进 `diting_express` 的行永不参与
  - 列表端不可见：`ui/BlacklistViewModel.kt:154` — cosmetic 取数包在 `if (dataset == RuleDataset.NORMAL)` 内，EXPRESS 下 `allCosmetics = emptyList()`（`:159`）
- **机制/影响**：三个条件叠加使该路径成为单向黑洞：用户（在极速模式黑名单页）粘贴 `example.com##.banner` → 提示「已添加元素隐藏规则」→ 列表里查不到该条（cosmetic 不显示）→ 也永不生效（CSS 从 NORMAL 库编译，且极速模式本身不做 HTTPS 检查/元素隐藏，`express/` 内无 MITM）→ 该行残留在 `diting_express.cosmetic_rule`，普通「清空手动」路径（`BlockRuleDao.deleteUserRules`）不含 cosmetic 表，故用户无任何 UI 手段删除。用户认知是「加了但没用」，磁盘上留下永久垃圾行。
- **触发路径**：极速模式 → 黑名单 → 输入 `example.com##.ad` → 成功提示 → 列表无此行 → 重启仍在（残留）→ 无任何入口删除。
- **复现/验证**：Robolectric/真机：EXPRESS dataset 下 `addRule("a.com##.x")` 返回 success，随后 `cosmeticRuleDao`（diting_express）行数 +1、列表 items 不含它、`compileScopedCss()` 输出不含 `.x`。修复二选一：与 DNS_MODE 同样拒绝 EXPRESS（**推荐**，与「极速模式无 HTTPS 检查」的产品事实一致），或让 `CosmeticRuleManager.getInstance` 接收 dataset 并在 Express 引擎接线（但极速模式无 MITM 注入点，故前者为正解）。
- **备注**：`CosmeticRuleManager` 的 dataset 硬编码与 O-102（`RuleOperationWorker` 硬编码 AppDatabase）同型但**不同文件、且本条经可达性验证**，故升级为确认缺陷；同一硬编码模式还有 `ui/apprule/AppRuleViewModel.kt:27`（O-130 已登记，因其路由不可达而未升级——本条的差异正在于路由可达）。

---

## A-076 默认开启的「绕过局域网」IPv4 补集枚举漏掉 116–119/8 与 122–123/8：约 1 亿在用公网 IP 的直连流量完全绕过 VPN 隧道，全部管控承诺对其静默失效

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnTunnelManager.kt:172-184` — `if (bypassLan) { IPV4_BYPASS_LAN_ROUTES.forEach { builder.addRoute(addr, len) }; addRoute(DNS_SERVER_V4, 32) }`；`:197-202` else 分支为全量 `0.0.0.0/0`
  - `:318-365` — `IPV4_BYPASS_LAN_ROUTES` 手写「公网补集」表：`112.0.0.0/6`（覆盖 112–115）、`120.0.0.0/7`（120–121）、`124.0.0.0/7`（124–125）、`126.0.0.0/8`——**116–119 与 122–123 无任何条目覆盖**
  - `:213-214` `establish()`；`:280` `bypassLan = SystemSettingsStore.isBypassLanEnabled(this)`；`ui/settings/SystemSettingsStore.kt:12` — `DEFAULT_BYPASS_LAN_ENABLED = true`（**默认开**）
  - 消费语义：Android `VpnService.Builder.addRoute` 是「命中该路由才进 TUN」，未被任何 route 覆盖的目的 IP 直接走物理网卡（与 `addDisallow`/排除路由无关——Android 无排除路由原语，补集枚举是此模式的唯一手段）
  - **独立覆盖校验**（本地脚本按逐 route 对 0–255 全部第一字节做掩码匹配）：未完全覆盖的第一字节恰为 `0,10,116,117,118,119,122,123,127,169(254 段),172(16-31 段),192(168 段),224–255`——除 116–119、122–123 外全部是有意的 RFC1918/回环/链路本地/组播保留段
  - 受影响面：116/8、117/8（中国电信 CN2/163 大众段）、118/8、119/8（移动/联通）、122/8、123/8（联通/网宿等）——中国境内 CDN、云厂商、大量自建服务的活跃地址空间
  - 对照 Express：`express/ExpressTunnelManager.kt:214-225` 走「窄路由 + 劫持 IP 逐条 /32」设计，不用本表——**NORMAL 模式专属缺陷**
- **机制/影响**：`bypassLan=true`（默认）下，目的 IP 落在 116–119/122–123 的连接**完全不进用户态栈**：域名规则的连接级复核、HTTPS MITM（`engine_mitm` 全链）、QUIC/DoT:853 阻断（`engine_full_tunnel.go:217,270`）、禁止联网按 UID 阻断（`isUIDBlocked`）、`TrafficStatsManager` 的 Go 计流全部不触发——而这些能力正是普通模式的产品承诺。App 硬编码 IP、直连 CDN IP、部分 P2P/测速流量可整体逃逸。
  - 为何现场不炸（反证成立）：绝大多数浏览走域名→DNS 阶段已被 NXDOMAIN/黑洞拦下，用户看不到 IP 层逃逸；IPv6 侧 `2000::/3`（`:187`）整体捕获不存在枚举问题——v4/v6 行为不对称正说明 v4 表是手写疏漏而非有意设计（v4 表里 169/172/192 的细粒度补集显然按「排除私网」意图认真算过，唯独这两组大段漏了）。
- **触发路径**：默认安装开 VPN → 用 `adb shell` 或某 App 直连 `116.***.***.***` 类地址（如某些 CDN 的边缘节点 IP、`122.***.***.***` 域名解析后的直连）→ `dumpsys connectivity` /抓包见该流走 wlan0 不进 tun0；对照组 `114.xxx`（112/6 覆盖）走 tun0。
- **复现/验证**：纯函数级单测即可定案：对 {116,117,118,119,122,123}∪{0..255} 做逐 route 匹配断言全覆盖（当前 6 个字节段 MISS）。修复：补 `116.0.0.0/6`（116–119）与 `122.0.0.0/7`+`124` 重排，或直接改 `112.0.0.0/4` 覆盖 112–127 再精确挖掉 124–125/126–127 既有段；改完必须全 0–255 掩码回归（防再次手误）。
- **备注**：本条与 A-012（IPv6 探测死代码）同在 `establishVpnInterface`，修复路由表时可一并复核。禁止联网/家长控制在此段的失效是**安全语义级**，严重度定为高。

---

## A-077 HTTPS 检查按「缓存的证书就绪位」决定本次会话是否 MITM，异步真校验发现证书已卸载后不回滚运行中的隧道

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/normal/DnsVpnService.kt:240-245` — `inspectionRequested = inspectionConfigured && tunnelManager.isHttpsInspectionCertificateInstalled(this)`（同步、读缓存）；`if (inspectionConfigured) verifyHttpsInspectionCertificateAsync(this, serviceScope)`（异步真校验，**结果不参与本会话决策**）
  - `normal/DnsVpnTunnelManager.kt:49-51` — `isHttpsInspectionCertificateInstalled` = `AppRulesSettingsStore.isHttpsInspectionReady(context)`（纯偏好缓存）
  - `:57-64` — `verifyHttpsInspectionCertificateAsync`：`GoInspectionCaManager.isInstalled` 查真实 AndroidCAStore；失败仅 `setHttpsInspectionReady(false)+setHttpInspectionEnabled(false)`——**不触碰运行中的 engine、不 restart**
  - 生效点：`:269-270` `activeInspectionPackages = if (inspectionRequested) …` → `startTunnel(inspectionEnabled=…)` → `GoInspectionTunnel.kt` `startStackMitm`
- **机制/影响**：用户从系统设置删掉本 App 的 CA 根证书后立即开 VPN：缓存仍为 true → 本会话照常 MITM → 客户端 App 校验链里已无该根 → 目标 App TLS 握手失败/证书告警（浏览器红锁、App 报网络错误）；异步校验随后把开关置灰，但隧道不重启——「通知显示已连接、HTTPS 检查显示已关、流量却仍被 MITM 掐死」三相矛盾持续到下次手动重连。
- **反证（为何现场少报）**：缓存位平时准确（证书装/卸都同步更新），仅「上次刷新与本次启动之间证书被移除」窗口触发——删证书本就是低频操作，且多数用户删证书是因为不再用该功能。
- **触发路径**：装好 HTTPS 检查并运行过 → 系统安全设置删除 DITING CA → 开启 VPN → 目标 App（如某银行/购物）访问被检查域 → 证书错误。
- **复现/验证**：单测方向：mock `isHttpsInspectionReady=true` + `GoInspectionCaManager.isInstalled=false`，断言异步回调后触发 `restartVpnLocked`/`stopStackMitm`（当前无任何引擎侧动作）。修复：异步校验失败且本会话 `inspectionRequested==true` 时回调 `configManager` 重下发（走 `refreshRuntimeConfig` 既有热路径或按需重启）。

---

## A-078 编辑排除/禁止联网/HTTPS 检查名单触发全量 VPN 重启，`TrafficStatsManager.start()` 无条件把「本会话」流量与时长清零并瞬断（allowlist 同类编辑却走热更新，口径不一致）

- **位置**
  - 链：`ui/blockedapps/BlockedAppsScreen.kt:55`、`normal/ui/AppRuleViewModel.kt:99,321`、`data/cleanup/DataCleanupManager.kt:380,389,399` → `core/rule/RuntimeDnsSettingsRefresher.kt:160-170`（ACTION_REFRESH_APP_EXCLUSIONS）→ `normal/DnsVpnService.kt:133` → `normal/DnsVpnRuntimeConfigManager.kt:175-186`（`refreshAppExclusions` → `onRestartVpn()`）→ `DnsVpnService.kt:345-349` `restartVpnLocked`（stop→`startVpn(startIntent)`）→ `:320-322` `TrafficStatsManager.start(this, true)`
  - `core/traffic/TrafficStatsManager.kt:84-97` — `start()` 无条件 `sessionStartTime.set(now); sessionTxTotal.set(0); sessionRxTotal.set(0); sessionAppBytes.clear()`（`:97` 注释自认「restartVpnLocked path can call start() again without a stop()」）
  - 不一致对照：同文件 `:189-205` `refreshAppAllowlist` → `goInspectionTunnel?.syncAppAllowlist(rules)` **热更新不重启**；而排除应用必须重启有其客观原因——`addDisallowedApplication` 在 `establish()` 时固化（`DnsVpnTunnelManager.kt:204-211`），无法热改
- **机制/影响**：用户在 VPN 运行中「把一个应用加进排除列表/禁止联网名单」这类**普通编辑操作** → TUN 重建（秒级黑洞，正在下载的东西断流重连）+ 「本会话 ↑/↓ 字节、已连接时长、各应用本会话排行」全部静默归零。日累计有 dbSyncer 持久化不丢，但「本会话」面板语义被一条编辑摧毁；用户无任何提示（无 toast、无日志页事件）。allowlist 同类操作无此代价，同一屏内两种名单行为分叉，用户无从预期。
- **反证（为何不算设计意图）**：若「重连即新会话」成立，则系统网络切换重连清零合理；但此处触发源是**本地列表编辑**，产品文案（`ui/traffic/` 页面「本会话」）与实际行为矛盾；且 restart 路径 `startVpn(startIntent)` 重放旧 intent 还有 O-103/存疑-b 的会话配置重解析问题。
- **触发路径**：开 VPN → 流量页记一会话数据 → 返回把任一应用加入「排除应用」 → 回流量页：计数与时长归零、连接瞬断。
- **复现/验证**：Robolectric/单测：`TrafficStatsManager.start()` 前后 session 字段（当前必清零）。修复方向：restart 路径把「会话保持」交给调用侧——`restartVpnLocked` 增加 `preserveSession` 参数（编辑类重启不清 sessionTx/Rx/startTime，仅重建 TUN 与 disallowed 列表）；或 start() 拆分 `ensureRunning()`（首次初始化）与 `reattach()`（重建不重置）。
- **备注**：存疑-a/b（provider intent 不可达 + refresh 丢弃运行时自定义上游）与 d（restartVpnLocked 释放顺序不对称）见 O-141/O-142。

---

## A-079 极速模式「缓存设置」屏四处 Store 调用全部漏传 dataset：读写打到 NORMAL prefs，极速引擎永不感知，改动反而偷改普通模式

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/CacheSettingsScreen.kt:37`（屏收 `dataset: RuleDataset = RuleDataset.NORMAL` 参数）、`:41`（仅用它判 `isDnsMode`）——非 DNS_MODE 分支的四处调用 **`:45` `DnsCacheSettingsStore.isCacheEnabled(context)`、`:51` `getDnsCachePreset(context)`、`:61`/`:72` `setDnsCachePolicy(context, …)` 全部不传 dataset**
  - `ui/settings/DnsCacheSettingsStore.kt:28,39,61,72` — 四方法签名 `dataset: RuleDataset = RuleDataset.NORMAL`：缺省即 `datasetPrefs` → NORMAL=`dns_vpn_prefs`（分库路由 `data/RuleDataset.kt` 家族，A-016/O-106 已证同名 key 分文件语义）
  - 挂载证据：`main/MainModeDispatcher.kt:60` — Express 主页 `onNavigateToCacheSettings = { onNavigateToSettings(Routes.CACHE_SETTINGS, RuleDataset.EXPRESS) }`；`SettingsRouteActivity.kt:430` 把 `requestedRuleDataset` 传入屏（屏却只在 isDnsMode 三分法里用了它）
  - 引擎读取端：`express/ExpressVpnService.kt:120` — `cachePolicyProvider = { DnsCacheSettingsStore.getDnsCachePolicy(this@ExpressVpnService, RuleDataset.EXPRESS) }`（**只认 diting_express_prefs**）；初始值由 `express/ExpressDefaultsSeeder.kt:68` `setCacheEnabled(appContext, true, RuleDataset.EXPRESS)` 种入
- **机制/影响**（三观察面）：
  1. 极速模式缓存屏显示/修改的是**普通模式**的策略：在极速里关掉「本地 DNS 缓存」，`diting_express_prefs` 不变 → 极速引擎照旧命中缓存（用户以为关了，日志仍见 cached=true）；
  2. 这次修改**实际写进 `dns_vpn_prefs`** → 切回普通模式后 `DnsVpnRuntimeConfigManager.refreshRuntimeConfig`（`:90`）读到被极速界面偷改的值，普通 VPN 的缓存防护行为**无声突变**；
  3. 保存后 `onRuntimeDnsSettingsChanged()` 触发的 ACTION_REFRESH 让极速引擎重读 EXPRESS prefs——值没变 → 「保存成功但什么都没发生」的假象闭环。
  - 为何现场不炸：值恒为合法布尔/枚举，屏自身读写一致（都打 NORMAL），功能降级静默无报错。
- **触发路径**：极速模式主页→功能聚合→缓存设置→关开关/换档位→回极速主页抓 DNS 日志仍显示 cached；再开普通模式 VPN 比对缓存行为与设置页显示错位。
- **复现/验证**：debug 包 `run-as` 切极速缓存开关 → `dns_vpn_prefs.xml` 的 `dns_cache_enabled*` 变、`diting_express_prefs.xml` 不变（当前行为）；修复后应相反。修复 = `:45/51/61/72` 补传 `dataset`（isDnsMode 分支已示范正确取值）。
- **备注**：同屏 `isDnsMode ? DnsModeManager.config` 分支写法说明作者完全清楚 dataset 语义，EXPRESS/NORMAL 二分支漏传是纯笔误。

---

## A-080 `AgentAnalysisSheet` 硬编码 NORMAL 库与 NORMAL 广播：极速模式 DNS 缓存页的 AI 分析读错日志库，加白/黑名单「热更生效」提示为假

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/agent/AgentAnalysisSheet.kt:95` — `val database = remember(context) { AppDatabase.getInstance(context) }`（NORMAL=diting_database，无 dataset 参数）；`:126/:137` 近期流量统计、`:141` http_request_log 全打该库
  - 挂载错位：`ui/DnsCacheScreen.kt:88` 屏自身按 dataset 取库（`RuleDatabases.forDataset`，列表显示极速库缓存），`LogRouteActivity.kt:120` 允许 dataset=EXPRESS 进入（`express/ui/ExpressMainScreen.kt:249`→`ExpressLogDashboardScreen` 导航链）；`:150` AutoAwesome 按钮 → `AgentAnalysisSheet(target=RecentTraffic)` **无 dataset 传入**
  - 写规则：`:312` `AllowListManager(database.allowRuleDao(), scope = RuleScope.DNS).addRule(domain)`、`:329` `BlockListManager(database.blockRuleDao(), …)` — 写进 **NORMAL** 库
  - 热更：`:315/:332` `RuntimeDnsSettingsRefresher.syncRuleIfRunning(context, "allow"/"block", domain, RuleScope.DNS)` — **dataset 缺省 NORMAL**（`core/rule/RuntimeDnsSettingsRefresher.kt:75`），`:78-90` when 分支 NORMAL 走 `isNormalRunning`，极速运行时**为 false → 直接 return**：ACTION_EXPRESS_SYNC_RULES 永不发出
  - UI 提示：`AgentAnalysisSheet` 成功分支文案「已加入…并生效」类（对照 DnsCacheScreen `:262-268` 长按域名加白路径）
- **机制/影响**：极速模式运行中，在极速自己的 DNS 缓存页用 AI 分析→加白名单：规则落进普通模式库、极速引擎既读不到（读 EXPRESS 库）也收不到同步广播——**拦截照常、提示是假的**；「网络流量分析」面板展示的也是普通模式的历史日志（或空），与用户正在排查的极速流量张冠李戴。
- **反证（为何主路径不炸）**：RequestLogScreen/AgentApiSettingsScreen 的常规入口都在普通模式，AppDatabase+NORMAL 广播恰好全对；极速日志台→DNS缓存→AI 分析这条链是唯一错位组合。
- **触发路径**：极速模式运行且拦截某域 → 日志→DNS 缓存→右上角 AI 图标→「加入白名单」→ 成功提示 → 该域在极速下仍被拦；Express 规则管理页查无此条；`diting_express` allow 表无新增。
- **复现/验证**：Robolectric：dataset=EXPRESS 场景调 `syncRuleIfRunning`（缺省 NORMAL）断言无 Express intent 发出（当前）；修复 = Sheet 增 `dataset` 参数，database 改 `RuleDatabases.forDataset(context, dataset)`、两处 syncRuleIfRunning 与 Manager scope 传 dataset（对照 `ui/DnsCacheScreen.kt:92` 已有正确写法可抄）。
- **备注**：与 O-102/O-130 同型（硬编码 AppDatabase），本条升级为确认缺陷的依据是**用户可达链已验证**（LogRouteActivity dataset 传递 + ExpressMainScreen 入口）。

---

## A-081 极速模式「动态拦截策略」开关可开可存但 `express/` 全包零读取：功能纯空转，副标题谎报「先 NODATA 后 NXDOMAIN」

- **位置**
  - 写链完整：`express/ui/ExpressRuleControlScreen.kt:128-136` 渲染动态开关与参数 → `ui/settings/RuleSettingsAccess.kt:67-77` dataset 路由到 `AppRulesSettingsStore.setDynamicBlockResponseConfig(context, config, EXPRESS)`（diting_express_prefs，存取本身正确）
  - 零消费证据：grep `express/` 全包（含 `ExpressDnsEngine.kt:26,103`、`ExpressVpnService.kt:118`）只读 `blockResponseModeProvider`（静态模式），无 `getDynamicBlockResponseConfig`/`DynamicBlockResponseTracker` 任何命中
  - 对照 NORMAL 有真消费者：`normal/DnsVpnRuntimeConfigManager.kt:98/109` 把 dynamic config 传进 Go 隧道（`tunnel/dns_config.go` `dynamicResponse` 生效）
  - UI 承诺：`normal/ui/RuleControlScreen.kt:170-177` 副标题「动态策略：先 NODATA，高频请求后 NXDOMAIN」（极速屏经 RuleSettingsAccess 共用同一组件文案）
  - 桩件旁证：`core/rule/DynamicBlockResponsePolicy.kt:26-41` `DynamicBlockResponseTracker` 本身只 clear 不 record（Kotlin 侧从未实现计数），NORMAL 靠 Go 实现——极速/DNS 都没有 Go 隧道可借
- **机制/影响**：极速用户开启动态策略并设阈值：prefs 落盘成功、界面显示生效中，实际拦截响应恒为所选静态 RCODE（先 NODATA/升级逻辑不存在）；重启服务亦不变（根本没有读取端）。与 A-023（DNS_MODE 的 `applyDnsConfig` 漏 JSON 键——**有读取端但没喂数据**）不同：本条 EXPRESS 连读取端都不存在，属**引擎未实现**，修复工作量也不同（A-023 补一个键，本条要在 ExpressDnsEngine 里实现整套频率升级或明确砍掉极速侧入口）。
- **触发路径**：极速模式→规则管控→拦截响应→开动态、阈值 2 → LAN 无关，本机高频查询被拦域名 → 应答 RCODE 恒定不变。
- **复现/验证**：静态 grep 即闭环（express 包零读取）；修复方向二选一：ExpressDnsEngine 实现 tracker+升级响应，或 Express UI 隐藏动态入口并注释「仅普通模式支持」——两案都比现状（静默空转）诚实。

---

## A-082 普通模式「日志保留天数」改后不触发运行时刷新：运行中引擎继续按旧 volatile 快照 prune（同屏日志模式项正确触发，对照即证据）

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/ui/LogRetentionSettingsScreen.kt:193-203` — 天数项 onClick：`SystemSettingsStore.setLogRetentionDays(context, days, dataset)` 后**无** `onRuntimeDnsSettingsChanged()`
  - 对照 `:168-172` — 日志模式项 onClick：`setDnsLogMode(…)` 后**有** `onRuntimeDnsSettingsChanged()`（同屏同构控件，一有一无即疏漏而非设计）
  - 快照消费链：`normal/DnsVpnService.kt:101` — `activeLogRetentionDays = { configManager.activeLogRetentionDays }`（volatile 快照）→ `normal/DnsVpnDatabaseComponents.kt:119/125` 传给 `LogMaintenance`；该字段仅在 `refreshRuntimeConfig`（`normal/DnsVpnRuntimeConfigManager.kt:96`）重读
  - 极速侧无此问题：`express/ExpressTunnelManager.kt:286-289` provider 每轮现读 prefs（Lambda 直通）
- **机制/影响**：VPN 运行中把保留期 30→1 天：内存快照仍 30，旧数据继续按 30 天保留（用户想省空间不生效）；1→30：仍按 1 天删（**用户以为数据保住了，实际持续被删**——方向上更危险）。直到下一次任意触发 refresh 的设置变更或重连才纠偏；日志量大的设备「1→30 仍被删」窗口可长达数天。
- **触发路径**：开 VPN、日志保留设 1 天、跑两天攒日志 → 改 30 天 → 等一轮 prune → 老日志仍被删。
- **复现/验证**：单测：`setLogRetentionDays` 后断言 `configManager.activeLogRetentionDays` 已更新（当前旧值）；或按 A-082 修复：onClick 补 `onRuntimeDnsSettingsChanged()`。一行修复，优先级不高但语义明确。
- **备注**：dataset 传参本身正确（`SystemSettingsStore.setLogRetentionDays(context, days, dataset)`），本条纯是**缺刷新调用**，与 O-103（下发失败分支不对称）是两处独立问题。

---

## A-083 SAF 持久读授权只取不还：全仓 5 处 `takePersistableUriPermission`、0 处 `releasePersistableUriPermission`，删图/删订阅/全面清理后授权永久残留

- **位置**
  - 取授权（全部只 `runCatching` 吞异常，从不配对释放）：
    - `Android/app/src/main/java/com/haoze/diting/ui/CustomBackgroundSettingsScreen.kt:83`（背景图选择）
    - `ui/AddSubscriptionScreen.kt:94`（本地订阅文件）
    - `ui/RuleManagementViewModel.kt:78,160`（本地规则/hosts 导入）
    - `ui/SubscriptionViewModel.kt:176`（本地订阅导入）
  - 全仓 grep `releasePersistableUriPermission` → **0 命中**
  - 对应「移除」操作存在且不回收授权：`ui/settings/AppearanceSettingsStore.kt:154-166` `removeCustomBackgroundUri` 只改 `custom_background_uri/uris` 键；`core/rule/SubscriptionManager.kt:521` `deleteSubscription` 只删 DB 行；`data/cleanup/DataCleanupManager.kt` `clearAllLocalData` 删 prefs/DB/文件——SAF 授权按 URI 记在**系统** `content` 权限表中，与 app 自身数据无关，全部不随之撤销
- **机制/影响**：Android 的 persistable URI 授权跨重启存续、卸载才清（部分 ROM 连卸载都残留记录）。用户「删除这张背景图」「删除这个本地订阅」「全面数据清理（恢复出厂观感）」之后，DITING 对这些 content URI 指向的用户文件（图片/文本，可能含隐私内容）的**读权限在系统层面永久保留**：系统设置→应用→权限里可见「可访问的文件」只增不减；用户以为已撤销的授权实际从未收回。属隐私语义缺陷（授权面失控），非功能故障。
- **触发路径**：选 10 张背景图再逐一删除 → `adb shell dumpsys content` 或在 DocumentsUI 权限页看 DITING 的持久授权列表仍含全部 URI。
- **复现/验证**：Robolectric/真机：take → removeCustomBackgroundUri → 对新上下文 `contentResolver.persistedUriPermissions` 仍含该 URI（当前）。修复 = 在 `removeCustomBackgroundUri`、`deleteSubscription`（本地文件类）、`clearCustomBackground`/`clearAllLocalData` 对应路径调用 `releasePersistableUriPermission(uri, FLAG_GRANT_READ_URI_PERMISSION)`（需 try/catch：部分 URI 本非 persistable）。
- **备注**：take 时未校验返回 URI 是否真支持 persist（`FLAG_GRANT_PERSISTABLE`）——失败被 runCatching 吞掉后规则照常保存，跨重启读取将抛 SecurityException，属同一族的输入面问题（settings 代理存疑-4 亦指向此处，一并修复）。与 A-016（prefs 键删错文件）互斥独立：那条说 URI 列表留在 prefs，这条说授权本身在系统层泄漏，两者修复不重叠。

---

## A-084 DNS 模式「使用向导」局域网接入信息硬编码端口 1053，从不读 `localListenPort`：改端口后向导指引用户把所有 LAN 设备配到错误端口

- **位置**（端口 1053 以字面量出现 5 处，全仓 grep `onboarding/*.kt` 实证；向导代码零引用 `DnsModeManager`/`localListenPort`，grep `localListenPort` 在 onboarding 包命中 0）：
  - `onboarding/ModeOnboardingSteps.kt:316` — `localIps.joinToString(" / ") { "$it:1053" }`（「本机局域网服务接入信息」卡片，含一键复制交互的显示文本）
  - `onboarding/ModeOnboardingSteps.kt:361` — 「…并将端口设为 1053（标准设备可使用路由器 DNS 转发）」
  - `onboarding/ModeOnboardingSteps.kt:140` — 「服务器模式仅在本地 1053 端口提供局域网服务…」（免 VPN 声明）
  - `onboarding/ModeOnboardingModels.kt:162` — 「本机直接监听 0.0.0.0:1053（UDP/TCP）…」
  - `onboarding/ModeOnboardingModels.kt:187` — 「服务默认在端口 1053 监听…」
- **机制**：`localListenPort` 用户可改：设置页 `server/ui/DnsMainScreen.kt:232-238` 经 `DnsPortEditDialog` 保存任意端口，验证器 `server/model/DnsListenPortValidator.kt` 允许 1024–65535；引擎按真实端口监听（`server/backend/DnsServerEngine.kt:38-46` `startStandalone(port)`）。而向导步骤内容全部来自静态 `ModeOnboardingRegistry.getConfig(mode)` 文案 + `localIps` 拼接，`ModeOnboardingActivity` 只把 `NetworkInfoProbe` 的 IP 列表传入（`:93-98`），没有任何一条路径读 prefs 里的端口。设置页 `server/ui/DnsSettingsScreen.kt:100` 显示 `${config.localListenPort}` 真实值——同一事实两个界面一个动态一个写死，即口径分裂。
- **触发路径（可达性已核）**：向导并非一次性：`ui/SettingsSearchCatalog.kt:45` 把 `Routes.USAGE_WIZARD`（「使用向导」）注册进设置搜索目录，`SettingsRouteActivity.kt:96-100/210-213/514-518` 三处随时可重新打开 `ModeOnboardingActivity`。用户流：改端口为 8053 → LAN 设备照设置页配置正常 → 某日按设置搜索重开向导复习配置 → 向导显示 `192.168.x.x:1053` → 把设备 DNS 改回 1053 → 该设备解析全部超时（本机已不监听 1053）。
- **用户可见影响**：向导的核心承诺「教你把其他设备接进来」在端口被修改后系统性给出错误配置指令，且用户无从察觉错误来源（文案通篇以事实句呈现，无「默认」限定——`:187` 那句虽有「默认在端口 1053」字样，但 `:316/:361/:140` 三处均为无条件陈述，`:316` 更是可复制的「接入信息」卡片）。
- **复现/验证**：真机或 Robolectric：`DnsModeManager.updateConfig(config.copy(localListenPort = 8053))` → 打开 USAGE_WIZARD 到第三步 → 接入信息卡片显示 `…:1053`（预期 `…:8053`）。单测层面 `ModeOnboardingSteps` 的文案拼接可参数化后断言。修复方向 = 向导渲染时把 `1053` 替换为 `DnsModeManager.config.value.localListenPort`（Activity 已持有 context），或在 `ModeOnboardingActivity` 把端口作为参数下传。
- **备注**：与 A-022（`loadConfig` 每次把 5353/5354 强改 1053）方向相反且互斥独立：A-022 是端口值被迁移逻辑篡改，本条是向导展示层无视端口值；两者可共存叠加（用户设 8053 → 显示 1053）。`ModeOnboardingSteps.kt` 414 行、`ModeOnboardingModels.kt` 204 行，均在 550 行限内，拆分无约定障碍。首屏 `localIps` 异步探测失败时显示「未连接 Wi-Fi…」占位（`:316` 的 else 分支），该降级本身正确，不另计。

## A-085 `countingConn` 内嵌接口吞掉 `CloseWrite`：全隧道 TCP 半关闭永久失效（EOF 定界协议双向僵死）

- **位置**：`Android/tunnel/traffic_tracker.go:105-109` — `type countingConn struct { net.Conn; tracker; uid }`，内嵌的是 **`net.Conn` 接口**（方法集只有 Read/Write/Close 等接口声明），Go 接口内嵌**不提升**具体类型才有的方法（`CloseWrite` 属 `*gonet.TCPConn`/`*net.TCPConn` 特有）；`tcp_stack_handlers.go:95-114` `bidiCopyFlow` 以 `if cw, ok := a.(interface{ CloseWrite() error })` 探测能力；`mitm_passthrough.go:81` `bidiCopyFlow(clientConn, remote)` 的 `clientConn` 即包装体（包装点 `engine_full_tunnel.go:246/275`、`mitm_handler.go:59`；`WrapClientConn` 仅 `uid<=0` 不包，Android 上多数流 uid 可解）。
- **机制/影响**：第二个 goroutine `io.Copy(a,b)` 结束后探测 `a.(CloseWrite)` 恒 false → 服务器先关写方向（FIN/EOF）、等客户端读完再关的半关闭模式下，App 侧收不到 FIN；而 `io.Copy(b,a)` 又在等 App 先关 → 双向僵死直到 App 自身超时。期间 gVisor endpoint、两条 relay goroutine、远端 socket 全部滞留。HTTP 无 Content-Length 应答、SSE、FTP、邮件协议实测会挂；文件头注释（`tcp_stack_handlers.go:5`）「TCP Half-Close: bidiCopyFlow supports half-close」对生产路径为假。`mitm_passthrough.go:94-103` 同型探测同型失效。
- **触发路径**：全隧道模式访问以 FIN 定界响应的端点（`Connection: close` 无长度头，或 SSE 客户端等 EOF）。
- **复现/验证**：Go 单测：`_, ok := any(&countingConn{Conn: c}).(interface{ CloseWrite() error })` 断言当前 ok==false；或 net.Pipe + EOF 应答服务，断言客户端读不到 EOF。修复 = countingConn 显式提升 `CloseWrite`/`CloseRead`（类型断言转发内嵌 Conn）。
- **备注**：`tcp_stack_handlers.go:51`（legacy 无包路径）不受影响——它传入未包装的 conn；缺陷恰在「有流量统计的新路径」上，与 O-135（Express protectSocket）无关。

## A-086 `bufferedTun.drain` 一次写错误永久停摆出站面：`Write` 恒报成功掩盖黑洞

- **位置**：`Android/tunnel/engine_full_tunnel.go:56-67`（`Write` 入队失败即 `default:` 丢包，**恒返回 `len(p), nil`**）、`:69-85`（`drain` 收到 TUN 写错误 → `logf` 一行 → `return`，无任何重启）、`:87`（`halt()` 仅由 `:176/:198` 会话收尾调用）。
- **机制**：Android 网络切换/接口 flap 时向 tun fd 写入返回 ENETDOWN/EINVAL 是现实来源；drain 协程永久退出后，gVisor 栈仍从 `Write` 得到「成功」回执，出站包进 2048 深队列→满→无声丢弃；App 侧 TCP ACK/数据与 serveDNS 回包从此黑洞，栈按「已送达」持续指数重传。用户表现 = 切换网络后 App 全部连不上/卡死，关掉再开 VPN 才好。legacy `packetPipe` 同型（`engine_mitm.go:124-137` 首错 `return`）。
- **触发路径**：真机 Wi-Fi↔蜂窝 handover 期间持续下载；logcat 出现 `StartFull: TUN drain write error, stopping writer` 后无任何恢复日志。
- **复现/验证**：把 `*os.File` 抽成接口注入首次写失败，断言 drain 应能重启（当前不能）；或注入恒错 writer 断言 `Write` 应向上返回错误（当前恒 nil）。修复 = drain 出错退出时关闭 stop/置位错误标志，使 `Write` 返回错误让 gVisor 感知，或重建 drain。

## A-087 `SetBlockEncryptedDns` 死开关：853 恒硬拦，UI 开关与日志归因双双失真

- **位置**：`Android/tunnel/engine_full_tunnel.go:285-287`（Store）、`engine.go:93`（声明）——全仓 grep `blockEncryptedDNS` **无任何 Load**；消费点 UDP `:217-220`、TCP `:270-273` 无条件丢弃并记 `blocked_encrypted_dns`；`engine_mitm.go:62-67` 同型。Kotlin 侧：`normal/GoInspectionTunnel.kt:368` 每次启动如实透传，`ui/settings/AppRulesSettingsStore.kt:291-293` 默认 **false**，`normal/ui/HttpInspectionSettingsScreen.kt:200-212` 提供「阻断加密 DNS (DoT)」开关、副标题「阻断 TCP 853 端口，防止绕过域名规则」。
- **机制**：用户把开关关掉（默认即关）→ Kotlin 传 false → Go 无读取点 → 853 仍被硬丢。Private DNS strict 模式设备/应用全部解析失败，而 UI 显示该功能未开启；日志归因 `blocked_encrypted_dns` 让排查者误判是用户主动阻断。
- **触发路径**：默认设置 → 系统 Private DNS 填 `dns.google`（strict）→ 所有域名解析失败。
- **复现/验证**：Go 单测：`SetBlockEncryptedDns(false)` 后走 UDP/TCP:853 handler，断言不应记 `blocked_encrypted_dns`（当前必记）。修复 = 消费点加 `if e.blockEncryptedDNS.Load()` 门（与 quicDrop `:231` 的 Load 用法对照即范例）。

## A-088 `BootstrapSelector` 漏传 dataset：极速模式整套 bootstrap 设置失效（A-079 同族、不同文件）

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/diagnostic/BootstrapSelector.kt:25-26` — `loadEnabledBootstrapIpEntries(context)`、`isBootstrapEnabled(context)` 均走默认参数 `dataset = RuleDataset.NORMAL`（`ui/settings/BootstrapDnsSettingsStore.kt:24/44`），而 `data/RuleDataset.kt:24-28` NORMAL=`dns_vpn_prefs`、EXPRESS=`diting_express_prefs` 分文件；构造点 `express/ExpressTunnelManager.kt:292` 未传（构造器也没有 dataset 参数），`ui/RaceModeSettingsViewModel.kt:51` 虽以 EXPRESS 构造 VM 但 Selector 同样读 NORMAL。
- **对照证据**：同族调用全部正确传 dataset（`BootstrapSettingsViewModel.kt:62-63`、`ConfigExporter.kt:100`）；写侧极速设置屏按 EXPRESS 写（`main/MainModeDispatcher.kt:44` → `SettingsRouteActivity.kt:421`）。
- **机制/影响**：极速引擎运行时永远拿普通模式的 bootstrap 集合——极速里「启用 Bootstrap」开关、预设勾选、自定义 IP 全部不生效；反向：普通模式关 bootstrap 会让极速 DoT/DoH 上游退化为系统解析（`express/engine/ExpressUpstreamDispatcher.kt:64-67` bootstrapAddresses 空→`InetAddress.getAllByName` 直连）。极速测速（RaceMode VM）测的是错误配置。
- **触发路径**：极速模式开/关 bootstrap → `ExpressDnsEngine.resolve` 行为不变；改 `dns_vpn_prefs` 反而变（adb 可断言 prefs 与解析日志）。
- **复现/验证**：Robolectric：EXPRESS prefs `bootstrap_enabled=false`、NORMAL prefs true → Express `resolveBootstrap` 仍返回解析结果。修复 = Selector 构造入参加 dataset 并透传两调用。

## A-089 `serveDNS` 缓存命中/stale 分支不续应用放行 IP 授权：白名单应用「解析成功、连接恒被拦」

- **位置**：`Android/tunnel/engine_standalone.go:296-312`（`serveDNS` hit 分支 `return`）、`:314-340`（stale 分支 `return`，后台 singleFlight 刷新亦绕开授权）、`:384`（唯一 `rememberAppAllowlistResponse` 调用点，仅在新鲜路径尾部）；闸门 `engine_app_allowlist.go:83-92`（按 `ips[uid][ip]` 的过期时间判连），授权期=rr TTL（`:117-128`）。
- **可达面（两条生产路径都中招）**：`serveDNS` 同时是服务器模式入口（`engine_standalone.go:25`）与全隧道 DNS 拦截入口（`engine_full_tunnel.go:332` UDP / `:395` TCP），而连接闸门在 `engine_full_tunnel.go:221/260` 与 `mitm_handler.go:43`——即 VPN 模式「DNS 应答」与「连接放行」共用这张授权表，非仅 standalone。`engine_dns.go:189/211/332` 是同型的 legacy `Engine.Start` 路径（生产无调用者，见 O-149），不作为本条证据。
- **机制**：授权表只在真实上游解析成功时写入。缓存命中/stale 续命期间上游不被触碰 → rrTTL（常 60s）过期而缓存仍在应答（FIXED/负 TTL 覆盖下应答期可远大于授权期；stale 窗口内后台刷新同样不写授权）→ 白名单应用对已允许域名「DNS 解析成功但 TCP/UDP 连接被 `app_allowlist_blocked`」，直至缓存彻底过期重走新鲜分支才自愈。日志只有连接行 `app_allowlist_blocked`，排查面误导。
- **触发路径**：strict 白名单 + 缓存 FIXED TTL 3600s + 上游 TTL 60s：查询一次 → 等 >60s → 发起 TCP → 被拦。
- **复现/验证**：Go 单测：预热 put 缓存 → 推进时钟 → 查询走 hit 分支 → 断言 `appAllowlist.ips` 过期时间被刷新（当前不刷新）。修复 = hit/stale 分支按 ipList 同规则续授权（期取 max(rrTTL, 缓存剩余期)）。

## A-090 `ApplyDNSConfig` 校验失败时部分配置已提交：「拒绝即回滚」承诺不成立

- **位置**：`Android/tunnel/dns_config.go:133-138` — 先持锁写 `e.responseType`/`e.dynamicResponse` 并 `e.dynamicBlocks.reset()`，随后 `:140-150` 才做 providers 校验（空/single 多上游/`validateDNSProvider` 任一失败 `return err`），而 `e.dnsConfig` 只在成功尾部落账（`:161-163`）。
- **机制/影响**：Kotlin 收到 error 视为整份拒绝（`DnsServerEngine.applyDnsConfig` runCatching），Go 却保留了**新**拦截应答类型与动态配置开关并清零动态计数；后续 `Start()/StartFull()` 用旧 `dnsConfig` 重建 resolver，应答类型却是新值——UI 显示与引擎行为漂移且无自愈点，动态拦截窗口被无端清零。
- **触发路径**：构造 `providers[1].protocol="bogus"` 的 JSON 调 `applyDNSConfig` → 返回错误 → 断言 `standaloneBlock` 默认 rcode 已变（当前会变）。
- **复现/验证**：Go 单测直接断言错误返回后 `e.responseType` 保持旧值。修复 = 全部校验前置，再一次性提交。

## A-091 `ProviderHealthEngine` 全仓零实例化：服务商健康页恒空、预测权重是编造均匀值

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/diagnostic/ProviderHealthEngine.kt:12`（构造器）——grep `ProviderHealthEngine(` 仅命中类声明本身，零调用点；`recordResult`（`:33`）零调用者；Go 侧 grep `provider_health` 零命中 → `ProviderHealthStore.saveAll`（`:91`）唯一写者永不运行。
- **消费链**：入口路由可达（`LogRouteActivity.kt:124` `Routes.PROVIDER_HEALTH -> ProviderHealthScreen`）；`ui/ProviderHealthScreen.kt:64-66` `flushActive`（`activeEngine` 恒 null → 恒 false）+ `loadAll` 恒空表；`:68-73` `predictionWeight ?: 1.0` → `normalizeWeightsToPercent` 对全部参与智能预测的服务商给等值权重——「权重 25%」是**未经任何测量的编造显示**；`ui/RaceModeSettingsViewModel.kt:111-113` 同源。`ProviderHealthStore.kt` 的 `hedgeMisses/decayedHedgeMisses` 及 cooldown 全为死代码（`hedgeMisses` 连写 API 都不存在）。
- **与 A-041 族关系**：同为「重构后接线缺失」，但表面不同——本条是 UI 谎报（页面渲染正常、无报错），用户只感知「每行暂无运行数据 + 看似有据的权重」；`?:` 兜底解释了「现场不炸」。
- **复现/验证**：真机进入健康页断言 attempts==0 且权重全等；修复 = 在实际上游解析完成处（`GoTunnelRuleManager`/`serveDNS` 回调或 Kotlin `DnsLatencyTester` 链）实例化并 `recordResult`。

## A-092 `BootstrapHealthEngine` 多实例全量覆盖 prefs：双源互抹健康数据与冷却状态

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/diagnostic/BootstrapHealthEngine.kt:17`（`healthByIp` 实例内存快照）、`:23`（`init{activeEngine=this}` 后构造者抢占单槽）、`:119-125`（`flush→saveAll` **全表 JSON 覆盖**）、`BootstrapHealthStore.kt:53-54`（固定 `dns_vpn_prefs` 单键，跨 dataset 同文件）。并存实例三处：`normal/DnsVpnDatabaseComponents.kt:100`（VPN 服务）、`ui/RaceModeSettingsViewModel.kt:47`（测速页）、`express/ExpressTunnelManager.kt:291`。写源：`normal/GoInspectionTunnel.kt:322`（服务引擎）与 `core/diagnostic/BootstrapSelector.kt:52/69`（VM/Express 引擎）。
- **机制**：两引擎各持构造时快照；VM 的 15s 定时 flush（`markDirty:160-167`）与 `onCleared→close→flush(commit=true)` 把 **VM 视角**的全表写回 prefs，整体抹掉期间服务引擎新记的成功/失败与 `cooldownUntil`；下次服务 flush 又反向回滚 VM 数据。`flushActive`（`BootstrapSettingsViewModel.kt:61`、`RaceModeSettingsViewModel.kt:111`）指向取决于谁最后构造——打开过测速页后它指向 VM。
- **用户可见影响**：Bootstrap 设置页健康统计（准确率/冷却）随机倒退忽好忽坏；冷却中 IP 状态丢失导致对已知故障 IP 反复降级重试。
- **触发路径**：开 VPN（Go 模式持续产生结果）→ 打开网络工具测速并停留 >15s → 退出 → 看 Bootstrap 设置页，服务引擎期间的记录消失。
- **复现/验证**：单测：A `recordResult(ip1,false)×3`，B 未见过 ip1 → B `flush(commit)` → 读回 prefs 断言 ip1 记录消失（当前实现）。修复 = 单实例化（DI）或 saveAll 改合并写（按 ipId 读-改-写）。

## A-093 Kotlin regex 规则匹配区分大小写，Go 恒 `(?i)`：双引擎对同一订阅给出相反结果

- **位置**：Kotlin `core/rule/BlockRuleMatcher.kt:233-234`、`core/rule/AllowRuleMatcher.kt:199-200` — `runCatching { Regex(rule.pattern).containsMatchIn(domain) }`（模式按用户原文存储：`AdblockRuleLineParser.kt:192-195` regex 分支 `domain = regexPattern!!` 不归一大小写；查询侧域名 lowercased）；Go `tunnel/policy_engine.go:112-113` — `if !strings.HasPrefix(rxPattern, "(?i)") { rxPattern = "(?i)" + rxPattern }`、`policy_matcher.go:33` 同。
- **机制/影响**：AdGuard 规范中 regex/域名匹配大小写无关（除非 `$match-case`，而 Kotlin 把 `match-case` 当 web-only 修饰 `isWebOnlyModifier→ignored`，`AdGuardDomainUtils.kt:25`——大小写敏感语义根本无法表达）。规则 `/Ads\..*/`：VPN 路径（Go `policyEngine.evaluate`，`engine_dns.go:187-200`/`engine_standalone.go` 同源判定）命中阻断；`DnsQueryFilter` 回调路径（`engine_dns.go:213-220` checker 兜底与 `DnsServerEngine` 的 DomainChecker）用 Kotlin 判定 → 不命中。同一订阅在服务器模式与 VPN 模式给出相反拦截结果，命中日志不一致。
- **触发路径**：订阅含大写字母的 regex 规则（如 Anti-AD 偶发 `/Ad[Ss]\d/` 类）→ 极速/服务器模式放行、VPN 模式拦截（或反向）。
- **复现/验证**：JVM：`Regex("Ads").containsMatchIn("ads") == false`；Go：`regexp.MatchString("(?i)Ads","ads") == true`。修复 = Kotlin 侧 `Regex(rule.pattern, RegexOption.IGNORE_CASE)`（保留大小写敏感须另行实现 `$match-case`，与 Go 对齐）。
- **备注**：Go 的 `(?i)` 无条件注入同样忽略 `$match-case`，属两侧共同缺口；本条缺陷是**分叉**本身（一注一不注）。

## A-094 `#$@#` 例外型元素隐藏未识别：`substringBefore('#')` 兜底把该域整站变成阻断规则

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/rule/AdblockRuleLineParser.kt:7` — `COSMETIC_DELIMITERS = listOf("#@#","##","#?#","#$#")`，缺规范中的 `#$@#`（domain-list 例外型元素隐藏，等价 `#@#`）；`:20-24` 识别失败后落入 `substringBefore('#')`；`:240-247` 定界符选择同缺。
- **机制**：`example.com#$@#.ad` → 非 cosmetic → 截 `#` 得 `example.com` → **生成 block 规则** `example.com`，整域拉黑；`example.com#$@##.ad` 形式则被 `##` 分支接走 → domain=`example.com#$`（`parseCosmeticLine:253-262` 不校验主机合法性）+ selector=`.ad`，例外语义丢失、scope 是垃圾串。
- **用户可见影响**：导入含 `#$@#` 例外行的 uBlock 风格列表 → 对应域名从「例外放行」反转为「整域阻断」，站点打不开；与 A-075（cosmetic 幽灵规则）同为 cosmetic 语法面但机制正交（本条在解析层，且后果是反向拉黑）。
- **复现/验证**：JVM 单测 `parseCategorizedLine("example.com#\$@#.ad")` 断言当前落入 `blockRules`（期望 `isException` cosmetic）。修复 = 定界符表补 `#$@#`（先于 `#@#`/`##` 判长）。

## A-095 regex 规则体内 `#` 被无差别截断：规则整条丢失且计为 invalid

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/rule/AdblockRuleLineParser.kt:24` — `var value = line.substringBefore('#').trim()` 早于 `:33-57` 的 regex 提取执行，cosmetic 预判（`:20-22`）只认四种定界符。
- **机制**：规范中 `/pattern/` 内 `#` 属模式字符。`/banner#1/` → value=`/banner` → `lastSlash==0` 不进 regex 分支 → 域名分支 `normalizeDomain("/banner")` 含 `/` 返回 null → `invalidCount=1`，规则静默丢失。
- **一致性反证（为何只列低）**：Go `tunnel/rule_compiler.go:193` 同样 `SplitN(line,"#")` 且 `:203` 直接拒绝 `/` 开头行——两端一致地丢，用户只见「规则无效」计数增加，无模式间行为分叉；`$comment` 与行尾注释场景使该截断不能简单移除。
- **复现/验证**：对 `/a#b/` 断言 invalidCount；再统计真实订阅中 regex 含 `#` 的丢弃率（低出现率解释了现场无反馈）。修复 = regex 定界（首尾 `/`）内不截 `#`（行尾 `$` 修饰符再截）。

## A-096 规则索引 `.tmp` 残留永久堆积 + `renameTo` 失败退化为非原子复制

- **位置**：`Android/app/src/main/java/com/haoze/diting/core/rule/MappedSubscriptionRuleIndex.kt:128-151` — `finally` 只删本线程 temp；`:137-143` `target.delete()` 失败仅 `Log.w`，`temp.renameTo(target)` 失败改 `temp.copyTo(target, overwrite=true)`（流式复制非原子）。`RuleIndexLayout.deleteAll`（`RuleIndexLayout.kt:85-91`）grep 全仓**零调用者**。`MappedSubscriptionRewriteIndex.kt:147-161` 同构同病。
- **机制/影响**：进程被杀（OOM/worker 崩溃）后 `block.trie.<nano>.tmp` 无人清理、无 TTL、无启动 glob 清理 → filesDir 永久堆积（单文件可达数 MB，×4 类 trie ×scope）；复制中途读端可见 magic 正确但 `sourceOffset+sourcesBytes != limit` 的半写文件——Kotlin `load` 的 `require` 抛错、Go `openDTRI`（`policy_dtri_reader.go:93-96`）返回 corrupted → `policy_engine.go:433-436` 记 `failed to open DTRI trie` 后 `snap.blockTrie=nil`：该轮订阅快照整体失去 trie，Go 侧无 Kotlin 的 fallback map → 依赖索引的订阅域名全部放行。
- **触发路径**：中断一次大订阅导入后 `adb shell ls files/rule-index/domain/` 见 `.tmp`；受限条件下 rename 跨失败时复制窗口可被并发读命中。
- **复现/验证**：单测注入 `renameTo` 失败断言 load 期间可见半文件；glob `rule-index/**/*.tmp` 无任何清理逻辑（grep 实证）。修复 = 启动/重建时删 `*.tmp`（或接入 `deleteAll`），复制走 temp+fsync+rename 双保险。

## A-097 AI 报告 Markdown 渲染吃作词内下划线：配置键名/包名在正文被改写变形

- **位置**：`Android/app/src/main/java/com/haoze/diting/ui/agent/MarkdownInlineAnnotator.kt:26` — 斜体分支 `(?<!_)_(?!_)[\s\S]+?(?<!_)_(?!_)` 的 lookaround 只排除**相邻**下划线（`__`），不排除词内下划线；`:132-138` 该分支输出时 `token.substring(1, token.length-1)` **吃掉两个下划线定界符**并斜体化。
- **机制/实证**（本机复算，Python `re` 与 Java/Kotlin `java.util.regex` 对本模式语义一致；对照表含 8 例）：纯文本 `dns_vpn_prefs` 命中 `_vpn_`（前后字符均非 `_`，lookaround 全过）→ 渲染为斜体 `vpn` 且**下划线消失**；`com_haoze_diting`→`_haoze_`、`KEY_LOG_QUERIES_MIGRATED`→`_LOG_` 同理。反例（代码段安全）：`` `dns_vpn_prefs` `` 整体先被 backtick 分支捕获、按 code 渲染——子代理原报「代码段被斜体化」不成立，被证伪后修正为「裸文本词下划线被吃掉+斜体化」。跨行 `[\s\S]+?` 还使孤对下划线（如两行各一个标识符下划线）可跨行配对成「斜体」吞字。
- **用户可见影响**：AI 分析报告正文中的 prefs 键名、常量名、包名（`dns_vpn_prefs`、`KEY_...`、`com_haoze_diting` 这类正是该 app 的常见内容）显示时缺下划线、局部斜体——信息失真且用户无从察觉来源；`ui/agent/MarkdownViewer.kt` 全链共用。
- **触发路径**：让 AI 分析结果正文含裸文本 `dns_vpn_prefs`（不加反引号）→ 打开分析弹层观察。
- **复现/验证**：JVM 单测 `formatMarkdownAnnotatedString("配置 dns_vpn_prefs 键", …)` 断言输出文本保留 `_`（当前丢失为 `配置 vpn 键` 斜体段）。修复 = 斜体分支补词边界（如 `(?<![\w_])_(?!_)[^_]+_(?![\w_])`）或按 CommonMark 规则排除 intra-word `_`。

---

## 观察（未达到确认缺陷标准，供后续验证）

### O-106 `StartupSelfCheck` 只消毒 NORMAL 偏好文件，Express/DNS_MODE 的同名键不覆盖
- `ui/settings/StartupSelfCheck.kt:22` 固定 `getSharedPreferences(PREFS_NAME)`（`SettingsPreferencesExtensions.kt:8` = `"dns_vpn_prefs"`）消毒 `dns_resolution_mode`/`preset_dns_service`/`bootstrap_custom_json`；而 `ResolutionSettingsStore.kt:107-121` 等实际经 `datasetPrefs` 按数据集分文件存储（`RuleDataset.kt:24-28`：NORMAL=dns_vpn_prefs，EXPRESS=diting_express_prefs，DNS_MODE=diting_dns_mode_prefs）。NORMAL 恰好同文件被覆盖，Express/DNS_MODE 的损坏值不会被清理。
- 未升级为缺陷：读取端本身安全（`getDnsResolutionMode` 对非法值 `?: SINGLE`，`getModeProviderIds` JSON 解析失败回落默认集），损坏值不致崩溃或错误行为，仅错过「修复落盘」的机会。确认方法：向 `diting_express_prefs` 注入非 JSON 的 `parallel_race_provider_ids`，跑自检后读回仍为损坏值（但功能已由 getter 兜底）。

### O-101 迁移 SQL 的 `DEFAULT` 与实体声明漂移（Room 容忍，非缺陷，仅规范卫生）
- `MIGRATION_1_2`/`DNS_RULES_MIGRATION_1_2` 建表带 `enabled INTEGER NOT NULL DEFAULT 1`（`AppDatabase.kt:56`、`DnsRulesDatabase.kt:49`，含 `cosmetic_rule_source` 的 `:66`/`:59`），`MIGRATION_2_3`/`EXPRESS_MIGRATION_1_2` 的 ALTER 带 `isException ... DEFAULT 0`（`AppDatabase.kt:79` 等）；而实体列均无 `@ColumnInfo(defaultValue)`（`CosmeticRuleEntity.kt:28-29`、`CosmeticRuleSourceEntity.kt:17`）。
- 曾疑为升级崩溃缺陷；回读 `room-runtime 2.7.0` 的 `TableInfoKt.equalsCommon` 后确认：ENTITY↔DATABASE 方向的默认值比较仅在**实体侧默认值非空**时才执行，实体侧为 null 即跳过，因此该漂移被 Room 容忍，校验通过。对照 `DnsCacheEntity.kt:25` 显式 `@ColumnInfo(defaultValue="0")` 的写法可知：若要消除漂移需给实体补对应 `defaultValue`，但当前不补亦不影响正确性。纯卫生项。

### O-102 `RuleOperationWorker.importCategorizedRules` 硬编码 `AppDatabase.getInstance`
- `RuleOperationWorker.kt:411` 取 `AppDatabase`，而 worker 其余部件按 `KEY_DATASET` 路由（`:145-151`）；`IMPORT_RULES`/`IMPORT_HOSTS_RULES` 的唯一入队点（`RuleManagementViewModel.kt:84,166`）未传 dataset（默认 NORMAL），当前不可达错位；若未来任何入口以 DNS_MODE/EXPRESS 入队这两类任务，URL/元素隐藏规则将写进普通模式库。设计耦合，暂列观察。

### O-103 `refreshRuntimeConfig` 失败分支提交的 `activeResolutionMode` 与 Go 侧不一致
- `normal/DnsVpnRuntimeConfigManager.kt:137-161`：`resolveDnsProviders` onFailure 时向 Go 回写 `providers=oldProviders` + `resolutionMode=activeResolutionMode(旧值)`（`:142`），但 Kotlin 随后仍提交 `activeResolutionMode=newResolutionMode`（`:153`）；成功分支对 `goSyncError != null` 会提前 `return@fold`（`:127`）保持两侧一致，失败分支不对称，可能留下「新档位 + 旧上游」组合显示在前台通知。
- 未升级为缺陷：`DnsVpnProviderResolver.resolveDnsProviders` 的兜底路径（`:71` `listOf(DnsProvider.loadSelected(context))`）实测难以抛错，未构造出确定性触发。确认方法：构造使 `resolveDnsProviders` 抛异常的配置（损坏的持久化上游设置），切换多上游档位后比对 Go 配置与 Kotlin 状态。

### O-104 start/stop 微秒级交错可能在 Kotlin 判定停止后遗留运行中的 Go TUN 栈
- `normal/GoInspectionTunnel.kt:91-99`：`start()` 在 `scope.launch(Dispatchers.IO){ engine.startFull(...) }` 后立即返回 true，不确认 `startFull` 已进入；若 `stop()`（`:101-107`，`engine.stop()`）在 IO 协程到达 Go `StartFull` 的 `e.mu.Lock()`（`tunnel/engine_full_tunnel.go:92`）之前执行，Stop 见 `running=false` 直接返回，随后 StartFull 置 `running=true` 并新建 done channel，无人再持有。
- 未升级原因：需要极快的 ACTION_STOP 或 IO 池饥饿才能命中，且 Kotlin 侧 `startJob?.cancel()` 若在 `startFull` 启动前生效可避免；无确定性触发。确认方法：start/stop 微压力测试轮询 `Engine.IsRunning()`。

### O-107 Kotlin 显示缓存把真实 TTL=0 的应答当「未知 TTL」落库，缓存统计页出现幽灵条目
- `core/cache/DnsResponseCache.kt:150` — `rawTtl = if (upstreamTtl > 0L) upstreamTtl else currentPolicy.maxTtlSeconds.coerceAtLeast(300L)`，随后 `effectiveTtlSeconds` 与 `expiresAt = now + effectiveTtl*1000`（`:166`）：`recordResolved(upstreamTtl = 0)` 的分支把上游**明确的 0 TTL**（`DnsCachePolicy.kt:37` FOLLOW 模式本应原样取 0，`:33` `effectiveTtlSeconds` 对 `<=0` 返回 0）与「没带 TTL」混为一谈，最终写入一条 `expiresAt≈now+maxTTL/300s` 的行。
- 触发链已核到底：Go `engine_dns.go:393-397` 对 `extractMinTTL` 返回 `(0, true)` 的应答置 `respTTL=0`；`log_aggregator.go:28` `json:"ttl,omitempty"` 使 TTL=0 在 JSON 中缺省；`normal/GoTunnelLogProcessor.kt:41` `optLong("ttl", 0L)` 读回 0，`:90` 调 `recordResolved(upstreamTtl = 0)`。Go 自身拒缓存该应答（`dns_cache.go` `effectiveTTL<=0 → return false`，每次查询都重新解析），Kotlin 行却长期「未过期」。
- 影响面有限（故列观察）：`DnsResponseCache.resolve/get/put/materialize` 已确认为死代码（全仓仅 `warmUp`/`recordCacheHit`/`recordResolved`/`clear`/`updatePolicy` 被调用），该行只进「DNS 缓存」展示/计数（`countUnexpired` 等），不改变实际解析。确认方法：FOLLOW 策略下 `recordResolved(name, type, "1.2.3.4", upstreamTtl = 0)`，断言 `getUnexpired` 不含该键（当前实现含）。修复方向：`recordResolved` 增加「TTL 缺失」与「TTL=0」的区分（如 Go 侧去掉 omitempty 或 Kotlin 用 `-1` 表示缺失）。

### O-108 共享 UID 应用在流量归因中坍缩为单一包名（Android 固有限制 + 主动截断）
- `core/traffic/TrafficAppResolver.kt:40` — `appInfoByUid[uid] = info` 对 `getInstalledApplications` 中同 UID 的多包**后写覆盖**；`:54` 对 `getPackagesForUid()` 结果取 `.firstOrNull()` 主动截断；Go 模式按 uid 归因（`:49`、调用点 `:186`）。
- 属 Android per-UID 统计的固有限制，且截断是显式选择；无多包共享 UID 的真实对照环境未验证，暂列观察。确认方法：安装一对共享 `android:sharedUserId` 的应用，制造流量后核对归因包名是否稳定取到「预期主包」。

### O-109 busybox/toybox `ping6` 若输出 `hoplimit=` 则逐项应答解析为空
- `core/diagnostic/NetworkPingTool.kt:248` — `REPLY_REGEX` 要求字面 `ttl=(\d+)`；注释（`:246-247`）已意识到 busybox 用 `seq=`（正则已兼容），但未覆盖 IPv6 常见的 `hoplimit=` 写法。若真机 `ping6` 打印 `hoplimit` 而非 `ttl`，逐序列应答列表为空，UI 显示「超时或无响应」（`:131-133`），而发送/接收/丢包/RTT 汇总仍解析正常（`:122-128`、`LOSS/TRANSMITTED/RECEIVED_REGEX`）。
- 未升级原因：需要一台 `ping -6` 实际输出 `hoplimit=` 的设备取证；toybox 现代版本多以 `ttl=` 统一输出。确认方法：`adb shell ping6 -c 2 <v6>` 观察应答行关键字。

### O-105 原生崩溃批量收集的文件名用写入时刻（ms），同毫秒可覆盖丢一份
- `crash/CrashLogManager.kt:53-54`：`saveCrashReport` 文件名 `crash_<yyyyMMdd_HHmmss_SSS>.log` 取的是**写入时** `Date()`，非崩溃标识；`checkAndCollectNativeCrashes` 在 `:320-341` 一个紧循环里最多迭代 10 条历史 `REASON_CRASH_NATIVE` 逐一落盘。两次迭代落入同一毫秒时，`FileOutputStream(file)` 截断覆盖前一份，历史原生崩溃静默丢失（现象：导出报告数少于待收集条数）。
- 未升级为缺陷：每次迭代含 `fos.fd.sync()` 与 `pruneOldLogs` 的 `listFiles`+排序，真机通常 >1ms，需多条待收集原生崩溃且存储极快才命中。确认方法：预置两条同 `timestamp` 的 `ApplicationExitInfo`，观察只落一份文件。修复方向：文件名追加 `index`/`pid`/`exitInfo` 指纹或用存在即改名的去重。
- 附带（非缺陷）：`CrashLogManager.kt:256-257` 的 `contains(X) || contains(X)` 两侧操作数相同，为无害复制粘贴；原生头 `DITING NATIVE CRASH REPORT` 不含 Java 子串 `DITING CRASH REPORT`，类型判定仍正确。

### O-110 后台停 VPN 时常驻监控通知可能静默不再出现（API 34+ FGS 后台启动限制）
- `normal/DnsVpnService.kt:381-383` `stopVpn()` 先 `stopForegroundCompat()` 再 `VpnMonitorManager.onVpnStopped(this)`；`notification/VpnMonitorManager.kt:41-45` 用 `ContextCompat.startForegroundService(...)` 拉起，异常仅 `Log.w` 吞掉。若此时应用整体处于后台（网络监控触发的自动停止、系统回收），Android 14+ 可能对 `startForegroundService` 抛 `ForegroundServiceStartNotAllowedException` → 常驻提醒消失，直到用户下次打开 App（`main/MainWorkModeCoordinator.kt` 的 sync）才恢复。同族路径 `express/ExpressVpnService.kt:193-196`。
- 未升级原因：前台点「停止」时应用可见、不触发限制，需后台停止场景 + logcat 抓到该异常才能定性。确认方法：API 34+ 真机让网络监控在后台触发 `stopVpn()`，看 logcat 是否出现 `ForegroundServiceStartNotAllowedException` 且 1002 通知消失。

### O-111 多个 MainActivity PendingIntent 共用 requestCode 0，extras 理论上互相覆盖
- `tile/DitingTileService.kt:139-144`（MainActivity + `EXTRA_AUTO_START_VPN`，code 0）、`normal/notification/VpnNotificationBuilder.kt:70-75`、`express/notification/ExpressNotificationBuilder.kt:71-76`、`core/rule/SubscriptionAutoUpdateScheduler.kt:249-253`（MainActivity，code 0，无该 extra）；`Intent.filterEquals` 不比较 extras/flags → `FLAG_UPDATE_CURRENT` 下后建者覆盖前者 extras。
- 未升级为缺陷：回读 `main/MainVpnController.kt:61-77`，auto-start 在 VPN 已运行时幂等（`DnsModeManager.startService` 见 RUNNING/STARTING 早退 `server/backend/DnsModeManager.kt:76`），未构造出可观察的错误结局。确认方法：运行时 dump 两个 PendingIntent 的 `isEquals` 并观察点「订阅更新完成」通知是否意外触发 VPN 启动。

### O-112 DNS 模式启动失败后磁贴短暂停留 ACTIVE（乐观更新无失败回滚）
- `tile/DitingTileService.kt:63-67` `toggleDnsService` 启动分支乐观 `updateTileState(running = true)`；`server/backend/DnsModeManager.kt:79-85` `startService` 走 catch 置 ERROR 时不发 `requestTileUpdate`（对照成功路径 `DnsModeService.kt:144`、停止路径 `:97` 均主动刷新）。ERROR 后磁贴仍显示 ACTIVE，直至下次面板打开 `onStartListening`（`:36-39`）自愈。与已修复的「DNS 启动重绘顺序」部分重叠，且自愈窗口短，列观察。

### O-114 超大 DNS 应答写回 1400-MTU TUN 且 DF=1，未夹紧也未分片（Express）
- `express/ExpressTunnelManager.kt:411-419` 把 `engine.resolve` 的原始应答经 `buildUdpResponse` 单包写回，不查 `VPN_MTU`（`:82`）；`express/engine/ExpressPacketCodec.kt:362` IPv4 头恒置 DF。>MTU 的应答（DNSSEC 大记录/多答案）理论上被 TUN 丢弃。未升级：未能从源码证明 Android TUN 对超限写是丢弃还是截断（legacy Go `tunnel/engine.go:357` 同样裸写），需真机 `ip -d link` + 大包上游对拍。

### O-115 Express 域名规则仅对 A/AAAA 生效，非地址类型记录放行（Go 侧对全部类型评估）
- `express/engine/ExpressDnsEngine.kt:95-96` `isAddressQuery` 门控规则评估；对照 Go `engine_dns.go:89` 对任意 qtype 调 `policyEngine.evaluate`。被拦域名的 HTTPS/SVCB(65) 记录在 Express 会透传。无连接绕过路径（连通仍需被拦的 A/AAAA），属信息泄漏面；是否构成缺陷取决于产品对「拦截」定义，暂列观察。

### O-116 `DnsResponseCache.resolve/get/put/materialize` 死代码内含真实取消缺陷（接线之日即须修）
- `core/cache/DnsResponseCache.kt:84` `catch (e: Exception)` 吞 `CancellationException`，`:67` `coroutineScope+async` 下单路失败会取消整个 scope 连带 leader 的 `finally inFlight` 清理。当前无生产调用（normal 走 Go、Express 自带实现），仅作 latent 记录。

### O-117 OkHttp `Call.await` 不随协程取消；测速每次 new OkHttpClient
- `core/dns/DnsLatencyTester.kt:247-257` `suspendCoroutine` 未注册 `invokeOnCancellation { call.cancel() }`：离开页面后在途 HTTPS 探测最长跑满 5s；`:120-139` 每 attempt 新建 client，弃用的连接池靠 OkHttp 空闲驱逐。有界自愈，列观察。

### O-118 `isUsableUpstreamResponse` 仅验 QR+TXID，不比对 QNAME/QTYPE/rcode
- `core/dns/DnsMessageUtils.kt:298-301`（Express 孪生 `ExpressDnsMessageUtils.kt:222-225` 至少钉 rcode）。UDP 冒充需猜 16-bit ID，硬化缺口而非确定性错误。

### O-119 DNS_MODE CNAME 覆写在 UI 显示「未生效」但实际仍被下发
- `ui/RewriteListViewModel.kt:228-229` CNAME 行 masterEnabled 取 `addressRulesOperational`（DNS_MODE 恒 false），而 `server/backend/DnsServerEngine.kt:102` 无条件 `setRewriteRules(含 cnameRedirects)`（不受 `:87-88` adBlock 闸门约束，`DnsModeService.kt:176-178` 注释亦称 hosts 类答案独立于过滤总开关）。Go DNS-server 层是否真应用字符串值未从 .aar 定版；显示与执行不一致，待 Go 侧取证再升级。

### O-120 竞速设置页对供应商列表一次性快照：从供应商管理返回可见旧列表
- `ui/RaceModeSettingsViewModel.kt:99-102` `activated` 守卫一次，`ui/DnsSpeedTestSection.kt:87` 仅 NavigationSettledEffect 触发，无 ON_RESUME 重读。仅当 VM 跨导航存活时命中（Compose 导航同图返回场景），未构造确定路径。

### O-121 `RaceModeSettingsViewModel` 三处 `getApplication().getString` 走未包装 Application locale
- `ui/RaceModeSettingsViewModel.kt:155,156,272`：Application 无 `attachBaseContext` 包装，应用内语言≠系统语言时这三条 toast/消息回落系统 locale。资源双语齐备，纯语言一致性问题。

### O-122 tombstone protobuf 字段号未经真机金标准对拍
- `crash/TombstoneProtobufDecoder.kt:58-61,97-100,182,231-233,307-325` 的字段号（root 9=processName、SignalInfo 5/6、Thread 3/4、BacktraceFrame 2/4/5/6）在线取 AOSP `tombstone.proto` 原文失败（镜像 404/需登录）。若 root 9 实为 message、或 Thread.frames 实为嵌套 Backtrace，则进程名乱码/帧恒 0 退化文本恢复。建议拉一份 API30+ 设备 `ApplicationExitInfo.traceInputStream` 建金标准单测。

### O-123 `clearCrashLogs` 把墙钟写进原生崩溃水位线：校时回拨后原生崩溃停采
- `crash/CrashLogManager.kt:360` 写 `System.currentTimeMillis()`，`:314` 与 `exitInfo.timestamp` 比较；用户调快时钟→清空日志→调回，其后的真实原生崩溃在时钟追平前被 `>` 过滤。`onCrashOccurred:103` 的 24h 窗口同受校时跳变影响（负差值不超窗继续累加）。条件性（需手动校时），列观察；建议改 `elapsedRealtime` 域或单调化比较。

### O-124 连崩计数读-改-写与启动收集线程并发，增量可丢失
- `crash/CrashLogManager.kt:99-113` get→commit 非原子；`DitingApp.kt:45-47` 的 NativeCrashCollector 线程逐条 `onCrashOccurred`（每条 binder+fsync 窗口大）与主线程 `CrashHandler.kt:78` 可交错。方向与 A-055 相反（丢增量→延后触发）。窗口小、概率低，列观察。

### O-125 `exportToPrivateDownloads` 兜底目录 `files/downloads` 无 FileProvider 映射
- `crash/CrashLogManager.kt:205-206` `getExternalFilesDir` 返回 null 时回落 `File(filesDir,"downloads")`，而 `app/src/main/res/xml/file_paths.xml` 只映射 `app-update/`、`crash_logs/`、external `Download/`——`getUriForFile` 必抛被吞 → 文件已写出却被判「备份失败」且成永久孤儿（不在 prune/clear 管辖）。仅未挂载/直启阶段命中，条件性成立，列观察（修复 = 补 `<files-path name="crash_fallback" path="downloads/"/>` 或失败前删文件）。

### O-126 崩溃导出页计数一次性组合期采样，后台原生崩溃晚到则按钮保持禁用
- `ui/LogRetentionSettingsScreen.kt:69` `remember { getCrashLogCount(context) }` 无 key/无刷新钩子（仅 `:259` 清空后置 0），`DitingApp.kt:45-47` 收集线程含 binder+fsync：冷启动直奔该页可先于收集完成组合 → 「当前无崩溃记录」+导出禁用，须退出重进。体验级，列观察。

### O-127 双 AppUpdateHost 并行下载竞态 / FileProvider 授权存续 / ABI 资产选择（update 模块存疑三则）
- S1：`MainActivity.kt:41` 与 `SettingsRouteActivity.kt:80` 各持一个 Host/Manager，`generation` 仅 Host 内有效，两页同点下载时单槽位 prefs 互相覆盖（`AppUpdateManager.kt:70-73` 的 Idle 前置检查存在 TOCTOU）——需双入口同时可点，难触发。S2：`AppUpdateManager.kt:158-162` 拉起安装器的 URI 读授权随任务栈回收，用户在安装器停留期间从最近任务划掉 DITING 时可能失效（ROM 行为不一，未实测）。S3：`:178-184` arm64 优先否则取首个 .apk，若 Release 混传 splits 会装错 ABI 包（取决于发布习惯）。均列观察。

### O-128 `SettingsRouteActivity` 离开不取消下载、无取消提示（可能是后台续传设计）
- 对照 `MainActivity.kt:231-234` 调 `cancelActiveDownload`，`SettingsRouteActivity.onStop(:195-198)` 不调；从设置页返回时 Host 随 Activity 销毁、`lifecycleScope` 取消下载半途作废且静默。若「后台续传」为意图则应有续传 UI，现状两头不靠——意图未证实，列观察。

### O-129 悬浮球面板 × 关闭不注销屏幕广播接收器（幂等、无实害）
- `ui/floating/FloatingLogOverlayController.kt:288-293` `hideForCurrentBackground()` 走 removeWindow 但跳过 `unregisterScreenReceiver()`，接收器存活至下次 syncVisibility（`:143/:149`）；`expanded` 先置 false 使 `applyScreenOn(:123-131)` 无法重启循环，register/unregister 均幂等（`:110/:118`）。无可观察损害，列观察。

### O-130 应用管控 VM 硬编码 NORMAL 数据集，但当前无路由以其它 dataset 挂载
- `normal/ui/AppRuleViewModel.kt:27` `AppDatabase.getInstance(application)`，经 `SettingsRouteActivity`（routes 带 dataset）挂载，理论上 EXPRESS/DNS_MODE 可达——全仓 grep 未发现以非 NORMAL dataset 打开 APP_ALLOWLIST/APP_RULE_MANAGEMENT 的导航（`MainModeDispatcher.kt:82-96` 仅 NORMAL 分支）。latent，列观察（与 O-102 同族）。

### O-131 `FloatingLogMapper.fromHttpLog` 副标题未过 `localizedText`
- `ui/floating/FloatingLogMapper.kt:118` 与兄弟行 `:45` 不一致，英文界面该副标题保持中文。纯文本一致性问题，列观察。

### O-132 请求日志页防火墙行在 SQL 层被排除出旁路桶，仪表盘却在 UI 层标旁路（A-049 的口径佐证）
- `data/repository/RequestLogRepository.kt:69` `(queryType=0 OR …) AND (message IS NULL OR message NOT LIKE '%blocked_by=firewall:%')`——app 自身定义「旁路=非拦截」，A-049 的 `:322` label 与之矛盾；若修 A-049 需同时核对仪表盘「旁路」统计卡是否复用同一行集。记录口径，不重复计缺陷。

### O-133 `DynamicPatternLocalization` 14 处 when 分支被更早前缀吞并（死分支清单，修复 A-061 时注意勿删 `:151` 兜底）
- 逐行核对：`:74`（`全部失败（` 同 `:30`）、`:119` 被 `:57` 挡、`:132` 被 `:119/57`、`:136/138/139/142/143`（`已处理` `平均胜出耗时` `首选命中` `原始 TTL` `最后命中` 各被 `:61/39/16/10/14` 挡）、`:151` 为泛化兜底**必须保留**（防「导入失败：成功 2 项…」嵌套串）、`:108/109` 被 `:63/:64` 挡、`:172` 被 `:173-175` 家族顺序问题（`更新 ` 在 `设置 ` 后，互不冲突，仅登记冗余）。死分支无害（重复即前序命中），但删减评审若误删 `:151` 会引入回归。列观察。

### O-134 `DnsCacheController` 单全局槽位 `activeCache`，第二 dataset 注册会顶掉首个的清理回调配对
- `core/cache/DnsCacheController.kt:9-16`；当前仅 `normal/DnsVpnDatabaseComponents.kt:139` 一处注册，无并发第二注册证据。latent，列观察。

### O-135 `DotTransport`/`ExpressDotTransport` 丢弃 `protectSocket()` 返回值，与 `PlainDnsTransport` 的抛错处理不对称
- `core/dns/DotTransport.kt:71` 与 `express/transport/ExpressDotTransport.kt:116`：`protectSocket?.invoke(rawSocket)` 返回的 Boolean 被丢；对照 `core/dns/PlainDnsTransport.kt:49-51` `if (protectSocket != null && !protectSocket(socket)) throw IOException("Failed to protect DNS UDP socket")`（Express Plain 孪生同抛）。`VpnService.protect()` 在服务停止/重建窗口返回 false。
- 未升级为缺陷（子代理复核后自证影响不成立）：两种模式的 builder 都 `addDisallowedApplication(自身包名)`（`normal/DnsVpnTunnelManager.kt:204-207`、`express/ExpressTunnelManager.kt:229`），未 protect 的本包 socket 仍直连物理网络，不构成「上游经自身 TUN 回环」黑洞；可观察后果仅剩「慢失（烧满 5s soTimeout）而非快失」与错误原因被掩盖。建议统一为抛错口径，属健壮性/一致性卫生项。

### O-141 运行时自定义上游的两处潜在缺陷（provider 重载路径当前不可达）
- (a) `normal/DnsVpnProviderResolver.kt:36-51`：intent 协议为明文 `DNS` 且省略 `EXTRA_DNS_PORT` 时默认落到 `DEFAULT_DOT_PORT`(853)——明文 DNS 发进 DoT 端口。全仓 `startIntent(context, provider)` 带 provider 实参零调用（仅无 provider 重载在用），故今天不可触发；一旦有「临时上游」入口即炸。
- (b) `normal/DnsVpnService.kt:228-231 + DnsVpnRuntimeConfigManager.refreshRuntimeConfig`：以 intent 携带运行时自定义 DoH/DoT 启动的会话，收到任何 `ACTION_REFRESH_RUNTIME_CONFIG`（intent=null）后按**持久化**上游重解析，静默丢弃启动时的自定义 provider。同因 (a) 的入口不可达而暂未升级。确认方法：给 (a) 造一个调用点后走 refresh 比对 `configManager.activeProviders`。

### O-142 `restartVpnLocked` 与 `stopVpn` 的 TUN 释放顺序不对称（无实害）
- `normal/DnsVpnService.kt:345-349` restart 先 `stopInspectionDataPlane()`（`goInspectionTunnel=null`）再 `disconnectVpnInterface()`，使后者内 `goInspectionTunnel?.releaseTun()` 恒为 no-op；stopVpn 路径顺序相反。已核 Go `Engine.Stop()` 关闭 tunFile（`tunnel/engine.go:229-231`），无 fd 泄漏，仅路径不对称；统一顺序可消除误读风险。另：`normal/DnsVpnNetworkMonitor.kt` 的 `onNetworkChanged` 回调在 `DnsVpnService.kt:57` 构造时未传（恒 null），四个 NetworkCallback 的 IPv6 自适应检查为空转——注册/注销配对完好无泄漏，属死码（A-012 备注已覆盖其后果）。

### O-144 DNS_MODE 数据清理与 NORMAL 共用 `rule-index/` 目录（入口当前不可达，latent）
- `core/rule/RuleIndexLayout.kt:43-45` — `rootDirectory(DNS_MODE)` 与 `rootDirectory(NORMAL)` 返回同一 `File(filesDir, "rule-index")`；`data/cleanup/DataCleanupManager.kt:158/237/316/513` 的 DNS_MODE 分支删该目录 → 一旦可达即连带删掉 VPN 模式正在 mmap 的规则索引（读者持旧指针场景再叠加 A-068）。当前全仓没有以 dataset=DNS_MODE 打开清理页/触发清理动作的用户入口（`DnsSettingsScreen.kt:51-56` 只暴露 cache/rules/black/white/rewrite 五路由；`MainModeDispatcher.kt:61,111` 传 EXPRESS/null），且规则写侧对 DNS_MODE 均 `if (dataset == DNS_MODE) null` 走纯内存（`RuleOperationWorker.kt:157`、`SubscriptionAutoUpdateEngine.kt:312`——与「索引归 VPN 模式」的注释语义一致）。确认方法：给 DNS_MODE 清理入口造一个（或单测直调 `clearAllLocalData(DNS_MODE)`）后检查 NORMAL trie 文件是否消失；修复方向：DNS_MODE 分支跳过索引目录，或 RuleIndexLayout 给 DNS_MODE 独立子目录。

### O-145 `WorkModeLifecycleRegistry` 默认前后台 lambda 写向无人读取的 `system_settings` 文件（窗口极窄）
- `core/WorkModeLifecycleRegistry.kt:43-51` — `updateNormalFloatingLogAppState` 的**默认实现**写 `getSharedPreferences("system_settings")` 的 `main_activity_foreground`；而读取端 `ui/settings/SystemSettingsStore.kt:84-94`（PREFS_NAME=dns_vpn_prefs）与 `ui/floating/FloatingLogOverlayController.kt:62` 都不看这个文件。`normal/DnsVpnService.kt:461` companion init 会用正确实现覆盖该 lambda，故只有「本进程从未加载 DnsVpnService 类 + Express 悬浮日志」窗口内值落进死文件（默认 true 与典型前台态一致，几乎不可见）。属 A-048 同族的双源残留，卫生级。另登记：`ui/settings/NetworkToolsSettingsStore.kt:11` 自有 prefs `network_tools_settings` 不在 `clearAllLocalData` 任何分支清单内（工具偏好是否有意保留未见声明注释）；`ui/subscription/AddSubscriptionScreen.kt:94` 的 `takePersistableUriPermission` 失败分支是否阻断保存未追完（content:// 订阅源跨重启可能 SecurityException）。

### O-146 「不再提示」建议忽略为全局 key，跨模式互相消音（意图待定）
- `permission/ModePermissionStore.kt:46-56` — key=`recommendation_dismissed_`+permission.name，**无 mode 维度**；`permission/ModeReadinessState.kt:21-23` 按此过滤建议。banner/对话框按模式评估（`ModePermissionWarningAction.kt:219-228` 在极速对话框里点「不再提示」后，普通/DNS 模式的同类建议同样永久消失），且全仓无恢复入口。产品意图若是「该建议全局不再烦我」则只是注释缺失；若要 per-mode 需在 key 加 mode。缺声明性证据，列观察。

### O-149 本轮三份子代理报告中被证伪/降级的条目（勿再提出）
- 【证伪】规则解析子代理 #8「`$dnrewrite=0.0.0.0,badfilter` 永远撤销不了 sinkhole 改写」：回读 `AdblockRuleLineParser.kt:139-140` — 值落 `SINKHOLE_ADDRESSES` 时**只置 `dnsrewriteIsBlock`，不置 `dnsrewriteTargetType`**；于是 `:211-216` 的 badfilter key 走 `dnsrewriteIsBlock || !allow` 分支取 `blockRuleKey`，与 `:228-230` 原规则产出 `blockRules` 时的 map key（`:107 blockRuleKey(rule)`）**同一体系**，撤销成立。子代理把 `:213` 的 `dnsrewriteTargetType != null` 首分支误当成命中分支。
- 【证伪】规则解析子代理 #10「hosts 多域名行整体丢弃」：`HostsAndDnsmasqParser.kt:126-137` 非 sinkhole 分支与 sinkhole 分支同构——逐域名 `normalizeDomain`，失败的 `invalidCount++`、成功的入列，仅全失败才整行 invalid。其举的 `1.2.3.4 a.example.com b_1.example.com` 例子按现实现**保留** `a.example.com`，结论方向反了。
- 【降级为观察，非确认缺陷】规则解析子代理 #6「`RuleIndexLayout.scopeDirectory` 忽略 scope 导致 DNS/HTTPS 索引互相覆盖」：`scopeDirectory` 确实丢弃 `scope` 参数（`:50-53` 直接 `return rootDirectory(...)`，与 `:12-19` 文档声明的 `rule-index/https/` 布局不符，属真实实现-文档不一致），**但后果不成立**——`BlockRuleEntity`/`RewriteRuleEntity` 无 scope 列（grep 实证仅有 `appScope`），`BlockRuleDao`/`RewriteRuleDao` 全部查询不带 scope 过滤（`enabledSubscriptionRulesPageKeyset:185-196`、`enabledNonSubscriptionRules:33` 等），故 HTTPS 作业与 DNS 作业编译的是**同一份全量规则**、写入同一文件的内容恒等，不存在互相覆盖丢数据。余留风险只有 §7 的 .tmp/半写面（已独立入库 A-096）。建议修复方向退化为「要么按文档真正分目录，要么删掉误导性的 scope 参数与注释」，属卫生项。
- 【降级】Go 引擎子代理 #6「`Engine.Start` 失败路径锁外写 `e.running` + 新建 Resolver 不 Shutdown」：`engine.go:138 Engine.Start(fd,…)` 在生产**无调用者**——Kotlin 三条入口分别是 `engine.startFull`（`normal/GoInspectionTunnel.kt:94`）、`engine.startStandalone`（`server/backend/DnsServerEngine.kt:41`）、`engine.startStackMitm`（`GoInspectionCaManager.kt:21`），且 `DnsModeService.kt:139` 的 `engine.start()` 是 Kotlin 侧 `DnsServerEngine.start()` 包装（内部调 startStandalone），非 Go `Engine.Start`。竞争/泄漏面真实但不可达，子代理自己在存疑段也标注了同一点。列观察备查（若日后启用 legacy 路径需一并修）。
- 【降级】Go 引擎子代理 #7「bootstrap 串行回退放大首查延迟」：`bootstrap_resolver.go` 的串行链与「同主机并发各自重复整轮」需配合**全部 bootstrap 站点黑洞**才显形；同族面已在 A-088（dataset 错读）与 O-150 第 4 项（Kotlin `BootstrapSelector` 的 3s×N×2 无总预算，可达性已核）登记，Go 侧维持观察。
- 【未升级】Go 引擎子代理存疑 4 项（`dns_interceptor.go` 分片黑洞、StartFull↔Stop 交错遗留 fd/栈、`Engine.Start` 路径 dynamicBlocks 缺席、`log_aggregator.go:99-102` start/stop 竞态）：均因「当前无生产调用者」或「微秒窗口无确定性触发」维持存疑，与上两条降级理由同源，此处一并留痕避免后续轮次重复提出。

### O-150 Kotlin 极速/诊断链的三项已核实但影响条件性/显示级的事实
- **极速运行期 bootstrap 无总时间预算**（diag 子代理 #5，机制核实）：`core/diagnostic/BootstrapSelector.kt:43-82` 对有序候选**串行**逐个解析，每候选 `resolveWithBootstrapDns` 又串行发 A 与 AAAA 两查询、各 `queryUdp` 用 `DNS_TIMEOUT_MS=3000`（`:139/:161`）的 `soTimeout`，且 `socket.receive` 不响应协程取消 → 最坏 `候选数×2×3s`（默认 7 预设≈42s）；调用端 `express/ExpressTunnelManager.kt:408-410` 每个 UDP:53 查询包独立 `scope.launch(Dispatchers.IO)`、`resolveBootstrap:481-486` 用 `runBlocking` 包住，而 `:102-104` 注释自证设计前提是「resolve() 每次至多 5s」——前提与实现相反；客户端 5s 超时重传会再起新协程并发跑同一条链（成功前无 in-flight 去重）。仅在 UDP:53 被拦/弱网时显形，且成功后缓存 60s 吸收，故列观察级（修复方向同 Go 侧 O-149：共享总预算 + 负结果短缓存 + single-flight）。
- **墙钟时间基在系统校时跳变下的瞬时失真**（diag #6）：`core/traffic/TrafficStatsManager.kt:245-246` `elapsedSeconds = max(0.2,(now-lastSampleTime)/1000)` 与 Go tick（`:178,198-199`）用 `System.currentTimeMillis()`；NTP 向后跳→clamp 0.2s→同一 delta 网速放大约 5×，向前跳→低估；`TrafficSpeedEstimator.kt:75-76 decayIdleSpeeds` 的「每调用=1s」假设在 tick 延迟时同样不成立。同族 `BootstrapHealthEngine.kt:29/40`、`BootstrapHealthStore.kt:34` 用墙钟判 `cooldownUntil`。开发者手动改时间可见、自愈，与 O-123 同根不同面。建议统一 `elapsedRealtime` 域。
- **两处显示级陈旧态**：(1) `core/diagnostic/NetworkInfoProbe.kt:40-42` `isVpnActive = cm.allNetworks.any { hasTransport(TRANSPORT_VPN) }` 判「存在任意 VPN」而非本 app，第三方 VPN 连接 + 本 app 停止时 `ui/NetworkToolsScreen.kt:228` 徽标误亮（文件头注释声称与 `DnsVpnTunnelManager` 语义一致，后者按自身 `vpnInterface` 判——口径分裂）；(2) `core/traffic/TrafficAppResolver.kt:19-20/111/119` `unresolvablePackages` 是进程级永久负缓存，已卸载应用再安装后其标签在整进程生命周期内退化为原始包名（`:93 schedulePackageLookup` 直接 return 不重试），仅 `clear()`/重启恢复。

### O-148 违反 AGENTS.md 第 1 条「代码文件 ≤550 行」的文件清单（约定违例，非行为缺陷）
- 全量扫描实证（`find -name '*.kt'/'*.go' ! -name '*_test.go'` 逐文件行数）：**Kotlin 13 个 + Go 1 个**超线——
  `ui/WhitelistViewModel.kt` 602、`ui/dashboard/ModernLogDashboardModeViews.kt` 599、`core/dns/DnsMessageUtils.kt` 597、`ui/localization/RulesAndSubscriptionLocalization.kt` 587、`ui/BlacklistViewModel.kt` 581、`normal/ui/ConfigTransferScreen.kt` 580、`ui/components/SettingsComponents.kt` 579、`ui/SubscriptionViewModel.kt` 575、`SettingsRouteActivity.kt` 569、`express/engine/ExpressPacketCodec.kt` 572、`core/rule/RuleOperationWorker.kt` 572、`normal/DnsVpnService.kt` 560、`data/dao/AllowRuleDao.kt` 554；Go：`tunnel/bootstrap_resolver.go` 558。
- 与行为缺陷分开计：这些文件当前**无已知正确性问题源于长度**，长度违例的代价是可维护性（AGENTS.md 明文上限即为此设）。修复方向为按既有职责切分（如 `Whitelist/BlacklistViewModel` 同构可提公共基类、`SettingsRouteActivity` 的 `SettingsRouteContent` when-分支表可拆 route→composable 映射表），但属代码修改，不在本记录（只记录不修改）范围。
- 后续轮次勿重复计数：以上清单即全量，新增超线文件才需登记。

### O-147 【证伪留痕】DNS_MODE 上游校验器与开机自启接收器三项候选全部排除（勿再提出）
- (1) `validateHost(":::")` 疑似放行畸形 IPv6 → 本机 JDK 实跑 `InetAddress.getByName(":::")` 抛 `UnknownHostException: :::: invalid IPv6 address literal`，`isValidIpv6` 返回 false（`server/model/DnsUpstreamValidator.kt:80-91`，与其注释「which rejects malformed forms such as `:::`」一致）；`1:2`、`2001:db8::1::2`、`fe80::1%eth0`（无此网卡时）同被拒。初判「::: 被接受」系未跑运行期即采信，已证伪。
- (2) DoH URL 端口不受 `validatePort` 约束（`:35` 对 DOH 直接 return null），`https://host:99999/dns-query` 可通过 → 核对为**设计一致**而非缺口：编辑对话框 DoH 分支根本不渲染端口输入框（`ui/components/ProviderManagementComponents.kt:194-242`，端口框位于 `else`（非 URL 型协议）分支内），`parsePort` 空文本兜底 443，引擎桥接 DOH 时发 `server:""` + `url:address`（`server/backend/DnsServerEngine.kt:190-205`），Go 侧 `validateDNSProvider` DOH 只验 `url.ParseRequestURI` + scheme + 非空 Host（`tunnel/dns_config.go:180-184`），端口属 URL 语义由用户显式书写——等同浏览器地址栏手填端口，不存在「校验通过但运行必炸」的不对称。`https:///dns-query`（空主机）与含空格 URL 亦已实跑证实被 `validateDohUrl`/`\s` 预检拒绝。
- (3) `DnsModeBootReceiver` `android:exported="false"` + BOOT_COMPLETED 疑似收不到系统广播/直启期读 CE prefs 失败 → 打包合并清单中 Google 自家 `androidx.work.impl.background.systemalarm.RescheduleReceiver` 同为 `exported="false"` + BOOT_COMPLETED 过滤器（debug 合并清单 :266-277），且 BOOT_COMPLETED 按规范只在用户首次解锁后发出（解锁前对应的是 LOCKED_BOOT_COMPLETED），CE 存储此时可读；接收器三守卫（action / `WorkModeStore`==DNS / `isServiceActive`）+ `runCatching` 包裹 FGS 启动，判为无缺陷。
- 附带卫生登记（未定级）：协议切换仅在目标为**非** URL 型协议时重置端口（`ProviderManagementComponents.kt:187-189`），DNS(:853) 编辑切 DoH 保存后 prefs 残留端口 853，但该值无任何读取方（引擎 DOH 分支不读 `upstream.port`），纯数据陈旧无后果。

### O-143 本地化引擎 32 位哈希键的理论碰撞面与不可刷新渠道名（卫生）
- `ui/localization/LocalizationEngine.kt:37-41`：`localized_text_<31bit(hash)>` 作为资源名与 app 内中文串互映射，`values/values-en` 各注册 112 条且完全对称（脚本核 `values−values-en = ∅`），当前全仓中文串间碰撞 0 组；但 String.hashCode 32-bit 截断至 31 bit，新增串存在理论碰撞（后果：一条文案显示另一条的译文），且无测试守护。resource-id/translation 双缓存在语言切换 `recreate()` 后跨 Activity 共享 stale id（后果=回落原中文，仅体验降级）。渠道名创建即固化，语言切换后系统通知设置页不刷新——A-037 修复备注已含，此处登记哈希面。

### O-138 `AppTrafficDao.upsertDelta` 用 SQLite UPSERT 语法：API 29 设备（NORMAL 模式可达下限）若其 bundled SQLite < 3.24 则流量历史静默全丢（版本下限未取证）
- `data/dao/AppTrafficDao.kt:48-56` — `INSERT … ON CONFLICT(date, package_name) DO UPDATE SET …`（经 `upsertBatchDeltas:66-77` 事务循环调用）；UPSERT 需 SQLite ≥ 3.24。
- **子代理原报「高危：minSdk 24 全设备静默丢失」的触发面已被证伪修正**：唯一调用链 `core/traffic/TrafficDatabaseSyncer.kt:117-129`（整体 `catch (e: Exception) Log.w`，异常确被吞）只由 `TrafficStatsManager` 驱动，而 `TrafficStatsManager.start(...)` 唯一调用点是 `normal/DnsVpnService.kt:321`——**NORMAL 模式专属**（全仓 grep `TrafficDatabaseSyncer` 仅命中 core/traffic 两文件，Express 零引用）。NORMAL 在 UI 层被 `ui/mode/WorkModeComponents.kt:128-136` 硬性拦在 API 29+（不支持即 toast「仅支持 Android 10 (API 29) 及以上系统」），且 `WorkModeStore.getAppWorkMode`（`:10-14`）无设备能力回退、配置导入导出不含工作模式键（grep 实证）。因此受害面收窄为「**API 29/30 设备 + NORMAL 模式**」。
- 未定级的决定性事实缺口：**API 29 出厂 bundled SQLite 是否 ≥ 3.24**。仓库自身注释与之一致地主张 API 30 下限——`data/dao/DnsCacheDao.kt:46-47` 原文「(INSERT ... ON CONFLICT DO UPDATE would need SQLite 3.24 / **API 30**, but minSdk is 24, so this portable form is used instead)」并据此为 `updateMetadata` 实现了 UPDATE→0 行→insertIfAbsent 的可移植回退；若该「API 30」经验真，则 A 面是 API 29 而非「24–29」，且 Express/API24–28 完全不相干。本次多路取证（AOSP `external/sqlite` VERSION 各 ref、android.googlesource `?format=TEXT`、aosp-mirror 分支、developer.android.com SQLite 页）均返回 404/导航占位或乱码解码，**未能取得可引用的一手版本表**，故不升级为确认缺陷。
- 确认方法（缺一手版本表亦可运行期定版）：API 29 真机/模拟器跑 NORMAL 模式产生 >1MB 或跨 15s 流量 → logcat 过滤 `Failed to flush traffic deltas to Room`（伴随 `near "CONFLICT": syntax error`）→ 命中即升级为高危（今日视图内存态可用，杀进程归零、THIS_WEEK/ALL_HISTORY 恒 0、跨零点 rollover 丢昨天整日）；无该行则说明 API 29 的 SQLite ≥ 3.24，降级为「与同库 DnsCacheDao 注释不一致」的卫生项。修复方向同注释：UPDATE→0 行→INSERT 回退，或 `@Upsert` + 版本门。
- 附带（子代理 S-1/S-3/S-4/S-5 四项，证据不足，一并登记）：`data/repository/DnsCacheRepository.kt:57`/`DnsLogRepository.kt:156` 的 PagingSource `prevKey = offset`（本页自身偏移）在 prepend 时会重载同页，但当前 UI 无触发反向翻页的路径（首屏 prevKey=null、invalidate 走 getRefreshKey→从头加载），latent；`data/dao/AllowRuleDao.kt:219-233` `enabledRuleByPattern` 不带 important 条件却返回单个 `EnabledRule?`（同 pattern 双行时 Room 取首行不报错，`syncCachedPattern` 可能同步到非预期那条；能否构造出双行未确认）；`data/cleanup/DataCleanupManager.kt:52-56` EXPRESS 清理未先冲 DnsLogger 内存批（500ms 窗口可回写少量行）；`data/dao/CosmeticRuleDao.kt:19-23` `insertForSource` 依赖的 `idByDomainAndSelector` 无行返回 0，理论上可生成 ruleId=0 孤儿 source 行，且 `cosmetic_rule_source` 是唯一**无外键 CASCADE** 的 `*_rule_source` 表（`CosmeticRuleSourceEntity.kt` 全文无 foreignKeys）——仅在并发删除时可达，未证实 UI 路径。

### O-139 【证伪留痕】Express/DNS_MODE 拦截统计「跨库 id 错配」不成立（勿再提出）
- 曾拟记录：`runtimeForDataset(DNS_MODE) -> AppDatabase`（`data/DnsRulesDatabase.kt:148-152`）+ 统计页 hits 用 runtime 库、订阅列表用 dataset 库（`ui/SubscriptionInterceptionStatsViewModel.kt:35-41,66-76`）→「VPN 的 dns_log 被按 DNS 库订阅 id 解释，出现已删除订阅行/占比错位」。
- 复核否决，三条独立事实：(1) `dns_log` **只有两个写入者**——`express/ExpressTunnelManager.kt:278`（diting_express）与 `normal/DnsVpnDatabaseComponents.kt:97`（AppDatabase）；`server/backend/` 下无任何 DnsLogger/logQuery 接线，即 **DNS_MODE 从不写 dns_log**，被「错读」的表里根本没有 DNS_MODE 场景的新数据；(2) 统计页 dataset 只来自 `LogRouteActivity.kt:24-30` 的 intent 缺省（NORMAL 或 EXPRESS），`MainNavigationCoordinator.kt:73-76` 的 `launchLogRoute(dataset)` 与 `normal/ui/MainScreen.kt:291-295`/`express/ui/ExpressMainScreen.kt:252` 均不传 DNS_MODE，`SettingsRouteActivity` 也未挂载该路由（`DnsSettingsScreen.kt:51-56` 的 DNS_MODE 只进 5 个规则/缓存页）——**DNS_MODE dataset 不可达**；(3) EXPRESS 侧写读同库（diting_express，`ExpressRulesDatabase.kt:62,91` 含 DnsLogEntity+SubscriptionEntity），`blockSubscriptionId ← "sub_<id>"`（`core/rule/SubscriptionUrlHelper.kt:57-58`）与本库订阅 id 同空间，不存在错配。子代理报告中的「与隔离承诺相悖」是对 `runtimeForDataset` 注释语义的过度推断。

### O-140 Engine 回调/配置字段无锁读写：Go 数据竞争（与 A-018 同族，本波补充未定级面）
- 写侧 `engine_config.go` 全无锁：`:48 e.domainChecker`、`:274 e.firewallChecker`、`:278 e.appResolver`、`:282 e.appUidResolver`、`:386 e.responseType`（`dns_config.go:134` 同）；读侧热路径无锁：`engine_dns.go:41,48,76,106,260,280`、`engine_rules.go:168`、`engine_connection_log.go:19-20,40-45`、`engine_standalone.go:60,97,121,248`。
- 与已入库 A-018（SetBlockResponseType/SetDomainChecker 不加锁 → 撕裂）为**同一处事实的不同取证视角**，故不另立编号；本条仅登记 A-018 未点到的其余四个字段（firewallChecker/appResolver/appUidResolver/responseType 的 dns_config 侧写入），修复时须一并覆盖，勿只修两个 setter。
- 另：`domain_trie.go:98-129` `matchWithWildcard` 每层同时试 exact 与 `*` 两支，最坏 2^(labels) 递归、深度=len(labels)。现实 trie 不会逐层放通配且标签数 ≤6，未构造出可达恶意输入（域名上限 127 label 需配合逐层通配的规则库）。建议加递归预算或 (node,index) memo；列为观察。

### O-137 Express DNS 缓存键忽略 DO/CD 位，与共享 `DnsCacheKey.storageKey` 分歧
- `express/cache/ExpressRoomDnsCache.kt:62,99`：键为 `"$name#${type}#${qclass}"`，不含 `question.dnssecOk`/`checkingDisabled`（同文件解析器 `express/dns/ExpressDnsMessageUtils.kt:34-35,56,61` 已提取这两个位）；对照共享实现 `core/cache/DnsCacheKey.kt:31-42` 追加 `|dnssecOk|checkingDisabled`。Express 上游每次查询都带 EDNS+DO（`express/transport/ExpressPlainDnsTransport.kt:39-43` / `ExpressDotTransport.kt:40` 经 `ensureEdns0`），故 DO=1 与 DO=0 的应答塌缩为同一条目：验证型客户端可能被喂无 RRSIG 缓存（RFC 4035 §3.1.1），反向则给非验证客户端塞 DNSSEC 大块。
- 未升级为缺陷：Android 系统 netd 解析器默认不设 DO，普通用户不触发；仅自跑验证/转发 stub 或加密 DNS 路径受影响（Express 专属，normal 走共享键无此问题）。确认方法：以 DO=0 查询缓存某 A，再以 DO=1 查同名观察应答缺 OPT/RRSIG。修复 = 键并入两布尔位对齐 `DnsCacheKey`。

### O-136 `HttpRequestLogger` 次构造器静默吞掉 `retentionDays`；`DnsLookupTool` queryName 显示选取仅装饰性
- `core/log/HttpRequestLogger.kt:35-40` 次构造器接收 `retentionDays` 但不落任何字段——当前所有调用方走主构造器，无观察后果，是留给下一个调用方的陷阱；`core/dns/DnsLookupTool.kt:92-93` 的 `toAsciiQueryName(name).takeIf{…} ?: name` 只影响展示选择。均卫生级，列观察。

### O-113 `BatteryOptimizationHelper` 的 200ms 防抖缓存无任何读取方（死但无害）
- `permission/BatteryOptimizationHelper.kt:54-65`：缓存分支仅在 `forceRefresh=false` 时读取；全仓调用点（`permission/AppPermission.kt:139`、本文件 `:130/:207/:213`）均用默认 `forceRefresh=true`（grep `isGranted(` 实证无显式 false 调用），`cachedIsIgnored` 只写不读；且各变更点都先 `invalidateCache()`。每次走真实 Binder 查询，功能正确，仅防抖设计落空。确认方法：`grep "forceRefresh = false\|isGranted(.*, false)"` 无命中（当前）。
