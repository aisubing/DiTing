/// 应用选择：勾选哪些应用纳入分流。
///
/// 一页只做一件事，但三处细节必须做对（`docs/refactor/04-rules-ui.md` §5）：
/// 搜索要防抖 250ms（列表里有几百个应用时，每次按键重建整张表会卡）；
/// 分组要按系统分类（用户找应用时先想「这是哪个类别的」）；
/// 全选 / 反选必须只作用于「当前可见」的应用，否则搜索状态下点全选会静默
/// 选中一堆看不见的条目。
library;

import 'dart:async';

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/app_selection_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'apps_rows.dart';

/// 与规则页一致的防抖时长：同属「边打边筛」的交互，两页手感应当一致。
const _searchDebounce = Duration(milliseconds: 250);

/// 应用选择页。
class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// 防抖后的关键词；输入框本身不受防抖影响，否则打字会掉字。
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  /// 关键词同时匹配名称与包名：高级用户往往记得包名片段。
  List<MockInstalledApp> get _visible => [
    for (final app in mockInstalledApps)
      if (_query.isEmpty ||
          app.name.toLowerCase().contains(_query) ||
          app.packageName.toLowerCase().contains(_query))
        app,
  ];

  /// 分类顺序按数据里首次出现的顺序，而不是字典序：这样「工具」「娱乐」这类
  /// 常用类别不会被「出行」「办公」挤到后面。
  List<String> get _categories {
    final seen = <String>{};
    return [
      for (final app in _visible)
        if (seen.add(app.category)) app.category,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(appSelectionProvider);
    final visible = _visible;
    final colorScheme = context.colorScheme;

    return CommonScaffold(
      title: '应用选择',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => ref
                    .read(appSelectionProvider.notifier)
                    .selectAll(visible.map((app) => app.packageName)),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '反选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => ref
                    .read(appSelectionProvider.notifier)
                    .invert(visible.map((app) => app.packageName)),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '清除全部选择',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: selected.isEmpty
              ? null
              : () => ref.read(appSelectionProvider.notifier).clear(),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '已安装',
                    value: '${mockInstalledApps.length}',
                    unit: '个',
                  ),
                  StatItem(
                    label: '已选择',
                    value: '${selected.length}',
                    color: selected.isEmpty
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                  StatItem(
                    label: '当前可见',
                    value: '${visible.length}',
                    unit: '个',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              controller: _search,
              onChanged: _onSearchChanged,
            ),
          ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SelectedSummary(
                selected: selected,
                onClear: () => ref.read(appSelectionProvider.notifier).clear(),
              ),
            ),
          if (visible.isEmpty)
            SizedBox(
              height: 340,
              child: NullStatus(
                label: '没有匹配的应用',
                description: '换个名称或包名片段再试',
                illustration: NullStatusIllustration.apps,
                action: _query.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: const Text('清空搜索'),
                      ),
              ),
            )
          else
            for (final category in _categories)
              generateSection(
                title: category,
                items: [
                  for (final app in visible)
                    if (app.category == category)
                      _AppRow(
                        app: app,
                        selected: selected.contains(app.packageName),
                        onToggle: () => ref
                            .read(appSelectionProvider.notifier)
                            .toggle(app.packageName),
                      ),
                ],
              ),
          ListFooter(
            text: '已选择 ${selected.length} / ${mockInstalledApps.length} 个应用。'
                '选择结果保存在演示状态里，离开页面再回来仍然有效。',
          ),
        ],
      ),
    );
  }
}
