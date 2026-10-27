import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/server/server_actions.dart';
import 'package:diting/router.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/server_upstream_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/nav_entry_row.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Server mode "overview" tab (upstream `server/ui/DnsHomeScreen.kt`): power plus status text,
/// current upstream, LAN access, service stats and a footer, all from `serverStatusProvider`.
class ServerOverviewPage extends ConsumerWidget {
  const ServerOverviewPage({
    super.key,
    required this.onOpenUpstreams,
    required this.onOpenSettings,
  });

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
              NavEntryRow(
                glyph: AppGlyphs.dns,
                title: upstream.name,
                subtitle: upstream.endpointLabel,
                onPressed: onOpenUpstreams,
              ),
            ],
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '局域网接入',
            // The port binds at startup only: changing it without a restart shows an
            // address nobody listens on and LAN devices time out.
            footer:
                '把同网段设备的 DNS 指向上面这个地址即可；'
                '端口只在启动时绑定，改动后需要重启服务。',
            items: [
              ListItem(
                title: Text(
                  localIpv4.isEmpty ? '未连接网络' : '$localIpv4:$port',
                  style: context.listTitleStyle.copyWith(
                    fontFamily: appMonospaceFontFamily,
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
                        // Write the clipboard before reporting: a bare "copied" leaves the
                        // user with an empty clipboard.
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
          // The stat strip sits directly in `PageBody` without `generateSection`, so it
          // supplies its own horizontal padding.
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
                    // The legacy version read `DnsModeStats.latencyMs`, which
                    // `EngineStats.snapshot` lacks, so this
                    // shows a dash rather than 0 or a mock number.
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
              NavEntryRow(
                glyph: AppGlyphs.reset,
                title: '重置运行统计',
                subtitle: '清空本次运行的全部计数，不清规则与缓存',
                onPressed: () => confirmResetServerStats(context, ref),
              ),
              NavEntryRow(
                glyph: AppGlyphs.settings,
                title: '模式设置',
                subtitle: '缓存、规则、后台稳定性与运行模式',
                onPressed: onOpenSettings,
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

/// Power area reusing [HomePowerButton] with two overridden labels. The explicit switch is
/// required: `PowerState` and `ServerStatus` both have five states with different labels.
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
          style: context.listCaptionStyle.copyWith(
            fontFamily: appMonospaceFontFamily,
          ),
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

/// Five-state status text; colour and wording follow the state. A separate line because the
/// button only conveys "tappable" and a failure needs a readable sentence.
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
