import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 「控制全局追加规则」页（上游 `_EditGlobalAddedRules`）。
///
/// 全局规则对所有档案生效，所以这一页只做启停，不提供编辑：改内容要去「已追加
/// 规则」那边，否则同一份规则会在十几处入口被改出十几个版本。
class GlobalRulesPage extends ConsumerStatefulWidget {
  const GlobalRulesPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<GlobalRulesPage> createState() => _GlobalRulesPageState();
}

class _GlobalRulesPageState extends ConsumerState<GlobalRulesPage> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockGlobalRule> _visible(List<MockGlobalRule> rules) => [
    for (final rule in rules)
      if (_query.isEmpty ||
          rule.content.toLowerCase().contains(_query) ||
          rule.target.toLowerCase().contains(_query) ||
          rule.type.value.toLowerCase().contains(_query) ||
          rule.type.label.contains(_query))
        rule,
  ];

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(globalRulesProvider);
    final visible = _visible(rules);
    final enabled = rules.where((rule) => rule.enabled).length;
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '全局追加规则',
      searchState: AppBarSearchState(
        onSearch: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
      body: NullStatusSwitcher(
        isEmpty: visible.isEmpty,
        isSearching: _query.isNotEmpty,
        nullStatus: NullStatus(
          label: _query.isEmpty ? '还没有全局追加规则' : '没有匹配的规则',
          description: _query.isEmpty ? '到「已追加规则」里添加，它们会对所有档案生效' : null,
          illustration: _query.isEmpty
              ? NullStatusIllustration.rules
              : NullStatusIllustration.search,
        ),
        child: PageBody(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '这些规则由所有档案共用，共 $enabled 条启用。关掉的规则仍留在列表里。',
                style: context.listCaptionStyle,
              ),
            ),
            const SizedBox(height: 12),
            generateSection(
              title: '规则',
              items: [
                for (final rule in visible)
                  ListItem(
                    leading: GlyphIcon(
                      rule.enabled ? AppGlyphs.rules : AppGlyphs.block,
                      color: rule.enabled
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      rule.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(
                            fontFamily: 'JetBrainsMono',
                            color: rule.enabled
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                    subtitle: Text(
                      '${rule.type.label} → ${rule.target}',
                      style: context.listCaptionStyle,
                    ),
                    trailing: Switch(
                      value: rule.enabled,
                      onChanged: (value) => ref
                          .read(globalRulesProvider.notifier)
                          .toggle(rule.id, value),
                    ),
                  ),
              ],
              footer: '全局规则排在每份档案自己的规则之前，所以能覆盖单份档案的设置。',
            ),
          ],
        ),
      ),
    );
  }
}
