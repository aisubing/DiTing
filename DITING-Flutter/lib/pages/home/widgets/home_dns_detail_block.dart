import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首页固定块「DNS 服务详情」。
///
/// 对应 1.4.3 `MainScreenContent.kt` 里 `dnsDetailOpacity` 管的那一块：
/// - **单选模式**（`SINGLE`）只显示当前服务商的 endpoint 一行文字；
/// - **多路模式**（智能 / 竞速 / 主备）显示已选服务商的地址列表
///   （旧版 `ProviderEndpointList`：一行一个 endpoint，居中排列）。
///
/// 旧版这两块都是**纯文字**、没有任何卡片外框——它就贴在解析模式按钮下面。
/// 这里同样不加 `CommonCard`：加了会与上面的服务商卡、下面的卡片区形成三层
/// 同宽的圆角块，视觉上分不清哪一层是「固定区」。
class HomeDnsDetailBlock extends ConsumerWidget {
  const HomeDnsDetailBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);

    if (resolution.isSingle) {
      return Text(
        endpointOfProvider(selectedId, catalog),
        textAlign: TextAlign.center,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 多路模式：按目录顺序列出已选的 endpoint，与右上角候选列表同序——
    // 用 `raceIds` 的插入顺序会出现「先选的排前面、后选的重排」，看起来像抖动。
    final endpoints = [
      for (final provider in catalog)
        if (raceIds.contains(provider.id))
          '${provider.protocol.label} · ${provider.address}',
    ];
    if (endpoints.isEmpty) {
      return Text('未选择服务商', textAlign: TextAlign.center, style: style);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final endpoint in endpoints)
          Text(
            endpoint,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }
}
