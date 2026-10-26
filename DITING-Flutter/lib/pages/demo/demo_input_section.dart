part of 'demo_page.dart';

/// Inputs: normal, focused and disabled states of [SearchField], [CommonCheckBox],
/// [SecretTextFormField] and [SegmentedControl], all interactive so the focus ring can be checked.
class _DemoInputSection extends StatefulWidget {
  const _DemoInputSection();

  @override
  State<_DemoInputSection> createState() => _DemoInputSectionState();
}

class _DemoInputSectionState extends State<_DemoInputSection> {
  final _searchController = TextEditingController();
  final _secretController = TextEditingController(text: 'diting-2026');
  final _plainController = TextEditingController(text: 'diting');
  final _filledController = TextEditingController(text: '填入式输入');
  bool? _checked = true;
  bool _circleChecked = false;
  int _segment = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _secretController.dispose();
    _plainController.dispose();
    _filledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('SearchField', trailing: 'ValueChanged<String>'),
        SearchField(onChanged: (value) => setState(() {})),
        const _DemoLabel('SearchField + controller', trailing: '预填关键词'),
        SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
        ),
        const _DemoLabel('SegmentedControl<T>', trailing: '三选一 / 二选一'),
        SegmentedControl<int>(
          segments: const [(0, '规则'), (1, '代理'), (2, '直连')],
          value: _segment,
          onChanged: (value) => setState(() => _segment = value),
        ),
        const SizedBox(height: 6),
        SegmentedControl<bool>(
          segments: const [(false, '关闭'), (true, '开启')],
          value: _circleChecked,
          onChanged: (value) => setState(() => _circleChecked = value),
        ),
        const _DemoLabel('CommonCheckBox', trailing: 'isCircle: false / true'),
        const _DemoCheckBoxRow(),
        _DemoCheckBoxes(
          checked: _checked,
          circleChecked: _circleChecked,
          onChecked: (value) => setState(() => _checked = value),
          onCircleChecked: (value) =>
              setState(() => _circleChecked = value ?? false),
        ),
        const _DemoLabel('SecretTextFormField', trailing: '默认遮蔽 / 多行'),
        SecretTextFormField(
          controller: _secretController,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '输入订阅密码',
          ),
        ),
        const SizedBox(height: 6),
        SecretTextFormField(
          controller: _plainController,
          maxLength: 16,
          decoration: const InputDecoration(labelText: '带字数上限'),
        ),
        const _DemoLabel('FilledInputTheme', trailing: '填充式输入外框'),
        FilledInputTheme(
          child: TextField(
            controller: _filledController,
            decoration: const InputDecoration(
              hintText: '输入内容',
              prefixIcon: GlyphIcon(AppGlyphs.search),
            ),
          ),
        ),
        const _DemoLabel('InputDialog', trailing: '点按弹出输入对话框'),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.edit,
          label: '打开 InputDialog',
          onPressed: () => _openInputDialog(context),
        ),
        const ListFooter(
          text:
              'SegmentedControl 的滑块用 AnimatedAlign 走 250ms easeOutCubic，'
              '所以连续切换时滑块会追着走，而不是瞬移。',
        ),
      ],
    );
  }

  Future<void> _openInputDialog(BuildContext context) async {
    final result = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '重命名',
        value: '默认策略',
        labelText: '策略名',
        hintText: '留空则使用默认值',
        resetValue: '默认策略',
        maxLength: 24,
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? '名称不能为空' : null,
      ),
    );
    if (context.mounted) {
      _demoToast(context, 'InputDialog → ${result ?? '取消'}');
    }
  }
}

/// [CommonCheckBox] has no `tristate`, so a null `value` trips the Checkbox assertion.
class _DemoCheckBoxRow extends StatelessWidget {
  const _DemoCheckBoxRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, value) in const <(String, bool)>[
          ('true', true),
          ('false', false),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              CommonCheckBox(value: value, onChanged: null),
              Text(
                label,
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: appMonospaceFontFamily,
                    ),
              ),
            ],
          ),
        Text(
          '（onChanged: null 即禁用）',
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Two interactive checkboxes, square and round; the round one means single choice in a list row.
class _DemoCheckBoxes extends StatelessWidget {
  const _DemoCheckBoxes({
    required this.checked,
    required this.circleChecked,
    required this.onChecked,
    required this.onCircleChecked,
  });

  final bool? checked;
  final bool circleChecked;
  final ValueChanged<bool?> onChecked;
  final ValueChanged<bool?> onCircleChecked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            CommonCheckBox(value: checked, onChanged: onChecked),
            Text('方形 $checked', style: AppTextStyle.footnote.of(context)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            CommonCheckBox(
              value: circleChecked,
              onChanged: onCircleChecked,
              isCircle: true,
            ),
            Text('圆形 $circleChecked', style: AppTextStyle.footnote.of(context)),
          ],
        ),
      ],
    );
  }
}