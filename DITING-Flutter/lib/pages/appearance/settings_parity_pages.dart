/// 外观与设置的对齐二级页（下半）：通知栏 / 软件背景 / 前后台行为 / 语言。
///
/// 这四页走的是旧版**设置域**的键，而不是外观域的视觉偏好：
/// - 通知栏四键在 `notification_settings_prefs`（前台服务读那一份）；
/// - 后台隐藏 / 绕过局域网 / IPv6 在 `ui/settings/SystemSettingsStore.kt`；
/// - 语言只有「跟随系统 / 中文」两项。
///
/// 与 `appearance_shared_pages.dart` 拆开的唯一原因是 550 行上限。
library;

import 'dart:io';

import 'package:diting/pages/appearance/appearance_inputs.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// 通知栏设置（旧版 NotificationSettingsScreen，四个键）
// ---------------------------------------------------------------------------

/// 通知栏设置：常驻通知 / 实时速率 / 两条自定义文案 / 系统通知权限。
///
/// 四个键都在 `notification_settings_prefs` 容器里（不是 `dns_vpn_prefs`）：
/// 前台服务读的是那一份，写错容器界面上看不出区别，通知栏却毫无变化。
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
              ListItem(
                title: const Text('系统通知权限'),
                subtitle: const Text('在系统设置里允许或关闭本应用的通知'),
                leading: const GlyphIcon(AppGlyphs.lock),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _hint(context, '请在系统设置 → 应用 → 谛听 → 通知里调整'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「上标签 + 下输入框」的内联编辑行。
///
/// 不复用 `ListItem.input`：那个自带点击弹出的对话框，而这里是内联编辑，
/// 行为完全不同。
void _hint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
    ),
  );
}

// ---------------------------------------------------------------------------
// 软件背景（旧版软件背景页）
// ---------------------------------------------------------------------------

/// 软件背景：启用开关 + 添加图片 + 已添加壁纸缩略图网格。
///
/// 选图要走原生 `PickVisualMedia`（通道由 Lead 提供）。通道缺失时这一页仍然可用
/// ——开关与清单照样读写，只是「添加图片」会给出明确提示，而不是弹出假缩略图。
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
              ListItem(
                title: const Text('添加图片'),
                subtitle: const Text('从相册选择一张'),
                leading: const GlyphIcon(AppGlyphs.add),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () async {
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

/// 壁纸缩略图网格：每行三张，点选切换、长按删除。
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
    // 缩略图接近手机比例（9:16），三列排布。
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
        // 最后一个动作是破坏性的：`destructive` 让它在填充底上呈红色，
        // 与其它确认弹窗一致（手写红字会得到「蓝底红字」的错误配色）。
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

/// 单张壁纸缩略图；从原生缓存路径加载，选中时右上角打勾。
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

// ---------------------------------------------------------------------------
// 前后台行为（旧版 FOREGROUND_BACKGROUND_SETTINGS）
// ---------------------------------------------------------------------------

/// 前后台行为：后台隐藏 / 绕过局域网 / IPv6 三档 / 忽略电池优化。
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
              ListItem(
                title: const Text('忽略电池优化'),
                subtitle: const Text('跳转系统设置，把本应用加入白名单'),
                leading: const GlyphIcon(AppGlyphs.bolt),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _hint(context, '请在系统设置 → 电池 → 电池优化里把谛听设为不优化'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 语言设置（旧版 LANGUAGE_SETTINGS：只有跟随系统 / 中文）
// ---------------------------------------------------------------------------

/// 语言设置。
///
/// 旧版枚举里预留了英文但没有文案资源，界面上只有两项。本轮照旧只做两项，
/// 并如实说明英文尚未提供——不臆造一个点了没反应的选项。
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
