/// 资源更新页（上游 `views/resources.dart`）。
///
/// 上游四类资源（GeoData / IconSet / RuleProvider / Script）都是「远端文件 +
/// 本地缓存」：每项显示名称、地址、更新时间、体积，可单项更新，也可整体更新。
/// 本仓按同样结构组织，但把上游的三层入口（分组 → 资源页 → 文件详情）压成
/// 两层：分组标题 + 行内展开，因为资源详情只有四五个字段，单独开一页太空。
///
/// 更新走 `ResourcesNotifier`（900 ms 假延时）：真正的下载在这份演示里没有，
/// 但「按钮转圈 → 时间刷新」这条反馈链必须真跑一遍，否则用户看不出区别。
library;

import 'dart:async';

import 'package:diting/data/mock_observability.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'resources_rows.dart';

/// 资源页。
class ResourcesPage extends ConsumerStatefulWidget {
  const ResourcesPage({super.key});

  @override
  ConsumerState<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends ConsumerState<ResourcesPage> {
  /// 首次加载的假延时：资源清单要先读盘再算体积，真实实现也不是瞬时的。
  static const _loadDelay = Duration(milliseconds: 400);

  Timer? _loadTimer;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(_loadDelay, () {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateAll() async {
    final state = ref.read(resourcesProvider);
    if (state.isBusy) {
      return;
    }
    final confirmed = await showObsConfirm(
      context,
      title: '更新全部资源',
      message: '将依次更新 ${state.resources.length} 项资源，耗时取决于网络。',
      confirmLabel: '确认更新',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(resourcesProvider.notifier).updateAll();
    if (!mounted) {
      return;
    }
    showObsTip(context, '全部资源已更新');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resourcesProvider);
    final colorScheme = context.colorScheme;
    final groups = [
      for (final kind in ObsResourceKind.values)
        (
          kind: kind,
          items: [
            for (final resource in state.resources)
              if (resource.kind == kind) resource,
          ],
        ),
    ];

    return CommonScaffold(
      title: '资源',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sync,
          tooltip: '同步全部资源',
          isLoading: state.updatingAll,
          onPressed: state.isBusy || _loading ? null : _updateAll,
        ),
      ],
      body: _loading
          ? const ObservabilityLoading(label: '正在读取资源清单')
          : NullStatusSwitcher(
              isEmpty: state.resources.isEmpty,
              nullStatus: obsEmpty(
                label: '没有可更新的资源',
                description: '资源会在首次启动时自动生成。',
                illustration: NullStatusIllustration.data,
              ),
              child: ListView(
                padding: EdgeInsets.only(
                  top: context.contentTopPadding,
                  bottom: 16,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ResourcesSummaryCard(state: state),
                  ),
                  for (final group in groups)
                    if (group.items.isNotEmpty)
                      generateSection(
                        title: group.kind.label,
                        footer: group.kind.description,
                        items: [
                          for (final resource in group.items)
                            ResourceRow(
                              resource: resource,
                              isUpdating: state.isUpdating(resource.id),
                              onSync: () => _updateOne(resource),
                              onEdit: () => _editUrl(resource),
                            ),
                        ],
                      ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: state.isBusy ? null : _updateAll,
                          child: Text(
                            state.updatingAll
                                ? '正在更新 ${state.completed}/${state.total}'
                                : '全部更新',
                          ),
                        ),
                        Text(
                          '更新只影响本地缓存，不会改动配置里的引用地址。',
                          textAlign: TextAlign.center,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 单项更新：不弹确认框。单项更新代价小、可重复，加一步确认只会变慢。
  Future<void> _updateOne(MockObsResource resource) async {
    await ref.read(resourcesProvider.notifier).updateOne(resource.id);
    if (!mounted) {
      return;
    }
    showObsTip(context, '${resource.name} 已更新');
  }

  /// 编辑地址：`InputDialog` 自带校验，直接拿返回值写回。
  ///
  /// 默认值传 `defaultUrl`，用户点「重置」就能回到内置地址。
  Future<void> _editUrl(MockObsResource resource) async {
    final url = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '修改地址',
        labelText: resource.name,
        hintText: 'https://example.com/resource.dat',
        value: resource.url,
        resetValue: resource.defaultUrl,
        suffixText: 'URL',
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return '地址不能为空';
          }
          if (!text.startsWith('https://') && !text.startsWith('http://')) {
            return '地址需以 http:// 或 https:// 开头';
          }
          if (Uri.tryParse(text) == null) {
            return '地址格式不正确';
          }
          return null;
        },
      ),
    );
    if (url == null || !mounted) {
      return;
    }
    ref.read(resourcesProvider.notifier).setUrl(resource.id, url);
    showObsTip(context, '${resource.name} 的地址已更新');
  }
}
