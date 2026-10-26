/// Per-site latency breakdown, opened from the card's cell and from the detail page's rows.
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class SiteLatencyTargetSheet extends StatelessWidget {
  const SiteLatencyTargetSheet({
    super.key,
    required this.target,
    required this.summary,
    required this.lastRunAt,
  });

  final SiteLatencyTarget target;
  final PingSummary? summary;
  final DateTime? lastRunAt;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    String ms(double? value) => value == null ? '—' : '${value.round()} ms';
    return CommonScaffold(
      title: target.name,
      body: ListView(
        // The sheet title floats over the body, so this top padding is required.
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          const ListHeader(title: '延迟'),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.link, size: 20),
            title: const Text('分类'),
            trailing: Text(target.category.label),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.link, size: 20),
            title: const Text('目标'),
            subtitle: Text(target.host),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.speed, size: 20),
            title: const Text('平均往返'),
            trailing: Text(ms(summary?.avgMs)),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.arrowDown, size: 20),
            title: const Text('最小 / 最大'),
            trailing: Text('${ms(summary?.minMs)} / ${ms(summary?.maxMs)}'),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.motion, size: 20),
            title: const Text('抖动'),
            trailing: Text(ms(summary?.jitterMs)),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.warning, size: 20),
            title: const Text('丢包'),
            trailing: Text(
              summary == null
                  ? '—'
                  : '${summary.lossPercent.toStringAsFixed(0)}%'
                        '（${summary.received}/${summary.transmitted}）',
            ),
          ),
          if (summary?.resolvedAddress case final address?
              when address.isNotEmpty)
            ListItem(
              leading: const GlyphIcon(AppGlyphs.dns, size: 20),
              title: const Text('解析地址'),
              subtitle: Text('${summary!.addressFamily ?? ''} $address'.trim()),
            ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.clock, size: 20),
            title: const Text('最近测速'),
            trailing: Text(elapsedAgoLabel(lastRunAt)),
          ),
          if (summary == null)
            const ListFooter(text: '尚未测速。点测速按钮开始测量。')
          else if (!summary.success)
            ListFooter(
              text: summary.message?.isNotEmpty == true
                  ? summary.message!
                  : '三个回显请求都没有收到应答，可能是站点限流或当前网络不通。',
            )
          else if (summary.measuredWithFallback)
            const ListFooter(
              text:
                  '系统 ping 不可用，这次数值来自 TCP 握手 / isReachable，'
                  '衡量的是建连时延而不是 ICMP 回显，会略高于真实往返。',
            )
          else
            const ListFooter(
              text:
                  '数值来自系统 ping 的 ICMP 回显（3 次取平均）。'
                  '本应用自身流量不经过 VPN，测的是物理网络。',
            ),
        ],
      ),
    );
  }
}
