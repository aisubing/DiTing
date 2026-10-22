import 'dart:typed_data';

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/recognition/recognition_members.dart';
import 'package:diting/data/recognition/recognition_repository.dart';
import 'package:diting/pages/hub/recognition_common.dart';
import 'package:diting/state/recognition_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';
import 'support/test_hooks.dart';

/// 名单页的显示守门。
///
/// 这一轮修的核心缺陷是「头像根本不是图片，而是昵称首字拼的彩色圆圈」，
/// 光看「页面能构建」的旧测试是发现不了的——所以这里断言：每一行都渲染了
/// [RecognitionAvatar]、排序按钮能真的反转顺序，以及拿不到头像字节时
/// 画的是人形占位而不是字母圆圈。
void main() {
  installGlobalTestHooks();

  const members = RecognitionMembers(
    version: 7,
    sponsors: [
      RecognitionMember(name: '甲', avatarFileName: 'a_avatar.jpg'),
      RecognitionMember(name: '乙'),
      RecognitionMember(name: '丙', avatarFileName: 'c_avatar.jpg'),
    ],
    coBuilders: [
      RecognitionMember(name: 'Ace', avatarFileName: 'ace_avatar.jpg'),
      RecognitionMember(name: 'Bob'),
    ],
  );

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appTestOverrides(),
          recognitionRepositoryProvider.overrideWithValue(
            _FakeRepository(members: members),
          ),
        ],
        child: AppHost(size: const Size(390, 844), child: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('赞助者名单：每行都有头像组件，默认按数组顺序', (tester) async {
    await pumpPage(
      tester,
      const RecognitionListPage(
        title: '赞助者名单',
        intro: '说明',
        sectionTitle: '赞助者',
        select: _sponsors,
        sortable: true,
      ),
    );

    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('丙'), findsOneWidget);
    expect(
      tester.widgetList<RecognitionAvatar>(find.byType(RecognitionAvatar)).length,
      3,
    );

    // 顺序：甲 → 乙 → 丙（顶到底）。
    final firstY = tester.getTopLeft(find.text('甲')).dy;
    final lastY = tester.getTopLeft(find.text('丙')).dy;
    expect(firstY, lessThan(lastY));
  });

  testWidgets('拿不到头像字节时用人形占位，而不是字母圆圈', (tester) async {
    await pumpPage(
      tester,
      const RecognitionListPage(
        title: '赞助者名单',
        intro: '说明',
        sectionTitle: '赞助者',
        select: _sponsors,
        sortable: true,
      ),
    );

    // 假仓库永远返回 null 字节，因此三行都应落到占位 glyph。
    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RecognitionAvatar),
        matching: find.byType(GlyphIcon),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('排序按钮把名单反转为由晚到早', (tester) async {
    await pumpPage(
      tester,
      const RecognitionListPage(
        title: '赞助者名单',
        intro: '说明',
        sectionTitle: '赞助者',
        select: _sponsors,
        sortable: true,
      ),
    );

    await tester.tap(find.byTooltip('切换为由晚到早'));
    await tester.pumpAndSettle();

    final firstY = tester.getTopLeft(find.text('甲')).dy;
    final lastY = tester.getTopLeft(find.text('丙')).dy;
    expect(firstY, greaterThan(lastY));
  });

  testWidgets('共建者名单没有排序按钮', (tester) async {
    await pumpPage(
      tester,
      const RecognitionListPage(
        title: '共建者名单',
        intro: '说明',
        sectionTitle: '共建者',
        select: _coBuilders,
      ),
    );

    expect(find.byTooltip('切换为由晚到早'), findsNothing);
    expect(find.text('Ace'), findsOneWidget);
  });
}

List<RecognitionMember> _sponsors(RecognitionMembers value) => value.sponsors;

List<RecognitionMember> _coBuilders(RecognitionMembers value) =>
    value.coBuilders;

/// 内存仓库：不碰网络、不碰 prefs、不碰原生缓存，只为验证渲染与交互。
class _FakeRepository extends RecognitionMembersRepository {
  _FakeRepository({required this.members})
    : super(store: MemoryLegacyPrefsStore());

  final RecognitionMembers members;

  @override
  RecognitionMembers? loadCached() => members;

  @override
  Future<RecognitionMembers?> refresh() async => members;

  @override
  Future<Uint8List?> loadAvatarBytes(String avatarFileName) async => null;
}
