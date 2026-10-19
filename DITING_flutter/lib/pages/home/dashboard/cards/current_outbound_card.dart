import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 当前状态卡（上游 `widgets/current_outbound.dart`，945 行）。
///
/// 上游这张卡最复杂：内核状态按钮 + 当前出站链 + 速率环形图 + 快捷动作。
/// 这里保留同样的信息层级，省略桌面才有的多列排布。
class CurrentOutboundCard extends ConsumerWidget {
  const CurrentOutboundCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(outboundModeProvider);
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final tone = switch (core) {
      CoreState.running => DashboardChipTone.ok,
      CoreState.starting => DashboardChipTone.idle,
      CoreState.stopped => DashboardChipTone.idle,
      CoreState.failed => DashboardChipTone.warn,
    };
    return DashboardCard(
      semanticLabel: '当前状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.status,
            title: '当前状态',
            trailing: [
              DashboardChip(label: core.label, tone: tone, dot: true),
            ],
          ),
          // 出站链：规则 → 代理组 → 节点，上游用三段可点的横条表示，
          // 每段之间画箭头。这里保留箭头与可点性。
          //
          // 三段是「标签 + 值」两行文字，横向空间很紧：320 宽时每段只分到约
          // 70dp，长值（`GEOSITE,cn`）必须自己省略，不能靠外层 `Expanded` 兜底
          // ——`Text` 默认 `softWrap` 在窄宽下会撑高而不是缩短。
          DashboardBlock(
            child: Row(
              spacing: 6,
              children: [
                Expanded(
                  child: _ChainNode(
                    label: '匹配规则',
                    value: 'GEOSITE,cn',
                    glyph: AppGlyphs.rules,
                  ),
                ),
                GlyphIcon(
                  AppGlyphs.chevronForward,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: _ChainNode(
                    label: '出站',
                    value: mode == OutboundMode.direct ? 'DIRECT' : '自动选择',
                    glyph: AppGlyphs.proxies,
                  ),
                ),
                GlyphIcon(
                  AppGlyphs.chevronForward,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: _ChainNode(
                    label: '节点',
                    value: '香港 01',
                    glyph: AppGlyphs.target,
                  ),
                ),
              ],
            ),
          ),
          // 三个指标横向等分；数值用 `Expanded` 让它们各自省略，而不是整行
          // 溢出——320 宽下「活动连接 128」加两个流量值本来就放不下。
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: DashboardMetric(
                  label: '活动连接',
                  value: dashboardCount(
                    ref.watch(connectionStatsProvider).active,
                  ),
                ),
              ),
              Expanded(
                child: DashboardMetric(
                  label: '上行',
                  value: dashboardTraffic(
                    ref.watch(trafficTotalsProvider).up,
                  ),
                ),
              ),
              Expanded(
                child: DashboardMetric(
                  label: '下行',
                  value: dashboardTraffic(
                    ref.watch(trafficTotalsProvider).down,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 40 * scale,
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: core == CoreState.starting
                        ? null
                        : () => ref
                              .read(coreStateProvider.notifier)
                              .restart(),
                    child: Text(
                      core == CoreState.starting ? '重启中…' : '重启内核',
                    ),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showSheet<void>(
                      context: context,
                      builder: (_) => const _CoreDetailSheet(),
                    ),
                    child: const Text('查看详情'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainNode extends StatelessWidget {
  const _ChainNode({
    required this.label,
    required this.value,
    required this.glyph,
  });

  final String label;
  final String value;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Row(
          spacing: 4,
          children: [
            GlyphIcon(
              glyph,
              size: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.label(context),
              ),
            ),
          ],
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .toTabular,
        ),
      ],
    );
  }
}

/// 内核详情浮层：把「当前状态」卡的摘要展开成完整信息。
class _CoreDetailSheet extends ConsumerWidget {
  const _CoreDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(outboundModeProvider);
    return CommonScaffold(
      title: '内核详情',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(title: '运行信息'),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.status),
            title: const Text('内核状态'),
            trailing: DashboardChip(label: core.label),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.split),
            title: const Text('出站模式'),
            trailing: Text(mode.label),
          ),
          const ListItem(
            leading: GlyphIcon(AppGlyphs.code),
            title: Text('内核版本'),
            trailing: Text('mihomo 1.19.2'),
          ),
          const ListItem(
            leading: GlyphIcon(AppGlyphs.clock),
            title: Text('已运行'),
            trailing: Text('3 小时 42 分'),
          ),
          ListFooter(text: '演示数据：状态由本地面板驱动，不来自真实内核。'),
        ],
      ),
    );
  }
}
