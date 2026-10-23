// ignore_for_file: sort_child_properties_last
import 'package:diting/data/agent/agent_analysis.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AI analysis result dialog: not configured, running (closable, request continues), succeeded
/// and failed (the real reason). The prompt summary makes the conclusion verifiable.
class AgentAnalysisDialog extends ConsumerStatefulWidget {
  const AgentAnalysisDialog({
    super.key,
    required this.target,
    required this.pending,
  });

  final AgentAnalysisTarget target;

  final Future<void> pending;

  @override
  ConsumerState<AgentAnalysisDialog> createState() =>
      _AgentAnalysisDialogState();
}

class _AgentAnalysisDialogState extends ConsumerState<AgentAnalysisDialog> {
  bool _showContext = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentAnalysisProvider);
    final colorScheme = context.colorScheme;
    final result = state.result;
    final error = state.error;
    final running = state.running || (result == null && error == null);
    return CommonDialog(
      title: widget.target.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (running)
            Row(
              spacing: 10,
              children: [
                const CommonCircleLoading(),
                Expanded(
                  child: Text('正在请求模型服务…', style: context.listSubtitleStyle),
                ),
              ],
            ),
          if (error != null)
            SelectableText(
              error,
              style: context.listSubtitleStyle.copyWith(
                color: colorScheme.error,
              ),
            ),
          if (result != null) ...[
            SelectableText(result.content, style: context.listSubtitleStyle),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                MetaChip(label: '模型 ${result.model}'),
                if (result.hasUsage)
                  MetaChip(label: '${result.totalTokens} tokens'),
              ],
            ),
          ],
          if (state.summary != null) ...[
            TextButton(
              onPressed: () => setState(() => _showContext = !_showContext),
              child: Text(_showContext ? '收起送检摘要' : '查看送检摘要'),
            ),
            if (_showContext)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(colorScheme),
                  shape: AppShape.md,
                ),
                child: SelectableText(
                  state.summary!.render(),
                  style: AppTextStyle.footnote.of(context).copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(running ? '后台继续' : '关闭'),
        ),
      ],
    );
  }
}