import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/memory_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Memory detail: the card can only show PSS and a three-part bar, so this page adds the device
/// view (how much of the phone is in use), the heap split as numbers instead of widths, and a
/// short PSS history to show whether memory is climbing while the tunnel runs.
class MemoryDetailPage extends ConsumerStatefulWidget {
  const MemoryDetailPage({super.key});

  @override
  ConsumerState<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends ConsumerState<MemoryDetailPage> {
  /// PSS history collected while the page is open; the provider only keeps the latest sample.
  static const _capacity = speedSampleCapacity;
  final List<double> _pss = [];

  ProcessMemoryNotifier? _memory;
  var _revision = 0;

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
    ref.listen(processMemoryProvider, (previous, next) {
      if (!next.available) return;
      setState(() {
        _pss.add(next.totalPss.toDouble());
        if (_pss.length > _capacity) _pss.removeAt(0);
        _revision++;
      });
    });
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final available = memory.available;
    final other = (memory.totalPss - memory.javaHeap - memory.nativeHeap).clamp(
      0,
      memory.totalPss,
    );
    final deviceUsed = (memory.systemTotal - memory.systemAvail).clamp(
      0,
      memory.systemTotal,
    );
    return DashboardDetailScaffold(
      title: '内存详情',
      actions: [
        IconButton(
          tooltip: '重新采样',
          onPressed: _memory == null ? null : () => _memory!.tick(),
          icon: const GlyphIcon(AppGlyphs.refresh),
        ),
      ],
      children: [
        DashboardDetailFigure(
          label: '本进程 PSS',
          value: available ? dashboardBinaryBytes(memory.totalPss) : '—',
          hint: available
              ? '占整机内存 ${dashboardPercent(memory.systemShare)}'
              : '当前环境读不到内存数据',
        ),
        DashboardDetailStats(
          stats: [
            StatItem(
              label: 'Java 堆',
              value: available ? dashboardBinaryBytes(memory.javaHeap) : '—',
              color: colorScheme.primary,
            ),
            StatItem(
              label: '原生堆',
              value: available ? dashboardBinaryBytes(memory.nativeHeap) : '—',
              color: colors.series2,
            ),
            StatItem(
              label: '其它',
              value: available ? dashboardBinaryBytes(other) : '—',
            ),
            StatItem(
              label: '整机可用',
              value: available ? dashboardBinaryBytes(memory.systemAvail) : '—',
            ),
          ],
        ),
        generateSection(
          title: '进程构成',
          footer: available
              ? 'PSS 按共享页的比例计入本进程，因此 Java 堆与原生堆之和小于 PSS，'
                    '差额是代码、图形缓冲与共享库。'
              : null,
          items: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  DashboardShareBar(
                    segments: [
                      (value: memory.javaHeap.toDouble(), color: colorScheme.primary),
                      (value: memory.nativeHeap.toDouble(), color: colors.series2),
                      (value: other.toDouble(), color: colors.track),
                    ],
                  ),
                  DashboardShareLegend(
                    label: 'Java 堆',
                    value: available ? dashboardBinaryBytes(memory.javaHeap) : '—',
                    color: colorScheme.primary,
                    share: _share(memory.javaHeap, memory.totalPss),
                  ),
                  DashboardShareLegend(
                    label: '原生堆',
                    value: available
                        ? dashboardBinaryBytes(memory.nativeHeap)
                        : '—',
                    color: colors.series2,
                    share: _share(memory.nativeHeap, memory.totalPss),
                  ),
                  DashboardShareLegend(
                    label: '其它（代码 / 共享库 / 图形）',
                    value: available ? dashboardBinaryBytes(other) : '—',
                    color: colors.track,
                    share: _share(other, memory.totalPss),
                  ),
                ],
              ),
            ),
          ],
        ),
        generateSection(
          title: '整机内存',
          footer: available && memory.systemTotal > 0
              ? '整机占用 = 总量 - 可用量，包含系统与所有应用；本进程只是其中一份。'
              : null,
          items: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  DashboardShareBar(
                    height: 12,
                    segments: [
                      (value: deviceUsed.toDouble(), color: colorScheme.primary),
                      (
                        value: memory.systemAvail.toDouble(),
                        color: colors.track,
                      ),
                    ],
                  ),
                  DashboardShareLegend(
                    label: '整机已用',
                    value: available
                        ? dashboardBinaryBytes(deviceUsed)
                        : '—',
                    color: colorScheme.primary,
                    share: _share(deviceUsed, memory.systemTotal),
                  ),
                  DashboardShareLegend(
                    label: '整机可用',
                    value: available
                        ? dashboardBinaryBytes(memory.systemAvail)
                        : '—',
                    color: colors.track,
                    share: _share(memory.systemAvail, memory.systemTotal),
                  ),
                ],
              ),
            ),
          ],
        ),
        generateSection(
          title: '最近 PSS',
          footer: '打开本页后每 2 秒采样一次，最多保留 60 个点；'
              '曲线持续上扬说明有内存未释放。',
          items: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 120,
                child: _pss.length < 2
                    ? const Center(child: Text('正在采样…'))
                    : LineChart(
                        values: _pss,
                        revision: _revision,
                        capacity: _capacity,
                        // 16 MB floor: a flat idle line must not be blown up into noise.
                        minScale: 16 * 1024 * 1024,
                        color: colorScheme.primary,
                        baselineRatio: 1,
                      ),
              ),
            ),
          ],
        ),
        const ListFooter(
          text:
              '数据来自 ActivityManager 的 MemoryInfo；'
              '切到后台或系统回收后数值会明显下降。',
        ),
      ],
    );
  }

  static double? _share(int part, int total) =>
      total <= 0 ? null : (part / total).clamp(0.0, 1.0);
}
