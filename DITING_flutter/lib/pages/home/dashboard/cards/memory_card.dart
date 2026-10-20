import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 内存占用卡（上游 `widgets/memory_info.dart`，654 行）。
///
/// 卡片只显示占用条 + 百分比；点开 `MemoryDetailSheet` 才看得到堆/常驻/协程
/// 等细项。上游把「细项」做成浮层，是为了让卡片在移动端保持一行高度。
class MemoryCard extends ConsumerWidget {
  const MemoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    // 超过 80% 换成警示色：上游同样在 80% 处变红，是内核 OOM 的前兆。
    final barColor = memory.ratio > 0.8
        ? colorScheme.error
        : memory.ratio > 0.6
        ? colorScheme.warning
        : colorScheme.primary;
    return DashboardCard(
      semanticLabel: '内存占用',
      onTap: () => showSheet<void>(
        context: context,
        builder: (_) => const MemoryDetailSheet(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.memory,
            title: '内存占用',
            chevron: true,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 6,
            children: [
              Text(
                memory.percent.toStringAsFixed(0),
                style: DashboardText.figure(
                  context,
                  AppTextStyle.title1,
                  color: barColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('%', style: DashboardText.unit(context)),
              ),
              const Spacer(),
              Text(
                '${dashboardTraffic(memory.used)} / ${dashboardTraffic(memory.total)}',
                style: DashboardText.label(context),
              ),
            ],
          ),
          SizedBox(
            height: 8 * scale,
            child: ClipRRect(
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    flex: (memory.ratio * 1000).round(),
                    child: ColoredBox(color: barColor),
                  ),
                  Expanded(
                    flex: ((1 - memory.ratio) * 1000).round(),
                    child: ColoredBox(color: DashboardColors.of(context).track),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 内存详情浮层（上游 `MemoryDetailSheet`）。
class MemoryDetailSheet extends ConsumerWidget {
  const MemoryDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider);
    final history = buildMockMemoryHistory();
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '内存详情',
      body: ListView(
        // 浮层标题浮在正文之上，不预留这段留白首行就被标题压住。
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text(
                    '总览',
                    style: AppTextStyle.headline.of(context, emphasized: true),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 6,
                    children: [
                      Text(
                        memory.percent.toStringAsFixed(1),
                        style: DashboardText.figure(
                          context,
                          AppTextStyle.title1,
                          color: colorScheme.primary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('%', style: DashboardText.unit(context)),
                      ),
                      const Spacer(),
                      Text(
                        '共 ${dashboardTraffic(memory.total)}',
                        style: DashboardText.label(context),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 80 * scale,
                    child: LineChart(
                      values: history,
                      revision: history.length,
                      capacity: history.length,
                      minScale: memory.total * 0.5,
                      baselineRatio: 1,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ListHeader(title: '明细'),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.memory),
            title: const Text('已用'),
            trailing: Text(dashboardTraffic(memory.used)),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.dataUsage),
            title: const Text('空闲'),
            trailing: Text(dashboardTraffic(memory.free)),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.layers),
            title: const Text('堆内存'),
            subtitle: Text(
              '${dashboardTraffic(memory.heapUsed)} / ${dashboardTraffic(memory.heapTotal)}',
            ),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.cpu),
            title: const Text('常驻内存 (RSS)'),
            trailing: Text(dashboardTraffic(memory.rss)),
          ),
          const ListItem(
            leading: GlyphIcon(AppGlyphs.code),
            title: Text('协程数'),
            trailing: Text('86'),
          ),
          const ListFooter(text: '演示数据：数值固定，不来自真实内核。'),
        ],
      ),
    );
  }
}
