/// 脚本页（上游 `views/config/scripts.dart`，412 行）。
///
/// 上游的脚本有两种来源：本地手写与远程 URL（可同步更新）。本仓保留两种来源的
/// 区分，但把「编辑器」简化成一段多行文本：上游打开的是完整 YAML/JS 编辑器
/// （补全、高亮、行号），那是另一个量级的组件，不应混进配置域的迁移。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'scripts_editor.dart';

/// 脚本列表页。
class ScriptsConfigPage extends ConsumerWidget {
  const ScriptsConfigPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MockScript script,
  ) async {
    final confirmed = await confirmConfigAction(
      context,
      title: '删除脚本',
      message:
          '确定删除「${script.name}」吗？'
          '${script.fromUrl ? '远程地址不会被删除，重新添加即可恢复。' : '脚本内容将一并删除。'}',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeScript(script.name);
  }

  void _sync(BuildContext context) =>
      showConfigHint(context, '演示环境不联网：远程脚本的同步只更新「上次同步」时间');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(configResourcesProvider).scripts;
    return CommonScaffold(
      title: '脚本',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加脚本',
          onPressed: () => showScriptEditor(context, ref),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '全部同步远程脚本',
          glyph: AppGlyphs.cloudSync,
          onPressed: scripts.any((script) => script.fromUrl)
              ? () => _sync(context)
              : null,
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '脚本在配置加载前执行：拿到整份配置对象，可以改规则、改 DNS、'
                '重命名节点组。多个脚本按列表顺序依次执行。',
            glyph: AppGlyphs.code,
          ),
          if (scripts.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: '还没有脚本',
                description: '写一段 main(config) 就能在配置加载前改它',
                illustration: NullStatusIllustration.scripts,
                action: FilledButton(
                  onPressed: () => showScriptEditor(context, ref),
                  child: const Text('添加脚本'),
                ),
              ),
            )
          else
            generateSection(
              title: '共 ${scripts.length} 个',
              items: [
                for (final script in scripts)
                  ListItem(
                    leading: GlyphIcon(
                      script.fromUrl ? AppGlyphs.cloudDownload : AppGlyphs.code,
                      size: 20,
                    ),
                    title: Text(script.name),
                    subtitle: Text(
                      script.description ?? (script.fromUrl ? '远程脚本' : '本地脚本'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        if (script.fromUrl)
                          ConfigRemoveButton(
                            tooltip: '同步 ${script.name}',
                            glyph: AppGlyphs.sync,
                            onPressed: () => _sync(context),
                          ),
                        ConfigRemoveButton(
                          tooltip: '编辑 ${script.name}',
                          glyph: AppGlyphs.edit,
                          onPressed: () =>
                              showScriptEditor(context, ref, existing: script),
                        ),
                        ConfigRemoveButton(
                          tooltip: '删除 ${script.name}',
                          onPressed: () => _delete(context, ref, script),
                        ),
                      ],
                    ),
                    onTap: () =>
                        showScriptEditor(context, ref, existing: script),
                  ),
              ],
              footer:
                  '脚本出错时内核会退回未修改的配置，'
                  '不会因为一个脚本挂掉整次加载。',
            ),
        ],
      ),
    );
  }
}
