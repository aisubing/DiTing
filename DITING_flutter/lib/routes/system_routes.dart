import 'package:diting/pages/appearance/font_family_page.dart';
import 'package:diting/pages/appearance/theme_page.dart';
import 'package:diting/pages/appearance/theme_preview_page.dart';
import 'package:diting/pages/forms/forms_demo_page.dart';
import 'package:diting/pages/forms/list_editor_demo_page.dart';
import 'package:diting/pages/forms/map_edit_demo_page.dart';
import 'package:diting/pages/forms/named_url_page.dart';
import 'package:diting/pages/forms/rule_preset_page.dart';
import 'package:diting/pages/forms/selection_demo_page.dart';
import 'package:diting/pages/system/access_page.dart';
import 'package:diting/pages/system/app_update_page.dart';
import 'package:diting/pages/system/backup_page.dart';
import 'package:diting/pages/system/developer_page.dart';
import 'package:diting/pages/system/disclaimer_page.dart';
import 'package:diting/pages/system/editor_page.dart';
import 'package:diting/pages/system/error_page.dart';
import 'package:diting/pages/system/ip_quality_page.dart';
import 'package:diting/pages/system/scan_page.dart';
import 'package:diting/pages/system/sponsor_page.dart';
import 'package:diting/ui/navigator.dart';
import 'package:go_router/go_router.dart';

/// 系统 / 外观 / 表单领域路由。
///
/// 外观（主题 / 字体）与系统（访问控制 / 备份 / 免责声明 / 更新 / 赞助）
/// 放在一起：它们都由「设置」页或功能中心进入，页面之间跳转频繁。
abstract final class SystemPaths {
  // —— 外观 ——
  static const theme = '/theme';
  static const themePreview = '/theme/preview';
  static const fontFamily = '/font-family';

  // —— 系统 ——
  static const access = '/access';
  static const backup = '/backup';
  static const disclaimer = '/disclaimer';
  static const developer = '/developer';
  static const sponsor = '/sponsor';
  static const appUpdate = '/app-update';
  static const ipQuality = '/ip-quality';
  static const editor = '/editor';
  static const scan = '/scan';
  static const errorPage = '/error';

  // —— 表单 ——
  static const formDemo = '/form';
  static const formListEditor = '/form/list-editor';
  static const formMapEdit = '/form/map-edit';
  static const formNamedUrl = '/form/named-url';
  static const formSelection = '/form/selection';
  static const formRulePreset = '/form/rule-preset';
}

/// 系统 / 外观 / 表单领域路由表。由 `lib/router.dart` 拼接。
///
/// 每个都用 `parentNavigatorKey: rootNavigatorKey`：这一族页面全是「盖在整棵树
/// 之上的整页」，不应该落进底栏所在的嵌套 navigator——否则底栏会在这些页面上
/// 继续可见，而它们没有底栏。
List<RouteBase> systemRoutes() => <RouteBase>[
  // —— 外观 ——
  GoRoute(
    path: SystemPaths.theme,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemePage(),
  ),
  GoRoute(
    path: SystemPaths.themePreview,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemePreviewPage(),
  ),
  GoRoute(
    path: SystemPaths.fontFamily,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const FontFamilyPage(),
  ),

  // —— 系统 ——
  GoRoute(
    path: SystemPaths.access,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AccessPage(),
  ),
  GoRoute(
    path: SystemPaths.backup,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const BackupPage(),
  ),
  GoRoute(
    path: SystemPaths.disclaimer,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DisclaimerPage(),
  ),
  GoRoute(
    path: SystemPaths.developer,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DeveloperPage(),
  ),
  GoRoute(
    path: SystemPaths.sponsor,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SponsorPage(),
  ),
  GoRoute(
    path: SystemPaths.appUpdate,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AppUpdatePage(),
  ),
  GoRoute(
    path: SystemPaths.ipQuality,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const IpQualityPage(),
  ),
  GoRoute(
    path: SystemPaths.editor,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const EditorPage(),
  ),
  GoRoute(
    path: SystemPaths.scan,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ScanPage(),
  ),
  GoRoute(
    path: SystemPaths.errorPage,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ErrorPage(),
  ),

  // —— 表单 ——
  GoRoute(
    path: SystemPaths.formDemo,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const FormsDemoPage(),
  ),
  GoRoute(
    path: SystemPaths.formListEditor,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ListEditorDemoPage(),
  ),
  GoRoute(
    path: SystemPaths.formMapEdit,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const MapEditDemoPage(),
  ),
  GoRoute(
    path: SystemPaths.formNamedUrl,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const NamedUrlPage(),
  ),
  GoRoute(
    path: SystemPaths.formSelection,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SelectionDemoPage(),
  ),
  GoRoute(
    path: SystemPaths.formRulePreset,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const RulePresetPage(),
  ),
];
