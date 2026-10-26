import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/server/server_actions.dart';
import 'package:diting/pages/server/server_platform_probe.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Server mode "settings" tab (upstream `server/ui/DnsSettingsScreen.kt`), five groups in upstream
/// order: proxy and resolution, rule management, data and reset, background stability, run mode.
class ServerSettingsPage extends ConsumerStatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  ConsumerState<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends ConsumerState<ServerSettingsPage> {
  BatteryOptimizationState _battery = BatteryOptimizationState.unavailable;
  bool _batteryLoaded = false;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _refreshBattery();
  }

  Future<void> _refreshBattery() async {
    final state = await readBatteryOptimization();
    if (!mounted) {
      return;
    }
    setState(() {
      _battery = state;
      _batteryLoaded = true;
    });
  }

  Future<void> _requestBattery() async {
    final state = await requestBatteryOptimization();
    if (!mounted) {
      return;
    }
    setState(() => _battery = state);
    if (state == BatteryOptimizationState.unavailable) {
      showServerHint(context, '当前设备不可用');
      return;
    }
    showServerHint(
      context,
      state == BatteryOptimizationState.ignored ? '已加入电池优化白名单' : '尚未加入电池优化白名单',
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空缓存',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
        child: const Text('将清空本机已缓存的解析结果，下一次查询会重新向上游请求。'),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _clearingCache = true);
    final cleared = await clearServerDnsCache();
    if (!mounted) {
      return;
    }
    setState(() => _clearingCache = false);
    // Only two causes: the service is not running (nothing to clear) or the engine threw.
    // Both mean "not cleared", so the hint is actionable rather than "not wired yet".
    showServerHint(
      context,
      cleared ? '缓存已清空' : '清空失败：请先启动解析服务再试',
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(legacySettingsProvider);
    final port = ref.watch(serverPortProvider);
    final cacheEnabled = settings.serverCacheEnabled;
    final adBlockEnabled = settings.serverAdBlockEnabled;
    final cacheSummary = cacheEnabled
        ? '${_cachePresetLabel(settings.serverCachePresetRaw)} · 命中缓存的查询不再请求上游'
        : '已关闭 · 每次解析都请求上游 DNS';
    return CommonScaffold(
      title: '模式设置',
      body: PageBody(
        children: [
          generateSection(
            title: '代理与解析设置',
            items: [
              ListItem(
                title: const Text('缓存设置'),
                subtitle: Text(cacheSummary),
                leading: const GlyphIcon(AppGlyphs.memory),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                // Server-mode cache keys live in `diting_dns_mode_prefs`, a different set
                // from the normal-mode cache page, so this entry only navigates.
                onTap: () => context.push(HubPaths.cache),
              ),
              ListItem(
                title: const Text('规则控制'),
                subtitle: Text(
                  adBlockEnabled ? '已开启 · 命中规则按拦截策略返回' : '已关闭 · 使用独立的过滤规则库',
                ),
                leading: const GlyphIcon(AppGlyphs.rules),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(HubPaths.ruleControl),
              ),
              ListItem(
                title: const Text('本地监听端口'),
                subtitle: const Text('DNS 服务在本机监听的端口，默认 1053'),
                leading: const GlyphIcon(AppGlyphs.speed),
                trailing: Text(
                  '$port',
                  style: context.listSubtitleStyle.copyWith(
                    fontFamily: appMonospaceFontFamily,
                  ),
                ),
                onTap: () => editServerPort(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '规则管理',
            items: [
              ListItem(
                title: const Text('黑名单'),
                subtitle: const Text('管理域名屏蔽规则，独立规则库'),
                leading: const GlyphIcon(AppGlyphs.block),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(Routes.rulesOf('block')),
              ),
              ListItem(
                title: const Text('白名单'),
                subtitle: const Text('管理域名放行规则，独立规则库'),
                leading: const GlyphIcon(AppGlyphs.verified),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(Routes.rulesOf('allow')),
              ),
              ListItem(
                title: const Text('Hosts 覆写'),
                subtitle: const Text('将指定域名解析到配置的 IP 或 CNAME'),
                leading: const GlyphIcon(AppGlyphs.dns),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                // The legacy `REWRITELIST_MANAGEMENT` is the rewrite table; of the three
                // rule kinds here it maps to `rewrite`.
                onTap: () => context.push(Routes.rulesOf('rewrite')),
              ),
            ],
            footer: '这三张表只影响服务器模式的独立规则库，与普通模式的规则互不覆盖。',
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '数据与重置',
            items: [
              ListItem(
                title: const Text('清空缓存'),
                subtitle: const Text('移除已缓存的解析结果，下一次查询重新向上游请求'),
                leading: const GlyphIcon(AppGlyphs.broom),
                trailing: _clearingCache
                    ? const CommonCircleLoading(size: 18)
                    : const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: _clearingCache ? null : _clearCache,
              ),
              ListItem(
                title: const Text('重置运行统计'),
                subtitle: const Text('清空本次运行的统计数据'),
                leading: const GlyphIcon(AppGlyphs.reset),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => confirmResetServerStats(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '后台稳定性',
            items: [_batteryRow(context)],
            footer:
                '系统会在后台冻结省电名单之外的应用；把它加入白名单，'
                'DNS 服务才能在息屏后继续应答局域网查询。',
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '运行模式',
            items: [
              ListItem(
                title: const Text('使用向导'),
                subtitle: const Text('查看服务器模式架构原理、局域网配置与就绪指引'),
                leading: const GlyphIcon(AppGlyphs.info),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(Routes.modeOnboarding),
              ),
              ListItem(
                title: const Text('重新选择工作模式'),
                subtitle: const Text('浏览所有工作模式详情并重新选择'),
                leading: const GlyphIcon(AppGlyphs.sliders),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(Routes.modeSelect),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Battery optimization: tappable while not granted, greyed out once granted. A missing
  /// channel also greys it out but must say "unavailable on this device".
  Widget _batteryRow(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (subtitle, value, enabled) = switch (_battery) {
      BatteryOptimizationState.ignored => ('已忽略电池优化', '已忽略', false),
      BatteryOptimizationState.notIgnored => ('保持 DNS 服务在后台稳定运行', null, true),
      BatteryOptimizationState.unavailable => ('当前设备不可用', null, false),
    };
    return ListItem(
      title: const Text('忽略电池优化'),
      subtitle: Text(subtitle),
      leading: GlyphIcon(
        AppGlyphs.bolt,
        color: enabled ? null : colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      trailing: !_batteryLoaded
          ? const CommonCircleLoading(size: 18)
          : value == null
          ? null
          : Text(
              value,
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: enabled ? _requestBattery : null,
    );
  }

  static String _cachePresetLabel(String raw) => switch (raw) {
    'conservative' => '保守',
    'high_hit_rate' => '高命中',
    _ => '标准',
  };
}