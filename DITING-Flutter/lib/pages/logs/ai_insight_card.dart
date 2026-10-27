import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/hub/agent_analysis_sheet.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Dashboard entry for the AI traffic report. It reuses the last successful run instead of
/// spending another request every time the card is tapped.
class AiInsightCard extends ConsumerWidget {
  const AiInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentAnalysisProvider);
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final report = state.success && state.target is AgentTrafficTarget
        ? state.content
        : null;
    final headline = report == null ? null : _headlineOf(report);

    return DashboardCard(
      semanticLabel: 'AI 研判',
      onTap: () => _open(context, state.sessionId, report != null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.sparkle,
            title: 'AI 研判',
            trailing: [
              DashboardChip(
                label: report == null ? '未分析' : '已有结论',
                tone: report == null
                    ? DashboardChipTone.idle
                    : DashboardChipTone.ok,
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          if (headline == null)
            Text(
              '把最近的 DNS 与 HTTPS 记录交给配置的模型，'
              '汇总异常请求、防护效果与优化建议。',
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
            )
          else ...[
            Text(
              headline,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline.of(context).copyWith(height: 1.4),
            ),
            SizedBox(height: 6 * scale),
            Text(
              [
                if (state.model case final model? when model.isNotEmpty)
                  '模型 $model',
                if (state.startedAt case final at?)
                  '${at.hour.toString().padLeft(2, '0')}:'
                      '${at.minute.toString().padLeft(2, '0')}',
              ].join(' · '),
              style: DashboardText.label(context),
            ),
          ],
          SizedBox(height: 12 * scale),
          Align(
            alignment: Alignment.centerLeft,
            child: TonalButton(
              size: TonalButtonSize.compact,
              glyph: report == null
                  ? AppGlyphs.sparkle
                  : AppGlyphs.chevronForward,
              label: report == null ? '用 AI 研判最近流量' : '查看完整报告',
              onPressed: () => _open(context, state.sessionId, report != null),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the report sheet; [adopt] makes it show the run that produced [sessionId] instead of
  /// starting a new one.
  void _open(BuildContext context, int sessionId, bool adopt) {
    showSheet<void>(
      context: context,
      builder: (_) => AgentAnalysisSheet(
        target: const AgentTrafficTarget(),
        adoptSessionId: adopt ? sessionId : 0,
      ),
    );
  }
}

/// First meaningful line of a Markdown report: skips headings, rules and empty lines so the card
/// shows a conclusion rather than `### 1. 总体网络安全状况`.
String? _headlineOf(String markdown) {
  for (final line in markdown.split('\n')) {
    final text = line
        .trim()
        .replaceAll(RegExp(r'^#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^(?:[-*+]|\d+\.)\s*'), '')
        .replaceAll(RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$'), '')
        .replaceAll(RegExp(r'[*_~`]'), '')
        .trim();
    if (text.length < 8) continue;
    // Headings and short labels carry no conclusion; the first real sentence does.
    if (RegExp(r'^【?(?:近期|总体|摘要|结论|分析)').hasMatch(text)) continue;
    return text;
  }
  return null;
}
