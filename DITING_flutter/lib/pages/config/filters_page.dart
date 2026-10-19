/// 过滤器（上游 `views/config/filters.dart`，289 行）。
///
/// 一组「名字 + 正则」的列表，用于在日志与连接列表里折叠噪声。上游用通用
/// `ListEditorPage`（可搜索、可多选、可拖拽排序），本仓保留「增删改 + 排序」，
/// 但不做多选删除：条目通常只有几条，逐条删更快，也不会误删一片。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'filters_form.dart';

/// 过滤器列表页。
class FiltersConfigPage extends ConsumerWidget {
  const FiltersConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(configResourcesProvider).filters;
    return CommonScaffold(
      title: '过滤器',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加过滤器',
          onPressed: () => showFilterForm(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '过滤器不拦截流量，只影响日志与连接列表的展示：'
                '命中正则的条目会被折叠成一行摘要。',
            glyph: AppGlyphs.filter,
          ),
          if (filters.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: '还没有过滤器',
                description: '用正则把噪声条目折叠起来，日志会清爽很多',
                illustration: NullStatusIllustration.logs,
                action: FilledButton(
                  onPressed: () => showFilterForm(context, ref),
                  child: const Text('添加过滤器'),
                ),
              ),
            )
          else
            generateSection(
              title: '共 ${filters.length} 条',
              items: [
                for (final filter in filters)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.filter),
                    title: Text(filter.label),
                    subtitle: Text(
                      filter.regex,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        ConfigRemoveButton(
                          tooltip: '编辑 ${filter.label}',
                          glyph: AppGlyphs.edit,
                          onPressed: () =>
                              showFilterForm(context, ref, existing: filter),
                        ),
                        ConfigRemoveButton(
                          tooltip: '删除 ${filter.label}',
                          onPressed: () => _remove(context, ref, filter.label),
                        ),
                      ],
                    ),
                    onTap: () => showFilterForm(context, ref, existing: filter),
                  ),
              ],
              footer: '过滤器按顺序匹配，同一行命中的第一个过滤器生效。',
            ),
        ],
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final confirmed = await confirmConfigAction(
      context,
      title: '删除过滤器',
      message: '确定删除「$label」吗？被它折叠的条目会重新出现在列表里。',
    );
    if (!confirmed) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeFilters({label});
  }
}
