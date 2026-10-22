/// 站点测速卡要测的国内站点。
///
/// 只放四家**国内常用**站点，理由与卡片文案一致：这张卡回答的是「现在上网顺不顺」，
/// 测国外站点在无代理的国内网络下会稳定超时，四个红点看不出任何信息。
///
/// 目标写域名而不是 IP：CDN 会把同一个域名解析到就近节点，写死 IP 等于测了另一台
/// 机器；延迟测量本身由原生 `ping` 完成，域名解析失败会如实报成「失败」。
///
/// 徽标用品牌标识而不是文字缩写（FlClash 的 `_ServiceBadge` 也是放
/// `assets/images/services/*.svg`）：四个汉字的缩写（百 / 抖 / 哔 / 网）放在
/// 26dp 的方块里既挤又没有辨识度，品牌图形一眼就能认出是哪一家。
library;

import 'package:diting/ui/icons/icons.dart';

class SiteLatencyTarget {
  const SiteLatencyTarget({
    required this.id,
    required this.name,
    required this.host,
    required this.glyph,
  });

  /// 稳定标识，用于结果表与测试断言。
  final String id;

  /// 展示名。
  final String name;

  /// 被探测的域名。
  final String host;

  /// 徽标里的品牌标识。
  final Glyph glyph;
}

/// 卡片与详情浮层共用的目标表。
const siteLatencyTargets = <SiteLatencyTarget>[
  SiteLatencyTarget(
    id: 'baidu',
    name: '百度',
    host: 'www.baidu.com',
    glyph: AppGlyphs.baidu,
  ),
  SiteLatencyTarget(
    id: 'douyin',
    name: '抖音',
    host: 'www.douyin.com',
    glyph: AppGlyphs.douyin,
  ),
  SiteLatencyTarget(
    id: 'bilibili',
    name: '哔哩哔哩',
    host: 'www.bilibili.com',
    glyph: AppGlyphs.bilibili,
  ),
  SiteLatencyTarget(
    id: 'netease',
    name: '网易云音乐',
    host: 'music.163.com',
    glyph: AppGlyphs.neteaseMusic,
  ),
];
