/// 未知路由兜底页。
///
/// `GoRouter` 默认把未匹配的路径渲染成空白：真机上是一片没有导航栏的白屏，
/// 用户只能杀进程；更糟的是**在测试里它不抛异常**，所以「每条路由都能构建」
/// 这类用例会对漏注册的路由静默放行。
///
/// 这个页面把两种情况都修掉：
/// - 用户看到明确的「页面不存在」+ 回首页按钮；
/// - `route_catalog_test.dart` 用 `find.byType(UnknownRoutePage)` 断言它不存在，
///   漏注册立刻变成硬失败。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 未匹配路由的兜底页。
class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.location});

  /// 用户实际访问的地址；显示出来便于用户报告、也便于开发者定位。
  final String location;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '页面不存在',
      // 正文从 y=0 起排（顶栏浮在上方），居中件在窄屏或大字号下会把内容
      // 顶进顶栏底部，所以统一用 `AppBarClearance` 让开浮位。
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
