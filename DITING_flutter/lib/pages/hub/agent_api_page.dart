// ignore_for_file: sort_child_properties_last
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// AI 分析设置（上游 `AgentApiSettingsScreen`）。
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      GlyphIcon(AppGlyphs.sparkle, size: 24, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.enabled ? 'AI 分析已启用' : 'AI 分析未启用',
                          style: context.listTitleStyle,
                        ),
                      ),
                      CommonCheckBox(
                        value: state.enabled,
                        onChanged: (value) => notifier.update(
                          (current) => current.copyWith(enabled: value ?? false),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    provider == null
                        ? '尚未配置 AI 厂商；请先在「AI 厂商管理」中添加并填写 API Key。'
                        : '当前厂商：${provider.name} · ${provider.model}',
                    style: context.listSubtitleStyle,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      MetaChip(label: provider?.hasKey == true ? '密钥已配置' : '缺少 API Key'),
                      MetaChip(
                        label: provider == null
                            ? '未选择厂商'
                            : (provider.hasKey ? '可直接分析' : '需补充密钥'),
                      ),
                      const MetaChip(label: '仅本地保存'),
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
                subtitle: Text(
                  '${state.providers.length} 个已配置厂商 · 选择接口与模型',
                ),
                onTap: () => context.push('/hub/agent/providers'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.sliders),
                title: const Text('参数与提示词'),
                subtitle: const Text('系统提示词、采样温度与输出限制'),
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
                subtitle: const Text('检查安全风险、追踪特征与规则处置建议'),
                onTap: () => _runTest(context, 'example-tracker.com'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dataUsage),
                title: const Text('分析最近流量'),
                subtitle: const Text('基于当前日志摘要生成研判结果'),
                onTap: () => _runTest(context, '最近 20 条请求'),
              ),
            ],
          ),
          generateSection(
            title: '重置设置',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.reset),
                title: const Text('恢复出厂默认配置'),
                subtitle: const Text('将清空厂商、API Key、提示词与参数'),
                onTap: () => _reset(context, notifier),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'AI 分析用于辅助研判，不会自动修改规则；所有请求由你配置的厂商处理。'
              '本演示不会真正发起网络请求。',
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

  Future<void> _runTest(BuildContext context, String target) async {
    await showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: 'AI 分析结果',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text('目标：$target', style: context.listTitleStyle),
            const Text('风险等级：中'),
            const Text('该域名包含明显的统计参数与第三方追踪特征，建议加入黑名单观察。'),
            const Text('演示环境不调用真实模型；配置厂商与密钥后由真实接口返回结果。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
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
    if (confirmed == true) {
      notifier.reset();
    }
  }
}
