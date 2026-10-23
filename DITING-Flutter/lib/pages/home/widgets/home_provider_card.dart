import 'package:diting/routes/routes.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The sheet keeps the active provider even after it left the catalog.
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
        // The sheet title floats over the body, so this top padding is required.
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
          // Two action items share the list and position with the providers. Close the
          // sheet before pushing, otherwise returning shows it again and looks stuck.
          ListItem(
            leading: const GlyphIcon(AppGlyphs.settings, size: 20),
            title: const Text('管理服务...'),
            trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
            onTap: () {
              Navigator.of(context).pop();
              context.push(HubPaths.providerManagement);
            },
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.eye, size: 20),
            title: const Text('服务显示...'),
            trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
            onTap: () {
              Navigator.of(context).pop();
              context.push(HubPaths.providerVisibility);
            },
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