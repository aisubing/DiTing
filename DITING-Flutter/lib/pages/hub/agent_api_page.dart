// ignore_for_file: sort_child_properties_last
import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/pages/hub/agent_analysis_sheet.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/standalone_routes.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// AI analysis settings (upstream `AgentApiSettingsScreen`). Reports are rendered by
/// [AgentAnalysisSheet], which the log pages open directly; this page configures the provider and
/// offers the two test entries.
class AgentApiPage extends ConsumerWidget {
  const AgentApiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentApiProvider);
    final notifier = ref.read(agentApiProvider.notifier);
    final provider = state.activeProvider;
    final colorScheme = context.colorScheme;
    final ready = state.ready;
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
                      MetaChip(
                        label: '温度 ${state.temperature.toStringAsFixed(1)}',
                      ),
                      const MetaChip(label: '请求由你的厂商处理'),
                    ],
                  ),
                  if (!ready)
                    Text(
                      state.enabled
                          ? '补全厂商与密钥后，日志页就能直接发起分析。'
                          : '开启后即可在日志页直接发起分析。',
                      style: AppTextStyle.footnote.of(
                        context,
                      ).copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '厂商与参数',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.devices),
                title: const Text('AI 厂商管理'),
                subtitle: Text('${state.providers.length} 个已配置厂商 · 选择接口与模型'),
                onTap: () => context.push(HubPaths.agentProviders),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.sliders),
                title: const Text('参数与提示词'),
                subtitle: const Text('系统提示词与采样温度'),
                onTap: () => context.push(HubPaths.agentParams),
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
                onTap: () => openAgentAnalysis(
                  context,
                  const AgentDomainTarget('example-tracker.com'),
                ),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dataUsage),
                title: const Text('分析最近流量'),
                subtitle: const Text('汇总最近 DNS 与 HTTPS 记录后真实调用模型'),
                onTap: () =>
                    openAgentAnalysis(context, const AgentTrafficTarget()),
              ),
            ],
            footer: ready
                ? '两项都会真实请求你配置的厂商并消耗额度。'
                : '当前配置不完整（未启用或缺少 API Key），点击会提示先补配置。',
          ),
          generateSection(
            title: '分析入口',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.layers),
                title: const Text('DNS 缓存表'),
                subtitle: const Text('点按任意一行，分析该域名的安全风险'),
                onTap: () => context.push('/logs/cache'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.requests),
                title: const Text('请求记录'),
                subtitle: const Text('打开一条请求的详情，底部可分析该域名'),
                onTap: () => context.push('/requests'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dashboard),
                title: const Text('日志仪表盘'),
                subtitle: const Text('「AI 研判」卡片可对最近流量发起整体分析'),
                // `/logs` is a tab root: pushing it stacks a second copy of the shell branch and
                // trips go_router's duplicate page-key assert, so open the full-screen twin and
                // fall back to a branch switch.
                onTap: () {
                  if (!pushStandalone(context, Routes.logs)) {
                    openLocation(context, Routes.logs);
                  }
                },
              ),
            ],
            footer: '分析结果里的域名可以一键写入白名单或屏蔽规则，写入后启动 DNS VPN 生效。',
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
