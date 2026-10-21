part of 'subscriptions_page.dart';

/// 添加订阅面板。
///
/// 用 `showSheet` + `CommonScaffold` 而不是对话框：表单有四个字段，对话框在键盘
/// 弹起后会被压到只剩一行，而 sheet 自带滚动与「取消 / 保存」工具栏。
///
/// 保存分两步：先落库（`importState = importing`，与上游 `addSubscription` 一致），
/// 再立刻发起一次真实下载把状态推进到 `ready` / `failed`。第二步失败不回滚记录，
/// 与旧版一致——用户能看到这条订阅和它的错误原因，可以手动重试。
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
  var _kind = SubscriptionKind.domain;
  int? _groupId;
  var _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final result = await ref
        .read(subscriptionActionsProvider)
        .add(name: _name.text, url: _url.text, kind: _kind, groupId: _groupId);
    if (!mounted) {
      return;
    }
    switch (result) {
      case AddSubscriptionFailure(:final message):
        setState(() => _submitting = false);
        // 地址重复不关面板：用户刚粘的地址要留在框里改，关掉等于让他重粘一遍。
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2600),
          ),
        );
      case AddSubscriptionOk(:final id):
        // 先发起一次下载，再关面板：关掉之后订阅页已经在转圈，用户看得到反应。
        final updated = ref.read(subscriptionUpdateProvider.notifier);
        Navigator.of(context).pop();
        await updated.updateOne(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(subscriptionGroupsProvider).value ?? const [];
    final selected = groups.any((group) => group.id == _groupId)
        ? _groupId
        : null;
    return CommonScaffold(
      title: '添加订阅',
      isLoading: _submitting,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存订阅',
        onPressed: _submitting ? null : _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            generateSection(
              title: '订阅信息',
              items: [
                _FieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '留空则取链接末段'),
                  ),
                ),
                _FieldRow(
                  label: '订阅地址',
                  child: TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/rules.txt',
                    ),
                    validator: (value) => validateSubscriptionUrl(value ?? ''),
                  ),
                ),
              ],
            ),
            generateSection(
              title: '规则类型',
              items: [
                ListItem<SubscriptionKind>.options(
                  title: const Text('收录类型'),
                  options: SubscriptionKind.values,
                  value: _kind,
                  textBuilder: (kind) => kind.displayName,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                ListItem<int?>.options(
                  title: const Text('所属分组'),
                  options: [null, for (final group in groups) group.id],
                  value: selected,
                  textBuilder: (id) => id == null
                      ? SubscriptionEntry.ungroupedLabel
                      : groups
                            .firstWhere(
                              (group) => group.id == id,
                              orElse: () => groups.first,
                            )
                            .name,
                  onChanged: (id) => setState(() => _groupId = id),
                ),
              ],
            ),
            ListFooter(
              text:
                  '同一条链接可以为黑白名单和 hosts 各建一条订阅（唯一性按「链接 + 类型」判定）。'
                  '保存后会立即下载一次正文并统计行数；规则解析与入库将在后续版本接入。',
            ),
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
