/// 自定义资源页（上游 `views/config/custom_resources.dart`，48 行）。
///
/// 上游四个入口：自定义代理、规则提供者、过滤器、图标集。其中「自定义代理」的
/// 实现（`CustomProxiesView`）不在配置域，它挂在配置档案下、需要 `profileId`
/// 才能打开（`/profiles/custom/:id/proxies`）。
///
/// 本仓的处理：这一行指向配置档案列表，由用户在那里选一份配置再进自定义节点。
/// 直接把 `:id` 写成一个假值会打开一份不存在的配置——那比不提供入口更糟。
library;

import 'package:diting/pages/config/config_common.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/routes/profiles_routes.dart';
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
          ConfigNoteCard(
            text:
                '这些资源都按名字被规则或分组引用：改名字等于断开引用，'
                '改内容则下一次加载配置时生效。',
            glyph: AppGlyphs.resources,
          ),
          generateSection(
            title: '资源',
            items: [
              ConfigEntryRow(
                glyph: AppGlyphs.proxies,
                title: '自定义代理',
                subtitle: '属于某一份配置：先选配置再编辑节点',
                onPressed: () => context.push(ProfilesPaths.profiles),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.resources,
                title: 'Clash 提供者',
                subtitle: '远程规则集，按更新间隔拉取',
                onPressed: () => context.push(ConfigPaths.providers),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.filter,
                title: '过滤器',
                subtitle: '折叠日志与连接列表里的噪声',
                onPressed: () => context.push(ConfigPaths.filters),
              ),
              ConfigEntryRow(
                glyph: AppGlyphs.photos,
                title: '图标集',
                subtitle: '分组卡片用的图标映射',
                onPressed: () => context.push(ConfigPaths.iconSets),
              ),
            ],
            footer:
                '「自定义代理」不在本域：它需要配置 id，'
                '所以这里只负责把你送到配置档案列表。',
          ),
          generateSection(
            title: '其他',
            items: [
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
