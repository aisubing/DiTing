part of 'access_page.dart';

/// 顶部的控制面板：总开关、模式、排序、来源过滤（上游 `AccessControlPanel`）。
///
/// 上游把这一整块塞进 banner 里、关闭时用 `DisabledMask` 整体压暗；这里沿用。
/// 但把「来源」的两个折叠开关也放进面板而不是菜单：「看哪些应用」和「怎么
/// 控制」是同一层级的事，藏进菜单会让人找不到。
class AccessControlPanel extends StatelessWidget {
  const AccessControlPanel({
    super.key,
    required this.state,
    required this.visibleCount,
    required this.onChanged,
  });

  final AccessControlState state;
  final int visibleCount;
  final ValueChanged<AccessControlState> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  state.enabled ? AppGlyphs.lock : AppGlyphs.lockOpen,
                  size: 20,
                  color: state.enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('启用访问控制', style: context.listTitleStyle),
                      Text(
                        state.enabled ? '拦截规则已生效' : '关闭时不限制任何应用',
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.enabled,
                  onChanged: (value) =>
                      onChanged(state.copyWith(enabled: value)),
                ),
              ],
            ),
            Divider(
              height: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            DisabledMask(
              // 关闭时整块变灰而不是隐藏：用户要知道「这里有东西，但需要先打开
              // 上面的开关」。
              status: !state.enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  // `SegmentedControl` 自身没有固有宽度（内部是 `Expanded`），
                  // 放进 `Row` 会拿到无界约束并直接崩掉；所以每一段都独占一行、
                  // 由外层 `stretch` 给它定宽。
                  _LabelledControl(
                    label: '控制模式',
                    child: SegmentedControl<AccessMode>(
                      segments: [
                        for (final mode in AccessMode.values)
                          (mode, mode.label),
                      ],
                      value: state.mode,
                      onChanged: (mode) =>
                          onChanged(state.copyWith(mode: mode)),
                    ),
                  ),
                  _LabelledControl(
                    label: '排序方式',
                    child: SegmentedControl<AccessSort>(
                      segments: [
                        for (final sort in AccessSort.values)
                          (sort, sort.label),
                      ],
                      value: state.sort,
                      onChanged: (sort) =>
                          onChanged(state.copyWith(sort: sort)),
                    ),
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: _FilterToggle(
                          label: '系统应用',
                          glyph: AppGlyphs.devices,
                          value: state.showSystemApps,
                          onChanged: (value) =>
                              onChanged(state.copyWith(showSystemApps: value)),
                        ),
                      ),
                      Expanded(
                        child: _FilterToggle(
                          label: '无网络权限',
                          glyph: AppGlyphs.wifiOff,
                          value: state.showNonInternetApps,
                          onChanged: (value) => onChanged(
                            state.copyWith(showNonInternetApps: value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              spacing: 6,
              children: [
                _CountPill(
                  label: '可见',
                  value: '$visibleCount',
                  color: colorScheme.onSurfaceVariant,
                ),
                _CountPill(
                  label: '已选',
                  value: '${state.selected.length}',
                  color: state.selected.isEmpty
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
                const Spacer(),
                Text(state.mode.label, style: context.listCaptionStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 一小段标题 + 控件。
///
/// `SegmentedControl` 需要确定宽度才能把分段等分，所以这里用上下结构而不是
/// 「标题在左、控件在右」——后者会把控件塞进宽度不确定的位置。
class _LabelledControl extends StatelessWidget {
  const _LabelledControl({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(label, style: context.listSubtitleStyle),
        child,
      ],
    );
  }
}

/// 一个小计数胶囊。
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        shape: AppShape.full,
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(label, style: context.listCaptionStyle),
          Text(
            value,
            style: AppTextStyle.footnote.of(context, emphasized: true).copyWith(
              color: color,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

/// 「图标 + 文字 + 开关」的小卡片，两个并排。
class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.glyph,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Glyph glyph;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: ShapeDecoration(
          shape: AppShape.md,
          color: value
              ? colorScheme.primary.withValues(alpha: 0.1)
              : context.raisedSurfaceLevel.colorOf(colorScheme),
        ),
        child: Row(
          spacing: 6,
          children: [
            GlyphIcon(
              glyph,
              size: 16,
              color: value ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listCaptionStyle.copyWith(
                  color: value
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}
