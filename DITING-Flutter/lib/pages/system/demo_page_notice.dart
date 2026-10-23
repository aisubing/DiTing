library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class DemoPageNotice extends StatelessWidget {
  const DemoPageNotice({super.key, this.dark = false});

  /// The scanner page is always dark, so the text color is explicit.
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