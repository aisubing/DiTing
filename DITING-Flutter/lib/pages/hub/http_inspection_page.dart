import 'dart:async';

import 'package:diting/app/l10n/l10n.dart';
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
        ? (ca == null
              ? context.l10n.httpInspCheckingCa
              : _caProblem(context.l10n, ca.available, ca.installed))
        : apps.isEmpty
        ? context.l10n.httpInspNoAppsHint
        : context.l10n.httpInspSelectedHint(apps.length);
    return CommonScaffold(
      title: context.l10n.hubHttpsInspection,
      body: SliverPageBody(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                generateSection(
                  title: context.l10n.httpInspScopeSection,
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.lock),
                      title: Text(context.l10n.httpInspEnable),
                      subtitle: Text(caHint),
                      value: enabled,
                      onChanged: caReady
                          ? (value) =>
                                _setEnabled(context, ref, settings, value)
                          : (_) => _explainCaMissing(context, ca),
                    ),
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.appsList),
                      title: Text(context.l10n.httpInspTargetApps),
                      subtitle: Text(
                        !caReady
                            ? caHint
                            : apps.isEmpty
                            ? context.l10n.httpInspNoApps
                            : context.l10n.httpInspSelectedApps(apps.length),
                      ),
                      // A dead row reads as "the app is broken"; explain the missing certificate
                      // instead and offer the one screen that fixes it.
                      onTap: caReady
                          ? () => context.push('/hub/https-inspection/apps')
                          : () => _explainCaMissing(context, ca),
                    ),
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.verified),
                      title: Text(context.l10n.httpInspCaCert),
                      subtitle: Text(
                        ca == null
                            ? context.l10n.httpInspCheckingCa
                            : caReady
                            ? context.l10n.httpInspCaReady
                            : _caProblem(
                                context.l10n,
                                ca.available,
                                ca.installed,
                              ),
                      ),
                      onTap: () => context.push('/hub/https-inspection/ca'),
                    ),
                  ],
                ),
                generateSection(
                  title: context.l10n.httpInspContentSection,
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.target),
                      title: Text(context.l10n.httpInspUrlRules),
                      subtitle: Text(
                        !caReady
                            ? caHint
                            : !enabled
                            ? context.l10n.httpInspNeedEnable
                            : !urlRules
                            ? context.l10n.httpInspUrlPaused
                            : context.l10n.httpInspUrlOn,
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
                  title: context.l10n.httpInspProtocolSection,
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.bolt),
                      title: Text(context.l10n.httpInspBlockHttp3),
                      subtitle: Text(
                        !enabled
                            ? context.l10n.httpInspNeedEnable
                            : context.l10n.httpInspBlockHttp3Subtitle,
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
                      title: Text(context.l10n.httpInspBlockDot),
                      subtitle: Text(
                        !enabled ? context.l10n.httpInspNeedEnable : context.l10n.httpInspBlockDotSubtitle,
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
                      title: Text(context.l10n.httpInspRequestLogs),
                      subtitle: Text(context.l10n.httpInspRequestLogsSubtitle),
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
        tooltip: context.l10n.bypassAddTitle,
        onPressed: () => _addBypass(context, ref, settings, bypass),
      ),
    ];
    final footer = context.l10n.httpInspBypassFooter;
    if (bypass.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: context.l10n.httpInspBypassTitle(0),
            actions: actions,
            items: [
              ListItem(
                leading: GlyphIcon(AppGlyphs.info),
                title: Text(context.l10n.httpInspBypassEmpty),
                subtitle: Text(context.l10n.httpInspBypassEmptySubtitle),
              ),
            ],
          ),
        ),
      ];
    }
    final sorted = bypass.toList()..sort();
    return lazySectionSlivers(
      title: context.l10n.httpInspBypassTitle(sorted.length),
      actions: actions,
      itemCount: sorted.length,
      footer: footer,
      itemBuilder: (context, index) {
        final rule = sorted[index];
        return ListItem(
          leading: const GlyphIcon(AppGlyphs.split, size: 20),
          title: Text(rule, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(context.l10n.httpInspBypassRowSubtitle),
          trailing: IconButton(
            tooltip: context.l10n.commonDelete,
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
        title: context.l10n.httpInspCaRequiredTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonLater),
          ),
          if (state != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.httpInspGoInstall),
            ),
        ],
        child: Text(
          state == null
              ? context.l10n.httpInspCaReadingBody
              : context.l10n.httpInspCaRequiredBody(
                  _caProblem(context.l10n, state.available, state.installed),
                ),
        ),
      ),
    );
    if (opened == true && context.mounted) {
      context.push('/hub/https-inspection/ca');
    }
  }

  /// "Certificate exists but is not installed" and "not generated yet" need different copy:
  /// install it from system settings, or regenerate first.
  static String _caProblem(AppL10n l10n, bool available, bool installed) {
    if (!available) {
      return l10n.httpInspCaMissing;
    }
    if (!installed) {
      return l10n.httpInspCaNotInstalled;
    }
    return l10n.httpInspCaReadyShort;
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
          title: context.l10n.httpInspNeedDomainRulesTitle,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.uiCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.httpInspEnableAll),
            ),
          ],
          child: Text(context.l10n.httpInspNeedDomainRulesBody),
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
      title: context.l10n.httpInspAppsTitle,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: context.l10n.httpInspSelectVisible,
          onPressed: visible.isEmpty
              ? null
              : () => _write({...selected, ...visiblePackages}),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: context.l10n.httpInspDeselectVisible,
          onPressed: visible.isEmpty
              ? null
              : () => _write(selected.difference(visiblePackages)),
        ),
      ],
      menuItems: appListMenuItems(
        l10n: context.l10n,
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
                PageIntroCard(text: context.l10n.httpInspAppsIntro),
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
              title: context.l10n.httpInspAppsCount(
                selected.length,
                visible.length,
              ),
              itemCount: visible.length,
              footer: visible.isEmpty
                  ? (apps.isEmpty ? context.l10n.appSelectionNoAppsAvailable : context.l10n.appSelectionNoMatch)
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
