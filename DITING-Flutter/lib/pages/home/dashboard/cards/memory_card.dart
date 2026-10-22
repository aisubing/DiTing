import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/memory_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 内存信息卡（FlClash `widgets/memory_info.dart` 的摘要部分）。
///
/// 上游摘要是一行总占用 + 一条进度条 + 两三个图例（应用 / 内核）。本仓分成两个
/// 量，因为它们回答不同问题：
/// - 大字是**整进程 PSS**（含映射页与共享库），配一条「占整机内存」的进度条；
/// - 图例是**堆分配**（Java 堆 / 原生堆），说明内存放在哪。
///
/// 两者不能相加：PSS 里还有 `.so` / `.dex` 映射与共享页，堆分配只算分配器给出的
/// 字节。把堆分配硬拼成 PSS 的分段会得到一条永远填不满的条，看起来像少算了一半。
///
/// 内核不单独列：Go 引擎是 in-process 的 AAR，它的分配已经在原生堆里。上游能拆
/// 「应用 / 内核」是因为它的 core 是独立进程。
///
/// 采样由 [processMemoryProvider] 每 2 秒推进，卡片只负责在挂载期持有它。
class MemoryCard extends ConsumerStatefulWidget {
  const MemoryCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  ConsumerState<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends ConsumerState<MemoryCard> {
  ProcessMemoryNotifier? _memory;

  @override
  void initState() {
    super.initState();
    _memory = ref.read(processMemoryProvider.notifier);
    _memory!.attachPolling();
  }

  @override
  void dispose() {
    _memory?.detachPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(processMemoryProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final available = memory.available;
    return DashboardCard(
      semanticLabel: '内存信息',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.memory,
            title: '内存信息',
            trailing: [
              if (widget.onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: widget.onDetail,
                ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: available ? dashboardBinaryBytes(memory.totalPss) : '—',
                  style: DashboardText.figure(
                    context,
                    AppTextStyle.title2,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (available)
                  TextSpan(
                    text: '  PSS',
                    style: DashboardText.unit(context, AppTextStyle.caption1),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10 * scale),
          _CompositionBar(
            segments: [
              (bytes: memory.javaHeap, color: colorScheme.primary),
              (bytes: memory.nativeHeap, color: colors.series2),
              (
                bytes: (memory.totalPss - memory.javaHeap - memory.nativeHeap)
                    .clamp(0, memory.totalPss),
                color: colors.track,
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Legend(
                label: 'Java 堆',
                value: memory.javaHeap,
                color: colorScheme.primary,
                available: available,
              ),
              _Legend(
                label: '原生堆',
                value: memory.nativeHeap,
                color: colors.series2,
                available: available,
              ),
              if (available && memory.systemTotal > 0)
                _Legend(
                  label: '整机可用',
                  value: memory.systemAvail,
                  color: colors.track,
                  available: available,
                  percentOf: memory.systemTotal,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一段图例：彩点 + 标签 + 字节数。
class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.value,
    required this.color,
    required this.available,
    this.percentOf,
  });

  final String label;
  final int value;
  final Color color;
  final bool available;

  /// 给了就把字节数换算成占比一起显示（整机可用内存按总量算才有意义）。
  final int? percentOf;

  @override
  Widget build(BuildContext context) {
    final percentOf = this.percentOf;
    final text = !available
        ? '—'
        : percentOf == null || percentOf <= 0
        ? dashboardBinaryBytes(value)
        : '${dashboardBinaryBytes(value)}'
              '（${(value * 100 / percentOf).toStringAsFixed(0)}%）';
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: ShapeDecoration(color: color, shape: AppShape.circle),
        ),
        Text(label, style: DashboardText.label(context)),
        Text(
          text,
          maxLines: 1,
          style: DashboardText.figure(context, AppTextStyle.caption1),
        ),
      ],
    );
  }
}

/// 一条按比例分段填充的条，用来显示「PSS 里堆占了多少」。
///
/// 段是 `Java 堆 / 原生堆 / 其余（映射与共享页）`：三者相加正好是 PSS，条因此
/// 总是填满。只画堆、让剩下半截空着会被读成「还有一半没统计到」。
///
/// 用 `ClipRSuperellipse` 而不是 `ClipRRect`：本仓圆角一律走超椭圆，`ClipRRect`
/// 在 `material_ui` 的 `RoundedSuperellipseBorder` 主题下会显出肉眼可见的差异。
class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.segments});

  final List<({int bytes, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.bytes);
    final height = 9.0 * scale;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(color: DashboardColors.of(context).track)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final segment in segments)
                    if (segment.bytes > 0)
                      Expanded(
                        // 千分比做 flex：一个 0.3% 的段若按 1 算会被放大成肉眼
                        // 可见的一条，凑成 1000 才能保住真实比例。
                        flex: (segment.bytes * 1000 ~/ total).clamp(1, 1000),
                        child: ColoredBox(color: segment.color),
                      ),
                ],
              ),
      ),
    );
  }
}
