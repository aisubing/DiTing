/// 代理设置浮层（上游 `views/proxies/setting.dart`）。
///
/// 六项：呈现形式、排序、列密度、卡片尺寸、分组图标、隐藏超时。
/// 分组图标只在列表形式下有意义，所以那一行随形式说明原因而不是静默失效。
library;

import 'package:diting/data/mock_proxies.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ProxiesSettingsSheet extends ConsumerWidget {
  const ProxiesSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(proxiesSettingsProvider);
    final notifier = ref.read(proxiesSettingsProvider.notifier);
    final isList = settings.type == ProxiesType.list;

    return CommonScaffold(
      title: '代理设置',
      body: PageBody(
        children: [
          generateSection(
            title: '呈现形式',
            items: [
              ListItem<ProxiesType>.options(
                title: const Text('代理列表形式'),
                subtitle: const Text('标签页一次看一组，列表一次看全部'),
                options: ProxiesType.values,
                value: settings.type,
                textBuilder: (value) => value.label,
                onChanged: notifier.setType,
              ),
              ListItem<ProxiesSortType>.options(
                title: const Text('排序'),
                subtitle: const Text('按延迟排序时未测速与超时沉底'),
                options: ProxiesSortType.values,
                value: settings.sortType,
                textBuilder: (value) => value.label,
                onChanged: notifier.setSortType,
              ),
            ],
          ),
          generateSection(
            title: '外观',
            items: [
              ListItem<ProxiesLayout>.options(
                title: const Text('列密度'),
                subtitle: const Text('影响分组标签之间的间距'),
                options: ProxiesLayout.values,
                value: settings.layout,
                textBuilder: (value) => value.label,
                onChanged: notifier.setLayout,
              ),
              ListItem<ProxyCardType>.options(
                title: const Text('卡片尺寸'),
                subtitle: const Text('影响节点的行高与每行列数'),
                options: ProxyCardType.values,
                value: settings.cardType,
                textBuilder: (value) => value.label,
                onChanged: notifier.setCardType,
              ),
              ListItem<ProxiesIconStyle>.options(
                title: const Text('分组图标'),
                subtitle: Text(
                  isList
                      ? '仅在列表形式下显示'
                      : '仅在列表形式下显示；当前是标签页形式，所以看不到变化',
                ),
                options: ProxiesIconStyle.values,
                value: settings.iconStyle,
                textBuilder: (value) => value.label,
                onChanged: notifier.setIconStyle,
              ),
            ],
          ),
          generateSection(
            title: '过滤',
            items: [
              ListItem.toggle(
                title: const Text('隐藏超时节点'),
                subtitle: const Text('测速超时的节点不在列表里显示'),
                value: settings.hideTimeoutProxies,
                onChanged: notifier.setHideTimeoutProxies,
              ),
            ],
            footer: '隐藏只影响显示；节点仍在配置里可用。',
          ),
        ],
      ),
    );
  }
}
