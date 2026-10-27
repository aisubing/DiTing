// Detail-panel sections of [AppRulesPage]: allowlisted domains and DNS-scoped rules.
//
// Split out only to keep the page file under 600 lines; an extension still sees the state's
// private helpers. Both sections build their rows through lazy slivers so a package with
// thousands of entries stays a flat first frame.
part of 'app_rules_page.dart';

extension _AppRulesDetail on _AppRulesPageState {
  /// Same rationale as [_allowDomainSlivers]: a package can carry hundreds of scoped rules, and
  /// they must not all be inflated before the first frame.
  List<Widget> _scopedRuleSlivers(InstalledApp app) {
    final actions = [
      IconButtonData(
        glyph: AppGlyphs.add,
        tooltip: '添加 DNS 规则',
        onPressed: () => _addScopedRule(app),
      ),
    ];
    const footer =
        '这些规则写入规则库的 block_rule / allow_rule，带 appScope 只对本应用生效，'
        '并随规则快照的 appRules 下发，不会扩大成全局拦截。';
    final rules = ref.watch(appScopedRulesProvider(app.packageName));
    if (rules.isLoading) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: 'DNS 专属黑/白名单',
            actions: actions,
            items: const [
              ListItem(
                leading: GlyphIcon(AppGlyphs.info),
                title: Text('正在读取规则库'),
                subtitle: Text('稍候'),
              ),
            ],
          ),
        ),
      ];
    }
    final value = rules.value;
    if (value == null || !value.available) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: 'DNS 专属黑/白名单',
            actions: actions,
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: const Text('读不到规则库'),
                subtitle: Text(value?.error ?? '当前环境无法读写规则库'),
              ),
            ],
          ),
        ),
      ];
    }
    final scoped = [...value.block, ...value.allow];
    if (scoped.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: 'DNS 专属黑/白名单',
            actions: actions,
            items: const [
              ListItem(
                leading: GlyphIcon(AppGlyphs.info),
                title: Text('未配置 DNS 专属规则'),
                subtitle: Text('添加后仅对本应用生效，不影响其他应用'),
              ),
            ],
          ),
        ),
      ];
    }
    return lazySectionSlivers(
      title: 'DNS 专属黑/白名单（${scoped.length}）',
      actions: actions,
      itemCount: scoped.length,
      footer: footer,
      itemBuilder: (context, index) {
        final rule = scoped[index];
        return AppScopedRuleRow(
          rule: rule,
          onToggle: (enabled) => _toggleScopedRule(app, rule, enabled),
          onDelete: () => _deleteScopedRule(app, rule),
        );
      },
    );
  }

  /// Header-only when there is nothing to list; the rows themselves are built by a lazy sliver, so
  /// an app with thousands of allowlisted domains no longer inflates them all in one frame.
  List<Widget> _allowDomainSlivers(
    AppRulesDraft draft,
    InstalledApp app,
    Set<String> domains,
  ) {
    final actions = [
      IconButtonData(
        glyph: AppGlyphs.add,
        tooltip: '添加放行域名',
        onPressed: () => _addDomain(draft, app.packageName),
      ),
    ];
    if (domains.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: generateSection(
            title: '专属放行域名（网络层） (0)',
            actions: actions,
            items: [
              const ListItem(
                title: Text('未配置网络放行域名'),
                subtitle: Text('网络层白名单为空时，该应用不受额外限制'),
                leading: GlyphIcon(AppGlyphs.info),
              ),
            ],
          ),
        ),
      ];
    }
    final sorted = domains.toList()..sort();
    return lazySectionSlivers(
      title: '专属放行域名（网络层） (${sorted.length})',
      actions: actions,
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final domain = sorted[index];
        return AppAllowDomainRow(
          domain: domain,
          onDelete: () => _removeDomain(draft, app.packageName, domain),
        );
      },
      footer:
          '这些域名会写入 app_allowlist_rules_json，'
          '由引擎在下一次启动隧道时下发给 setAppAllowlist。',
    );
  }

  /// Trailing section of the detail panel: the outer-network switch for this package.
  Widget _detailFooter(InstalledApp app, AsyncValue<AppScopedRules> rules) {
    final fullBlock = rules.value?.fullBlock ?? false;
    return Column(
      children: [
        generateSection(
          title: '外联与隔离模式',
          items: [
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.wifiOff),
              title: const Text('默认拦截全部外联'),
              subtitle: const Text('开启后阻断该应用的所有网络连接，仅放行白名单'),
              value: fullBlock,
              onChanged: (value) => _toggleFullBlock(app, value),
            ),
            if (fullBlock)
              const ListItem(
                leading: GlyphIcon(AppGlyphs.info),
                title: Text('已开启全阻断模式'),
                subtitle: Text('请确保已添加必要的放行白名单，否则应用可能无法联网。'),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
