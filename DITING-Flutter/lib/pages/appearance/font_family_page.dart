/// Font settings page (upstream `views/font_family.dart`).
///
/// The list is the bundle's own `mockFontFamilies`, so it is available synchronously: there is no
/// system-font enumeration API on Android without a native channel, and pretending to scan for one
/// with a delay is what this page used to do.
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class FontFamilyPage extends ConsumerWidget {
  const FontFamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFontFamilyProvider);
    final scale = ref.watch(textScaleProvider);
    return CommonScaffold(
      title: '字体设置',
      body: PageBody(
        dockSpacer: false,
        children: [
          // Font size entry: the slider lives in `/font-size`, so the
          // subtitle shows the current scale here.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: EdgeInsets.zero,
              child: ListItem(
                title: const Text('字号'),
                subtitle: Text('当前 ${(scale * 100).round()}%'),
                leading: const GlyphIcon(AppGlyphs.textSize),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(SystemPaths.fontSize),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PreviewHero(family: selected, label: _labelOf(selected)),
          const SizedBox(height: 12),
          generateSection(
            title: '可选字体',
            items: [
              for (final family in mockFontFamilies)
                _FontRow(
                  family: family,
                  selected: family.family == selected,
                  onTap: () => ref
                      .read(selectedFontFamilyProvider.notifier)
                      .select(family.family),
                ),
            ],
            footer:
                '本仓只打包了 JetBrains Mono 与 Twemoji；'
                '其余是系统常见字体，选中未安装的字族会静默回退到系统默认。',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '选择只影响本机显示，不改动服务端规则。',
              style: context.listCaptionStyle,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _labelOf(String? family) {
    if (family == null) {
      return '系统默认';
    }
    for (final option in mockFontFamilies) {
      if (option.family == family) {
        return option.label;
      }
    }
    return family;
  }
}

class _PreviewHero extends StatelessWidget {
  const _PreviewHero({required this.family, required this.label});

  final String? family;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              '谛听万象，明察清浊',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.title2
                  .of(context, emphasized: true)
                  .copyWith(fontFamily: family),
            ),
            Text(
              'The quick brown fox jumps over the lazy dog · 0123456789',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(fontFamily: family),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                MetaChip(label: label),
                const Spacer(),
                Text(
                  family ?? '（跟随平台）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'JetBrainsMono',
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final MockFontFamily family;
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecorationListItem(
      isSelected: selected,
      onPressed: onTap,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: AppShape.sm,
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
        ),
        child: Text(
          'Aa',
          style: AppTextStyle.subheadline
              .of(context, emphasized: true)
              .copyWith(
                fontFamily: family.family,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      title: Text(family.label, style: TextStyle(fontFamily: family.family)),
      subtitle: Text(family.description),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (family.bundled)
            TonalChip(
              label: '内置',
              color: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          if (selected) const SelectionCheck() else const SizedBox(width: 24),
        ],
      ),
    );
  }
}