import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/router.dart';
import 'package:diting/state/server_upstream_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 服务器模式概览页（上游 `server/ui/DnsHomeScreen.kt`，221 行）。
///
/// 上游这一屏是 LazyColumn 六个 item：电源 + 五态状态文字 / 当前上游 /
/// 局域网接入 / 服务状态五项 / 底部说明。这里逐项对应，但把「设置区」也
/// 并进来——上游设置是同一 pager 的第三页，演示层没有那个 pager，分开做会
/// 让「端口」这种最常改的项藏在两级之后。
///
/// 状态源是 `serverStatusProvider`（五态）而不是首页的 `powerProvider`：两者
/// 状态机相同但生命周期不同，服务器模式没有「启动失败」的自动复位语义。
class ServerPage extends ConsumerWidget {
  const ServerPage({super.key});

  /// 监听地址。上游只展示 IPv4（引擎虽绑 `[::]`，界面不列 IPv6）。
  static const _lanAddresses = <String>['192.168.1.42', '10.0.0.42'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider);
    final port = ref.watch(serverPortProvider);
    final stats = ref.watch(serviceStatsProvider);
    final upstream = ref.watch(serverSelectedUpstreamProvider);
    final running = status == ServerStatus.running;
    return CommonScaffold(
      title: '谛听 · 服务器',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.swap,
          tooltip: '切换工作模式',
          onPressed: () => context.push(Routes.modeSelect),
        ),
        IconButtonData(
          glyph: AppGlyphs.sliders,
          tooltip: '修改监听端口',
          onPressed: () => _editPort(context, ref, port),
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
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: () => _pickUpstream(context, ref, upstream.id),
              ),
            ],
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '局域网接入',
            footer: '把同网段设备的 DNS 指向上面任一地址即可；'
                '端口只在启动时绑定，改动后需要重启服务。',
            items: [
              for (final address in _lanAddresses)
                ListItem(
                  title: Text(
                    '$address:$port',
                    style: context.listTitleStyle.copyWith(
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  subtitle: Text(address == _lanAddresses.first ? 'Wi-Fi' : '以太网'),
                  leading: const GlyphIcon(AppGlyphs.wifi),
                  trailing: GlyphIcon(
                    AppGlyphs.copy,
                    color: context.colorScheme.primary,
                  ),
                  onTap: () => _toast(context, '已复制 $address:$port'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const ListHeader(title: '服务状态'),
          // 这张卡直接放在 `PageBody` 里（不像别处由 `generateSection` 包一层），
          // 横向留白得自己给，否则统计条两端贴住屏幕边沿。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CommonCard(
              padding: EdgeInsets.zero,
              child: StatStrip(
                stats: [
                  StatItem(label: '总查询', value: '${stats.queries}'),
                  StatItem(
                    label: '缓存命中',
                    value: '${(stats.cacheHitRate * 100).round()}',
                    unit: '%',
                    color: context.colorScheme.primary,
                  ),
                  StatItem(
                    label: '已拦截',
                    value: '${stats.blocked}',
                    color: context.colorScheme.error,
                  ),
                  StatItem(
                    label: '平均时延',
                    value: running ? '${stats.averageLatencyMs}' : '--',
                    unit: running ? 'ms' : null,
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
            title: '设置',
            items: [
              ListItem(
                title: const Text('本地监听端口'),
                subtitle: const Text('范围 1024–65535，默认 1053'),
                leading: const GlyphIcon(AppGlyphs.speed),
                trailing: Text(
                  '$port',
                  style: context.listSubtitleStyle.copyWith(
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                onTap: () => _editPort(context, ref, port),
              ),
              _ServerToggleRow(
                title: 'DNS 缓存',
                onSubtitle: '命中缓存的查询不再向上游发起',
                offSubtitle: '已关闭 · 每次解析都请求上游',
                glyph: AppGlyphs.memory,
                valueOf: (settings) => settings.serverCacheEnabled,
                onChanged: (settings, value) =>
                    settings.setServerCacheEnabled(value),
              ),
              _ServerToggleRow(
                title: '广告拦截',
                onSubtitle: '按服务器模式的独立规则库拦截域名',
                offSubtitle: '已关闭 · 仅解析与缓存，不做规则拦截',
                glyph: AppGlyphs.rules,
                valueOf: (settings) => settings.serverAdBlockEnabled,
                onChanged: (settings, value) =>
                    settings.setServerAdBlockEnabled(value),
              ),
              ListItem(
                title: const Text('规则控制'),
                subtitle: const Text('使用服务器模式独立规则库，编辑入口稍后接入'),
                leading: const GlyphIcon(AppGlyphs.rules),
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: () => _toast(context, '服务器模式规则编辑页尚未接入'),
              ),
              ListItem(
                title: const Text('重置运行统计'),
                subtitle: const Text('清空本次运行的全部计数，不清规则与缓存'),
                leading: const GlyphIcon(AppGlyphs.reset),
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: () {
                  ref.read(serviceStatsProvider.notifier).reset();
                  _toast(context, '运行统计已重置');
                },
              ),
            ],
          ),
          const ListFooter(
            text: '服务器模式不建立 VPN 隧道：它只在本机监听 DNS 端口，'
                '因此可以与其它 VPN 共存，也不占用系统的 VPN 槽位。',
          ),
        ],
      ),
    );
  }
}

/// 电源区：复用首页的 [HomePowerButton]，只覆写两个文案。
///
/// 状态映射是必须的：`PowerState` 与 `ServerStatus` 都是五态，但语义标签
/// 不同（前者「启动失败」、后者「异常」）。直接传字符串会绕过类型检查，
/// 所以这里显式 switch，编译期就能发现新增状态。
class _PowerArea extends ConsumerWidget {
  const _PowerArea({required this.status, required this.port});

  final ServerStatus status;
  final int port;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = status == ServerStatus.starting || status == ServerStatus.stopping;
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
/// 单独一行而不是塞进按钮：按钮只表达「能不能点」，出问题时用户需要一句
/// 能读的结论，红色是第二层信号。
class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});

  final ServerStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (text, color) = switch (status) {
      ServerStatus.stopped => ('服务器模式已停止', colorScheme.onSurfaceVariant),
      ServerStatus.starting => ('正在启动服务…', colorScheme.primary),
      ServerStatus.running => ('运行中，局域网内可直接使用', colorScheme.primary),
      ServerStatus.stopping => ('正在停止服务…', colorScheme.onSurfaceVariant),
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

/// 服务器模式的两个主开关直接写 `diting_dns_mode_prefs`；它们只在下次启动
/// 时被引擎读取，界面不假装已经生效。
class _ServerToggleRow extends ConsumerWidget {
  const _ServerToggleRow({
    required this.title,
    required this.onSubtitle,
    required this.offSubtitle,
    required this.glyph,
    required this.valueOf,
    required this.onChanged,
  });

  final String title;
  final String onSubtitle;
  final String offSubtitle;
  final Glyph glyph;
  final bool Function(LegacySettings settings) valueOf;
  final void Function(LegacySettings settings, bool value) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final enabled = valueOf(settings);
    return ListItem.toggle(
      title: Text(title),
      subtitle: Text(enabled ? onSubtitle : offSubtitle),
      leading: GlyphIcon(glyph),
      value: enabled,
      onChanged: (value) => onChanged(settings, value),
    );
  }
}

/// 选择上游服务商。
///
/// 服务器模式只有「一家上游」的概念（多路竞速属于普通 / 极速模式），所以这里
/// 是单选而不是勾选集合；用底部抽屉而不是整页：候选只有六条，抽屉一屏就够，
/// 整页会把「当前上游」这个只读信息变成一次跳转。
Future<void> _pickUpstream(
  BuildContext context,
  WidgetRef ref,
  String currentId,
) {
  return showSheet<void>(
    context: context,
    builder: (sheetContext) => CommonScaffold(
      title: '当前上游',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          generateSection(
            footer: '服务器模式只用一家上游；需要多路竞速请切到普通或极速模式。',
            items: [
              for (final upstream in ref.read(serverUpstreamListProvider))
                ListItem(
                  title: Text(upstream.name),
                  subtitle: Text(upstream.endpointLabel),
                  leading: const GlyphIcon(AppGlyphs.proxies),
                  trailing: upstream.id == currentId
                      ? const SelectionCheck()
                      : const SizedBox(width: SelectionCheck.size),
                  onTap: () {
                    ref
                        .read(serverSelectedUpstreamProvider.notifier)
                        .select(upstream.id);
                    sheetContext.safeNestedPop();
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 端口编辑对话框。
///
/// 用 `showFloatingDialog` + [InputDialog] 而不是 `ListItem.input`：后者的
/// 校验器拿不到「范围提示」这个上下文，而端口是唯一需要把合法区间写进
/// 错误文案的项。校验放在 `validator` 里，非法时对话框不关闭。
Future<void> _editPort(BuildContext context, WidgetRef ref, int port) async {
  final result = await showFloatingDialog<String>(
    context: Navigator.of(context, rootNavigator: true).context,
    child: InputDialog(
      title: '本地监听端口',
      value: '$port',
      suffixText: '',
      hintText: '1024–65535',
      keyboardType: TextInputType.number,
      maxLength: 5,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null) {
          return '请输入数字';
        }
        if (parsed < 1024 || parsed > 65535) {
          return '范围 1024–65535';
        }
        return null;
      },
    ),
  );
  final parsed = int.tryParse(result?.trim() ?? '');
  if (parsed == null) {
    return;
  }
  ref.read(serverPortProvider.notifier).set(parsed);
  if (context.mounted) {
    _toast(context, '端口已改为 $parsed，重启服务后生效');
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ),
  );
}
