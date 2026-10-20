/// 日志仪表盘：请求 / 缓存 / 竞速三视图共用一页。
///
/// 为什么不是三个页面：三者是同一个「观测」动作的不同粒度——用户先看概览，
/// 再下钻到单条请求，或换一列看缓存与竞速。上游同样是
/// `ModernLogDashboardScreen` 单屏 + 模式切换
/// （`docs/refactor/05-traffic-log-system.md` §3.3），拆页会让一次切换变成两次
/// 导航，也保不住搜索框与筛选条件。
///
/// 「请求」读原生写入的 `dns_log`，「缓存表」读旧版 `dns_cache`（Go 只在内存
/// 里维护 LRU，没有枚举接口），「竞速排行」由原生 `RaceLogWriter` 落库后在
/// Dart 侧聚合。清空只删 `dns_log`，不碰缓存与竞速历史。
library;

import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'logs_rows.dart';

/// 三个视图。标签刻意与 [LogAction] 的文案（放行 / 拦截 / 覆写 / 缓存）不重合：
/// 「缓存」既是处置类型又是视图名，同一屏里两个同名可点项会让人点错。
enum _LogsView {
  requests('请求'),
  cache('缓存表'),
  race('竞速排行');

  const _LogsView(this.label);

  final String label;
}

/// 日志页。
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _search = TextEditingController();
  var _view = _LogsView.requests;

  /// 输入即过滤：固定 40 条内存数据，过滤是纯 CPU 操作，加防抖只会让筛选显得
  /// 迟钝（规则页要防抖是因为那边每次按键都要重建几十个可编辑行）。
  var _query = '';
  LogAction? _action;

  @override
  void initState() {
    super.initState();
    // Counters live in the native engine; pull them as soon as the dashboard
    // opens instead of waiting for the next lifecycle resume.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(workModeProvider) == AppWorkMode.server) {
        ref.read(serverStatusProvider.notifier).syncStatus();
      } else {
        ref.read(powerProvider.notifier).syncStatus();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockLogEntry> _visibleLogs(List<MockLogEntry> all) => [
    for (final entry in all)
      if ((_action == null || entry.action == _action) &&
          (_query.isEmpty || entry.domain.toLowerCase().contains(_query)))
        entry,
  ];

  Future<void> _clearLogs() async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空请求日志',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
        child: const Text('将删除当前模式数据库中的全部 DNS 请求日志。'),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final db = await ref.read(activeLogDatabaseProvider.future);
    await db?.delete('dns_log');
    ref.read(dnsLogRevisionProvider.notifier).bump();
  }

  void _refreshLogs() => ref.read(dnsLogRevisionProvider.notifier).bump();

  void _openDetail(MockLogEntry entry) => showSheet<void>(
    context: context,
    builder: (_) => _LogDetailSheet(entry: entry),
  );

  /// `dns_log` 只存原始字段；处置、客户端与耗时都从结果列和 message 还原。
  static MockLogEntry _toEntry(DnsLogRecord record) {
    final message = record.message ?? '';
    final latency = int.tryParse(
          RegExp(r'elapsed=(\d+)ms').firstMatch(message)?.group(1) ?? '',
        ) ??
        0;
    final action = switch (record.result) {
      'BLOCKED' => LogAction.blocked,
      'REWRITTEN' => LogAction.rewritten,
      _ => record.cached ? LogAction.cached : LogAction.allowed,
    };
    final timestamp = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    String two(int value) => value.toString().padLeft(2, '0');
    return MockLogEntry(
      time: '${two(timestamp.hour)}:${two(timestamp.minute)}:'
          '${two(timestamp.second)}',
      domain: record.domain,
      action: action,
      latencyMs: latency,
      client: record.packageName?.isNotEmpty == true
          ? record.packageName!
          : '系统',
      rule: message.isEmpty ? null : message,
      cached: record.cached,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(serviceStatsProvider);
    final asyncLogs = ref.watch(dnsLogsProvider);
    final colorScheme = context.colorScheme;
    final all = [
      for (final record in asyncLogs.value ?? const <DnsLogRecord>[])
        _toEntry(record),
    ];
    final visible = _visibleLogs(all);
    final averageLatency = all.isEmpty
        ? stats.averageLatencyMs
        : all.map((entry) => entry.latencyMs).reduce((a, b) => a + b) ~/
              all.length;

    return CommonScaffold(
      title: '日志仪表盘',
      menuItems: [
        CommonPopupMenuItem(
          label: '刷新日志',
          glyph: AppGlyphs.reset,
          onPressed: _refreshLogs,
        ),
        CommonPopupMenuItem(
          label: '清空日志',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: all.isEmpty ? null : _clearLogs,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '今日查询',
                    value: _formatCount(stats.queries),
                  ),
                  StatItem(
                    label: '缓存命中',
                    value: '${(stats.cacheHitRate * 100).round()}',
                    unit: '%',
                    color: colorScheme.success,
                  ),
                  StatItem(
                    label: '已拦截',
                    value: _formatCount(stats.blocked),
                    color: colorScheme.error,
                  ),
                  StatItem(
                    label: '平均延迟',
                    value: '$averageLatency',
                    unit: 'ms',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<_LogsView>(
              segments: [
                for (final view in _LogsView.values) (view, view.label),
              ],
              value: _view,
              onChanged: (view) => setState(() => _view = view),
            ),
          ),
          ...switch (_view) {
            _LogsView.requests =>
              asyncLogs.isLoading && !asyncLogs.hasValue
                  ? const [_LogsLoading()]
                  : asyncLogs.hasError
                  ? const [_LogsError()]
                  : _requestChildren(visible),
            _LogsView.cache => _cacheChildren(ref.watch(dnsCacheProvider)),
            _LogsView.race => _raceChildren(
              ref.watch(resolutionModeProvider),
              ref.watch(raceRankingProvider),
            ),
          },
        ],
      ),
    );
  }

  List<Widget> _requestChildren(List<MockLogEntry> visible) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SearchField(
        controller: _search,
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: _ActionChips(
        value: _action,
        onChanged: (action) => setState(() => _action = action),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        visible.isEmpty
            ? '没有匹配的请求'
            : '共 ${visible.length} 条 · 拦截 '
                  '${visible.where((entry) => entry.action == LogAction.blocked).length}',
        style: context.listCaptionStyle,
      ),
    ),
    if (visible.isEmpty)
      SizedBox(
        height: 300,
        child: NullStatus(
          label: '暂无请求日志',
          description: '启动任一模式后，DNS 查询会出现在这里；也可以点「刷新日志」重新读取。',
          illustration: NullStatusIllustration.logs,
          action: FilledButton(
            onPressed: _refreshLogs,
            child: const Text('刷新日志'),
          ),
        ),
      )
    else
      generateSection(
        title: '最近请求',
        footer: '点按一行查看完整解析信息；数据按时间倒序，共 ${visible.length} 条。',
        items: [
          for (final entry in visible)
            _RequestRow(entry: entry, onTap: () => _openDetail(entry)),
        ],
      ),
  ];

  List<Widget> _cacheChildren(AsyncValue<List<DnsCacheRecord>> cache) => [
    if (cache.isLoading && !cache.hasValue)
      const _LogsLoading()
    else if (cache.hasError)
      const _LogsError()
    else if ((cache.value ?? const []).isEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: NullStatus(
          label: '暂无缓存条目',
          description: 'Go 引擎的缓存只在内存里，不落这张表；这里显示的是旧版 1.4.3 '
              '遗留、且尚未过期的条目。',
          illustration: NullStatusIllustration.logs,
        ),
      )
    else
      generateSection(
        title: 'DNS 缓存',
        footer: '按命中次数排序，只显示尚未过期的旧版缓存条目；'
            '当前引擎的命中率见顶部「缓存命中」。',
        items: [
          for (final entry in cache.value!) _CacheRow(entry: entry),
        ],
      ),
  ];

  List<Widget> _raceChildren(
    ResolutionMode resolution,
    AsyncValue<RaceRankingBoard> ranking,
  ) => [
    if (resolution.isSingle)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: CommonCard(
          child: ListItem(
            leading: const GlyphIcon(AppGlyphs.shuffle),
            title: const Text('当前为单服务商模式'),
            subtitle: const Text('竞速排行只在并行竞速 / 主备切换模式下产生新数据，这里是上次多路模式的记录。'),
            trailing: const GlyphIcon(AppGlyphs.info, size: 18),
          ),
        ),
      ),
    if (ranking.isLoading && !ranking.hasValue)
      const _LogsLoading()
    else if (ranking.hasError)
      const _LogsError()
    else if ((ranking.value?.entries ?? const []).isEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: NullStatus(
          label: '暂无竞速记录',
          description: '切换到并行竞速或主备切换模式后，每次多路上游解析都会记录胜出服务商。',
          illustration: NullStatusIllustration.logs,
        ),
      )
    else
      generateSection(
        title: '上游竞速排行',
        footer: '胜出次数是「最先返回」的次数；整轮失败共 '
            '${ranking.value!.summary.failures} 次，平均耗时 '
            '${ranking.value!.summary.averageLatencyMs}ms（共 '
            '${ranking.value!.summary.requests} 次多路解析）。',
        items: [
          for (final (index, entry) in ranking.value!.entries.indexed)
            _RaceRow(rank: index + 1, entry: entry),
        ],
      ),
  ];
}

/// 首次读取旧库时的占位；只在拿到第一帧数据前出现。
class _LogsLoading extends StatelessWidget {
  const _LogsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 260,
    child: Center(child: CommonCircleLoading.page()),
  );
}

/// 旧库损坏/被占用时的兜底。日志页不该因此把整屏变成错误页。
class _LogsError extends StatelessWidget {
  const _LogsError();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: NullStatus(
      label: '无法读取日志库',
      description: '数据库可能被占用或已损坏；重启应用后再试。',
      illustration: NullStatusIllustration.logs,
    ),
  );
}

/// 处置筛选 chip 行：全部 / 放行 / 拦截 / 覆写 / 缓存。
class _ActionChips extends StatelessWidget {  const _ActionChips({required this.value, required this.onChanged});

  final LogAction? value;
  final ValueChanged<LogAction?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final options = <(LogAction?, String)>[
      (null, '全部'),
      for (final action in LogAction.values) (action, action.label),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (action, label) = options[index];
          final selected = action == value;
          return TonalChip(
            label: label,
            color: selected
                ? colorScheme.primary
                : context.raisedSurfaceLevel.colorOf(colorScheme),
            foregroundColor: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            onPressed: () => onChanged(action),
          );
        },
      ),
    );
  }
}

/// 千分位整数。查询数是五位数，不加分隔符时「28471」和「28741」很难一眼比出来。
String _formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
