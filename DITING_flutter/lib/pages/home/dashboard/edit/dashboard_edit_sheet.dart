import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 「添加卡片」浮层（上游 `dashboard/edit.dart` 的添加区）。
///
/// 列出还没上屏的卡片，点一项立刻追加到末尾并关闭。已上屏的不出现在列表里，
/// 因此不需要「已添加」的禁用态——上游也是这么做的。
class DashboardEditSheet extends ConsumerWidget {
  const DashboardEditSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardWidgetsProvider);
    final notifier = ref.read(dashboardWidgetsProvider.notifier);
    final available = [
      for (final widget in DashboardWidget.mobileAvailable)
        if (!widgets.contains(widget)) widget,
    ];
    return CommonScaffold(
      title: '添加卡片',
      actions: [
        TextButton(
          onPressed: () => notifier.reset(),
          child: const Text('恢复默认'),
        ),
      ],
      body: available.isEmpty
          ? const Center(
              child: NullStatus(
                illustration: NullStatusIllustration.data,
                label: '卡片都放上来了',
                description: '想减少卡片，请回到编辑模式点卡片右上角的移除。',
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const ListHeader(title: '可添加的卡片'),
                for (final widget in available)
                  ListItem(
                    leading: GlyphIcon(_glyphOf(widget)),
                    title: Text(widget.label),
                    subtitle: Text(_descriptionOf(widget)),
                    trailing: const GlyphIcon(
                      AppGlyphs.addCircle,
                      size: 20,
                    ),
                    onTap: () {
                      notifier.add(widget);
                      Navigator.of(context).maybePop();
                    },
                  ),
                const ListFooter(
                  text: '卡片顺序可在编辑模式下拖拽调整；本演示不持久化。',
                ),
              ],
            ),
    );
  }

  static Glyph _glyphOf(DashboardWidget widget) => switch (widget) {
    DashboardWidget.currentOutbound => AppGlyphs.status,
    DashboardWidget.networkSpeed => AppGlyphs.speed,
    DashboardWidget.outboundMode => AppGlyphs.split,
    DashboardWidget.vpn => AppGlyphs.vpn,
    DashboardWidget.serviceStatus => AppGlyphs.status,
    DashboardWidget.profiles => AppGlyphs.profiles,
    DashboardWidget.proxyGroups => AppGlyphs.proxies,
    DashboardWidget.connectionStats => AppGlyphs.connections,
    DashboardWidget.intranetIp => AppGlyphs.devices,
    DashboardWidget.memory => AppGlyphs.memory,
  };

  static String _descriptionOf(DashboardWidget widget) => switch (widget) {
    DashboardWidget.currentOutbound => '内核状态、出站链与快捷动作',
    DashboardWidget.networkSpeed => '实时上下行速率与累计流量',
    DashboardWidget.outboundMode => '规则 / 全局 / 直连三选一',
    DashboardWidget.vpn => '本地 VPN 接管开关',
    DashboardWidget.serviceStatus => '各服务探测结果与延迟',
    DashboardWidget.profiles => '当前配置、用量进度与到期时间',
    DashboardWidget.proxyGroups => '各代理组当前选中与延迟',
    DashboardWidget.connectionStats => '活动连接、已关闭与累计流量',
    DashboardWidget.intranetIp => '本机局域网地址与端口',
    DashboardWidget.memory => '内核内存占用与明细',
  };
}

/// 编辑态的退出确认条（顶栏「完成」按钮旁的提示）。
///
/// 上游编辑模式退出时不再询问（改了就生效），这里保持一致，只在首次进入时
/// 用一条 SnackBar 说明手势。
class DashboardEditingHint extends StatelessWidget {
  const DashboardEditingHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
