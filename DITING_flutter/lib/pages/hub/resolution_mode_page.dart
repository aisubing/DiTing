import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 解析模式首页（上游 `ResolutionModeHomeScreen`）。
///
/// 当前模式 + 内置服务协议 + 四张模式配置卡。模式本身沿用本仓已有的
/// `ResolutionMode` 状态，避免出现两套解析模式开关。
class ResolutionModePage extends ConsumerStatefulWidget {
  const ResolutionModePage({super.key});

  @override
  ConsumerState<ResolutionModePage> createState() => _ResolutionModePageState();
}

class _ResolutionModePageState extends ConsumerState<ResolutionModePage> {
  static const _descriptions = {
    ResolutionMode.single: '所有查询都发往当前选中的服务商。',
    ResolutionMode.smart: '按历史成功率挑一个，失败后自动换下一个。',
    ResolutionMode.parallel: '同时向所有服务商发起，取最先返回的结果。',
    ResolutionMode.primaryBackup: '主服务商优先，超时后才动备用。',
  };

  ProviderProtocol _protocol = ProviderProtocol.doh;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final colorScheme = context.colorScheme;
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final singleProvider = catalog
        .where((provider) => provider.id == selectedId)
        .firstOrNull;
    return CommonScaffold(
      title: '解析模式',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  GlyphIcon(
                    AppGlyphs.shuffle,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(mode.label, style: context.listTitleStyle),
                        Text(
                          _descriptions[mode] ?? '',
                          style: context.listSubtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  const GlyphIcon(AppGlyphs.chevronForward, size: 18),
                ],
              ),
              onPressed: () => _showModePicker(context, mode),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text('内置服务协议', style: context.listTitleStyle),
                SegmentedControl<ProviderProtocol>(
                  segments: [
                    for (final protocol in ProviderProtocol.values)
                      (protocol, protocol.label),
                  ],
                  value: _protocol,
                  onChanged: (value) => setState(() => _protocol = value),
                ),
                Text(
                  '仅切换内置服务商使用的 DNS / DoT / DoH 协议；'
                  '自定义服务商按自身协议展示。',
                  style: context.listSubtitleStyle,
                ),
              ],
            ),
          ),
          generateSection(
            title: '模式配置',
            items: [
              for (final option in ResolutionMode.values)
                ListItem(
                  leading: GlyphIcon(_glyphOf(option), size: 20),
                  title: Text(option.label),
                  subtitle: Text(_descriptions[option] ?? ''),
                  trailing: Text(
                    _summaryOf(option, singleProvider, raceIds.length),
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () => context.push('/hub/resolution/${_idOf(option)}'),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Glyph _glyphOf(ResolutionMode mode) => switch (mode) {
    ResolutionMode.single => AppGlyphs.dns,
    ResolutionMode.smart => AppGlyphs.sparkle,
    ResolutionMode.parallel => AppGlyphs.speed,
    ResolutionMode.primaryBackup => AppGlyphs.swap,
  };

  static String _summaryOf(
    ResolutionMode mode,
    MockProvider? singleProvider,
    int raceCount,
  ) => switch (mode) {
    ResolutionMode.single => singleProvider?.name ?? '未配置',
    _ => '$raceCount 个服务商',
  };

  static String _idOf(ResolutionMode mode) => switch (mode) {
    ResolutionMode.single => 'single',
    ResolutionMode.smart => 'smart',
    ResolutionMode.parallel => 'parallel',
    ResolutionMode.primaryBackup => 'backup',
  };

  void _showModePicker(BuildContext context, ResolutionMode current) {
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '选择解析模式',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ResolutionMode.values)
              ListItem(
                leading: GlyphIcon(_glyphOf(mode), size: 20),
                title: Text(mode.label),
                subtitle: Text(_descriptions[mode] ?? ''),
                trailing: mode == current ? const SelectionCheck() : null,
                onTap: () {
                  ref.read(resolutionModeProvider.notifier).select(mode);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 单模式配置页（上游四条 `RESOLUTION_*` 路由合并为一个参数化页面）。
class ResolutionModeConfigPage extends ConsumerStatefulWidget {
  const ResolutionModeConfigPage({super.key, required this.modeId});

  final String modeId;

  @override
  ConsumerState<ResolutionModeConfigPage> createState() =>
      _ResolutionModeConfigPageState();
}

class _ResolutionModeConfigPageState
    extends ConsumerState<ResolutionModeConfigPage> {
  ProviderProtocol _protocol = ProviderProtocol.doh;
  late List<String> _order;

  ResolutionMode get _mode => switch (widget.modeId) {
    'smart' => ResolutionMode.smart,
    'parallel' => ResolutionMode.parallel,
    'backup' => ResolutionMode.primaryBackup,
    _ => ResolutionMode.single,
  };

  bool get _single => _mode == ResolutionMode.single;

  @override
  void initState() {
    super.initState();
    final race = ref.read(raceProvidersProvider);
    final catalog = ref.read(dnsProviderCatalogProvider);
    _order = [
      for (final provider in catalog)
        if (race.contains(provider.id)) provider.id,
    ];
  }

  void _select(MockProvider provider) {
    if (_single) {
      ref.read(selectedProviderProvider.notifier).select(provider.id);
      return;
    }
    final notifier = ref.read(raceProvidersProvider.notifier);
    final before = ref.read(raceProvidersProvider);
    final willRemove = before.contains(provider.id);
    if (willRemove && before.length <= RaceProvidersNotifier.minCount) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('至少保留 2 家服务商'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    notifier.toggle(provider.id);
    final next = ref.read(raceProvidersProvider);
    setState(() {
      final nextOrder = [..._order];
      if (next.contains(provider.id) && !nextOrder.contains(provider.id)) {
        nextOrder.add(provider.id);
      }
      nextOrder.removeWhere((id) => !next.contains(id));
      _order = nextOrder;
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _order.length) {
      return;
    }
    setState(() {
      final item = _order.removeAt(index);
      _order.insert(target, item);
    });
    // Primary→backup order is persisted (the engine tries providers in list
    // order), so a drag must write back, not just re-sort the local view.
    ref.read(raceProvidersProvider.notifier).reorder(_order);
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final providers = catalog
        .where((provider) => provider.protocol == _protocol)
        .toList(growable: false);
    final selectedCount = _single ? 1 : raceIds.length;
    final valid = _single
        ? providers.any((provider) => provider.id == selectedId)
        : selectedCount >= RaceProvidersNotifier.minCount;
    final ordered = [
      for (final id in _order)
        ...catalog.where(
          (provider) => provider.id == id && provider.protocol == _protocol,
        ),
    ];
    final rest = [
      for (final provider in providers)
        if (!_order.contains(provider.id)) provider,
    ];
    return CommonScaffold(
      title: _mode.label,
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  GlyphIcon(
                    _single ? AppGlyphs.dns : AppGlyphs.speed,
                    size: 22,
                    color: context.colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      _mode == ResolutionMode.single
                          ? '选择一个服务商作为唯一查询出口。'
                          : '已选 $selectedCount 家服务商，至少需要 2 家。',
                      style: context.listSubtitleStyle,
                    ),
                  ),
                  TonalChip(
                    label: valid ? '已就绪' : '待配置',
                    color: valid
                        ? context.colorScheme.primary
                        : context.raisedSurfaceLevel.colorOf(
                            context.colorScheme,
                          ),
                    foregroundColor: valid
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedControl<ProviderProtocol>(
              segments: [
                for (final protocol in ProviderProtocol.values)
                  (protocol, protocol.label),
              ],
              value: _protocol,
              onChanged: (value) => setState(() => _protocol = value),
            ),
          ),
          generateSection(
            title: switch (_mode) {
              ResolutionMode.single => '查询服务',
              ResolutionMode.smart => '候选服务',
              ResolutionMode.parallel => '同时查询的服务',
              ResolutionMode.primaryBackup => '依次尝试的服务',
            },
            items: [
              for (final provider in [...ordered, ...rest])
                ListItem(
                  leading: GlyphIcon(
                    _single
                        ? (provider.id == selectedId
                              ? AppGlyphs.checkCircle
                              : AppGlyphs.dns)
                        : (raceIds.contains(provider.id)
                              ? AppGlyphs.checkCircle
                              : AppGlyphs.dns),
                    size: 20,
                  ),
                  title: Text(provider.name),
                  subtitle: Text(provider.address),
                  trailing:
                      _mode == ResolutionMode.primaryBackup &&
                          raceIds.contains(provider.id)
                      ? _OrderButtons(
                          onUp: () => _move(_order.indexOf(provider.id), -1),
                          onDown: () => _move(_order.indexOf(provider.id), 1),
                        )
                      : null,
                  onTap: () => _select(provider),
                ),
            ],
            footer: providers.isEmpty ? '暂无此协议的服务商' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OrderButtons extends StatelessWidget {
  const _OrderButtons({required this.onUp, required this.onDown});

  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上移',
          onPressed: onUp,
          icon: const GlyphIcon(AppGlyphs.arrowUp, size: 18),
        ),
        IconButton(
          tooltip: '下移',
          onPressed: onDown,
          icon: const GlyphIcon(AppGlyphs.arrowDown, size: 18),
        ),
      ],
    );
  }
}
