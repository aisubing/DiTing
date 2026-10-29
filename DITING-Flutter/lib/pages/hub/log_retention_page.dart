/// Log mode (legacy `ui/LogRetentionSettingsScreen.kt`): `dns_log_mode`, `log_retention_days`.
/// Crash logs live on the 故障排查 page in 数据与维护.
library;

import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LogRetentionPage extends ConsumerWidget {
  const LogRetentionPage({super.key});

  static const _retentionOptions = [1, 7, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(logModeProvider);
    final retentionDays = ref.watch(logRetentionProvider);
    final floatingLog = ref.watch(floatingLogProvider);
    return CommonScaffold(
      title: '日志模式',
      body: PageBody(
        children: [
          generateSection(
            title: 'DNS 请求日志',
            items: [
              for (final option in LegacyLogMode.values)
                ListItem(
                  leading: GlyphIcon(
                    mode == option ? AppGlyphs.checkCircle : AppGlyphs.logs,
                    size: 20,
                  ),
                  title: Text(option.label(context.l10n)),
                  subtitle: Text(option.description(context.l10n)),
                  trailing: mode == option ? const SelectionCheck() : null,
                  onTap: () =>
                      ref.read(logModeProvider.notifier).select(option),
                ),
            ],
            footer: '关闭后不会删除已有日志，重新开启即可继续查看。',
          ),
          generateSection(
            title: '悬浮窗',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.eye),
                title: const Text('悬浮窗日志'),
                subtitle: const Text('VPN 运行且应用在后台时显示悬浮球，点击查看最近请求'),
                value: floatingLog,
                onChanged: (value) =>
                    ref.read(floatingLogProvider.notifier).toggle(value),
              ),
            ],
            footer: '需要系统悬浮窗权限；回到应用前台时悬浮窗会自动隐藏。',
          ),
          if (mode != LegacyLogMode.off)
            generateSection(
              title: '自动清理时间',
              items: [
                for (final days in _retentionOptions)
                  ListItem(
                    leading: GlyphIcon(
                      retentionDays == days
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text('保留 $days 天'),
                    trailing: retentionDays == days
                        ? const SelectionCheck()
                        : null,
                    onTap: () =>
                        ref.read(logRetentionProvider.notifier).set(days),
                  ),
              ],
              footer:
                  '超过所选时间的请求日志由隧道服务每小时清理一次'
                  '（首次在启动 30 秒后）。关闭日志不会删除已有记录。',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
