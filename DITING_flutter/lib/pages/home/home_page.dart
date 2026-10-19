import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 首页：三种工作模式共用一个壳，只有服务商区块与句子随模式变。
///
/// 结构（`docs/refactor/03-navigation-and-main-ui.md` §3.2）：
/// 电源按钮 → 首页句子 → 模式 chip → 服务商选择卡 → 解析详情 → 快捷入口。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workModeProvider);
    final power = ref.watch(powerProvider);
    final sentence = ref.watch(homeSentenceProvider);
    final opacity = ref.watch(homeOpacityProvider);

    return CommonScaffold(
      title: _titleOf(mode),
      actions: [
        _ModeChip(mode: mode, onPressed: () => context.push(Routes.modeSelect)),
      ],
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新状态',
          onPressed: () => ref.read(powerProvider.notifier).reset(),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '工作模式',
          glyph: AppGlyphs.layers,
          onPressed: () => context.push(Routes.modeSelect),
        ),
        CommonPopupMenuItem(
          label: '三步引导',
          glyph: AppGlyphs.puzzle,
          onPressed: () => context.push(Routes.modeOnboarding),
        ),
        CommonPopupMenuItem(
          label: '组件画廊',
          glyph: AppGlyphs.palette,
          onPressed: () => context.push(Routes.demo),
        ),
      ],
      body: PageBody(
        children: [
          const SizedBox(height: 8),
          Opacity(
            opacity: opacity[HomeLayer.powerButton] ?? 1,
            child: HomePowerButton(
              state: power,
              onPressed: () => ref.read(powerProvider.notifier).toggle(),
            ),
          ),
          if (sentence.forState(power) case final text? when text.isNotEmpty)
            Opacity(
              opacity: opacity[HomeLayer.poem] ?? 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 4),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Opacity(
              opacity: opacity[HomeLayer.providerSelector] ?? 1,
              child: const _ProviderCard(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Opacity(
              opacity: opacity[HomeLayer.modeButton] ?? 1,
              child: _ResolutionCard(mode: mode),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _QuickStats(state: power),
          ),
          const SizedBox(height: 8),
          _QuickEntries(mode: mode),
        ],
      ),
    );
  }

  String _titleOf(AppWorkMode mode) => switch (mode) {
    AppWorkMode.normal => '谛听 · 普通',
    AppWorkMode.server => '谛听 · 服务器',
    AppWorkMode.express => '谛听 · 极速',
  };
}

/// 句子按电源状态二选一；运行/启动中显示「运行」那句。
extension on ({String running, String stopped}) {
  String? forState(PowerState state) =>
      state.isRunning || state == PowerState.starting ? running : stopped;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.onPressed});

  final AppWorkMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TonalChip(
        label: mode.title,
        color: context.colorScheme.primaryContainer,
        foregroundColor: context.colorScheme.onPrimaryContainer,
        onPressed: onPressed,
      ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final subtitle = resolution.isSingle
        ? providerEndpointOf(selectedId)
        : raceProviderSummary(raceIds);
    return CommonCard(
      onPressed: () => showSheet(
        context: context,
        builder: (_) => const _ProviderSheet(),
      ),
      child: ListItem(
        leading: const GlyphIcon(AppGlyphs.dns),
        title: Text(resolution.isSingle ? '解析服务商' : '竞速服务商'),
        subtitle: Text(subtitle),
        trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
        onTap: () => showSheet(
          context: context,
          builder: (_) => const _ProviderSheet(),
        ),
      ),
    );
  }
}

class _ResolutionCard extends ConsumerWidget {
  const _ResolutionCard({required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    return CommonCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              const GlyphIcon(AppGlyphs.shuffle, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('解析模式', style: context.listTitleStyle),
              ),
              Text(
                resolution.label,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.primary),
              ),
            ],
          ),
          SegmentedControl<ResolutionMode>(
            segments: [
              for (final option in ResolutionMode.values)
                (option, option.label),
            ],
            value: resolution,
            onChanged: (value) =>
                ref.read(resolutionModeProvider.notifier).select(value),
          ),
          if (!resolution.isSingle)
            Text(
              '多路模式会同时向上游服务商发起解析，取最先返回的结果。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.state});

  final PowerState state;

  @override
  Widget build(BuildContext context) {
    final stats = mockServiceStats;
    return CommonCard(
      child: StatStrip(
        stats: [
          StatItem(
            label: '今日查询',
            value: state.isRunning ? '28,471' : '0',
          ),
          StatItem(
            label: '缓存命中',
            value: state.isRunning
                ? '${(stats.cacheHitRate * 100).round()}'
                : '0',
            unit: '%',
            color: context.colorScheme.success,
          ),
          StatItem(
            label: '平均延迟',
            value: state.isRunning ? '${stats.averageLatencyMs}' : '—',
            unit: state.isRunning ? 'ms' : null,
          ),
        ],
      ),
    );
  }
}

class _QuickEntries extends StatelessWidget {
  const _QuickEntries({required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, Glyph, String)>[
      ('日志', AppGlyphs.logs, Routes.logs),
      ('流量', AppGlyphs.dataUsage, Routes.traffic),
      ('订阅', AppGlyphs.cloudSync, Routes.subscriptions),
      ('工具', AppGlyphs.tools, Routes.tools),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 10,
        children: [
          for (final (label, glyph, route) in entries)
            Expanded(
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () => context.push(route),
                child: Column(
                  spacing: 6,
                  children: [
                    GlyphIcon(glyph, size: 22),
                    Text(label, style: AppTextStyle.caption1.of(context)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 服务商选择面板：单选 / 多选两套（上游 `ProviderSelectionDialog`）。
class _ProviderSheet extends ConsumerWidget {
  const _ProviderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    return CommonScaffold(
      title: resolution.isSingle ? '选择解析服务商' : '选择竞速服务商',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(title: resolution.isSingle ? '内置服务商' : '至少选 2 个'),
          for (final provider in mockProviders)
            ListItem(
              leading: GlyphIcon(glyphByName('dns'), size: 20),
              title: Text(provider.name),
              subtitle: Text(
                '${provider.protocol.label} · ${provider.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: resolution.isSingle
                  ? (selectedId == provider.id
                        ? const SelectionCheck()
                        : Text(
                            '${provider.latencyMs}ms',
                            style: AppTextStyle.caption1.of(context),
                          ))
                  : CommonCheckBox(
                      value: raceIds.contains(provider.id),
                      isCircle: true,
                      onChanged: (_) => ref
                          .read(raceProvidersProvider.notifier)
                          .toggle(provider.id),
                    ),
              onTap: resolution.isSingle
                  ? () {
                      ref
                          .read(selectedProviderProvider.notifier)
                          .select(provider.id);
                      Navigator.of(context).pop();
                    }
                  : () => ref
                        .read(raceProvidersProvider.notifier)
                        .toggle(provider.id),
            ),
          ListFooter(
            text: resolution.isSingle
                ? '延迟是上次探测结果，不是实时值。'
                : '竞速模式下每个查询会并发发往所有选中服务商。',
          ),
        ],
      ),
    );
  }
}
