import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// DNS 缓存设置（上游 `CacheSettingsScreen`）。
///
/// 缓存开关 + 四个预设档位；关闭时隐藏档位，与上游 `AnimatedVisibility` 等价。
enum DnsCachePreset {
  minimal(
    '最小缓存',
    '最长 TTL 5 分钟',
    '只缓存极短时间，适合频繁变更的域名。',
  ),
  standard(
    '标准',
    '最长 TTL 1 小时',
    '在命中率与新鲜度之间取平衡，推荐大多数场景。',
  ),
  extended(
    '较长时间',
    '最长 TTL 6 小时',
    '减少上游查询，适合网络稳定、域名变化少的场景。',
  ),
  aggressive(
    '激进缓存',
    '最长 TTL 24 小时',
    '最大化命中率；域名解析变更后可能延迟一天生效。',
  );

  const DnsCachePreset(this.label, this.summary, this.description);

  final String label;
  final String summary;
  final String description;
}

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  bool _enabled = true;
  DnsCachePreset _preset = DnsCachePreset.standard;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '缓存设置',
      body: PageBody(
        children: [
          generateSection(
            title: '缓存',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.memory),
                title: const Text('本地 DNS 缓存'),
                subtitle: Text(
                  _enabled
                      ? '${_preset.summary}：${_preset.description}'
                      : '关闭后每次解析都会请求上游 DNS',
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          if (_enabled)
            generateSection(
              title: '缓存档位',
              items: [
                for (final option in DnsCachePreset.values)
                  ListItem(
                    leading: GlyphIcon(
                      _preset == option
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text(option.label),
                    subtitle: Text('${option.summary}。${option.description}'),
                    trailing: _preset == option ? const SelectionCheck() : null,
                    onTap: () => setState(() => _preset = option),
                  ),
              ],
              footer: '建议使用「标准」。档位会自动设置最长 TTL、最短 TTL 和'
                  '解析失败兜底时间，不再需要手动填写秒数。',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
