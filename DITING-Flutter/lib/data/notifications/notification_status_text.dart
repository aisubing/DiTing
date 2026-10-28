/// Legacy-compatible notification bodies.
///
/// The foreground services only see the config JSON, which carries provider ids but no display
/// names, so Dart composes the default status line here and stores it in
/// `notification_settings_prefs`; a user-defined text still wins natively.
library;

import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';

/// Legacy wording, kept for the notification even where the UI uses shorter labels.
const _modeLabels = {
  'single': '单一服务',
  'smart_prediction': '智能选择',
  'parallel_race': '最快响应',
  'primary_backup': '依次尝试',
};

/// `已连接 · [最快响应] 3 个服务商` / `已连接 · 阿里云` / `已连接`; express prefixes
/// `极速模式运行中` instead, exactly like the legacy builder.
String defaultRunningNotificationText(
  LegacySettings settings, {
  required bool express,
}) {
  final config = buildDnsConfig(settings);
  final prefix = express ? '极速模式运行中' : '已连接';
  final providers = config.providers;
  if (providers.length > 1) {
    final mode = _modeLabels[config.mode] ?? config.mode;
    return '$prefix · [$mode] ${providers.length} 个服务商';
  }
  if (providers.isNotEmpty) return '$prefix · ${providers.first.name}';
  return prefix;
}

/// `当前上游: 阿里云 (223.5.5.5) · 端口 1053`: the legacy server body plus the listen port, which
/// differs from the legacy fixed 53.
String defaultServerNotificationText(LegacySettings settings) {
  final config = buildServerDnsConfig(settings);
  return '当前上游: ${config.upstream.name} (${config.upstream.address})'
      ' · 端口 ${config.port}';
}
