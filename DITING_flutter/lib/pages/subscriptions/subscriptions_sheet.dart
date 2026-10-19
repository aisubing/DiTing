part of 'subscriptions_page.dart';

/// 添加订阅面板。
///
/// 用 `showSheet` + `CommonScaffold` 而不是对话框：表单有三个字段，对话框在
/// 键盘弹起后会被压到只剩一行，而 sheet 自带滚动与「取消 / 保存」工具栏。
class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  var _group = mockSubscriptionGroups.first;
  var _importType = SubscriptionImportType.remote;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final added = ref
        .read(subscriptionsProvider.notifier)
        .add(
          name: _name.text,
          url: _url.text,
          group: _group,
          importType: _importType,
        );
    if (!added) {
      // 地址重复不关面板：用户刚粘的地址要留在框里改，关掉等于让他重粘一遍。
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('该订阅地址已存在'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(subscriptionGroupsProvider);
    return CommonScaffold(
      title: '添加订阅',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存订阅',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: const EdgeInsets.only(top: 8),
          children: [
            generateSection(
              title: '订阅信息',
              items: [
                _FieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '如：AdGuard 基础'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '名称不能为空' : null,
                  ),
                ),
                _FieldRow(
                  label: _importType == SubscriptionImportType.remote
                      ? '订阅地址'
                      : '文件路径',
                  child: TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: _importType == SubscriptionImportType.remote
                          ? 'https://example.com/rules.txt'
                          : '/storage/rules.txt',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '地址不能为空';
                      }
                      if (_importType == SubscriptionImportType.remote &&
                          !text.startsWith('http')) {
                        return '订阅地址需以 http 开头';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            generateSection(
              title: '导入方式',
              items: [
                ListItem<SubscriptionImportType>.options(
                  title: const Text('来源类型'),
                  options: SubscriptionImportType.values,
                  value: _importType,
                  textBuilder: (type) => type.label,
                  onChanged: (type) => setState(() => _importType = type),
                ),
                ListItem<String>.options(
                  title: const Text('所属分组'),
                  options: groups,
                  value: groups.contains(_group) ? _group : groups.first,
                  textBuilder: (group) => group,
                  onChanged: (group) => setState(() => _group = group),
                ),
              ],
            ),
            const ListFooter(text: '远程订阅会按更新周期自动拉取，本地文件只在导入时读取一次。'),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

/// 表单行：左标签 + 右输入框。
///
/// 不复用 `ListItem.input` 是因为那个自带一个点击弹出的对话框，而这里是面板内
/// 联编辑，行为完全不同。
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: context.listTitleStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
