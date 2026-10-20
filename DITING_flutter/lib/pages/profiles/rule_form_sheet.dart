import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 规则表单的草稿：调用方决定保存到哪个表里。
///
/// 自定义规则页与扩展页的「已追加规则」用的是同一张表单、不同的数据源，所以
/// 表单只产出草稿，保存交给 `onSave`；不传就用默认的 `customRulesProvider`。
typedef RuleDraft = ({
  CustomRuleType type,
  String content,
  String target,
  bool noResolve,
  bool src,
  bool disabled,
});

/// 新增 / 编辑规则的表单（上游 `_EditRuleView`）。
///
/// 三段：类型、内容、目标。类型决定内容输入框的提示与「no-resolve」是否可用
/// —— `GEOIP`/`IP-CIDR` 才有 `no-resolve`，域名类规则加上它没有意义。
///
/// 目标用可搜索的选项行而不是自由文本：目标是组名或内置策略，写错一个字母
/// 整条规则就失效，而内核不会因此报错（只是静默不匹配）。
class RuleFormSheet extends ConsumerStatefulWidget {
  const RuleFormSheet({super.key, this.rule, this.onSave});

  final MockCustomRule? rule;

  /// 自定义保存动作；返回 false 表示保存被拒绝（重名或完全重复）。
  final bool Function(RuleDraft draft)? onSave;

  @override
  ConsumerState<RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends ConsumerState<RuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _content = TextEditingController();
  var _type = CustomRuleType.domainSuffix;
  var _target = MockRuleTarget.direct.value;
  var _noResolve = false;
  var _src = false;
  var _disabled = false;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    if (rule == null) {
      return;
    }
    _content.text = rule.content;
    _type = rule.type;
    _target = rule.target;
    _noResolve = rule.noResolve;
    _src = rule.src;
    _disabled = rule.disabled;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  /// 可选目标：内置策略 + 所有组名。
  List<String> get _targets => [
    for (final target in MockRuleTarget.values) target.value,
    for (final group in ref.read(proxyGroupsProvider)) group.name,
  ];

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final draft = (
      type: _type,
      content: _content.text.trim(),
      target: _target,
      noResolve: _type.supportsNoResolve && _noResolve,
      src: _type.supportsSrc && _src,
      disabled: _disabled,
    );
    final onSave = widget.onSave;
    if (onSave != null) {
      if (!onSave(draft)) {
        _reject();
        return;
      }
      Navigator.of(context).pop();
      return;
    }
    final notifier = ref.read(customRulesProvider.notifier);
    final rule = MockCustomRule(
      id: widget.rule?.id ?? 'r-new',
      type: draft.type,
      content: draft.content,
      target: draft.target,
      noResolve: draft.noResolve,
      src: draft.src,
      disabled: draft.disabled,
    );
    if (!notifier.put(rule)) {
      _reject();
      return;
    }
    Navigator.of(context).pop();
  }

  void _reject() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已存在完全相同的规则'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: _isEditing ? '编辑规则' : '添加规则',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存规则',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            generateSection(
              title: '匹配',
              items: [
                ListItem<CustomRuleType>.options(
                  title: const Text('类型'),
                  subtitle: Text(_type.hint),
                  options: CustomRuleType.values,
                  value: _type,
                  textBuilder: (type) => type.label,
                  onChanged: (type) => setState(() {
                    _type = type;
                    if (!type.supportsNoResolve) {
                      _noResolve = false;
                    }
                    if (!type.supportsSrc) {
                      _src = false;
                    }
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text('内容', style: context.listTitleStyle),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _content,
                          autofocus: !_isEditing,
                          style: const TextStyle(fontFamily: 'JetBrainsMono'),
                          decoration: InputDecoration(hintText: _type.hint),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return '内容不能为空';
                            }
                            if (text.contains(' ')) {
                              return '内容里不能有空格';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              footer: '内容按类型解释：${_type.value},${_type.hint}',
            ),
            generateSection(
              title: '动作',
              items: [
                ListItem<String>.options(
                  title: const Text('目标'),
                  subtitle: const Text('命中后交给这个组或内置策略处理'),
                  options: _targets,
                  value: _target,
                  textBuilder: (target) => target,
                  onChanged: (target) => setState(() => _target = target),
                ),
                if (_type.supportsNoResolve)
                  ListItem.toggle(
                    title: const Text('no-resolve'),
                    subtitle: const Text('只匹配 IP 字面量，不做 DNS 解析'),
                    value: _noResolve,
                    onChanged: (value) => setState(() => _noResolve = value),
                  ),
                if (_type.supportsSrc)
                  ListItem.toggle(
                    title: const Text('src'),
                    subtitle: const Text('匹配来源地址而不是目标地址'),
                    value: _src,
                    onChanged: (value) => setState(() => _src = value),
                  ),
                ListItem.toggle(
                  title: const Text('启用这条规则'),
                  subtitle: const Text('关掉后保留在列表里但不参与匹配'),
                  value: !_disabled,
                  onChanged: (value) => setState(() => _disabled = !value),
                ),
              ],
            ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '规则位置决定匹配顺序：越靠前越先命中。要改顺序请回列表用排序模式拖动。',
                  style: context.listCaptionStyle.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}
