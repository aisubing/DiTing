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

## 观察（未达到确认缺陷标准，供后续验证）

### O-101 `MIGRATION_1_2`/`DNS_RULES_MIGRATION_1_2` 建表的 `enabled ... DEFAULT 1` 与实体无默认值声明同样漂移
- `AppDatabase.kt:56`、`DnsRulesDatabase.kt:49`、`cosmetic_rule_source` 的 `enabled DEFAULT 1`（`AppDatabase.kt:66`、`DnsRulesDatabase.kt:59`）与 `CosmeticRuleEntity.kt:28`/`CosmeticRuleSourceEntity.kt:17`（均无 `@ColumnInfo(defaultValue)`）不匹配。
- 但仅影响曾走 1→2 迁移的历史设备；从 tag 可见的已发布版本起 schema 已是 v2（表由生成代码创建、无 DEFAULT），当前升级路径（v2→v3）不触发该列漂移。随 A-011 一并修正最稳妥。

### O-102 `RuleOperationWorker.importCategorizedRules` 硬编码 `AppDatabase.getInstance`
- `RuleOperationWorker.kt:411` 取 `AppDatabase`，而 worker 其余部件按 `KEY_DATASET` 路由（`:145-151`）；`IMPORT_RULES`/`IMPORT_HOSTS_RULES` 的唯一入队点（`RuleManagementViewModel.kt:84,166`）未传 dataset（默认 NORMAL），当前不可达错位；若未来任何入口以 DNS_MODE/EXPRESS 入队这两类任务，URL/元素隐藏规则将写进普通模式库。设计耦合，暂列观察。
