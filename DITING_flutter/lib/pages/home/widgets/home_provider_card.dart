import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首页的服务商选择卡。
///
/// 单选模式显示当前服务商与地址，竞速模式显示「已选 N 个」摘要；点开只读浮层
/// 选。候选目录来自旧版 prefs（预设 + `user_providers_json`），再按「服务显示」
/// 的三组过滤条件剔除；当前选中的服务商永远保留，否则用户会看不到自己正在用
/// 的那一项。
class HomeProviderCard extends ConsumerWidget {
  const HomeProviderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final subtitle = resolution.isSingle
        ? endpointOfProvider(selectedId, catalog)
        : summaryOfProviders(raceIds, catalog);
    void open() => showSheet<void>(
      context: context,
      builder: (_) => const _ProviderSheet(),
    );
    return CommonCard(
      onPressed: open,
      child: ListItem(
        leading: const GlyphIcon(AppGlyphs.dns),
        title: Text(resolution.isSingle ? '解析服务商' : '竞速服务商'),
        subtitle: Text(subtitle),
        trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
        onTap: open,
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
    final visible = ref.watch(visibleProvidersProvider);
    return CommonScaffold(
      title: resolution.isSingle ? '选择解析服务商' : '选择竞速服务商',
      body: ListView(
        // 浮层标题浮在正文之上，不预留这段留白首行（「可选服务商」）就被
        // 标题压住。
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          ListHeader(title: resolution.isSingle ? '可选服务商' : '至少选 2 个'),
          for (final provider in visible)
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
                            providerLatencyLabel(provider),
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
                ? '延迟取自上一次解析的健康记录，不是实时值。'
                : '竞速模式下每个查询会并发发往所有选中服务商。',
          ),
        ],
      ),
    );
  }
}
