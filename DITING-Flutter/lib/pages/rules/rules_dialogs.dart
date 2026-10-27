part of 'rules_page.dart';

/// Input dialog for a rewrite rule: domain plus target value. InputDialog takes one field,
/// and two chained dialogs would leave the user unsure where they were after cancelling.
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

  /// Existing patterns, used to report duplicates in place instead of after closing.
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

/// Shared confirmation dialog. Only true runs a destructive action. Clear, delete and the
/// whitelist relax all use it because there is no undo.
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
          onPressed: () => popFloatingDialog(context, false),
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () => popFloatingDialog(context, true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
  return result ?? false;
}
