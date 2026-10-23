// ignore_for_file: sort_child_properties_last
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/block_response_settings.dart';
import 'package:diting/router.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Rule control (upstream `RuleControlScreen`): master switch, URL rules, block response
/// and subscription updates; block, allow and override lists stay in their own hub cards.
class RuleControlPage extends ConsumerWidget {
  const RuleControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final domainRules = settings.domainRulesEnabled;
    final blockMode = BlockResponseMode.fromStorage(
      settings.blockResponseModeRaw,
    );
    // CA readiness comes from the real channel: `caReadyProvider` reads
    // `CaCertificateService.inspect()`, so an installed certificate is not reported as missing.
    final caReady = ref.watch(caReadyProvider);
    final inspectionApps = settings.httpInspectionPackages;
    final subscriptions = ref.watch(subscriptionEntriesProvider).value;
    final mirrors = ref.watch(mirrorTemplatesProvider).value;
    final autoUpdate = ref.watch(autoUpdateSettingsProvider);
    final footnote = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    final urlSubtitle = !caReady
        ? '未就绪 · 需先安装并验证 CA 根证书'
        : !settings.httpInspectionEnabled
        ? '未就绪 · 需在 HTTPS 流量检查中开启'
        : inspectionApps.isEmpty
        ? '未就绪 · 需在 HTTPS 流量检查中选择目标应用'
        : !domainRules
        ? '已暂停 · 未启用解密 URL 过滤与重定向'
        : '运行中 · 解密流量匹配 URL 屏蔽、放行及重定向';
    return CommonScaffold(
      title: '规则控制',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '统一管理域名过滤、URL 规则及规则覆写的总控开关、拦截策略与在线规则订阅。'
                '黑名单、白名单与覆写名单可在功能中心中独立管理。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '过滤与覆写控制',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.rules),
                title: const Text('启用域名规则'),
                subtitle: Text(
                  domainRules
                      ? '开启 DNS 阶段域名屏蔽、白名单放行及 IPv4/IPv6 覆写'
                      : '已禁用 DNS 域名过滤，查询将直接放行',
                ),
                value: domainRules,
                onChanged: (value) {
                  settings.setDomainRulesEnabled(value);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.target),
                title: const Text('URL 规则与内容过滤'),
                subtitle: Text(urlSubtitle),
                trailing: Text(
                  settings.httpInspectionEnabled &&
                          settings.addressRulesEnabled &&
                          caReady
                      ? '运行中'
                      : '未就绪',
                  style: footnote,
                ),
                onTap: () => context.push('/hub/https-inspection'),
              ),
            ],
          ),
          generateSection(
            title: '拦截策略',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.block),
                title: const Text('拦截响应'),
                subtitle: Text(
                  settings.dynamicBlockEnabled
                      ? '动态策略：先 NODATA，高频请求后 ${blockMode.label}'
                      : blockMode.label,
                ),
                onTap: () => context.push('/hub/rules/block-response'),
              ),
            ],
          ),
          generateSection(
            title: '订阅与更新',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.cloudSync),
                title: const Text('规则订阅'),
                subtitle: const Text('管理域名规则与 IPv4/IPv6 覆写订阅源及分组'),
                trailing: Text(
                  subscriptions == null ? '—' : '${subscriptions.length} 个',
                  style: footnote,
                ),
                onTap: () => context.push(Routes.subscriptions),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.refresh),
                title: const Text('自动更新设置'),
                subtitle: Text(
                  autoUpdate.enabled
                      ? '已开启 · 每 ${autoUpdate.intervalHours} 小时自动更新'
                      : '已关闭自动更新',
                ),
                onTap: () => context.push('/hub/rules/auto-update'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.layers),
                title: const Text('镜像站模板'),
                subtitle: const Text('维护订阅下载镜像，可在添加订阅时直接选择'),
                trailing: Text(
                  mirrors == null ? '—' : '${mirrors.length} 个',
                  style: footnote,
                ),
                onTap: () => context.push('/hub/rules/mirrors'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Block response settings (upstream `BlockResponseSettingsScreen`), persisted in
/// `dns_vpn_prefs` (`block_response_mode` plus four `dynamic_block_*` keys) and published
/// by `buildDnsConfig` on next start.
class BlockResponsePage extends ConsumerWidget {
  const BlockResponsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final mode = BlockResponseMode.fromStorage(settings.blockResponseModeRaw);
    final policy = DynamicBlockPolicy.read(settings);
    return CommonScaffold(
      title: '拦截响应',
      body: PageBody(
        children: [
          generateSection(
            title: '固定响应',
            items: [
              for (final option in BlockResponseMode.values)
                ListItem(
                  leading: GlyphIcon(
                    option == mode ? AppGlyphs.checkCircle : AppGlyphs.block,
                    size: 20,
                  ),
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  trailing: option == mode ? const SelectionCheck() : null,
                  onTap: () {
                    settings.setBlockResponseModeRaw(option.storageValue);
                    ref.read(legacySettingsRevisionProvider.notifier).bump();
                  },
                ),
            ],
            footer:
                '动态策略开启时会临时覆盖以上选择：先返回 NODATA，'
                '高频请求后返回 NXDOMAIN。',
          ),
          generateSection(
            title: '动态策略',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.motion),
                title: const Text('启用动态策略'),
                subtitle: const Text('同一域名的所有记录类型合并计数'),
                value: policy.enabled,
                onChanged: (value) {
                  policy.copyWith(enabled: value).write(settings);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.sliders),
                title: const Text('动态参数'),
                subtitle: Text(
                  '${policy.requestThreshold} 次 / ${policy.windowSeconds} 秒 / '
                  '保持 ${policy.nxDomainDurationSeconds} 秒',
                ),
                onTap: policy.enabled
                    ? () => _editParameters(context, ref, policy)
                    : null,
              ),
            ],
            footer:
                '正常客户端会缓存 NODATA 响应。动态策略主要用于持续重试或'
                '忽略负缓存的请求。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editParameters(
    BuildContext context,
    WidgetRef ref,
    DynamicBlockPolicy policy,
  ) async {
    final result = await showFloatingDialog<DynamicBlockPolicy>(
      context: context,
      child: _DynamicParameterDialog(policy: policy),
    );
    if (result == null) {
      return;
    }
    result.write(ref.read(legacySettingsProvider));
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

class _DynamicParameterDialog extends StatefulWidget {
  const _DynamicParameterDialog({required this.policy});

  final DynamicBlockPolicy policy;

  @override
  State<_DynamicParameterDialog> createState() =>
      _DynamicParameterDialogState();
}

class _DynamicParameterDialogState extends State<_DynamicParameterDialog> {
  late final _threshold = TextEditingController(
    text: '${widget.policy.requestThreshold}',
  );
  late final _window = TextEditingController(
    text: '${widget.policy.windowSeconds}',
  );
  late final _duration = TextEditingController(
    text: '${widget.policy.nxDomainDurationSeconds}',
  );
  String? _error;

  @override
  void dispose() {
    _threshold.dispose();
    _window.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final threshold = int.tryParse(_threshold.text);
    final window = int.tryParse(_window.text);
    final duration = int.tryParse(_duration.text);
    String? error;
    // Upstream clamps: 2-100 requests, 10-300 s window, 60-3600 s hold.
    if (threshold == null || threshold < 2 || threshold > 100) {
      error = '请求次数需在 2–100 之间';
    } else if (window == null || window < 10 || window > 300) {
      error = '统计窗口需在 10–300 秒之间';
    } else if (duration == null || duration < 60 || duration > 3600) {
      error = '保持时长需在 60–3600 秒之间';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      DynamicBlockPolicy(
        enabled: true,
        requestThreshold: threshold!,
        windowSeconds: window!,
        nxDomainDurationSeconds: duration!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '动态参数',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '请求次数',
              helperText: '2–100 次；第 N+1 次开始升级',
            ),
          ),
          TextField(
            controller: _window,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '统计窗口（秒）',
              helperText: '10–300 秒',
            ),
          ),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'NXDOMAIN 保持时长（秒）',
              helperText: '60–3600 秒；首次升级起固定计时',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}