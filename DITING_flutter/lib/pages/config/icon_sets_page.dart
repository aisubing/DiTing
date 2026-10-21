/// 图标集页（上游 `views/config/icon_sets.dart`，316 行）。
///
/// 图标集是「名字 → 图标文件」的 JSON：订阅里的节点组写上图标名，就能在分组
/// 卡片上显示。本仓保留列表、表单与网格预览；从文件导入需要文件选择器，演示层
/// 不引依赖，改为手动填写图标名。
library;

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'icon_sets_form.dart';
part 'icon_sets_preview.dart';

/// 图标集列表页。
class IconSetsConfigPage extends ConsumerWidget {
  const IconSetsConfigPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MockIconSet iconSet,
  ) async {
    final confirmed = await confirmConfigAction(
      context,
      title: '删除图标集',
      message: '确定删除「${iconSet.name}」吗？引用它的分组会退回无图标状态。',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeIconSet(iconSet.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconSets = ref.watch(configResourcesProvider).iconSets;
    return CommonScaffold(
      title: '图标集',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加图标集',
          onPressed: () => showIconSetForm(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '图标集把「图标名 → 图片」的映射集中管理：'
                '分组配置里写 `icon: 图标名`，卡片就会显示对应图片。',
            glyph: AppGlyphs.iconTile,
          ),
          if (iconSets.isEmpty)
            EmptyStateBox(
              minHeight: 300,
              child: NullStatus(
                label: '还没有图标集',
                description: '添加一组图标后，分组卡片就能显示它们',
                illustration: NullStatusIllustration.icons,
                action: FilledButton(
                  onPressed: () => showIconSetForm(context, ref),
                  child: const Text('添加图标集'),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CommonCard(
                child: StatStrip(
                  stats: [
                    StatItem(label: '图标集', value: '${iconSets.length}'),
                    StatItem(
                      label: '图标总数',
                      value:
                          '${iconSets.fold<int>(0, (sum, item) => sum + item.icons.length)}',
                    ),
                  ],
                ),
              ),
            ),
            generateSection(
              title: '全部图标集',
              items: [
                for (final iconSet in iconSets)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.photos, size: 20),
                    title: Text(iconSet.name),
                    subtitle: Text(
                      iconSet.fromUrl ? '远程 · ${iconSet.url}' : '本地图标集',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        ConfigRemoveButton(
                          tooltip: '预览 ${iconSet.name}',
                          glyph: AppGlyphs.eye,
                          onPressed: () => showIconSetPreview(context, iconSet),
                        ),
                        ConfigRemoveButton(
                          tooltip: '编辑 ${iconSet.name}',
                          glyph: AppGlyphs.edit,
                          onPressed: () =>
                              showIconSetForm(context, ref, existing: iconSet),
                        ),
                        ConfigRemoveButton(
                          tooltip: '删除 ${iconSet.name}',
                          onPressed: () => _delete(context, ref, iconSet),
                        ),
                      ],
                    ),
                    onTap: () => showIconSetPreview(context, iconSet),
                  ),
              ],
              footer:
                  '同一图标名在多个图标集里出现时，'
                  '按列表顺序取第一个匹配的图标集。',
            ),
          ],
        ],
      ),
    );
  }
}
