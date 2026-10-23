/// On-demand page (upstream `views/config/on_demand.dart`).
library;

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'on_demand_ssid_form.dart';

const _currentSsid = 'Home-5G';

class OnDemandConfigPage extends ConsumerWidget {
  const OnDemandConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(configResourcesProvider);
    final notifier = ref.read(configResourcesProvider.notifier);
    final rules = resources.ssidRules;
    return CommonScaffold(
      title: '按需连接',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加 SSID',
          onPressed: () => showSsidForm(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          generateSection(
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.wifi),
                title: const Text('启用按需连接'),
                subtitle: Text(
                  resources.onDemand
                      ? '当前连接：$_currentSsid'
                      : '关闭时 VPN 始终在线，不随网络切换',
                ),
                value: resources.onDemand,
                onChanged: notifier.setOnDemand,
              ),
            ],
            footer:
                '开启后，只有连上白名单里的 SSID 时才会自动启动 VPN；'
                '其余网络保持断开，省电也更可控。',
          ),
          if (resources.onDemand)
            generateSection(
              title: 'SSID 白名单',
              actions: [
                IconButtonData(
                  glyph: AppGlyphs.add,
                  tooltip: '添加 SSID',
                  onPressed: () => showSsidForm(context, ref),
                ),
              ],
              items: [
                if (rules.isEmpty)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.wifiOff),
                    title: const Text('还没有 SSID'),
                    subtitle: const Text('没有白名单时按需连接不会触发'),
                    onTap: () => showSsidForm(context, ref),
                  )
                else
                  for (final rule in rules)
                    ListItem(
                      leading: GlyphIcon(
                        rule.enabled ? AppGlyphs.wifi : AppGlyphs.wifiOff,
                        size: 20,
                      ),
                      title: Text(rule.ssid),
                      subtitle: Text(_ruleSummary(rule)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          ConfigRemoveButton(
                            tooltip: '编辑 ${rule.ssid}',
                            glyph: AppGlyphs.edit,
                            onPressed: () =>
                                showSsidForm(context, ref, existing: rule.ssid),
                          ),
                          ConfigRemoveButton(
                            tooltip: '删除 ${rule.ssid}',
                            onPressed: () => notifier.removeSsid(rule.ssid),
                          ),
                        ],
                      ),
                      onTap: () =>
                          showSsidForm(context, ref, existing: rule.ssid),
                    ),
              ],
              footer:
                  '延迟用于等 Wi-Fi 完成认证与 DHCP；'
                  '过早启动 VPN 会让首个请求落到尚未就绪的网络上。',
            ),
          const _PrerequisiteSection(),
        ],
      ),
    );
  }
}

String _ruleSummary(MockSsidRule rule) {
  final parts = <String>[if (rule.cellular) '蜂窝', if (rule.wifi) 'Wi-Fi'];
  final kinds = parts.isEmpty ? '不启用' : parts.join(' 与 ');
  final delay = rule.delayMs == 0 ? '立即连接' : '延迟 ${rule.delayMs} ms';
  return '$kinds · $delay';
}

/// Only the state is reported and the purpose explained, so the rows are not dead buttons.
class _PrerequisiteSection extends StatelessWidget {
  const _PrerequisiteSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return generateSection(
      title: '前置条件',
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.locate, size: 20),
          title: const Text('定位权限'),
          subtitle: const Text('Android 需要它才能读取当前 Wi-Fi 名称'),
          trailing: Text(
            '未申请',
            style: context.listCaptionStyle.copyWith(
              color: colorScheme.warning,
            ),
          ),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.bolt, size: 20),
          title: const Text('忽略电池优化'),
          subtitle: const Text('避免系统在后台冻结 VPN 进程'),
          trailing: Text(
            '未加入',
            style: context.listCaptionStyle.copyWith(
              color: colorScheme.warning,
            ),
          ),
        ),
      ],
      footer: '演示环境没有申请平台权限：真实构建里这两项会各带一个授权按钮。',
    );
  }
}