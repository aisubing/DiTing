/// 崩溃日志: moved out of the log-mode page into 功能中心 → 故障排查. The files, export and clear
/// paths are unchanged; only the entry point moved, so the legacy count/export behavior stays put.
library;

import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class CrashLogPage extends ConsumerStatefulWidget {
  const CrashLogPage({super.key});

  @override
  ConsumerState<CrashLogPage> createState() => _CrashLogPageState();
}

class _CrashLogPageState extends ConsumerState<CrashLogPage>
    with WidgetsBindingObserver {
  /// The real crash log count; `null` while it loads, so the first frame shows no number.
  int? _crashLogCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCrashCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Same intent as the legacy `ON_RESUME` listener: crashes are collected outside the
    // page, so re-read on resume.
    if (state == AppLifecycleState.resumed) {
      _refreshCrashCount();
    }
  }

  Future<void> _refreshCrashCount() async {
    final count = await PlatformBridge().crashLogCount();
    if (!mounted) return;
    setState(() => _crashLogCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final count = _crashLogCount ?? 0;
    final hasCrashes = count > 0;
    return CommonScaffold(
      title: '崩溃日志',
      body: PageBody(
        children: [
          generateSection(
            title: '崩溃日志',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.wrench),
                title: const Text('导出崩溃日志'),
                subtitle: Text(_crashSubtitle(_crashLogCount)),
                onTap: hasCrashes ? _exportCrashes : null,
              ),
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.delete,
                  color: hasCrashes
                      ? context.colorScheme.error
                      : context.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  '清空崩溃日志',
                  style: hasCrashes
                      ? TextStyle(color: context.colorScheme.error)
                      : null,
                ),
                subtitle: const Text('删除本地所有已记录的崩溃文件'),
                onTap: hasCrashes ? _clearCrashes : null,
              ),
            ],
            footer:
                '发生未捕获异常时自动保存诊断信息与关键日志，仅保存在设备本地，'
                '导出后可反馈给开发者。',
          ),
          const ListFooter(
            text: '导出后可在「联系开发者」页面附上该文件，便于定位崩溃原因。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The subtitle reflects the real count; an unreadable count says so instead of inventing one.
  String _crashSubtitle(int? count) => switch (count) {
    null => '正在读取本机崩溃日志…',
    0 => '当前设备没有崩溃日志',
    _ => '已记录 $count 份崩溃日志，点击导出文件',
  };

  /// Reads the real files, joins them and writes the text to the app's external private
  /// directory; failures report a reason instead of a fake success.
  Future<void> _exportCrashes() async {
    final content = await PlatformBridge().readCrashLogs();
    if (!mounted) return;
    if (content.isEmpty) {
      _toast('没有可导出的崩溃日志');
      return;
    }
    final path = await PlatformBridge().exportText(
      name: 'DITING-crash-logs-${_stamp()}.txt',
      content: content,
    );
    if (!mounted) return;
    _toast(path == null ? '导出失败：本机没有可写的导出目录' : '已导出到 $path');
  }

  String _stamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[^0-9]'), '')
      .substring(0, 14);

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearCrashes() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空崩溃日志',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
        child: const Text('确认清空所有已保存的崩溃日志吗？'),
      ),
    );
    if (confirmed != true) return;
    final removed = await PlatformBridge().clearCrashLogs();
    if (!mounted) return;
    // Re-read after clearing instead of zeroing: the native side may fail to delete a file,
    // and the number shown must be the real one afterwards.
    await _refreshCrashCount();
    if (!mounted) return;
    _toast(removed > 0 ? '已清空 $removed 份崩溃日志' : '没有可清空的崩溃日志');
  }
}
