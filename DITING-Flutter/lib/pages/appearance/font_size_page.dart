library;

import 'package:diting/app/theme/layout.dart';
import 'package:diting/pages/appearance/appearance_inputs.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class FontSizePage extends ConsumerWidget {
  const FontSizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    return CommonScaffold(
      title: '字号',
      body: PageBody(
        children: [
          const _SizePreview(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: EdgeInsets.zero,
              child: SliderCardRow(
                label: '字号',
                glyph: AppGlyphs.textSize,
                value: scale,
                min: minTextScale,
                max: maxTextScale,
                divisions: ((maxTextScale - minTextScale) / 0.1).round(),
                onChanged: (value) =>
                    ref.read(textScaleProvider.notifier).set(value),
              ),
            ),
          ),
          const ListFooter(
            text:
                '字号会同时放大正文、标题与列表行；'
                '范围为 ${minTextScale * 100}%–${maxTextScale * 100}%。',
          ),
        ],
      ),
    );
  }
}

/// `MediaQuery` already scales from `textScaleProvider`; multiplying again would double it.
class _SizePreview extends StatelessWidget {
  const _SizePreview();

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
              style: AppTextStyle.title2.of(context, emphasized: true),
            ),
            Text(
              '这是一段用来对比字号的示例文字，滑动下方的滑杆即可预览效果。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}