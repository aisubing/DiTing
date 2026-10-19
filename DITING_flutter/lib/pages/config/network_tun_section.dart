part of 'network_page.dart';

/// TUN 段：开关 + 栈 + MTU + 拥塞控制 + 路由网段。
///
/// 上层 VPN 关闭时整段置灰而不是隐藏：TUN 是 VPN 的实现方式，用户需要看到
/// 「它存在、但现在不生效」，隐藏会让人以为 TUN 被移除了。
class TunConfigSection extends ConsumerWidget {
  const TunConfigSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkConfigProvider);
    final notifier = ref.read(networkConfigProvider.notifier);
    final active = network.vpnEnable;
    final tunOn = active && network.tunEnable;
    final isMips = network.tunStack == TunStack.mips;
    return generateSection(
      title: 'TUN',
      items: [
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.layers),
          title: const Text('启用 TUN'),
          subtitle: const Text('用虚拟网卡接管全部流量，兼容性最好'),
          value: tunOn,
          onChanged: active ? notifier.setTunEnable : null,
        ),
        ListItem<TunStack>.options(
          leading: const GlyphIcon(AppGlyphs.cpu),
          title: const Text('协议栈'),
          subtitle: Text(network.tunStack.description),
          options: TunStack.values,
          value: network.tunStack,
          textBuilder: (stack) => stack.label,
          onChanged: tunOn ? notifier.setTunStack : (stack) {},
        ),
        ListItem.input(
          leading: const GlyphIcon(AppGlyphs.memory),
          title: const Text('MTU'),
          subtitle: Text('${network.mtu} 字节'),
          dialogTitle: 'MTU',
          value: '${network.mtu}',
          keyboardType: TextInputType.number,
          maxLength: TextInputLimits.number,
          resetValue: '1500',
          validator: (value) {
            final mtu = int.tryParse((value ?? '').trim());
            if (mtu == null) {
              return 'MTU 必须是数字';
            }
            if (mtu < minTunMtu || mtu > maxTunMtu) {
              return 'MTU 需在 $minTunMtu–$maxTunMtu 之间';
            }
            return null;
          },
          onChanged: (value) {
            final mtu = int.tryParse((value ?? '').trim());
            if (mtu == null) {
              return;
            }
            if (mtu < minTunMtu || mtu > maxTunMtu) {
              showConfigHint(context, 'MTU 需在 $minTunMtu–$maxTunMtu 之间');
              return;
            }
            notifier.setMtu(mtu);
          },
        ),
        ListItem<String>.options(
          leading: const GlyphIcon(AppGlyphs.speed),
          title: const Text('拥塞控制'),
          subtitle: Text(isMips ? '仅 mips 栈读取这一项' : '当前栈不读取这一项，切换到 mips 才生效'),
          options: mockCongestionControllers,
          value:
              mockCongestionControllers.contains(network.congestionController)
              ? network.congestionController
              : mockCongestionControllers.first,
          textBuilder: (controller) => controller,
          onChanged: isMips ? notifier.setCongestionController : (_) {},
        ),
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.split),
          title: const Text('绕过私有网段'),
          subtitle: const Text('局域网与链路本地地址不进 TUN'),
          value: network.bypassPrivateRoute,
          onChanged: tunOn ? notifier.setBypassPrivateRoute : null,
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.target),
          title: const Text('路由网段'),
          subtitle: Text(
            '${configListSummary(network.routeAddress)}，决定哪些地址走 TUN',
          ),
          trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
          onTap: tunOn
              ? () => showNetworkStringListSheet(
                  context,
                  NetworkStringList.routeAddress,
                )
              : null,
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.block),
          title: const Text('排除网段'),
          subtitle: Text(
            '${configListSummary(network.routeExcludeAddress)}，永远不走 TUN',
          ),
          trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
          onTap: tunOn
              ? () => showNetworkStringListSheet(
                  context,
                  NetworkStringList.routeExcludeAddress,
                )
              : null,
        ),
      ],
      footer:
          'MTU 建议保持 1500；链路本身有额外封装时才需要下调，'
          '调得过低会明显掉速。',
    );
  }
}
