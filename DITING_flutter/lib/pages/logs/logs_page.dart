/// 日志仪表盘：请求 / 缓存 / 竞速三视图共用一页。
///
/// 为什么不是三个页面：三者是同一个「观测」动作的不同粒度——用户先看概览，
/// 再下钻到单条请求，或换一列看缓存与竞速。上游同样是
/// `ModernLogDashboardScreen` 单屏 + 模式切换
/// （`docs/refactor/05-traffic-log-system.md` §3.3），拆页会让一次切换变成两次
/// 导航，也保不住搜索框与筛选条件。
///
/// 数据全部来自 `mockLogs` / `mockDnsCache` / `mockRaceRanking`；清空只改页面
/// 本地状态，不碰任何 provider——演示页不该把自己的临时操作写进全局状态。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
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
  var _cleared = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockLogEntry> get _visibleLogs {
    if (_cleared) {
      return const [];
    }
    return [
      for (final entry in mockLogs)
        if ((_action == null || entry.action == _action) &&
            (_query.isEmpty || entry.domain.toLowerCase().contains(_query)))
          entry,
    ];
  }

  List<MockDnsCacheEntry> get _sortedCache =>
      [...mockDnsCache]..sort((a, b) => b.hits.compareTo(a.hits));

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
        child: const Text('将清空本页的请求日志演示数据。清空后可用「恢复示例日志」还原。'),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _cleared = true);
  }

  void _restoreLogs() => setState(() => _cleared = false);

  void _openDetail(MockLogEntry entry) => showSheet<void>(
    context: context,
    builder: (_) => _LogDetailSheet(entry: entry),
  );

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(serviceStatsProvider);
    final resolution = ref.watch(resolutionModeProvider);
    final colorScheme = context.colorScheme;
    final visible = _visibleLogs;

    return CommonScaffold(
      title: '日志仪表盘',
      menuItems: [
        CommonPopupMenuItem(
          label: '清空日志',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: _cleared ? null : _clearLogs,
        ),
        CommonPopupMenuItem(
          label: '恢复示例日志',
          glyph: AppGlyphs.reset,
          onPressed: _cleared ? _restoreLogs : null,
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
                    value: '${stats.averageLatencyMs}',
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
            _LogsView.requests => _requestChildren(visible),
            _LogsView.cache => _cacheChildren(),
            _LogsView.race => _raceChildren(resolution),
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
          label: _cleared ? '日志已清空' : '没有匹配的请求',
          description: _cleared
              ? '清空只影响本页演示数据，可随时恢复。'
              : '换个关键词或处置类型再试',
          illustration: NullStatusIllustration.logs,
          action: _cleared
              ? FilledButton(
                  onPressed: _restoreLogs,
                  child: const Text('恢复示例日志'),
                )
              : null,
        ),
      )
    else
      generateSection(
        title: '最近请求',
        footer: '点按一行查看完整解析信息；演示数据按时间倒序，共 ${mockLogs.length} 条。',
        items: [
          for (final entry in visible)
            _RequestRow(entry: entry, onTap: () => _openDetail(entry)),
        ],
      ),
  ];

  List<Widget> _cacheChildren() => [
    generateSection(
      title: 'DNS 缓存',
      footer: '按命中次数排序。TTL 归零后，下一轮缓存清扫才会移除条目——所以这里能看到 '
          'TTL 很小但仍在列表里的记录。',
      items: [
        for (final entry in _sortedCache) _CacheRow(entry: entry),
      ],
    ),
  ];

  List<Widget> _raceChildren(ResolutionMode resolution) => [
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
    generateSection(
      title: '上游竞速排行',
      footer: '胜出次数是「最先返回」的次数；失败数是超时或解析失败的次数。',
      items: [
        for (final entry in mockRaceRanking) _RaceRow(entry: entry),
      ],
    ),
  ];
}

/// 处置筛选 chip 行：全部 / 放行 / 拦截 / 覆写 / 缓存。
class _ActionChips extends StatelessWidget {
  const _ActionChips({required this.value, required this.onChanged});

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
