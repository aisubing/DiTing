import 'package:diting/pages/appearance/appearance_color_page.dart';
import 'package:diting/pages/appearance/appearance_shared_pages.dart';
import 'package:diting/pages/appearance/font_family_page.dart';
import 'package:diting/pages/appearance/settings_parity_pages.dart';
import 'package:diting/pages/appearance/theme_page.dart';
import 'package:diting/pages/demo/demo_page.dart';
import 'package:diting/pages/forms/forms_demo_page.dart';
import 'package:diting/pages/forms/list_editor_demo_page.dart';
import 'package:diting/pages/forms/map_edit_demo_page.dart';
import 'package:diting/pages/forms/named_url_page.dart';
import 'package:diting/pages/forms/rule_preset_page.dart';
import 'package:diting/pages/forms/selection_demo_page.dart';
import 'package:diting/pages/system/app_update_page.dart';
import 'package:diting/pages/system/developer_page.dart';
import 'package:diting/pages/system/editor_page.dart';
import 'package:diting/pages/system/ip_quality_page.dart';
import 'package:diting/pages/system/scan_page.dart';
import 'package:diting/pages/system/sponsor_page.dart';
import 'package:diting/ui/navigator.dart';
import 'package:go_router/go_router.dart';

/// 外观 / 设置子页 / 系统 / 表单领域路由。
///
/// 上一轮这一族里有 `/theme/preview`（主题预览）、`/access`（访问控制）、
/// `/backup`（WebDAV 主页）、`/disclaimer`（独立免责声明页）、`/error`（错误页）。
/// 这五条在 1.4.3 都没有对应界面：旧版外观设置是「3 组 8 项」的菜单，没有整页
/// 预览；访问控制属于 FlClash 的应用分流；WebDAV 在旧版只是备份页里的一张表单；
/// 免责声明是首次启动的对话框（`使用须知与免责声明`）加关于页的一节；错误页在
/// 本仓没有任何入口。本轮按「旧版为准」清理。
abstract final class SystemPaths {
  // —— 外观（旧版 `APPEARANCE_SETTINGS` 三组八项）——
  static const theme = '/theme';
  static const dayNight = '/theme/day-night';
  static const colorStyle = '/theme/color';
  static const homeOpacity = '/theme/home-opacity';
  static const bottomBar = '/theme/bottom-bar';
  static const homeSentence = '/theme/home-sentence';
  static const notification = '/theme/notification';
  static const background = '/theme/background';

  /// 字体族。旧版没有这一项，用户要求保留。
  static const fontFamily = '/font-family';

  // —— 设置子页 ——
  /// 前后台行为（旧版 `FOREGROUND_BACKGROUND_SETTINGS`）。
  static const foregroundBackground = '/settings/background';

  /// 语言设置（旧版 `LANGUAGE_SETTINGS`）。
  static const language = '/settings/language';

  // —— 系统 ——
  /// 开发者选项聚合页。旧版没有这一页：它是保留项的入口，也是本计划里唯一
  /// 「旧版无对应菜单」的整页入口，因此只挂在设置页顶栏一个图标按钮上。
  static const developer = '/developer';
  static const sponsor = '/sponsor';
  static const appUpdate = '/app-update';

  // —— 保留页（旧版无对应界面，用户要求保留）——
  static const ipQuality = '/ip-quality';
  static const editor = '/editor';
  static const scan = '/scan';

  // —— 演示页（保留组件画廊与表单族）——
  static const demo = '/demo';
  static const formDemo = '/form';
  static const formListEditor = '/form/list-editor';
  static const formMapEdit = '/form/map-edit';
  static const formNamedUrl = '/form/named-url';
  static const formSelection = '/form/selection';
  static const formRulePreset = '/form/rule-preset';
}

/// 外观 / 设置子页 / 系统 / 表单路由表。由 `lib/router.dart` 拼接。
///
/// 全部用 `parentNavigatorKey: rootNavigatorKey`：这一族页面都是「盖在整棵树
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
    path: SystemPaths.dayNight,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeDayNightPage(),
  ),
  GoRoute(
    path: SystemPaths.colorStyle,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeColorPage(),
  ),
  GoRoute(
    path: SystemPaths.homeOpacity,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeHomeOpacityPage(),
  ),
  GoRoute(
    path: SystemPaths.bottomBar,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeBottomBarPage(),
  ),
  GoRoute(
    path: SystemPaths.homeSentence,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeHomeSentencePage(),
  ),
  GoRoute(
    path: SystemPaths.notification,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeNotificationPage(),
  ),
  GoRoute(
    path: SystemPaths.background,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ThemeBackgroundPage(),
  ),
  GoRoute(
    path: SystemPaths.fontFamily,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const FontFamilyPage(),
  ),

  // —— 设置子页 ——
  GoRoute(
    path: SystemPaths.foregroundBackground,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SettingsBackgroundPage(),
  ),
  GoRoute(
    path: SystemPaths.language,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SettingsLanguagePage(),
  ),

  // —— 系统 ——
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

  // —— 保留页 ——
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

  // —— 演示页 ——
  GoRoute(
    path: SystemPaths.demo,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DemoPage(),
  ),
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
