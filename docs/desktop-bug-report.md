# 安卓端 Bug 记录

> 文件名沿用项目既定约定（`docs/desktop-bug-report.md`），内容为安卓客户端扫描结果，不包含桌面端问题。
>
> - 扫描基线：`main` @ `3a048c5`（含修复提交 `18319ed`）
> - 扫描范围：`Android/app/src/main/java/com/haoze/diting/` 与 `Android/tunnel/`
> - 记录原则：只记录问题，不修改代码；每条给出代码位置、触发路径和验证方式。存疑但未达到确认标准的事项统一放在文末“观察”。
> - 前一轮（基线 `6da118e`）的 A-001…A-010 已由 `18319ed` 修复并从本文档删除，本轮编号从 A-011 起，避免与历史编号重复。
> - 验证状态：A-011 的 Room 校验语义依据本机 Gradle 缓存中的 `room-runtime 2.7.0` 字节码（`TableInfoKt.equalsCommon`/`defaultValueEqualsCommon`/`RoomOpenHelper.onUpgrade`）与 KSP 生成代码（`app/build/generated/ksp/debug/.../AppDatabase_Impl.kt`）逐项核对；升级路径需真机/模拟器取证。

## 汇总

| 编号 | 严重度 | 模块 | 问题 | 状态 |
| --- | --- | --- | --- | --- |
| A-011 | 高 | 数据库迁移 | `isException` 迁移的 `ALTER ... DEFAULT 0` 与实体生成的期望 schema 不一致，升级设备打开数据库即抛 `IllegalStateException`（`18319ed` 引入的回归） | 待处理 |
| A-012 | 中 | VPN IPv6 探测 | AUTO 模式的网关/路由检查是死代码：只要接口有 GUA 地址就启用 IPv6，与函数文档「地址 AND 路由」相反（normal 与 Express 两份拷贝同犯） | 待处理 |

---

## A-011 三库 `isException` 迁移与 Room 期望 schema 的 DEFAULT 不一致，升级后每次打开数据库都失败

- **位置**
  - `Android/app/src/main/java/com/haoze/diting/data/AppDatabase.kt:79` — `ALTER TABLE cosmetic_rule ADD COLUMN isException INTEGER NOT NULL DEFAULT 0`
  - `Android/app/src/main/java/com/haoze/diting/data/DnsRulesDatabase.kt:70` — 同句
  - `Android/app/src/main/java/com/haoze/diting/data/ExpressRulesDatabase.kt:49` — 同句
  - `Android/app/src/main/java/com/haoze/diting/data/entity/CosmeticRuleEntity.kt:28-29` — `val enabled: Boolean = true`、`val isException: Boolean = false`，均无 `@ColumnInfo(defaultValue = ...)`
  - 生成代码（本机构建产物）：`Android/app/build/generated/ksp/debug/kotlin/com/haoze/diting/data/AppDatabase_Impl.kt:181` — 期望 CREATE TABLE 中 `` `isException` INTEGER NOT NULL ``，无 DEFAULT
- **问题**
  - 迁移 SQL 给 `cosmetic_rule.isException` 带上了 SQL 层 `DEFAULT 0`；而实体声明（Kotlin 属性默认值 `= false`）在 Room 里不生成 SQL DEFAULT，期望 schema 该列无默认值。两者经 `TableInfo` 对比不相等，迁移后校验失败。
- **机制**（逐项对 Room 2.7.0 实际字节码核对，非凭记忆）
  - `TableInfo$CREATED_FROM_ENTITY = 1`、`CREATED_FROM_DATABASE = 2`（`TableInfo.class` 常量）。
  - `TableInfoKt.equalsCommon(Column, Any)`：当 `expected.createdFrom == ENTITY(1)` 且 `existing.createdFrom == DATABASE(2)` 且 existing 的 `defaultValue != null` 时，必须 `defaultValueEqualsCommon(expected, existing)` 为真；`defaultValueEqualsCommon` 仅在两值 `areEqual` 或 current 带成对括号（`( … )`）时相等——`null` 与 `"0"` 不相等，也无括号可容忍。
  - `PRAGMA table_info` 读回的 ALTER 列 `dflt_value = '0'`、createdFrom=DATABASE；KSP 生成的期望列 defaultValue=null、createdFrom=ENTITY → 列不相等 → `onValidateSchema` 返回 `ValidationResult(false, "cosmetic_rule(...)...")`。
  - `RoomOpenHelper.onUpgrade`：`findMigrationPath(2,3)` 非空（三个库都注册了迁移），因此走“执行迁移 → onValidateSchema → 失败直接 `throw IllegalStateException("Migration didn't properly handle: ...")`”分支；`fallbackToDestructiveMigration(true)` 只在 *没有注册迁移* 的路径生效，救不了本例。框架侧 `patchVersion` 事务回滚，`user_version` 不推进，之后每次打开重试迁移、每次抛出。
  - 三库同犯：`diting_database`（2→3）、`diting_dns_rules`（2→3）、`diting_express`（1→2）。索引重建部分（`DROP INDEX` + `CREATE UNIQUE INDEX index_cosmetic_rule_domain_selector_isException`）与实体 `@Index` 一致，没有问题；唯一分叉点是 `DEFAULT 0`。
  - 对照证明作者知晓该约定：`DnsCacheEntity.kt:25` 的 `hitCount` 就写了 `@ColumnInfo(defaultValue = "0")`，与 `dns_cache` 期望 schema 对齐。
- **用户可见影响**
  - 从任何已发布版本（tag 1.1.5…1.2.11 均为 schema v2；`git show <tag>:AppDatabase.kt` 可证）升级到含 `18319ed` 的版本后，AppDatabase/DnsRules/Express 三库在升级后第一次打开即抛异常。外层多为 `runCatching` 包裹的调用点会表现为“规则列表为空/保存失败/数据库不可用”等功能性损坏，未捕获路径直接崩溃；且异常在回滚前抛出，重启复现，无法自愈。
  - 恰好命中上一轮 A-002 修复要服务的场景（老设备带着既有元素隐藏规则升级）：升级即坏。
- **触发路径**
  - 安装 1.2.x（或任何 schema v2 构建）→ 添加任意元素隐藏规则 → 覆盖安装到 `18319ed` 之后的构建 → 打开黑名单页或启动任一模式。
- **复现/验证**
  1. 设备/模拟器装 tag `1.2.11`，`adb run-as` 确认 `diting_database` `PRAGMA user_version = 2`；装本分支 APK，冷启动后访问任一规则界面：期望正常，实际 logcat 出现 `java.lang.IllegalStateException: Migration didn't properly handle: cosmetic_rule(...)`，Expected 段该列无 DEFAULT、Found 段带 `defaultValue=0`。
  2. 静态取证：把三个 `ALTER` 语句的 `DEFAULT 0` 删去（或给实体 `isException` 加 `@ColumnInfo(defaultValue = "0")` 并同步 `enabled` 与三库 `MIGRATION_1_2` 的 `DEFAULT 1`），重跑 `:app:kspDebugKotlin` 对比生成 schema 与迁移 SQL 逐列一致。
  3. 建议长期措施：打开 `exportSchema = true` 并启用 Room 的 `migrationTestRule`/`AutoMigrationValidator`，把三库 schema 一致性纳入 CI（当前 `exportSchema = false`，本次只能从 KSP 产物取证）。
- **备注**
  - 修复时三库必须同步：`MIGRATION_2_3`（两库）与 `EXPRESS_MIGRATION_1_2` 要么全部去掉 `DEFAULT 0`（ALTER 需要 NOT NULL 列带默认值才能成功——SQLite 允许 `ADD COLUMN NOT NULL` 仅当有 DEFAULT，因此“去掉 DEFAULT”不可行），正确做法是给实体列补 `@ColumnInfo(defaultValue = "0")`，使期望 schema 与迁移一致；`enabled` 列与 `MIGRATION_1_2`/`DNS_RULES_MIGRATION_1_2` 的 `DEFAULT 1` 同理需对齐（`defaultValue = "1"`）。
  - 本条是 `18319ed`（上一轮 A-002 修复）引入的回归；按 AGENTS.md 已核对修复本身的语义正确（UPDATE 回填 `#@#`、索引重建无误），仅 schema 默认值漂移这一处破坏升级路径。

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

### O-101 `MIGRATION_1_2`/`DNS_RULES_MIGRATION_1_2` 建表的 `enabled ... DEFAULT 1` 与实体无默认值声明同样漂移
- `AppDatabase.kt:56`、`DnsRulesDatabase.kt:49`、`cosmetic_rule_source` 的 `enabled DEFAULT 1`（`AppDatabase.kt:66`、`DnsRulesDatabase.kt:59`）与 `CosmeticRuleEntity.kt:28`/`CosmeticRuleSourceEntity.kt:17`（均无 `@ColumnInfo(defaultValue)`）不匹配。
- 但仅影响曾走 1→2 迁移的历史设备；从 tag 可见的已发布版本起 schema 已是 v2（表由生成代码创建、无 DEFAULT），当前升级路径（v2→v3）不触发该列漂移。随 A-011 一并修正最稳妥。

### O-102 `RuleOperationWorker.importCategorizedRules` 硬编码 `AppDatabase.getInstance`
- `RuleOperationWorker.kt:411` 取 `AppDatabase`，而 worker 其余部件按 `KEY_DATASET` 路由（`:145-151`）；`IMPORT_RULES`/`IMPORT_HOSTS_RULES` 的唯一入队点（`RuleManagementViewModel.kt:84,166`）未传 dataset（默认 NORMAL），当前不可达错位；若未来任何入口以 DNS_MODE/EXPRESS 入队这两类任务，URL/元素隐藏规则将写进普通模式库。设计耦合，暂列观察。

### O-103 `refreshRuntimeConfig` 失败分支提交的 `activeResolutionMode` 与 Go 侧不一致
- `normal/DnsVpnRuntimeConfigManager.kt:137-161`：`resolveDnsProviders` onFailure 时向 Go 回写 `providers=oldProviders` + `resolutionMode=activeResolutionMode(旧值)`（`:142`），但 Kotlin 随后仍提交 `activeResolutionMode=newResolutionMode`（`:153`）；成功分支对 `goSyncError != null` 会提前 `return@fold`（`:127`）保持两侧一致，失败分支不对称，可能留下「新档位 + 旧上游」组合显示在前台通知。
- 未升级为缺陷：`DnsVpnProviderResolver.resolveDnsProviders` 的兜底路径（`:71` `listOf(DnsProvider.loadSelected(context))`）实测难以抛错，未构造出确定性触发。确认方法：构造使 `resolveDnsProviders` 抛异常的配置（损坏的持久化上游设置），切换多上游档位后比对 Go 配置与 Kotlin 状态。

### O-104 start/stop 微秒级交错可能在 Kotlin 判定停止后遗留运行中的 Go TUN 栈
- `normal/GoInspectionTunnel.kt:91-99`：`start()` 在 `scope.launch(Dispatchers.IO){ engine.startFull(...) }` 后立即返回 true，不确认 `startFull` 已进入；若 `stop()`（`:101-107`，`engine.stop()`）在 IO 协程到达 Go `StartFull` 的 `e.mu.Lock()`（`tunnel/engine_full_tunnel.go:92`）之前执行，Stop 见 `running=false` 直接返回，随后 StartFull 置 `running=true` 并新建 done channel，无人再持有。
- 未升级原因：需要极快的 ACTION_STOP 或 IO 池饥饿才能命中，且 Kotlin 侧 `startJob?.cancel()` 若在 `startFull` 启动前生效可避免；无确定性触发。确认方法：start/stop 微压力测试轮询 `Engine.IsRunning()`。
