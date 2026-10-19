/// 配置域各页共用的小部件与交互惯用法。
///
/// 不放进 `lib/widgets/`：这些helper只服务 `lib/pages/config/`，别处的页面
/// 不该被迫跟着配置页的密度与文案口径走。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 配置项即时反馈。
///
/// 配置页大量操作是「改了就生效」的开关与选项，除了控件自身的状态变化没有
/// 别的痕迹；被规则拒绝（重名、端口冲突、超范围）时尤其需要一句话说明，
/// 否则用户只会看到开关弹回去。
void showConfigHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ),
  );
}

/// 删除类操作的确认框。
Future<bool> confirmConfigAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
}) async {
  final confirmed = await showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: title,
      destructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
  return confirmed ?? false;
}

/// 表单页里「左标签 + 右输入框」的一行。
///
/// 不复用 `ListItem.input`：那个自带点击弹出的对话框，而表单页是内联编辑，
/// 行为完全不同。
class ConfigFieldRow extends StatelessWidget {
  const ConfigFieldRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;

  /// 输入框下方的补充说明；比 placeholder 适合放「为什么这样填」。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
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
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 88),
              child: Text(hint, style: context.listCaptionStyle),
            ),
        ],
      ),
    );
  }
}

/// 页面顶部的说明卡。
///
/// 覆写页与资源页的规则都不直观（「这里的键会写进每一份订阅」），塞进列表
/// 首行会让那一行既能点又不可点；单独一张卡说明白更清楚。
class ConfigNoteCard extends StatelessWidget {
  const ConfigNoteCard({
    super.key,
    required this.text,
    this.glyph = AppGlyphs.info,
  });

  final String text;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: CommonCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              GlyphIcon(glyph, size: 18, color: colorScheme.onSurfaceVariant),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行尾的「删除这一项」小按钮。
///
/// 统一包一层 `CommonMinIconButtonTheme`：默认 IconButton 的命中区在列表行里
/// 会把行高撑大一截，而这里的删除按钮只是个附注动作。
class ConfigRemoveButton extends StatelessWidget {
  const ConfigRemoveButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.glyph = AppGlyphs.removeCircle,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    return CommonMinIconButtonTheme(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: GlyphIcon(
          glyph,
          size: 18,
          color: onPressed == null
              ? context.colorScheme.onSurface.withValues(alpha: 0.3)
              : context.colorScheme.error,
        ),
      ),
    );
  }
}

/// 列表型条目的副标题：报出条数，空列表时说明后果。
String configListSummary(List<String> items, {String empty = '未设置'}) =>
    items.isEmpty ? empty : '共 ${items.length} 项';

/// 一条「打开另一个页面」的入口行。
///
/// 配置域的四个覆写页与四份资源页都从别的页面进去，入口行的长相必须一致：
/// 图标 + 标题 + 一句副标题 + 箭头。
class ConfigEntryRow extends StatelessWidget {
  const ConfigEntryRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.enabled = true,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        glyph,
        size: 20,
        color: enabled ? null : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: GlyphIcon(
        AppGlyphs.chevronForward,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: enabled ? onPressed : null,
    );
  }
}
