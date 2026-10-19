part of 'override_spec_page.dart';

/// 一行覆写条目：行首删除按钮 + 按字段类型渲染的值控件。
class OverrideEntryRow extends ConsumerWidget {
  const OverrideEntryRow({
    super.key,
    required this.spec,
    required this.entry,
    required this.value,
  });

  final MockOverrideSpec spec;
  final MockOverrideEntry entry;
  final String value;

  void _set(WidgetRef ref, String next) =>
      ref.read(overrideProvider.notifier).setValue(spec.id, entry.key, next);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remove = ConfigRemoveButton(
      tooltip: '移除 ${entry.label}',
      onPressed: () =>
          ref.read(overrideProvider.notifier).remove(spec.id, entry.key),
    );
    final description = entry.description;
    return switch (entry.kind) {
      OverrideFieldKind.toggle => ListItem.toggle(
        leading: remove,
        title: Text(entry.label),
        subtitle: description == null ? null : Text(description),
        value: _asBool(value),
        onChanged: (on) => _set(ref, on ? 'true' : 'false'),
      ),
      OverrideFieldKind.options => ListItem<String>.options(
        leading: remove,
        title: Text(entry.label),
        subtitle: description == null ? null : Text(description),
        options: entry.options,
        value: entry.options.contains(value) ? value : entry.options.first,
        textBuilder: (option) => option,
        onChanged: (option) => _set(ref, option),
      ),
      OverrideFieldKind.number => ListItem.input(
        leading: remove,
        title: Text(entry.label),
        subtitle: Text(_numberSummary()),
        dialogTitle: entry.label,
        value: value,
        keyboardType: TextInputType.number,
        maxLength: TextInputLimits.number,
        validator: _validateNumber,
        onChanged: (next) => _set(ref, (next ?? '').trim()),
      ),
      OverrideFieldKind.text => ListItem.input(
        leading: remove,
        title: Text(entry.label),
        subtitle: Text(value.isEmpty ? '未设置' : value),
        dialogTitle: entry.label,
        value: value,
        maxLength: TextInputLimits.dnsListen,
        onChanged: (next) => _set(ref, (next ?? '').trim()),
      ),
      OverrideFieldKind.list => ListItem(
        leading: remove,
        title: Text(entry.label),
        subtitle: Text(_listSummary()),
        trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
        onTap: () => showOverrideListSheet(context, spec, entry),
      ),
    };
  }

  String _numberSummary() {
    final unit = entry.unit;
    final text = value.trim().isEmpty ? '未设置' : value;
    return unit == null ? text : '$text $unit';
  }

  String _listSummary() {
    final items = splitOverrideList(value);
    return switch (items.length) {
      0 => '未设置',
      1 => items.first,
      _ => '${items.first} 等 ${items.length} 项',
    };
  }

  String? _validateNumber(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) {
      return '清空等于不覆写这一项';
    }
    final number = int.tryParse(text);
    if (number == null) {
      return '必须是数字';
    }
    final min = entry.min;
    final max = entry.max;
    if (min != null && number < min) {
      return '不能小于 $min';
    }
    if (max != null && number > max) {
      return '不能大于 $max';
    }
    return null;
  }
}

bool _asBool(String value) => value.trim().toLowerCase() == 'true';
