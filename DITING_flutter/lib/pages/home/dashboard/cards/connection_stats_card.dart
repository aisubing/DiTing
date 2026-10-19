import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 连接统计卡（上游 `widgets/connection_stats.dart`，131 行）。
///
/// 三格并排：活动连接 / 已关闭 / 累计流量。每格都能点进对应列表——上游也是
/// 这样，点击即跳转。
class ConnectionStatsCard extends ConsumerWidget {
  const ConnectionStatsCard({super.key, this.onOpenConnections});

  final VoidCallback? onOpenConnections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(connectionStatsProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    return DashboardCard(
      semanticLabel: '连接统计',
      padding: const EdgeInsets.all(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCell(
                glyph: AppGlyphs.connections,
                label: '活动连接',
                value: dashboardCount(stats.active),
                onTap: onOpenConnections,
              ),
            ),
            _Divider(height: 40 * scale),
            Expanded(
              child: _StatCell(
                glyph: AppGlyphs.checkCircle,
                label: '已关闭',
                value: dashboardCount(stats.closed),
              ),
            ),
            _Divider(height: 40 * scale),
            Expanded(
              child: _StatCell(
                glyph: AppGlyphs.dataUsage,
                label: '累计流量',
                value: dashboardTraffic(stats.upload + stats.download),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: height,
        color: context.colorScheme.outlineVariant,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.glyph,
    required this.label,
    required this.value,
    this.onTap,
  });

  final Glyph glyph;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = AppShape.all(AppCorner.md);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          GlyphIcon(
            glyph,
            size: 16,
            color: context.colorScheme.onSurfaceVariant,
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.figure(context, AppTextStyle.title3),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
