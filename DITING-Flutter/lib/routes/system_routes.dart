import 'package:diting/pages/appearance/appearance_color_page.dart';
import 'package:diting/pages/appearance/appearance_shared_pages.dart';
import 'package:diting/pages/appearance/font_family_page.dart';
import 'package:diting/pages/appearance/font_size_page.dart';
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
import 'package:diting/routes/page.dart';
import 'package:diting/ui/navigator.dart';
import 'package:go_router/go_router.dart';

/// Appearance, settings sub pages, system and form routes.
abstract final class SystemPaths {
  static const theme = '/theme';
  static const dayNight = '/theme/day-night';
  static const colorStyle = '/theme/color';
  static const homeOpacity = '/theme/home-opacity';
  static const bottomBar = '/theme/bottom-bar';
  static const homeSentence = '/theme/home-sentence';
  static const notification = '/theme/notification';
  static const background = '/theme/background';

  /// Font family. No upstream equivalent; kept at the user's request.
  static const fontFamily = '/font-family';

  /// Font size, a sub page of [fontFamily]. Upstream had a slider on the appearance page.
  static const fontSize = '/font-size';

  /// Foreground/background behaviour (upstream `FOREGROUND_BACKGROUND_SETTINGS`).
  static const foregroundBackground = '/settings/background';

  /// Language settings (upstream `LANGUAGE_SETTINGS`).
  static const language = '/settings/language';

  /// Developer options hub. Upstream had no such page; it is the only entry
  /// to the retained pages and sits in the settings app bar.
  static const developer = '/developer';
  static const sponsor = '/sponsor';
  static const appUpdate = '/app-update';

  // Retained pages: no upstream UI, kept at the user's request.
  static const ipQuality = '/ip-quality';
  static const editor = '/editor';
  static const scan = '/scan';

  // Demo pages: component gallery and form family.
  static const demo = '/demo';
  static const formDemo = '/form';
  static const formListEditor = '/form/list-editor';
  static const formMapEdit = '/form/map-edit';
  static const formNamedUrl = '/form/named-url';
  static const formSelection = '/form/selection';
  static const formRulePreset = '/form/rule-preset';
}

/// Appearance, settings, system and form routes, assembled by `lib/router.dart`. All set
/// `parentNavigatorKey: rootNavigatorKey`: they are full pages covering the whole tree, so the
/// nested navigator would keep the bottom dock visible.
List<RouteBase> systemRoutes() => <RouteBase>[
  GoRoute(
    path: SystemPaths.theme,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemePage()),
  ),
  GoRoute(
    path: SystemPaths.dayNight,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeDayNightPage()),
  ),
  GoRoute(
    path: SystemPaths.colorStyle,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeColorPage()),
  ),
  GoRoute(
    path: SystemPaths.homeOpacity,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeHomeOpacityPage()),
  ),
  GoRoute(
    path: SystemPaths.bottomBar,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeBottomBarPage()),
  ),
  GoRoute(
    path: SystemPaths.homeSentence,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeHomeSentencePage()),
  ),
  GoRoute(
    path: SystemPaths.notification,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeNotificationPage()),
  ),
  GoRoute(
    path: SystemPaths.background,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ThemeBackgroundPage()),
  ),
  GoRoute(
    path: SystemPaths.fontFamily,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const FontFamilyPage()),
  ),
  GoRoute(
    path: SystemPaths.fontSize,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const FontSizePage()),
  ),

  GoRoute(
    path: SystemPaths.foregroundBackground,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const SettingsBackgroundPage()),
  ),
  GoRoute(
    path: SystemPaths.language,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const SettingsLanguagePage()),
  ),

  GoRoute(
    path: SystemPaths.developer,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const DeveloperPage()),
  ),
  GoRoute(
    path: SystemPaths.sponsor,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const SponsorPage()),
  ),
  GoRoute(
    path: SystemPaths.appUpdate,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const AppUpdatePage()),
  ),

  // Retained pages.
  GoRoute(
    path: SystemPaths.ipQuality,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const IpQualityPage()),
  ),
  GoRoute(
    path: SystemPaths.editor,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const EditorPage()),
  ),
  GoRoute(
    path: SystemPaths.scan,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ScanPage()),
  ),

  // Demo pages.
  GoRoute(
    path: SystemPaths.demo,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const DemoPage()),
  ),
  GoRoute(
    path: SystemPaths.formDemo,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const FormsDemoPage()),
  ),
  GoRoute(
    path: SystemPaths.formListEditor,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ListEditorDemoPage()),
  ),
  GoRoute(
    path: SystemPaths.formMapEdit,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const MapEditDemoPage()),
  ),
  GoRoute(
    path: SystemPaths.formNamedUrl,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const NamedUrlPage()),
  ),
  GoRoute(
    path: SystemPaths.formSelection,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const SelectionDemoPage()),
  ),
  GoRoute(
    path: SystemPaths.formRulePreset,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const RulePresetPage()),
  ),
];
