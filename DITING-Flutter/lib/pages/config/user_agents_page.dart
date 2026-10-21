/// User-Agent 页（上游 `views/config/user_agents.dart`，235 行）。
///
/// UA 列表是「一组候选 + 当前选中的一条」：选中的那条写进订阅下载请求，其余只是
/// 备选。上游把「不覆写」做成列表首项，本仓照做——否则用户没有办法回到「跟随
/// 订阅/内核默认」。
///
/// 选中值放在 `configResourcesProvider` 里而不是通用配置：那一族（FlClash 的
/// 内核配置）随页面一起删除，为一行保留项拖回整套通用配置不划算。
library;

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'user_agents_dialog.dart';

/// UA 列表页。
class UserAgentsConfigPage extends ConsumerWidget {
  const UserAgentsConfigPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MockUserAgent agent,
  ) async {
    final confirmed = await confirmConfigAction(
      context,
      title: '删除 User-Agent',
      message: '确定删除这一条吗？只删候选，不影响当前已选中的 UA。',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeUserAgent(agent.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(configResourcesProvider);
    final agents = resources.userAgents;
    final selected = resources.selectedUserAgent;
    final notifier = ref.read(configResourcesProvider.notifier);
    return CommonScaffold(
      title: 'User-Agent',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加 User-Agent',
          onPressed: () => showUserAgentDialog(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          const ConfigNoteCard(
            text:
                'UA 会随订阅下载、规则集拉取与订阅测速请求一起发送；'
                '部分服务端按 UA 拒绝请求，改这里可以绕过。',
            glyph: AppGlyphs.account,
          ),
          generateSection(
            title: '当前选择',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.checkCircle),
                title: const Text('不覆写'),
                subtitle: const Text('沿用订阅或内核自带的 UA'),
                trailing: selected == null ? const SelectionCheck() : null,
                onTap: () => notifier.selectUserAgent(null),
              ),
              for (final agent in agents)
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.account),
                  title: Text(
                    agent.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(agent.isDefault ? '内置' : '自定义'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      if (agent.value == selected) const SelectionCheck(),
                      if (!agent.isDefault)
                        ConfigRemoveButton(
                          tooltip: '编辑',
                          glyph: AppGlyphs.edit,
                          onPressed: () => showUserAgentDialog(
                            context,
                            ref,
                            existing: agent.value,
                          ),
                        ),
                      if (!agent.isDefault)
                        ConfigRemoveButton(
                          tooltip: '删除',
                          onPressed: () => _delete(context, ref, agent),
                        ),
                    ],
                  ),
                  onTap: () => notifier.selectUserAgent(agent.value),
                ),
            ],
            footer:
                '内置 UA 不可删除：删掉之后内核回落到默认值，'
                '用户会误以为「设置没生效」。',
          ),
        ],
      ),
    );
  }
}
