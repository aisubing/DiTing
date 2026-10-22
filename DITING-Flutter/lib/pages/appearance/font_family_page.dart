/// 字体设置页（上游 `views/font_family.dart`，194 行）。
///
/// 上游用平台通道读系统字体表，逐帧把每个名字换成它自己的字族——第一帧用
/// 默认字体渲染、随后逐个切换，因为一次给几十个家庭加载字体卡主线程。演示层
/// 不接平台通道，改成「进页面时异步加载（`Future.delayed`）+ 骨架」，同样保留
/// 逐项延迟上字体的效果，但来源换成 `mock_forms.dart` 的静态表。
///
/// **这一页是「字体设置」，不是单纯的字体族选择**：字号滑杆从外观设置页搬到了
/// 这里的二级页（`/font-size`），标题也随之从「字体族」改成「字体设置」。
/// 外观设置页只剩一个「字体」入口。
library;

import 'dart:async';

import 'package:diting/data/mock_forms.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 字体设置页：字号入口 + 字体族选择。
class FontFamilyPage extends ConsumerStatefulWidget {
  const FontFamilyPage({super.key});

  @override
  ConsumerState<FontFamilyPage> createState() => _FontFamilyPageState();
}

class _FontFamilyPageState extends ConsumerState<FontFamilyPage> {
  /// `null` 表示仍在「加载」；空列表表示真的没有可选字体。
  List<MockFontFamily>? _families;

  /// 已经能用自己的字族渲染的条目。逐帧放行，避免一屏同时加载全部字体。
  final _shown = <String>{};

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() => _families = mockFontFamilies);
    _revealNext();
  }

  /// 每 90ms 放行一个条目；全部放行后停表。
  void _revealNext() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      final families = _families;
      if (!mounted || families == null) {
        timer.cancel();
        return;
      }
      final next = families.firstWhere(
        (family) => !_shown.contains(family.label),
        orElse: () => _noMore,
      );
      if (identical(next, _noMore)) {
        timer.cancel();
        return;
      }
      setState(() => _shown.add(next.label));
    });
  }

  static final _noMore = MockFontFamily(
    family: null,
    label: '',
    description: '',
  );

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedFontFamilyProvider);
    final scale = ref.watch(textScaleProvider);
    final families = _families;
    return CommonScaffold(
      title: '字体设置',
      body: families == null
          ? const _FontSkeleton()
          : PageBody(
              dockSpacer: false,
              children: [
                // 字号入口：滑杆搬进 `/font-size` 二级页，这里只留一行入口，
                // 副标题直接显示当前档位，不必点进去才知道。
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: CommonCard(
                    padding: EdgeInsets.zero,
                    child: ListItem(
                      title: const Text('字号'),
                      subtitle: Text('当前 ${(scale * 100).round()}%'),
                      leading: const GlyphIcon(AppGlyphs.textSize),
                      trailing: const GlyphIcon(
                        AppGlyphs.chevronForward,
                        size: 20,
                      ),
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
                    for (final family in families)
                      _FontRow(
                        family: family,
                        selected: family.family == selected,
                        preview: _shown.contains(family.label),
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
                    '字体的「预览」一栏会先按默认字体渲染，再逐项换成各自字族，'
                    '这是上游为了不卡住首帧而做的分帧加载；这里用 90ms 的定时代替。',
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

/// 加载中的骨架：一行页首 + 六行列表。
class _FontSkeleton extends StatelessWidget {
  const _FontSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12 + context.contentTopPadding, 16, 24),
      children: [
        const SkeletonPill(width: double.infinity, height: 96),
        const SizedBox(height: 20),
        for (var i = 0; i < 6; i++) ...[
          Row(
            spacing: 12,
            children: [
              const SkeletonPill(width: 34, height: 34),
              Expanded(child: SkeletonText(width: 60 + i * 24.0)),
            ],
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

/// 页首：用当前选中的字族渲染一段示例文字。
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

/// 一行字体：名字用它自己的字族渲染，右侧是选中标记。
class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.family,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final MockFontFamily family;
  final bool selected;

  /// 是否已经可以换成自己的字族渲染。
  final bool preview;

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
                fontFamily: preview ? family.family : null,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      title: Text(
        family.label,
        style: preview ? TextStyle(fontFamily: family.family) : null,
      ),
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
