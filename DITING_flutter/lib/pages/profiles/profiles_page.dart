import 'dart:math' as math;

import 'package:diting/data/mock_profiles.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'profiles_cards.dart';
part 'profiles_sheets.dart';

/// 配置档案页（上游 `views/profiles/profiles.dart`，657 行）。
///
/// 两列卡片网格而不是列表：档案是个位数的、每张卡要同时显示类型、更新时间
/// 和（远程档案的）用量进度，列表行放不下三行信息，而网格能用卡片宽度换高度。
///
/// 交互有三层：
/// - 点卡片 = 切换当前档案；
/// - 长按 = 进入多选，顶栏换成「删除 / 全选 / 退出多选」；
/// - 卡片右上菜单 = 编辑 / 预览 / 扩展 / 更新 / 重命名 / 删除。
class ProfilesPage extends ConsumerStatefulWidget {
  const ProfilesPage({super.key});

  @override
  ConsumerState<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends ConsumerState<ProfilesPage> {
  /// 网格列数由宽度决定：手机 1 列、平板 2 列、桌面 3 列。
  ///
  /// 不用 `SliverGridDelegateWithMaxCrossAxisExtent`：卡片高度是固定的，宽度
  /// 浮动会让同一行的卡片高矮不齐，而卡片里的进度条必须横向对齐才看得出差异。
  int _columnsFor(double width) {
    if (width >= 1000) {
      return 3;
    }
    if (width >= 620) {
      return 2;
    }
    return 1;
  }

  Future<void> _confirmDelete(List<MockProfile> profiles) async {
    final localizations = UiLocalizations.of(context);
    final names = profiles.map((profile) => profile.name).join('、');
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: profiles.length == 1 ? '删除配置档案' : '删除 ${profiles.length} 个档案',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: Text(
          profiles.length == 1
              ? '删除「$names」后，来自它的节点与规则会一起移除。此操作不可撤销。'
              : '将删除「$names」。此操作不可撤销。',
        ),
      ),
    );
    if (confirmed ?? false) {
      final notifier = ref.read(profilesProvider.notifier);
      if (profiles.length == 1) {
        notifier.delete(profiles.first.id);
      } else {
        notifier.deleteSelected();
      }
    }
  }

  Future<void> _rename(MockProfile profile) async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '重命名档案',
        value: profile.name,
        selectAll: true,
        validator: (value) => (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    ref
        .read(profilesProvider.notifier)
        .update(
          profile.id,
          name: name,
          url: profile.url,
          autoUpdate: profile.autoUpdate,
          userAgent: profile.userAgent,
        );
  }

  void _openSortSheet() {
    showSheet<void>(
      context: context,
      builder: (sheetContext) => _ReorderProfilesSheet(
        onSave: () {
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _handleTap(MockProfile profile) {
    final notifier = ref.read(profilesProvider.notifier);
    if (ref.read(profilesProvider).isSelecting) {
      notifier.toggleSelection(profile.id);
      return;
    }
    if (profile.kind.isMerged) {
      context.push(ProfilesPaths.customOf(profile.id));
      return;
    }
    notifier.select(profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profilesProvider);
    final notifier = ref.read(profilesProvider.notifier);
    final selected = [
      for (final profile in state.profiles)
        if (state.selection.contains(profile.id)) profile,
    ];
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: state.isSelecting ? '已选 ${selected.length} 项' : '配置档案',
      backAction: state.isSelecting ? notifier.clearSelection : null,
      primaryAction: state.isSelecting
          ? null
          : IconButtonData(
              glyph: AppGlyphs.addCircle,
              tooltip: '添加配置档案',
              onPressed: () => context.push(ProfilesPaths.add),
            ),
      iconActions: state.isSelecting
          ? [
              IconButtonData(
                glyph: AppGlyphs.selectAll,
                tooltip: '全选',
                onPressed: notifier.selectAll,
              ),
              IconButtonData(
                glyph: AppGlyphs.delete,
                tooltip: '删除所选',
                onPressed: selected.isEmpty
                    ? null
                    : () => _confirmDelete(selected),
              ),
            ]
          : [
              IconButtonData(
                glyph: AppGlyphs.sort,
                tooltip: '排序与重排',
                onPressed: state.profiles.isEmpty ? null : _openSortSheet,
              ),
            ],
      menuItems: state.isSelecting
          ? const []
          : [
              CommonPopupMenuItem(
                label: '按名称排序',
                glyph: AppGlyphs.sort,
                onPressed: () => notifier.sortBy(ProfileSort.name),
              ),
              CommonPopupMenuItem(
                label: '按更新时间排序',
                glyph: AppGlyphs.clock,
                onPressed: () => notifier.sortBy(ProfileSort.updatedAt),
              ),
              CommonPopupMenuItem(
                label: '按类型排序',
                glyph: AppGlyphs.layers,
                onPressed: () => notifier.sortBy(ProfileSort.kind),
              ),
            ],
      body: state.profiles.isEmpty
          ? NullStatus(
              label: '还没有配置档案',
              description: '从订阅链接、本地文件或一份空白配置开始',
              illustration: NullStatusIllustration.profile,
              action: FilledButton(
                onPressed: () => context.push(ProfilesPaths.add),
                child: const Text('添加配置档案'),
              ),
            )
          : PageBody(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: CommonCard(
                    child: StatStrip(
                      stats: [
                        StatItem(
                          label: '档案总数',
                          value: '${state.profiles.length}',
                        ),
                        StatItem(
                          label: '远程订阅',
                          value:
                              '${state.profiles.where((p) => p.kind.isRemote).length}',
                          color: colorScheme.primary,
                        ),
                        StatItem(
                          label: '正在更新',
                          value: '${state.updatingIds.length}',
                          color: state.updatingIds.isEmpty
                              ? null
                              : colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    state.isSelecting ? '点卡片继续选择，长按可退出多选' : '点卡片切换当前档案，长按进入多选',
                    style: context.listCaptionStyle,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsFor(constraints.maxWidth);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          for (
                            var row = 0;
                            row < (state.profiles.length / columns).ceil();
                            row++
                          )
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 12,
                              children: [
                                for (var column = 0; column < columns; column++)
                                  Expanded(
                                    child: switch (row * columns + column) {
                                      final index
                                          when index < state.profiles.length =>
                                        _ProfileCard(
                                          profile: state.profiles[index],
                                          isCurrent:
                                              state.profiles[index].id ==
                                              state.currentId,
                                          isSelected: state.selection.contains(
                                            state.profiles[index].id,
                                          ),
                                          isUpdating: state.updatingIds
                                              .contains(
                                                state.profiles[index].id,
                                              ),
                                          onTap: () =>
                                              _handleTap(state.profiles[index]),
                                          onLongPress: () =>
                                              notifier.toggleSelection(
                                                state.profiles[index].id,
                                              ),
                                          menuItems: () =>
                                              _menuItems(state.profiles[index]),
                                        ),
                                      _ => const SizedBox.shrink(),
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  List<CommonPopupMenuItem> _menuItems(MockProfile profile) {
    final notifier = ref.read(profilesProvider.notifier);
    final updatable =
        profile.kind.isRemote &&
        !ref.read(profilesProvider).updatingIds.contains(profile.id);
    return [
      CommonPopupMenuItem(
        label: profile.kind.isMerged ? '编辑自定义配置' : '编辑档案',
        glyph: AppGlyphs.edit,
        onPressed: () => context.push(
          profile.kind.isMerged
              ? ProfilesPaths.customOf(profile.id)
              : ProfilesPaths.editOf(profile.id),
        ),
      ),
      CommonPopupMenuItem(
        label: '查看运行配置',
        glyph: AppGlyphs.eye,
        onPressed: () => context.push(ProfilesPaths.previewOf(profile.id)),
      ),
      if (updatable)
        CommonPopupMenuItem(
          label: '立即更新',
          glyph: AppGlyphs.sync,
          onPressed: () => notifier.startUpdate(profile.id),
        ),
      if (!profile.kind.isMerged)
        CommonPopupMenuItem(
          label: '扩展配置',
          glyph: AppGlyphs.puzzle,
          onPressed: () => context.push(ProfilesPaths.extendOf(profile.id)),
        ),
      CommonPopupMenuItem(
        label: '重命名',
        glyph: AppGlyphs.textShort,
        onPressed: () => _rename(profile),
      ),
      CommonPopupMenuItem(
        label: '删除',
        glyph: AppGlyphs.delete,
        danger: true,
        onPressed: () => _confirmDelete([profile]),
      ),
    ];
  }
}
