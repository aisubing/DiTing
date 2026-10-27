import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Add/edit custom upstream dialog (upstream `AddUpstreamDialog`). Validation reuses
/// [validateServerUpstream] so it cannot drift; a failure keeps the dialog open with the
/// reason under the field.
class UpstreamDialog extends StatefulWidget {
  const UpstreamDialog({super.key, this.initial, required this.protocol});

  final ServerUpstream? initial;

  final DnsProtocol protocol;

  @override
  State<UpstreamDialog> createState() => _UpstreamDialogState();
}

class _UpstreamDialogState extends State<UpstreamDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late final _port = TextEditingController(
    text: '${widget.initial?.port ?? _defaultPort(widget.protocol)}',
  );
  late DnsProtocol _protocol = widget.initial?.protocol ?? widget.protocol;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    super.dispose();
  }

  static int _defaultPort(DnsProtocol protocol) =>
      protocol == DnsProtocol.dot ? 853 : 53;

  void _submit() {
    final port = int.tryParse(_port.text.trim()) ?? 0;
    final validation = validateServerUpstream(
      name: _name.text,
      protocol: _protocol,
      address: _address.text,
      port: port,
    );
    if (validation is UpstreamInvalid) {
      setState(() => _error = validation.message);
      return;
    }
    final existing = widget.initial;
    Navigator.of(context).pop(
      ServerUpstream(
        id: existing?.id ?? '',
        name: _name.text.trim(),
        protocol: _protocol,
        address: _address.text.trim(),
        port: _protocol == DnsProtocol.doh ? 443 : port,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoh = _protocol == DnsProtocol.doh;
    return CommonDialog(
      title: widget.initial == null ? '添加自定义服务商' : '编辑自定义服务商',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('保存')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          SegmentedControl<DnsProtocol>(
            segments: const [
              (DnsProtocol.dns, 'DNS'),
              (DnsProtocol.doh, 'DoH'),
              (DnsProtocol.dot, 'DoT'),
            ],
            value: _protocol,
            onChanged: (value) => setState(() {
              _protocol = value;
              // Switching protocol also swaps in that protocol's default port.
              _port.text = '${_defaultPort(value)}';
              _error = null;
            }),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          TextField(
            controller: _address,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: isDoh ? 'DoH 地址' : '服务器地址',
              helperText: isDoh
                  ? '必须以 https:// 开头'
                  : 'IPv4 / IPv6 均可；IPv6 可直接填 [::1]',
            ),
          ),
          if (!isDoh)
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '端口',
                helperText: 'DNS 通常 53，DoT 通常 853',
              ),
            ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.colorScheme.error)),
        ],
      ),
    );
  }
}
