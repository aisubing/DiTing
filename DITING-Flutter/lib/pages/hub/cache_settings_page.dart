import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/cache_presets.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// DNS cache settings (upstream `CacheSettingsScreen`). The switch and presets write the
/// nine legacy `dns_cache_*_v2` keys directly, because the engine follows that policy; the
/// level list is demo data.
class CacheSettingsPage extends ConsumerWidget {
  const CacheSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final enabled = settings.cacheEnabled;
    final preset = DnsCachePreset.current(settings);
    return CommonScaffold(
      title: context.l10n.cacheSettingsTitle,
      body: PageBody(
        children: [
          generateSection(
            title: context.l10n.cacheSection,
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.memory),
                title: Text(context.l10n.cacheLocalDns),
                subtitle: Text(
                  enabled
                      ? '${preset.label}：${preset.summary}'
                      : context.l10n.cacheOffNote,
                ),
                value: enabled,
                onChanged: (value) {
                  preset.applyTo(settings, enabled: value);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
            ],
          ),
          if (enabled)
            generateSection(
              title: context.l10n.cachePresetSection,
              items: [
                for (final option in DnsCachePreset.values)
                  ListItem(
                    leading: GlyphIcon(
                      preset == option
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text(option.label(context.l10n)),
                    subtitle: Text('${option.summary}。${option.description}'),
                    trailing: preset == option ? const SelectionCheck() : null,
                    onTap: () {
                      option.applyTo(settings, enabled: enabled);
                      ref.read(legacySettingsRevisionProvider.notifier).bump();
                    },
                  ),
              ],
              footer:
                  context.l10n.cachePresetNote,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
