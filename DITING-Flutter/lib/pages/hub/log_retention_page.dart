/// Log mode (legacy `ui/LogRetentionSettingsScreen.kt`): `dns_log_mode`, `log_retention_days`.
library;

import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LogRetentionPage extends ConsumerStatefulWidget {
  const LogRetentionPage({super.key});

  @override
  ConsumerState<LogRetentionPage> createState() => _LogRetentionPageState();
}

class _LogRetentionPageState extends ConsumerState<LogRetentionPage>
    with WidgetsBindingObserver {
  /// The real crash log count; `null` while it loads, so the first frame shows no number.
  int? _crashLogCount;

  static const _retentionOptions = [1, 7, 30];

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
    final mode = ref.watch(logModeProvider);
    final retentionDays = ref.watch(logRetentionProvider);
    final floatingLog = ref.watch(floatingLogProvider);
    final count = _crashLogCount ?? 0;
    final hasCrashes = count > 0;
    return CommonScaffold(
      title: '日志模式',
      body: PageBody(
        children: [
          generateSection(
            title: 'DNS 请求日志',
            items: [
              for (final option in LegacyLogMode.values)
                ListItem(
                  leading: GlyphIcon(
                    mode == option ? AppGlyphs.checkCircle : AppGlyphs.logs,
                    size: 20,
                  ),
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  trailing: mode == option ? const SelectionCheck() : null,
                  onTap: () =>
                      ref.read(logModeProvider.notifier).select(option),
                ),
            ],
            footer: '关闭后不会删除已有日志，重新开启即可继续查看。',
          ),
          generateSection(
            title: '悬浮窗',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.eye),
                title: const Text('悬浮窗日志'),
                subtitle: const Text('VPN 运行且应用在后台时显示悬浮球，点击查看最近请求'),
                value: floatingLog,
                onChanged: (value) =>
                    ref.read(floatingLogProvider.notifier).toggle(value),
              ),
            ],
            footer: '需要系统悬浮窗权限；回到应用前台时悬浮窗会自动隐藏。',
          ),
          if (mode != LegacyLogMode.off)
            generateSection(
              title: '自动清理时间',
              items: [
                for (final days in _retentionOptions)
                  ListItem(
                    leading: GlyphIcon(
                      retentionDays == days
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text('保留 $days 天'),
                    trailing: retentionDays == days
                        ? const SelectionCheck()
                        : null,
                    onTap: () =>
                        ref.read(logRetentionProvider.notifier).set(days),
                  ),
              ],
              footer:
                  '超过所选时间的请求日志由隧道服务每小时清理一次'
                  '（首次在启动 30 秒后）。关闭日志不会删除已有记录。',
            ),
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
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final path = await PlatformBridge().exportText(
      name: 'DITING-crash-logs-$stamp.txt',
      content: content,
    );
    if (!mounted) return;
    _toast(
      path == null ? '导出失败：本机没有可写的导出目录' : '已导出到 $path',
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(removed > 0 ? '已清空 $removed 份崩溃日志' : '没有可清空的崩溃日志'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}