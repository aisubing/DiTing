// ignore_for_file: sort_child_properties_last
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 日志模式（上游 `LogRetentionSettingsScreen`）。
class LogRetentionPage extends ConsumerStatefulWidget {
  const LogRetentionPage({super.key});

  @override
  ConsumerState<LogRetentionPage> createState() => _LogRetentionPageState();
}

class _LogRetentionPageState extends ConsumerState<LogRetentionPage> {
  bool _floatingLog = false;
  int _crashLogCount = 3;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logModeProvider);
    final notifier = ref.read(logModeProvider.notifier);
    return CommonScaffold(
      title: '日志模式',
      body: PageBody(
        children: [
          generateSection(
            title: 'DNS 请求日志',
            items: [
              for (final mode in DnsLogMode.values)
                ListItem(
                  leading: GlyphIcon(
                    state.mode == mode ? AppGlyphs.checkCircle : AppGlyphs.logs,
                    size: 20,
                  ),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  trailing: state.mode == mode ? const SelectionCheck() : null,
                  onTap: () => notifier.setMode(mode),
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
                value: _floatingLog,
                onChanged: (value) => setState(() => _floatingLog = value),
              ),
            ],
            footer: '需要系统悬浮窗权限；回到应用前台时悬浮窗会自动隐藏。',
          ),
          if (state.mode != DnsLogMode.off)
            generateSection(
              title: '自动清理时间',
              items: [
                for (final days in const [1, 7, 30])
                  ListItem(
                    leading: GlyphIcon(
                      state.retentionDays == days
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.clock,
                      size: 20,
                    ),
                    title: Text('保留 $days 天'),
                    trailing: state.retentionDays == days
                        ? const SelectionCheck()
                        : null,
                    onTap: () => notifier.setRetentionDays(days),
                  ),
              ],
              footer: '超过所选时间的 DNS 请求日志会自动删除，用于控制本地日志占用。',
            ),
          generateSection(
            title: '崩溃日志',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.wrench),
                title: const Text('导出崩溃日志'),
                subtitle: Text(
                  _crashLogCount > 0
                      ? '已记录 $_crashLogCount 份崩溃日志，点击导出文件'
                      : '当前无崩溃记录',
                ),
                onTap: _crashLogCount > 0 ? _exportCrashes : null,
              ),
              if (_crashLogCount > 0)
                ListItem(
                  leading: GlyphIcon(
                    AppGlyphs.delete,
                    color: context.colorScheme.error,
                  ),
                  title: Text(
                    '清空崩溃日志',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                  subtitle: const Text('删除本地所有已记录的崩溃文件'),
                  onTap: _clearCrashes,
                ),
            ],
            footer: '发生未捕获异常时自动保存诊断信息与关键日志，仅保存在设备本地，'
                '导出后可反馈给开发者。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _exportCrashes() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('崩溃日志已导出到下载目录'),
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
        child: const Text('确认清空所有已保存的崩溃日志吗？'),
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
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _crashLogCount = 0);
    }
  }
}
