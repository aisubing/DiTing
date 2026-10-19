/// NTP 页（上游 `views/config/ntp.dart`，125 行）。
///
/// NTP 覆写共六个键，全部由 [OverrideSpecPage] 渲染；这一页额外把「上次对时」
/// 摆出来，因为 NTP 是否生效从配置上看不出来，只能看时间读数。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/override_spec_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 演示用的对时读数。
const _lastSyncedAt = '2026-10-19 06:12';
const _clockOffset = '+0.021 s';

/// NTP。
class NtpConfigPage extends StatelessWidget {
  const NtpConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OverrideSpecPage(
      spec: mockNtpOverrideSpec,
      extraSections: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CommonCard(
            child: StatStrip(
              stats: const [
                StatItem(label: '上次对时', value: _lastSyncedAt),
                StatItem(label: '时钟偏移', value: _clockOffset),
              ],
            ),
          ),
        ),
        const ListFooter(text: '对时读数来自内核上报；偏移持续增大说明服务器不可达或链路不稳。'),
      ],
    );
  }
}
