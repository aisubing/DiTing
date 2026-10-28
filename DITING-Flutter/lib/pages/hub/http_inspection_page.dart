import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/http_inspection_bypass_dialog.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/standalone_routes.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_icon_avatar.dart';
import 'package:diting/widgets/app_list_error_state.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/section_slivers.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// HTTPS inspection (upstream `HttpInspectionSettingsScreen`). Switch and app list live in
/// `http_inspection_enabled` / `http_inspection_app_packages`; CA readiness comes from
/// `CaCertificateService`.
class HttpInspectionPage extends ConsumerWidget {
  const HttpInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final caAsync = ref.watch(caCertificateStateProvider);
    final ca = caAsync.value;
    final caReady = ca?.ready ?? false;
    final apps = settings.httpInspectionPackages;
    final enabled = caReady && settings.httpInspectionEnabled;
    final urlRules = enabled && settings.addressRulesEnabled;
    final http3 = enabled && settings.http3InspectionEnabled;
    final encryptedDns = enabled && settings.encryptedDnsBlockingEnabled;
    final bypass = settings.httpsBypassRules;
    final caHint = !caReady
        ? (ca == null ? '正在检查根证书…' : _caProblem(ca.available, ca.installed))
        : apps.isEmpty
        ? '未选择目标应用，仅保留 DNS 过滤'
        : '已选 ${apps.length} 个应用，其余直接转发';
    return CommonScaffold(
      title: 'HTTPS 流量检查',
      body: SliverPageBody(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                generateSection(
                  title: '检查范围',
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.lock),
                      title: const Text('启用 HTTPS 检查'),
                      subtitle: Text(caHint),
                      value: enabled,
                      onChanged: caReady
                          ? (value) =>
                                _setEnabled(context, ref, settings, value)
                          : (_) => _explainCaMissing(context, ca),
                    ),
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.appsList),
                      title: const Text('目标应用'),
                      subtitle: Text(
                        !caReady
                            ? caHint
                            : apps.isEmpty
                            ? '未选择任何应用'
                            : '已选择 ${apps.length} 个应用',
                      ),
                      // A dead row reads as "the app is broken"; explain the missing certificate
                      // instead and offer the one screen that fixes it.
                      onTap: caReady
                          ? () => context.push('/hub/https-inspection/apps')
                          : () => _explainCaMissing(context, ca),
                    ),
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.verified),
                      title: const Text('CA 证书'),
                      subtitle: Text(
                        ca == null
                            ? '正在检查根证书…'
                            : caReady
                            ? '证书已安装且指纹匹配，可查看或重置'
                            : _caProblem(ca.available, ca.installed),
                      ),
                      onTap: () => context.push('/hub/https-inspection/ca'),
                    ),
                  ],
                ),
                generateSection(
                  title: '解密内容过滤',
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.target),
                      title: const Text('启用 URL 规则与重定向'),
                      subtitle: Text(
                        !caReady
                            ? caHint
                            : !enabled
                            ? '需先启用 HTTPS 检查'
                            : !urlRules
                            ? '已暂停 · 解密请求直接放行，不应用 URL 规则及 CNAME 重定向'
                            : '开启解密流量下的 URL 屏蔽、放行及 CNAME 重定向',
                      ),
                      value: urlRules,
                      onChanged: enabled
                          ? (value) {
                              settings.setHttpInspectionToggles(
                                http3: settings.http3InspectionEnabled,
                                encryptedDns:
                                    settings.encryptedDnsBlockingEnabled,
                                addressRules: value,
                              );
                              ref
                                  .read(legacySettingsRevisionProvider.notifier)
                                  .bump();
                            }
                          : null,
                    ),
                  ],
                ),
                generateSection(
                  title: '协议与兼容性',
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.bolt),
                      title: const Text('拦截 HTTP/3 (QUIC)'),
                      subtitle: Text(
                        !enabled
                            ? '需先启用 HTTPS 检查'
                            : '阻断 QUIC 促使回退至 TCP 以便解密；若异常请关闭',
                      ),
                      value: http3,
                      onChanged: enabled
                          ? (value) {
                              settings.setHttpInspectionToggles(
                                http3: value,
                                encryptedDns:
                                    settings.encryptedDnsBlockingEnabled,
                                addressRules: settings.addressRulesEnabled,
                              );
                              ref
                                  .read(legacySettingsRevisionProvider.notifier)
                                  .bump();
                            }
                          : null,
                    ),
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.lock),
                      title: const Text('阻断加密 DNS (DoT)'),
                      subtitle: Text(
                        !enabled ? '需先启用 HTTPS 检查' : '阻断 TCP 853 端口，防止绕过域名规则',
                      ),
                      value: encryptedDns,
                      onChanged: enabled
                          ? (value) {
                              settings.setHttpInspectionToggles(
                                http3: settings.http3InspectionEnabled,
                                encryptedDns: value,
                                addressRules: settings.addressRulesEnabled,
                              );
                              ref
                                  .read(legacySettingsRevisionProvider.notifier)
                                  .bump();
                            }
                          : null,
                    ),
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.logs),
                      title: const Text('请求日志'),
                      subtitle: const Text('查看解密明细与自动旁路记录'),
                      onTap: () {
                        if (!pushStandalone(context, '/logs')) {
                          openLocation(context, '/logs');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          ..._bypassSlivers(context, ref, settings, bypass),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// Bypass suffixes are user-maintained and grow without bound; a lazy sliver keeps the first
  /// frame flat no matter how many are configured.
  List<Widget> _bypassSlivers(
    BuildContext context,
    WidgetRef ref,
    LegacySettings settings,
    Set<String> bypass,
  ) {
    final actions = [
      IconButtonData(
        glyph: AppGlyphs.add,
        tooltip: '添加绕过域名',
        onPressed: () => _addBypass(context, ref, settings, bypass),
      ),
    ];
    const footer =
        '写入 https_bypass_rules，与 assets/https_passthrough.txt 的内置清单'
        '合并后交给引擎的 setExtraPassthroughSuffixes。';
    if (bypass.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: 'HTTPS 绕过规则（0）',
            actions: actions,
            items: const [
              ListItem(
                leading: GlyphIcon(AppGlyphs.info),
                title: Text('未配置自定义绕过规则'),
                subtitle: Text('内置放行清单始终生效；这里是额外追加的域名后缀'),
              ),
            ],
          ),
        ),
      ];
    }
    final sorted = bypass.toList()..sort();
    return lazySectionSlivers(
      title: 'HTTPS 绕过规则（${sorted.length}）',
      actions: actions,
      itemCount: sorted.length,
      footer: footer,
      itemBuilder: (context, index) {
        final rule = sorted[index];
        return ListItem(
          leading: const GlyphIcon(AppGlyphs.split, size: 20),
          title: Text(rule, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('不参与解密，直接透传'),
          trailing: IconButton(
            tooltip: '删除',
            onPressed: () {
              settings.setHttpsBypassRules({...bypass}..remove(rule));
              ref.read(legacySettingsRevisionProvider.notifier).bump();
            },
            icon: const GlyphIcon(AppGlyphs.delete, size: 20),
          ),
        );
      },
    );
  }

  /// Tapping a gated row while the CA is unready used to do nothing at all.
  static Future<void> _explainCaMissing(
    BuildContext context,
    CaCertificateState? state,
  ) async {
    final opened = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '需要先安装根证书',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          if (state != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('前往安装'),
            ),
        ],
        child: Text(
          state == null
              ? '正在读取根证书状态，请稍后再试。'
              : 'HTTPS 检查要把解密后的明文交回应用，必须由系统的根证书信任链认可谛听的'
                    '根证书。当前是「${_caProblem(state.available, state.installed)}」，'
                    '所以还不能选择目标应用。\n\n去 CA 证书页生成并安装证书？',
        ),
      ),
    );
    if (opened == true && context.mounted) {
      context.push('/hub/https-inspection/ca');
    }
  }

  /// "Certificate exists but is not installed" and "not generated yet" need different copy:
  /// install it from system settings, or regenerate first.
  static String _caProblem(bool available, bool installed) {
    if (!available) {
      return '尚未生成根证书：前往 CA 证书页生成';
    }
    if (!installed) {
      return '证书已生成但未安装到系统信任存储';
    }
    return '证书已就绪';
  }

  /// Toggles inspection, asking first when domain rules are off: decrypting traffic with
  /// `domain_rules_enabled` off looks "on but useless", so the dialog enables both at once.
  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    LegacySettings settings,
    bool value,
  ) async {
    if (!value) {
      settings.setHttpInspectionApps(
        packages: settings.httpInspectionPackages,
        enabled: false,
      );
      ref.read(legacySettingsRevisionProvider.notifier).bump();
      return;
    }
    if (!settings.domainRulesEnabled) {
      final confirmed = await showFloatingDialog<bool>(
        context: context,
        child: CommonDialog(
          title: '还需要开启域名规则',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('全部开启'),
            ),
          ],
          child: const Text(
            'HTTPS 检查负责解密，域名规则负责决定解密后的流量怎么处理。'
            '当前域名规则是关闭状态，只开检查不会有任何拦截效果。\n\n'
            '是否同时开启域名规则？',
          ),
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
      settings.setDomainRulesEnabled(true);
    }
    settings.setHttpInspectionApps(
      packages: settings.httpInspectionPackages,
      enabled: true,
    );
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  Future<void> _addBypass(
    BuildContext context,
    WidgetRef ref,
    LegacySettings settings,
    Set<String> current,
  ) async {
    final value = await showFloatingDialog<String>(
      context: context,
      child: const HttpInspectionBypassDialog(),
    );
    if (value == null) {
      return;
    }
    settings.setHttpsBypassRules({...current, value});
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

class HttpInspectionAppsPage extends ConsumerStatefulWidget {
  const HttpInspectionAppsPage({super.key});

  @override
  ConsumerState<HttpInspectionAppsPage> createState() =>
      _HttpInspectionAppsPageState();
}

class _HttpInspectionAppsPageState
    extends ConsumerState<HttpInspectionAppsPage> {
  final _search = TextEditingController();
  String _query = '';

  /// Same 250 ms debounce as 1.4.3 `AppPickerScreen`.
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Every change is persisted immediately, since the parent page reads the same keys; the
  /// master switch is left alone, matching `saveHttpInspectionApps`.
  void _write(Set<String> packages) {
    final settings = ref.read(legacySettingsProvider);
    settings.setHttpInspectionApps(
      packages: packages,
      enabled: settings.httpInspectionEnabled,
    );
    if (packages.isNotEmpty) {
      settings.setExcludedPackages(
        settings.excludedPackages.difference(packages),
      );
      settings.setBlockedApps(
        packages: settings.blockedAppPackages.difference(packages),
        enabled: settings.blockedAppsEnabled,
      );
      final allowlist = settings.appAllowlistRules;
      if (allowlist.keys.any(packages.contains)) {
        settings.setAppAllowlistRules({
          for (final entry in allowlist.entries)
            if (!packages.contains(entry.key)) entry.key: entry.value,
        });
      }
    }
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(legacySettingsProvider);
    final selected = settings.httpInspectionPackages;
    final filter = AppListFilter.fromStorageValue(
      settings.httpInspectionAppsFilterRaw,
    );
    final sort = AppListSort.fromStorageValue(
      settings.httpInspectionAppsSortRaw,
    );
    final snapshot = ref.watch(installedAppsProvider);
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    final visible = visibleInstalledApps(
      apps: apps,
      query: _query,
      filter: filter,
      sort: sort,
      selected: selected,
    );
    final visiblePackages = {for (final app in visible) app.packageName};
    return CommonScaffold(
      title: '选择检查应用',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => _write({...selected, ...visiblePackages}),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '取消当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => _write(selected.difference(visiblePackages)),
        ),
      ],
      menuItems: appListMenuItems(
        filter: filter,
        sort: sort,
        onFilterChanged: (value) {
          settings.setHttpInspectionAppsFilterRaw(value.storageValue);
          ref.read(legacySettingsRevisionProvider.notifier).bump();
        },
        onSortChanged: (value) {
          settings.setHttpInspectionAppsSortRaw(value.storageValue);
          ref.read(legacySettingsRevisionProvider.notifier).bump();
        },
        onSelectAll: () => _write({...selected, ...visiblePackages}),
        onClear: () => _write(const {}),
        onInvert: () => _write(
          selected
              .difference(visiblePackages)
              .union(visiblePackages.difference(selected)),
        ),
      ),
      body: AppListScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                PageIntroCard(
                  text:
                      'Go 隧道接管流量后，HTTPS 流量检查仅检查所选应用的 HTTP(S) 请求，'
                      '其他应用直接转发。选择应用会取消其「排除应用」「禁止联网」'
                      '与应用独立规则状态。',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (snapshot.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CommonCircleLoading()),
                  )
                else if (snapshot.value?.error case final error?)
                  AppListErrorState(error: error),
              ],
            ),
          ),
          if (!snapshot.isLoading && snapshot.value?.error == null)
            ...appListSlivers(
              title: '已选择 ${selected.length} 个应用（可见 ${visible.length}）',
              itemCount: visible.length,
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可选的应用' : '未找到匹配应用')
                  : null,
              itemBuilder: (context, index) {
                final app = visible[index];
                return ListItem(
                  leading: AppIconAvatar(packageName: app.packageName),
                  title: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: CommonCheckBox(
                    value: selected.contains(app.packageName),
                    isCircle: true,
                    onChanged: (_) => _toggle(selected, app.packageName),
                  ),
                  onTap: () => _toggle(selected, app.packageName),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _toggle(Set<String> selected, String packageName) {
    final next = {...selected};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    _write(next);
  }
}
