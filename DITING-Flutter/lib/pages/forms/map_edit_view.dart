library;

import 'package:diting/pages/forms/batch_section.dart';
import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class MapEntryDraft {
  MapEntryDraft({required this.key, required this.value});

  String key;
  String value;
}

class MapEditView extends StatefulWidget {
  const MapEditView({
    super.key,
    required this.entries,
    required this.onChanged,
    this.keyHint = '键',
    this.valueHint = '值',
    this.title = '键值对',
    this.footer,
  });

  final List<MapEntryDraft> entries;

  /// Every change reports the full new list; the caller owns the state.
  final ValueChanged<List<MapEntryDraft>> onChanged;

  final String keyHint;
  final String valueHint;
  final String title;
  final String? footer;

  @override
  State<MapEditView> createState() => _MapEditViewState();
}

class _MapEditViewState extends State<MapEditView> {
  final _batch = TextEditingController();
  late List<MapEntryDraft> _entries = [...widget.entries];

  /// One controller per key, cached by identity so rebuilds keep the cursor.
  final _keyControllers = <MapEntryDraft, TextEditingController>{};
  final _valueControllers = <MapEntryDraft, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final entry in _entries) {
      _controllerFor(entry, isKey: true).text = entry.key;
      _controllerFor(entry, isKey: false).text = entry.value;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      ..._keyControllers.values,
      ..._valueControllers.values,
    ]) {
      controller.dispose();
    }
    _batch.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(
    MapEntryDraft entry, {
    required bool isKey,
  }) {
    final cache = isKey ? _keyControllers : _valueControllers;
    return cache.putIfAbsent(
      entry,
      () => TextEditingController(text: isKey ? entry.key : entry.value),
    );
  }

  void _apply(List<MapEntryDraft> entries) {
    setState(() => _entries = entries);
    widget.onChanged(entries);
  }

  void _add() {
    final entry = MapEntryDraft(key: '', value: '');
    _apply([..._entries, entry]);
  }

  void _remove(MapEntryDraft entry) {
    final controllers = [
      _keyControllers.remove(entry),
      _valueControllers.remove(entry),
    ];
    for (final controller in controllers) {
      controller?.dispose();
    }
    _apply([
      for (final other in _entries)
        if (!identical(other, entry)) other,
    ]);
  }

  /// Batch parse: one `key=value` per line, skipping blanks and lines without `=`.
  void _importBatch() {
    final lines = _batch.text.split('\n');
    final added = <MapEntryDraft>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final index = trimmed.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      if (key.isEmpty) {
        continue;
      }
      added.add(MapEntryDraft(key: key, value: value));
    }
    if (added.isEmpty) {
      return;
    }
    for (final entry in added) {
      _controllerFor(entry, isKey: true).text = entry.key;
      _controllerFor(entry, isKey: false).text = entry.value;
    }
    _apply([..._entries, ...added]);
    _batch.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ListHeader(
          title: widget.title,
          trailing: Text(
            '${_entries.length} 项',
            style: context.listCaptionStyle,
          ),
        ),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '还没有键值对，用下面的批量输入一次粘贴吧。',
              style: context.listCaptionStyle,
            ),
          )
        else
          generateSection(
            items: [
              for (final entry in _entries)
                _MapEntryRow(
                  keyController: _controllerFor(entry, isKey: true),
                  valueController: _controllerFor(entry, isKey: false),
                  keyHint: widget.keyHint,
                  valueHint: widget.valueHint,
                  onKeyChanged: (value) {
                    entry.key = value;
                    widget.onChanged(_entries);
                  },
                  onValueChanged: (value) {
                    entry.value = value;
                    widget.onChanged(_entries);
                  },
                  onRemove: () => _remove(entry),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 8,
            children: [
              TonalButton(
                label: '添加一行',
                glyph: AppGlyphs.add,
                size: TonalButtonSize.section,
                onPressed: _add,
              ),
              const Spacer(),
              if (widget.footer case final footer?)
                Flexible(
                  child: Text(
                    footer,
                    style: context.listCaptionStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ),
        BatchSection(
          controller: _batch,
          title: '批量导入',
          hintText: 'mixed-port=7890\nallow-lan=true',
          footer:
              '每行一条，格式为「键=值」；忽略空行与不含等号的行。'
              '导入后追加到现有列表，不覆盖同名键（同名键在保存时由调用方去重）。',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TonalButton(
            label: '解析并添加',
            glyph: AppGlyphs.importFile,
            size: TonalButtonSize.section,
            onPressed: _importBatch,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '当前共 ${_entries.length} 项，其中空键 ${_entries.where((e) => e.key.trim().isEmpty).length} 项。'
            '空键在保存前会被拦下。',
            style: context.listCaptionStyle.copyWith(
              color: _entries.any((e) => e.key.trim().isEmpty)
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapEntryRow extends StatelessWidget {
  const _MapEntryRow({
    required this.keyController,
    required this.valueController,
    required this.keyHint,
    required this.valueHint,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onRemove,
  });

  final TextEditingController keyController;
  final TextEditingController valueController;
  final String keyHint;
  final String valueHint;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return FormRow(
      title: '键值',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Flexible(
            flex: 2,
            child: _BareField(
              controller: keyController,
              hintText: keyHint,
              textAlign: TextAlign.end,
              onChanged: onKeyChanged,
            ),
          ),
          Text('=', style: context.listCaptionStyle),
          Flexible(
            flex: 3,
            child: _BareField(
              controller: valueController,
              hintText: valueHint,
              textAlign: TextAlign.start,
              onChanged: onValueChanged,
            ),
          ),
          CommonMinIconButtonTheme(
            child: IconButton(
              tooltip: '删除',
              onPressed: onRemove,
              icon: GlyphIcon(
                AppGlyphs.removeCircle,
                size: 18,
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BareField extends StatelessWidget {
  const _BareField({
    required this.controller,
    required this.hintText,
    required this.textAlign,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextAlign textAlign;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textAlign: textAlign,
      style: context.listTitleStyle.copyWith(fontFamily: 'JetBrainsMono'),
      decoration: InputDecoration.collapsed(
        hintText: hintText,
        hintStyle: context.listCaptionStyle,
      ),
    );
  }
}