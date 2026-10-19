/// 代理提供者编辑表单（上游 `views/proxies/providers.dart` 的编辑面板）。
///
/// 只改四项演示字段：名称、订阅地址、自动更新间隔、节点名过滤。
/// 保存走 [onSave] 回调而不是自己改 provider，这样页面能决定保存后要不要关闭浮层。
///
/// 刻意**不用** `ListItem.input`：它是「点一行弹一个输入对话框」的语义，适合
/// 单字段微调；这里是四字段一起看、一起校验的表单，用内联 `TextField` 行更短。
library;

import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

class ProxyProviderForm extends StatefulWidget {
  const ProxyProviderForm({
    super.key,
    required this.entry,
    required this.onSave,
  });

  final ProxyProviderEntry entry;
  final ValueChanged<ProxyProviderEntry> onSave;

  @override
  State<ProxyProviderForm> createState() => _ProxyProviderFormState();
}

class _ProxyProviderFormState extends State<ProxyProviderForm> {
  late final _name = TextEditingController(text: widget.entry.name);
  late final _url = TextEditingController(text: widget.entry.url);
  late final _filter = TextEditingController(text: widget.entry.filter ?? '');
  late int _interval = widget.entry.intervalHours;

  /// 间隔选项。用固定档位而不是数字输入框：真实用法里几乎没人填 37 小时。
  static const _intervals = <int>[0, 6, 12, 24, 72, 168];

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _filter.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _url.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) {
      return;
    }
    final trimmedFilter = _filter.text.trim();
    widget.onSave(
      widget.entry.copyWith(
        name: _name.text.trim(),
        url: _url.text.trim(),
        intervalHours: _interval,
        filter: trimmedFilter.isEmpty ? null : trimmedFilter,
        // `copyWith(filter: null)` 走不到，清空必须用这个标记。
        clearFilter: trimmedFilter.isEmpty,
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '编辑提供者',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存',
        onPressed: _valid ? _save : null,
      ),
      body: PageBody(
        children: [
          generateSection(
            title: '基本信息',
            items: [
              _Field(
                title: '名称',
                controller: _name,
                hintText: '给这个提供者起个名字',
                onChanged: (_) => setState(() {}),
              ),
              _Field(
                title: '订阅地址',
                controller: _url,
                hintText: 'https://',
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
              _Field(
                title: '节点名过滤',
                controller: _filter,
                hintText: '🇭🇰|🇯🇵|🇸🇬',
                footnote: '正则；留空表示不过滤',
                onChanged: (_) => setState(() {}),
              ),
            ],
            footer: '过滤只影响从该提供者导入哪些节点，不改变原始订阅。',
          ),
          generateSection(
            title: '自动更新',
            items: [
              ListItem<int>.options(
                title: const Text('更新间隔'),
                options: _intervals,
                value: _interval,
                textBuilder: _intervalLabel,
                onChanged: (value) => setState(() => _interval = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _intervalLabel(int hours) => switch (hours) {
    0 => '不自动更新',
    6 => '每 6 小时',
    12 => '每 12 小时',
    24 => '每天',
    72 => '每 3 天',
    168 => '每周',
    _ => '每 $hours 小时',
  };
}

/// 一行「标题 + 内联输入框」。
///
/// 用 `CommonCard` 自己拼而不是 `ListItem`：`ListItem` 的四种具名构造里没有
/// 「内联多行输入」这一种，硬套 `.input` 会变成点一下弹对话框。
class _Field extends StatelessWidget {
  const _Field({
    required this.title,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.footnote,
    this.keyboardType,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? footnote;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              title,
              style: AppTextStyle.caption1
                  .of(context, emphasized: true)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: AppTextStyle.body.of(context),
              cursorColor: colorScheme.primary,
              decoration: InputDecoration.collapsed(
                hintText: hintText,
                hintStyle: AppTextStyle.body.of(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (footnote != null)
              Text(
                footnote!,
                style: AppTextStyle.caption2.of(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
