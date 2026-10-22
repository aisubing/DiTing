import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 状态卡（FlClash `widgets/current_outbound.dart` 的形态）。
///
/// 上游那张卡的主体是「出口 IP 大字 + 国家徽标 + 质量胶囊 + 运行时长 / IP 归属
/// 两格」。DITING 没有出口节点这个概念——它是个 DNS 服务，`状态`要回答的是
/// 「内核在不在跑、跑了多久、走哪个服务商、今天解析了多少」。
///
/// 因此大字号位置放**运行时长**，下面两格是**当前服务商**与**今日查询**：
/// 结构（大字 + 两格）与上游一致，每个数字仍然来自真实状态机与引擎计数器。
/// 未运行时时长显示 `—` 而不是 `0秒`：没跑过就没有时长，这不是「刚启动」。
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, this.onDetail});

  /// 右上角「详情」的落点。
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(workModeProvider);
    final stats = ref.watch(serviceStatsProvider);
    final primary = ref.watch(primaryProviderProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final (tone, label) = switch (core) {
      CoreState.running => (DashboardChipTone.ok, core.label),
      CoreState.starting => (DashboardChipTone.idle, core.label),
      CoreState.failed => (DashboardChipTone.warn, core.label),
      CoreState.stopped => (DashboardChipTone.idle, core.label),
    };
    return DashboardCard(
      semanticLabel: '状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.status,
            title: '状态',
            leading: [DashboardChip(label: label, tone: tone, dot: true)],
            trailing: [
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text('运行时长', style: DashboardText.label(context)),
          SizedBox(height: 2 * scale),
          Text(
            core.isRunning ? stats.uptimeLabel : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.figure(
              context,
              AppTextStyle.title1,
              color: core.isRunning ? colorScheme.onSurface : null,
            ),
          ),
          SizedBox(height: 14 * scale),
          Row(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _StatusCell(
                  label: '当前服务商',
                  value: primary?.name ?? '未选择',
                  hint: primary?.address,
                ),
              ),
              Expanded(
                flex: 2,
                child: _StatusCell(
                  label: '今日查询',
                  value: dashboardCount(stats.queries),
                  hint: mode.title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「标签 / 主值 / 副值」一格。
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, required this.value, this.hint});

  final String label;
  final String value;

  /// 主值下面的小字；没有就整行不出现，不留空。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(context, AppTextStyle.subheadline),
        ),
        if (hint != null && hint.isNotEmpty)
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
      ],
    );
  }
}
