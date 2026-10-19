import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 分享链接对话框（上游 `_ShareLinkDialog`）：显示一条链接并提供复制。
Future<void> showShareLinkDialog({
  required BuildContext context,
  required MockProxy proxy,
}) {
  return showFloatingDialog<void>(
    context: context,
    child: _ShareLinkDialog(proxy: proxy),
  );
}

class _ShareLinkDialog extends StatelessWidget {
  const _ShareLinkDialog({required this.proxy});

  final MockProxy proxy;

  @override
  Widget build(BuildContext context) {
    final localizations = UiLocalizations.of(context);
    final colorScheme = context.colorScheme;
    return CommonDialog(
      title: proxy.name,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.close),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: proxy.shareLink));
            Navigator.of(context).pop();
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('已复制分享链接'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 1600),
              ),
            );
          },
          child: const Text('复制'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            '链接里带着凭据，只分享给信任的人。',
            style: context.listCaptionStyle.copyWith(color: colorScheme.error),
          ),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
              shape: AppShape.sm,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                proxy.shareLink,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(fontFamily: 'JetBrainsMono', height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 从分享链接导入（上游 `_ShareLinkDialog` 的反向用法：粘一条链接建一个节点）。
///
/// 演示版不解析真实协议编码，只按协议前缀识别类型，再用一条内置模板填表；
/// 关键是要让人看到「粘一条链接 → 表单被填好 → 还能进去改」这条路。
class ShareLinkParseSheet extends ConsumerStatefulWidget {
  const ShareLinkParseSheet({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ShareLinkParseSheet> createState() =>
      _ShareLinkParseSheetState();
}

class _ShareLinkParseSheetState extends ConsumerState<ShareLinkParseSheet> {
  final _link = TextEditingController();
  String? _error;
  MockProxy? _parsed;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _link.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = '请粘贴一条分享链接';
        _parsed = null;
      });
      return;
    }
    final protocol = _protocolOf(text);
    if (protocol == null) {
      setState(() {
        _error = '无法识别的链接：支持 ss / vmess / vless / trojan / hysteria2 / tuic';
        _parsed = null;
      });
      return;
    }
    final uri = Uri.tryParse(text);
    final host = uri?.host ?? '';
    final port = uri?.port ?? 0;
    if (host.isEmpty) {
      setState(() {
        _error = '链接里没有有效的主机名';
        _parsed = null;
      });
      return;
    }
    final name = uri?.fragment.isNotEmpty == true
        ? Uri.decodeComponent(uri!.fragment)
        : '${protocol.label} 节点';
    setState(() {
      _error = null;
      _parsed = MockProxy(
        id: 'n-parsed',
        name: name,
        protocol: protocol,
        server: host,
        port: port == 0 ? protocol.defaultPort : port,
        latencyMs: 0,
        password: uri?.userInfo ?? '',
        tls: protocol.supportsTls,
        sni: host,
      );
    });
  }

  ProxyProtocol? _protocolOf(String text) {
    for (final protocol in ProxyProtocol.values) {
      if (text.toLowerCase().startsWith('${protocol.value}://')) {
        return protocol;
      }
    }
    // SS 链接常见 `ss://` 前缀，但也会写成 `ssr://`；两者都当 shadowsocks。
    if (text.toLowerCase().startsWith('ssr://')) {
      return ProxyProtocol.shadowsocks;
    }
    return null;
  }

  void _submit() {
    final parsed = _parsed;
    if (parsed == null) {
      _parse();
      return;
    }
    final notifier = ref.read(customProxiesProvider.notifier);
    notifier.put(
      notifier.create(
        name: parsed.name,
        protocol: parsed.protocol,
        server: parsed.server,
        port: parsed.port,
        cipher: parsed.cipher,
        password: parsed.password,
        tls: parsed.tls,
        sni: parsed.sni,
        skipCertVerify: false,
        udp: true,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final parsed = _parsed;
    return CommonScaffold(
      title: '从分享链接导入',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '导入节点',
        onPressed: _submit,
      ),
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
            '支持 ss / vmess / vless / trojan / hysteria2 / tuic。演示版只识别协议与'
            '主机，不解析加密参数。',
            style: context.listCaptionStyle,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _link,
            minLines: 3,
            maxLines: 5,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(fontFamily: 'JetBrainsMono', height: 1.5),
            decoration: const InputDecoration(
              hintText: 'vmess://…@hk01.example.net:443#香港 01',
            ),
            onChanged: (_) {
              if (_error != null || _parsed != null) {
                setState(() {
                  _error = null;
                  _parsed = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              FilledButton(onPressed: _parse, child: const Text('解析')),
              if (parsed != null)
                Text(
                  '已识别：${parsed.protocol.label}',
                  style: context.listCaptionStyle.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Row(
              spacing: 6,
              children: [
                GlyphIcon(AppGlyphs.error, size: 16, color: colorScheme.error),
                Expanded(
                  child: Text(
                    error,
                    style: context.listCaptionStyle.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (parsed != null) ...[
            const SizedBox(height: 16),
            generateSection(
              title: '解析结果',
              items: [
                KeyValueRow(label: '名称', value: parsed.name),
                KeyValueRow(
                  label: '协议',
                  value: parsed.protocol.label,
                  monospace: true,
                ),
                KeyValueRow(
                  label: '地址',
                  value: '${parsed.server}:${parsed.port}',
                  monospace: true,
                ),
                KeyValueRow(
                  label: 'SNI',
                  value: parsed.sni.isEmpty ? '—' : parsed.sni,
                  monospace: true,
                ),
              ],
              footer: '导入后可以在节点卡片里继续编辑。',
            ),
          ],
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}
