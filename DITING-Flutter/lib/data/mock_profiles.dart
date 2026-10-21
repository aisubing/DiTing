/// 演示数据：配置档案领域（上游 `lib/views/profiles/` 15 个文件，约 8,600 行）。
///
/// 全部是编译期常量或轻量构造函数，没有网络、没有数据库、没有真实配置文件。
/// 数值刻意做得像真的（订阅 42 个节点、48,213 条规则、44% 流量），因为空数据
/// 看不出卡片网格、进度条与成员列表在真实密度下的表现。
///
/// 按域拆成四个 part（AGENTS.md 的 550 行上限）：
/// - `mock_profiles_models.dart`：档案类型、自动更新周期、档案与覆写；
/// - `mock_profiles_custom.dart`：自定义配置的节点 / 组 / 规则 / 提供者 / 拨号器类型；
/// - `mock_profiles_seed.dart`：上面那些类型的初始常量表；
/// - `mock_profiles_extend.dart`：扩展模式、脚本、追加规则、预览用 YAML、图标候选。
library;

part 'mock_profiles_models.dart';
part 'mock_profiles_custom.dart';
part 'mock_profiles_seed.dart';
part 'mock_profiles_extend.dart';
