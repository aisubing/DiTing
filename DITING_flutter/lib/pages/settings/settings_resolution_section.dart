part of 'settings_page.dart';

/// 解析分组：解析模式、服务商入口、缓存 TTL。
///
/// 解析模式决定首页「服务商」卡片长什么样（单选框还是竞速名单），所以改完
/// 立刻生效；服务商入口则按模式切换语义——单选模式点一下即选中，多路模式
/// 是勾选集合，两种语义混在一个弹层里会互相误伤，因此分成两个页面。
class _ResolutionSection extends ConsumerWidget {
  const _ResolutionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final single = mode.isSingle;
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final summary = single
        ? endpointOfProvider(selectedId, catalog)
        : summaryOfProviders(raceIds, catalog);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: 'DNS 解析',
          footer: '「单服务商」只问一家；其余三种模式维护一个候选集合，'
              '首页会额外列出每个候选的端点。',
          items: [
            ListItem<ResolutionMode>.options(
              title: const Text('解析模式'),
              subtitle: const Text('决定多路候选的调度策略'),
              leading: const GlyphIcon(AppGlyphs.speed),
              options: ResolutionMode.values,
              value: mode,
              textBuilder: (mode) => mode.label,
              onChanged: (mode) =>
                  ref.read(resolutionModeProvider.notifier).select(mode),
            ),
            ListItem.next(
              title: Text(single ? '解析服务商' : '竞速服务商'),
              subtitle: Text(summary),
              leading: const GlyphIcon(AppGlyphs.dns),
              widget: const _ProviderPickerPage(),
            ),
            ListItem(
              title: const Text('DNS 缓存'),
              subtitle: Text(cacheSummaryOf(ref.read(legacySettingsProvider))),
              leading: const GlyphIcon(AppGlyphs.memory),
              onTap: () => context.push('/hub/cache'),
            ),
          ],
        ),
      ],
    );
  }
}


/// 服务商选择页：按当前解析模式切换单选 / 多选。
///
/// 用整页而不是弹层：多路模式下要能看到全部候选的端点与延迟，弹层高度不够；
/// 而且首页那个弹层是「快速切换」，这里是「配置」，入口不同、深度也不同。
class _ProviderPickerPage extends ConsumerWidget {
  const _ProviderPickerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(resolutionModeProvider);
    final selectedId = ref.watch(selectedProviderProvider);
    final raceIds = ref.watch(raceProvidersProvider);
    final single = mode.isSingle;
    return CommonScaffold(
      title: single ? '解析服务商' : '竞速服务商',
      body: PageBody(
        children: [
          generateSection(
            title: single ? '单选' : '多选（至少 2 家）',
            footer: single
                ? '单选模式下所有查询都发往这一家。'
                : '竞速时同时问多家、取最先返回的结果，至少保留 2 家才有意义。',
            items: [
              for (final provider in ref.watch(dnsProviderCatalogProvider))
                ListItem(
                  title: Text(provider.name),
                  subtitle: Text(
                    '${provider.protocol.label} · ${provider.address}'
                    ' · ${providerLatencyLabel(provider)}',
                  ),
                  leading: const GlyphIcon(AppGlyphs.proxies),
                  trailing: single
                      ? (provider.id == selectedId
                            ? const SelectionCheck()
                            : const SizedBox(width: SelectionCheck.size))
                      : CommonCheckBox(
                          isCircle: true,
                          value: raceIds.contains(provider.id),
                          onChanged: (_) => _toggleRace(context, ref, provider.id),
                        ),
                  onTap: single
                      ? () {
                          ref
                              .read(selectedProviderProvider.notifier)
                              .select(provider.id);
                          // 这一页由 `ListItem.next` 的 Extend 宿主推入，返回必须走
                          // 宿主自己的 pop，否则桌面端会留下一个空层。
                          context.safeNestedPop();
                        }
                      : () => _toggleRace(context, ref, provider.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 多路模式的勾选：被下限挡住时提示而不是静默忽略。
  void _toggleRace(BuildContext context, WidgetRef ref, String id) {
    final accepted = ref.read(raceProvidersProvider.notifier).toggle(id);
    if (!accepted) {
      _showSettingHint(context, '竞速至少保留 ${RaceProvidersNotifier.minCount} 家服务商');
    }
  }
}

