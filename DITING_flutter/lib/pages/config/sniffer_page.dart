/// 嗅探页（上游 `views/config/sniffer.dart`，285 行）。
///
/// 上游 = 一份 `_SnifferOverrideSpec`（八个通用键） + 三个协议键
/// （`sniff-http` / `sniff-tls` / `sniff-quic`，每项再展开一个子页：端口列表 +
/// 是否覆写目标地址）。本仓把通用键交给 [OverrideSpecPage]，协议部分做成
/// [SnifferProtocolSection]——每个协议在列表里占一行，点开是同一个编辑面板，
/// 而不是三个各自独立的子页面。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/pages/config/override_spec_page.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'sniffer_protocol_section.dart';

/// 嗅探。
class SnifferConfigPage extends StatelessWidget {
  const SnifferConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OverrideSpecPage(
      spec: mockSnifferOverrideSpec,
      extraSections: [SnifferProtocolSection()],
    );
  }
}
