part of 'edit_profile_page.dart';

/// 表单里的文本行：左标签 + 右输入框。
///
/// 不复用 `ListItem.input`（那个自带点击弹窗），也不用 `Form` + `TextFormField`
/// 的校验：这里一次只报一条错误，校验集中在页面里的 `_issue` 里，字段本身只
/// 负责把「是否出错」画成边框颜色。
class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.invalid = false,
    this.monospace = false,
    this.keyboardType,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool invalid;
  final bool monospace;
  final TextInputType? keyboardType;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: context.listTitleStyle.copyWith(
                color: invalid ? colorScheme.error : null,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: monospace
                  ? context.listSubtitleStyle.copyWith(
                      fontFamily: 'JetBrainsMono',
                    )
                  : null,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                enabledBorder: invalid
                    ? AppShape.input.copyWith(
                        borderSide: BorderSide(color: colorScheme.error),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 文件条目（上游 `_ProfileFileItem`）：只读信息 + 预览入口。
///
/// 上游这一行可以「编辑」（打开代码编辑器改文本）和「上传」（换一个文件）。
/// 演示版没有文件系统，两个动作都收成「查看运行配置」——至少让用户看到内容。
class _ProfileFileItem extends StatelessWidget {
  const _ProfileFileItem({required this.profile, required this.onPreview});

  final MockProfile profile;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final isLocal = profile.kind == ProfileKind.local;
    return ListItem(
      leading: GlyphIcon(
        isLocal ? AppGlyphs.importFile : AppGlyphs.layers,
        color: context.colorScheme.secondary,
      ),
      title: Text(
        isLocal
            ? (profile.fileName.isEmpty ? '本地文件' : profile.fileName)
            : '合并档案',
      ),
      subtitle: Text(
        isLocal
            ? '${profile.fileSize.isEmpty ? '—' : profile.fileSize} · ${profile.updatedAt}'
            : '由节点、组与规则手工维护，没有源文件',
        style: context.listCaptionStyle,
      ),
      trailing: TextButton(onPressed: onPreview, child: const Text('查看')),
    );
  }
}
