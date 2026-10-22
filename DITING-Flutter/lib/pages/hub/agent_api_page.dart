// ignore_for_file: sort_child_properties_last
import 'package:diting/data/agent/agent_analysis.dart';
import 'package:diting/pages/hub/agent_analysis_dialog.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// AI 分析设置（上游 `AgentApiSettingsScreen`）。
///
/// 上一轮这一页的「功能测试」两个入口弹的是一份**写死的**研判
/// （「风险等级：中」「该域名包含明显的统计参数与第三方追踪特征」），页脚
/// 还写着「本演示不会真正发起网络请求」。现在两个入口都真发请求：
/// - 「分析一个域名」用 `example-tracker.com` 作示例，上下文取自 `dns_log`；
/// - 「分析最近流量」把最近 40 条 DNS + 30 条 HTTPS 记录汇总成摘要再说。
///
/// 结果对话框里同时展示**送进提示词的摘要**：用户能对照「模型看到的是什么」，
/// 而不是只能相信一段无法验证的结论。
class AgentApiPage extends ConsumerWidget {
  const AgentApiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentApiProvider);
    final notifier = ref.read(agentApiProvider.notifier);
    final provider = state.activeProvider;
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: 'AI 分析',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      GlyphIcon(
                        AppGlyphs.sparkle,
                        size: 24,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.enabled ? 'AI 分析已启用' : 'AI 分析未启用',
                          style: context.listTitleStyle,
                        ),
                      ),
                      Switch(
                        value: state.enabled,
                        onChanged: notifier.setEnabled,
                      ),
                    ],
                  ),
                  Text(
                    provider == null
                        ? '尚未配置 AI 厂商；请先在「AI 厂商管理」中添加并填写 API Key。'
                        : '当前厂商：${provider.name} · '
                              '${provider.model.isEmpty ? '未选择模型' : provider.model}',
                    style: context.listSubtitleStyle,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      MetaChip(
                        label: provider?.hasKey == true ? '密钥已配置' : '缺少 API Key',
                      ),
                      MetaChip(label: '温度 ${state.temperature.toStringAsFixed(1)}'),
                      const MetaChip(label: '请求由你的厂商处理'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '详细设置',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.devices),
                title: const Text('AI 厂商管理'),
                subtitle: Text('${state.providers.length} 个已配置厂商 · 选择接口与模型'),
                onTap: () => context.push('/hub/agent/providers'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.sliders),
                title: const Text('参数与提示词'),
                subtitle: const Text('系统提示词与采样温度'),
                onTap: () => context.push('/hub/agent/params'),
              ),
            ],
          ),
          generateSection(
            title: '功能测试',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dns),
                title: const Text('分析一个域名'),
                subtitle: const Text('用示例域名真实调用模型，检查安全风险与处置建议'),
                onTap: () => _run(
                  context,
                  ref,
                  const AgentDomainTarget('example-tracker.com'),
                ),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dataUsage),
                title: const Text('分析最近流量'),
                subtitle: const Text('汇总最近 DNS 与 HTTPS 记录后真实调用模型'),
                onTap: () =>
                    _run(context, ref, const AgentTrafficTarget()),
              ),
            ],
            footer: state.ready
                ? '两项都会真实请求你配置的厂商并消耗额度。'
                : '当前配置不完整（未启用或缺少 API Key），点击会提示先补配置。',
          ),
          generateSection(
            title: '重置设置',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.reset),
                title: const Text('恢复出厂默认配置'),
                subtitle: const Text('将清空厂商、API Key、提示词与温度'),
                onTap: () => _reset(context, notifier),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'AI 分析用于辅助研判，不会自动修改规则；所有请求由你配置的厂商处理，'
              '密钥只存在本机。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    AgentAnalysisTarget target,
  ) async {
    final notifier = ref.read(agentAnalysisProvider.notifier);
    notifier.clear();
    final future = notifier.run(target);
    await showFloatingDialog<void>(
      context: context,
      child: AgentAnalysisDialog(target: target, pending: future),
    );
  }

  Future<void> _reset(BuildContext context, AgentApiNotifier notifier) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '恢复默认配置？',
        destructive: true,
        child: const Text('此操作将把所有 AI 分析参数、API Key 与系统提示词恢复为默认设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.reset();
  }
}
