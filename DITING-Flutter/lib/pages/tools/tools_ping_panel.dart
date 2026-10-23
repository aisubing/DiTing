part of 'tools_page.dart';

/// Ping panel: target, count and real ICMP results from `DiagnosticsRunner.ping`.
/// `success=false` renders a failure, `measuredWithFallback=true` means the latency is TCP
/// handshake time, not ICMP RTT.
class _PingPanel extends ConsumerStatefulWidget {
  const _PingPanel();

  @override
  ConsumerState<_PingPanel> createState() => _PingPanelState();
}

class _PingPanelState extends ConsumerState<_PingPanel> {
  final _target = TextEditingController(text: '');
  var _count = 4;
  var _running = false;
  PingSummary? _result;
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
    final summary = await ref
        .read(diagnosticsRunnerProvider)
        .ping(resolved.host, count: _count);
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _result = summary;
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
        // Same count options as the legacy `PingSection`: 4 and 10 only.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedControl<int>(
            segments: const [(4, '4 次'), (10, '10 次')],
            value: _count,
            onChanged: (count) {
              if (!_running) {
                setState(() => _count = count.clamp(1, 20));
              }
            },
          ),
        ),
        generateSection(
          title: '探测选项',
          items: [
            _ViaTunnelRow(
              storageKey: pingViaTunnelKey,
              title: '通过 Go 隧道解析',
              subtitle: '域名经运行中的 Go 隧道解析（应用覆写与过滤规则），探测仍走物理网络',
              value: flags.pingViaTunnel,
              enabled: !_running,
            ),
          ],
        ),
        _RunButton(
          glyph: AppGlyphs.send,
          label: '开始 Ping',
          runningLabel: '正在探测…',
          running: _running,
          onPressed: _run,
        ),
        if (_hostError case final error?)
          _ToolNotice(text: error, isError: true, glyph: AppGlyphs.error),
        if (result != null) ...[
          if (result.measuredWithFallback)
            const _ToolNotice(
              text:
                  '系统 ICMP 受限，已用 TCP 回退测量。此时的时延是连接建立耗时，'
                  '不能与 ICMP 往返时延直接比较。',
              glyph: AppGlyphs.warning,
            ),
          if (!result.success)
            _ToolNotice(
              text: result.message ?? '探测失败：未收到任何回复',
              isError: true,
              glyph: AppGlyphs.error,
            ),
          _ToolSection(
            rows: [
              KeyValueRow(label: '目标', value: result.target, monospace: true),
              KeyValueRow(
                label: '解析地址',
                value: result.resolvedAddress ?? '—',
                monospace: true,
              ),
              KeyValueRow(label: '地址族', value: result.addressFamily ?? '—'),
              KeyValueRow(
                label: '发送 / 接收',
                value: '${result.transmitted} / ${result.received}',
                monospace: true,
              ),
              KeyValueRow(
                label: '丢包率',
                value: '${result.lossPercent.toStringAsFixed(1)} %',
                monospace: true,
              ),
              KeyValueRow(
                label: '最小 / 平均 / 最大',
                value:
                    '${_msText(result.minMs)} / ${_msText(result.avgMs)} / '
                    '${_msText(result.maxMs)}',
                monospace: true,
              ),
              KeyValueRow(
                label: '抖动',
                value: _msText(result.jitterMs),
                monospace: true,
              ),
            ],
            footer: result.success ? '抖动按各包时延与均值的平均绝对偏差计算。' : null,
          ),
          if (result.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final reply in result.replies)
                      KeyValueRow(
                        label: '第 ${reply.sequence} 个包',
                        value: reply.ok
                            ? _msText(reply.elapsedMs)
                            : (reply.error ?? '超时'),
                        monospace: true,
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '本次共发送 ${result.transmitted} 个探测包，'
              '失败 ${result.transmitted - result.received} 个。',
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const ListFooter(
          text:
              'Ping 由原生侧执行：优先调用系统 ping 二进制，不可用时回退到'
              '地址可达性与 TCP 端口握手计时，并会明确标注。',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}