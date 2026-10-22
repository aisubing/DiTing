import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// HTTPS 流量检查（上游 `HttpInspectionSettingsScreen`）。
///
/// 开关与目标应用清单走 `legacySettings`（`http_inspection_enabled` /
/// `http_inspection_app_packages`），CA 就绪状态来自 `CaCertificateService`
/// ——不再有 `caReady` 这类页面内开关，因为它必须反映设备上真实装没装证书。
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
      body: PageBody(
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
                    ? (value) => _setEnabled(context, ref, settings, value)
                    : null,
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
                onTap: caReady
                    ? () => context.push('/hub/https-inspection/apps')
                    : null,
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
                          encryptedDns: settings.encryptedDnsBlockingEnabled,
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
                  !enabled ? '需先启用 HTTPS 检查' : '阻断 QUIC 促使回退至 TCP 以便解密；若异常请关闭',
                ),
                value: http3,
                onChanged: enabled
                    ? (value) {
                        settings.setHttpInspectionToggles(
                          http3: value,
                          encryptedDns: settings.encryptedDnsBlockingEnabled,
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
                onTap: () => context.push('/logs'),
              ),
            ],
          ),
          generateSection(
            title: 'HTTPS 绕过规则（${bypass.length}）',
            actions: [
              IconButtonData(
                glyph: AppGlyphs.add,
                tooltip: '添加绕过域名',
                onPressed: () => _addBypass(context, ref, settings, bypass),
              ),
            ],
            items: [
              if (bypass.isEmpty)
                const ListItem(
                  leading: GlyphIcon(AppGlyphs.info),
                  title: Text('未配置自定义绕过规则'),
                  subtitle: Text('内置放行清单始终生效；这里是额外追加的域名后缀'),
                ),
              for (final rule in bypass.toList()..sort())
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.split, size: 20),
                  title: Text(
                    rule,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('不参与解密，直接透传'),
                  trailing: IconButton(
                    tooltip: '删除',
                    onPressed: () {
                      settings.setHttpsBypassRules({...bypass}..remove(rule));
                      ref.read(legacySettingsRevisionProvider.notifier).bump();
                    },
                    icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                  ),
                ),
            ],
            footer:
                '写入 https_bypass_rules，与 assets/https_passthrough.txt 的内置清单'
                '合并后交给引擎的 setExtraPassthroughSuffixes。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 「有证书但没装」和「压根没生成」是两种不同的处置，文案必须分开说：
  /// 前者去系统设置安装，后者要先点「重新生成」。
  static String _caProblem(bool available, bool installed) {
    if (!available) {
      return '尚未生成根证书：前往 CA 证书页生成';
    }
    if (!installed) {
      return '证书已生成但未安装到系统信任存储';
    }
    return '证书已就绪';
  }

  /// 打开/关闭 HTTPS 检查；域名规则关着时先要求用户确认联动开启。
  ///
  /// 上游 `HttpInspectionSettingsScreen` 的耦合约束：`domain_rules_enabled` 是关的
  /// 时候打开检查，解密流量却没有任何规则可应用，看起来像「开了但没用」；它弹
  /// `DomainRulesInspectionLinkageDialog` 让用户一次性把两个开关都打开。这里保留
  /// 同一行为，只是文案换成直白解释。
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
      child: const _BypassDomainDialog(),
    );
    if (value == null) {
      return;
    }
    settings.setHttpsBypassRules({...current, value});
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

/// 选择检查应用（上游 `HttpInspectionAppsScreen`）。
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 每次改动立即落盘：选择集很小，父页面读的是同一个键。
  ///
  /// 总开关保持原值不跟着变——上游 `saveHttpInspectionApps` 只写包名集合，是否
  /// 启用由 CA 就绪状态与用户手动切换决定，勾选应用不该顺手把检查打开。
  ///
  /// 三处互斥清洗与上游一致：勾选的应用不能同时留在「排除」「禁止联网」
  /// 「应用独立规则」里，否则引擎侧判定顺序决定结果，用户看到的是随机行为。
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
    final selected = ref.watch(legacySettingsProvider).httpInspectionPackages;
    final snapshot = ref.watch(installedAppsProvider);
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    final visible = visibleInstalledApps(
      apps: apps,
      query: _query,
      filter: AppListFilter.all,
      sort: AppListSort.labelAsc,
      selected: selected,
    );
    return CommonScaffold(
      title: '选择检查应用',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => _write({
                  ...selected,
                  for (final app in visible) app.packageName,
                }),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '取消当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => _write(
                  selected.difference({
                    for (final app in visible) app.packageName,
                  }),
                ),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Go 隧道接管流量后，HTTPS 流量检查仅检查所选应用的 HTTP(S) 请求，'
                '其他应用直接转发。选择应用会取消其「排除应用」「禁止联网」'
                '与应用独立规则状态。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (snapshot.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CommonCircleLoading()),
            )
          else if (snapshot.value?.error != null)
            EmptyStateBox(
              minHeight: 260,
              child: NullStatus(
                label: '读不到应用列表',
                description: snapshot.value!.error,
                illustration: NullStatusIllustration.apps,
                action: TextButton(
                  onPressed: () =>
                      ref.read(installedAppsRevisionProvider.notifier).bump(),
                  child: const Text('重试'),
                ),
              ),
            )
          else
            generateSection(
              title: '已选择 ${selected.length} 个应用（可见 ${visible.length}）',
              items: [
                for (final app in visible)
                  ListItem(
                    leading: GlyphIcon(
                      selected.contains(app.packageName)
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.appsList,
                      size: 20,
                      color: selected.contains(app.packageName)
                          ? context.colorScheme.primary
                          : null,
                    ),
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
                  ),
              ],
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可选的应用' : '未找到匹配应用')
                  : null,
            ),
          const SizedBox(height: 24),
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

/// 绕过域名输入弹窗。
///
/// 控制器由弹窗自己持有：写成「调用方 new 一个 controller、`await` 之后立刻
/// `dispose()`」时，`pop` 一调用 future 就完成，而退场动画还没跑完、`TextField`
/// 仍挂在树上，dispose 会让它在动画中途重建到已失效的依赖上，实测整屏红
/// （`'_dependents.isEmpty': is not true`）。
class _BypassDomainDialog extends StatefulWidget {
  const _BypassDomainDialog();

  @override
  State<_BypassDomainDialog> createState() => _BypassDomainDialogState();
}

class _BypassDomainDialogState extends State<_BypassDomainDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加绕过域名',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('添加')),
      ],
      child: TextField(
        controller: _controller,
        autocorrect: false,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '域名后缀',
          hintText: 'example.com',
          helperText: '匹配该后缀及其子域名；不参与 HTTPS 解密',
        ),
      ),
    );
  }
}
