/// 演示数据：服务商、规则、订阅、日志、流量、应用。
///
/// 全部是编译期常量或轻量 getter，没有网络、没有数据库。数值刻意做得像真的
/// （延迟 8–180ms、命中率 60%–90%），因为空数据看不出列表、图表和统计卡在
/// 真实密度下的表现——而「真实密度」正是这些页面要验证的东西。
///
/// 按域拆成三个 part（AGENTS.md 的 550 行上限）：
/// - `mock_providers.dart`：解析服务商 + 三类规则；
/// - `mock_content.dart`：订阅、日志、缓存、竞速排行、服务统计；
/// - `mock_apps.dart`：应用流量、已安装应用、功能中心卡片、流量采样。
library;
part 'mock_providers.dart';
part 'mock_content.dart';
part 'mock_apps.dart';
