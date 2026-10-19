/// Clash 提供者页（上游 `views/config/providers.dart`，636 行）。
///
/// 规则提供者（`rule-providers`）：一组「名字 + 地址 + 行为类型 + 更新间隔」的
/// 远程规则集。上游把增删改、同步、预览、编辑器全塞进这一页；本仓保留列表 +
/// 表单 + 同步（演示），预览与编辑器不做——它们分别需要真实拉取与完整编辑器。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'providers_form.dart';

/// 规则提供者列表页。
class ProvidersConfigPage extends ConsumerWidget {
  const ProvidersConfigPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MockClashProvider provider,
  ) async {
    final confirmed = await confirmConfigAction(
      context,
      title: '删除提供者',
      message: '确定删除「${provider.name}」吗？引用它的规则会失去内容。',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeProvider(provider.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(configResourcesProvider).providers;
    return CommonScaffold(
      title: 'Clash 提供者',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加提供者',
          onPressed: () => showProviderForm(context, ref),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '全部同步',
          glyph: AppGlyphs.cloudSync,
          onPressed: providers.isEmpty
              ? null
              : () => showConfigHint(context, '演示环境不联网：同步只更新「上次更新」时间'),
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '提供者把一大段规则放在远端，内核按更新间隔拉取。'
                '规则里用 RULE-SET,名字,策略 引用它们。',
            glyph: AppGlyphs.resources,
          ),
          if (providers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CommonCard(
                child: StatStrip(
                  stats: [
                    StatItem(label: '提供者', value: '${providers.length}'),
                    StatItem(label: '上次更新', value: mockProviderUpdatedAt),
                  ],
                ),
              ),
            ),
          if (providers.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: '还没有提供者',
                description: '添加一个远端规则集，规则里就能按名字引用它',
                illustration: NullStatusIllustration.rules,
                action: FilledButton(
                  onPressed: () => showProviderForm(context, ref),
                  child: const Text('添加提供者'),
                ),
              ),
            )
          else
            generateSection(
              title: '共 ${providers.length} 个',
              items: [
                for (final provider in providers)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.resources, size: 20),
                    title: Text(provider.name),
                    subtitle: Text(
                      '${provider.behavior} · 每 ${provider.intervalLabel} 更新',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        ConfigRemoveButton(
                          tooltip: '编辑 ${provider.name}',
                          glyph: AppGlyphs.edit,
                          onPressed: () => showProviderForm(
                            context,
                            ref,
                            existing: provider,
                          ),
                        ),
                        ConfigRemoveButton(
                          tooltip: '删除 ${provider.name}',
                          onPressed: () => _delete(context, ref, provider),
                        ),
                      ],
                    ),
                    onTap: () =>
                        showProviderForm(context, ref, existing: provider),
                  ),
              ],
              footer:
                  '行为决定规则集的匹配方式：domain 按域名、'
                  'ipcidr 按网段、classical 直接写完整规则。',
            ),
        ],
      ),
    );
  }
}
