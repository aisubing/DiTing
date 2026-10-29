import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/state/feature_hub_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Hidden features (upstream `HiddenFeaturesScreen`). Hiding only affects the feature hub
/// and never disables anything; keys persist to `dns_vpn_prefs` / `hidden_features_set`.
class HiddenFeaturesPage extends ConsumerWidget {
  const HiddenFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final express = ref.watch(workModeProvider) == AppWorkMode.express;
    final hidden = ref.watch(hiddenFeatureKeysProvider);
    final groups = hiddenFeaturesByCategory(
      express: express,
      l10n: context.l10n,
    );
    return CommonScaffold(
      title: '隐藏功能',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.reset,
          tooltip: '恢复全部显示',
          onPressed: hidden.isEmpty
              ? null
              : () => ref.read(hiddenFeatureKeysProvider.notifier).resetAll(),
        ),
      ],
      body: PageBody(
        children: [
          PageIntroCard(
            text:
                '自定义在功能中心显示的功能卡片。关闭开关将从功能中心隐藏该卡片，'
                '默认全部显示。隐藏仅调整界面展示，不会影响功能的后台运行与规则生效。'
                '设置会保存到本机，重启后仍然有效。',
          ),
          for (final entry in groups.entries)
            generateSection(
              title: entry.key,
              items: [
                for (final feature in entry.value)
                  ListItem(
                    leading: GlyphIcon(
                      glyphByName(feature.glyphName),
                      size: 20,
                    ),
                    title: Text(feature.title),
                    subtitle: Text(feature.description),
                    trailing: CommonCheckBox(
                      value: !hidden.contains(feature.key),
                      onChanged: (visible) => ref
                          .read(hiddenFeatureKeysProvider.notifier)
                          .setVisible(feature.key, visible ?? true),
                    ),
                    onTap: () => ref
                        .read(hiddenFeatureKeysProvider.notifier)
                        .toggle(feature.key),
                  ),
              ],
            ),
          const ListFooter(text: '「隐藏功能」卡片固定常驻，确保随时可以在这里恢复。'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
