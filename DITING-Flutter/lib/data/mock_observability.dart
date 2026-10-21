/// 观测域演示数据：连接 / 请求 / DNS 查询 / 资源更新 / IP 质量。
///
/// 数据层不依赖 widget 层：网络类型、图标名这类展示属性以字符串记录，图标由
/// 页面侧 `glyphByName` 解析（与 `mock_data.dart` 同一约定）。数值按真实量级
/// 取值（上行 10–80 KB、下行 200 KB–15 MB），列表在真实密度下才看得出问题。
///
/// 明细用「记录表 + 映射」的写法而不是逐条 `const`：连接与请求各有二十多条，
/// 逐条写会把常量区撑到几百行，而它们的字段几乎完全重复。
///
/// 按 AGENTS.md 的 550 行上限拆成四个 part：
/// - `mock_observability_connections.dart`：连接；
/// - `mock_observability_requests.dart`：请求；
/// - `mock_observability_dns.dart`：DNS 查询与 IP 质量；
/// - `mock_observability_resources.dart`：四类可刷新资源。
library;

part 'mock_observability_connections.dart';
part 'mock_observability_dns.dart';
part 'mock_observability_requests.dart';
part 'mock_observability_resources.dart';
