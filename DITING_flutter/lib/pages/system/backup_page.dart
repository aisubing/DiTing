/// 备份与恢复（上游 `views/backup_and_restore.dart`，491 行）。
///
/// 三块内容：本地导出、恢复（多选恢复项）、WebDAV 远端备份。WebDAV 表单在
/// 上游是一个独立的 `WebDAVForm` 组件，这里同样拆到 `backup_webdav_form.dart`：
/// 表单里有自己的连接状态机，塞回页面会让「页面读什么、表单读什么」混在一起。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'backup_webdav_form.dart';

/// 备份与恢复页。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  /// 上次导出的时间戳；`null` 表示本次会话还没导出过。
  DateTime? _lastExport;

  /// 恢复项的勾选结果：默认全选，因为多数用户就是「全都要」。
  var _restoreOptions = {...RestoreOption.values};

  Future<void> _export(String what) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }
    setState(() => _lastExport = DateTime.now());
    messenger?.showSnackBar(
      SnackBar(
        content: Text('$what 已导出到剪贴板（演示：未真正写文件）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (_restoreOptions.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('至少选择一项要恢复的内容'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    final confirmed = await _showRestoreConfirm();
    if (confirmed != true) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    messenger?.showSnackBar(
      SnackBar(
        content: Text('已恢复 ${_restoreOptions.length} 项内容'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<bool?> _showRestoreConfirm() => showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: '确认恢复',
      destructive: true,
      hasFields: false,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('恢复'),
        ),
      ],
      child: Text(
        '将覆盖当前的'
        '${_restoreOptions.map((option) => option.label).join('、')}。'
        '覆盖后无法撤销，建议先导出当前配置。',
      ),
    ),
  );

  /// 恢复项多选浮层。
  Future<void> _pickOptions() async {
    final result = await showFormSheet<Set<RestoreOption>>(
      context: context,
      props: const SheetProps(detents: [0.7]),
      builder: (_) => _RestoreOptionsSheet(initial: _restoreOptions),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _restoreOptions = result);
  }

  @override
  Widget build(BuildContext context) {
    final dav = ref.watch(davProvider);
    final colorScheme = context.colorScheme;
    final lastExport = _lastExport;
    return CommonScaffold(
      title: '备份与恢复',
      body: PageBody(
        children: [
          const SizedBox(height: 8),
          _DavConnectionIndicator(status: dav.status, message: dav.message),
          generateSection(
            title: '导出',
            footer: '导出内容为 JSON 文本，演示层只写剪贴板，不落文件。',
            items: [
              ListItem(
                title: const Text('导出配置'),
                subtitle: const Text('外观、底栏、解析模式等全部应用设置'),
                leading: const GlyphIcon(AppGlyphs.export),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _export('配置'),
              ),
              ListItem(
                title: const Text('导出规则'),
                subtitle: const Text('黑名单 / 白名单 / 覆写规则与订阅地址'),
                leading: const GlyphIcon(AppGlyphs.rules),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _export('规则'),
              ),
            ],
          ),
          if (lastExport != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    GlyphIcon(
                      AppGlyphs.checkCircle,
                      size: 16,
                      color: colorScheme.success,
                    ),
                    Expanded(
                      child: Text(
                        '上次导出 ${_formatTime(lastExport)}',
                        style: context.listCaptionStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          generateSection(
            title: '恢复',
            footer: '恢复会覆盖同名项；未勾选的内容保持不变。',
            items: [
              ListItem(
                title: const Text('恢复内容'),
                subtitle: Text(
                  _restoreOptions.isEmpty
                      ? '尚未选择'
                      : '已选 ${_restoreOptions.length} 项：'
                            '${_restoreOptions.map((o) => o.label).join('、')}',
                ),
                leading: const GlyphIcon(AppGlyphs.importFile),
                trailing: const GlyphIcon(AppGlyphs.picker, size: 20),
                onTap: _pickOptions,
              ),
              ListItem(
                title: const Text('开始恢复'),
                subtitle: const Text('从本机备份文件读回所选内容'),
                leading: const GlyphIcon(AppGlyphs.sync),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: _restore,
              ),
            ],
          ),
          WebDavForm(
            onTest: () => ref.read(davProvider.notifier).test(),
            onReset: () => ref.read(davProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}

/// 连接状态徽标（上游 `_DavConnectionIndicator`，第 267 行）。
///
/// 三态各有颜色与字形：只看颜色分不清「连接中」和「未连接」（两者都不显眼），
/// 所以配了不同的字形与文案。
class _DavConnectionIndicator extends StatelessWidget {
  const _DavConnectionIndicator({required this.status, this.message});

  final DavStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, glyph) = switch (status) {
      DavStatus.idle => (colorScheme.onSurfaceVariant, AppGlyphs.cloudSync),
      DavStatus.connecting => (colorScheme.warning, AppGlyphs.sync),
      DavStatus.connected => (colorScheme.success, AppGlyphs.checkCircle),
      DavStatus.failed => (colorScheme.error, AppGlyphs.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          spacing: 10,
          children: [
            if (status == DavStatus.connecting)
              CommonCircleLoading(color: color)
            else
              GlyphIcon(glyph, size: 20, color: color),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    status.label,
                    style: context.listTitleStyle.copyWith(color: color),
                  ),
                  Text(
                    message ?? _hintOf(status),
                    style: context.listCaptionStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hintOf(DavStatus status) => switch (status) {
    DavStatus.idle => '配置服务器信息后可测试连接',
    DavStatus.connecting => '正在握手，请稍候',
    DavStatus.connected => '可以上传或下载备份',
    DavStatus.failed => '检查地址、账号与证书后重试',
  };
}

/// 恢复项多选浮层。
class _RestoreOptionsSheet extends StatefulWidget {
  const _RestoreOptionsSheet({required this.initial});

  final Set<RestoreOption> initial;

  @override
  State<_RestoreOptionsSheet> createState() => _RestoreOptionsSheetState();
}

class _RestoreOptionsSheetState extends State<_RestoreOptionsSheet> {
  late final _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '恢复内容',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '确定',
        onPressed: () => Navigator.of(context).pop(_selected),
      ),
      body: PageBody(
        dockSpacer: false,
        children: [
          generateSection(
            title: '可恢复项',
            items: [
              for (final option in RestoreOption.values)
                ListItem.checkbox(
                  value: _selected.contains(option),
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _selected.add(option);
                    } else {
                      _selected.remove(option);
                    }
                  }),
                ),
            ],
            footer: '未勾选的类别保持现状；恢复前建议先导出当前配置作为回滚点。',
          ),
        ],
      ),
    );
  }
}
