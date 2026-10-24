import 'package:diting/app/app.dart';
import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/router.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// Leaving an app picker with pending changes asks whether to save them. The title-bar arrow, the
/// system back gesture and the hardware key all land on the same dialog.
void main() {
  installGlobalTestHooks();

  late MemoryLegacyPrefsStore store;

  Future<void> pumpPicker(WidgetTester tester, String cardTitle) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    store = MemoryLegacyPrefsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appTestOverrides(),
          legacyPrefsStoreProvider.overrideWithValue(store),
          installedAppsSourceProvider.overrideWithValue(_FakeAppsSource()),
        ],
        child: DitingApp(initialLocation: Routes.hub),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    // Open the picker from the hub, so the route really has a page below it and the bar draws a
    // back arrow (an initial route would not).
    final card = find.text(cardTitle);
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Set<String> blocked() => LegacySettings(store).blockedAppPackages;

  /// Taps an app row; `last` skips the row count in the section heading.
  Future<void> tapApp(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// Dialog buttons only: the page has its own 保存 button and the hub a 排除应用 card, so a bare
  /// text finder would be ambiguous.
  Finder inDialog(String label) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(label));

  Future<void> leaveWith(WidgetTester tester, String button) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('保存更改？'), findsOneWidget);
    await tester.tap(inDialog(button));
    await tester.pumpAndSettle();
  }

  testWidgets('勾选后返回会先询问，只给「不保存」「保存」两个动作', (tester) async {
    await pumpPicker(tester, '禁止联网应用');
    await tapApp(tester, '地图');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('保存更改？'), findsOneWidget);
    expect(inDialog('不保存'), findsOneWidget);
    expect(inDialog('保存'), findsOneWidget);
    expect(inDialog('取消'), findsNothing);
  });

  testWidgets('点遮罩关闭弹窗视作留下，草稿不写入', (tester) async {
    await pumpPicker(tester, '禁止联网应用');
    await tapApp(tester, '地图');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // The barrier sits above and below the alert pane; the top strip is always outside it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('保存更改？'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(blocked(), isEmpty);
  });

  testWidgets('选择不保存则丢弃改动并离开', (tester) async {
    await pumpPicker(tester, '禁止联网应用');
    await tapApp(tester, '地图');
    await leaveWith(tester, '不保存');

    expect(find.byType(BackButton), findsNothing);
    expect(blocked(), isEmpty);
  });

  testWidgets('选择保存则写入后再离开', (tester) async {
    await pumpPicker(tester, '禁止联网应用');
    await tapApp(tester, '地图');
    await leaveWith(tester, '保存');

    expect(find.byType(BackButton), findsNothing);
    expect(blocked(), {'com.example.maps'});
  });

  testWidgets('没有改动时返回不弹窗', (tester) async {
    await pumpPicker(tester, '排除应用');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('保存更改？'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });
}

class _FakeAppsSource implements InstalledAppsSource {
  static const _apps = [
    InstalledApp(
      packageName: 'com.example.chat',
      label: 'Chat',
      isSystem: false,
      uid: 10102,
    ),
    InstalledApp(
      packageName: 'com.example.maps',
      label: '地图',
      isSystem: false,
      uid: 10101,
    ),
  ];

  @override
  Future<List<InstalledApp>> list() async => _apps;

  @override
  Future<Map<String, int>> resolveUids(Iterable<String> packages) async => {
    for (final app in _apps)
      if (packages.contains(app.packageName)) app.packageName: app.uid,
  };

  @override
  Future<bool> isSelf(String packageName) async => false;

  @override
  Future<Map<String, Uint8List>> loadIcons(Iterable<String> packages) async =>
      const {};
}
