import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Home resolution mode card: segmented control, explanation, current endpoints. The
/// address block sits inside the card, and the dnsDetail opacity slider governs only it.
class HomeResolutionCard extends ConsumerWidget {
  const HomeResolutionCard({super.key, required this.mode});

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
              Expanded(child: Text('解析模式', style: context.listTitleStyle)),
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
          Text(
            _describe(resolution),
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          Opacity(
            opacity: ref.watch(homeOpacityProvider)[HomeLayer.dnsDetail] ?? 1,
            child: const _ResolutionEndpoints(),
          ),
        ],
      ),
    );
  }

  static String _describe(ResolutionMode mode) => switch (mode) {
    ResolutionMode.single => '只用当前选中的服务商，最快但可用性取决于它。',
    ResolutionMode.smart => '按历史成功率挑一个，失败后自动换下一个。',
    ResolutionMode.parallel => '同时向所有服务商发起，取最先返回的结果。',
    ResolutionMode.primaryBackup => '主服务商优先，超时后才动备用。',
  };
}

/// Current resolution endpoints, embedded in the mode card. Multi mode lists providers in
/// catalog order, so the order does not shuffle as providers are picked.
class _ResolutionEndpoints extends ConsumerWidget {
  const _ResolutionEndpoints();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final colorScheme = context.colorScheme;

    final endpoints = resolution.isSingle
        ? [endpointOfProvider(selectedId, catalog)]
        : [
            for (final provider in catalog)
              if (raceIds.contains(provider.id))
                '${provider.protocol.label} · ${provider.address}',
          ];
    final lines = endpoints.isEmpty ? const ['未选择服务商'] : endpoints;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.all(AppCorner.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: GlyphIcon(
              AppGlyphs.dns,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}