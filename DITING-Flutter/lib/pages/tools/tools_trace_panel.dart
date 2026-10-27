part of 'tools_page.dart';

/// Traceroute panel with a per-hop list from `DiagnosticsRunner.traceRoute`. Hops arrive in
/// one batch: the legacy progressive callbacks cannot survive Flutter rebuilds.
class _TraceroutePanel extends ConsumerStatefulWidget {
  const _TraceroutePanel();

  @override
  ConsumerState<_TraceroutePanel> createState() => _TraceroutePanelState();
}

class _TraceroutePanelState extends ConsumerState<_TraceroutePanel> {
  final _target = TextEditingController(text: '');
  var _maxHops = 15;
  var _running = false;
  TraceResult? _result;
  String? _hostError;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    final resolved = resolveProbeHost(_target.text);
    if (resolved.error != null) {
      setState(() => _hostError = resolved.error);
      return;
    }
    setState(() {
      _hostError = null;
      _running = true;
      _result = null;
    });
    final result = await ref
        .read(diagnosticsRunnerProvider)
        .traceRoute(resolved.host, maxHops: _maxHops);
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(networkToolFlagsProvider);
    final colorScheme = context.colorScheme;
    final result = _result;
    return PageBody(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _ToolField(
            controller: _target,
            hintText: '输入 IP 或域名',
            glyph: AppGlyphs.target,
            enabled: !_running,
            onSubmitted: (_) => _run(),
          ),
        ),
        // Same hop options as the legacy `TracerouteSection`: 15 and 30, defaulting to 15.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedControl<int>(
            segments: const [(15, '15 跳'), (30, '30 跳')],
            value: _maxHops,
            onChanged: (hops) {
              if (!_running) {
                setState(() => _maxHops = hops.clamp(1, 30));
              }
            },
          ),
        ),
        generateSection(
          title: '追踪选项',
          items: [
            _ViaTunnelRow(
              storageKey: tracerouteViaTunnelKey,
              title: '通过 Go 隧道解析',
              subtitle: '域名经运行中的 Go 隧道解析（应用覆写与过滤规则），探测仍走物理网络',
              value: flags.tracerouteViaTunnel,
              enabled: !_running,
            ),
          ],
        ),
        _RunButton(
          glyph: AppGlyphs.split,
          label: '开始追踪',
          runningLabel: '追踪中…',
          running: _running,
          onPressed: _run,
        ),
        if (_hostError case final error?)
          _ToolNotice(text: error, isError: true, glyph: AppGlyphs.error),
        if (result != null) ...[
          if (!result.success && !result.cancelled)
            _ToolNotice(
              text: result.message ?? '追踪失败：未收到任何回应',
              isError: true,
              glyph: AppGlyphs.error,
            ),
          if (result.cancelled)
            const _ToolNotice(text: '追踪已取消。', glyph: AppGlyphs.info),
          _ToolSection(
            rows: [
              KeyValueRow(label: '目标', value: result.target, monospace: true),
              KeyValueRow(
                label: '解析地址',
                value: result.resolvedAddress ?? '—',
                monospace: true,
              ),
              KeyValueRow(
                label: '跳数',
                value: '${result.hops.length} / 最多 $_maxHops',
                monospace: true,
              ),
            ],
          ),
          if (result.hops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final hop in result.hops)
                      ListItem(
                        leading: SizedBox(
                          width: 24,
                          child: Text(
                            '${hop.hop}',
                            textAlign: TextAlign.center,
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        title: Text(
                          hop.address ?? '* * *',
                          style: AppTextStyle.subheadline
                              .of(context)
                              .copyWith(
                                fontFamily: appMonospaceFontFamily,
                                color: hop.responded
                                    ? (hop.reachedTarget
                                          ? colorScheme.success
                                          : colorScheme.onSurface)
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                        trailing: Text(
                          hop.responded ? _msText(hop.elapsedMs) : '无响应',
                          style: AppTextStyle.caption1
                              .of(context)
                              .copyWith(
                                color: hop.responded
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.warning,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const ListFooter(
          text:
              '星号表示该跳在超时时间内没有回包——不代表链路断了，很多路由器'
              '不响应探测包。绿色一行表示已到达目标。',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
