/// 覆写编辑器（上游 `views/config/override.dart`，695 行）。
///
/// 上游没有把「覆写」做成一个独立入口：它是四个页面（TUN / DNS / NTP / 嗅探）
/// 共用的一套视图基类。本仓的路由表里有 `/config/override` 这一项，所以这一页
/// 做成「覆写总览」：四条入口 + 五类字段类型的说明。
///
/// 说明部分不是装饰：覆写页里同一行可能是开关、可能是列表，用户第一次点进去
/// 常常不知道「为什么这一项没有输入框」。把字段类型先讲清楚，四个页面就不用各
/// 自解释一遍。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 覆写总览页。
class OverrideConfigPage extends StatelessWidget {
  const OverrideConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '覆写',
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '覆写是「只改这一项，其余照抄订阅」：挑一个键、给一个值，'
                '整份配置里同名的字段就以这里为准。清空值等于取消这一项的覆写。',
            glyph: AppGlyphs.sliders,
          ),
          generateSection(
            title: '可覆写的页面',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.layers,
                title: 'TUN 覆写',
                subtitle: 'MTU、栈、路由网段、接口与端口过滤',
                onPressed: () => context.push(ConfigPaths.tun),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.dns,
                title: 'DNS 覆写',
                subtitle: '服务商、增强模式、缓存与策略表',
                onPressed: () => context.push(ConfigPaths.dns),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.clock,
                title: 'NTP 覆写',
                subtitle: '对时服务器、间隔与写回系统',
                onPressed: () => context.push(ConfigPaths.ntp),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.target,
                title: '嗅探覆写',
                subtitle: '嗅探开关、名单与三个协议的端口',
                onPressed: () => context.push(ConfigPaths.sniffer),
              ),
            ],
            footer:
                '四个页面结构一致：顶部一句说明，下面是按键名分组的条目；'
                '右上角加号挑键，compose 图标快速编辑。',
          ),
          generateSection(
            title: '五类字段',
            items: [
              for (final kind in OverrideFieldKind.values)
                ListItem(
                  leading: GlyphIcon(_glyphOf(kind), size: 20),
                  title: Text(kind.label),
                  subtitle: Text(kind.description),
                ),
            ],
            footer:
                '同一种控件在所有覆写页里长相一致：'
                '这是「一眼能认出这是什么类型」的前提。',
          ),
        ],
      ),
    );
  }
}

Glyph _glyphOf(OverrideFieldKind kind) => switch (kind) {
  OverrideFieldKind.toggle => AppGlyphs.toggle,
  OverrideFieldKind.options => AppGlyphs.caretDown,
  OverrideFieldKind.number => AppGlyphs.speed,
  OverrideFieldKind.text => AppGlyphs.edit,
  OverrideFieldKind.list => AppGlyphs.layers,
};
