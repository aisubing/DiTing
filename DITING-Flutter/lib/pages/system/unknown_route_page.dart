/// Fallback page for unmatched routes.
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.location});

  /// The address the user actually opened, shown so both users and developers can
  /// report or locate it.
  final String location;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '页面不存在',
      // The body starts at y=0 under the floating app bar, so a centered column would
      // slide under it on narrow screens or large text; `AppBarClearance` reserves room.
      body: AppBarClearance(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                GlyphIcon(
                  AppGlyphs.search,
                  size: 40,
                  color: colorScheme.onSurfaceVariant,
                ),
                Text(
                  '找不到这个页面',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.title3.of(context, emphasized: true),
                ),
                SelectableText(
                  location,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}