import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首页的解析模式卡。
///
/// 四选一分段控件 + 一句当前模式的说明 + 当前解析地址。上游这一区在普通/服务器/
/// 极速三种模式下都显示，只是极速模式把多路选项藏掉；这里保持一致但不禁用任何
/// 项——演示阶段允许自由切换以便观察差异。
///
/// ## 地址为什么在卡里
/// 上一版地址是卡片**下面**独立的一行文字（1.4.3 的 `dnsDetailOpacity` 块）。
/// 它看起来像页面上的孤立注释：读的时候要跳过卡片的圆角边界，再猜这行地址属于
/// 上面那张卡还是下面的卡片区。把它收进卡内做成一块内嵌条，归属就写在了结构上。
///
/// 透明度滑杆 `HomeLayer.dnsDetail` 仍然只管这一段（卡片其余部分不受影响），
/// 否则「DNS 服务详情」这根滑杆会静默失效。
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

/// 当前解析地址，内嵌在解析模式卡里。
///
/// - **单选模式**只显示当前服务商的 endpoint；
/// - **多路模式**按目录顺序列出已选服务商（与右上角候选列表同序——用插入顺序
///   会出现「先选的排前面、后选的重排」，看起来像抖动）。
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
