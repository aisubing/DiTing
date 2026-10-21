/// 表单族演示入口（上游没有这一页，是 DITING_flutter 自己的组件展厅）。
///
/// 表单族组件（`FormPage` / `FormRow` / `BatchSection` / `SelectionSheet` /
/// `NamedUrlForm` / `NestedFormSheet` / `CustomIssuesBanner`）平时分散在规则、
/// 订阅、WebDAV 等页面里，没有一个地方能看到全部形态。这一页把它们排在一屏，
/// 既方便对照「同一种行在不同类型下的样子」，也让并行开发期能独立验收。
library;

import 'dart:async';

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/batch_section.dart';
import 'package:diting/pages/forms/custom_issue.dart';
import 'package:diting/pages/forms/filter.dart';
import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/pages/forms/rule_preset_sheet.dart';
import 'package:diting/pages/forms/selection_sheet.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 表单族演示页。
class FormsDemoPage extends StatefulWidget {
  const FormsDemoPage({super.key});

  @override
  State<FormsDemoPage> createState() => _FormsDemoPageState();
}

class _FormsDemoPageState extends State<FormsDemoPage> {
  // —— 表单字段示例的本地状态 ——
  final _label = TextEditingController(text: '北京时间');
  final _server = TextEditingController(text: 'ntp.aliyun.com');
  final _port = TextEditingController(text: '123');
  final _password = TextEditingController();
  final _filter = TextEditingController(text: 'example`ads');

  final _batch = TextEditingController();
  var _enabled = true;
  var _protocol = 'UDP';

  /// 校验问题：空表示通过。提交时才算，不边打边标红。
  var _issues = <String>[];
  var _saving = false;

  /// 单次提交是否成功（用于演示错误条）。
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _label,
      _server,
      _port,
      _password,
      _filter,
      _batch,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _validate() {
    final issues = <String>[];
    if (_label.text.trim().isEmpty) {
      issues.add('名称不能为空');
    }
    if (_server.text.trim().isEmpty) {
      issues.add('服务器地址不能为空');
    }
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      issues.add('端口必须是 1–65535 之间的整数');
    }
    if (_password.text.isNotEmpty && _password.text.length < 6) {
      issues.add('密码至少 6 位');
    }
    return issues;
  }

  Future<void> _submit() async {
    final issues = _validate();
    setState(() {
      _issues = issues;
      _error = null;
    });
    if (issues.isNotEmpty) {
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = '演示层不会真的保存：这次提交只走了一遍校验与 loading 状态。';
    });
  }

  Future<void> _pickProtocol() async {
    final result = await showSelectionSheet<String>(
      context: context,
      title: '协议',
      items: const ['UDP', 'TCP', 'DoT', 'DoH'],
      labelBuilder: (item) => item,
      selected: _protocol,
    );
    if (result != null && mounted) {
      setState(() => _protocol = result);
    }
  }

  Future<void> _openRulePreset() async {
    final result = await showFormSheet<Set<String>>(
      context: context,
      props: const SheetProps(detents: [0.85]),
      builder: (_) => const RulePresetSheet(),
    );
    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('已选中 ${result.length} 个预设：${result.join('、')}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '表单组件',
      menuItems: [
        CommonPopupMenuItem(
          label: '查看命名 URL 表单',
          glyph: AppGlyphs.link,
          onPressed: () => context.push(SystemPaths.formNamedUrl),
        ),
        CommonPopupMenuItem(
          label: '查看列表编辑器',
          glyph: AppGlyphs.appsList,
          onPressed: () => context.push(SystemPaths.formListEditor),
        ),
        CommonPopupMenuItem(
          label: '查看键值编辑器',
          glyph: AppGlyphs.key,
          onPressed: () => context.push(SystemPaths.formMapEdit),
        ),
        CommonPopupMenuItem(
          label: '查看选择浮层',
          glyph: AppGlyphs.picker,
          onPressed: () => context.push(SystemPaths.formSelection),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.sliders,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      Text(
                        '表单族构件',
                        style: AppTextStyle.title3.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '下面这一屏用了 FormPage、FormRow 的四种派生、SegmentedControl、'
                    '批量输入、过滤器与校验汇总。点右上角菜单可以跳到其余四个表单页面。',
                    style: context.listSubtitleStyle.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          if (_issues.isNotEmpty) CustomIssuesBanner(issues: _issues),
          if (_error case final error?) ErrorBanner(message: error),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: FormPage(
                title: '',
                padding: EdgeInsets.zero,
                onSave: null,
                children: [
                  FormRowTextField(
                    title: '名称',
                    controller: _label,
                    hintText: '如「北京时间」',
                    invalid: _issues.any((issue) => issue.contains('名称')),
                    onChanged: (_) => setState(() {}),
                  ),
                  FormRowTextField(
                    title: '服务器',
                    controller: _server,
                    hintText: 'ntp.example.com',
                    monospace: true,
                    invalid: _issues.any((issue) => issue.contains('服务器')),
                    onChanged: (_) => setState(() {}),
                  ),
                  FormRowTextField(
                    title: '端口',
                    controller: _port,
                    keyboardType: TextInputType.number,
                    monospace: true,
                    invalid: _issues.any((issue) => issue.contains('端口')),
                    onChanged: (_) => setState(() {}),
                  ),
                  FormRowSecretTextField(
                    title: '密码',
                    controller: _password,
                    hintText: '可留空',
                    invalid: _issues.any((issue) => issue.contains('密码')),
                    onChanged: (_) => setState(() {}),
                  ),
                  FormRowSwitch(
                    title: '启用',
                    value: _enabled,
                    description: '关闭后不再使用这条记录',
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  FormRow(
                    title: '协议',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(_protocol),
                        const GlyphIcon(AppGlyphs.picker, size: 16),
                      ],
                    ),
                    onPressed: _pickProtocol,
                  ),
                  FormRowValue(
                    title: '版本',
                    value: '1.0.0',
                    monospace: true,
                    description: '只读值，不可编辑',
                  ),
                  FormRow(
                    title: '规则预设',
                    description: '从七个常用预设里多选插入',
                    trailing: const GlyphIcon(AppGlyphs.rulePresets, size: 18),
                    onPressed: _openRulePreset,
                  ),
                  FormRow(
                    title: '危险操作',
                    trailing: Text(
                      '清空',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    onPressed: () => setState(() {
                      _label.clear();
                      _server.clear();
                      _port.clear();
                      _password.clear();
                    }),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TonalButton(
              label: _saving ? '提交中…' : '提交表单',
              glyph: _saving ? null : AppGlyphs.check,
              size: TonalButtonSize.section,
              onPressed: _saving ? null : _submit,
            ),
          ),
          const SizedBox(height: 12),
          SectionBlock(
            title: '过滤器',
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            footer: '反引号分隔多个条件；下面的标签可以单独点掉。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                FilterField(
                  value: _filter.text,
                  onChanged: (value) => setState(() => _filter.text = value),
                ),
                FilterRegexText(
                  raw: _filter.text,
                  onRemove: (next) => setState(() => _filter.text = next),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          BatchSection(
            controller: _batch,
            title: '批量输入',
            hintText: 'DOMAIN-SUFFIX,example.com\nDOMAIN-KEYWORD,ads',
            footer: '批量输入与过滤器不同：它按行解析，每行一条完整内容。',
            onChanged: (_) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in mockRulePresets.take(3))
                  TonalChip(
                    label: preset.title,
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    foregroundColor: colorScheme.onSurface,
                    onPressed: () =>
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(
                              '插入「${preset.title}」的 ${preset.rules.length} 条规则',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 1400),
                          ),
                        ),
                  ),
              ],
            ),
          ),
          ListFooter(
            text:
                '表单族的完整页面：命名 URL、列表编辑器、键值编辑器、选择浮层、'
                '规则预设，都可以从右上角菜单进入。',
          ),
        ],
      ),
    );
  }
}
