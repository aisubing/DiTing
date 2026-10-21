import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/cache_presets.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// DNS 缓存设置（上游 `CacheSettingsScreen`）。
///
/// 开关与三档预设直接读写旧版 `dns_cache_*_v2` 九个键：引擎按这份 policy
/// 工作，只改一个「预设名」不会生效。3 档是上游的完整枚举——常见的四档
/// 列表是演示数据，和 1.4.3 不一致。
class CacheSettingsPage extends ConsumerWidget {
  const CacheSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final enabled = settings.cacheEnabled;
    final preset = DnsCachePreset.current(settings);
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
                  enabled
                      ? '${preset.label}：${preset.summary}'
                      : '关闭后每次解析都会请求上游 DNS',
                ),
                value: enabled,
                onChanged: (value) {
                  preset.applyTo(settings, enabled: value);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
            ],
          ),
          if (enabled)
            generateSection(
              title: '缓存档位',
              items: [
                for (final option in DnsCachePreset.values)
                  ListItem(
                    leading: GlyphIcon(
                      preset == option
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text(option.label),
                    subtitle: Text('${option.summary}。${option.description}'),
                    trailing: preset == option ? const SelectionCheck() : null,
                    onTap: () {
                      option.applyTo(settings, enabled: enabled);
                      ref.read(legacySettingsRevisionProvider.notifier).bump();
                    },
                  ),
              ],
              footer:
                  '建议使用「标准」。档位会自动设置最长 TTL、最短 TTL 和'
                  '解析失败兜底时间，不再需要手动填写秒数。',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
