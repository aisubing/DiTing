import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/profiles/quick_edit_sheet.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 自定义配置总览（上游 `views/profiles/custom/custom.dart`，621 行）。
///
/// 上游是一串「入口行 + 状态文字」：节点、组、规则、提供者、拨号器，每行右侧
/// 显示条数或问题数。这里保留这个结构，并把它拆成两张卡：
/// - 第一张 = 五个数据入口（数量）；
/// - 第二张 = 快速编辑与导入（动作）。
///
/// 拆卡而不是一张长列表：入口行和动作行点下去的后果不同（前者进子页、后者
/// 直接改数据），混排时用户点错一次就可能覆盖整份配置。
class CustomProfilePage extends ConsumerWidget {
  const CustomProfilePage({super.key, required this.profileId});

  final String profileId;

  MockProfile? _profileOf(WidgetRef ref) {
    for (final profile in ref.watch(profilesProvider).profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = _profileOf(ref);
    final proxies = ref.watch(customProxiesProvider);
    final groups = ref.watch(proxyGroupsProvider);
    final rules = ref.watch(customRulesProvider);
    final proxyProviders = ref.watch(proxyProvidersProvider);
    final ruleProviders = ref.watch(ruleProvidersProvider);
    final dialers = ref.watch(dialersProvider);
    final colorScheme = context.colorScheme;
    final issueCount = _issueCount(
      proxies: proxies,
      groups: groups,
      rules: rules,
      dialers: dialers,
    );
    return CommonScaffold(
      title: profile?.name ?? '自定义配置',
      titleMenuItems: [
        CommonPopupMenuItem(
          label: '重命名',
          glyph: AppGlyphs.textShort,
          onPressed: () => _rename(context, ref, profile),
        ),
        CommonPopupMenuItem(
          label: '查看运行配置',
          glyph: AppGlyphs.eye,
          onPressed: () => context.push(ProfilesPaths.previewOf(profileId)),
        ),
      ],
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.edit,
          tooltip: '快速编辑',
          onPressed: () => _quickEdit(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(label: '节点', value: '${proxies.length}'),
                  StatItem(
                    label: '代理组',
                    value: '${groups.length}',
                    color: colorScheme.primary,
                  ),
                  StatItem(label: '规则', value: '${rules.length}'),
                  if (issueCount > 0)
                    StatItem(
                      label: '待修复',
                      value: '$issueCount',
                      color: colorScheme.error,
                    ),
                ],
              ),
            ),
          ),
          if (issueCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _IssueBanner(count: issueCount),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: generateSection(
              title: '配置内容',
              items: [
                _EntryRow(
                  glyph: AppGlyphs.proxies,
                  title: '节点',
                  subtitle: '自建节点：协议、地址、端口与传输参数',
                  count: proxies.length,
                  onTap: () => context.push(ProfilesPaths.proxiesOf(profileId)),
                ),
                _EntryRow(
                  glyph: AppGlyphs.layers,
                  title: '代理组',
                  subtitle: '手动选择、自动测速、故障转移与负载均衡',
                  count: groups.length,
                  onTap: () => context.push(ProfilesPaths.groupsOf(profileId)),
                ),
                _EntryRow(
                  glyph: AppGlyphs.rules,
                  title: '规则',
                  subtitle: '按顺序匹配，最后一条通常落到 MATCH',
                  count: rules.length,
                  badge: _badgeOf(
                    rules.where((rule) => !rule.disabled).length,
                    '启用',
                  ),
                  onTap: () => context.push(ProfilesPaths.rulesOf(profileId)),
                ),
                _EntryRow(
                  glyph: AppGlyphs.resources,
                  title: '提供者',
                  subtitle: '远程拉取节点集与规则集',
                  count: proxyProviders.length + ruleProviders.length,
                  onTap: () =>
                      context.push(ProfilesPaths.providersOf(profileId)),
                ),
                _EntryRow(
                  glyph: AppGlyphs.link,
                  title: '拨号器',
                  subtitle: '把出站请求串到另一个节点或组之后再发出',
                  count: dialers.length,
                  onTap: () => context.push(ProfilesPaths.dialersOf(profileId)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: generateSection(
              title: '动作',
              items: [
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.compose),
                  title: const Text('快速编辑'),
                  subtitle: const Text('用文本编辑规则与节点，按格式校验后整体应用'),
                  trailing: const DisclosureIndicator(),
                  onTap: () => _quickEdit(context, ref),
                ),
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.importFile),
                  title: const Text('导入配置片段'),
                  subtitle: const Text('粘贴 YAML，替换当前节点与规则'),
                  trailing: const DisclosureIndicator(),
                  onTap: () => _import(context, ref),
                ),
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.eye),
                  title: const Text('查看运行配置'),
                  subtitle: const Text('合并后的完整 YAML（只读）'),
                  trailing: const DisclosureIndicator(),
                  onTap: () => context.push(ProfilesPaths.previewOf(profileId)),
                ),
              ],
              footer: '快速编辑与导入都会整体替换，导入前会先让你确认。',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '这份档案不依赖订阅：节点与规则都在本地维护，更新时不会覆盖。',
                style: context.listCaptionStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _badgeOf(int count, String label) =>
      count == 0 ? null : '$count $label';

  /// 问题计数：节点名空、组没有成员、规则内容空、拨号器指向不存在的节点。
  ///
  /// 判据集中在这里而不是让每个子页各算一遍：总览的数字必须和子页顶部的
  /// 数字对得上，否则用户点进去会发现「说 2 个问题，里面一个也没有」。
  int _issueCount({
    required List<MockProxy> proxies,
    required List<MockProxyGroup> groups,
    required List<MockCustomRule> rules,
    required Map<String, String> dialers,
  }) {
    final names = {for (final proxy in proxies) proxy.name};
    final groupNames = {for (final group in groups) group.name};
    return proxies.where((proxy) => proxy.server.isEmpty).length +
        groups.where((group) => group.members.isEmpty).length +
        rules.where((rule) => rule.content.isEmpty).length +
        dialers.values
            .where(
              (target) =>
                  !names.contains(target) && !groupNames.contains(target),
            )
            .length;
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    MockProfile? profile,
  ) async {
    if (profile == null) {
      return;
    }
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '重命名档案',
        value: profile.name,
        selectAll: true,
        validator: (value) => (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name == null) {
      return;
    }
    ref
        .read(profilesProvider.notifier)
        .update(
          profileId,
          name: name,
          url: profile.url,
          autoUpdate: profile.autoUpdate,
          userAgent: profile.userAgent,
        );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final text = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '导入配置片段',
        value: '',
        hintText: 'proxies:\n  - name: …',
        validator: (value) => (value ?? '').trim().isEmpty ? '内容不能为空' : null,
      ),
    );
    if (text == null || !context.mounted) {
      return;
    }
    if (!text.contains('proxies:') && !text.contains('rules:')) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('没有找到 proxies 或 rules 段'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 2000),
        ),
      );
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('演示版不解析 YAML，导入只做了格式检查'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  void _quickEdit(BuildContext context, WidgetRef ref) {
    showQuickEditSheet(
      context: context,
      ref: ref,
      profileId: profileId,
      title: '快速编辑规则',
      kind: QuickEditKind.rules,
    );
  }
}

/// 入口行：图标 + 标题 + 说明 + 数量 + 箭头。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.badge,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(glyph, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: context.listCaptionStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            badge ?? '$count',
            style: context.listSubtitleStyle.copyWith(
              fontFamily: 'JetBrainsMono',
              color: count == 0
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
            ),
          ),
          const DisclosureIndicator(),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 问题提示条：总览顶部的一条，点进去看具体项。
class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.errorContainer,
        shape: AppShape.md,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          spacing: 8,
          children: [
            GlyphIcon(
              AppGlyphs.warning,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
            Expanded(
              child: Text(
                '有 $count 项内容不完整，运行时会被内核忽略',
                style: context.listCaptionStyle.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
