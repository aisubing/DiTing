/// About page, merged with the former update & support page. The layout follows FlClash's
/// `lib/views/about.dart`: centred hero, version/licence pills, one check-update bar, then grouped
/// rows. Update state renders inline under the bar instead of a separate card.
library;

import 'package:diting/pages/hub/recognition_pages.dart';
import 'package:diting/pages/system/app_info.dart';
import 'package:diting/pages/system/disclaimer_page.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);
    final disableStartupCheck = ref.watch(startupUpdateCheckProvider);
    return CommonScaffold(
      title: '关于',
      body: PageBody(
        children: [
          _AboutHero(
            version: ref.watch(appVersionProvider).name,
            update: update,
            onCheck: update.stage.isBusy ? null : notifier.check,
            onDownload: update.stage.isBusy ? null : notifier.download,
            onInstall: () => _install(context, ref),
          ),
          const SizedBox(height: 8),
          generateSection(
            title: '更多',
            items: [
              _LinkRow(
                glyph: AppGlyphs.code,
                title: '项目',
                label: projectRepositoryUrl.replaceFirst('https://', ''),
                url: projectRepositoryUrl,
              ),
              _LinkRow(
                glyph: AppGlyphs.send,
                title: '加入 QQ 群',
                label: '群号 $qqGroupNumber',
                url: qqGroupUri,
              ),
              _LinkRow(
                glyph: AppGlyphs.star,
                title: '赞助',
                label: sponsorReadmeUrl.replaceFirst('https://', ''),
                url: sponsorReadmeUrl,
              ),
            ],
          ),
          generateSection(
            title: '开源致谢',
            items: [
              _LinkRow(
                glyph: AppGlyphs.palette,
                title: 'FlClash',
                label: '界面组件与交互实现复用自该项目',
                url: flClashRepositoryUrl,
              ),
              _LinkRow(
                glyph: AppGlyphs.vpn,
                title: 'blockads-android',
                label: 'Go 隧道内核最初魔改自该项目',
                url: blockAdsRepositoryUrl,
              ),
            ],
            footer:
                '上述两个项目均以 GPL-3.0 协议开源，相关代码与设计的版权归各自作者所有。'
                '谛听的界面层大量借鉴了 FlClash 的实现思路，隧道内核也源自 blockads-android 的早期改造；'
                '在此向它们的作者与所有贡献者致以诚挚谢意。',
          ),
          generateSection(
            title: '设置',
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
              ListItem.next(
                leading: const GlyphIcon(AppGlyphs.gavel),
                title: const Text('使用须知与免责声明'),
                subtitle: const Text('软件说明、运行机制与免责条款全文'),
                // Acceptance happens in the first-run dialog; this only re-reads it.
                widget: const DisclaimerPage(),
              ),
            ],
          ),
          generateSection(
            title: '其他贡献者',
            items: [
              ListItem.next(
                leading: const GlyphIcon(AppGlyphs.verified),
                title: const Text('赞助者名单'),
                subtitle: const Text('鸣谢支持谛听项目的赞助者'),
                widget: const SponsorListPage(),
              ),
              ListItem.next(
                leading: const GlyphIcon(AppGlyphs.account),
                title: const Text('共建者名单'),
                subtitle: const Text('感谢为谛听贡献代码与建议的共建者'),
                widget: const CoBuildersPage(),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Install through the system installer; failures are reported, usually a missing install
  /// permission.
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

/// Centred hero: app icon, name, version and licence pills, description and the update bar.
class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.version,
    required this.update,
    required this.onCheck,
    required this.onDownload,
    required this.onInstall,
  });

  static const _logoSize = 96.0;
  static const _logoInset = 14.0;

  final String version;
  final UpdateState update;
  final VoidCallback? onCheck;
  final VoidCallback? onDownload;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final stage = update.stage;
    // The brand mark ships in both modes: #FAF8F9/#007AFE for light, #1F1F22/#2E83FF for dark.
    final logoAsset = colorScheme.brightness == Brightness.dark
        ? 'assets/images/icon_dark.png'
        : 'assets/images/icon.png';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
              shape: AppShape.all(AppCorner.fit(_logoSize)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_logoInset),
              child: Image.asset(
                logoAsset,
                width: _logoSize - _logoInset * 2,
                height: _logoSize - _logoInset * 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '谛听',
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Pill(
                label: 'v$version',
                color: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              _Pill(
                label: 'GPL-3.0',
                color: context.raisedSurfaceLevel.colorOf(colorScheme),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              '基于 Android VpnService 的本地优先 DNS 加速与流量过滤工具，'
              '简单易用，开源无广告。',
              textAlign: TextAlign.center,
              style: AppTextStyle.subheadline.of(context).copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TonalButton(
            size: TonalButtonSize.bar,
            glyph: AppGlyphs.sync,
            label: stage == UpdateStage.checking ? '检查中…' : '检查更新',
            onPressed: onCheck,
          ),
          if (stage == UpdateStage.downloading || stage == UpdateStage.downloaded)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _DownloadProgress(state: update),
            ),
          if (stage == UpdateStage.available ||
              stage == UpdateStage.downloading ||
              stage == UpdateStage.downloaded)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TonalButton(
                size: TonalButtonSize.section,
                glyph: stage == UpdateStage.downloaded
                    ? AppGlyphs.check
                    : AppGlyphs.cloudDownload,
                label: switch (stage) {
                  UpdateStage.downloading => '下载中…',
                  UpdateStage.downloaded => '安装',
                  _ => '下载',
                },
                onPressed: stage == UpdateStage.downloaded
                    ? onInstall
                    : onDownload,
              ),
            ),
          if (_caption(context) case final caption?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                caption.text,
                textAlign: TextAlign.center,
                style: context.listCaptionStyle.copyWith(color: caption.color),
              ),
            ),
        ],
      ),
    );
  }

  /// One status line under the bar; null while idle and clean, where the bar speaks for itself.
  ({String text, Color color})? _caption(BuildContext context) {
    final colorScheme = context.colorScheme;
    final latest = update.info?.version;
    final current = update.currentVersion;
    return switch (update.stage) {
      UpdateStage.idle => switch (update.error) {
        final error? => (text: error, color: colorScheme.error),
        null => null,
      },
      UpdateStage.checking => (
        text: '正在检查 GitHub Release',
        color: colorScheme.onSurfaceVariant,
      ),
      UpdateStage.upToDate => (
        text: '当前已是最新版本${current == null ? '' : '（$current）'}',
        color: colorScheme.success,
      ),
      UpdateStage.available => (
        text: [
          '发现 ${latest ?? '新'}版本',
          if (current != null) '（当前 $current）',
          if (update.error != null) '，${update.error}',
        ].join(),
        color: update.error == null ? colorScheme.primary : colorScheme.error,
      ),
      UpdateStage.downloading || UpdateStage.downloaded => (
        text: '${latest ?? '新版本'} 更新包',
        color: colorScheme.onSurfaceVariant,
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  final String label;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: AppShape.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: AppTextStyle.caption1.of(context, emphasized: true).copyWith(
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}

/// External link row: square glyph badge, title, one-line target, open-external arrow.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.glyph,
    required this.title,
    required this.label,
    required this.url,
  });

  final Glyph glyph;
  final String title;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.md,
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: GlyphIcon(
              glyph,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      title: Text(title),
      subtitle: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const GlyphIcon(AppGlyphs.openExternal),
      onTap: () => openLinkOrCopy(
        context,
        url,
        '未能打开浏览器，链接已复制：$url',
      ),
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
    final color = done ? colorScheme.success : colorScheme.primary;
    return ClipRSuperellipse(
      borderRadius: AppRadius.full,
      child: LinearProgressIndicator(
        value: state.progress,
        minHeight: 8,
        backgroundColor: context.raisedSurfaceLevel.colorOf(colorScheme),
        color: color,
      ),
    );
  }
}
