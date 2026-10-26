/// Site categories for the site-latency card and its detail page, plus the card's slot count.
///
/// Order here is the order the detail page stacks its groups.
library;

import 'package:diting/ui/icons/icons.dart';

/// The dashboard card draws a 2x2 grid, so the user picks exactly this many sites.
const dashboardSiteCount = 4;

enum SiteCategory {
  search('搜索', AppGlyphs.search),
  shopping('购物', AppGlyphs.star),
  video('视频', AppGlyphs.photos),
  music('音乐', AppGlyphs.motion),
  social('社交', AppGlyphs.account),
  developer('开发者', AppGlyphs.code),
  game('游戏', AppGlyphs.puzzle);

  const SiteCategory(this.label, this.glyph);

  final String label;

  /// Section header glyph; the board's own icons carry the brand, these carry the topic.
  final Glyph glyph;
}
