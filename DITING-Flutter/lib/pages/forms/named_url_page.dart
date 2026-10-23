/// Named URL form page (`/form/named-url`).
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/named_url_form.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

class NamedUrlPage extends StatefulWidget {
  const NamedUrlPage({super.key});

  @override
  State<NamedUrlPage> createState() => _NamedUrlPageState();
}

class _NamedUrlPageState extends State<NamedUrlPage> {
  late final _saved = <NamedUrl>[
    for (final entry in mockNamedUrls)
      (label: entry.label, url: entry.url, ageSecretKey: ''),
  ];

  var _submitting = false;

  Future<void> _save(NamedUrl value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _saved.add(value);
    });
    messenger?.showSnackBar(
      SnackBar(
        content: Text('已添加「${value.label}」'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '命名地址',
      body: PageBody(
        dockSpacer: false,
        children: [
          // `NamedUrlForm` already pads its content by 16, so adding horizontal
          // padding here would double the card indent to 32.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: NamedUrlForm(
              initial: (label: '', url: '', ageSecretKey: ''),
              title: '名称',
              submitting: _submitting,
              onSave: _save,
            ),
          ),
          generateSection(
            title: '已添加 ${_saved.length} 条',
            items: [
              for (final entry in _saved)
                ListItem(
                  title: Text(entry.label),
                  subtitle: Text(
                    entry.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(fontFamily: 'JetBrainsMono'),
                  ),
                  leading: const GlyphIcon(AppGlyphs.link),
                  trailing: entry.ageSecretKey.isEmpty
                      ? null
                      : const GlyphIcon(AppGlyphs.lock, size: 18),
                ),
            ],
            footer: '带锁图标的条目配置了 age 密钥；演示层不做真正的加解密。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}