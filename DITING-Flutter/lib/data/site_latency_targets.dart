/// Domestic sites probed by the site-latency card: foreign sites time out without a proxy, and
/// domains let the CDN map each to a nearby node.
library;

import 'package:diting/ui/icons/icons.dart';

class SiteLatencyTarget {
  const SiteLatencyTarget({
    required this.id,
    required this.name,
    required this.host,
    required this.glyph,
  });

  final String id;

  final String name;

  final String host;

  final Glyph glyph;
}

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
