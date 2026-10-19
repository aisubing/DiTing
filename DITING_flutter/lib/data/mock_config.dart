/// 配置领域演示数据：通用 / 网络 / 覆写 / 数据资源四个 part。
///
/// 与 `mock_data.dart` 分开，是因为配置域的数据几乎全部可编辑（开关、端口、
/// 键值表、列表、脚本代码）。这里只放**初始值**，可变副本由
/// `lib/state/config_providers.dart` 持有；把两者混在一份常量里，热重载后
/// 「用户改过的状态」会污染初始值，下一次进页面就回不到演示起点。
///
/// 按 AGENTS.md 的 550 行上限拆成四个 part：
/// - `mock_config_general.dart`：日志级别、Hosts、通用设置；
/// - `mock_config_network.dart`：VPN / TUN / 系统代理 / 出站选项；
/// - `mock_config_override.dart`：覆写键规格（TUN / NTP / 嗅探）与协议配置；
/// - `mock_config_dns.dart`：DNS 覆写规格与策略表；
/// - `mock_config_resources.dart`：过滤器、追加规则、脚本、Clash 提供者、
///   图标集、User-Agent、按需连接。
library;

part 'mock_config_general.dart';
part 'mock_config_network.dart';
part 'mock_config_override.dart';
part 'mock_config_dns.dart';
part 'mock_config_resources.dart';
