/// User-Agent page (upstream `views/config/user_agents.dart`).
library;

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/note_card.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'user_agents_dialog.dart';

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
          const NoteCard(
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