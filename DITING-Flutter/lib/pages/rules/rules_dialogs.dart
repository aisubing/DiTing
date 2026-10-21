part of 'rules_page.dart';

/// 覆写规则的输入框：域名 + 目标值两个字段。
///
/// 覆写规则比另两种多一个目标值，而 [InputDialog] 只能收一个字段；用一个
/// 双字段对话框而不是「先填域名、再填目标」两次弹框，是因为中途取消第一次
/// 之后用户不知道自己填到哪一步了。
class _RuleDialog extends StatefulWidget {
  const _RuleDialog({
    required this.title,
    required this.initialPattern,
    this.initialTarget,
    this.existingPatterns = const {},
  });

  final String title;
  final String initialPattern;
  final String? initialTarget;

  /// 已存在的规则内容，用于就地报「已存在」，避免关框之后才发现重复。
  final Set<String> existingPatterns;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _pattern = TextEditingController(text: widget.initialPattern);
  late final _target = TextEditingController(text: widget.initialTarget ?? '');

  @override
  void dispose() {
    _pattern.dispose();
    _target.dispose();
    super.dispose();
  }

  String? _validatePattern(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '规则内容不能为空';
    }
    if (text.contains('#@#')) {
      return '该规则为放行规则，请在白名单中添加';
    }
    if (widget.existingPatterns.contains(text)) {
      return '该规则已存在';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context).pop<({String pattern, String? target})>((
      pattern: _pattern.text.trim(),
      target: _target.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = UiLocalizations.of(context);
    return CommonDialog(
      title: widget.title,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(localizations.submit)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          spacing: 12,
          children: [
            TextFormField(
              controller: _pattern,
              autofocus: true,
              maxLines: null,
              minLines: 1,
              validator: _validatePattern,
              decoration: const InputDecoration(
                hintText: '域名，如 cdn.example.com',
              ),
            ),
            TextFormField(
              controller: _target,
              maxLines: null,
              minLines: 1,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? '目标值不能为空' : null,
              decoration: const InputDecoration(hintText: '目标值，如 10.0.0.8'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一的二次确认框。返回值 `true` 才执行破坏性操作。
///
/// 清空、删除、放宽白名单保护三处都走它：上游把这类确认定为不可降级为提示条
/// 的一档，因为误触之后没有撤销入口。
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final localizations = UiLocalizations.of(context);
  final result = await showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: title,
      destructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
  return result ?? false;
}
