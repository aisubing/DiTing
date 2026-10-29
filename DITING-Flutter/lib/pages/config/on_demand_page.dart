/// On-demand page (upstream `views/config/on_demand.dart`).
library;

import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/pages/config/on_demand_capabilities.dart';
import 'package:diting/pages/server/server_platform_probe.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/state/on_demand_runner.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'on_demand_ssid_form.dart';

class OnDemandConfigPage extends ConsumerWidget {
  const OnDemandConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(configResourcesProvider);
    final notifier = ref.read(configResourcesProvider.notifier);
    final rules = resources.ssidRules;
    final decision = ref.watch(onDemandDecisionProvider);
    return CommonScaffold(
      title: '按需连接',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '立即应用',
          onPressed: () => _applyNow(context, ref),
        ),
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
                      ? _decisionSummary(decision)
                      : '关闭时 VPN 始终在线，不随网络切换',
                ),
                value: resources.onDemand,
                onChanged: (value) => _setEnabled(context, ref, value),
              ),
            ],
            footer:
                '开启后，只有连上白名单里的 SSID 时才会自动启动 VPN；'
                '其余网络保持断开，省电也更可控。自动判定只在网络'
                '变化时启停 VPN，不会覆盖手动开关的结果；点右上角'
                '「立即应用」可立即按当前网络重新判定。',
          ),
          if (resources.onDemand) _DecisionCard(decision: decision),
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
          const _NetworkSection(),
          const _BatterySection(),
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

/// One line for the switch's subtitle, so the current outcome is visible without opening a page.
String _decisionSummary(SsidDecision decision) => switch (decision.state) {
  SsidMatchState.disabled => '按需连接已关闭',
  SsidMatchState.unknown => '无法读取当前 Wi-Fi，白名单不会触发',
  SsidMatchState.noWifi => '当前不在 Wi-Fi 上，VPN 保持断开',
  SsidMatchState.matched => '已匹配 ${decision.rule?.ssid ?? ''}，VPN 会自动启动',
  SsidMatchState.unmatched => '当前 Wi-Fi 不在白名单，VPN 保持断开',
};

/// Turns the switch on and immediately applies it: flipping the toggle alone only wrote a
/// preference, so the tunnel state never followed the whitelist until the next restart.
Future<void> _setEnabled(
  BuildContext context,
  WidgetRef ref,
  bool value,
) async {
  ref.read(configResourcesProvider.notifier).setOnDemand(value);
  if (!value) {
    showConfigHint(context, '按需连接已关闭，VPN 不再随网络切换');
    return;
  }
  final outcome = await ref.read(onDemandRunnerProvider).apply(force: true);
  if (!context.mounted) return;
  showConfigHint(context, outcome.label(context.l10n));
}

/// Re-evaluates the whitelist against the current network; the page has no network callback, so
/// this is how a user applies it after switching Wi-Fi.
Future<void> _applyNow(BuildContext context, WidgetRef ref) async {
  final outcome = await ref.read(onDemandRunnerProvider).apply(force: true);
  if (!context.mounted) return;
  showConfigHint(context, outcome.label(context.l10n));
}

/// What the whitelist decides for the network the device is on now. The card exists because a
/// list alone never tells the user whether the tunnel would start.
class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision});

  final SsidDecision decision;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (glyph, title, tone) = switch (decision.state) {
      SsidMatchState.disabled => (
        AppGlyphs.wifiOff,
        '未启用',
        colorScheme.onSurfaceVariant,
      ),
      SsidMatchState.unknown => (AppGlyphs.locate, '无法判断', colorScheme.warning),
      SsidMatchState.noWifi => (
        AppGlyphs.wifiOff,
        '未连接 Wi-Fi',
        colorScheme.onSurfaceVariant,
      ),
      SsidMatchState.matched => (
        AppGlyphs.check,
        '会启动 VPN',
        colorScheme.primary,
      ),
      SsidMatchState.unmatched => (
        AppGlyphs.wifi,
        '不会启动 VPN',
        colorScheme.warning,
      ),
    };
    final rule = decision.rule;
    return generateSection(
      title: '当前判定',
      items: [
        ListItem(
          leading: GlyphIcon(glyph, size: 20, color: tone),
          title: Text(
            title,
            style: context.listTitleStyle.copyWith(color: tone),
          ),
          subtitle: Text(
            rule == null ? _decisionSummary(decision) : _ruleSummary(rule),
          ),
        ),
      ],
      footer:
          '判定按当前网络实时计算：切换 Wi-Fi 后重新读取即可看到结果。'
          'SSID 区分大小写。',
    );
  }
}

/// The name of the joined network, read from the platform channel; the row is also the place to
/// re-read it, since the network can change while the page is open.
class _NetworkSection extends ConsumerWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final async = ref.watch(currentSsidProvider);
    final ssid = async.asData?.value;
    final unknown = async.hasValue && ssid == null;
    return generateSection(
      title: '当前网络',
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.wifi, size: 20),
          title: const Text('Wi-Fi 名称'),
          subtitle: Text(describeSsid(ssid)),
          trailing: ConfigRemoveButton(
            tooltip: '重新读取',
            glyph: AppGlyphs.refresh,
            onPressed: () => ref.invalidate(currentSsidProvider),
          ),
          onTap: () => ref.invalidate(currentSsidProvider),
        ),
        if (unknown)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.locate, size: 20),
            title: const Text('读取权限'),
            subtitle: const Text('Android 10 起读取 Wi-Fi 名称需要位置权限'),
            trailing: Text(
              '未授权',
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.warning,
              ),
            ),
          ),
      ],
      footer: unknown
          ? '本机当前无法读取 Wi-Fi 名称：请在系统设置里授予本应用位置权限后重新读取。'
          : 'SSID 只用于匹配白名单，不会被上传；手动添加的 SSID 在无法读取时仍然可用。',
    );
  }
}

/// Battery-optimization allowlist, the one prerequisite the app can actually query and request.
class _BatterySection extends ConsumerWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final async = ref.watch(batteryOptimizationProvider);
    final state = async.asData?.value;
    final (label, color) = switch (state) {
      BatteryOptimizationState.ignored => ('已加入', colorScheme.primary),
      BatteryOptimizationState.notIgnored => ('未加入', colorScheme.warning),
      BatteryOptimizationState.unavailable ||
      null => ('不可用', context.colorScheme.onSurfaceVariant),
    };
    return generateSection(
      title: '前置条件',
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.bolt, size: 20),
          title: const Text('忽略电池优化'),
          subtitle: Text(
            state == BatteryOptimizationState.ignored
                ? '系统不会在后台冻结 VPN 进程'
                : state == BatteryOptimizationState.notIgnored
                ? '未加入时后台 VPN 可能被系统冻结，点击申请'
                : '当前构建没有提供电池优化通道',
          ),
          trailing: Text(
            label,
            style: context.listCaptionStyle.copyWith(color: color),
          ),
          onTap: state == BatteryOptimizationState.notIgnored
              ? () => _request(context, ref)
              : null,
        ),
      ],
      footer: '点击「未加入」会打开系统授权页；返回后会重新读取真实状态，取消则保持未加入。',
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final state = await requestBatteryOptimizationAccess(ref);
    if (!context.mounted) return;
    showConfigHint(context, switch (state) {
      BatteryOptimizationState.ignored => '已加入电池优化白名单',
      BatteryOptimizationState.notIgnored => '仍未加入，VPN 可能被系统冻结',
      BatteryOptimizationState.unavailable => '当前构建不支持该授权',
    });
  }
}
