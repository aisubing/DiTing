/// 嵌套表单浮层（上游 `features/form/nested_form_sheet.dart`，113 行）。
///
/// 上游要解决的核心问题是「浮层里还有浮层，返回时要不要保存」：`CommonPopScope`
/// 拦下返回手势，如果表单是 dirty 的就弹「保存 / 放弃 / 继续编辑」。本文件把
/// 这段逻辑封装成 `NestedFormSheet`，让调用方只管给表单内容。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 有未保存改动时拦下返回的浮层。
///
/// [isDirty] 必须是纯查询（不能有副作用）；每次返回手势都会调它一次。
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

  /// 点「保存」时的动作；它应当关闭浮层并返回结果。
  final VoidCallback? onSave;

  final String saveLabel;
  final String discardLabel;
  final String confirmMessage;

  /// 透传给内部 `CommonScaffold` 的顶栏动作。
  ///
  /// 编辑器这类「全屏但有工具栏」的页面要保留自己的工具栏（格式化 / 还原 /
  /// 保存），所以这几个参数原样转下去，而不是让调用方在 `child` 里伪造一条
  /// 顶栏——那样会与真实的 `CommonScaffold` 顶栏重叠。
  final List<IconButtonData> iconActions;
  final IconButtonData? confirmationAction;
  final IconButtonData? primaryAction;

  @override
  State<NestedFormSheet> createState() => _NestedFormSheetState();
}

class _NestedFormSheetState extends State<NestedFormSheet> {
  /// 返回 `true` 表示允许这次 pop；`false` 表示拦下。
  ///
  /// `CommonPopScope` 的语义是「handler 返回真则放行」，所以这里返回的布尔值
  /// 与「是否继续退出」同向，不需要再反转。
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
        // 保存动作自己负责关闭浮层，这里不再放行，否则会连浮层下面的页面
        // 一起弹掉。
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
        body: widget.child,
      ),
    );
  }
}

enum _ExitChoice { stay, discard, save }
