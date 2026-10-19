import 'dart:math' as math;

import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 当前配置档案卡（上游 `widgets/profiles.dart`，446 行）。
///
/// 上游除了名称/类型/更新时间，还有一条**波浪进度**：已用流量占套餐的比例，
/// 进度条头部随百分比缓慢起伏。这里用 `AnimatedContainer` + 正弦偏移复刻，
/// 而不是画 custom painter——视觉差异肉眼不可见，代码少得多。
class ProfilesCard extends StatelessWidget {
  const ProfilesCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = mockCurrentProfile;
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    return DashboardCard(
      semanticLabel: '配置档案',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.profiles,
            title: '配置档案',
            chevron: onTap != null,
            trailing: [
              DashboardChip(label: profile.type),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context, emphasized: true),
                ),
              ),
              Text(
                '更新于 ${profile.updatedAt}',
                style: DashboardText.label(context),
              ),
            ],
          ),
          if (profile.progress case final progress?) ...[
            SizedBox(
              height: 10 * scale,
              child: _WaveProgress(progress: progress, height: 10 * scale),
            ),
            Row(
              spacing: 12,
              children: [
                Text(
                  '已用 ${dashboardTraffic(profile.upload + profile.download)}',
                  style: DashboardText.label(context),
                ),
                Expanded(
                  child: Text(
                    '共 ${dashboardTraffic(profile.total)}',
                    textAlign: TextAlign.end,
                    style: DashboardText.label(context),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: DashboardText.label(
                    context,
                    color: progress > 0.9
                        ? colorScheme.error
                        : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _Figure(
                  label: '上行',
                  value: dashboardTraffic(profile.upload),
                  glyph: AppGlyphs.arrowUp,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: '下行',
                  value: dashboardTraffic(profile.download),
                  glyph: AppGlyphs.arrowDown,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: '到期',
                  value: profile.expireAt,
                  glyph: AppGlyphs.clock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.glyph,
  });

  final String label;
  final String value;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    // 320 宽下每格只有约 90dp，「上行 1.4 GB」放不下一行，因此图标 + 标签
    // 一行、数值另起一行：横向省一半，纵向多一行仍比溢出可读。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            GlyphIcon(
              glyph,
              size: 11,
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
          style: DashboardText.label(
            context,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 波浪进度条：轨道 + 按比例填充 + 头部一段起伏的曲线。
///
/// 起伏用 `AnimationController` 驱动。**测试里必须关掉**（见
/// [debugDisableDashboardLiveUpdates]）：`repeat()` 会永远排帧，
/// `pumpAndSettle` 因此等不到静止。真机上它由 `TickerMode` 在离屏时自动暂停。
class _WaveProgress extends StatefulWidget {
  const _WaveProgress({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  State<_WaveProgress> createState() => _WaveProgressState();
}

class _WaveProgressState extends State<_WaveProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (!debugDisableDashboardLiveUpdates) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final shape = AppShape.all(widget.height / 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final filled =
            (constraints.maxWidth * widget.progress).clamp(0.0, constraints.maxWidth);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.track,
                  shape: shape,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: filled,
              height: widget.height,
              decoration: ShapeDecoration(
                color: colorScheme.primary,
                shape: shape,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _WaveHeadPainter(
                    phase: _controller.value,
                    color: Color.alphaBlend(
                      colorScheme.primary.withValues(alpha: 0.55),
                      colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 进度条右端的一小段波纹高光；本体是一条正弦，振幅不超过条高的一半。
class _WaveHeadPainter extends CustomPainter {
  const _WaveHeadPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8) {
      return;
    }
    final width = size.width.clamp(0.0, 24.0);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width - width, 0);
    const steps = 12;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = size.width - width + width * t;
      final y = size.height * (0.5 + 0.5 * math.sin(2 * math.pi * (t + phase)));
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveHeadPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
