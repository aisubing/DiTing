/// 设置页：外观 / 首页 / 底栏 / 解析 / 关于五组设置。
///
/// 这一页同时是设计系统的「密度验收面」：除滑杆与色板圆点这类本质定制的控件
/// 外，每一行都由 `ListItem` 的构造器 + `generateSection` 组合，没有手写的行
/// 样式——否则设计系统一改行高或圆角，这里就会成为最早露馅的地方。
///
/// 按 AGENTS.md 的 550 行上限拆成库根 + part：本文件只放页面骨架与五个分组的
/// 组装顺序，每组各占一个 part。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'settings_about_section.dart';
part 'settings_appearance_section.dart';
part 'settings_bottom_bar_section.dart';
part 'settings_home_section.dart';
part 'settings_resolution_section.dart';

/// 展示用版本号。
///
/// 演示层不读 `package_info_plus`（本阶段不引依赖），所以与 `pubspec.yaml` 的
/// `version: 1.0.0+1` 手工对齐；发版时必须同步改这两处，别只改一处。
const appVersionLabel = '1.0.0';

/// 设置页外壳。
///
/// 页尾的 `DockSpacer` 由 [PageBody] 自动补上（设置页是底栏 tab，浮条会盖住
/// 最后一行），所以这里不再手动加留白。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '设置',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.palette,
          tooltip: '组件画廊',
          onPressed: () => context.push(Routes.demo),
        ),
      ],
      body: const PageBody(
        children: [
          _AppearanceSection(),
          _HomeSection(),
          _BottomBarSection(),
          _ResolutionSection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

/// 设置项的即时反馈统一走 SnackBar。
///
/// 底栏项数的上限/下限只由 `BottomBarNotifier` 的单次操作决定，被拒绝时除了
/// 开关回到原位没有任何痕迹，用户会以为「点坏了」——必须补一句说明。
void _showSettingHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ),
  );
}
