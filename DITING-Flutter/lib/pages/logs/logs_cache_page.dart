import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/pages/hub/agent_analysis_sheet.dart';
import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/log_refresh_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// DNS cache table from the real `dns_cache` table. The engine's in-memory LRU is authoritative;
/// `DnsCacheMirror` mirrors its top entries into this table every 10 s.
class LogsCachePage extends ConsumerStatefulWidget {
  const LogsCachePage({super.key});

  @override
  ConsumerState<LogsCachePage> createState() => _LogsCachePageState();
}

class _LogsCachePageState extends ConsumerState<LogsCachePage> {
  final _search = TextEditingController();
  var _query = '';

  /// The native mirror rewrites `dns_cache` every 10 s; the list follows it without a tap.
  LogLiveRefreshNotifier? _logRefresh;

  @override
  void initState() {
    super.initState();
    _logRefresh = ref.read(logLiveRefreshProvider.notifier);
    _logRefresh!.attachPolling();
  }

  @override
  void dispose() {
    _logRefresh?.detachPolling();
    _search.dispose();
    super.dispose();
  }

  List<DnsCacheRecord> _visible(List<DnsCacheRecord> all) {
    if (_query.isEmpty) return all;
    return [
      for (final entry in all)
        if (entry.domain.toLowerCase().contains(_query)) entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(dnsCacheProvider);
    return CommonScaffold(
      title: 'DNS 缓存表',
      searchState: AppBarSearchState(
        onSearch: (value) {
          final next = value.trim().toLowerCase();
          if (next == _query) return;
          setState(() => _query = next);
        },
      ),
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => ref.read(dnsLogRevisionProvider.notifier).bump(),
          icon: const GlyphIcon(AppGlyphs.refresh),
        ),
      ],
      body: _buildBody(asyncEntries),
    );
  }

  Widget _buildBody(AsyncValue<List<DnsCacheRecord>> asyncEntries) {
    // Check hasValue first: a refresh keeps the old value alongside isLoading, and
    // looking at isLoading alone would flash the loading state and lose scroll.
    if (!asyncEntries.hasValue) {
      if (asyncEntries.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '无法读取缓存表：${asyncEntries.error}',
              textAlign: TextAlign.center,
              style: context.listSubtitleStyle,
            ),
          ),
        );
      }
      return const LogsPageLoading(label: '正在读取缓存表');
    }
    final entries = _visible(asyncEntries.requireValue);
    // Last-hit time is a separate column because DnsCacheRecord has no lastHitAt.
    final lastHits = ref.watch(cacheLastHitProvider).value ?? const {};
    if (entries.isEmpty) {
      return PageBody(
        children: [
          logsEmpty(
            label: _query.isEmpty ? '缓存表还没有条目' : '没有匹配的缓存',
            description: _query.isEmpty
                ? '引擎解析成功后会把应答写进 dns_cache；'
                      '全新安装或隧道刚启动时这张表可能还是空的。'
                : '当前搜索：$_query',
            illustration: NullStatusIllustration.dns,
          ),
        ],
      );
    }
    return PageBody(
      children: [
        generateSection(
          title: '有效缓存',
          footer:
              '共 ${entries.length} 条，按命中次数与过期时间排序。'
              '剩余 TTL 少于 30 秒的条目标橙色。点按一行可用 AI 分析该域名。',
          items: [
            for (final entry in entries)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.layers),
                onTap: () =>
                    openAgentAnalysis(context, AgentDomainTarget(entry.domain)),
                title: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        entry.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TonalChip(
                      label: dnsTypeName(entry.queryType),
                      color: context.raisedSurfaceLevel.colorOf(
                        context.colorScheme,
                      ),
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      '原始 TTL ${remainingLabel(entry.originalTtlSeconds)} · '
                      '命中 ${entry.hitCount} 次 · ${entry.responseSize} B',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '最后命中 ${switch (lastHits['${entry.domain}|${entry.queryType}']) {
                        null => '尚未命中',
                        final at => shortDateTimeOf(at),
                      }}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Text(
                  '剩 ${remainingLabel(entry.remainingTtlSeconds)}',
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(
                        color: entry.remainingTtlSeconds < 30
                            ? context.colorScheme.warning
                            : context.colorScheme.success,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
