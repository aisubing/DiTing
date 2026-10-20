/// 网络工具：测速 / Ping / DNS 查询 / 路由追踪四个入口。
///
/// 四个工具共用一个页面而不是四个路由：它们的操作模型完全相同（填一个目标 →
/// 跑一次 → 看结果），合并后用户换工具不需要退回上一级。上游也是同一屏里的
/// 四个 pager 页（`docs/refactor/06-settings-network-agent.md` §4）。
///
/// 面板全部走 `showSheet`：工具是「临时用一下」的动作，做成独立路由会留下
/// 一串返回栈，而结果也没有长期保留的价值。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'tools_panels.dart';

/// 一个工具入口。
class _ToolEntry {
  const _ToolEntry({
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final Glyph glyph;
  final WidgetBuilder builder;
}

/// 网络工具页。
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final providers = ref.watch(dnsProviderCatalogProvider);
    final entries = <_ToolEntry>[
      _ToolEntry(
        title: '网络测速',
        subtitle: '下行 / 上行 / 延迟一次测完',
        glyph: AppGlyphs.speed,
        builder: (_) => const _SpeedTestPanel(),
      ),
      _ToolEntry(
        title: 'Ping',
        subtitle: '探测目标可达性与往返延迟',
        glyph: AppGlyphs.connections,
        builder: (_) => const _PingPanel(),
      ),
      _ToolEntry(
        title: 'DNS 查询',
        subtitle: '按服务商查询 A / AAAA / CNAME / TXT',
        glyph: AppGlyphs.dns,
        builder: (_) => const _DnsLookupPanel(),
      ),
      _ToolEntry(
        title: '路由追踪',
        subtitle: '逐跳查看到达目标的路径',
        glyph: AppGlyphs.layers,
        builder: (_) => const _TraceroutePanel(),
      ),
    ];

    return CommonScaffold(
      title: '网络工具',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '当前解析',
                    value: '${mockServiceStats.averageLatencyMs}',
                    unit: 'ms',
                    color: colorScheme.success,
                  ),
                  StatItem(
                    label: '服务商',
                    value: '${providers.length}',
                    unit: '个',
                  ),
                  StatItem(label: '运行时长', value: mockServiceStats.uptimeLabel),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              child: ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: const Text('工具走本机解析链路'),
                subtitle: const Text(
                  '演示版不会真正发包，结果由内置样例生成；真实实现里这些请求会经过当前解析服务商。',
                ),
              ),
            ),
          ),
          for (final entry in entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CommonCard(
                onPressed: () => showSheet<void>(
                  context: context,
                  builder: entry.builder,
                ),
                child: ListItem(
                  leading: GlyphIcon(entry.glyph, size: 22),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
                  onTap: () => showSheet<void>(
                    context: context,
                    builder: entry.builder,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 面板共用的服务商选择行。
///
/// 用横向 chip 而不是六行列表：面板是底部弹层，六行列表会把「发起查询」按钮
/// 挤出首屏，用户得先滚一下才能触发——而换服务商是次要操作。
class _ProviderChips extends ConsumerWidget {
  const _ProviderChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final providers = ref.watch(dnsProviderCatalogProvider);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: providers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final provider = providers[index];
          final selected = provider.id == value;
          return TonalChip(
            label: provider.name,
            color: selected
                ? colorScheme.primary
                : context.raisedSurfaceLevel.colorOf(colorScheme),
            foregroundColor: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            onPressed: () => onChanged(provider.id),
          );
        },
      ),
    );
  }
}

/// 面板共用的输入行外框。
///
/// `FilledInputTheme` 而不是裸 `TextField`：设计系统里独立出现的输入框统一是
/// 填充圆角，裸框会退回 Material 默认的描边样式，和卡片叠在一起很突兀。
class _ToolField extends StatelessWidget {
  const _ToolField({
    required this.controller,
    required this.hintText,
    required this.glyph,
  });

  final TextEditingController controller;
  final String hintText;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    return FilledInputTheme(
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: GlyphIcon(glyph),
        ),
      ),
    );
  }
}
