# 安卓端缺陷分级 · Low

> 本文档由对安卓端缺陷报告（扫描基线 `main @ 3a048c5`）逐条复核产出的**低严重度**问题构成：30 条 A 系列确认缺陷 + 21 条 O 系列（原「观察」经复核**构成缺陷**并转正入级）。源报告 `docs/desktop-bug-report.md` 已于 2026-10-18 删除，后续重建时不参考旧版本；本文档各表的「问题（复核后口径）」与「需修正要点」即为现存记录。分级依据**复核后严重度**。
>
> - Low 门槛：机制确证但后果为显示/计数/统计失真、窄窗口竞态、条件性触发、可自愈或有界损失、约定违例/卫生项。
> - 「判定」取 **存在** 或 **需修正**（机制成立，引证/触发面/影响叙述有偏差，「需修正要点」给出复核后口径）。
> - O 系列转正条目以本表口径为准（原正文随源报告删除，无保留价值）；被判定**不构成缺陷**的 O 条目列于文末「未入级说明」。
> - 撤回项：A-068/A-070/A-072/A-074 复核判**不存在**，不入任何分级——其崩溃/漏拦叙述全部挂在 `Engine.Start`/`SetTries` 旧 trie+bloom 拦截子系统，全仓 caller grep 证实零调用者死代码（翻案经过见 `AGENT_MISTAKES.md` 2026-10-18 「复核轮把 legacy 子系统当在用路径」条目）；A-067 例外——写序缺陷本身成立，仅原「高」影响叙述因同一死代码路径失实，降级留于 Low。

## 汇总表（A 系列 30 条）

| 编号 | 模块 | 问题（复核后口径） | 判定 | 文档原级 | 需修正要点 |
| --- | --- | --- | --- | --- | --- |
| A-016 | 数据清理 | 清背景缓存删 `appearance_settings` 键，实际存 `dns_vpn_prefs`，背景设置原样保留 | 存在 | 中 | 位图缓存确有删除、无存储残留，属承诺落空+误导 |
| A-017 | Go 引擎生命周期 | dnsCache 清理协程无停止路径 + CA 管理器每调用新建 Engine 不 Stop：泄漏 goroutine+缓存 | 存在 | 中 | 触发频率被收窄（每次 VPN 启动+证书操作），单会话内无用户可见故障 |
| A-019 | Go DNS | UDP 上游响应不查 TC 位、无 TCP 重试，截断响应写缓存并原样回放 | 存在 | 中 | 触发需上游不发 EDNS0；`:47` TCP 调用是 socks5 出网回退非策略路径（文档性质写错） |
| A-022 | DNS 模式端口 | loadConfig 每次把 5353/5354 强制改写 1053（非一次性迁移）并持久化 | 存在 | 中高 | 「保存即销毁」应为「保存后首次读取即销毁」；默认端口用户零影响 |
| A-024 | DNS 模式启动窗口 | STARTING 窗口内配置/上游修改被丢弃，完成后不重放 | 存在 | 中 | 例子混入 A-022（应为 UI 显示新端口、引擎监听旧端口）；下次变更即自愈 |
| A-034 | 通知渠道 | 两条同名「规则导入与更新」渠道：注册表 id 仅死代码引用，实际走 Worker 硬编码 id | 存在 | 中 | 通知功能不受影响，属设置面混淆 |
| A-035 | 配置导入 | 通知栏自定义文案要求两条都非空才写入：只填一条时该条也丢失 | 存在 | 中 | EXPRESS 模式同样命中（文档未述） |
| A-036 | 通知设置入口 | ACTION_APP_NOTIFICATION_SETTINGS（API 26+）+ runCatching 吞异常：7.x 点击无反应 | 存在 | 低 | 受害面再被 Express 64 位设备门收窄；AppPermission.kt:119-124 已有正确守卫先例可参照 |
| A-037 | 应用内语言 | 磁贴标签/监控通知/渠道名走未包装 getString（系统语言），同屏其它走 localizedText | 存在 | 低 | RuleOperationWorker :529/:538 另有两处裸串未列 |
| A-044 | DNS 缓存 | DnsResponseCache.clear() 与 30s 批量 flush 交错：drain 后写库前 clearAll → ≤200 行复活 | 存在 | 中 | 后果可再清（非永久）；命中需 clear 恰落毫秒级间隙；行号两处微偏 |
| A-047 | 应用更新 | 下载进度仅按 256KB 字节节流、无时间下限：快网下通知风暴/掉帧 | 存在 | 中高 | 「每 5–50ms」系推算应标注；设置页 onStop 不取消下载放大窗口（已核实） |
| A-048 | Express 悬浮窗 | 前后台状态写入被 isRunning 门控（NORMAL 侧无条件写）：停服期切换丢失→偏好陈旧 | 存在 | 中高 | 两症状一次生命周期事件后自愈；错误窗口窄但违背承诺文案 |
| A-050 | 悬浮窗兼容 | TYPE_APPLICATION_OVERLAY（API 26+）硬编码无 SDK 分支，minSdk 24 | 需修正 | 中 | 「toast 骚扰循环」不成立（亮灭屏路径不触发重建）；「7.x 必抛」待真机 logcat 定版，静态仅证无回退分支 |
| A-055 | 原生崩溃收集 | 批量收集水位线整循环后才 apply：中途进程死→下轮整批重采、计数虚增 | 存在 | 中 | 文档漏注 API 30+ 设备门（触发面更窄） |
| A-056 | 统计边界 | dayStartMillis 用当前 UTC 偏移折固定网格：DST 切换日「今日」偏 1 小时 | 需修正 | 低 | 文档复现例（01:30 EDT）实测**不偏**；真实窗口为拨快后 03:00–04:00，比文档描述更窄；Asia/Shanghai 恒正确 |
| A-057 | 流量页时钟 | 「已连接 HH:MM:SS」仅组合期取值，空闲无流量时不重组→时钟冻结 | 存在 | 低 | 纯显示新鲜度 |
| A-058 | 崩溃导出 | 手动导出成功标记由可取消 scope 在 IO 完成后写：写完即切页→阈值仍武装 | 存在 | 低 | 窗口帧级 |
| A-061 | 本地化 | Express 空态文案「当前筛选下暂无 DNS 请求日志」无字典条目，前缀替换吐半英拼接串 | 存在 | 低 | 哈希键 resource 零命中经 JVM 复算实证；触发即必现（英文界面） |
| A-064 | Go MITM 注入器 | InjectingReader EOF/提前返回丢弃 carry 残留 `<head` 前缀：特定文档截尾 | 存在 | 低中 | 实测触发面略宽（完整 `<head` 缺 `>` 也吞）；正常文档前 16KB 含 `<head>` 即不现形 |
| A-065 | Express 缓存统计 | dns_cache 每次 put 用 REPLACE 整行覆盖：hitCount/lastHitAt 重缓存归零 | 需修正 | 中 | 文档示例路径部分被自然过期掩盖，净损失发生在「未过期行被重缓存」；ExpressRulesDatabase 行号 :99（非 :61） |
| A-066 | 数据清理计数 | 清域名规则删 HOSTS 订阅覆写不复位 ruleCount；resetAfterRuleCleanup 全仓零调用 | 存在 | 低 | 纯陈旧计数；行号微偏两处 |
| A-067 | Go DNS v6 应答 | buildIPv6UDPPacket 在校验和**之后**才写 payload：合成 v6 UDP 应答校验和恒错 | 需修正 | 高 | **原「高」影响叙述失实**：唯一消费链挂 Engine.Start 旧拦截路径（零调用者死码），在用模式经 gVisor/OS socket 应答不经过该函数；保留为待清理死代码缺陷 |
| A-069 | Go DNS 缓存 | dnsCache.clear() 用 lruList.Init() 不 Remove：并发命中提升把孤儿元素链回，LRU/map 失同步 | 存在 | 中 | 后果有界（每 clear 每分片至多回链一个孤儿），无崩溃 |
| A-071 | Go MITM 证书缓存 | certCache 无上限 sync.Map、仅过期命中删除，与头注释「LRU 512」不符 | 存在 | 中 | flightCache 同样无界；随 StartStackMitm 重建自然释放 |
| A-073 | Go 连接日志 | 包级 connLogSeen 仅 StartFull 清空：长跑会话内去重键只增不减 | 需修正 | 低中 | 「standalone/inspection 无回收点」伪命题（这些模式从不写入）；「跨实例压制」证伪（第二个实例必先走自己的 StartFull 全清） |
| A-090 | Go DNS 配置原子性 | ApplyDNSConfig 先提交 responseType/dynamicResponse/reset 再校验 providers：失败时部分生效 | 存在 | 中 | 脏化范围恰为文档所述（resolver/cache 更新在校验之后），逐行确认 |
| A-095 | regex 注释截断 | AdblockRuleLineParser 无差别 substringBefore('#') 早于 regex 提取：regex 体内 # 令规则整条丢失 | 存在 | 低 | Go 同型截断（两端一致丢弃、无分叉），故低 |
| A-096 | 规则索引残留 | compileAndLoad finally 只删本线程 temp；deleteAll 全仓零调用 → .tmp 永久堆积；renameTo 失败退化非原子复制 | 存在 | 低中 | 触发需进程被杀/半写被读，窗口窄 |
| A-097 | AI 报告渲染 | MarkdownInlineAnnotator 斜体分支未排除词内下划线：dns_vpn_prefs 类键名被斜体化改写 | 存在 | 低 | Python re 等价复算 8 例中 5 例误中（本批复算吻合）；反引号代码段不受害（文档已自修正） |
| A-100 | 预置白名单升级覆盖 | 升级 forceReset 静默清除用户对 preset 行的全部改动，KDoc「customizations preserved」与实现不符 | 存在 | 低 | asset 实数 5 条、逐条改 preset 用户极少，触发面极窄 |

## 汇总表（O 系列转正 21 条）

O 系列原为「观察」章节条目（无严重度自评），「文档原级」列记「—」。

| 编号 | 模块 | 问题（复核后口径） | 判定 | 文档原级 | 需修正要点 |
| --- | --- | --- | --- | --- | --- |
| O-103 | 运行时配置 | refreshRuntimeConfig 失败分支 Go 回写旧档位、Kotlin 仍提交新值：两侧不对称 | 存在 | — | 行号 :141/:152（文档 :142/:153）；触发难构造，下次变更自愈 |
| O-104 | Go 生命周期 | start/stop 微秒交错可遗留运行中 TUN 栈 | 需修正 | — | 机制应改写「StartFull 晚于 Stop 取锁」——Engine.Stop 无 running=false 早退守卫（文档原述误） |
| O-107 | DNS 缓存显示 | 显示缓存把真实 TTL=0 应答当「未知 TTL」落库：缓存统计页幽灵条目 | 存在 | — | DnsCachePolicy 行号 :34-35；纯展示级（Go 侧 TTL≤0 每次重查） |
| O-112 | 磁贴状态 | DNS 启动失败后磁贴短暂 ACTIVE（乐观更新无失败回滚） | 需修正 | — | 仅 :81 catch 形态成立；端口占用失败经 onDestroy 即时刷新，受害面比文档窄 |
| O-117 | DNS 测速 | Call.await 不随协程取消；每次探测 new OkHttpClient | 存在 | — | 有界自愈（5s callTimeout 封顶），卫生+正确性缺口 |
| O-119 | 重写显示 | DNS_MODE CNAME 覆写 UI 显示「未生效」但实际被下发 | 存在 | — | **已定版**：Go 源码在仓内且 `engine_rewrite_test.go:11` 实证字符串值解析为 CNAME 并应用（文档「未从 .aar 定版」过时） |
| O-120 | 竞速设置页 | 供应商列表一次性快照：从供应商管理返回可见旧列表 | 需修正 | — | 文档「未构造确定路径」偏保守——VM 为 Activity 级 store（无 key 的 `viewModel()`），跨导航返回存活是常态，受害面应按「可预期路径」描述；建议真机再钉一次 store owner 层级 |
| O-121 | 应用内语言 | RaceModeSettingsViewModel getApplication().getString 走未包装 locale | 需修正 | — | 实为 **4 处**（:155/:156/:163/:272，非 3）；:163 格式串与参数分走两语言源，混搭更明显 |
| O-123 | 崩溃水位线 | clearCrashLogs 把墙钟写进原生崩溃水位线：校时回拨后原生崩溃停采 | 存在 | — | API 30+ 门；条件性（需手动校时），可自愈 |
| O-124 | 连崩计数 | 读-改-写与收集线程并发，增量可丢失→阈值延后触发 | 存在 | — | 窗口小、有界 |
| O-125 | 崩溃导出兜底 | filesDir/downloads 兜底目录无 FileProvider 映射：误报失败+永久孤儿 | 存在 | — | 双重前置条件（外置存储不可用），条件性成立 |
| O-126 | 崩溃导出页 | 计数一次性组合期采样：原生崩溃晚到则按钮保持禁用 | 存在 | — | 体验级，退出重进自愈 |
| O-128 | 更新取消 | SettingsRouteActivity onStop 不取消下载（对照 MainActivity 有） | 需修正 | — | (a)「Host 随 Activity 销毁」不准——真正作废是 finish 场景；(b) 文档漏掉更实的后果：取消路径不清 ongoing 通知 → 僵尸「下载中」通知滞留 |
| O-133 | 本地化死分支 | DynamicPatternLocalization 死分支清单（修 A-061 的操作依据） | 需修正 | — | 总数 14 巧合对、成员错：误列 108/119（实为活支），漏 49/72/83/84/106；109 吞并者应为 :89。两路独立探针核验一致；按错误清单删减会引入真回归 |
| O-137 | Express 缓存键 | 缓存键忽略 DO/CD 位，与共享 DnsCacheKey 分歧 | 需修正 | — | 「每次查询都带 EDNS+DO」证伪（ensureEdns0 写 flags=0 不置 DO）；实际需客户端 DO 交替才塌缩，触发面远窄 |
| O-140 | Go 引擎并发 | Engine 回调/配置字段无锁读写（与 A-018 同题） | 需修正 | — | 活竞争面只剩 **responseType** 一个（DNS_MODE 运行中 syncRules 无锁写 vs 无锁读）；engine_standalone.go:246-249 实为持锁快照（文档误列）；firewallChecker/appResolver 零写入者 |
| O-145 | 生命周期残留 | WorkModeLifecycleRegistry 默认 lambda 写无人读取的 system_settings 死文件 | 需修正 | — | 触发窗口应改「非 EXPRESS（NORMAL/DNS）且本进程未加载 DnsVpnService」——文档「Express 悬浮日志」与 ExpressModeLauncher:161 分支矛盾；卫生级（A-048 同族双源残留） |
| O-146 | 权限建议 | 「不再提示」key 无 mode 维度：一模式点忽略后跨模式同类建议永久消音且无恢复入口 | 存在 | — | clearDismissedRecommendations 全仓零调用实证；影响限保活建议面，若产品意图为全局忽略则仅缺声明 |
| O-148 | 约定违例 | AGENTS.md「单文件 ≤550 行」超线清单 | 需修正 | — | 本会话全仓自数：文档口径 Kotlin 13（全对）+ Go **2**（漏 Desktop/internal/core/safebrowsing.go 569）；若口径含前端再漏 5 个（RulesPanel.vue 621 等）；maintenance 无违例。性质为可维护性违例，非行为缺陷 |
| O-150 | 极速 bootstrap/时钟 | (a) bootstrap 串行无总预算最坏 候选×2×3s 且每 UDP 包独立协程自我放大；(b) 网速用墙钟受校时跳变；(c) isVpnActive 判任意 VPN + unresolvablePackages 永久负缓存 | 需修正 | — | (a)「默认 7 预设≈42s」应改「默认启用 3 条≈18s，42s 需手工全开 7」（DEFAULT_BOOTSTRAP_PRESET_IDS=3）；(b) decayIdleSpeeds 实际安全（调用方单调 delay）；(c) 负缓存严格条件是「同进程未再经历 start()+refreshAppList」 |
| O-151 | 规则解析 | (a) SetRewriteRules 非字符串/数组值静默跳过零日志；(b) `~denyallow` 反义丢失 | 需修正 | — | (a) 生产构造点恒 JSONArray/String，当前无畸形值生产者；(b) JVM 实跑两种写法同 key 实证 isNegative 不进 :109 值（参与 :99 偏移裁剪，文档「从未参与赋值」略强）；条件性/弱概念，列低 |

## 未入级说明（O 系列其余条目复核结论）

以下观察项经复核**不构成缺陷**（机制不可达、后果不成立、属产品语义或取证缺口），不进入本分级；结论以本节为准（原文档已删除）：

- **证伪留痕仍有效**：O-101、O-139、O-147、O-149（逐项拆验，含 #8 badfilter 撤销、#10 hosts 多域名行、scopeDirectory 后果、Engine.Start 零调用者）。
- **当前不可达（latent/接线之日再修）**：O-102（入口函数本身零调用者，文档「未传 dataset」表述过强）、O-116、O-130、O-134、O-141、O-142、O-144。
- **非缺陷（固有限制/产品语义/无观察后果）**：O-108、O-111、O-113、O-115、O-118（isUsableUpstreamResponse 仅 QR+TXID 属硬化缺口非确定性错误；Express 孪生至少钉 rcode，孪生实际路径为 express/dns/）、O-129、O-131（副标题成分全 ASCII，「英文界面保持中文」后果不成立）、O-132（口径佐证，修复面比文档担心的窄——统计卡不复用 DNS 行集）、O-135、O-136、O-105、O-114（存在 EDNS0 bufsize=1232 减面，文档未提）、O-127（S1 被 onStop 取消链结构性关闭）、O-152（两端一致偏离，属覆盖率非一致性）。
- **卫生/事实缺口，维持不定级**：O-106（受害面应仅 EXPRESS，DNS_MODE 无该三键写入者）、O-109、O-110、O-122、O-143（新发现 25/112 条资源键与其原文哈希自指不符、全仓可达键仅 61/112——映射链漂移，待澄清后另议）、O-138（API 29 bundled SQLite 版本一手源仍未取到，维持「真机 logcat 定版」路径；命中则应升**高**——流量历史全丢，未命中降卫生项）。
