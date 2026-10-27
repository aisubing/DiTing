// ignore_for_file: sort_child_properties_last
import 'package:diting/pages/hub/agent_provider_editor.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AI provider management (upstream `AiProviderManageScreen`), persisted by `AgentApiNotifier` so
/// "test connection" reflects what is on disk. An empty key keeps the existing one.
class AgentProvidersPage extends ConsumerWidget {
  const AgentProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentApiProvider);
    final notifier = ref.read(agentApiProvider.notifier);
    final groups = <String, List<AiProviderPreset>>{};
    for (final preset in aiProviderPresets) {
      groups.putIfAbsent(preset.group, () => []).add(preset);
    }
    final added = state.providers.map((provider) => provider.presetId).toSet();
    return CommonScaffold(
      title: 'AI 厂商管理',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加自定义厂商',
          onPressed: () => _edit(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          PageIntroCard(
            text:
                '点选下方预设厂商会自动预填接口地址；模型名请在编辑页点「拉取模型」'
                '从厂商真实返回的列表里选。编辑时若 API Key 留空则保留原密钥。'
                '密钥以旧版同一套掩码混淆后存在本机，不额外落明文。',
          ),
          generateSection(
            title: '我的厂商',
            items: [
              if (state.providers.isEmpty)
                const ListItem(
                  title: Text('暂无厂商'),
                  subtitle: Text('从下方预设厂商目录点选，或点击右上角添加自定义厂商'),
                  leading: GlyphIcon(AppGlyphs.info),
                ),
              for (final provider in state.providers)
                ListItem(
                  leading: GlyphIcon(
                    provider.id == state.activeProviderId
                        ? AppGlyphs.checkCircle
                        : AppGlyphs.devices,
                    size: 20,
                    color: provider.id == state.activeProviderId
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(provider.name),
                  subtitle: Text(
                    '${provider.model.isEmpty ? '未选择模型' : provider.model} · '
                    '${provider.baseUrl} · '
                    '${provider.hasKey ? '密钥已配置' : '缺少密钥'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () =>
                            _edit(context, ref, existing: provider),
                        icon: const GlyphIcon(AppGlyphs.edit, size: 20),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _delete(context, notifier, provider),
                        icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                      ),
                    ],
                  ),
                  onTap: () => notifier.selectProvider(provider.id),
                ),
            ],
            footer: state.providers.isEmpty
                ? null
                : '点一行可切换当前生效厂商；切换会把接口地址、密钥与模型同步到旧版的'
                      '四个平铺键，避免新版界面与旧版读取来源不一致。',
          ),
          for (final entry in groups.entries)
            generateSection(
              title: entry.key,
              items: [
                for (final preset in entry.value)
                  ListItem(
                    leading: GlyphIcon(
                      added.contains(preset.id)
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.addCircle,
                      size: 20,
                    ),
                    title: Text(preset.name),
                    subtitle: Text(preset.baseUrl),
                    trailing: TonalChip(
                      label: added.contains(preset.id) ? '已添加' : '添加',
                      color: added.contains(preset.id)
                          ? context.raisedSurfaceLevel.colorOf(
                              context.colorScheme,
                            )
                          : context.colorScheme.primary,
                      foregroundColor: added.contains(preset.id)
                          ? context.colorScheme.onSurfaceVariant
                          : context.colorScheme.onPrimary,
                      onPressed: added.contains(preset.id)
                          ? null
                          : () => _edit(context, ref, preset: preset),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    AiProviderConfig? existing,
    AiProviderPreset? preset,
  }) async {
    final result = await showFloatingDialog<ProviderFormResult>(
      context: context,
      child: AgentProviderEditor(existing: existing, preset: preset),
    );
    if (result == null) return;
    final notifier = ref.read(agentApiProvider.notifier);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final id =
        existing?.id ??
        (preset != null ? 'preset_${preset.id}_$stamp' : 'provider_$stamp');
    notifier.saveProvider(
      AiProviderConfig(
        id: id,
        name: result.name,
        baseUrl: result.baseUrl,
        model: result.model,
        presetId: preset?.id ?? existing?.presetId ?? '',
        sealedKey: existing?.sealedKey ?? '',
      ),
      plainKey: result.key,
    );
  }

  Future<void> _delete(
    BuildContext context,
    AgentApiNotifier notifier,
    AiProviderConfig provider,
  ) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除厂商',
        destructive: true,
        child: Text('确定要删除「${provider.name}」吗？相关 API Key 也会从本机移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.deleteProvider(provider.id);
  }
}
