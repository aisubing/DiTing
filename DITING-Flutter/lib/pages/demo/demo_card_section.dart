part of 'demo_page.dart';

/// Cards: the six [CommonCard] states, the [InfoHeader] + [Info] header, and the
/// inline [SettingTextCard], [SortHandle], [DisclosureIndicator], [DetailButton].
class _DemoCardSection extends StatelessWidget {
  const _DemoCardSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel(
          'CommonCard 六种状态',
          trailing: 'isSelected / isError / inert',
        ),
        const _DemoCardStates(),
        const _DemoLabel('InfoHeader + Info', trailing: '卡片表头与右侧动作'),
        const _DemoInfoHeaders(),
        const _DemoLabel('SettingTextCard', trailing: '主题预设那种文字卡片'),
        const _DemoSettingCards(),
        const _DemoLabel('行内小件', trailing: 'SortHandle / Disclosure / Detail'),
        const _DemoInlineBits(),
      ],
    );
  }
}

class _DemoCardStates extends StatelessWidget {
  const _DemoCardStates();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    Widget body(String label) => Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        spacing: 10,
        children: [
          const GlyphIcon(AppGlyphs.layers, size: commonCardIconSize),
          Expanded(child: Text(label)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        CommonCard(child: body('普通卡片')),
        CommonCard(
          onPressed: () => _demoToast(context, '可点卡片'),
          child: body('可点卡片'),
        ),
        CommonCard(isSelected: true, child: body('isSelected（不填充）')),
        CommonCard(
          isSelected: true,
          fillsSelection: true,
          onPressed: () => _demoToast(context, '选中卡片'),
          child: body('isSelected + fillsSelection'),
        ),
        CommonCard(isError: true, child: body('isError')),
        CommonCard(inert: true, onPressed: () {}, child: body('inert（忽略点按）')),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: CommonCard(
                radius: AppCorner.sm,
                child: body('radius: sm'),
              ),
            ),
            Expanded(
              child: CommonCard(
                radius: AppCorner.xxl,
                child: body('radius: xxl'),
              ),
            ),
          ],
        ),
        CommonCard(
          shape: AppShape.circle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'shape: AppShape.circle',
              textAlign: TextAlign.center,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card header: a [Info] with a glyph and two actions, plus the minimal form.
class _DemoInfoHeaders extends StatelessWidget {
  const _DemoInfoHeaders();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        CommonCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoHeader(
                info: const Info(label: '流量统计', glyph: AppGlyphs.dataUsage),
                actions: [
                  AppBarActionButton(
                    data: IconButtonData(
                      glyph: AppGlyphs.refresh,
                      tooltip: '刷新',
                      onPressed: () => _demoToast(context, 'InfoHeader · 刷新'),
                    ),
                  ),
                  AppBarActionButton(
                    data: IconButtonData(
                      glyph: AppGlyphs.more,
                      tooltip: '更多',
                      onPressed: () => _demoToast(context, 'InfoHeader · 更多'),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'InfoHeader 右侧的动作区高度跟着 cardHeaderHeight 走，'
                  '所以加不加图标，表头总高不变。',
                  style: AppTextStyle.footnote.of(context),
                ),
              ),
            ],
          ),
        ),
        CommonCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoHeader(info: Info(label: '无字形的表头')),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'Info 的 glyph 为 null 时表头只有文字，行高取 lineHeight。',
                  style: AppTextStyle.footnote.of(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoSettingCards extends StatelessWidget {
  const _DemoSettingCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SettingTextCard(
            '浅色',
            onPressed: () => _demoToast(context, 'SettingTextCard · 浅色'),
          ),
        ),
        Expanded(
          child: SettingTextCard(
            '深色',
            isSelected: true,
            onPressed: () => _demoToast(context, 'SettingTextCard · 深色'),
          ),
        ),
        Expanded(
          child: SettingTextCard(
            '跟随系统',
            isSelected: false,
            onPressed: () => _demoToast(context, 'SettingTextCard · 跟随系统'),
          ),
        ),
      ],
    );
  }
}

/// Inline pieces: drag handle, disclosure indicator, detail button. [SortHandle]
/// ignores drags outside a reorderable list, so only its shape is verified here.
class _DemoInlineBits extends StatelessWidget {
  const _DemoInlineBits();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        CommonCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            spacing: 10,
            children: [
              const SortHandle(index: 0),
              Expanded(
                child: Text(
                  'SortHandle（需在可排序列表内才可拖）',
                  style: AppTextStyle.footnote.of(context),
                ),
              ),
              const DisclosureIndicator(),
            ],
          ),
        ),
        CommonCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  'DetailButton：行尾的圆形详情入口',
                  style: AppTextStyle.footnote.of(context),
                ),
              ),
              DetailButton(
                glyph: AppGlyphs.info,
                tooltip: '详情',
                onPressed: () => _demoToast(context, 'DetailButton'),
              ),
              DetailButton(
                glyph: AppGlyphs.link,
                tooltip: '禁用态',
                onPressed: null,
              ),
            ],
          ),
        ),
        Text(
          'DisclosureIndicator 是纯静态箭头，不带点击；需要点击请用 DetailButton。',
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}