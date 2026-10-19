/// 应用访问控制（上游 `views/access.dart`，649 行）。
///
/// 上游把这一页做成「顶部 banner 一条 + 应用列表」，banner 上放总开关、模式、
/// 计数和会随选择状态变化的菜单项。本文件保留同一个结构，但把 banner 拆成
/// 独立的 `AccessControlPanel`、行拆成 `PackageListItem`，与上游的行数切分
/// 一致（上游也是这么拆的）。
library;

import 'dart:async';

import 'package:diting/data/mock_system.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'access_panel.dart';
part 'access_rows.dart';

/// 与规则页、应用选择页一致的防抖时长。
const _searchDebounce = Duration(milliseconds: 250);

/// 访问控制页。
class AccessPage extends ConsumerStatefulWidget {
  const AccessPage({super.key});

  @override
  ConsumerState<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends ConsumerState<AccessPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// 防抖后的关键词；输入框本身不防抖，否则打字会掉字。
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

  /// 关键词同时匹配名称与包名：改规则时手上往往只有一个包名片段。
  List<MockPackage> _visible(AccessControlState state) {
    final apps = [
      for (final package in mockPackages)
        if ((state.showSystemApps || !package.isSystem) &&
            (state.showNonInternetApps || package.hasNetwork) &&
            (_query.isEmpty ||
                package.name.toLowerCase().contains(_query) ||
                package.packageName.toLowerCase().contains(_query)))
          package,
    ];
    switch (state.sort) {
      case AccessSort.none:
        return apps;
      case AccessSort.name:
        return apps..sort((a, b) => a.name.compareTo(b.name));
      case AccessSort.time:
        return apps..sort((a, b) => a.installOrder.compareTo(b.installOrder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accessControlProvider);
    final visible = _visible(state);
    final names = visible.map((package) => package.packageName).toList();

    return CommonScaffold(
      title: '访问控制',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: names.isEmpty || !state.enabled
              ? null
              : () => ref.read(accessControlProvider.notifier).selectAll(names),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '反选当前结果',
          onPressed: names.isEmpty || !state.enabled
              ? null
              : () => ref.read(accessControlProvider.notifier).invert(names),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: state.showSystemApps ? '隐藏系统应用' : '显示系统应用',
          glyph: AppGlyphs.devices,
          checked: state.showSystemApps,
          onPressed: () => ref
              .read(accessControlProvider.notifier)
              .update((s) => s.copyWith(showSystemApps: !s.showSystemApps)),
        ),
        CommonPopupMenuItem(
          label: state.showNonInternetApps ? '隐藏无网络权限应用' : '显示无网络权限应用',
          glyph: AppGlyphs.wifiOff,
          checked: state.showNonInternetApps,
          onPressed: () => ref
              .read(accessControlProvider.notifier)
              .update((s) => s.copyWith(showNonInternetApps: !s.showNonInternetApps)),
        ),
        CommonPopupMenuItem(
          label: '重置全部选择',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: state.selected.isEmpty
              ? null
              : () => ref.read(accessControlProvider.notifier).reset(),
        ),
      ],
      body: PageBody(
        children: [
          AccessControlPanel(
            state: state,
            visibleCount: visible.length,
            onChanged: (next) =>
                ref.read(accessControlProvider.notifier).update((_) => next),
          ),
          if (state.selected.isNotEmpty)
            _SelectedSummary(
              selected: state.selected,
              onClear: () => ref
                  .read(accessControlProvider.notifier)
                  .update((s) => s.copyWith(selected: const {})),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(controller: _search, onChanged: _onSearchChanged),
          ),
          if (visible.isEmpty)
            SizedBox(
              height: 320,
              child: NullStatus(
                label: '没有匹配的应用',
                description: '换个名称或包名片段，或打开菜单显示系统应用',
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
            generateSection(
              title: state.mode == AccessMode.whitelist ? '白名单应用' : '黑名单应用',
              items: [
                for (final package in visible)
                  _PackageListItem(
                    package: package,
                    selected: state.selected.contains(package.packageName),
                    enabled: state.enabled,
                    onToggle: () => ref
                        .read(accessControlProvider.notifier)
                        .toggle(package.packageName),
                  ),
              ],
            ),
          ListFooter(
            text: '${state.mode.label}：'
                '${state.mode == AccessMode.whitelist ? '只有选中的应用' : '选中的应用之外的'}'
                '会经过本机解析。当前共选择 ${state.selected.length} 个应用，'
                '列表可见 ${visible.length} 个。',
          ),
        ],
      ),
    );
  }
}

/// 已选应用摘要：chip 行 + 一键清除。
class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({required this.selected, required this.onClear});

  final Set<String> selected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final names = [
      for (final package in mockPackages)
        if (selected.contains(package.packageName)) package.name,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选 ${selected.length} 个应用',
                    style: context.listTitleStyle,
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: Text(
                    '清除',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in names) CommonChip(label: name),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 应用图标：没有真实图标资源，用数据里的字形名 + 首字兜底。
Widget _packageLeading(MockPackage package, {required bool selected}) {
  return Builder(
    builder: (context) {
      final colorScheme = context.colorScheme;
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: AppShape.sm,
          color: selected
              ? colorScheme.primaryContainer
              : context.raisedSurfaceLevel.colorOf(colorScheme),
        ),
        child: GlyphIcon(
          glyphByName(package.glyphName),
          size: 18,
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      );
    },
  );
}
