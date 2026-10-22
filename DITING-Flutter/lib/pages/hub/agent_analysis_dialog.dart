// ignore_for_file: sort_child_properties_last
import 'package:diting/data/agent/agent_analysis.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AI 分析结果对话框：真实状态机 + 送进提示词的摘要。
///
/// 上一轮这里是四个常量文本（「风险等级：中」…）。现在四种状态各自说自己的
/// 话：未配置（指路到 AI 厂商管理）/ 进行中（可关闭，请求继续）/ 成功（正文 +
/// 模型名 + token 用量）/ 失败（具体原因）。
///
/// 成功时把**送进提示词的摘要**折叠展示在下方。理由：流量分析的结论只有在
/// 「模型拿到的是这 40 条记录」这句话可见时才可验证；只给结论，用户没法判断
/// 模型是在分析他的网络还是在复述提示词。
class AgentAnalysisDialog extends ConsumerStatefulWidget {
  const AgentAnalysisDialog({
    super.key,
    required this.target,
    required this.pending,
  });

  final AgentAnalysisTarget target;

  /// 已启动的分析；对话框只负责订阅状态，不重发请求。
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
