import 'package:diting/data/mock_data.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 服务显示（上游 `HomeProviderVisibilityScreen`）。
///
/// 关闭竞速时，首页解析服务下拉框只显示这里选中的服务；当前正在使用的
/// 服务会始终保留。
class ProviderVisibilityPage extends StatefulWidget {
  const ProviderVisibilityPage({super.key});

  @override
  State<ProviderVisibilityPage> createState() => _ProviderVisibilityPageState();
}

class _ProviderVisibilityPageState extends State<ProviderVisibilityPage> {
  final Set<ProviderProtocol> _visibleProtocols = {...ProviderProtocol.values};
  final Set<String> _hiddenProviders = {};

  bool _visible(ProviderProtocol protocol, MockProvider provider) =>
      _visibleProtocols.contains(protocol) &&
      !_hiddenProviders.contains(provider.id);

  void _setProtocol(ProviderProtocol protocol, bool visible) {
    setState(() {
      if (visible) {
        _visibleProtocols.add(protocol);
      } else {
        _visibleProtocols.remove(protocol);
      }
      _hiddenProviders.removeAll(
        mockProviders
            .where((provider) => provider.protocol == protocol)
            .map((provider) => provider.id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '服务显示',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '关闭竞速模式时，首页解析服务下拉框仅显示这里选中的服务。'
                '当前正在使用的服务会始终保留。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          for (final protocol in ProviderProtocol.values)
            _protocolSection(protocol),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _protocolSection(ProviderProtocol protocol) {
    final providers = mockProviders
        .where((provider) => provider.protocol == protocol)
        .toList(growable: false);
    final selectedCount = providers
        .where((provider) => _visible(protocol, provider))
        .length;
    final protocolVisible = _visibleProtocols.contains(protocol);
    return generateSection(
      title: '${protocol.label} 服务',
      items: [
        ListItem(
          leading: GlyphIcon(
            protocolVisible ? AppGlyphs.checkCircle : AppGlyphs.removeCircle,
            size: 20,
          ),
          title: Text('全部 ${protocol.label} 服务'),
          subtitle: Text(
            !protocolVisible
                ? '不显示该类型的服务'
                : selectedCount == providers.length
                ? '显示该类型的全部服务'
                : '已选择 $selectedCount 个服务',
          ),
          trailing: CommonCheckBox(
            value: protocolVisible && selectedCount > 0,
            onChanged: (_) => _setProtocol(protocol, !protocolVisible),
          ),
          onTap: () => _setProtocol(protocol, !protocolVisible),
        ),
        for (final provider in providers)
          ListItem(
            leading: GlyphIcon(
              _visible(protocol, provider)
                  ? AppGlyphs.checkCircle
                  : AppGlyphs.removeCircle,
              size: 20,
            ),
            title: Text(provider.name),
            subtitle: Text(provider.address),
            trailing: CommonCheckBox(
              value: _visible(protocol, provider),
              onChanged: (_) => setState(() {
                if (!_hiddenProviders.remove(provider.id)) {
                  _hiddenProviders.add(provider.id);
                }
              }),
            ),
            onTap: () => setState(() {
              if (!_hiddenProviders.remove(provider.id)) {
                _hiddenProviders.add(provider.id);
              }
            }),
          ),
      ],
    );
  }
}
