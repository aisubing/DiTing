import 'package:diting/pages/profiles/add_profile_page.dart';
import 'package:diting/pages/profiles/custom_dialers_page.dart';
import 'package:diting/pages/profiles/custom_profile_page.dart';
import 'package:diting/pages/profiles/custom_providers_page.dart';
import 'package:diting/pages/profiles/custom_proxies_page.dart';
import 'package:diting/pages/profiles/custom_rules_page.dart';
import 'package:diting/pages/profiles/edit_profile_page.dart';
import 'package:diting/pages/profiles/extend_page.dart';
import 'package:diting/pages/profiles/group_edit_page.dart';
import 'package:diting/pages/profiles/group_members_page.dart';
import 'package:diting/pages/profiles/icon_picker_page.dart';
import 'package:diting/pages/profiles/profile_preview_page.dart';
import 'package:diting/pages/profiles/profiles_page.dart';
import 'package:diting/pages/profiles/proxy_groups_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 配置档案领域路由（上游 `lib/views/profiles/`）。
///
/// 上游 15 个文件分三层：配置网格 → 配置编辑 / 自定义配置 → 自定义子项
/// （节点 / 组 / 规则 / 提供者 / 拨号器 / 图标）。
///
/// 带 id 的页面一律把 id 放路径参数里，而不是 `extra`：`extra` 只在 push 时
/// 存在，刷新或深链会拿到 null，而这些页面（编辑、自定义配置）都必须能重建。
abstract final class ProfilesPaths {
  static const profiles = '/profiles';
  static const add = '/profiles/add';

  /// 二级页面模板；用下面的 `editOf` 这类方法拼具体地址。
  static const edit = '/profiles/edit';
  static const preview = '/profiles/preview';

  static const custom = '/profiles/custom';
  static const customProxies = '$custom/proxies';
  static const customGroups = '$custom/groups';
  static const customRules = '$custom/rules';
  static const customProviders = '$custom/providers';
  static const customDialers = '$custom/dialers';
  static const customIcon = '$custom/icon';

  static const extend = '/profiles/extend';
  static const extendScript = '$extend/script';

  static String editOf(String id) => '$edit/$id';
  static String previewOf(String id) => '$preview/$id';
  static String customOf(String id) => '$custom/$id';
  static String proxiesOf(String id) => '$custom/$id/proxies';
  static String groupsOf(String id) => '$custom/$id/groups';
  static String groupEditOf(String id, String groupId) =>
      '$custom/$id/groups/$groupId/edit';
  static String groupMembersOf(String id, String groupId) =>
      '$custom/$id/groups/$groupId/members';
  static String rulesOf(String id) => '$custom/$id/rules';
  static String providersOf(String id) => '$custom/$id/providers';
  static String dialersOf(String id) => '$custom/$id/dialers';
  static String iconOf(String id, {String? current}) => current == null
      ? '$custom/$id/icon'
      : '$custom/$id/icon?current=${Uri.encodeQueryComponent(current)}';
  static String extendOf(String id) => '$extend/$id';
}

/// 配置档案领域路由表。由 `lib/router.dart` 拼接。
List<RouteBase> profilesRoutes() => [
  GoRoute(
    path: ProfilesPaths.profiles,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ProfilesPage(),
  ),
  GoRoute(
    path: ProfilesPaths.add,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AddProfilePage(),
  ),
  GoRoute(
    path: '${ProfilesPaths.edit}/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        EditProfilePage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.preview}/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        ProfilePreviewPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        CustomProfilePage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/proxies',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        CustomProxiesPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/groups',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        ProxyGroupsPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/groups/:groupId/edit',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => GroupEditPage(
      profileId: state.pathParameters['id'] ?? '',
      groupId: state.pathParameters['groupId'] ?? '',
    ),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/groups/:groupId/members',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => GroupMembersPage(
      profileId: state.pathParameters['id'] ?? '',
      groupId: state.pathParameters['groupId'] ?? '',
    ),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/rules',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        CustomRulesPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/providers',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        CustomProvidersPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/dialers',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        CustomDialersPage(profileId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '${ProfilesPaths.custom}/:id/icon',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => IconPickerPage(
      profileId: state.pathParameters['id'] ?? '',
      current: state.uri.queryParameters['current'],
    ),
  ),
  GoRoute(
    path: '${ProfilesPaths.extend}/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        ExtendPage(profileId: state.pathParameters['id'] ?? ''),
  ),
];
