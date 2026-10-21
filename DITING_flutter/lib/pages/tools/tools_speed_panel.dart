part of 'tools_page.dart';

/// 测速页签：真实 DNS 查询耗时测量（旧版 `DnsSpeedTestSection`）。
///
/// 三个必须如实呈现的点：
/// 1. **不可用态先说清楚**。通道不存在时（桌面 / 测试宿主）页面显示「当前设备
///    不支持测速」并禁用按钮，绝不用假数字顶替；
/// 2. 成功项的耗时来自原生侧的真实往返（3 次查询取成功样本平均），失败项显示
///    `全部失败（N 次）` + 原因，不参与最快徽标；
/// 3. 结果按「成功优先 → 平均耗时升序」排序，名次就是列表下标 + 1。
class _SpeedTestPanel extends ConsumerStatefulWidget {
  const _SpeedTestPanel();

  @override
  ConsumerState<_SpeedTestPanel> createState() => _SpeedTestPanelState();
}

class _SpeedTestPanelState extends ConsumerState<_SpeedTestPanel> {
  final _domain = TextEditingController();

  /// 只在首帧把 provider 里的域名灌进输入框，之后由用户输入驱动。
  var _domainBound = false;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protocols = ref.watch(latencyTestProtocolsProvider);
    final protocol = ref.watch(latencyProtocolProvider);
    final domain = ref.watch(latencyDomainProvider);
    final selected = ref.watch(latencySelectionProvider);
    final state = ref.watch(latencyTestProvider);
    final available = ref.watch(latencyTestAvailableProvider);
    final catalog = ref.watch(latencyTestCatalogProvider);
    final providers = [
      for (final spec in catalog)
        if (spec.protocol == protocol) spec,
    ];
    if (!_domainBound) {
      _domainBound = true;
      _domain.text = domain;
    }
    final unavailable = available.value == false || state.unavailable;
    final barMax = latencyBarMax(state.results);

    return PageBody(
      children: [
        if (available.isLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _ToolNotice(text: '正在检查测速通道…'),
          ),
        if (unavailable)
          const _ToolNotice(
            text:
                '当前设备不支持测速：本机没有提供 DNS 查询耗时测量的原生通道，'
                '页面不会显示任何模拟耗时。',
            isError: true,
            glyph: AppGlyphs.warning,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CommonCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _ToolField(
              controller: _domain,
              hintText: '用于测速的域名',
              glyph: AppGlyphs.language,
              enabled: !state.running && !unavailable,
              // 必须边输边写回 provider：`_run` 读的是 provider 里的域名，
              // 只改输入框文字会让测速打在上一次的域名上。
              onChanged: (value) =>
                  ref.read(latencyDomainProvider.notifier).setDomain(value),
              onSubmitted: (_) => _run(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedControl<DnsLatencyProtocol>(
            segments: [for (final item in protocols) (item, item.label)],
            value: protocol,
            onChanged: (value) {
              if (!state.running) {
                ref.read(latencyProtocolProvider.notifier).select(value);
              }
            },
          ),
        ),
        generateSection(
          title: '测速服务商',
          items: [
            if (providers.isEmpty)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info, size: 20),
                title: Text('暂无 ${protocol.label} DNS 服务商'),
                subtitle: const Text('在「服务商管理」里添加后即可参与测速'),
              )
            else
              for (final spec in providers)
                ListItem.checkbox(
                  value: selected.contains(spec.id),
                  leading: const GlyphIcon(AppGlyphs.dns, size: 20),
                  title: Text(spec.name),
                  subtitle: Text(latencyEndpointLabel(spec)),
                  onChanged: state.running
                      ? null
                      : (_) => ref
                            .read(latencySelectionProvider.notifier)
                            .toggle(spec.id),
                ),
          ],
          footer:
              '可选择 1 个或多个服务商；这里的选择只用于 DNS 查询测速，'
              '不影响竞速模式。',
        ),
        if (state.error case final error?)
          _ToolNotice(text: error, isError: true, glyph: AppGlyphs.error),
        _RunButton(
          glyph: AppGlyphs.speed,
          label: '测试查询耗时',
          runningLabel: '测速中…',
          running: state.running,
          onPressed: unavailable || selected.isEmpty ? null : _run,
        ),
        if (!state.running && state.results.isEmpty && !unavailable)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CommonCard(
              padding: EdgeInsets.all(16),
              child: Text(
                '尚未测速。选好服务商后点上面的按钮，本应用会直接向每个服务商发送 3 次'
                '真实 DNS 查询并记录往返耗时。',
              ),
            ),
          ),
        if (state.results.isNotEmpty) ...[
          // 结果行用 `generateSection` 而不是自己套 `CommonCard` + `Column`：
          // 旧版 `DnsSpeedTestSection` 每行之间有 0.5dp 的 `HorizontalDivider`，
          // 而 `lib/ui` 的行分隔线由 `ItemPosition` 驱动（`list_row_separator`）——
          // 它按设备像素比取整到真正的发丝线，并在高亮/聚焦时自动收线。
          // 自己画一条 `Divider(height: 0.5)` 会得到 1 逻辑像素（粗一倍），且与
          // 其它列表页的线条粗细不一致。
          generateSection(
            title: '查询耗时结果',
            items: [
              for (final (index, sample) in state.results.indexed)
                _SpeedResultRow(
                  sample: sample,
                  rank: index + 1,
                  isFastest: index == 0 && sample.success,
                  barMax: barMax,
                ),
            ],
            footer:
                '测速结果按成功优先、平均耗时从低到高排序；'
                '结果只反映本次查询时的网络状态。域名当前为「$domain」。',
          ),
        ],
        const ListFooter(
          text:
              '测速由原生侧执行：向每个服务商分别发送真实的 DoH / DoT / 明文 DNS '
              '查询，只有拿到成功应答的样本才计入耗时。',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _run() async {
    ref.read(latencyTestProvider.notifier).clearError();
    await ref.read(latencyTestProvider.notifier).run();
    if (!mounted) {
      return;
    }
    final error = ref.read(latencyTestProvider).error;
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// 一行测速结果：名次 + 名称 + 协议徽标 + 最快徽标 + 耗时条 + 成功率 + 样本。
class _SpeedResultRow extends StatelessWidget {
  const _SpeedResultRow({
    required this.sample,
    required this.rank,
    required this.isFastest,
    required this.barMax,
  });

  final DnsLatencySample sample;
  final int rank;
  final bool isFastest;
  final int barMax;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final share = barMax <= 0 ? 0.0 : sample.elapsedMs / barMax;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$rank',
                  style: AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: isFastest
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  sample.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listTitleStyle,
                ),
              ),
              TonalChip(
                label: sample.protocol.label,
                color: context.raisedSurfaceLevel.colorOf(colorScheme),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              if (isFastest)
                TonalChip(
                  label: '最快',
                  color: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                ),
            ],
          ),
          if (sample.success) ...[
            Text(
              '${sample.elapsedMs} ms',
              style: AppTextStyle.title3
                  .of(context, emphasized: true)
                  .copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: colorScheme.primary,
                  ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: colorScheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: share.clamp(0.0, 1.0),
                        child: ColoredBox(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              sample.samplesMs.length > 1
                  ? '${sample.successRateLabel} · 样本 '
                        '${sample.samplesMs.map((ms) => '$ms ms').join(' / ')}'
                  : sample.successRateLabel,
              style: context.listCaptionStyle,
            ),
          ] else ...[
            Text(
              '全部失败（${sample.attempts} 次）',
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.error,
              ),
            ),
            if (sample.message case final message?)
              Text(
                message,
                style: context.listCaptionStyle.copyWith(
                  color: colorScheme.error,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
