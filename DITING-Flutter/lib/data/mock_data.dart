/// 演示数据：服务商、规则、应用与功能中心卡片。
///
/// 这个库剩下的都是**仍在使用**的内容：服务商预设与三类规则（真实配置的兜底
/// 输入）、已安装应用演示清单、功能中心卡片清单。曾经的订阅 / 日志 / 服务统计
/// 常量已随本轮接线删除（见 `mock_content.dart` 的类注释）。
///
/// 按域拆成四个 part（AGENTS.md 的 550 行上限）：
/// - `mock_providers.dart`：解析服务商 + 三类规则；
/// - `mock_content.dart`：`ServiceStats`（唯一剩下的模型）；
/// - `mock_apps.dart`：应用流量、已安装应用、流量采样；
/// - `mock_feature_hub.dart`：功能中心卡片清单。
library;

part 'mock_providers.dart';
part 'mock_content.dart';
part 'mock_apps.dart';
part 'mock_feature_hub.dart';
