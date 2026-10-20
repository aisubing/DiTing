part of 'tools_page.dart';

/// DNS 查询面板。
///
/// 数据源是 `DiagnosticsRunner.lookupDns`。与旧版一致的两点：
/// 1. `viaTunnel` 决定问隧道引擎（`Engine.resolveDomain`，走本软件自己的规则与
///    缓存）还是问系统解析器；
/// 2. 结果必须标 `source`：只有 `upstream` 表示真的打到了上游解析器，
///    `cache` / `rewrite` / `blocked` 都是隧道自己给的答案。把 `blocked` 显示成
///    「解析成功」会让用户以为域名正常。
class _DnsLookupPanel extends ConsumerStatefulWidget {
  const _DnsLookupPanel();

  @override
  ConsumerState<_DnsLookupPanel> createState() => _DnsLookupPanelState();
}

class _DnsLookupPanelState extends ConsumerState<_DnsLookupPanel> {
  final _domain = TextEditingController(text: '');
  var _running = false;
  var _ipv4 = true;
  DnsLookupResult? _result;
  String? _hostError;

  @override
  void dispose() {
    _domain.dispose();
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
    setState(() {
      _hostError = null;
      _running = true;
      _result = null;
    });
    final result = await ref
        .read(diagnosticsRunnerProvider)
        .lookupDns(
          resolved.host,
          viaTunnel: ref.read(networkToolFlagsProvider).dnsLookupViaTunnel,
          ipv4: _ipv4,
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
    return CommonScaffold(
      title: 'DNS 查询',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ToolField(
              controller: _domain,
              hintText: '要查询的域名',
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
          generateSection(
            title: '查询选项',
            items: [
              _ViaTunnelRow(
                storageKey: dnsLookupViaTunnelKey,
                title: '走隧道查询',
                subtitle: '开启后由隧道引擎解析，会套用拦截规则与缓存；'
                    '关闭时直接问系统解析器',
                value: flags.dnsLookupViaTunnel,
                enabled: !_running,
              ),
            ],
          ),
          _RunButton(
            glyph: AppGlyphs.search,
            label: '发起查询',
            runningLabel: '正在查询…',
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
                KeyValueRow(
                  label: '查询域名',
                  value: result.domain,
                  monospace: true,
                ),
                KeyValueRow(
                  label: '记录类型',
                  value: _ipv4 ? 'A（IPv4）' : 'AAAA（IPv6）',
                ),
                KeyValueRow(
                  label: '答案来源',
                  value: dnsSourceLabel(result.source),
                ),
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
                          label:
                              '${answer.recordType} · TTL ${answer.ttl}s',
                          value: answer.value,
                          monospace: true,
                        ),
                    ],
                  ),
                ),
              )
            else
              const _ToolNotice(
                text: '没有返回任何应答记录。'
                    '若来源是「被规则拦截」，说明该域名在本机规则里被拦掉了。',
                glyph: AppGlyphs.warning,
              ),
          ],
          const ListFooter(
            text: '「走隧道查询」问的是本软件的解析链路（含规则与缓存）；'
                '关闭时问系统解析器，两者结果可能不同。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
