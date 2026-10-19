part of 'network_page.dart';

/// 出站与接口选项（上游 `NetworkOptionsSection` + `outboundItems`）。
///
/// 接口名相关项在 Android 上无效——上游的 `DefaultSocketHook` 会忽略
/// `interface-name`——但演示层保留它们并把无效原因写在副标题里：让读者看到
/// 这些键确实存在、以及在什么平台上才有意义。
class NetworkOptionsSection extends ConsumerWidget {
  const NetworkOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkConfigProvider);
    final notifier = ref.read(networkConfigProvider.notifier);
    final customInterface =
        network.interfaceNameMode == InterfaceNameMode.custom;
    return Column(
      children: [
        generateSection(
          title: '接口',
          items: [
            ListItem<InterfaceNameMode>.options(
              leading: const GlyphIcon(AppGlyphs.devices),
              title: const Text('接口名模式'),
              subtitle: Text(network.interfaceNameMode.description),
              options: InterfaceNameMode.values,
              value: network.interfaceNameMode,
              textBuilder: (mode) => mode.label,
              onChanged: notifier.setInterfaceNameMode,
            ),
            if (customInterface)
              ListItem.input(
                leading: const GlyphIcon(AppGlyphs.edit),
                title: const Text('接口名'),
                subtitle: Text(network.interfaceName),
                dialogTitle: '接口名',
                value: network.interfaceName,
                maxLength: TextInputLimits.name,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? '接口名不能为空' : null,
                onChanged: (value) => notifier.setInterfaceName(value ?? ''),
              ),
          ],
          footer: '接口名只在桌面端生效：Android 的套接字钩子会忽略这一项。',
        ),
        generateSection(
          title: '系统',
          items: [
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.toggle),
              title: const Text('系统代理'),
              subtitle: const Text('桌面端能力；Android 由 VPN 接管，无需此项'),
              // 移动端没有系统代理开关，恒为 false 且不可操作，
              // 但保留这一行以说明「这个键存在」。
              value: false,
              onChanged: null,
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.clock),
              title: const Text('保持连接存活'),
              subtitle: const Text('关闭后内核会周期性探测空闲连接'),
              value: !network.disableKeepAlive,
              onChanged: (value) => notifier.setDisableKeepAlive(!value),
            ),
            DisabledMask(
              status: network.disableKeepAlive,
              child: Column(
                children: [
                  ListItem.input(
                    leading: const GlyphIcon(AppGlyphs.clock),
                    title: const Text('探测间隔'),
                    subtitle: Text('${network.keepAliveInterval} 秒'),
                    dialogTitle: '探测间隔（秒）',
                    value: '${network.keepAliveInterval}',
                    keyboardType: TextInputType.number,
                    maxLength: TextInputLimits.interval,
                    onChanged: (value) {
                      final seconds = int.tryParse((value ?? '').trim());
                      if (seconds == null || seconds <= 0) {
                        return;
                      }
                      notifier.setKeepAliveInterval(seconds);
                    },
                  ),
                  ListItem.input(
                    leading: const GlyphIcon(AppGlyphs.clock),
                    title: const Text('空闲阈值'),
                    subtitle: Text('${network.keepAliveIdle} 秒'),
                    dialogTitle: '空闲阈值（秒）',
                    value: '${network.keepAliveIdle}',
                    keyboardType: TextInputType.number,
                    maxLength: TextInputLimits.interval,
                    onChanged: (value) {
                      final seconds = int.tryParse((value ?? '').trim());
                      if (seconds == null || seconds <= 0) {
                        return;
                      }
                      notifier.setKeepAliveIdle(seconds);
                    },
                  ),
                ],
              ),
            ),
          ],
          footer: '存活探测能更快发现断掉的连接，代价是少量常驻流量。',
        ),
      ],
    );
  }
}
