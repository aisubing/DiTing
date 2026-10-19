import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 出站模式卡（上游 `widgets/outbound_mode.dart`，174 行）。
///
/// 三项等宽分段：规则 / 全局 / 直连。选中项胀成整颗胶囊，两端圆、内侧锐。
class OutboundModeCard extends ConsumerWidget {
  const OutboundModeCard({super.key});

  static const _outer = 26.0;
  static const _inner = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(outboundModeProvider);
    return DashboardCard(
      semanticLabel: '出站模式',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const DashboardCardHeader(
            glyph: AppGlyphs.split,
            title: '出站模式',
          ),
          DashboardSegmentedControl<OutboundMode>(
            outer: _outer,
            inner: _inner,
            segments: const [
              (OutboundMode.rule, AppGlyphs.rules, '规则'),
              (OutboundMode.global, AppGlyphs.proxies, '全局'),
              (OutboundMode.direct, AppGlyphs.target, '直连'),
            ],
            value: mode,
            onChanged: (value) =>
                ref.read(outboundModeProvider.notifier).select(value),
          ),
          Text(
            switch (mode) {
              OutboundMode.rule => '按规则列表分流，未命中的走默认出站。',
              OutboundMode.global => '所有流量都走当前代理组。',
              OutboundMode.direct => '所有流量直连，不经过任何代理。',
            },
            style: DashboardText.label(context),
          ),
        ],
      ),
    );
  }
}
