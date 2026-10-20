import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 新增 / 编辑节点的表单（上游 `_EditCustomProxyView`，约 700 行）。
///
/// 上游把 30 多个 `ProxyField` 按「认证 / 传输 / TLS / 连接」分组渲染。演示里
/// 只保留每类里真正影响能否连通的字段（协议、地址、端口、加密方式、密码、
/// TLS 三件套、UDP），因为剩下的字段没有真实内核可验证，填了也只是装饰。
///
/// 表单结构与上游一致：分组 `generateSection` + 内联输入行，不用对话框——
/// 一个对话框放不下七行字段。
class CustomProxyFormSheet extends ConsumerStatefulWidget {
  const CustomProxyFormSheet({super.key, required this.profileId, this.proxy});

  final String profileId;
  final MockProxy? proxy;

  @override
  ConsumerState<CustomProxyFormSheet> createState() =>
      _CustomProxyFormSheetState();
}

class _CustomProxyFormSheetState extends ConsumerState<CustomProxyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _port = TextEditingController();
  final _cipher = TextEditingController();
  final _password = TextEditingController();
  final _sni = TextEditingController();
  var _protocol = ProxyProtocol.vmess;
  var _tls = true;
  var _skipCertVerify = false;
  var _udp = true;

  bool get _isEditing => widget.proxy != null;

  @override
  void initState() {
    super.initState();
    final proxy = widget.proxy;
    if (proxy == null) {
      _port.text = '${_protocol.defaultPort}';
      return;
    }
    _name.text = proxy.name;
    _server.text = proxy.server;
    _port.text = '${proxy.port}';
    _cipher.text = proxy.cipher;
    _password.text = proxy.password;
    _sni.text = proxy.sni;
    _protocol = proxy.protocol;
    _tls = proxy.tls;
    _skipCertVerify = proxy.skipCertVerify;
    _udp = proxy.udp;
  }

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _port.dispose();
    _cipher.dispose();
    _password.dispose();
    _sni.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final port = int.tryParse(_port.text.trim()) ?? _protocol.defaultPort;
    final notifier = ref.read(customProxiesProvider.notifier);
    final existing = widget.proxy;
    final saved = existing == null
        ? notifier.put(
            notifier.create(
              name: _name.text,
              protocol: _protocol,
              server: _server.text,
              port: port,
              cipher: _cipher.text,
              password: _password.text,
              tls: _protocol.supportsTls && _tls,
              sni: _sni.text,
              skipCertVerify: _protocol.supportsTls && _skipCertVerify,
              udp: _udp,
            ),
          )
        : notifier.put(
            existing.copyWith(
              name: _name.text,
              protocol: _protocol,
              server: _server.text,
              port: port,
              cipher: _cipher.text,
              password: _password.text,
              tls: _protocol.supportsTls && _tls,
              sni: _sni.text,
              skipCertVerify: _protocol.supportsTls && _skipCertVerify,
              udp: _udp,
            ),
          );
    if (!saved) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('已有同名节点'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: _isEditing ? '编辑节点' : '添加节点',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存节点',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            generateSection(
              title: '基本',
              items: [
                _ProxyFieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(
                      hintText: '如：香港 01 · IPLC',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '名称不能为空' : null,
                  ),
                ),
                ListItem<ProxyProtocol>.options(
                  title: const Text('协议'),
                  options: ProxyProtocol.values,
                  value: _protocol,
                  textBuilder: (protocol) => protocol.label,
                  onChanged: (protocol) => setState(() {
                    _protocol = protocol;
                    // 换协议时端口跟着换到该协议的常见端口，省得每次都改。
                    if (_port.text.isEmpty ||
                        int.tryParse(_port.text) ==
                            _previousProtocol.defaultPort) {
                      _port.text = '${protocol.defaultPort}';
                    }
                    _previousProtocol = protocol;
                  }),
                ),
                _ProxyFieldRow(
                  label: '地址',
                  child: TextFormField(
                    controller: _server,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(hintText: 'hk01.example.net'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '地址不能为空';
                      }
                      if (text.contains(RegExp(r'[\s/]'))) {
                        return '只填主机名或 IP，不要带协议与路径';
                      }
                      return null;
                    },
                  ),
                ),
                _ProxyFieldRow(
                  label: '端口',
                  child: TextFormField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(hintText: '443'),
                    validator: (value) {
                      final port = int.tryParse((value ?? '').trim());
                      if (port == null || port <= 0 || port > 65535) {
                        return '端口需在 1–65535 之间';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            generateSection(
              title: '认证',
              items: [
                if (_protocol.supportsCipher)
                  _ProxyFieldRow(
                    label: '加密方式',
                    child: TextFormField(
                      controller: _cipher,
                      style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      decoration: const InputDecoration(
                        hintText: 'aes-256-gcm',
                      ),
                    ),
                  ),
                _ProxyFieldRow(
                  label:
                      _protocol == ProxyProtocol.shadowsocks ||
                          _protocol == ProxyProtocol.trojan ||
                          _protocol == ProxyProtocol.hysteria2
                      ? '密码'
                      : 'UUID / 密钥',
                  child: TextFormField(
                    controller: _password,
                    obscureText: false,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(hintText: '从服务商处复制'),
                    validator: (value) =>
                        (value ?? '').isEmpty ? '这一项不能为空' : null,
                  ),
                ),
              ],
              footer: '凭据以明文保存在演示状态里；真实实现要放进加密存储。',
            ),
            if (_protocol.supportsTls)
              generateSection(
                title: 'TLS',
                items: [
                  ListItem.toggle(
                    title: const Text('启用 TLS'),
                    subtitle: const Text('关闭后 SNI 与证书校验都不生效'),
                    value: _tls,
                    onChanged: (value) => setState(() => _tls = value),
                  ),
                  if (_tls)
                    _ProxyFieldRow(
                      label: 'SNI',
                      child: TextFormField(
                        controller: _sni,
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        decoration: InputDecoration(
                          hintText: _server.text.isEmpty
                              ? '留空则用地址'
                              : _server.text,
                        ),
                      ),
                    ),
                  if (_tls)
                    ListItem.toggle(
                      title: const Text('跳过证书校验'),
                      subtitle: const Text('自签证书才需要，开启后无法防中间人'),
                      value: _skipCertVerify,
                      onChanged: (value) =>
                          setState(() => _skipCertVerify = value),
                    ),
                ],
              ),
            generateSection(
              title: '连接',
              items: [
                ListItem.toggle(
                  title: const Text('转发 UDP'),
                  subtitle: const Text('游戏与语音通话需要；部分协议不支持'),
                  value: _udp,
                  onChanged: (value) => setState(() => _udp = value),
                ),
              ],
            ),
            if (!_isEditing)
              const ListFooter(text: '保存后延迟显示为「未测速」，在组里选中它时才会真正发起探测。'),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }

  /// 上一次的协议，用来判断端口是不是「跟着协议自动填的」。
  ///
  /// 只有自动填的端口才跟着换；用户手改过的端口不该被覆盖。
  ProxyProtocol _previousProtocol = ProxyProtocol.vmess;
}

/// 表单行：左标签 + 右输入框。
class _ProxyFieldRow extends StatelessWidget {
  const _ProxyFieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: context.listTitleStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
