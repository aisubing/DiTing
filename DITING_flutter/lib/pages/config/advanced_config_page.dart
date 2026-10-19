/// 高级配置页（上游 `views/config/advanced.dart`，52 行）。
///
/// 上游这一页只有四个入口：网络、DNS、追加规则、脚本。本仓保留同样的四个入口，
/// 另外补上「覆写编辑器」——上游没有单独一页覆写编辑器，但本仓有
/// `/config/override` 这个路由常量，正好用它承载「五类字段类型」的演示。
library;

import 'package:diting/pages/config/config_common.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 高级配置入口页。
class AdvancedConfigPage extends StatelessWidget {
  const AdvancedConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '高级',
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '这里放的都不是「打开就能用」的开关：'
                '它们要么直接改写内核配置，要么会改变分流结果。',
            glyph: AppGlyphs.wrench,
          ),
          generateSection(
            title: '内核',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.key,
                title: '网络',
                subtitle: 'VPN、TUN、接口与出站选项',
                onPressed: () => context.push(ConfigPaths.network),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.dns,
                title: 'DNS',
                subtitle: '服务商、增强模式与策略表',
                onPressed: () => context.push(ConfigPaths.dns),
              ),
            ],
          ),
          generateSection(
            title: '规则',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.rules,
                title: '追加规则',
                subtitle: '手动写规则，顺序决定优先级',
                onPressed: () => context.push(ConfigPaths.rules),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.sliders,
                title: '覆写编辑器',
                subtitle: '逐键覆写 TUN、DNS、NTP 与嗅探',
                onPressed: () => context.push(ConfigPaths.override),
              ),
            ],
          ),
          generateSection(
            title: '配置加载',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.code,
                title: '脚本',
                subtitle: '在配置加载前改写整份配置',
                onPressed: () => context.push(ConfigPaths.scripts),
              ),
            ],
            footer: '这些改动只作用于当前配置；切换配置后需要重新设置。',
          ),
        ],
      ),
    );
  }
}
