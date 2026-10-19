part of 'settings_page.dart';

/// 首页分组：四个元素的透明度 + 两句首页文案。
///
/// 透明度的取值范围是 0.1–1.0 而不是 0–1.0：上游同样不提供「完全隐藏」，
/// 因为首页一旦把电源按钮调到 0，用户就再也找不到启动入口了。
class _HomeSection extends ConsumerWidget {
  const _HomeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = ref.watch(homeOpacityProvider);
    final sentence = ref.watch(homeSentenceProvider);
    final opacityNotifier = ref.read(homeOpacityProvider.notifier);
    final sentenceNotifier = ref.read(homeSentenceProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: '首页元素',
          actions: [
            IconButtonData(
              glyph: AppGlyphs.reset,
              tooltip: '恢复默认透明度',
              onPressed: opacityNotifier.resetAll,
            ),
          ],
          items: [
            for (final layer in HomeLayer.values)
              _OpacityRow(
                layer: layer,
                value: opacity[layer] ?? opacitySliderMax,
                onChanged: (value) => opacityNotifier.set(layer, value),
              ),
          ],
        ),
        const ListFooter(
          text: '透明度只影响首页展示，不影响功能；四个元素各自独立记忆，'
              '「恢复默认」一次把四项调回 100%。',
        ),
        const SizedBox(height: 6),
        generateSection(
          // 不叫「首页句子」：`HomeLayer.poem` 的滑杆标签已经是这四个字，
          // 两个同名标题上下相邻会看不出谁是分组、谁是控件。
          title: '首页文案',
          actions: [
            IconButtonData(
              glyph: AppGlyphs.reset,
              tooltip: '恢复默认句子',
              onPressed: sentenceNotifier.reset,
            ),
          ],
          footer: '句子留空即不显示。运行 / 停止两态各一条，'
              '因为它们出现在电源按钮下方的同一位置。',
          items: [
            ListItem.input(
              title: const Text('运行中显示'),
              subtitle: Text(
                sentence.running.isEmpty ? '（留空则不显示）' : sentence.running,
              ),
              leading: const GlyphIcon(AppGlyphs.bolt),
              dialogTitle: '运行中显示',
              value: sentence.running,
              suffixText: '',
              maxLength: 24,
              onChanged: (value) =>
                  sentenceNotifier.set(running: value?.trim() ?? ''),
            ),
            ListItem.input(
              title: const Text('已停止显示'),
              subtitle: Text(
                sentence.stopped.isEmpty ? '（留空则不显示）' : sentence.stopped,
              ),
              leading: const GlyphIcon(AppGlyphs.clock),
              dialogTitle: '已停止显示',
              value: sentence.stopped,
              suffixText: '',
              maxLength: 24,
              onChanged: (value) =>
                  sentenceNotifier.set(stopped: value?.trim() ?? ''),
            ),
          ],
        ),
      ],
    );
  }
}

/// 一条透明度滑杆。
///
/// 单独包一层是因为 `_SliderCard` 的读数要显示百分比，而 provider 存的是
/// 0.1–1.0 的原始值——换算只在这一处，别让调用方各自乘 100。
class _OpacityRow extends StatelessWidget {
  const _OpacityRow({
    required this.layer,
    required this.value,
    required this.onChanged,
  });

  final HomeLayer layer;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SliderCard(
      label: layer.label,
      value: value,
      min: opacitySliderMin,
      max: opacitySliderMax,
      divisions: opacitySliderSteps,
      valueLabel: '${(value * 100).round()}%',
      onChanged: onChanged,
    );
  }
}
