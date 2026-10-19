part of 'tools_page.dart';

/// 模拟一次耗时操作：置为运行中，等一会儿再给结果。
///
/// 演示版不真正发包，但必须留出「运行中」这一段——否则点一下立刻出结果，
/// 用户看不出按钮的忙碌态与结果区的关系。
mixin _ToolRunState<T extends StatefulWidget> on State<T> {
  var _running = false;
  var _hasResult = false;

  bool get running => _running;
  bool get hasResult => _hasResult;

  Future<void> run(VoidCallback assignResult) async {
    if (_running) {
      return;
    }
    setState(() {
      _running = true;
      _hasResult = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _hasResult = true;
      assignResult();
    });
  }
}

/// 测速面板：下行 / 上行 / 延迟。
class _SpeedTestPanel extends StatefulWidget {
  const _SpeedTestPanel();

  @override
  State<_SpeedTestPanel> createState() => _SpeedTestPanelState();
}

class _SpeedTestPanelState extends State<_SpeedTestPanel>
    with _ToolRunState<_SpeedTestPanel> {
  var _down = 0.0;
  var _up = 0.0;
  var _latency = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '网络测速',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '下行',
                    value: hasResult ? _down.toStringAsFixed(1) : '—',
                    unit: hasResult ? 'Mbps' : null,
                    color: hasResult ? colorScheme.primary : null,
                  ),
                  StatItem(
                    label: '上行',
                    value: hasResult ? _up.toStringAsFixed(1) : '—',
                    unit: hasResult ? 'Mbps' : null,
                  ),
                  StatItem(
                    label: '延迟',
                    value: hasResult ? '$_latency' : '—',
                    unit: hasResult ? 'ms' : null,
                    color: hasResult ? colorScheme.delayColor(_latency) : null,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '测速会连续下载 / 上传一小段数据并取平均，因此需要几秒；'
              '运营商限速或代理链路会让上行明显低于下行。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(
              glyph: AppGlyphs.speed,
              label: running ? '正在测速…' : (hasResult ? '重新测速' : '开始测速'),
              onPressed: running
                  ? null
                  : () => run(() {
                      _down = 86.4;
                      _up = 21.7;
                      _latency = 18;
                    }),
            ),
          ),
          ListFooter(
            text: hasResult
                ? '结果是本次采样的平均值，与运营商测速页可能相差 5% 以内。'
                : '演示版用内置样例生成结果，不会消耗真实流量。',
          ),
        ],
      ),
    );
  }
}

/// Ping 面板：目标 + 次数 + 逐包结果。
class _PingPanel extends StatefulWidget {
  const _PingPanel();

  @override
  State<_PingPanel> createState() => _PingPanelState();
}

class _PingPanelState extends State<_PingPanel>
    with _ToolRunState<_PingPanel> {
  final _target = TextEditingController(text: 'api.example.com');

  /// 上游次数选项是 4 / 10，且钳位在 1..20。
  var _count = 4;
  List<int> _rtts = const [];

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Ping',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ToolField(
              controller: _target,
              hintText: '域名或 IP',
              glyph: AppGlyphs.target,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<int>(
              segments: const [(4, '4 次'), (10, '10 次'), (20, '20 次')],
              value: _count,
              onChanged: (count) => setState(() => _count = count.clamp(1, 20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TonalButton(
              glyph: AppGlyphs.send,
              label: running ? '正在探测…' : '开始 Ping',
              onPressed: running
                  ? null
                  : () => run(() {
                      _rtts = [
                        for (var i = 0; i < _count; i++) 14 + (i * 7) % 26,
                      ];
                    }),
            ),
          ),
          if (hasResult)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, rtt) in _rtts.indexed)
                      KeyValueRow(
                        label: '第 ${index + 1} 个包',
                        value: '$rtt ms',
                        monospace: true,
                      ),
                    KeyValueRow(
                      label: '平均',
                      value:
                          '${(_rtts.reduce((a, b) => a + b) / _rtts.length).toStringAsFixed(1)} ms',
                      monospace: true,
                    ),
                  ],
                ),
              ),
            ),
          ListFooter(
            text: '演示版不会真的发包。真实实现里超时的包记为「请求超时」，'
                '不参与平均值计算。',
          ),
        ],
      ),
    );
  }
}

/// DNS 查询面板：服务商 + 记录类型 + 查询结果。
class _DnsLookupPanel extends StatefulWidget {
  const _DnsLookupPanel();

  @override
  State<_DnsLookupPanel> createState() => _DnsLookupPanelState();
}

class _DnsLookupPanelState extends State<_DnsLookupPanel>
    with _ToolRunState<_DnsLookupPanel> {
  final _domain = TextEditingController(text: 'api.example.com');
  var _providerId = mockProviders.first.id;
  var _recordType = 'A';
  var _answer = '';

  static const _recordTypes = ['A', 'AAAA', 'CNAME', 'TXT'];

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = mockProviders.firstWhere(
      (candidate) => candidate.id == _providerId,
    );
    return CommonScaffold(
      title: 'DNS 查询',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ToolField(
              controller: _domain,
              hintText: '要查询的域名',
              glyph: AppGlyphs.language,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<String>(
              segments: [
                for (final type in _recordTypes) (type, type),
              ],
              value: _recordType,
              onChanged: (type) => setState(() => _recordType = type),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _ProviderChips(
              value: _providerId,
              onChanged: (id) => setState(() => _providerId = id),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TonalButton(
              glyph: AppGlyphs.search,
              label: running ? '正在查询…' : '发起查询',
              onPressed: running
                  ? null
                  : () => run(() {
                      _answer = switch (_recordType) {
                        'AAAA' => '2001:db8::12',
                        'CNAME' => 'origin.example.com',
                        'TXT' => 'v=spf1 include:example.com ~all',
                        _ => '10.0.0.12',
                      };
                    }),
            ),
          ),
          if (hasResult)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyValueRow(
                      label: '记录类型',
                      value: _recordType,
                      monospace: true,
                    ),
                    KeyValueRow(
                      label: '应答',
                      value: _answer,
                      monospace: true,
                    ),
                    KeyValueRow(
                      label: '经由服务商',
                      value: provider.name,
                    ),
                    KeyValueRow(
                      label: '耗时',
                      value: '${provider.latencyMs} ms',
                      monospace: true,
                    ),
                  ],
                ),
              ),
            ),
          ListFooter(
            text: '结果只显示第一条应答；真实实现会列出全部 A / AAAA 记录与 TTL。',
          ),
        ],
      ),
    );
  }
}

/// 路由追踪面板：目标 + 最大跳数 + 逐跳结果。
class _TraceroutePanel extends StatefulWidget {
  const _TraceroutePanel();

  @override
  State<_TraceroutePanel> createState() => _TraceroutePanelState();
}

class _TraceroutePanelState extends State<_TraceroutePanel>
    with _ToolRunState<_TraceroutePanel> {
  final _target = TextEditingController(text: 'cdn.example.com');

  /// 上游默认 15 跳，上限 30。
  var _maxHops = 15;
  var _hops = const <(String, int)>[];

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '路由追踪',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ToolField(
              controller: _target,
              hintText: '域名或 IP',
              glyph: AppGlyphs.target,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<int>(
              segments: const [(10, '10 跳'), (15, '15 跳'), (30, '30 跳')],
              value: _maxHops,
              onChanged: (hops) => setState(() => _maxHops = hops.clamp(1, 30)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TonalButton(
              glyph: AppGlyphs.split,
              label: running ? '正在追踪…' : '开始追踪',
              onPressed: running
                  ? null
                  : () => run(() {
                      _hops = [
                        for (var i = 0; i < 6 && i < _maxHops; i++)
                          ('10.0.${i + 1}.1', 3 + i * 6),
                        if (_maxHops > 6) ('* * *', -1),
                      ];
                    }),
            ),
          ),
          if (hasResult)
            generateSection(
              title: '路径',
              footer: '星号表示该跳在超时时间内没有回包——不一定代表链路断了，'
                  '很多路由器不响应探测包。',
              items: [
                for (final (index, hop) in _hops.indexed)
                  ListItem(
                    leading: SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    title: Text(
                      hop.$1,
                      style: AppTextStyle.subheadline.of(context).copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: hop.$2 < 0
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                    trailing: Text(
                      hop.$2 < 0 ? '超时' : '${hop.$2} ms',
                      style: AppTextStyle.caption1.of(context).copyWith(
                        color: hop.$2 < 0
                            ? colorScheme.warning
                            : colorScheme.delayColor(hop.$2),
                      ),
                    ),
                  ),
              ],
            ),
          ListFooter(
            text: '最大 $_maxHops 跳。真实实现每跳会发 3 个探测包，这里只显示一次。',
          ),
        ],
      ),
    );
  }
}
