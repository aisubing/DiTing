/// 字号设置页（「字体设置 → 字号」的二级页）。
///
/// 旧版把字号做成外观设置里的一段滑杆，与「纯黑」「字体」同屏；用户要求把它
/// 收进「字体设置」这个二级页底下，让外观页只留入口、字号页只放一段可控的
/// 预览 + 滑杆。
///
/// 滑杆本身复用 [SliderCardRow]，与外观子树其它输入行同一套视觉；范围取
/// `minTextScale`–`maxTextScale`（0.8–1.4），并给出 0.1 的刻度——和
/// `clampTextScale` 的夹取边界一致，超过这个范围的输入在 provider 里会被夹回，
/// 这里不重复夹。
library;

import 'package:diting/app/theme/layout.dart';
import 'package:diting/pages/appearance/appearance_inputs.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 字号设置页。
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

/// 顶部预览：用当前字号渲染一段示例，改动滑杆时立刻能看出大小。
///
/// `MediaQuery` 在全局已按 `textScaleProvider` 缩放整棵树，所以这里不再手动
/// 乘缩放系数——否则预览会比实际界面大两倍。
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
