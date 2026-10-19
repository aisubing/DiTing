part of 'demo_page.dart';

/// 浮层分区：验证 [showFloatingDialog] / [showSheet] / [showFormSheet] /
/// [showExtend] / [showSnapSheet] 五种打开方式，以及 [CommonPopupBox] 的
/// 锚点弹出菜单。
///
/// 浮层最容易出的回归是「层级」而不是「样式」：对话框必须压在 Dock 之上、
/// 侧边抽屉必须能盖住整个页面、弹窗必须贴着按钮而不越出屏幕。这些只有真的
/// 点开才能验证，所以每个按钮都接真实的宿主。
class _DemoOverlaySection extends StatelessWidget {
  const _DemoOverlaySection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('对话框', trailing: 'showFloatingDialog'),
        const _DemoDialogButtons(),
        const _DemoLabel('抽屉', trailing: 'showSheet / showFormSheet'),
        const _DemoSheetButtons(),
        const _DemoLabel('页面式浮层', trailing: 'showExtend / showSnapSheet'),
        const _DemoExtendButtons(),
        const _DemoLabel('锚点菜单', trailing: 'CommonPopupBox'),
        const _DemoPopupButtons(),
        const _DemoLabel('AlertActions', trailing: '对话框按钮的排版器'),
        const _DemoAlertActions(),
        const ListFooter(
          text: '对话框的遮罩用 alertScrim（比 modalScrim 更暗），'
              '抽屉用 modalScrim——两者深浅不同是刻意的。',
        ),
      ],
    );
  }
}

/// [AlertActions] 的两种排布：普通（末项是默认动作，填主色）与破坏性
/// （末项是危险动作，填 error 色）。两者都按「取消在左、确认在右」排列。
class _DemoAlertActions extends StatelessWidget {
  const _DemoAlertActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        AlertActions(
          actions: [
            TextButton(
              onPressed: () => _demoToast(context, 'AlertActions · 取消'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => _demoToast(context, 'AlertActions · 确定'),
              child: const Text('确定'),
            ),
          ],
        ),
        AlertActions(
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => _demoToast(context, 'AlertActions · 取消'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => _demoToast(context, 'AlertActions · 删除'),
              child: const Text('删除'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 三个对话框入口：普通双按钮、带输入框、破坏性操作。
class _DemoDialogButtons extends StatelessWidget {
  const _DemoDialogButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.info,
          label: '双按钮对话框',
          onPressed: () => _showPlainDialog(context),
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.edit,
          label: '带输入框',
          onPressed: () => _showFieldsDialog(context),
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.delete,
          label: '破坏性',
          onPressed: () => _showDestructiveDialog(context),
        ),
      ],
    );
  }

  Future<void> _showPlainDialog(BuildContext context) async {
    final result = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '切换配置？',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('切换'),
          ),
        ],
        child: const Text('切换后当前连接会全部重建，正在下载的任务将中断。'),
      ),
    );
    if (context.mounted) {
      _demoToast(context, '对话框 → ${result ?? '关闭'}');
    }
  }

  Future<void> _showFieldsDialog(BuildContext context) async {
    final result = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '输入名称',
        value: '我的配置',
        labelText: '名称',
        maxLength: 32,
      ),
    );
    if (context.mounted) {
      _demoToast(context, '字段对话框 → ${result ?? '取消'}');
    }
  }

  Future<void> _showDestructiveDialog(BuildContext context) async {
    final result = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除配置',
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
        child: const Text('该操作不可撤销，配置文件与订阅记录都会被移除。'),
      ),
    );
    if (context.mounted) {
      _demoToast(context, '破坏性对话框 → ${result ?? '关闭'}');
    }
  }
}

/// 抽屉入口：普通抽屉、表单抽屉（带键盘避让）、侧边抽屉。
class _DemoSheetButtons extends StatelessWidget {
  const _DemoSheetButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.layers,
          label: 'showSheet',
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => const _DemoSheetContent(title: 'showSheet'),
          ),
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.keyboard,
          label: 'showFormSheet',
          onPressed: () => showFormSheet<void>(
            context: context,
            builder: (_) => const _DemoSheetContent(
              title: 'showFormSheet',
              hasField: true,
            ),
          ),
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.layers,
          label: 'SheetProps(detents)',
          onPressed: () => showSheet<void>(
            context: context,
            props: const SheetProps(detents: [0.4, 0.9]),
            builder: (_) => const _DemoSheetContent(title: '自定义 detents'),
          ),
        ),
      ],
    );
  }
}

/// 页面式浮层：showExtend 与 showSnapSheet。
class _DemoExtendButtons extends StatelessWidget {
  const _DemoExtendButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.openExternal,
          label: 'showExtend',
          onPressed: () => showExtend<void>(
            context,
            builder: (_) => const _DemoSheetContent(
              title: 'showExtend',
              tall: true,
            ),
          ),
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.openExternal,
          label: 'showSnapSheet',
          onPressed: () => showSnapSheet<void>(
            context,
            builder: (_, controller) => _DemoSheetContent(
              title: 'showSnapSheet',
              scrollController: controller,
            ),
          ),
        ),
      ],
    );
  }
}

/// 锚点菜单：一个放在按钮上的 [CommonPopupBox]，菜单里带图标、勾选、子菜单
/// 与危险项。
class _DemoPopupButtons extends StatelessWidget {
  const _DemoPopupButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        CommonPopupBox(
          targetBuilder: (open) => TonalButton(
            size: TonalButtonSize.section,
            glyph: AppGlyphs.more,
            label: '打开菜单',
            onPressed: open,
          ),
          popupBuilder: (context) => CommonPopupMenu(
            items: [
              CommonPopupMenuItem(
                label: '编辑',
                glyph: AppGlyphs.edit,
                onPressed: () => _demoToast(context, '菜单 · 编辑'),
              ),
              CommonPopupMenuItem(
                label: '复制',
                glyph: AppGlyphs.copy,
                checked: true,
                onPressed: () => _demoToast(context, '菜单 · 复制'),
              ),
              CommonPopupMenuItem(
                label: '更多',
                glyph: AppGlyphs.moreCircle,
                subItems: [
                  CommonPopupMenuItem(
                    label: '导出',
                    glyph: AppGlyphs.export,
                    onPressed: () => _demoToast(context, '子菜单 · 导出'),
                  ),
                  CommonPopupMenuItem(
                    label: '导入',
                    glyph: AppGlyphs.importFile,
                    onPressed: () => _demoToast(context, '子菜单 · 导入'),
                  ),
                ],
              ),
              CommonPopupMenuItem(
                label: '删除',
                glyph: AppGlyphs.delete,
                danger: true,
                onPressed: () => _demoToast(context, '菜单 · 删除'),
              ),
            ],
          ),
        ),
        CommonPopupBox(
          placement: PopupPlacement.overAnchorStart,
          targetBuilder: (open) => TonalButton(
            size: TonalButtonSize.section,
            glyph: AppGlyphs.filter,
            label: '限制高度',
            onPressed: open,
          ),
          popupBuilder: (context) => CommonPopupMenu(
            maxVisibleItems: 3,
            items: [
              for (final label in const ['规则', '代理', '直连', '日志', '设置'])
                CommonPopupMenuItem(
                  label: label,
                  onPressed: () => _demoToast(context, '菜单 · $label'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 浮层里放的内容：一个能自己关掉的最小页面，验证宿主给的退出路径。
///
/// 是 StatefulWidget 只为了持有表单字段的 controller：浮层关闭时它必须跟着
/// dispose，否则每开一次表单抽屉就漏一个 controller。
class _DemoSheetContent extends StatefulWidget {
  const _DemoSheetContent({
    required this.title,
    this.hasField = false,
    this.tall = false,
    this.scrollController,
  });

  final String title;
  final bool hasField;
  final bool tall;
  final ScrollController? scrollController;

  @override
  State<_DemoSheetContent> createState() => _DemoSheetContentState();
}

class _DemoSheetContentState extends State<_DemoSheetContent> {
  final _fieldController = TextEditingController();

  @override
  void dispose() {
    _fieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.scrollController;
    final body = _DemoSectionBody(
      children: [
        Text(
          '${widget.title} 的内容区。这一块用来确认浮层宿主把 SafeArea、'
          '底部内边距和键盘避让都传下来了。',
          style: AppTextStyle.footnote.of(context),
        ),
        if (widget.hasField)
          SecretTextFormField(
            controller: _fieldController,
            decoration: const InputDecoration(labelText: '表单字段'),
          ),
        if (widget.tall)
          for (var index = 0; index < 12; index++)
            CommonCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('第 ${index + 1} 行'),
              ),
            ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.close,
          label: '关闭',
          onPressed: () => context.safeNestedPop(),
        ),
      ],
    );
    if (controller == null) {
      return SingleChildScrollView(child: body);
    }
    return SingleChildScrollView(controller: controller, child: body);
  }
}
