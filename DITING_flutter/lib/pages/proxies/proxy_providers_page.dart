/// 代理提供者页（上游 `views/proxies/providers.dart`）。
///
/// 外部提供者 = 「从某个 URL 拉一批节点」的订阅源。四项演示数据各自有更新间隔，
/// 页面提供「全部更新 / 单个更新 / 编辑」三个动作。
library;

import 'package:diting/pages/proxies/proxy_provider_form.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ProxyProvidersPage extends ConsumerWidget {
  const ProxyProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(proxyProvidersProvider);
    final notifier = ref.read(proxyProvidersProvider.notifier);
    final busy = providers.any((provider) => provider.isUpdating);

    return CommonScaffold(
      title: '代理提供者',
      primaryAction: IconButtonData(
        glyph: AppGlyphs.refresh,
        tooltip: busy ? '更新中…' : '全部更新',
        onPressed: busy ? null : notifier.updateAll,
      ),
      body: providers.isEmpty
          ? const NullStatus(
              label: '还没有外部提供者',
              description: '添加一个订阅地址，从它拉取节点',
              illustration: NullStatusIllustration.proxies,
            )
          : PageBody(
              children: [
                generateSection(
                  title: '外部提供者',
                  items: [
                    for (var i = 0; i < providers.length; i++)
                      _ProviderRow(
                        entry: providers[i],
                        onUpdate: () => notifier.update(providers[i].name),
                        onEdit: () => _edit(context, ref, i, providers[i]),
                      ),
                  ],
                  footer: '更新会按每条自己的间隔自动进行；本演示只做手动触发。',
                ),
              ],
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    int index,
    ProxyProviderEntry entry,
  ) async {
    await showExtend(
      context,
      builder: (context) => ProxyProviderForm(
        entry: entry,
        onSave: (next) =>
            ref.read(proxyProvidersProvider.notifier).save(index, next),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.entry,
    required this.onUpdate,
    required this.onEdit,
  });

  final ProxyProviderEntry entry;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      title: Text(entry.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(
              entry.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption2.of(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              entry.isUpdating
                  ? '正在更新…'
                  : '${entry.count} 个节点 · ${entry.updatedAt} · '
                        '${_intervalLabel(entry.intervalHours)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption2.of(context).copyWith(
                color: entry.isUpdating
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (entry.filter != null)
              Text(
                '过滤：${entry.filter}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.caption2.of(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          GestureDetector(
            onTap: entry.isUpdating ? null : onUpdate,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GlyphIcon(
                entry.isUpdating ? AppGlyphs.sync : AppGlyphs.cloudDownload,
                size: 18,
                color: entry.isUpdating
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GlyphIcon(
                AppGlyphs.edit,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _intervalLabel(int hours) => switch (hours) {
    0 => '不自动更新',
    24 => '每天',
    168 => '每周',
    _ when hours % 24 == 0 => '每 ${hours ~/ 24} 天',
    _ => '每 $hours 小时',
  };
}
