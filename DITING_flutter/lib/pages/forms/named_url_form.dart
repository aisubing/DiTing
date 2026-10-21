/// 命名 URL 表单（上游 `features/form/named_url_form.dart`，324 行）。
///
/// 上游的 `NamedUrl = ({String label, String url, String ageSecretKey})`：一条
/// 「名字 + 地址 + 密钥」。表单支持单条编辑与批量粘贴两种模式，批量模式下
/// 逐行校验并在底部汇总。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/batch_section.dart';
import 'package:diting/pages/forms/custom_issue.dart';
import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一条命名 URL。
typedef NamedUrl = ({String label, String url, String ageSecretKey});

/// 校验一条记录，返回问题列表（空表示通过）。
///
/// 抽成顶层函数而不是方法：批量模式下要对几十条各校验一次，纯函数更容易在
/// 演示页里被单独调用与测试。
List<String> validateNamedUrl(NamedUrl value) {
  final issues = <String>[];
  if (value.label.trim().isEmpty) {
    issues.add('名称不能为空');
  }
  final url = value.url.trim();
  if (url.isEmpty) {
    issues.add('地址不能为空');
  } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
    issues.add('地址必须以 http:// 或 https:// 开头');
  }
  return issues;
}

/// 命名 URL 表单。
class NamedUrlForm extends StatefulWidget {
  const NamedUrlForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.title = '命名地址',
    this.submitting = false,
    this.error,
  });

  final NamedUrl initial;
  final ValueChanged<NamedUrl> onSave;
  final String title;
  final bool submitting;
  final String? error;

  @override
  State<NamedUrlForm> createState() => _NamedUrlFormState();
}

class _NamedUrlFormState extends State<NamedUrlForm> {
  late final _label = TextEditingController(text: widget.initial.label);
  late final _url = TextEditingController(text: widget.initial.url);
  late final _secret = TextEditingController(text: widget.initial.ageSecretKey);
  late final _batch = TextEditingController();

  var _batchMode = false;
  var _issues = <String>[];

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _secret.dispose();
    _batch.dispose();
    super.dispose();
  }

  NamedUrl get _value =>
      (label: _label.text, url: _url.text, ageSecretKey: _secret.text);

  void _submit() {
    final value = _value;
    final issues = validateNamedUrl(value);
    setState(() => _issues = issues);
    if (issues.isEmpty) {
      widget.onSave(value);
    }
  }

  /// 批量解析结果：每行 `名称,地址`，可选第三段密钥。
  List<({String raw, NamedUrl? value, List<String> issues})> get _parsed => [
    for (final line in _batch.text.split('\n'))
      if (line.trim().isNotEmpty)
        () {
          final parts = line.split(',');
          final value = (
            label: parts.isNotEmpty ? parts[0].trim() : '',
            url: parts.length > 1 ? parts[1].trim() : '',
            ageSecretKey: parts.length > 2 ? parts[2].trim() : '',
          );
          return (
            raw: line.trim(),
            value: value,
            issues: validateNamedUrl(value),
          );
        }(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (widget.error case final error?) ErrorBanner(message: error),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedControl<bool>(
            segments: const [(false, '单条编辑'), (true, '批量粘贴')],
            value: _batchMode,
            onChanged: (value) => setState(() => _batchMode = value),
          ),
        ),
        if (_batchMode) ..._buildBatch(context) else ..._buildSingle(context),
        if (_issues.isNotEmpty) CustomIssuesBanner(issues: _issues),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: TonalButton(
            label: _batchMode ? '解析并全部添加' : (widget.submitting ? '提交中…' : '保存'),
            glyph: _batchMode ? AppGlyphs.importFile : AppGlyphs.check,
            size: TonalButtonSize.section,
            onPressed: widget.submitting
                ? null
                : _batchMode
                ? () {
                    final parsed = _parsed;
                    final bad = [for (final entry in parsed) ...entry.issues];
                    setState(() => _issues = bad);
                    if (bad.isEmpty && parsed.isNotEmpty) {
                      for (final entry in parsed) {
                        final value = entry.value;
                        if (value != null) {
                          widget.onSave(value);
                        }
                      }
                    }
                  }
                : _submit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            _batchMode
                ? '每行一条，格式为「名称,地址」或「名称,地址,密钥」。'
                      '当前输入 ${_parsed.length} 行，其中 '
                      '${_parsed.where((e) => e.issues.isNotEmpty).length} 行有问题。'
                : '密钥用于 age 加密，留空表示不加密。演示层不发起真实请求，'
                      '保存只会写进内存状态。',
            style: context.listCaptionStyle.copyWith(
              color: _batchMode && _parsed.any((e) => e.issues.isNotEmpty)
                  ? colorScheme.error
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSingle(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CommonCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: FormPage(
            title: '',
            padding: EdgeInsets.zero,
            onSave: null,
            children: [
              FormRowTextField(
                title: widget.title,
                controller: _label,
                hintText: '如「主订阅」',
                invalid: _issues.any((issue) => issue.contains('名称')),
                onChanged: (_) => setState(() {}),
              ),
              FormRowTextField(
                title: '地址',
                controller: _url,
                hintText: 'https://example.com/sub',
                keyboardType: TextInputType.url,
                monospace: true,
                invalid: _issues.any((issue) => issue.contains('地址')),
                onChanged: (_) => setState(() {}),
              ),
              FormRowSecretTextField(
                title: '密钥',
                controller: _secret,
                hintText: '可留空',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      if (_parsed.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '预置样例：${mockNamedUrls.first.label}',
            style: context.listCaptionStyle,
          ),
        ),
    ];
  }

  List<Widget> _buildBatch(BuildContext context) {
    return [
      BatchSection(
        controller: _batch,
        title: '批量粘贴',
        hintText:
            '主订阅,https://sub.example.com/diting/main\n'
            '备用,https://backup.example.com/diting/backup,age1...',
        footer: '逗号分隔。密钥可省略。逐行校验，全部通过才会一次写入。',
        minLines: 5,
        onChanged: (_) => setState(() => _issues = const []),
      ),
      for (final entry in _parsed)
        if (entry.issues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              spacing: 6,
              children: [
                GlyphIcon(
                  AppGlyphs.error,
                  size: 14,
                  color: context.colorScheme.error,
                ),
                Expanded(
                  child: Text(
                    '${entry.raw}：${entry.issues.first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.listCaptionStyle.copyWith(
                      color: context.colorScheme.error,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
              ],
            ),
          ),
    ];
  }
}
