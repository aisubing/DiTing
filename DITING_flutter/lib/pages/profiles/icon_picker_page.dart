import 'package:diting/data/mock_profiles.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 图标选择器（上游 `views/profiles/custom/icon.dart`，593 行）。
///
/// 上游按图标集分组、每个集可折叠、带搜索与「当前选中」标记。这里保留分组
/// 网格 + 搜索 + 选中标记 + 清空，去掉折叠——演示里一共 4 组，全展开才看得全。
///
/// 选中的图标通过 `context.pop(iconName)` 回传给调用页（组编辑页），而不是写
/// provider：图标只属于「正在编辑的那个组」，由调用方决定写进哪个组，选择器
/// 本身不需要知道。
class IconPickerPage extends ConsumerStatefulWidget {
  const IconPickerPage({super.key, required this.profileId, this.current});

  final String profileId;
  final String? current;

  @override
  ConsumerState<IconPickerPage> createState() => _IconPickerPageState();
}

class _IconPickerPageState extends ConsumerState<IconPickerPage> {
  final _search = TextEditingController();
  late String? _selected = widget.current;
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 过滤后的分组；搜索时丢掉空组。
  Map<String, List<String>> get _groups {
    if (_query.isEmpty) {
      return mockIconGroups;
    }
    final result = <String, List<String>>{};
    for (final entry in mockIconGroups.entries) {
      final hits = [
        for (final name in entry.value)
          if (name.toLowerCase().contains(_query)) name,
      ];
      if (hits.isNotEmpty) {
        result[entry.key] = hits;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '选择图标',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '使用这个图标',
        onPressed: _selected == null ? null : () => context.pop(_selected),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.broom,
          tooltip: '清空图标',
          onPressed: () => context.pop(''),
        ),
      ],
      searchState: AppBarSearchState(
        onSearch: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
      body: groups.isEmpty
          ? const NullStatus(
              label: '没有匹配的图标',
              description: '试试其它关键词',
              illustration: NullStatusIllustration.search,
            )
          : PageBody(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          _selected == null
                              ? '未选择图标，组会按类型自动取一个'
                              : '当前：$_selected',
                          style: context.listCaptionStyle,
                        ),
                      ),
                      if (_selected != null)
                        TonalChip(
                          label: '已选',
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          foregroundColor: colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                for (final entry in groups.entries)
                  _IconSection(
                    title: entry.key,
                    names: entry.value,
                    selected: _selected,
                    onSelect: (name) => setState(() => _selected = name),
                  ),
              ],
            ),
    );
  }
}

/// 一组图标：标题 + 网格。
///
/// 每格固定 4 列，不做响应式——一行 4 个、每格 72pt 宽，在手机与桌面上都能
/// 一眼扫完；改成自适应列数会让「同组图标在哪」每次都变。
class _IconSection extends StatelessWidget {
  const _IconSection({
    required this.title,
    required this.names,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              Text(title, style: context.listTitleStyle),
              Text(
                '${names.length}',
                style: context.listCaptionStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 4;
              const spacing = 10.0;
              final size =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final (index, name) in names.indexed)
                    _IconCell(
                      name: name,
                      size: size,
                      isSelected: name == selected,
                      onTap: () => onSelect(name),
                      // 用索引做 key：同名图标在不同组里也不该复用选中动画。
                      key: ValueKey('$title-$index-$name'),
                      glyphColor: colorScheme.onSurfaceVariant,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 单个图标格：选中时换成主色底 + 勾选角标。
class _IconCell extends StatelessWidget {
  const _IconCell({
    super.key,
    required this.name,
    required this.size,
    required this.isSelected,
    required this.onTap,
    required this.glyphColor,
  });

  final String name;
  final double size;
  final bool isSelected;
  final VoidCallback onTap;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      selected: isSelected,
      button: true,
      label: name,
      child: SizedBox.square(
        dimension: size,
        child: CommonCard(
          isSelected: isSelected,
          fillsSelection: isSelected,
          onPressed: onTap,
          child: Stack(
            children: [
              Center(
                child: GlyphIcon(
                  glyphByName(name),
                  size: 22,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GlyphIcon(
                    AppGlyphs.checkCircle,
                    size: 14,
                    color: colorScheme.onPrimary,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.8)
                            : glyphColor.withValues(alpha: 0.6),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
