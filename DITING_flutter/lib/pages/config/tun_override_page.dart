/// TUN 覆写页（上游 `views/config/tun.dart`，265 行）。
///
/// 上游这一页就是一份 `appTunOverrideSpec` 加 `OverrideView`；本仓的
/// [OverrideSpecPage] 承担了视图部分，所以这里只剩下规格选择。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/override_spec_page.dart';
import 'package:material_ui/material_ui.dart';

/// TUN 覆写。
class TunOverridePage extends StatelessWidget {
  const TunOverridePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const OverrideSpecPage(spec: mockTunOverrideSpec);
}
