import 'package:diting/data/db/mirror_template_repository.dart';
import 'package:diting/state/global_mirror_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Global mirror switch on the mirror-template page: once on, every subscription without its own
/// template and the app update check and download go through the chosen template.
class GlobalMirrorSection extends ConsumerWidget {
  const GlobalMirrorSection({super.key, required this.templates});

  final List<MirrorTemplateRecord> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mirror = ref.watch(globalMirrorProvider);
    final notifier = ref.read(globalMirrorProvider.notifier);
    final selected = templates
        .where((row) => row.template == mirror.template)
        .firstOrNull;
    return generateSection(
      title: '全局镜像',
      items: [
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.bolt),
          title: const Text('默认使用镜像下载'),
          subtitle: Text(
            templates.isEmpty ? '先添加一个模板后才能开启' : '订阅下载与软件更新都经由所选模板',
          ),
          value: mirror.enabled && templates.isNotEmpty,
          onChanged: templates.isEmpty
              ? null
              : (value) => notifier.setEnabled(
                  value,
                  // A stale or missing choice falls back to the newest template.
                  fallbackTemplate: selected == null
                      ? templates.first.template
                      : null,
                ),
        ),
        if (mirror.enabled && templates.isNotEmpty)
          ListItem<MirrorTemplateRecord>.options(
            leading: const GlyphIcon(AppGlyphs.layers),
            title: const Text('使用的模板'),
            // The saved string is what downloads use, even if this mode's list lacks it.
            subtitle: Text(
              mirror.template ?? templates.first.template,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            options: templates,
            value: selected ?? templates.first,
            textBuilder: (row) => row.name,
            onChanged: (row) => notifier.select(row.template),
          ),
      ],
      footer:
          '开启后，未单独设置镜像的订阅、检查更新与下载安装包都会先请求镜像，'
          '镜像失败时自动改用原始地址。单独设置过镜像的订阅仍按自己的设置。',
    );
  }
}
