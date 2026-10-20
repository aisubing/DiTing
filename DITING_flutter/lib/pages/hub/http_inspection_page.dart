import 'package:diting/data/mock_system.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// HTTPS 流量检查（上游 `HttpInspectionSettingsScreen`）。
class HttpInspectionPage extends ConsumerWidget {
  const HttpInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(httpInspectionProvider);
    final apps = ref.watch(hubAppSelectionsProvider)[
        HubAppPool.httpInspection] ??
        const <String>{};
    final notifier = ref.read(httpInspectionProvider.notifier);
    final canUse = state.caReady;
    final protocolEnabled = state.caReady && state.enabled;
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
                subtitle: Text(
                  !state.caReady
                      ? '需先安装并验证 CA 根证书'
                      : apps.isEmpty
                      ? '未选择目标应用，仅保留 DNS 过滤'
                      : '已选 ${apps.length} 个应用，其余直接转发',
                ),
                value: state.enabled && canUse,
                onChanged: canUse
                    ? (value) => notifier.update(
                        (current) => current.copyWith(enabled: value),
                      )
                    : null,
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.appsList),
                title: const Text('目标应用'),
                subtitle: Text(
                  !state.caReady
                      ? '需先安装并验证 CA 根证书'
                      : apps.isEmpty
                      ? '未选择任何应用'
                      : '已选择 ${apps.length} 个应用',
                ),
                onTap: canUse
                    ? () => context.push('/hub/https-inspection/apps')
                    : null,
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.verified),
                title: const Text('CA 证书'),
                subtitle: Text(
                  state.caReady ? '证书已就绪，可查看或重置' : '未安装或未验证，点击配置',
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
                  !state.caReady
                      ? '需先安装并验证 CA 根证书'
                      : !state.enabled
                      ? '需先启用 HTTPS 检查'
                      : !state.urlRules
                      ? '已暂停 · 解密请求直接放行，不应用 URL 规则及 CNAME 重定向'
                      : '开启解密流量下的 URL 屏蔽、放行及 CNAME 重定向',
                ),
                value: state.urlRules && protocolEnabled,
                onChanged: protocolEnabled
                    ? (value) => notifier.update(
                        (current) => current.copyWith(urlRules: value),
                      )
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
                  !protocolEnabled
                      ? '需先启用 HTTPS 检查'
                      : '阻断 QUIC 促使回退至 TCP 以便解密；若异常请关闭',
                ),
                value: state.http3,
                onChanged: protocolEnabled
                    ? (value) => notifier.update(
                        (current) => current.copyWith(http3: value),
                      )
                    : null,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.lock),
                title: const Text('阻断加密 DNS (DoT)'),
                subtitle: Text(
                  !protocolEnabled ? '需先启用 HTTPS 检查' : '阻断 TCP 853 端口，防止绕过域名规则',
                ),
                value: state.encryptedDns,
                onChanged: protocolEnabled
                    ? (value) => notifier.update(
                        (current) => current.copyWith(encryptedDns: value),
                      )
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
          const SizedBox(height: 24),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(hubAppSelectionsProvider)[
        HubAppPool.httpInspection] ??
        const <String>{};
    final notifier = ref.read(hubAppSelectionsProvider.notifier);
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final app in mockPackages)
        if (query.isEmpty ||
            app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query))
          app,
    ];
    return CommonScaffold(
      title: '选择检查应用',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: () => notifier.write(HubAppPool.httpInspection, {
            ...selected,
            for (final app in visible) app.packageName,
          }),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '取消当前结果',
          onPressed: () => notifier.write(
            HubAppPool.httpInspection,
            selected.difference({for (final app in visible) app.packageName}),
          ),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              child: Text(
                'Go 隧道接管流量后，HTTPS 流量检查仅检查所选应用的 HTTP(S) 请求，'
                '其他应用直接转发。选择应用会取消其「排除应用」状态。',
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
          generateSection(
            title: '已选择 ${selected.length} 个应用',
            items: [
              for (final app in visible)
                ListItem(
                  leading: GlyphIcon(
                    selected.contains(app.packageName)
                        ? AppGlyphs.checkCircle
                        : glyphByName(app.glyphName),
                    size: 20,
                    color: selected.contains(app.packageName)
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  trailing: CommonCheckBox(
                    value: selected.contains(app.packageName),
                    isCircle: true,
                    onChanged: (_) =>
                        notifier.toggle(HubAppPool.httpInspection, app.packageName),
                  ),
                  onTap: () =>
                      notifier.toggle(HubAppPool.httpInspection, app.packageName),
                ),
            ],
            footer: visible.isEmpty ? '未找到匹配应用' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
