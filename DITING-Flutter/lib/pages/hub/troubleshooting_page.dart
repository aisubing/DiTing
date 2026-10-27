/// 故障排查: one page for everything a user would send a developer — the crash reports written
/// automatically, plus the manual runtime-logcat capture. Both are troubleshooting material, so
/// they share a surface instead of two nearly identical cards in 数据与维护.
library;

import 'dart:async';

import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/native/runtime_log_bridge.dart';
import 'package:diting/state/runtime_log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class TroubleshootingPage extends ConsumerStatefulWidget {
  const TroubleshootingPage({super.key});

  @override
  ConsumerState<TroubleshootingPage> createState() =>
      _TroubleshootingPageState();
}

class _TroubleshootingPageState extends ConsumerState<TroubleshootingPage>
    with WidgetsBindingObserver {
  /// The real crash log count; `null` while it loads, so the first frame shows no number.
  int? _crashLogCount;

  /// Blocks a second tap while the start/stop round trip runs, so two services cannot race.
  bool _busy = false;

  /// Ticks while capture is on so the file count and size stay live; the state provider is not
  /// auto-disposed, so nothing else would re-read the disk.
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCrashCount();
    // The provider outlives the page, so a reopen would otherwise show the size from last time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRuntimeStatus();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Both sources change outside the page — crashes are collected by the app, and the capture
    // keeps running behind the notification — so re-read on resume.
    if (state == AppLifecycleState.resumed) {
      _refreshCrashCount();
      _refreshRuntimeStatus(force: true);
    }
  }

  Future<void> _refreshCrashCount() async {
    final count = await PlatformBridge().crashLogCount();
    if (!mounted) return;
    setState(() => _crashLogCount = count);
  }

  /// Re-reads the native capture status and keeps the live size ticking only while it is on.
  Future<void> _refreshRuntimeStatus({bool force = false}) async {
    if (_busy && !force) return;
    final status = await ref.read(runtimeLogStatusProvider.notifier).refresh();
    if (!mounted) return;
    _syncPolling(status.capturing);
  }

  void _syncPolling(bool capturing) {
    if (!capturing) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(
      const Duration(seconds: 2),
      // Through [_refreshRuntimeStatus] so a capture stopped from the notification also stops it.
      (_) => _refreshRuntimeStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crashCount = _crashLogCount;
    final hasCrashes = (crashCount ?? 0) > 0;
    final status = ref.watch(runtimeLogStatusProvider).value;
    final capturing = status?.capturing ?? false;
    final hasRuntimeLogs = status?.hasLogs ?? false;
    final error = context.colorScheme.error;
    final muted = context.colorScheme.onSurfaceVariant;
    return CommonScaffold(
      title: '故障排查',
      body: PageBody(
        children: [
          generateSection(
            title: '运行日志',
            items: [
              ListItem.toggle(
                leading: GlyphIcon(
                  capturing ? AppGlyphs.checkCircle : AppGlyphs.logs,
                  size: 20,
                ),
                title: const Text('记录运行日志'),
                subtitle: Text(_switchSubtitle(status)),
                value: capturing,
                onChanged: _busy ? null : (value) => _onToggle(value),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.export),
                title: const Text('导出运行日志'),
                subtitle: Text(_exportSubtitle(status)),
                onTap: hasRuntimeLogs ? _exportRuntimeLogs : null,
              ),
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.delete,
                  color: hasRuntimeLogs ? error : muted,
                ),
                title: Text(
                  '清空运行日志',
                  style: hasRuntimeLogs ? TextStyle(color: error) : null,
                ),
                subtitle: const Text('删除本地已记录的全部运行日志文件'),
                onTap: hasRuntimeLogs ? _clearRuntimeLogs : null,
              ),
            ],
            footer:
                '默认关闭。开启后会在通知栏显示状态，关闭软件或手动关闭后即停止记录；'
                '日志只保存在本机，不会自动上传。',
          ),
          generateSection(
            title: '崩溃日志',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.wrench),
                title: const Text('导出崩溃日志'),
                subtitle: Text(_crashSubtitle(crashCount)),
                onTap: hasCrashes ? _exportCrashes : null,
              ),
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.delete,
                  color: hasCrashes ? error : muted,
                ),
                title: Text(
                  '清空崩溃日志',
                  style: hasCrashes ? TextStyle(color: error) : null,
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
            text:
                '抓取运行日志会持续读写少量文件，可能导致功耗升高、存储占用增加或产生'
                '其他未知影响，不需要时请及时关闭。导出的文件可发送给开发者，'
                '配合问题现象与发生时间能更快定位原因。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _switchSubtitle(RuntimeLogStatus? status) {
    if (status == null) return '正在读取抓取状态…';
    if (status.capturing) {
      return '正在记录，已占用 ${status.sizeLabel}，再次点击可关闭';
    }
    return status.hasLogs
        ? '已关闭，本地已有 ${status.sizeLabel} 日志可导出'
        : '已关闭，开启后才会记录运行日志';
  }

  String _exportSubtitle(RuntimeLogStatus? status) {
    if (status == null) return '正在读取本地日志…';
    if (!status.hasLogs) return '当前设备没有运行日志';
    return '共 ${status.fileCount} 个文件，${status.sizeLabel}，点击导出文件';
  }

  /// The subtitle reflects the real count; an unreadable count says so instead of inventing one.
  String _crashSubtitle(int? count) => switch (count) {
    null => '正在读取本机崩溃日志…',
    0 => '当前设备没有崩溃日志',
    _ => '已记录 $count 份崩溃日志，点击导出文件',
  };

  /// Turning on is the risky direction, so it asks first; turning off just stops.
  Future<void> _onToggle(bool value) async {
    if (!value) {
      setState(() => _busy = true);
      await ref.read(runtimeLogStatusProvider.notifier).stop();
      if (!mounted) return;
      setState(() => _busy = false);
      _syncPolling(false);
      _toast('已停止记录运行日志');
      return;
    }
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '开启运行日志抓取',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定开启'),
          ),
        ],
        child: const Text(
          '该功能主要用于协助开发者排查问题，开启后会开始记录软件的运行日志，'
          '并持续写入本机存储。\n\n'
          '抓取期间可能导致功耗升高、存储占用增加，或产生其他未知影响。'
          '如非排查问题所需，建议用完即关。\n\n'
          '日志只保存在本机，关闭后停止记录；导出后你可以自行发送给开发者。',
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final started = await ref.read(runtimeLogStatusProvider.notifier).start();
    if (!mounted) return;
    setState(() => _busy = false);
    _syncPolling(started);
    _toast(started ? '已开始记录运行日志' : '无法开启日志抓取，请稍后重试');
  }

  Future<void> _exportRuntimeLogs() async {
    final content = await ref.read(runtimeLogBridgeProvider).read();
    if (!mounted) return;
    if (content.isEmpty) {
      _toast('没有可导出的运行日志');
      return;
    }
    final path = await PlatformBridge().exportText(
      name: 'DITING-runtime-logs-${_stamp()}.txt',
      content: content,
    );
    if (!mounted) return;
    _toast(path == null ? '导出失败：本机没有可写的导出目录' : '已导出到 $path');
  }

  Future<void> _clearRuntimeLogs() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空运行日志',
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
        child: const Text('确认清空所有已保存的运行日志吗？该操作不可恢复。'),
      ),
    );
    if (confirmed != true) return;
    final removed = await ref.read(runtimeLogBridgeProvider).clear();
    if (!mounted) return;
    await ref.read(runtimeLogStatusProvider.notifier).refresh();
    if (!mounted) return;
    _toast(removed > 0 ? '已清空 $removed 个日志文件' : '没有可清空的运行日志');
  }

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
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
