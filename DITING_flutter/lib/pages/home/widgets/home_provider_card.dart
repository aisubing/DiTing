import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首页的服务商选择卡。
///
/// 单选模式显示当前服务商与地址，竞速模式显示「已选 N 个」摘要；点开只读浮层
/// 选。上游把这段放在 `home.dart` 里；这里拆出来是为了让首页本体只做排版。
class HomeProviderCard extends ConsumerWidget {
  const HomeProviderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final subtitle = resolution.isSingle
        ? providerEndpointOf(selectedId)
        : raceProviderSummary(raceIds);
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
