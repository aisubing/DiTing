/// Font settings page (upstream `views/font_family.dart`).
///
/// The app bundles no fonts: the list is the system default plus whatever TTF/OTF files the user
/// imported. Android exposes no system-font enumeration API without a native channel, so there is
/// nothing to scan for — a fixed list of vendor family names would only ever render in the fallback
/// face on most devices.
library;

import 'package:diting/data/fonts/font_repository.dart';
import 'package:diting/pages/appearance/appearance_shared_pages.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/font_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class FontFamilyPage extends ConsumerStatefulWidget {
  const FontFamilyPage({super.key});

  @override
  ConsumerState<FontFamilyPage> createState() => _FontFamilyPageState();
}

class _FontFamilyPageState extends ConsumerState<FontFamilyPage> {
  /// Importing reads and parses a file, so the button shows a spinner while the picker is open.
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedFontFamilyProvider);
    final scale = ref.watch(textScaleProvider);
    final fonts = ref.watch(importedFontsProvider);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PreviewHero(
              family: selected,
              label: fontLabelOf(fonts, selected),
            ),
          ),
          const SizedBox(height: 12),
          generateSection(
            title: '字体',
            items: [
              _FontRow(
                label: '系统默认',
                description: '跟随宿主平台的中文界面字体，最稳妥的选择',
                family: null,
                selected: selected == null,
                onTap: () => _select(null),
              ),
              for (final font in fonts)
                _FontRow(
                  label: font.label,
                  description: '已导入的第三方字体',
                  family: font.family,
                  selected: selected == font.family,
                  onTap: () => _select(font.family),
                  onDelete: () => _delete(font),
                ),
            ],
            footer: fonts.isEmpty
                ? '还没有导入字体。导入后即可在这里切换，字体文件只保存在本机。'
                : '导入的字体只影响本机显示，删除后会自动回退到系统默认。',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ImportCard(
              isImporting: _importing,
              onPressed: _importing ? null : _import,
            ),
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

  void _select(String? family) {
    ref.read(selectedFontFamilyProvider.notifier).select(family);
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final result = await ref.read(fontRepositoryProvider).import();
    if (!mounted) {
      return;
    }
    setState(() => _importing = false);
    if (result.cancelled) {
      return;
    }
    final font = result.font;
    if (font == null) {
      showSettingHint(context, result.error ?? '导入失败');
      return;
    }
    // Refresh the list, then switch to the new font so the user sees it applied.
    ref.invalidate(importedFontsProvider);
    _select(font.family);
    showSettingHint(context, '已导入 ${font.label}');
  }

  Future<void> _delete(ImportedFont font) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除字体',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: Text('删除「${font.label}」后，使用该字体的界面会回退到系统默认。'),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    // Fall back first: the engine keeps the registered bytes for the process lifetime, so the
    // selection has to move before the entry disappears.
    if (ref.read(selectedFontFamilyProvider) == font.family) {
      _select(null);
    }
    await ref.read(fontRepositoryProvider).delete(font);
    if (!mounted) {
      return;
    }
    ref.invalidate(importedFontsProvider);
    showSettingHint(context, '已删除 ${font.label}');
  }
}

/// Sample text rendered in the candidate face, labelled with the name the user picked.
class _PreviewHero extends StatelessWidget {
  const _PreviewHero({required this.family, required this.label});

  final String? family;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '谛听万象，明察清浊',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.title2
                .of(context, emphasized: true)
                .copyWith(fontFamily: family),
          ),
          const SizedBox(height: 6),
          Text(
            'The quick brown fox jumps over the lazy dog · 0123456789',
            style: AppTextStyle.footnote.of(context).copyWith(
              fontFamily: family,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          MetaChip(label: label),
        ],
      ),
    );
  }
}

/// One selectable font. `Aa` is drawn in the candidate face so the list itself previews each entry;
/// imported entries get a delete button in the trailing slot.
class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.label,
    required this.description,
    required this.family,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final String description;
  final String? family;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

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
          style: AppTextStyle.subheadline.of(context, emphasized: true).copyWith(
            fontFamily: family,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(label, style: TextStyle(fontFamily: family)),
      subtitle: Text(description),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDelete case final onDelete?)
            IconButton(
              tooltip: '删除',
              onPressed: onDelete,
              icon: const GlyphIcon(AppGlyphs.delete, size: 20),
            ),
          if (selected)
            const SelectionCheck()
          else
            const SizedBox(width: 24),
        ],
      ),
    );
  }
}

/// Import entry point, styled as a card so it reads as an action rather than another list row.
class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.isImporting, required this.onPressed});

  final bool isImporting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      onPressed: onPressed,
      inert: onPressed == null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GlyphIcon(
            AppGlyphs.importFile,
            size: commonCardIconSize,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入字体', style: context.listTitleStyle),
                const SizedBox(height: 2),
                Text(
                  isImporting ? '正在读取字体文件…' : '选择本机的 TTF / OTF 文件',
                  style: context.listSubtitleStyle,
                ),
              ],
            ),
          ),
          if (isImporting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const GlyphIcon(AppGlyphs.chevronForward, size: 20),
        ],
      ),
    );
  }
}
