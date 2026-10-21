part of 'tools_page.dart';

/// DNS 查询面板。
///
/// 数据源是 `DiagnosticsRunner.lookupDns`。与旧版 `DnsLookupSection` 一致的三点：
/// 1. **DNS 服务器两态**：`SYSTEM`（问本机解析器）/ `CUSTOM`（向指定 IP 发真实
///    UDP 查询）。旧版就是这两档 + 「自定义 DNS 服务器 IP」输入框——问「某个具体
///    服务器会怎么答」正是这类工具存在的意义，上一轮的迁移把它丢了；
/// 2. `viaTunnel` 决定问隧道引擎（`Engine.resolveDomain`，走本软件自己的规则与
///    缓存），此时服务器选择被忽略（隧道不接受指定服务器）；
/// 3. 结果必须标 `source`：只有 `upstream` 表示真的打到了上游解析器，
///    `cache` / `rewrite` / `blocked` 都是隧道自己给的答案。把 `blocked` 显示成
///    「解析成功」会让用户以为域名正常。
class _DnsLookupPanel extends ConsumerStatefulWidget {
  const _DnsLookupPanel();

  @override
  ConsumerState<_DnsLookupPanel> createState() => _DnsLookupPanelState();
}

/// 与旧版 `DnsServerMode` 同名的两档。
enum _DnsServerMode {
  system('跟随系统'),
  custom('自定义');

  const _DnsServerMode(this.label);

  final String label;
}

class _DnsLookupPanelState extends ConsumerState<_DnsLookupPanel> {
  final _domain = TextEditingController(text: '');
  final _server = TextEditingController(text: '');
  var _running = false;
  var _ipv4 = true;
  var _serverMode = _DnsServerMode.system;
  DnsLookupResult? _result;
  String? _hostError;

  @override
  void dispose() {
    _domain.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    final resolved = resolveProbeHost(_domain.text);
    if (resolved.error != null) {
      setState(() => _hostError = resolved.error);
      return;
    }
    final viaTunnel = ref.read(networkToolFlagsProvider).dnsLookupViaTunnel;
    // 只有「非隧道 + 自定义」才带服务器；其余两种情况走系统解析器。
    final server = !viaTunnel && _serverMode == _DnsServerMode.custom
        ? _server.text.trim()
        : null;
    // 空的自定义服务器会在原生侧被当成「系统」，那样用户以为在测 A 服务器、
    // 实际测的是系统——必须在发出请求前就拦住。
    if (server != null && server.isEmpty) {
      setState(() => _hostError = '请输入自定义 DNS 服务器 IP');
      return;
    }
    setState(() {
      _hostError = null;
      _running = true;
      _result = null;
    });
    final result = await ref
        .read(diagnosticsRunnerProvider)
        .lookupDns(
          resolved.host,
          viaTunnel: viaTunnel,
          ipv4: _ipv4,
          server: server,
        );
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
    final result = _result;
    // 隧道模式下服务器由隧道决定，两档选择器没有意义——隐藏而不是禁用：
    // 灰掉的控件会让人以为「启用后就能选」，实际永远不会。
    final showServerMode = !flags.dnsLookupViaTunnel;
    return PageBody(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _ToolField(
            controller: _domain,
            hintText: '输入要解析的域名',
            glyph: AppGlyphs.language,
            enabled: !_running,
            onSubmitted: (_) => _run(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedControl<bool>(
            segments: const [(true, 'IPv4 (A)'), (false, 'IPv6 (AAAA)')],
            value: _ipv4,
            onChanged: (value) {
              if (!_running) {
                setState(() => _ipv4 = value);
              }
            },
          ),
        ),
        if (showServerMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<_DnsServerMode>(
              segments: [
                for (final mode in _DnsServerMode.values) (mode, mode.label),
              ],
              value: _serverMode,
              onChanged: (mode) {
                if (!_running) {
                  setState(() => _serverMode = mode);
                }
              },
            ),
          ),
          if (_serverMode == _DnsServerMode.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ToolField(
                controller: _server,
                hintText: '自定义 DNS 服务器 IP（如 1.1.1.1）',
                glyph: AppGlyphs.dns,
                enabled: !_running,
                onSubmitted: (_) => _run(),
              ),
            ),
        ],
        generateSection(
          title: '查询选项',
          items: [
            _ViaTunnelRow(
              storageKey: dnsLookupViaTunnelKey,
              title: '通过 Go 隧道解析',
              subtitle:
                  '开启后由隧道引擎解析，会套用拦截规则与缓存；'
                  '关闭时直接问系统解析器',
              value: flags.dnsLookupViaTunnel,
              enabled: !_running,
            ),
          ],
        ),
        // 按钮文案逐字照抄旧版 `DnsLookupSection`：idle「开始查询」、
        // running「查询中...」。
        _RunButton(
          glyph: AppGlyphs.search,
          label: '开始查询',
          runningLabel: '查询中…',
          running: _running,
          onPressed: _run,
        ),
        if (_hostError case final error?)
          _ToolNotice(text: error, isError: true, glyph: AppGlyphs.error),
        if (result != null) ...[
          if (result.error != null)
            _ToolNotice(
              text: result.error!,
              isError: true,
              glyph: AppGlyphs.error,
            ),
          _ToolSection(
            rows: [
              KeyValueRow(label: '查询域名', value: result.domain, monospace: true),
              KeyValueRow(
                label: '记录类型',
                value: _ipv4 ? 'A（IPv4）' : 'AAAA（IPv6）',
              ),
              KeyValueRow(
                label: 'DNS 服务器',
                value: _serverLabel(flags.dnsLookupViaTunnel),
                monospace: true,
              ),
              KeyValueRow(label: '答案来源', value: dnsSourceLabel(result.source)),
              KeyValueRow(
                label: '耗时',
                value: _msText(result.elapsedMs),
                monospace: true,
              ),
              KeyValueRow(
                label: '答案条数',
                value: '${result.answers.length}',
                monospace: true,
              ),
            ],
            footer: result.source == 'blocked'
                ? '该域名被隧道规则拦截，因此没有真实上游应答。'
                : null,
          ),
          if (result.answers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final answer in result.answers)
                      KeyValueRow(
                        label: '${answer.recordType} · TTL ${answer.ttl}s',
                        value: answer.value,
                        monospace: true,
                      ),
                  ],
                ),
              ),
            )
          else
            const _ToolNotice(
              text:
                  '没有返回任何应答记录。'
                  '若来源是「被规则拦截」，说明该域名在本机规则里被拦掉了。',
              glyph: AppGlyphs.warning,
            ),
        ],
        const ListFooter(
          text:
              '「走隧道查询」问的是本软件的解析链路（含规则与缓存），此时服务器由'
              '隧道决定；关闭后可选择跟随系统或指定一台 DNS 服务器，两者结果可能不同。',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 本次查询实际问了谁。
  ///
  /// 必须在结果区显式写出：用户改过服务器输入框但没重新查询时，结果还是上一次
  /// 的——只看「自定义」两个字会以为是刚输入的那台。
  String _serverLabel(bool viaTunnel) {
    if (viaTunnel) return '隧道引擎';
    if (_serverMode == _DnsServerMode.custom) return _server.text.trim();
    // 系统的具体地址不在结果里（原生只回答案），如实说明而不是编一个。
    return '跟随系统';
  }
}
