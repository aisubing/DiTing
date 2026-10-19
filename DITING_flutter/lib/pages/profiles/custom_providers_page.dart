import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 提供者页（上游 `views/profiles/custom/providers.dart`，643 行）。
///
/// 上游分两段：代理提供者与规则提供者，各自可增删、可改健康检查。这里用
/// `SegmentedControl` 切成两个 tab 而不是上下堆叠：两类提供者的字段完全不同
/// （一个拉节点、一个拉规则集），放在一页里滚动会让人以为它们是同一种东西。
class CustomProvidersPage extends ConsumerStatefulWidget {
  const CustomProvidersPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<CustomProvidersPage> createState() =>
      _CustomProvidersPageState();
}

class _CustomProvidersPageState extends ConsumerState<CustomProvidersPage> {
  var _tab = 0;

  Future<void> _addProxyProvider() async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '添加代理提供者',
        value: '',
        hintText: '如：机场节点集',
        validator: (value) => (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name == null) {
      return;
    }
    ref.read(proxyProvidersProvider.notifier).addProvider(name);
  }

  Future<void> _addRuleProvider() async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '添加规则提供者',
        value: '',
        hintText: '如：广告拦截',
        validator: (value) => (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name == null) {
      return;
    }
    ref.read(ruleProvidersProvider.notifier).addNamed(name);
  }

  @override
  Widget build(BuildContext context) {
    final proxyProviders = ref.watch(proxyProvidersProvider);
    final ruleProviders = ref.watch(ruleProvidersProvider);
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '提供者',
      primaryAction: IconButtonData(
        glyph: AppGlyphs.addCircle,
        tooltip: _tab == 0 ? '添加代理提供者' : '添加规则提供者',
        onPressed: _tab == 0 ? _addProxyProvider : _addRuleProvider,
      ),
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '代理提供者',
                    value: '${proxyProviders.length}',
                    color: colorScheme.primary,
                  ),
                  StatItem(label: '规则提供者', value: '${ruleProviders.length}'),
                  StatItem(
                    label: '代理已启用',
                    value: '${proxyProviders.where((p) => p.enabled).length}',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl(
              segments: const [(0, '代理提供者'), (1, '规则提供者')],
              value: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
          const SizedBox(height: 12),
          if (_tab == 0)
            _ProxyProviderSection(
              providers: proxyProviders,
              onToggle: (id, value) => ref
                  .read(proxyProvidersProvider.notifier)
                  .toggleEnabled(id, value),
              onHealthCheck: (id, value) => ref
                  .read(proxyProvidersProvider.notifier)
                  .setHealthCheck(id, value),
            )
          else
            _RuleProviderSection(
              providers: ruleProviders,
              onRemove: (id) =>
                  ref.read(ruleProvidersProvider.notifier).remove(id),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              '提供者从远程拉取内容，节点/规则在运行时才展开。演示版只展示拉取结果'
              '的摘要，不发起真实请求。',
              style: context.listCaptionStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 代理提供者列表：每条可开关与设置健康检查。
class _ProxyProviderSection extends StatelessWidget {
  const _ProxyProviderSection({
    required this.providers,
    required this.onToggle,
    required this.onHealthCheck,
  });

  final List<MockProxyProvider> providers;
  final void Function(String id, bool value) onToggle;
  final void Function(String id, bool value) onHealthCheck;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: NullStatus(
          label: '还没有代理提供者',
          description: '添加后可以按需拉取节点集，避免整份订阅都塞进配置',
          illustration: NullStatusIllustration.proxies,
        ),
      );
    }
    final colorScheme = context.colorScheme;
    return generateSection(
      title: '代理提供者',
      items: [
        for (final provider in providers)
          ListItem(
            leading: GlyphIcon(
              provider.enabled ? AppGlyphs.cloudSync : AppGlyphs.cloudDownload,
              color: provider.enabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            title: Text(provider.name),
            subtitle: Text(
              '${provider.proxyCount} 个节点 · ${provider.updatedAt} · '
              '每 ${provider.intervalMinutes ~/ 60} 小时拉取',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.listCaptionStyle,
            ),
            trailing: CommonPopupBox(
              targetBuilder: (open) => IconButton(
                tooltip: UiLocalizations.of(context).more,
                onPressed: open,
                icon: const GlyphIcon(AppGlyphs.more),
              ),
              popupBuilder: (_) => CommonPopupMenu(
                items: [
                  CommonPopupMenuItem(
                    label: provider.enabled ? '停用' : '启用',
                    glyph: provider.enabled ? AppGlyphs.block : AppGlyphs.check,
                    onPressed: () => onToggle(provider.id, !provider.enabled),
                  ),
                  CommonPopupMenuItem(
                    label: '健康检查',
                    glyph: AppGlyphs.verified,
                    checked: provider.healthCheck,
                    onPressed: () =>
                        onHealthCheck(provider.id, !provider.healthCheck),
                  ),
                ],
              ),
            ),
          ),
      ],
      footer: '开启健康检查后，不可用的节点会被自动跳过。',
    );
  }
}

/// 规则提供者列表：每条显示类型与规则条数。
class _RuleProviderSection extends StatelessWidget {
  const _RuleProviderSection({required this.providers, required this.onRemove});

  final List<MockRuleProvider> providers;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: NullStatus(
          label: '还没有规则提供者',
          description: '把大的规则集拆成远程文件，规则本身只留一行引用',
          illustration: NullStatusIllustration.rules,
        ),
      );
    }
    final colorScheme = context.colorScheme;
    return generateSection(
      title: '规则提供者',
      items: [
        for (final provider in providers)
          ListItem(
            leading: GlyphIcon(AppGlyphs.rules, color: colorScheme.primary),
            title: Text(provider.name),
            subtitle: Text(
              '${_behaviorLabel(provider.behavior)} · ${provider.ruleCount} 条 · '
              '${provider.updatedAt}',
              style: context.listCaptionStyle,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                MetaChip(label: provider.format),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => onRemove(provider.id),
                  icon: GlyphIcon(
                    AppGlyphs.delete,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
      footer: '行为决定规则集的匹配方式：domain 类匹配域名，ipcidr 类匹配网段。',
    );
  }
}

/// 规则提供者的行为名（YAML 里是英文，界面上要中文；未知值原样显示）。
String _behaviorLabel(String behavior) => switch (behavior) {
  'domain' => '域名',
  'ipcidr' => '网段',
  'classical' => '传统规则',
  _ => behavior,
};
