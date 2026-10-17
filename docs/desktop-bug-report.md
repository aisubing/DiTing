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
  - `DnsVpnNetworkMonitor.kt:69` 的 `scheduleIpv6AdaptationCheck` 也基于该探测做自适应，同样被短路结果误导。
- **复现/验证**
  1. JVM 单测方向：向 `hasPhysicalIpv6Support` 注入/构造含 `2000::/64` 链路地址、routes 仅有 IPv4 默认路由的 `LinkProperties`，断言应为 false；当前实现返回 true（`:136` 恒真）。
  2. 真机：路由器关闭 v6 前缀的默认路由（RA 里 router-lifetime=0 或只发前缀不发路由），手机获得 GUA；AUTO 档开启 VPN，`logcat | grep establishVpnInterface` 显示 `enableIpv6=true`；对比 v6-only 目标（如 `curl -6 https://[2606:4700:4700::1111]`）经 VPN 黑洞、直连正常。
- **备注**
  - 意图明显是让 `&&`（地址且有路由）或至少以 `hasIpv6Route` 为决定项；按函数文档修正即可。两份拷贝必须同步修复，或将探测抽成共用函数（`core/diagnostic/NetworkInfoProbe.kt:15` 已引用其语义注释）。
  - `hasIpv6Route` 中 `route.hasGateway()` 对 on-link 直写路由同样为 true 的宽松性属另一层语义问题，修正短路后建议一并复核（未单列）。

---

## 观察（未达到确认缺陷标准，供后续验证）

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
