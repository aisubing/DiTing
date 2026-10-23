part of 'demo_page.dart';

/// Lists: all seven [ListItem] constructors plus [ListHeader], [ListFooter],
/// [generateSection] and [DecorationListItem]. They share one group because the rounded
/// first and last row only shows in a run of rows.
class _DemoListSection extends StatefulWidget {
  const _DemoListSection();

  @override
  State<_DemoListSection> createState() => _DemoListSectionState();
}

class _DemoListSectionState extends State<_DemoListSection> {
  bool _checked = true;
  bool _toggled = false;
  int _option = 1;

  static const _options = ['DIRECT', 'REJECT', 'PROXY'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: 'ListItem · 七种构造器',
          actions: [
            IconButtonData(
              glyph: AppGlyphs.add,
              tooltip: '新增',
              onPressed: () => _demoToast(context, 'ListHeader 动作 · 新增'),
            ),
            IconButtonData(
              glyph: AppGlyphs.sort,
              tooltip: '排序',
              onPressed: () => _demoToast(context, 'ListHeader 动作 · 排序'),
            ),
          ],
          footer: '首行只圆上边、末行只圆下边，中间行是直角——这是分组列表的核心。',
          items: [
            ListItem(
              title: const Text('默认 · 行尾箭头'),
              subtitle: const Text('ListItem() 的 onTap 走页面跳转'),
              leading: const GlyphIcon(AppGlyphs.dashboard),
              onTap: () => _demoToast(context, '默认行被点按'),
            ),
            ListItem.open(
              title: const Text('open · 内嵌展开'),
              subtitle: const Text('桌面端弹 Extend，移动端 OpenContainer'),
              leading: const GlyphIcon(AppGlyphs.layers),
              widget: const _DemoOpenDetail(),
              onChanged: (_) => _demoToast(context, 'open 行返回'),
            ),
            ListItem.next(
              title: const Text('next · 下一级页面'),
              subtitle: const Text('推入一个独立页面'),
              leading: const GlyphIcon(AppGlyphs.settings),
              widget: const _DemoOpenDetail(),
            ),
            ListItem<int>.options(
              title: const Text('options · 选项菜单'),
              subtitle: Text('当前：${_options[_option]}'),
              leading: const GlyphIcon(AppGlyphs.rules),
              options: List.generate(_options.length, (index) => index),
              value: _option,
              textBuilder: (value) => _options[value],
              onChanged: (value) => setState(() => _option = value),
            ),
            ListItem.input(
              title: const Text('input · 输入对话框'),
              subtitle: const Text('点按弹出 InputDialog'),
              leading: const GlyphIcon(AppGlyphs.edit),
              dialogTitle: '修改备注',
              value: '默认策略',
              suffixText: '',
              resetValue: '默认策略',
              maxLength: 24,
              onChanged: (value) =>
                  _demoToast(context, 'input → ${value ?? ''}'),
            ),
            ListItem.checkbox(
              title: const Text('checkbox · 复选框'),
              subtitle: const Text('勾选状态由外部持有'),
              leading: const GlyphIcon(AppGlyphs.checkCircle),
              value: _checked,
              onChanged: (value) => setState(() => _checked = value ?? false),
            ),
            ListItem.toggle(
              title: const Text('toggle · 开关'),
              subtitle: const Text('开关只上报值，不改自身状态'),
              leading: const GlyphIcon(AppGlyphs.toggle),
              value: _toggled,
              onChanged: (value) => setState(() => _toggled = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _DemoLabel('ListHeader', trailing: 'title / actions / trailing'),
        ListHeader(
          title: '带单个动作的表头',
          actions: [
            IconButtonData(
              glyph: AppGlyphs.sync,
              tooltip: '同步',
              onPressed: () => _demoToast(context, 'ListHeader · 同步'),
            ),
          ],
        ),
        ListHeader(
          title: '带 trailing 的表头',
          trailing: MetaChip(label: '${_options.length} 项'),
        ),
        const _DemoLabel('DecorationListItem', trailing: '选中 / 普通 / 非法'),
        const _DemoDecorationItems(),
        const _DemoLabel('MoreActionButton 与 ListFooter', trailing: '收尾件'),
        MoreActionButton(
          label: '查看全部列表组件',
          onPressed: () => _demoToast(context, 'MoreActionButton'),
        ),
        const ListFooter(
          text:
              'ListFooter 的左右缩进跟着 1.mAp(context) 缩放，'
              '所以平板上它不会和行内容错位。',
        ),
      ],
    );
  }
}

/// Three [DecorationListItem] states: plain, selected and invalid.
class _DemoDecorationItems extends StatelessWidget {
  const _DemoDecorationItems();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        DecorationListItem(
          title: const Text('普通行'),
          subtitle: const Text('DecorationListItem 自带行内边距'),
          leading: const GlyphIcon(AppGlyphs.proxies),
          onPressed: () => _demoToast(context, 'DecorationListItem'),
        ),
        DecorationListItem(
          title: const Text('选中行'),
          subtitle: const Text('isSelected: true 时底色换到主色系'),
          leading: const GlyphIcon(AppGlyphs.proxies),
          isSelected: true,
          trailing: const SelectionCheck(),
          onPressed: () {},
        ),
        DecorationListItem(
          title: const Text('非法行'),
          subtitle: const Text('invalid: true 时描边转 error'),
          leading: const GlyphIcon(AppGlyphs.warning),
          invalid: true,
          trailing: GlyphIcon(AppGlyphs.error, color: colorScheme.error),
          onPressed: () {},
        ),
      ],
    );
  }
}

/// The page opened by `ListItem.open`; it must support `safeNestedPop`.
class _DemoOpenDetail extends StatelessWidget {
  const _DemoOpenDetail();

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '详情页',
      // A `Column` body would sit under the floating top bar; only scrolling bodies
      // like `PageBody` use padding.
      body: AppBarClearance(
        child: _DemoSectionBody(
          children: [
            Text(
              '这一页由 ListItem.open / .next 推入，用来验证内嵌展开与整页跳转'
              '两条路径都能正常返回。',
              style: AppTextStyle.footnote.of(context),
            ),
            TonalButton(
              size: TonalButtonSize.section,
              glyph: AppGlyphs.arrowBack,
              label: '返回',
              onPressed: () => context.safeNestedPop(),
            ),
          ],
        ),
      ),
    );
  }
}