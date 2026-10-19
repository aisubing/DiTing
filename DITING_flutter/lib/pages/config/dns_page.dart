/// DNS 覆写页（上游 `views/config/dns.dart`，414 行）。
///
/// 上游这一页 = 一份 `appDnsOverrideSpec` + 一个策略字段（`_PolicyField`，
/// 规则集 → 服务商的映射编辑器）。本仓把规格交给 [OverrideSpecPage]、把策略表
/// 做成 [DnsPolicySection]，这一页只负责把两者拼在一起。
///
/// 策略表没有复用 `lib/pages/forms/map_edit_view.dart`：那个视图是给「粘贴一大
/// 堆键值对」用的（自带批量导入区），而 DNS 策略只有十来条、逐条添加更贴近
/// 实际用法；嵌进来会让这一页平白多出一整块批量输入区。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/pages/config/override_spec_page.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'dns_policy_section.dart';

/// DNS 覆写。
class DnsOverridePage extends StatelessWidget {
  const DnsOverridePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OverrideSpecPage(
      spec: mockDnsOverrideSpec,
      extraSections: [DnsPolicySection()],
    );
  }
}
