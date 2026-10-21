import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/server/server_actions.dart';
import 'package:diting/router.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/server_upstream_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 服务器模式「概览」Tab（上游 `server/ui/DnsHomeScreen.kt`，221 行）。
///
/// 上游这一屏是 LazyColumn 六个 item：电源 + 状态文字 / 当前上游 / 局域网接入 /
/// 服务状态五项 / 底部说明。这里逐项对应，另把「切换工作模式」放回顶栏——它是
/// 进这个模式的唯一出口，旧版同样把它放在概览页的 `actions` 里。
///
/// 状态源是 `serverStatusProvider`（五态）而不是首页的 `powerProvider`：两者
/// 状态机相同但生命周期不同，服务器模式没有「启动失败」的自动复位语义。
class ServerOverviewPage extends ConsumerWidget {
  const ServerOverviewPage({
    super.key,
    required this.onOpenUpstreams,
    required this.onOpenSettings,
  });

  /// 跳到同壳的另外两个 Tab（上游 `onNavigateToServers`）。
  final VoidCallback onOpenUpstreams;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider);
    final port = ref.watch(serverPortProvider);
    final stats = ref.watch(serviceStatsProvider);
    final upstream = ref.watch(serverSelectedUpstreamProvider);
    final network = ref.watch(networkInfoProvider);
    final running = status == ServerStatus.running;
    final localIpv4 = network.asData?.value.localIpv4 ?? '';
    return CommonScaffold(
      title: '谛听 · 服务器模式',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.swap,
          tooltip: '切换工作模式',
          onPressed: () => context.push(Routes.modeSelect),
        ),
        IconButtonData(
          glyph: AppGlyphs.sliders,
          tooltip: '修改监听端口',
          onPressed: () => editServerPort(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          _PowerArea(status: status, port: port),
          _StatusText(status: status),
          const SizedBox(height: 8),
          generateSection(
            title: '当前上游',
            items: [
              ListItem(
                title: Text(upstream.name),
                subtitle: Text(upstream.endpointLabel),
                leading: const GlyphIcon(AppGlyphs.dns),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: onOpenUpstreams,
              ),
            ],
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '局域网接入',
            // 端口只在启动时绑定：改完端口不重启，界面上的地址就是一个没人
            // 监听的端口，局域网里的设备会直接超时。
            footer:
                '把同网段设备的 DNS 指向上面这个地址即可；'
                '端口只在启动时绑定，改动后需要重启服务。',
            items: [
              ListItem(
                title: Text(
                  localIpv4.isEmpty ? '未连接网络' : '$localIpv4:$port',
                  style: context.listTitleStyle.copyWith(
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                subtitle: Text(
                  localIpv4.isEmpty
                      ? '连上 Wi-Fi 或以太网后这里会显示可用地址'
                      : '将局域网其他设备的 DNS 指向此地址',
                ),
                leading: GlyphIcon(
                  localIpv4.isEmpty ? AppGlyphs.wifiOff : AppGlyphs.wifi,
                ),
                trailing: localIpv4.isEmpty
                    ? null
                    : GlyphIcon(
                        AppGlyphs.copy,
                        color: context.colorScheme.primary,
                      ),
                onTap: localIpv4.isEmpty
                    ? null
                    : () async {
                        // 真的写剪贴板再提示：只弹「已复制」而不写，用户会拿着
                        // 空剪贴板去配置另一台设备。
                        final address = '$localIpv4:$port';
                        await Clipboard.setData(ClipboardData(text: address));
                        if (!context.mounted) {
                          return;
                        }
                        showServerHint(context, '已复制 $address');
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const ListHeader(title: '服务状态'),
          // 统计条直接放在 `PageBody` 里（不经 `generateSection` 包一层），
          // 横向留白得自己给，否则数字两端贴住屏幕边沿。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CommonCard(
              padding: EdgeInsets.zero,
              child: StatStrip(
                stats: [
                  StatItem(label: '总查询量', value: '${stats.queries}'),
                  StatItem(
                    label: '缓存命中',
                    value: '${stats.cacheHits}',
                    color: context.colorScheme.primary,
                  ),
                  StatItem(
                    label: '已拦截',
                    value: '${stats.blocked}',
                    color: context.colorScheme.error,
                  ),
                  const StatItem(
                    label: '平均时延',
                    // 旧版这一格读 `DnsModeStats.latencyMs`；迁移后原生状态快照
                    // （`EngineStats.snapshot`）没有这个字段，所以固定显示破折号，
                    // 不拿 0 或 mock 数字顶上——那会让用户以为服务「很快」。
                    value: '--',
                    unit: 'ms',
                  ),
                  StatItem(
                    label: '运行时长',
                    value: running ? stats.uptimeLabel : '--',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          generateSection(
            items: [
              ListItem(
                title: const Text('重置运行统计'),
                subtitle: const Text('清空本次运行的全部计数，不清规则与缓存'),
                leading: const GlyphIcon(AppGlyphs.reset),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => confirmResetServerStats(context, ref),
              ),
              ListItem(
                title: const Text('模式设置'),
                subtitle: const Text('缓存、规则、后台稳定性与运行模式'),
                leading: const GlyphIcon(AppGlyphs.settings),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: onOpenSettings,
              ),
            ],
          ),
          const ListFooter(
            text:
                '服务器模式不建立 VPN 隧道：它只在本机监听 DNS 端口，'
                '因此可以与其它 VPN 共存，也不占用系统的 VPN 槽位；'
                '本机应用的查询不会自动经过该服务。',
          ),
        ],
      ),
    );
  }
}

/// 电源区：复用首页的 [HomePowerButton]，只覆写两个文案。
///
/// 状态映射是必须的：`PowerState` 与 `ServerStatus` 都是五态，但语义标签不同
/// （前者「启动失败」、后者「异常」）。直接传字符串会绕过类型检查，所以这里显式
/// switch，编译期就能发现新增状态。
class _PowerArea extends ConsumerWidget {
  const _PowerArea({required this.status, required this.port});

  final ServerStatus status;
  final int port;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        status == ServerStatus.starting || status == ServerStatus.stopping;
    return Column(
      children: [
        const SizedBox(height: 4),
        HomePowerButton(
          state: _powerStateOf(status),
          busyLabel: busy ? '启动中' : '停止中',
          runningLabel: '停止',
          stoppedLabel: '开启',
          onPressed: () => ref.read(serverStatusProvider.notifier).toggle(),
        ),
        Text(
          '监听 0.0.0.0:$port',
          style: context.listCaptionStyle.copyWith(fontFamily: 'JetBrainsMono'),
        ),
      ],
    );
  }

  static PowerState _powerStateOf(ServerStatus status) => switch (status) {
    ServerStatus.stopped => PowerState.stopped,
    ServerStatus.starting => PowerState.starting,
    ServerStatus.running => PowerState.running,
    ServerStatus.stopping => PowerState.stopping,
    ServerStatus.error => PowerState.error,
  };
}

/// 五态状态文案：颜色与措辞都跟着状态走。
///
/// 单独一行而不是塞进按钮：按钮只表达「能不能点」，出问题时用户需要一句能读的
/// 结论，红色是第二层信号。
class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});

  final ServerStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (text, color) = switch (status) {
      ServerStatus.stopped => ('服务器模式已停止', colorScheme.onSurfaceVariant),
      ServerStatus.starting => ('正在启动服务...', colorScheme.primary),
      ServerStatus.running => ('服务器模式运行中', colorScheme.primary),
      ServerStatus.stopping => ('正在停止服务...', colorScheme.onSurfaceVariant),
      ServerStatus.error => ('服务异常：端口可能已被占用', colorScheme.error),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyle.subheadline
            .of(context, emphasized: true)
            .copyWith(color: color),
      ),
    );
  }
}
