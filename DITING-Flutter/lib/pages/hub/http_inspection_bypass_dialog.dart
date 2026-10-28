/// Bypass domain dialog for HTTPS inspection. The controller is owned by the dialog: disposing it
/// right after `await` fires on `pop` mid animation and trips `'_dependents.isEmpty': is not true`.
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class HttpInspectionBypassDialog extends StatefulWidget {
  const HttpInspectionBypassDialog({super.key});

  @override
  State<HttpInspectionBypassDialog> createState() =>
      _HttpInspectionBypassDialogState();
}

class _HttpInspectionBypassDialogState extends State<HttpInspectionBypassDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加绕过域名',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('添加')),
      ],
      child: TextField(
        controller: _controller,
        autocorrect: false,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '域名后缀',
          hintText: 'example.com',
          helperText: '匹配该后缀及其子域名；不参与 HTTPS 解密',
        ),
      ),
    );
  }
}
