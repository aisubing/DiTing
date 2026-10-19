/// 代理域页面共用的小件：延迟文字、分组图标、空状态。
///
/// 节点卡片同时出现在 tab 形式与 list 形式里，两边对「延迟怎么显示」的要求
/// 完全一致（未测速灰、超时红、正常按阈值走 success/warning），所以抽到这里，
/// 避免两处各写一份阈值——阈值一改就只剩一处生效是这类代码最常见的事故。
library;

import 'package:diting/data/mock_proxies.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:material_ui/material_ui.dart';

/// 延迟文字。
///
/// 四档语义（与 `colorScheme.delayColor` 对齐）：
/// - `null`：未测速 → 显示「—」且用次要色，**不是** 0ms；
/// - `< 0`：超时 → 显示「超时」；
/// - `>= 0`：正常 → 显示毫秒数。
///
/// 刻意不用转圈动画代替「未测速」：`CommonCircleLoading` 是 `repeat()` 动画，
/// 一个列表里挂几十个会让 `pumpAndSettle` 永远等不到静止（见 AGENT_MISTAKES）。
class ProxyDelayText extends StatelessWidget {
  const ProxyDelayText({super.key, required this.delayMs, this.testing = false});

  final int? delayMs;

  /// 测速中：显示转圈占位，但仍不是无限动画（见下）。
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (testing) {
      return Text(
        '测速中',
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: colorScheme.onSurfaceVariant),
      );
    }
    final text = delayMs == null
        ? '—'
        : delayMs! < 0
        ? '超时'
        : '$delayMs';
    return Text(
      text,
      style: AppTextStyle.caption1.of(context, emphasized: true).copyWith(
        color: colorScheme.delayColor(delayMs) ?? colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 分组图标：按 `glyphName` 取字形，取不到时退回 `proxies`。
///
/// `glyphByName` 对未知名字返回 `AppGlyphs.proxies`（见 `lib/widgets/glyph_lookup.dart`），
/// 所以这里不需要再判空。
class ProxyGroupIcon extends StatelessWidget {
  const ProxyGroupIcon({
    super.key,
    required this.glyphName,
    this.size = 16,
    this.color,
  });

  final String glyphName;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GlyphIcon(
      glyphByName(glyphName),
      size: size,
      color: color ?? context.colorScheme.primary,
    );
  }
}

/// 协议徽标文字。`MockProxy.protocol` 是枚举，必须走 `.label`——
/// 直接插值会渲染成 `ProxyProtocol.ss`（AGENT_MISTAKES 已有同源条目）。
class ProxyProtocolBadge extends StatelessWidget {
  const ProxyProtocolBadge({super.key, required this.protocol});

  final ProxyProtocol protocol;

  @override
  Widget build(BuildContext context) {
    return Text(
      protocol.label,
      style: AppTextStyle.caption2
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}
