import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 网络接管卡（上游 `widgets/network_takeover.dart`，299 行）。
///
/// 上游在桌面端展示「系统代理 / TUN 接管」两个开关；Android 上没有系统代理
/// 接管，但 VPN 服务开关是真实存在的，因此这里取 VPN 形态：一个大开关 + 权限
/// 状态行。开关只是演示反馈，不会真的建立 VPN。
class VpnCard extends StatefulWidget {
  const VpnCard({super.key});

  @override
  State<VpnCard> createState() => _VpnCardState();
}

class _VpnCardState extends State<VpnCard> {
  var _enabled = false;
  var _busy = false;

  Future<void> _toggle({required bool value}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    // 上游这里要等系统授权，会有 1–2 秒的空档；演示里留 700ms 让忙碌态可见。
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = value;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DashboardCard(
      semanticLabel: '网络接管',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.vpn,
            title: '网络接管',
            trailing: [
              DashboardChip(
                label: _busy
                    ? '切换中'
                    : _enabled
                    ? '已接管'
                    : '未接管',
                tone: _enabled ? DashboardChipTone.ok : DashboardChipTone.idle,
                dot: true,
              ),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: _enabled
                      ? colorScheme.primaryContainer
                      : DashboardColors.of(context).tone,
                  shape: AppShape.all(AppCorner.md),
                ),
                child: Center(
                  child: GlyphIcon(
                    _enabled ? AppGlyphs.vpn : AppGlyphs.wifiOff,
                    size: 22,
                    color: _enabled
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      _enabled ? '流量已走本地 VPN' : '流量未接管',
                      style: DashboardText.rowTitle(context),
                    ),
                    Text(
                      _enabled
                          ? '所有应用经 127.0.0.1:7890 出网'
                          : '开启后需要授权 VPN 权限',
                      style: DashboardText.label(context),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const CommonCircleLoading(size: 22)
              else
                Switch(
                  value: _enabled,
                  onChanged: (value) => _toggle(value: value),
                ),
            ],
          ),
          // 权限说明：上游这里还有一条「已授予 VPN 权限」的只读行。
          Row(
            spacing: 6,
            children: [
              GlyphIcon(
                _enabled ? AppGlyphs.checkCircle : AppGlyphs.info,
                size: 14,
                color: _enabled ? colorScheme.success : colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  _enabled ? 'VPN 权限已授予' : '尚未授予 VPN 权限（演示不会真的申请）',
                  style: DashboardText.label(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
