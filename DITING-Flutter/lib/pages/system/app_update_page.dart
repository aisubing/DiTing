/// Update and support page (upstream `ui/AppUpdateScreen.kt`).
library;

import 'package:diting/pages/system/app_info.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);
    final disableStartupCheck = ref.watch(startupUpdateCheckProvider);
    final hasNewVersion =
        update.stage == UpdateStage.available ||
        update.stage == UpdateStage.downloading ||
        update.stage == UpdateStage.downloaded;
    return CommonScaffold(
      title: '更新与支持',
      menuItems: [
        CommonPopupMenuItem(
          label: '重置更新状态',
          glyph: AppGlyphs.reset,
          onPressed: notifier.reset,
        ),
      ],
      body: PageBody(
        children: [
          const SizedBox(height: 4),
          _UpdateCard(
            currentVersion: ref.watch(appVersionProvider).name,
            update: update,
            hasNewVersion: hasNewVersion,
            onCheck: update.stage.isBusy ? null : notifier.check,
            onDownload: update.stage.isBusy ? null : notifier.download,
            onInstall: () => _install(context, ref),
          ),
          generateSection(
            title: '设置与支持',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.clock),
                title: const Text('关闭启动时检查更新'),
                subtitle: Text(
                  disableStartupCheck ? '应用启动时不自动检查，可随时手动检查' : '应用启动时自动检查新版本',
                ),
                value: disableStartupCheck,
                onChanged: (value) =>
                    ref.read(startupUpdateCheckProvider.notifier).toggle(value),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.account),
                title: const Text('加入 QQ 群'),
                subtitle: const Text('交流群：$qqGroupNumber'),
                onTap: () => copyToClipboard(
                  context,
                  qqGroupNumber,
                  '群号已复制：$qqGroupNumber',
                ),
              ),
            ],
            footer: '更新不会影响你的配置与规则；导入旧配置可在「备份与迁移」里完成。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Install through the system installer; failures are reported, usually a missing
  /// install permission.
  Future<void> _install(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await ref.read(updateProvider.notifier).install();
    if (!context.mounted) return;
    if (!ok) {
      final reason = ref.read(updateProvider).error ?? '无法调起系统安装器';
      messenger?.showSnackBar(
        SnackBar(
          content: Text(reason),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2200),
        ),
      );
    }
  }
}

/// Update status text. The version comes from the real check result; an unread version is
/// reported as unchecked.
String statusText(UpdateState state) {
  final latest = state.info?.version;
  final current = state.currentVersion;
  return switch (state.stage) {
    UpdateStage.checking => '正在检查 GitHub Release',
    UpdateStage.available => [
      '发现 ${latest ?? '新'}版本',
      if (current != null) '（当前 $current）',
    ].join(),
    UpdateStage.downloading =>
      '正在下载 ${latest ?? '安装包'}，${(state.progress * 100).round()}%',
    UpdateStage.downloaded => '${latest ?? '安装包'} 已下载，可安装',
    UpdateStage.upToDate => [
      '当前已是最新版本',
      if (current != null) '（$current）',
    ].join(),
    UpdateStage.idle => state.error ?? '检查 GitHub Release 中的最新版本',
  };
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.currentVersion,
    required this.update,
    required this.hasNewVersion,
    required this.onCheck,
    required this.onDownload,
    required this.onInstall,
  });

  /// Display version, read from `pubspec.yaml`.
  final String currentVersion;

  final UpdateState update;
  final bool hasNewVersion;
  final VoidCallback? onCheck;
  final VoidCallback? onDownload;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: colorScheme.primaryContainer,
                    shape: AppShape.lg,
                  ),
                  child: GlyphIcon(
                    AppGlyphs.cloudDownload,
                    size: 28,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        hasNewVersion
                            ? '可更新到 ${update.info?.version ?? '新版本'}'
                            : '谛听',
                        style: AppTextStyle.title3.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      Text(
                        '当前版本 $currentVersion',
                        style: context.listSubtitleStyle.copyWith(
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
                _StageBadge(stage: update.stage),
              ],
            ),
            if (update.stage == UpdateStage.downloading ||
                update.stage == UpdateStage.downloaded)
              _DownloadProgress(state: update),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TonalButton(
                    label: switch (update.stage) {
                      UpdateStage.checking => '检查中…',
                      UpdateStage.available => '重新检查',
                      _ => '检查更新',
                    },
                    glyph: AppGlyphs.refresh,
                    size: TonalButtonSize.section,
                    onPressed: onCheck,
                  ),
                ),
                if (update.stage == UpdateStage.available ||
                    update.stage == UpdateStage.downloading)
                  Expanded(
                    child: TonalButton(
                      label: update.stage == UpdateStage.downloading
                          ? '下载中…'
                          : '下载',
                      glyph: AppGlyphs.cloudDownload,
                      size: TonalButtonSize.section,
                      onPressed: onDownload,
                    ),
                  ),
                if (update.stage == UpdateStage.downloaded)
                  Expanded(
                    child: TonalButton(
                      label: '安装',
                      glyph: AppGlyphs.check,
                      size: TonalButtonSize.section,
                      onPressed: onInstall,
                    ),
                  ),
              ],
            ),
            if (update.stage == UpdateStage.idle)
              Text(
                update.error ??
                    '「检查更新」会向 GitHub Releases 查询最新版本；发现新版本后可'
                        '直接在本页下载并安装。',
                style: context.listCaptionStyle.copyWith(
                  color: update.error == null ? null : colorScheme.error,
                ),
              ),
            if (update.stage == UpdateStage.upToDate)
              Text(
                statusText(update),
                style: context.listCaptionStyle.copyWith(
                  color: colorScheme.success,
                ),
              ),
            if (update.stage == UpdateStage.available && update.error != null)
              Text(
                update.error!,
                style: context.listCaptionStyle.copyWith(
                  color: colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final UpdateStage stage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, background, foreground) = switch (stage) {
      UpdateStage.idle => (
        colorScheme.onSurfaceVariant,
        context.raisedSurfaceLevel.colorOf(colorScheme),
        colorScheme.onSurfaceVariant,
      ),
      UpdateStage.checking => (
        colorScheme.warning,
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
      ),
      UpdateStage.upToDate => (
        colorScheme.success,
        colorScheme.successContainer,
        colorScheme.onSuccessContainer,
      ),
      UpdateStage.available || UpdateStage.downloading => (
        colorScheme.primary,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      UpdateStage.downloaded => (
        colorScheme.success,
        colorScheme.successContainer,
        colorScheme.onSuccessContainer,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (stage.isBusy)
          CommonCircleLoading(size: 14, color: color)
        else
          GlyphIcon(AppGlyphs.status, size: 14, color: color),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: ShapeDecoration(color: background, shape: AppShape.full),
          child: Text(
            stage.label,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final done = state.stage == UpdateStage.downloaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          children: [
            Text(done ? '下载完成' : '正在下载', style: context.listSubtitleStyle),
            const Spacer(),
            Text(
              '${(state.progress * 100).round()}%',
              style: context.listSubtitleStyle.copyWith(
                fontFamily: 'JetBrainsMono',
                color: done ? colorScheme.success : colorScheme.primary,
              ),
            ),
          ],
        ),
        ClipRSuperellipse(
          borderRadius: AppRadius.full,
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            backgroundColor: context.raisedSurfaceLevel.colorOf(colorScheme),
            color: done ? colorScheme.success : colorScheme.primary,
          ),
        ),
      ],
    );
  }
}