/// 表单错误提示（上游 `features/form/custom_issue.dart`）。
///
/// 上游区分两种：字段级的 `CustomIssue`（挂在某一行上）与整页的
/// `CustomIssuesBanner`。本仓的 `FormRow.invalid` 已经承担了字段级提示，
/// 所以这里只保留两件东西：一条通用 banner（`ErrorBanner`）与一个
/// 「多个校验问题」的汇总列表（`CustomIssuesBanner`）。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一条提示横幅：图标 + 文本，底色是语义色的淡色。
///
/// 三种语义（错误 / 警告 / 一般）共用同一个结构，只换颜色与字形——这是上游
/// `_Banner` 的做法。分成三个类会让调用点重复三份布局代码。
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.glyph,
    this.color,
    this.foregroundColor,
    this.actions,
  });

  /// 错误态：红色。
  const InfoBanner.error({super.key, required this.message, this.actions})
    : glyph = AppGlyphs.error,
      color = null,
      foregroundColor = null;

  /// 警告态：琥珀色。
  const InfoBanner.warning({super.key, required this.message, this.actions})
    : glyph = AppGlyphs.warning,
      color = null,
      foregroundColor = null;

  final String message;
  final Glyph? glyph;

  /// `null` 表示按 `glyph` 自动推断（错误 / 警告 / 一般）。
  final Color? color;
  final Color? foregroundColor;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (resolvedColor, resolvedForeground) = switch (glyph) {
      AppGlyphs.error => (colorScheme.error, colorScheme.onError),
      AppGlyphs.warning => (
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
      ),
      _ => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
    };
    final tint = color ?? resolvedColor;
    final foreground =
        foregroundColor ??
        (color == null
            ? resolvedForeground
            : (tint.computeLuminance() > 0.55 ? Colors.black : Colors.white));
    final actions = this.actions;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: ShapeDecoration(
          shape: AppShape.xl,
          color: tint.withValues(alpha: color == null ? 1 : 0.14),
        ),
        child: Row(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphIcon(glyph ?? AppGlyphs.info, size: 20, color: foreground),
            Expanded(
              child: Text(
                message,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: foreground),
              ),
            ),
            if (actions != null)
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }
}

/// 错误条：`InfoBanner.error` 的别名，调用点更短。
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => InfoBanner.error(message: message);
}

/// 多条校验问题的汇总。
///
/// 单条的问题挂在行上（`FormRow.invalid`），但「提交时发现有 4 个字段不合规」
/// 需要一个地方一次说清，否则用户得自己一屏屏找红框。
class CustomIssuesBanner extends StatelessWidget {
  const CustomIssuesBanner({
    super.key,
    required this.issues,
    this.title = '有几点需要先修正',
  });

  final List<String> issues;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: ShapeDecoration(
          shape: AppShape.xl,
          color: colorScheme.errorContainer,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.warning,
                  size: 20,
                  color: colorScheme.onErrorContainer,
                ),
                Text(
                  title,
                  style: AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(color: colorScheme.onErrorContainer),
                ),
              ],
            ),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '· $issue',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
