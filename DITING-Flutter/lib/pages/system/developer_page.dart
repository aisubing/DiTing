/// Developer options hub, which has no 1.4.3 counterpart. Every action here talks to the real
/// database, native channels or the cleanup service; nothing is simulated.
library;

import 'dart:io';
import 'dart:math';

import 'package:diting/data/cleanup/data_cleanup_service.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/observability_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/cleanup_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Rows in the stress action; one batch, so the UI never freezes mid-way.
const _stressRowCount = 1000;

/// The four actions that do real work. `title` doubles as the running indicator.
enum _DeveloperAction {
  stressLogs(
    title: '日志压测',
    subtitle: '向当前模式的日志库真实写入 $_stressRowCount 条 DNS 日志',
    glyphName: 'logs',
  ),
  reportError(
    title: '错误上报自检',
    subtitle: '通过 FlutterError 上报一条测试异常，验证错误链路',
    glyphName: 'error',
  ),
  clearAllData(
    title: '清空全部数据',
    subtitle: '删除配置、规则与日志，恢复出厂状态',
    glyphName: 'clearAll',
    destructive: true,
  ),
  vacuum(
    title: '压缩数据库',
    subtitle: '对三个本地库执行 VACUUM，回收已删除记录占用的空间',
    glyphName: 'memory',
  );

  const _DeveloperAction({
    required this.title,
    required this.subtitle,
    required this.glyphName,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final String glyphName;
  final bool destructive;
}

class DeveloperPage extends ConsumerStatefulWidget {
  const DeveloperPage({super.key});

  @override
  ConsumerState<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends ConsumerState<DeveloperPage> {
  /// Non-null while an action runs; disables the whole list instead of only one row.
  _DeveloperAction? _running;

  Future<void> _handle(_DeveloperAction action) async {
    if (_running != null) return;
    if (action.destructive) {
      final confirmed = await showFloatingDialog<bool>(
        context: context,
        child: CommonDialog(
          title: action.title,
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('执行'),
            ),
          ],
          child: Text('${action.subtitle}\n\n该操作会真正改写本机数据，无法撤销。'),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _running = action);
    String message;
    try {
      message = switch (action) {
        _DeveloperAction.stressLogs => await _stressLogs(),
        _DeveloperAction.reportError => _reportError(),
        _DeveloperAction.clearAllData => await _clearAllData(),
        _DeveloperAction.vacuum => await _vacuum(),
      };
    } catch (error) {
      message = '${action.title}失败：$error';
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (!mounted) return;
    _toast(message);
    // "Clear all data" also wipes the first-run agreement, so the app must restart; staying alive
    // would leave "running" split from "must agree again" (same rule as the cleanup page).
    if (action == _DeveloperAction.clearAllData && mounted) {
      await _offerRestart();
    }
  }

  /// Writes real rows into the active `dns_log`; the revision bump makes the log pages re-query.
  Future<String> _stressLogs() async {
    final fileName = ref.read(activeLogDatabaseFileProvider);
    final db = await LegacyDatabase.open(fileName);
    if (db == null) return '日志压测失败：无法打开日志数据库';
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final batch = db.batch();
    for (var index = 0; index < _stressRowCount; index++) {
      batch.insert('dns_log', {
        'timestamp': now - index * 1000,
        'queryName': 'stress-${index.toString().padLeft(4, '0')}.example.com',
        'queryType': 1,
        'result': index.isEven ? 'PASSED' : 'BLOCKED',
        'message': 'developer stress test',
        'cached': random.nextBool() ? 1 : 0,
        'packageName': 'com.haoze.diting',
      });
    }
    final inserted = (await batch.commit(noResult: true)).length;
    ref.read(dnsLogRevisionProvider.notifier).bump();
    return '日志压测完成：写入 $inserted 条到 $fileName';
  }

  /// Goes through the same handler the framework uses, so it exercises a real error path without
  /// tearing the app down.
  String _reportError() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('开发者选项触发的测试异常'),
        library: 'diting.developer',
        context: ErrorDescription('错误上报自检'),
      ),
    );
    return '已上报一条 FlutterError：开发者选项触发的测试异常';
  }

  Future<String> _clearAllData() async {
    final result = await ref
        .read(cleanupRunnerProvider)
        .run(CleanupAction.allData);
    return result.message;
  }

  /// `VACUUM` on every existing database file; the difference in file size is the real gain.
  Future<String> _vacuum() async {
    var freed = 0;
    final touched = <String>[];
    for (final fileName in const [
      LegacyDatabase.mainFile,
      LegacyDatabase.expressFile,
      LegacyDatabase.serverFile,
    ]) {
      final db = await LegacyDatabase.open(fileName, create: false);
      if (db == null) continue;
      try {
        final file = File(db.path);
        final before = await file.length();
        await db.execute('VACUUM');
        freed += before - await file.length();
        touched.add(fileName);
      } finally {
        await db.close();
      }
    }
    if (touched.isEmpty) return '压缩数据库失败：本机还没有数据库文件';
    final kb = (freed / 1024).round();
    return '已压缩 ${touched.join('、')}，回收 ${kb < 0 ? 0 : kb} KB';
  }

  Future<void> _offerRestart() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '需要重启',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('立即退出'),
          ),
        ],
        child: const Text('全部数据已清空，需要重新启动应用才能从出厂状态进入。'),
      ),
    );
    if (confirmed == true) await SystemNavigator.pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(developerModeProvider);
    return CommonScaffold(
      title: '开发者选项',
      // Avoids `PageBody` (a lazy ListView): this is a directory, and never-built entries stay
      // invisible to the a11y tree and screenshot review. Building them all is cheap.
      body: AppBarClearance(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DeveloperModeCard(),
              generateSection(
                title: '诊断与观测',
                items: [
                  _Entry(
                    glyph: AppGlyphs.target,
                    title: 'IP 质量',
                    subtitle: '实测出口地址与三个公开情报源的类型判断',
                    route: SystemPaths.ipQuality,
                  ),
                  _Entry(
                    glyph: AppGlyphs.requests,
                    title: '请求日志',
                    subtitle: '合并 http_request_log 与 dns_log 的实时请求记录',
                    route: ObservabilityPaths.requests,
                  ),
                  _Entry(
                    glyph: AppGlyphs.logs,
                    title: '日志保留',
                    subtitle: '日志容量上限、崩溃日志的查看与导出',
                    route: HubPaths.logRetention,
                  ),
                  _Entry(
                    glyph: AppGlyphs.broom,
                    title: '数据清理',
                    subtitle: '按类别删除日志、权重、规则与缓存',
                    route: HubPaths.dataCleanup,
                  ),
                ],
              ),
              generateSection(
                title: '配置与资源',
                items: [
                  _Entry(
                    glyph: AppGlyphs.resources,
                    title: '自定义资源',
                    subtitle: 'User-Agent、按需连接等配置资源入口',
                    route: ConfigPaths.customResources,
                  ),
                  _Entry(
                    glyph: AppGlyphs.account,
                    title: 'User-Agent',
                    subtitle: '订阅下载与测速请求携带的 UA',
                    route: ConfigPaths.userAgents,
                  ),
                  _Entry(
                    glyph: AppGlyphs.wifi,
                    title: '按需连接',
                    subtitle: '按 SSID 决定是否启动 VPN',
                    route: ConfigPaths.onDemand,
                  ),
                  _Entry(
                    glyph: AppGlyphs.cloudSync,
                    title: 'WebDAV 云同步',
                    subtitle: '把备份真实上传到自建的 WebDAV 服务',
                    route: HubPaths.configTransferWebdav,
                  ),
                ],
              ),
              generateSection(
                title: '界面与外观保留项',
                items: [
                  _Entry(
                    glyph: AppGlyphs.font,
                    title: '字体',
                    subtitle: '选择界面字体族，独立页',
                    route: SystemPaths.fontFamily,
                  ),
                  _Entry(
                    glyph: AppGlyphs.textSize,
                    title: '字号',
                    subtitle: '全局文字缩放；在外观设置「界面显示」组内联滑杆',
                    route: SystemPaths.theme,
                  ),
                  _Entry(
                    glyph: AppGlyphs.motion,
                    title: 'Tab 动画',
                    subtitle: '切换底部标签时的入场动画；在外观设置「背景与动效」组内联选项',
                    route: SystemPaths.theme,
                  ),
                ],
              ),
              generateSection(
                title: '设计与演示',
                items: [
                  _Entry(
                    glyph: AppGlyphs.palette,
                    title: '组件画廊',
                    subtitle: '设计系统全部组件与字形目录',
                    route: SystemPaths.demo,
                  ),
                ],
              ),
              generateSection(
                title: '实验动作',
                items: [
                  for (final action in _DeveloperAction.values)
                    _ActionRow(
                      action: action,
                      enabled: enabled && _running == null,
                      running: _running == action,
                      onTap: enabled && _running == null
                          ? () => _handle(action)
                          : null,
                    ),
                ],
                footer:
                    '这些动作直接作用于本机的数据库、prefs 与 native 通道：'
                    '日志压测会真的写入 $_stressRowCount 条日志，压缩数据库执行的是 SQLite VACUUM，'
                    '清空全部数据会删除所有本地数据并要求重启。',
              ),
              const ListFooter(
                text:
                    '以上「诊断与观测」「配置与资源」「界面与外观保留项」「设计与演示」'
                    '里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；'
                    '旧版对应的功能仍按旧版菜单进入，不经过本页。',
              ),
              const DockSpacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// When off the actions are disabled, not hidden, so the user sees where to enable them.
class _DeveloperModeCard extends ConsumerWidget {
  const _DeveloperModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(developerModeProvider);
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  AppGlyphs.wrench,
                  size: 22,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开发者模式', style: context.listTitleStyle),
                      Text(
                        enabled ? '实验动作已解锁' : '关闭时下面的动作不可用',
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (value) =>
                      ref.read(developerModeProvider.notifier).toggle(value),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: ShapeDecoration(
                shape: AppShape.md,
                color: colorScheme.warningContainer,
              ),
              child: Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlyphIcon(
                    AppGlyphs.warning,
                    size: 16,
                    color: colorScheme.onWarningContainer,
                  ),
                  Expanded(
                    child: Text(
                      '这里的动作会真的改写本机数据（日志库、prefs、数据库文件），'
                      '其中「清空全部数据」不可撤销，不要在生产环境打开。',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onWarningContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: GlyphIcon(glyph, size: 20),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: () => context.push(route),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.enabled,
    required this.running,
    required this.onTap,
  });

  final _DeveloperAction action;
  final bool enabled;
  final bool running;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final glyphColor = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : action.destructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    return ListItem(
      title: Text(
        action.title,
        style: action.destructive && enabled
            ? TextStyle(color: colorScheme.error)
            : null,
      ),
      subtitle: Text(running ? '执行中…' : action.subtitle),
      leading: running
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : GlyphIcon(glyphByName(action.glyphName), color: glyphColor),
      trailing: running
          ? null
          : const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: onTap,
    );
  }
}
