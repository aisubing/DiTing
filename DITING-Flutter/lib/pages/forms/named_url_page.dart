/// 命名 URL 表单页（`/form/named-url`）。
///
/// 把 `NamedUrlForm` 装进页面：保存时把新记录追加到页内列表，列表本身用
/// `generateSection` 展示。上游把这份表单放在订阅编辑的浮层里；这里做成整页，
/// 便于演示与截图。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/named_url_form.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 命名 URL 表单页。
class NamedUrlPage extends StatefulWidget {
  const NamedUrlPage({super.key});

  @override
  State<NamedUrlPage> createState() => _NamedUrlPageState();
}

class _NamedUrlPageState extends State<NamedUrlPage> {
  /// 已保存的记录；初始来自演示数据。
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
          // `NamedUrlForm` 内部自己按 16 排每块内容，外层再套一次横向 16 会让
          // 表单卡片比下方「已添加 N 条」这组缩进一倍（真机量到 32 vs 16）。
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
