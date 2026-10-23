/// Nested form sheet (upstream `features/form/nested_form_sheet.dart`).
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// [isDirty] must be a pure query and is called on every back gesture.
class NestedFormSheet extends StatefulWidget {
  const NestedFormSheet({
    super.key,
    required this.title,
    required this.child,
    required this.isDirty,
    this.onSave,
    this.saveLabel = '保存',
    this.discardLabel = '放弃',
    this.confirmMessage = '有未保存的修改，确定要离开吗？',
    this.iconActions = const [],
    this.confirmationAction,
    this.primaryAction,
  });

  final String title;
  final Widget child;
  final bool Function() isDirty;

  /// Save action; it should close the sheet and return the result.
  final VoidCallback? onSave;

  final String saveLabel;
  final String discardLabel;
  final String confirmMessage;

  /// Forwarded to the inner `CommonScaffold` app bar. Full-screen editors keep their own
  /// toolbar, so these pass through instead of faking a second app bar.
  final List<IconButtonData> iconActions;
  final IconButtonData? confirmationAction;
  final IconButtonData? primaryAction;

  @override
  State<NestedFormSheet> createState() => _NestedFormSheetState();
}

class _NestedFormSheetState extends State<NestedFormSheet> {
  /// `true` allows the pop, `false` blocks it. `CommonPopScope` lets a `true` handler
  /// through, so the value is not inverted.
  Future<bool> _handleExit(BuildContext context) async {
    if (!widget.isDirty()) {
      return true;
    }
    final choice = await showFloatingDialog<_ExitChoice>(
      context: context,
      child: CommonDialog(
        title: '还没保存',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.stay),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.discard),
            child: Text(widget.discardLabel),
          ),
          if (widget.onSave != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitChoice.save),
              child: Text(widget.saveLabel),
            ),
        ],
        child: Text(widget.confirmMessage),
      ),
    );
    switch (choice) {
      case null:
      case _ExitChoice.stay:
        return false;
      case _ExitChoice.discard:
        return true;
      case _ExitChoice.save:
        widget.onSave?.call();
        // The save action closes the sheet itself; letting this pop through would
        // also pop the page below.
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonPopScope(
      onPop: _handleExit,
      child: CommonScaffold(
        title: widget.title,
        iconActions: widget.iconActions,
        confirmationAction: widget.confirmationAction,
        primaryAction: widget.primaryAction,
        // The app bar floats above the body (`extendBodyBehindAppBar`) and this body
        // is a non-scrolling Column, so the inset must be added explicitly.
        body: AppBarClearance(child: widget.child),
      ),
    );
  }
}

enum _ExitChoice { stay, discard, save }