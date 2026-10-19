import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 拨号器页（上游 `views/profiles/custom/dialers.dart`，158 行）。
///
/// 上游是一张「节点 → 中转目标」的映射表：每个节点最多一个 dialer。这里按同样
/// 语义做成列表——每行是一个节点，右侧是它当前的中转目标（或「直连」）。
///
/// 用「每个节点一行」而不是「每条拨号规则一行」：反向列出来更直观（能立刻看到
/// 哪些节点还没被中转），而空状态也自然落在「所有节点都直连」上。
class CustomDialersPage extends ConsumerWidget {
  const CustomDialersPage({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxies = ref.watch(customProxiesProvider);
    final groups = ref.watch(proxyGroupsProvider);
    final dialers = ref.watch(dialersProvider);
    final targets = [
      for (final group in groups) group.name,
      for (final proxy in proxies) proxy.name,
    ];
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '拨号器',
      body: NullStatusSwitcher(
        isEmpty: proxies.isEmpty,
        nullStatus: const NullStatus(
          label: '还没有节点',
          description: '先添加节点，才能给它们指定中转',
          illustration: NullStatusIllustration.proxies,
        ),
        child: PageBody(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '给节点指定中转后，它的流量会先经过中转节点再发出，用来让某个出口'
                '「借道」另一条线路。',
                style: context.listCaptionStyle,
              ),
            ),
            const SizedBox(height: 16),
            generateSection(
              title: '节点与中转',
              items: [
                for (final proxy in proxies)
                  ListItem(
                    leading: GlyphIcon(
                      dialers.containsKey(proxy.name)
                          ? AppGlyphs.link
                          : AppGlyphs.target,
                      color: dialers.containsKey(proxy.name)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(proxy.name),
                    subtitle: Text(
                      dialers[proxy.name] ?? '直连，不经过中转',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle.copyWith(
                        color: dialers.containsKey(proxy.name)
                            ? colorScheme.primary
                            : null,
                      ),
                    ),
                    trailing: CommonPopupBox(
                      targetBuilder: (open) => IconButton(
                        tooltip: UiLocalizations.of(context).more,
                        onPressed: open,
                        icon: const GlyphIcon(AppGlyphs.more),
                      ),
                      popupBuilder: (_) => CommonPopupMenu(
                        items: [
                          CommonPopupMenuItem(
                            label: '不中转（直连）',
                            glyph: AppGlyphs.target,
                            checked: !dialers.containsKey(proxy.name),
                            onPressed: () => ref
                                .read(dialersProvider.notifier)
                                .set(proxy.name, null),
                          ),
                          for (final target in targets)
                            if (target != proxy.name)
                              CommonPopupMenuItem(
                                label: target,
                                glyph: AppGlyphs.link,
                                checked: dialers[proxy.name] == target,
                                onPressed: () => ref
                                    .read(dialersProvider.notifier)
                                    .set(proxy.name, target),
                              ),
                        ],
                      ),
                    ),
                  ),
              ],
              footer: '中转目标可以是另一个节点，也可以是组；不能指向自己。',
            ),
            if (dialers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(
                  '当前有 ${dialers.length} 个节点经过中转。',
                  style: context.listCaptionStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
