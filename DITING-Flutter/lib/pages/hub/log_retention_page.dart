/// 日志模式（对齐旧版 `ui/LogRetentionSettingsScreen.kt`）。
///
/// 四组：DNS 请求日志（三档）/ 悬浮窗 / 自动清理时间（仅日志非关闭时）/ 崩溃日志。
///
/// 两处上一轮的缺陷在本轮修掉：
/// 1. **崩溃日志条数是写死的 `_crashLogCount = 3`**。旧版读
///    `CrashLogManager.getCrashLogCount(context)`——它枚举 `filesDir/crash/` 的真实
///    文件数。这里改为 `PlatformBridge().crashLogCount()`，并在回到前台时刷新：
///    崩溃收集发生在页面构建之外（应用启动时的原生崩溃收集线程），只在进页面时
///    采样一次会一直过期到下次进来。通道缺失（非 Android 宿主 / 测试）返回 0，
///    页面显示「当前设备没有崩溃日志」并禁用清空，不显示假数字。
/// 2. **日志模式与保留天数没有落盘**：上一轮用 `hub_settings_providers` 里的
///    内存版 `logModeProvider`，退出页面就回到默认值。旧版三档与天数存在数据集
///    容器的 `dns_log_mode` 与 `log_retention_days`，运行中的引擎读同一份键。
///    现在改读 `settings_providers` 的 `logModeProvider` /
///    `logRetentionProvider` / `floatingLogProvider`。
library;

import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 日志模式页。
class LogRetentionPage extends ConsumerStatefulWidget {
  const LogRetentionPage({super.key});

  @override
  ConsumerState<LogRetentionPage> createState() => _LogRetentionPageState();
}

class _LogRetentionPageState extends ConsumerState<LogRetentionPage>
    with WidgetsBindingObserver {
  /// 真实崩溃日志条数；`null` 表示还没读到（首帧不显示任何数字）。
  int? _crashLogCount;

  /// 与旧版一致的可选保留窗口。
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
    // 与旧版 `ON_RESUME` 的监听同义：崩溃收集在页面之外发生，回前台时重读。
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

  /// 副标题按真实条数说话；读不到时明确说「没有」，不编一个数字。
  String _crashSubtitle(int? count) => switch (count) {
    null => '正在读取本机崩溃日志…',
    0 => '当前设备没有崩溃日志',
    _ => '已记录 $count 份崩溃日志，点击导出文件',
  };

  /// 导出崩溃日志：读真实文件 → 拼成一份文本 → 写到应用外部私有目录。
  ///
  /// 上一轮这里只弹一句「导出内容需原生侧提供文件读取」。那是个假入口：按钮
  /// 可点、提示像成功、文件不存在。现在内容与落盘都走真实通道，并在失败时说明
  /// 原因，而不是笼统地说「导出成功」。
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
    // 清空后重读而不是直接置 0：原生侧可能因文件被占用少删几个，
    // 界面上的数字必须是删完之后的真实值。
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
