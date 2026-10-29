/// Detail sheet for one `dns_cache` row, laid out like the request detail sheet.
library;

import 'package:diting/app/l10n/l10n.dart';
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
      title: context.l10n.logsCacheDetailTitle,
      body: PageBody(
        children: [
          DetailHeroCard(
            glyph: AppGlyphs.layers,
            color: color,
            title: domain.isEmpty ? '—' : domain,
            subtitle: expiring
                ? context.l10n.logsCacheExpiringBody
                : context.l10n.logsCacheValidBody,
            chips: [
              TonalChip(
                label: expiring ? context.l10n.logsExpiring : context.l10n.logsValid,
                color: color.withValues(alpha: 0.14),
                foregroundColor: color,
              ),
              DetailMetaChip(label: dnsTypeName(entry.queryType)),
              DetailMetaChip(
                label: context.l10n.logsHitTimes(entry.hitCount),
              ),
            ],
          ),
          DomainActionRow(host: domain.isEmpty ? null : domain),
          SectionBlock(
            title: context.l10n.logsCacheInfo,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DetailInfoCard(
              children: [
                KeyValueRow(
                  label: context.l10n.logsRecordType,
                  value: dnsTypeName(entry.queryType),
                  monospace: true,
                ),
                KeyValueRow(label: context.l10n.logsRemainingTtl, value: remainingLabel(remaining, context.l10n)),
                KeyValueRow(
                  label: context.l10n.logsOriginalTtl,
                  value: remainingLabel(entry.originalTtlSeconds, context.l10n),
                ),
                KeyValueRow(
                  label: context.l10n.logsExpiry,
                  value: shortDateTimeOf(entry.expiresAt),
                  monospace: true,
                ),
                KeyValueRow(
                  label: context.l10n.logsHitCount,
                  value: countOf(entry.hitCount),
                  monospace: true,
                ),
                KeyValueRow(
                  label: context.l10n.logsLastHit,
                  value: switch (lastHitAt) {
                    null => context.l10n.logsNeverHit,
                    final at => shortDateTimeOf(at),
                  },
                  monospace: lastHitAt != null,
                ),
                KeyValueRow(
                  label: context.l10n.logsResponseSize,
                  value: '${entry.responseSize} B',
                  monospace: true,
                ),
              ],
            ),
          ),
          if (domain.isNotEmpty)
            SectionBlock(
              title: context.l10n.obsAiAnalysis,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AgentAnalysisEntryCard(domain: domain, title: context.l10n.logsAnalyzeDomain),
            ),
          ListFooter(
            text:
                context.l10n.logsCacheDetailFooter,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
