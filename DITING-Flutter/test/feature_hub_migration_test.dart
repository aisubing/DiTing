import 'package:diting/data/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the feature-hub migration counts measured on upstream `FeatureHubScreen.kt`
void main() {
  test('normal 模式：7 类 28 卡，隐藏键唯一', () {
    expect(mockFeatureCategories.length, 7);
    final cards = [
      for (final category in mockFeatureCategories) ...category.cards,
    ];
    expect(cards.length, 28);
    final keys = [
      for (final card in cards)
        if (card.featureKey != null) card.featureKey!,
    ];
    expect(keys.length, 27);
    expect(keys.toSet().length, keys.length);
    expect(cards.where((card) => card.isFixed).length, 1);
    expect(cards.firstWhere((card) => card.isFixed).title, '隐藏功能');
  });

  test('normal 模式：分类标题与卡片顺序对齐旧版', () {
    expect(
      [for (final category in mockFeatureCategories) category.title],
      ['DNS 服务', '策略与规则', '网络控制', '高级与诊断', '界面与设置', '数据与维护', '关于谛听'],
    );
    expect(
      [
        for (final category in mockFeatureCategories)
          for (final card in category.cards) card.title,
      ],
      [
        '服务商管理', '引导解析设置', '解析模式', '缓存设置',
        '规则控制', '黑名单', '白名单', '覆写名单',
        '应用流量统计', '应用独立规则', '禁止联网应用', '排除应用',
        'HTTPS 流量检查', '出站代理', '网络诊断', 'AI 分析',
        '外观调整', '服务显示', '隐藏功能', '其他设置',
        '日志', '备份与迁移', '数据清理', '更新与支持',
        '应用信息', '赞助', '赞助者名单', '共建者名单',
      ],
    );
  });

  test('express 模式：5 类 19 卡，18 项可隐藏', () {
    final categories = visibleFeatureCategories(
      express: true,
      hiddenKeys: const {},
    );
    expect(categories.length, 5);
    expect(
      [
        for (final category in categories) ...[
          category.title,
          ...category.cards.map((card) => card.title),
        ],
      ],
      [
        'DNS 服务', '服务商管理', '引导解析设置', '解析模式', '缓存设置',
        '策略与规则', '规则控制', '黑名单', '白名单',
        '界面与设置', '外观调整', '服务显示', '隐藏功能', '其他设置',
        '数据与维护', '日志', '备份与迁移', '数据清理', '更新与支持',
        '关于谛听', '应用信息', '赞助', '赞助者名单', '共建者名单',
      ],
    );
    expect(mockHiddenFeatures.where((feature) => feature.expressVisible).length, 18);
    expect(hiddenFeaturesByCategory(express: true).values.expand((e) => e).length, 18);
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
    expect(categories.length, 6);

    final allHidden = {
      for (final card in mockFeatureCategories.expand((category) => category.cards))
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
