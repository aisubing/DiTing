import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 内网 IP 卡（上游 `widgets/intranet_ip.dart`，150 行）。
///
/// 显示本机在当前局域网的地址；「允许局域网」打开时地址后面带端口。点击
/// 复制按钮把完整地址写进剪贴板并弹提示。
class IntranetIpCard extends ConsumerWidget {
  const IntranetIpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(intranetProvider);
    final colorScheme = context.colorScheme;
    final figureStyle = DashboardText.figure(
      context,
      AppTextStyle.title2,
    ).copyWith(letterSpacing: 0);
    return DashboardCard(
      semanticLabel: '内网 IP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.devices,
            title: '内网 IP',
            trailing: [
              Transform.translate(
                offset: const Offset(8, 0),
                child: DashboardIconButton(
                  glyph: AppGlyphs.copy,
                  tooltip: '复制地址',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: info.display),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text('已复制 ${info.display}'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Text(
            info.display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: figureStyle,
          ),
          Row(
            spacing: 8,
            children: [
              DashboardChip(
                label: info.interfaceName,
                dot: true,
                tone: DashboardChipTone.ok,
              ),
              Expanded(
                child: Text(
                  info.allowLan ? '局域网可访问' : '仅本机可用',
                  style: DashboardText.label(context),
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  '允许局域网',
                  style: DashboardText.rowTitle(context).copyWith(
                    fontSize: AppTextStyle.subheadline.size,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: info.allowLan,
                onChanged: (value) => ref
                    .read(intranetProvider.notifier)
                    .setAllowLan(value: value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
