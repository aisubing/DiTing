/// 资源入口页：图标集 / User-Agent / 按需连接。
///
/// 上一轮这里还挂着「自定义代理 / Clash 提供者 / 过滤器」三行——那三项属于
/// FlClash 的代理内核，1.4.3 没有对应物，已随内核配置族一并删除。
///
/// 剩下三张表都不是旧版界面，属于用户要求保留的项。它们没有旧版入口，因此
/// 统一收在这一页，由 `/developer` 聚合页进入；设置页与功能中心不出现它们，
/// 以免把旧版的 6 行设置与 28 张卡片挤变形。
library;

import 'package:diting/pages/config/config_common.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 自定义资源入口页。
class CustomResourcesConfigPage extends StatelessWidget {
  const CustomResourcesConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '自定义资源',
      body: PageBody(
        children: [
          const ConfigNoteCard(
            text:
                '这些资源按名字被引用：改名字等于断开引用，改内容则在下一次'
                '加载配置时生效。它们不属于旧版 1.4.3 的界面，保留在此供调试使用。',
            glyph: AppGlyphs.resources,
          ),
          generateSection(
            title: '资源',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.photos,
                title: '图标集',
                subtitle: '分组卡片用的图标映射',
                onPressed: () => context.push(ConfigPaths.iconSets),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.account,
                title: 'User-Agent',
                subtitle: '订阅下载与测速请求携带的 UA',
                onPressed: () => context.push(ConfigPaths.userAgents),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.wifi,
                title: '按需连接',
                subtitle: '按 SSID 决定是否启动 VPN',
                onPressed: () => context.push(ConfigPaths.onDemand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
