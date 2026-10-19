/// 配置详情页（上游 `views/dashboard/widgets/profile_detail.dart`，349 行）。
///
/// 上游是一个 sheet，从仪表盘「配置档案」卡点进来。内容四段：
/// 四格统计（代理组/节点/规则/提供者）、订阅流量、档案元信息、外部提供者。
///
/// 上游的统计数字靠 `compute()` 在 isolate 里解析配置 YAML 得到；这里全部来自
/// `mock_profiles` 的演示数据，所以是同步的、无等待态。上游「解析失败时显示
/// 一行错误而不是空白」这种失败可见的交互值得保留——见 `_StatsGrid.failed`
/// 的落点（本页数据恒可用，故恒为 false，接口留着）。
library;

import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ProfileDetailPage extends ConsumerWidget {
  const ProfileDetailPage({super.key, this.profileId});

  /// 未指定时展示第一条档案（对应上游 `currentProfileProvider` 的「当前档案」）。
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = profileId == null
        ? (mockProfiles.isEmpty ? null : mockProfiles.first)
        : mockProfiles.where((it) => it.id == profileId).firstOrNull;
    if (profile == null) {
      return const CommonScaffold(
        title: '配置详情',
        body: NullStatus(
          label: '没有选中的配置',
          description: '先在配置档案里选一个',
          illustration: NullStatusIllustration.profile,
        ),
      );
    }

    final providers = ref.watch(proxyProvidersProvider);
    final subscription = profile.subscription;

    return CommonScaffold(
      title: profile.name,
      body: PageBody(
        children: [
          _StatsGrid(
            groups: profile.proxyCount ~/ 12,
            proxies: profile.proxyCount,
            rules: profile.ruleCount,
            providers: providers.length,
          ),
          if (subscription != null)
            generateSection(
              title: '订阅流量',
              items: [
                ListItem(
                  title: const Text('已用 / 总量'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: subscription.progress,
                        minHeight: 6,
                        backgroundColor: SurfaceLevel.inset.colorOf(
                          context.colorScheme,
                        ),
                      ),
                    ),
                  ),
                  trailing: Text(
                    '${subscription.usedGb.toStringAsFixed(1)} / '
                    '${subscription.totalGb.toStringAsFixed(0)} GB',
                    style: AppTextStyle.caption1.of(context),
                  ),
                ),
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.clock),
                  title: const Text('到期时间'),
                  trailing: Text(subscription.expireAt),
                ),
              ],
            ),
          generateSection(
            title: '档案',
            items: [
              _InfoRow(label: '最后更新', value: profile.updatedAt),
              _InfoRow(label: '类型', value: profile.kind.label),
              if (profile.url.isNotEmpty)
                _InfoRow(label: '订阅地址', value: profile.url),
              if (profile.fileName.isNotEmpty)
                _InfoRow(label: '文件', value: profile.fileName),
            ],
          ),
          if (providers.isNotEmpty)
            generateSection(
              title: '外部提供者',
              items: [
                for (final provider in providers)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.cloudSync),
                    title: Text(provider.name),
                    subtitle: Text(
                      '${provider.count} 个节点 · '
                      '${_intervalLabel(provider.intervalHours)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              footer: '外部提供者会在订阅更新时一并拉取。',
            ),
          const ListFooter(text: '演示数据：统计数字不来自真实配置解析。'),
        ],
      ),
    );
  }

  static String _intervalLabel(int hours) => switch (hours) {
    0 => '不自动更新',
    24 => '每天',
    168 => '每周',
    _ when hours % 24 == 0 => '每 ${hours ~/ 24} 天',
    _ => '每 $hours 小时',
  };
}

/// 四格统计。上游在窄屏折成两行，这里固定一行四格 + `Expanded`，
/// 320 宽下每格约 66dp，只放得下「图标 / 数字 / 两字标签」。
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.groups,
    required this.proxies,
    required this.rules,
    required this.providers,
  });

  final int groups;
  final int proxies;
  final int rules;
  final int providers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tiles = <(String, int, Glyph)>[
      ('代理组', groups, AppGlyphs.layers),
      ('节点', proxies, AppGlyphs.vpn),
      ('规则', rules, AppGlyphs.rules),
      ('提供者', providers, AppGlyphs.cloudSync),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        spacing: 8,
        children: [
          for (final (label, value, glyph) in tiles)
            Expanded(
              child: CommonCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 3,
                  children: [
                    GlyphIcon(
                      glyph,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      '$value',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption2.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1.of(context),
        ),
      ),
    );
  }
}
