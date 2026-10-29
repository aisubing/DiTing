/// Building blocks shared by the request detail and DNS cache detail sheets, so the two sheets
/// keep one look and one set of domain actions.
library;

import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/rules/rule_domain_utils.dart';
import 'package:diting/pages/hub/agent_analysis_sheet.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/icon_badge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Summary card: status badge, selectable host, one-line explanation and classifying chips.
class DetailHeroCard extends StatelessWidget {
  const DetailHeroCard({
    super.key,
    required this.glyph,
    required this.color,
    required this.title,
    required this.subtitle,
    this.chips = const [],
  });

  final Glyph glyph;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        inert: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                IconBadge(
                  glyph: glyph,
                  color: color.withValues(alpha: 0.14),
                  foregroundColor: color,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      SelectableText(
                        title,
                        style: AppTextStyle.headline
                            .of(context)
                            .copyWith(
                              color: colorScheme.onSurface,
                              fontFamily: appMonospaceFontFamily,
                            ),
                      ),
                      Text(subtitle, style: context.listCaptionStyle),
                    ],
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      ),
    );
  }
}

/// Neutral chip for the hero card; a status chip passes its own colors to [TonalChip].
class DetailMetaChip extends StatelessWidget {
  const DetailMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return TonalChip(
      label: label,
      color: context.raisedSurfaceLevel.colorOf(colorScheme),
      foregroundColor: colorScheme.onSurfaceVariant,
    );
  }
}

/// Copy, blacklist and whitelist buttons for [host]. Domain rules match query names, so a literal
/// IP can only be copied, and a note under the row says why the rule buttons are off.
class DomainActionRow extends ConsumerWidget {
  const DomainActionRow({super.key, required this.host});

  /// Bare host without port or trailing dot; null when the record has none.
  final String? host;

  Future<void> _copy(BuildContext context, String host) async {
    await Clipboard.setData(ClipboardData(text: host));
    if (!context.mounted) return;
    showObsTip(context, '已复制 $host');
  }

  Future<void> _addRule(
    BuildContext context,
    WidgetRef ref,
    RuleKind kind,
    String domain,
  ) async {
    final added = await ref.read(rulesProvider.notifier).add(kind, domain);
    if (!context.mounted) return;
    showObsTip(
      context,
      added ? '已将 $domain 加入${kind.title}' : '$domain 已在${kind.title}中',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final host = this.host;
    final domain = host == null ? null : normalizeDomain(host);
    bool listed(RuleKind kind) =>
        domain != null &&
        ref
            .watch(rulesOfKindProvider(kind))
            .any((rule) => rule.pattern == domain);
    final inBlock = listed(RuleKind.block);
    final inAllow = listed(RuleKind.allow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyphs.copy,
                  label: host != null && domain == null ? '复制地址' : '复制域名',
                  color: colorScheme.primary,
                  onPressed: host == null ? null : () => _copy(context, host),
                ),
              ),
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyphs.block,
                  label: inBlock ? '已在黑名单' : '加入黑名单',
                  color: colorScheme.error,
                  onPressed: domain == null || inBlock
                      ? null
                      : () => _addRule(context, ref, RuleKind.block, domain),
                ),
              ),
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyphs.checkCircle,
                  label: inAllow ? '已在白名单' : '加入白名单',
                  color: colorScheme.success,
                  onPressed: domain == null || inAllow
                      ? null
                      : () => _addRule(context, ref, RuleKind.allow, domain),
                ),
              ),
            ],
          ),
        ),
        if (host != null && domain == null)
          const ListFooter(text: '该记录只有 IP 地址，域名规则无法匹配，因此不能加入黑白名单。'),
      ],
    );
  }
}

/// Icon over label in a card; disabled when [onPressed] is null.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.glyph,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final Glyph glyph;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = enabled ? color : context.colorScheme.onSurfaceVariant;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: CommonCard(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            IconBadge(
              glyph: glyph,
              size: 40,
              glyphSize: 20,
              color: tint.withValues(alpha: 0.14),
              foregroundColor: tint,
              shape: AppShape.circle,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .copyWith(color: context.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows of `KeyValueRow` on one card, the layout the traffic detail sheet uses.
class DetailInfoCard extends StatelessWidget {
  const DetailInfoCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      inert: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Tappable card that opens the AI report for [domain] above the current sheet.
class AgentAnalysisEntryCard extends StatelessWidget {
  const AgentAnalysisEntryCard({
    super.key,
    required this.domain,
    this.title = '分析这条请求',
  });

  final String domain;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onPressed: () => openAgentAnalysis(context, AgentDomainTarget(domain)),
      child: Row(
        spacing: 12,
        children: [
          IconBadge(
            glyph: AppGlyphs.sparkle,
            size: 38,
            glyphSize: 20,
            color: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            shape: AppShape.circle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: context.listTitleStyle),
                Text('用配置的模型研判归属、风险与处置建议', style: context.listCaptionStyle),
              ],
            ),
          ),
          GlyphIcon(
            AppGlyphs.chevronForward,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
