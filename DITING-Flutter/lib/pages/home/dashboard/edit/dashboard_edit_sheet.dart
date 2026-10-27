import 'package:diting/data/dashboard_models.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Tapping appends the card at the end and closes, so no disabled state is needed.
class DashboardEditSheet extends ConsumerWidget {
  const DashboardEditSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardWidgetsProvider);
    final notifier = ref.read(dashboardWidgetsProvider.notifier);
    final available = [
      for (final widget in DashboardWidget.values)
        if (!widgets.contains(widget)) widget,
    ];
    return CommonScaffold(
      title: '添加卡片',
      actions: [
        TextButton(
          onPressed: () => notifier.reset(),
          child: const Text('恢复默认'),
        ),
      ],
      body: available.isEmpty
          ? const AppBarClearance(
              child: Center(
                child: NullStatus(
                  illustration: NullStatusIllustration.data,
                  label: '卡片都放上来了',
                  description: '想减少卡片，请回到编辑模式点卡片右上角的移除。',
                ),
              ),
            )
          : ListView(
              // The sheet title floats over the body, so this top padding is required.
              padding: EdgeInsets.only(
                top: context.contentTopPadding,
                bottom: 24,
              ),
              children: [
                const ListHeader(title: '可添加的卡片'),
                for (final widget in available)
                  ListItem(
                    leading: GlyphIcon(_glyphOf(widget)),
                    title: Text(widget.label),
                    subtitle: Text(_descriptionOf(widget)),
                    trailing: const GlyphIcon(AppGlyphs.addCircle, size: 20),
                    onTap: () {
                      notifier.add(widget);
                      Navigator.of(context).maybePop();
                    },
                  ),
                const ListFooter(text: '卡片顺序可在编辑模式下拖拽调整。'),
              ],
            ),
    );
  }

  static Glyph _glyphOf(DashboardWidget widget) => switch (widget) {
    DashboardWidget.status => AppGlyphs.status,
    DashboardWidget.networkSpeed => AppGlyphs.speed,
    DashboardWidget.siteLatency => AppGlyphs.speed,
    DashboardWidget.memoryInfo => AppGlyphs.memory,
    DashboardWidget.intranetIp => AppGlyphs.devices,
  };

  static String _descriptionOf(DashboardWidget widget) => switch (widget) {
    DashboardWidget.status => '内核状态、运行时长、当前服务商与今日查询',
    DashboardWidget.networkSpeed => '上下行实时速率曲线与今日累计流量',
    DashboardWidget.siteLatency => '自定义 4 个站点的实测延迟，详情页可按分类测速',
    DashboardWidget.memoryInfo => '本进程 PSS 与 Java / 原生堆构成',
    DashboardWidget.intranetIp => '当前局域网地址、监听状态与复制入口',
  };
}
