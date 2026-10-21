/// 保留演示页的统一标注。
///
/// 旧版 1.4.3 没有编辑器、扫码、IP 质量这三个界面。它们是本仓保留的调试与
/// 组件验收入口，用户在这里看到的一切都不是「旧版功能」。页面上必须写清楚，
/// 否则下一个人会把它当成功能缺失或功能回归（上一轮就有人把它们当成
/// 「待对齐的旧版页面」提交过需求）。
///
/// 三个页面共用同一句文案：只写一次，避免三处措辞各自漂移。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 「演示页」标注条：一行小字 + 信息图标。
class DemoPageNotice extends StatelessWidget {
  const DemoPageNotice({super.key, this.dark = false});

  /// 扫码页是固定深色主题，文字颜色要单独给。
  final bool dark;

  static const label = '演示页：不属于旧版 1.4.3 的界面';

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = dark
        ? Colors.white.withValues(alpha: 0.45)
        : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        spacing: 6,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlyphIcon(AppGlyphs.info, size: 14, color: color),
          Expanded(
            child: Text(
              label,
              style: AppTextStyle.caption2.of(context).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
