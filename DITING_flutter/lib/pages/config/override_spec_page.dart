/// 覆写页的通用骨架（上游 `views/config/override.dart`，695 行）。
///
/// 上游把「一份覆写规格」抽成 `OverrideSpec`，四个页面（TUN / DNS / NTP / 嗅探）
/// 只提供规格、共用同一个视图。这里保留同样的分工：本文件把
/// [MockOverrideSpec] 渲染成列表、加条目浮层与快速编辑，四个页面各自只剩一句
/// `OverrideSpecPage(spec: ...)`。
///
/// 与上游的差异：上游「清空值」会把条目从列表移除（`emptyCancels`），这里保留
/// 空值行——演示页里用户需要看得见「这一项现在没有覆写」，直接消失会让人以为
/// 刚加的条目丢了。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'override_add_sheet.dart';
part 'override_list_sheet.dart';
part 'override_quick_edit.dart';
part 'override_spec_rows.dart';

/// 一份覆写规格的完整页面。
class OverrideSpecPage extends ConsumerWidget {
  const OverrideSpecPage({super.key, required this.spec, this.extraSections});

  final MockOverrideSpec spec;

  /// 追加在覆写列表之后的分组（DNS 页用来放策略表）。
  final List<Widget>? extraSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked =
        ref.watch(overrideProvider.select((all) => all[spec.id]))?.picked ??
        const <String>[];
    final canAdd = spec.allKeys.any((entry) => !picked.contains(entry.key));
    return CommonScaffold(
      title: spec.title,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.addCircle,
          tooltip: '添加条目',
          onPressed: canAdd ? () => showOverrideAddSheet(context, spec) : null,
        ),
        IconButtonData(
          glyph: AppGlyphs.compose,
          tooltip: '快速编辑',
          onPressed: picked.isEmpty
              ? null
              : () => showOverrideQuickEdit(context, spec),
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(text: spec.description),
          OverrideSpecBody(spec: spec),
          ...?extraSections,
        ],
      ),
    );
  }
}

/// 覆写规格的列表部分，可单独嵌进别的页面正文。
class OverrideSpecBody extends ConsumerWidget {
  const OverrideSpecBody({super.key, required this.spec});

  final MockOverrideSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overrideProvider.select((all) => all[spec.id]));
    final picked = state?.picked ?? const <String>[];
    final values = state?.values ?? const <String, String>{};
    final entries = [
      for (final entry in spec.allKeys)
        if (picked.contains(entry.key)) entry,
    ];
    final grouped = groupOverrideEntries(entries);
    return NullStatusSwitcher(
      isEmpty: entries.isEmpty,
      nullStatus: NullStatus(
        label: '还没有覆写任何键',
        description: '点右上角的加号挑一个键开始覆写',
        illustration: NullStatusIllustration.tun,
        action: TonalButton(
          size: TonalButtonSize.bar,
          glyph: AppGlyphs.addCircle,
          label: '添加条目',
          onPressed: () => showOverrideAddSheet(context, spec),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          for (final section in grouped.entries)
            generateSection(
              title: section.key,
              items: [
                for (final entry in section.value)
                  OverrideEntryRow(
                    key: ValueKey('${spec.id}-${entry.key}'),
                    spec: spec,
                    entry: entry,
                    value: values[entry.key] ?? entry.value,
                  ),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 列表型覆写值在状态里用换行分隔保存。
///
/// 换行而不是逗号：DNS 服务商与 CIDR 都可能带逗号分隔的参数，逗号会把一项
/// 拆成两项，而换行在 YAML 列表里本来就是分隔符。
List<String> splitOverrideList(String value) => [
  for (final line in value.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];
