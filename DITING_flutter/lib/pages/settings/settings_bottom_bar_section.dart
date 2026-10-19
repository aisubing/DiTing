part of 'settings_page.dart';

/// 底栏分组：6 个可选项的开关、触感反馈、重置。
///
/// 上下限不是「校验失败就报错」，而是「点不动」：`BottomBarNotifier.toggle`
/// 被拒时返回 false 且状态不变，这里据此弹一句说明。开关先动再回弹会让用户
/// 以为点中了却没生效，比直接拒绝更糟。
class _BottomBarSection extends ConsumerWidget {
  const _BottomBarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(bottomBarProvider);
    final haptic = ref.watch(hapticProvider);
    final notifier = ref.read(bottomBarProvider.notifier);

    void onToggle(BottomBarDestination destination) {
      if (notifier.toggle(destination)) {
        return;
      }
      final selected = destinations.contains(destination);
      _showSettingHint(
        context,
        selected ? '底栏至少保留 2 项' : '底栏最多 $maxDockDestinations 项',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: '底栏项（${destinations.length}/$maxDockDestinations）',
          actions: [
            IconButtonData(
              glyph: AppGlyphs.reset,
              tooltip: '恢复默认底栏',
              onPressed: () {
                notifier.reset();
                _showSettingHint(context, '已恢复默认底栏');
              },
            ),
          ],
          footer: '至少 2 项、最多 $maxDockDestinations 项：浮条按项数等比分配宽度，'
              '再多就会挤到无法点按。顺序固定，不随开关变化。',
          items: [
            for (final destination in BottomBarDestination.values)
              ListItem.toggle(
                title: Text(destination.label),
                leading: GlyphIcon(destination.glyph),
                value: destinations.contains(destination),
                onChanged: (_) => onToggle(destination),
              ),
          ],
        ),
        const SizedBox(height: 6),
        generateSection(
          items: [
            ListItem.toggle(
              title: const Text('触感反馈'),
              subtitle: const Text('切换底栏页时触发一次轻震'),
              leading: const GlyphIcon(AppGlyphs.motion),
              value: haptic,
              onChanged: (value) =>
                  ref.read(hapticProvider.notifier).toggle(value),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _DockPreview(destinations: destinations),
      ],
    );
  }
}

/// 底栏实时预览。
///
/// 设置页最怕「改完不知道长什么样、得退回去看」；这里用和真实浮条同一套
/// 图标与文案画一条只读预览，改开关时立刻能看到宽度变化。
class _DockPreview extends StatelessWidget {
  const _DockPreview({required this.destinations});

  final List<BottomBarDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('预览', style: context.listCaptionStyle),
          Center(
            child: AnimatedSize(
              duration: midDuration,
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(colorScheme),
                  shape: AppShape.full,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    for (final destination in destinations)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            GlyphIcon(
                              destination.glyph,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            Text(
                              destination.label,
                              style: AppTextStyle.caption2.of(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
