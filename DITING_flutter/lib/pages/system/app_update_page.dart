/// 应用更新（上游没有独立页，落在 about 页的检查更新入口）。
///
/// 三段结构：版本对比 → 下载进度 → 更新日志。演示层不联网：检查与下载都用
/// `Future.delayed` 走完，进度条按 10 步推进，让「下载中」这个状态真的可见。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 当前版本（与 `settings_page.dart` 的 `appVersionLabel` 对齐）。
const currentAppVersion = '1.0.0';

/// 应用更新页。
class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);
    final colorScheme = context.colorScheme;
    final latest = mockChangelog.first;
    return CommonScaffold(
      title: '检查更新',
      menuItems: [
        CommonPopupMenuItem(
          label: '重置更新状态',
          glyph: AppGlyphs.reset,
          onPressed: notifier.reset,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                              update.stage == UpdateStage.available ||
                                      update.stage ==
                                          UpdateStage.downloading ||
                                      update.stage ==
                                          UpdateStage.downloaded
                                  ? '可更新到 ${latest.version}'
                                  : '谛听',
                              style: AppTextStyle.title3.of(
                                context,
                                emphasized: true,
                              ),
                            ),
                            Text(
                              '当前版本 $currentAppVersion',
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
                          onPressed: update.stage.isBusy
                              ? null
                              : () => notifier.check(),
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
                            onPressed: update.stage.isBusy
                                ? null
                                : () => notifier.download(),
                          ),
                        ),
                      if (update.stage == UpdateStage.downloaded)
                        Expanded(
                          child: TonalButton(
                            label: '安装',
                            glyph: AppGlyphs.check,
                            size: TonalButtonSize.section,
                            onPressed: () =>
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  const SnackBar(
                                    content: Text('演示环境不执行安装'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(milliseconds: 1600),
                                  ),
                                ),
                          ),
                        ),
                    ],
                  ),
                  if (update.stage == UpdateStage.idle)
                    Text(
                      '演示层不发起真实请求：点「检查更新」会直接返回「发现新版本」，'
                      '下载会走完 10 步进度后停在「下载完成」。',
                      style: context.listCaptionStyle,
                    ),
                ],
              ),
            ),
          ),
          const ListHeader(title: '更新日志'),
          for (final entry in mockChangelog)
            _ChangelogCard(entry: entry, isLatest: entry == latest),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.info,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    '更新不会影响你的配置与规则；如需回滚，可在「备份与恢复」里导入旧配置。',
                    style: context.listCaptionStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 阶段徽标。
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
      UpdateStage.available => (
        colorScheme.primary,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      UpdateStage.downloading => (
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
            style: AppTextStyle.caption1.of(context).copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

/// 下载进度条。
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
            Text(
              done ? '下载完成' : '正在下载',
              style: context.listSubtitleStyle,
            ),
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

/// 一条更新日志。
class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry, required this.isLatest});

  final MockChangelogEntry entry;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Text(
                  entry.version,
                  style: AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(fontFamily: 'JetBrainsMono'),
                ),
                if (isLatest)
                  TonalChip(
                    label: '最新',
                    color: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                const Spacer(),
                Text(entry.date, style: context.listCaptionStyle),
              ],
            ),
            for (final item in entry.items)
              Row(
                spacing: 6,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: ShapeDecoration(
                        shape: AppShape.circle,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyle.footnote.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
