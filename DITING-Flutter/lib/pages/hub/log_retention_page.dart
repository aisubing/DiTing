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
      title: context.l10n.logRetentionTitle,
      body: PageBody(
        children: [
          generateSection(
            title: context.l10n.logRetentionDnsLogs,
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
            footer: context.l10n.logRetentionOffNote,
          ),
          generateSection(
            title: context.l10n.logRetentionOverlay,
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.eye),
                title: Text(context.l10n.logRetentionOverlayLogs),
                subtitle: Text(context.l10n.logRetentionOverlayBody),
                value: floatingLog,
                onChanged: (value) =>
                    ref.read(floatingLogProvider.notifier).toggle(value),
              ),
            ],
            footer: context.l10n.logRetentionOverlayNote,
          ),
          if (mode != LegacyLogMode.off)
            generateSection(
              title: context.l10n.logRetentionCleanup,
              items: [
                for (final days in _retentionOptions)
                  ListItem(
                    leading: GlyphIcon(
                      retentionDays == days
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text(context.l10n.logRetentionKeepDays('$days')),
                    trailing: retentionDays == days
                        ? const SelectionCheck()
                        : null,
                    onTap: () =>
                        ref.read(logRetentionProvider.notifier).set(days),
                  ),
              ],
              footer:
                  context.l10n.logRetentionCleanupNote,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
