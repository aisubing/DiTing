/// 运行日志: manual, user-started runtime logcat capture. The switch is the only entry point, and
/// turning it on always goes through the risk confirmation first — the capture costs power and its
/// effect on the device is not fully known, so the user decides, not a default.
library;

import 'dart:async';

import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/native/runtime_log_bridge.dart';
import 'package:diting/state/runtime_log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class RuntimeLogPage extends ConsumerStatefulWidget {
  const RuntimeLogPage({super.key});

  @override
  ConsumerState<RuntimeLogPage> createState() => _RuntimeLogPageState();
}

class _RuntimeLogPageState extends ConsumerState<RuntimeLogPage>
    with WidgetsBindingObserver {
  /// Blocks a second tap while the start/stop round trip runs, so two services cannot race.
  bool _busy = false;

  /// Ticks while capture is on so the file count and size stay live; the state provider is not
  /// auto-disposed, so nothing else would re-read the disk.
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The provider outlives the page, so a reopen would otherwise show the size from last time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(runtimeLogStatusProvider.notifier).refresh();
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
    // The capture keeps running (and the notification shows it) outside the page: re-read on
    // resume so the switch cannot disagree with the service.
    if (state == AppLifecycleState.resumed) {
      _refresh(force: true);
    }
  }

  /// Re-reads the native status and keeps the live size ticking only while capture is on.
  Future<void> _refresh({bool force = false}) async {
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
      // Through [_refresh] so a capture stopped from the notification also stops the timer.
      (_) => _refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(runtimeLogStatusProvider).value;
    final capturing = status?.capturing ?? false;
    final hasLogs = status?.hasLogs ?? false;
    return CommonScaffold(
      title: '运行日志',
      body: PageBody(
        children: [
          generateSection(
            title: '日志抓取',
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
            ],
            footer:
                '默认关闭。开启后会在通知栏显示状态，关闭软件或手动关闭后即停止记录；'
                '日志只保存在本机，不会自动上传。',
          ),
          generateSection(
            title: '导出与清理',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.export),
                title: const Text('导出运行日志'),
                subtitle: Text(_exportSubtitle(status)),
                onTap: hasLogs ? _exportLogs : null,
              ),
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.delete,
                  color: hasLogs
                      ? context.colorScheme.error
                      : context.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  '清空运行日志',
                  style: hasLogs
                      ? TextStyle(color: context.colorScheme.error)
                      : null,
                ),
                subtitle: const Text('删除本地已记录的全部运行日志文件'),
                onTap: hasLogs ? _clearLogs : null,
              ),
            ],
            footer:
                '导出后请把文件发给开发者，配合问题现象与发生时间，能更快定位原因。',
          ),
          const ListFooter(
            text:
                '运行日志用于协助开发者排查问题：抓取期间会持续读写少量日志，'
                '可能导致功耗升高、存储占用增加或产生其他未知影响。不需要时请及时关闭。',
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

  Future<void> _exportLogs() async {
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

  Future<void> _clearLogs() async {
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
}
