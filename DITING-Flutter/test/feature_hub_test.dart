import 'package:diting/data/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards feature-hub visibility: hidden cards drop their category, fixed cards stay
void main() {
  test('隐藏键唯一，一个开关只牵连一张卡片', () {
    final keys = [
      for (final category in mockFeatureCategories)
        for (final card in category.cards)
          if (card.featureKey != null) card.featureKey!,
    ];
    expect(keys, isNotEmpty);
    expect(keys.toSet().length, keys.length);
  });

  test('隐藏卡片后分类为空时整类消失，固定卡始终保留', () {
    final hidden = {
      for (final card in mockFeatureCategories.first.cards)
        if (card.featureKey != null) card.featureKey!,
    };
    final categories = visibleFeatureCategories(
      express: false,
      hiddenKeys: hidden,
    );
    expect(categories.any((category) => category.title == 'DNS 服务'), isFalse);
    expect(categories.length, mockFeatureCategories.length - 1);

    final allHidden = {
      for (final card in mockFeatureCategories.expand(
        (category) => category.cards,
      ))
        if (card.featureKey != null) card.featureKey!,
    };
    final onlyFixed = visibleFeatureCategories(
      express: false,
      hiddenKeys: allHidden,
    );
    expect(onlyFixed.length, 1);
    expect(onlyFixed.single.cards.single.title, '隐藏功能');
  });
}
