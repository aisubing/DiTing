/// Notification bodies for the three data planes.
///
/// The foreground services only see the config JSON, which carries provider ids but no display
/// names, so Dart composes the body here and stores it in `notification_settings_prefs`; a
/// user-defined text still wins natively.
///
/// Every mode shares one grammar, `运行中 · <上游>`, and carries its mode name in the title:
/// `运行中 · 阿里云`, `运行中 · [最快响应] 3 个服务商`, `运行中 · 阿里云 · 端口 1053`.
library;

import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';

/// Legacy wording of the resolution modes; shorter UI labels would not say what is racing.
const _modeLabels = {
  'single': '单一服务',
  'smart_prediction': '智能选择',
  'parallel_race': '最快响应',
  'primary_backup': '依次尝试',
};

/// `运行中 · [最快响应] 3 个服务商` / `运行中 · 阿里云` / `运行中`.
///
/// Normal and express share this shape; the mode itself is the notification title.
String defaultRunningNotificationText(LegacySettings settings) {
  final config = buildDnsConfig(settings);
  final providers = config.providers;
  if (providers.length > 1) {
    final mode = _modeLabels[config.mode] ?? config.mode;
    return '运行中 · [$mode] ${providers.length} 个服务商';
  }
  if (providers.isNotEmpty) return '运行中 · ${providers.first.name}';
  return '运行中';
}

/// `运行中 · 阿里云 · 端口 1053`: the upstream name plus the listen port, which is not 53 here.
String defaultServerNotificationText(LegacySettings settings) {
  final config = buildServerDnsConfig(settings);
  return '运行中 · ${config.upstream.name} · 端口 ${config.port}';
}
