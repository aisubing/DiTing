/// 配置域状态：只保留图标集 / User-Agent / 按需连接三张「保留资源」表。
///
/// 上一轮这个库还挂着通用 / 网络 / 四份覆写 / DNS 策略表 / 嗅探六族 provider，
/// 全部来自 FlClash 的内核配置。1.4.3 没有「内核配置」这个概念——它只管 DNS
/// 解析路径、规则、缓存与上游，没有 TUN 栈、没有 NTP、没有嗅探、没有内核覆写，
/// 因此那六族随页面一并删除。
///
/// 剩下的三张表由 `config_providers_resources.dart` 承载（它们是独立的 library
/// 而不是 part，避免为一个入口页保留整套配置库的依赖）。本文件只做转发，保持
/// 既有 import 路径 `package:diting/state/config_providers.dart` 不变。
library;

export 'config_providers_resources.dart';
