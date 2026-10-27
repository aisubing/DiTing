/// Notifications, background and language sub pages; keys in `notification_settings_prefs`.
library;

import 'dart:io';

import 'package:diting/data/native/permissions_bridge.dart';
import 'package:diting/pages/appearance/appearance_inputs.dart';
import 'package:diting/state/permission_providers.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/nav_entry_row.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';


/// Notification settings. The four keys live in `notification_settings_prefs`: the
/// foreground service reads that container, so writing elsewhere silently does nothing.
class ThemeNotificationPage extends ConsumerStatefulWidget {
  const ThemeNotificationPage({super.key});

  @override
  ConsumerState<ThemeNotificationPage> createState() =>
      _ThemeNotificationPageState();
}

class _ThemeNotificationPageState extends ConsumerState<ThemeNotificationPage> {
  late final TextEditingController _running;
  late final TextEditingController _stopped;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(notificationSettingsProvider);
    _running = TextEditingController(text: settings.runningText);
    _stopped = TextEditingController(text: settings.stoppedText);
  }

  @override
  void dispose() {
    _running.dispose();
    _stopped.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    return CommonScaffold(
      title: '通知栏设置',
      body: PageBody(
        children: [
          generateSection(
            title: '常驻通知',
            footer: '关闭后服务运行时不再显示常驻通知，系统可能因此更快回收进程。',
            items: [
              ListItem.toggle(
                title: const Text('通知常驻'),
                subtitle: const Text('服务运行时保留一条不可划掉的通知'),
                leading: const GlyphIcon(AppGlyphs.status),
                value: settings.persistent,
                onChanged: notifier.setPersistent,
              ),
              ListItem.toggle(
                title: const Text('显示实时速率'),
                subtitle: const Text('在通知里显示当前上下行速率'),
                leading: const GlyphIcon(AppGlyphs.speed),
                value: settings.showSpeed,
                onChanged: settings.persistent ? notifier.setShowSpeed : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: FieldGroupCard(
              children: [
                LabeledTextField(
                  label: 'DNS 服务开启时',
                  controller: _running,
                  minLines: 2,
                  hintText: '留空则使用默认文案',
                  onChanged: notifier.setRunningText,
                ),
                LabeledTextField(
                  label: 'DNS 服务关闭时',
                  controller: _stopped,
                  minLines: 2,
                  hintText: '留空则使用默认文案',
                  onChanged: notifier.setStoppedText,
                ),
              ],
            ),
          ),
          const ListFooter(text: '留空则使用默认文案；文案只影响通知栏，不改变服务行为。'),
          generateSection(
            title: '权限',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.lock,
                title: '系统通知权限',
                subtitle: '打开系统的通知设置页',
                // Opening the page directly beats a hint: the hint only told people what
                // to do and left them to find it in Settings.
                onPressed: () => ref
                    .read(permissionStatesProvider.notifier)
                    .openSystemSettings(AppPermission.notification),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline edit row; `ListItem.input` opens a dialog on tap instead.
void _hint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
    ),
  );
}


/// App background. Picking goes through the native `PickVisualMedia` channel; without
/// it the page still works and only "add image" reports that it is unavailable.
class ThemeBackgroundPage extends ConsumerWidget {
  const ThemeBackgroundPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = ref.watch(customBackgroundProvider);
    final notifier = ref.read(customBackgroundProvider.notifier);
    return CommonScaffold(
      title: '软件背景',
      body: PageBody(
        children: [
          generateSection(
            title: '自定义背景',
            footer: '壁纸只保存在本机，不随备份导出。',
            items: [
              ListItem.toggle(
                title: const Text('启用自定义背景'),
                subtitle: Text(
                  background.uris.isEmpty ? '请先添加一张图片' : '在全部页面下垫一层壁纸',
                ),
                leading: const GlyphIcon(AppGlyphs.photos),
                value: background.enabled,
                onChanged: background.uris.isEmpty ? null : notifier.setEnabled,
              ),
              NavEntryRow(
                glyph: AppGlyphs.add,
                title: '添加图片',
                subtitle: '从相册选择一张',
                onPressed: () async {
                  final error = await notifier.pickAndAdd();
                  if (error != null && context.mounted) _hint(context, error);
                },
              ),
            ],
          ),
          if (background.uris.isNotEmpty)
            generateSection(
              title: '已添加壁纸',
              footer: '点一下切换，长按删除。',
              items: [
                _WallpaperGrid(
                  uris: background.uris,
                  currentUri: background.currentUri,
                  onSelect: notifier.select,
                  onRemove: notifier.remove,
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: NullStatus(
                illustration: NullStatusIllustration.data,
                label: '还没有背景图',
                description: '点「添加图片」从相册里挑一张。',
              ),
            ),
        ],
      ),
    );
  }
}

class _WallpaperGrid extends StatelessWidget {
  const _WallpaperGrid({
    required this.uris,
    required this.currentUri,
    required this.onSelect,
    required this.onRemove,
  });

  final List<String> uris;
  final String? currentUri;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    // Thumbnails use a phone-like 9:16 ratio in three columns.
    const aspectRatio = 9 / 16;
    final rows = <Widget>[];
    for (var i = 0; i < uris.length; i += 3) {
      final rowUris = uris.sublist(i, (i + 3).clamp(0, uris.length));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            for (final uri in rowUris)
              Expanded(
                child: _WallpaperThumbnail(
                  uri: uri,
                  aspectRatio: aspectRatio,
                  selected: uri == currentUri,
                  onTap: () => onSelect(uri),
                  onLongPress: () => _confirmRemove(context, uri),
                ),
              ),
            for (var pad = rowUris.length; pad < 3; pad++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(spacing: 8, children: rows),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String uri) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除壁纸',
        // The last action is destructive: `destructive` tints it red on a filled
        // background, consistent with the other confirmation dialogs.
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: const Text('确定删除这张已添加的壁纸吗？'),
      ),
    );
    if (confirmed == true) onRemove(uri);
  }
}

/// One wallpaper thumbnail, checked when selected.
class _WallpaperThumbnail extends StatefulWidget {
  const _WallpaperThumbnail({
    required this.uri,
    required this.aspectRatio,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String uri;
  final double aspectRatio;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_WallpaperThumbnail> createState() => _WallpaperThumbnailState();
}

class _WallpaperThumbnailState extends State<_WallpaperThumbnail> {
  late Future<String?> _path;

  @override
  void initState() {
    super.initState();
    _path = _resolve();
  }

  Future<String?> _resolve() async {
    final container = ProviderScope.containerOf(context, listen: false);
    return container.read(backgroundBridgeProvider).resolve(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRSuperellipse(
          borderRadius: AppRadius.md,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colorScheme.surfaceContainerHighest),
              FutureBuilder<String?>(
                future: _path,
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  if (path == null) return const SizedBox.shrink();
                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  );
                },
              ),
              if (widget.selected) ...[
                ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: ShapeDecoration(
                      shape: AppShape.circle,
                      color: colorScheme.primary,
                    ),
                    child: GlyphIcon(
                      AppGlyphs.check,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class SettingsBackgroundPage extends ConsumerWidget {
  const SettingsBackgroundPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foregroundBackgroundProvider);
    final notifier = ref.read(foregroundBackgroundProvider.notifier);
    return CommonScaffold(
      title: '前后台行为',
      body: PageBody(
        children: [
          generateSection(
            title: '后台与隐私',
            footer: '「后台隐藏」会从最近任务列表里移除本应用；下次从桌面图标进入即可。',
            items: [
              ListItem.toggle(
                title: const Text('后台隐藏'),
                subtitle: const Text('不在最近任务列表中显示'),
                leading: const GlyphIcon(AppGlyphs.eyeOff),
                value: state.hideFromRecents,
                onChanged: notifier.setHideFromRecents,
              ),
            ],
          ),
          generateSection(
            title: '路由',
            items: [
              ListItem.toggle(
                title: const Text('绕过局域网'),
                subtitle: const Text('本地网段与本机地址不走隧道'),
                leading: const GlyphIcon(AppGlyphs.devices),
                value: state.bypassLan,
                onChanged: notifier.setBypassLan,
              ),
              ListItem<LegacyIpv6Mode>.options(
                title: const Text('IPv6'),
                subtitle: Text(state.ipv6Mode.description),
                leading: const GlyphIcon(AppGlyphs.link),
                options: LegacyIpv6Mode.values,
                value: state.ipv6Mode,
                textBuilder: (mode) => mode.label,
                onChanged: notifier.setIpv6Mode,
              ),
            ],
          ),
          generateSection(
            title: '稳定性',
            footer: '关闭电池优化后，系统在后台更不容易回收服务进程。',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.bolt,
                title: '忽略电池优化',
                subtitle: '请求把本应用加入系统白名单',
                // Asks the system instead of describing the screen path; the request shows the
                // "always run in background" dialog when the ROM allows it.
                onPressed: () => ref
                    .read(permissionStatesProvider.notifier)
                    .request(AppPermission.batteryOptimization),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// The legacy enum reserves English but ships no strings, so only two options are offered.
class SettingsLanguagePage extends ConsumerWidget {
  const SettingsLanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);
    return CommonScaffold(
      title: '语言设置',
      body: PageBody(
        children: [
          generateSection(
            title: '界面语言',
            footer: '英文界面的文案尚未提供；选择「跟随系统」时非中文系统仍显示中文。',
            items: [
              for (final option in AppLanguageMode.values)
                ListItem(
                  title: Text(option.label),
                  leading: GlyphIcon(
                    option == mode ? AppGlyphs.check : AppGlyphs.language,
                    color: option == mode ? context.colorScheme.primary : null,
                  ),
                  trailing: option == mode
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () =>
                      ref.read(languageModeProvider.notifier).select(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}