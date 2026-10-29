/// Settings page: the legacy "other settings" list of five groups, plus the launch auto start and
/// VPN watchdog switches in the runtime group.
library;

import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/nav_entry_row.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The only app-bar action (wrench) opens the developer options hub, the single entry point for
/// pages the legacy app had no menu for. The list stays at the legacy five groups and six rows.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: context.l10n.hubOtherSettings,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.wrench,
          tooltip: context.l10n.devOptions,
          onPressed: () => context.push(SystemPaths.developer),
        ),
      ],
      body: PageBody(
        children: [
          // Each `_SettingsGroup` maps to a legacy `SettingsSection`; empty groups are skipped.
          _SettingsGroup(
            title: context.l10n.serverRunMode,
            items: [
              NavEntryRow(
                glyph: AppGlyphs.layers,
                title: context.l10n.serverRunMode,
                subtitle: context.l10n.settingsModeSubtitle,
                onPressed: () => context.push(Routes.modeSelect),
              ),
            ],
          ),
          _SettingsGroup(
            title: context.l10n.settingsPerformanceSection,
            items: [
              NavEntryRow(
                glyph: AppGlyphs.cpu,
                title: context.l10n.cacheSettingsTitle,
                subtitle: context.l10n.settingsCacheSubtitle,
                onPressed: () => context.push(HubPaths.cache),
              ),
              NavEntryRow(
                glyph: AppGlyphs.clock,
                title: context.l10n.logRetentionTitle,
                subtitle: context.l10n.settingsLogModeSubtitle,
                onPressed: () => context.push(HubPaths.logRetention),
              ),
            ],
          ),
          _SettingsGroup(
            title: context.l10n.settingsRuntimeSection,
            items: [
              NavEntryRow(
                glyph: AppGlyphs.eyeOff,
                title: context.l10n.foregroundTitle,
                subtitle: context.l10n.settingsForegroundSubtitle,
                onPressed: () => context.push(SystemPaths.foregroundBackground),
              ),
              ListItem.toggle(
                title: Text(context.l10n.settingsAutoStartTitle),
                subtitle: Text(context.l10n.settingsAutoStartSubtitle),
                leading: const GlyphIcon(AppGlyphs.bolt),
                value: ref.watch(autoStartOnLaunchProvider),
                onChanged: ref.read(autoStartOnLaunchProvider.notifier).toggle,
              ),
              ListItem.toggle(
                title: Text(context.l10n.settingsVpnWatchdogTitle),
                subtitle: Text(context.l10n.settingsVpnWatchdogSubtitle),
                leading: const GlyphIcon(AppGlyphs.vpn),
                value: ref.watch(vpnWatchdogProvider),
                onChanged: ref.read(vpnWatchdogProvider.notifier).toggle,
              ),
            ],
          ),
          // Appearance (order 3) is an empty group upstream: its entries moved to the feature hub.
          _SettingsGroup(
            title: context.l10n.settingsDataSection,
            items: [
              NavEntryRow(
                glyph: AppGlyphs.language,
                title: context.l10n.languageTitle,
                subtitle: context.l10n.settingsLanguageSubtitle,
                onPressed: () => context.push(SystemPaths.language),
              ),
            ],
          ),
          _SettingsGroup(
            title: context.l10n.hubOtherSettings,
            items: [
              NavEntryRow(
                glyph: AppGlyphs.puzzle,
                title: context.l10n.serverWizard,
                subtitle: context.l10n.settingsWizardSubtitle,
                onPressed: () => context.push(Routes.modeOnboarding),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) =>
      generateSection(title: title, items: items);
}
