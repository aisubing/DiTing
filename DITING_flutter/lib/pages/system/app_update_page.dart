/// 更新与支持（对齐旧版 `ui/AppUpdateScreen.kt`）。
///
/// 旧版是一张 5 行的设置组：当前版本 / 检查更新 / 关闭启动时检查更新 /
/// 加入 QQ 群 / （发现新版本时才出现的）下载·安装。本轮结构照抄，但把
/// **更新日志**留在页尾：本仓的更新是演示流程（`updateProvider` 三个
/// `Future.delayed`），用户需要一段说明，否则「检查更新」点完只看到阶段徽标变了一下。
///
/// `关闭启动时检查更新` 的语义容易写反：键名是 `disable_*`、默认 true，
/// 也就是**开关打开 = 不检查**。provider 的 `toggle(bool)` 与键同向，页面直接
/// 传开关值，不做取反。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/pages/system/app_info.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 检查更新页。
class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);
    final disableStartupCheck = ref.watch(startupUpdateCheckProvider);
    final latest = mockChangelog.first;
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
            update: update,
            latest: latest,
            hasNewVersion: hasNewVersion,
            onCheck: update.stage.isBusy ? null : notifier.check,
            onDownload: update.stage.isBusy ? null : notifier.download,
          ),
          generateSection(
            title: '更新与支持',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: const Text('当前版本'),
                subtitle: const Text(appVersionName),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.refresh),
                title: const Text('检查更新'),
                subtitle: Text(statusText(update)),
                onTap: update.stage.isBusy ? null : notifier.check,
              ),
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
          ),
          const ListHeader(title: '更新日志'),
          for (final entry in mockChangelog)
            _ChangelogCard(entry: entry, isLatest: entry == latest),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.info,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    '更新不会影响你的配置与规则；导入旧配置可在「备份与迁移」里完成。',
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

/// 旧版 `updateStatusText` + `downloadActionText` 的文案。
String statusText(UpdateState state) {
  final latest = mockChangelog.first.version;
  return switch (state.stage) {
    UpdateStage.checking => '正在检查 GitHub Release',
    UpdateStage.available => '发现 $latest 新版本，可下载',
    UpdateStage.downloading =>
      '正在下载 $latest，${(state.progress * 100).round()}%',
    UpdateStage.downloaded => '$latest 已下载，点击安装',
    UpdateStage.upToDate => '当前已是最新版本',
    UpdateStage.idle => '检查 GitHub Release 中的最新版本',
  };
}

/// 页首版本卡：当前版本 + 阶段徽标 + 检查 / 下载 / 安装按钮。
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.latest,
    required this.hasNewVersion,
    required this.onCheck,
    required this.onDownload,
  });

  final UpdateState update;
  final MockChangelogEntry latest;
  final bool hasNewVersion;
  final VoidCallback? onCheck;
  final VoidCallback? onDownload;

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
                        hasNewVersion ? '可更新到 ${latest.version}' : '谛听',
                        style: AppTextStyle.title3.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      Text(
                        '当前版本 $appVersionName',
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
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(
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
