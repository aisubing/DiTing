/// WebDAV 云同步（自 `backup_page.dart` 的 `WebDavForm` 迁入功能中心）。
///
/// 1.4.3 没有独立的「备份」主页：WebDAV 只是备份页里的一张表单。这里把它搬成
/// 「功能中心 → 备份与迁移 → WebDAV 云同步」下面的一页。
///
/// ## 本轮真实化
///
/// 上一轮 `DavNotifier.test()` 只转 1.2 秒并按地址里有没有 `fail` 决定成败——
/// 服务器压根不存在也会显示「连接成功」，用户据此以为云备份可用。现在：
///
/// - **测试连接** 走真实 `PROPFIND`（目录不存在则 `MKCOL`）；
/// - **上传备份** 走真实 `PUT`，内容是「备份与迁移」同一份生成器的 JSON；
/// - **下载恢复** 走真实 `GET`，并把内容交给同一个 `BackupImporter` 合并。
///
/// 密码只存在内存里，不落盘（与备份文件「不含凭据」的承诺一致）。
library;

import 'package:diting/data/backup/backup_importer.dart';
import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/state/backup_providers.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// WebDAV 云同步页。
class ConfigTransferWebdavPage extends ConsumerStatefulWidget {
  const ConfigTransferWebdavPage({super.key});

  @override
  ConsumerState<ConfigTransferWebdavPage> createState() =>
      _ConfigTransferWebdavPageState();
}

class _ConfigTransferWebdavPageState
    extends ConsumerState<ConfigTransferWebdavPage> {
  /// 上传/下载进行中；两钮一起禁用，避免并发改同一份云端文件。
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final dav = ref.watch(davProvider);
    final field = ref.read(davProvider.notifier);
    final canTransfer = dav.status == DavStatus.connected && !_busy;
    return CommonScaffold(
      title: 'WebDAV 云同步',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.reset,
          tooltip: '清空配置',
          onPressed: dav.status == DavStatus.connecting
              ? null
              : () => ref.read(davProvider.notifier).reset(),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DavStatusCard(status: dav.status, message: dav.message),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: FormPage(
                title: '',
                padding: EdgeInsets.zero,
                onSave: dav.isConfigured
                    ? () => ref.read(davProvider.notifier).test()
                    : null,
                saving: dav.status == DavStatus.connecting,
                saveLabel: '测试连接',
                children: [
                  FormRowTextField(
                    title: '服务器',
                    value: dav.server,
                    hintText: 'https://dav.example.com',
                    keyboardType: TextInputType.url,
                    invalid:
                        dav.status == DavStatus.failed && dav.server.isEmpty,
                    onChanged: (value) => field.update(
                      (state) =>
                          state.copyWith(server: value, status: DavStatus.idle),
                    ),
                  ),
                  FormRowTextField(
                    title: '用户名',
                    value: dav.username,
                    invalid:
                        dav.status == DavStatus.failed && dav.username.isEmpty,
                    onChanged: (value) => field.update(
                      (state) => state.copyWith(
                        username: value,
                        status: DavStatus.idle,
                      ),
                    ),
                  ),
                  FormRowSecretTextField(
                    title: '密码',
                    controller: _passwordController(),
                    onChanged: (value) => field.update(
                      (state) => state.copyWith(password: value),
                    ),
                  ),
                  FormRowTextField(
                    title: '远端路径',
                    value: dav.path,
                    hintText: '/diting/',
                    monospace: true,
                    onChanged: (value) =>
                        field.update((state) => state.copyWith(path: value)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TonalButton(
                    label: '测试连接',
                    glyph: AppGlyphs.sync,
                    size: TonalButtonSize.section,
                    onPressed: _busy
                        ? null
                        : () => ref.read(davProvider.notifier).test(),
                  ),
                ),
                Expanded(
                  child: TonalButton(
                    label: '清空',
                    glyph: AppGlyphs.broom,
                    size: TonalButtonSize.section,
                    onPressed: _busy
                        ? null
                        : () => ref.read(davProvider.notifier).reset(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TonalButton(
                    label: '上传备份',
                    glyph: AppGlyphs.export,
                    size: TonalButtonSize.section,
                    onPressed: canTransfer ? _upload : null,
                  ),
                ),
                Expanded(
                  child: TonalButton(
                    label: '下载恢复',
                    glyph: AppGlyphs.importFile,
                    size: TonalButtonSize.section,
                    onPressed: canTransfer ? _download : null,
                  ),
                ),
              ],
            ),
          ),
          ListFooter(
            text:
                '「测试连接」会真实发起 WebDAV 请求：PROPFIND 探测目录，不存在则'
                '尝试创建。上传与下载走与「备份与迁移」同一份备份格式。'
                '${canTransfer ? '' : '连接成功后即可上传或恢复。'}'
                '密码只存在内存里，不落盘。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 密码控制器挂在 provider 之外：`TextEditingController` 是可变对象，
  /// 每次 build 新建会把光标重置。这里用一个按 provider 生命周期缓存的包装。
  TextEditingController _passwordController() {
    final cached = ref.watch(_passwordControllerProvider);
    final password = ref.read(davProvider).password;
    if (cached.text != password) {
      cached.value = TextEditingValue(
        text: password,
        selection: TextSelection.collapsed(offset: password.length),
      );
    }
    return cached;
  }

  /// 上传：用与「备份与迁移」同一份生成器产出 JSON，再 `PUT` 到云端。
  ///
  /// 复用同一份生成器而不是另写一套，是为了让「导出到文件」与「上传到云端」
  /// 产出完全等价的备份——两份格式若有出入，用户会在换设备时才发现。
  Future<void> _upload() async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(backupActionsProvider);
      final export = await actions.export(BackupGroup.values.toSet());
      if (!mounted) return;
      if (export.isEmpty) {
        _toast('本机没有可备份的配置');
        return;
      }
      final result = await ref.read(davProvider.notifier).upload(export.content);
      if (!mounted) return;
      _toast(
        result.succeeded
            ? '已上传 ${export.included.length} 组、共 ${export.totalItems} 项'
            : (result.error ?? '上传失败'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 下载：取回云端 JSON 交给同一个合并器，并弹出逐组明细。
  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final text = await ref.read(davProvider.notifier).download();
      if (!mounted) return;
      if (text == null) {
        _toast(ref.read(davProvider).message ?? '云端没有可恢复的备份');
        return;
      }
      final result = await ref
          .read(backupActionsProvider)
          .importText(text, sourceName: DavNotifier.remoteFileName);
      if (!mounted) return;
      await showFloatingDialog<void>(
        context: context,
        child: _DavImportDialog(result: result),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 云端恢复的结果明细（与本地导入共用同一份 `BackupImportResult`）。
class _DavImportDialog extends StatelessWidget {
  const _DavImportDialog({required this.result});

  final BackupImportResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonDialog(
      title: '从云端恢复配置',
      trailing: MetaChip(label: result.failed ? '恢复失败' : '恢复完成'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (result.failed)
            Text(result.fatalError!, style: TextStyle(color: colorScheme.error))
          else ...[
            Text(
              '恢复汇总：新增 ${result.added} 项，更新 ${result.updated} 项，'
              '跳过 ${result.skipped} 项',
              style: context.listTitleStyle,
            ),
            for (final outcome in result.changed)
              Text(
                '  + ${outcome.group.title} · '
                '新增 ${outcome.added}，跳过 ${outcome.skipped}',
              ),
            for (final outcome in result.failedGroups)
              Text(
                '  ! ${outcome.group.title}：${outcome.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            if (result.changed.isEmpty && result.failedGroups.isEmpty)
              const Text('  （云端备份与本机一致，没有需要变更的内容）'),
          ],
        ],
      ),
    );
  }
}

/// 供 [ConfigTransferWebdavPage] 复用的密码控制器；页面销毁时由 Riverpod 释放。
final _passwordControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// 连接状态徽标（上游 `_DavConnectionIndicator`）。
///
/// 三态各有颜色与字形：只看颜色分不清「连接中」和「未连接」（两者都不显眼），
/// 所以配了不同的字形与文案。
class _DavStatusCard extends StatelessWidget {
  const _DavStatusCard({required this.status, this.message});

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
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      isError: status == DavStatus.failed,
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
    );
  }

  static String _hintOf(DavStatus status) => switch (status) {
    DavStatus.idle => '配置服务器信息后可测试连接',
    DavStatus.connecting => '正在握手，请稍候',
    DavStatus.connected => '可上传备份或从云端恢复配置',
    DavStatus.failed => '检查地址、账号与证书后重试',
  };
}
