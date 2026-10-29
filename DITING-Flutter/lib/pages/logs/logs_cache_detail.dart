/// Detail sheet for one `dns_cache` row, laid out like the request detail sheet.
library;

import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/pages/observability/domain_detail_parts.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// Rows under 30 s of TTL are about to drop out of the cache; the list marks them orange too.
const int cacheExpiringSeconds = 30;

class DnsCacheDetailSheet extends StatelessWidget {
  const DnsCacheDetailSheet({super.key, required this.entry, this.lastHitAt});

  final DnsCacheRecord entry;

  /// Separate column (`lastHitAt`), read by the list page; null when never hit.
  final int? lastHitAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final remaining = entry.remainingTtlSeconds;
    final expiring = remaining < cacheExpiringSeconds;
    final color = expiring ? colorScheme.warning : colorScheme.success;
    final domain = entry.domain.replaceFirst(RegExp(r'\.+$'), '');

    return CommonScaffold(
      title: '缓存详情',
      body: PageBody(
        children: [
          DetailHeroCard(
            glyph: AppGlyphs.layers,
            color: color,
            title: domain.isEmpty ? '—' : domain,
            subtitle: expiring
                ? '缓存即将过期，过期后下一次查询会重新向上游解析'
                : '缓存有效，命中时直接返回应答，不再请求上游',
            chips: [
              TonalChip(
                label: expiring ? '即将过期' : '有效',
                color: color.withValues(alpha: 0.14),
                foregroundColor: color,
              ),
              DetailMetaChip(label: dnsTypeName(entry.queryType)),
              DetailMetaChip(label: '命中 ${entry.hitCount} 次'),
            ],
          ),
          DomainActionRow(host: domain.isEmpty ? null : domain),
          SectionBlock(
            title: '缓存信息',
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DetailInfoCard(
              children: [
                KeyValueRow(
                  label: '记录类型',
                  value: dnsTypeName(entry.queryType),
                  monospace: true,
                ),
                KeyValueRow(label: '剩余 TTL', value: remainingLabel(remaining)),
                KeyValueRow(
                  label: '原始 TTL',
                  value: remainingLabel(entry.originalTtlSeconds),
                ),
                KeyValueRow(
                  label: '过期时间',
                  value: shortDateTimeOf(entry.expiresAt),
                  monospace: true,
                ),
                KeyValueRow(
                  label: '命中次数',
                  value: countOf(entry.hitCount),
                  monospace: true,
                ),
                KeyValueRow(
                  label: '最后命中',
                  value: switch (lastHitAt) {
                    null => '尚未命中',
                    final at => shortDateTimeOf(at),
                  },
                  monospace: lastHitAt != null,
                ),
                KeyValueRow(
                  label: '应答大小',
                  value: '${entry.responseSize} B',
                  monospace: true,
                ),
              ],
            ),
          ),
          if (domain.isNotEmpty)
            SectionBlock(
              title: 'AI 分析',
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AgentAnalysisEntryCard(domain: domain, title: '分析这个域名'),
            ),
          const ListFooter(
            text:
                '缓存表每 10 秒从引擎内存同步一次，这里是打开时的快照。'
                '加入的黑白名单可在「规则」页查看和撤销。',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
