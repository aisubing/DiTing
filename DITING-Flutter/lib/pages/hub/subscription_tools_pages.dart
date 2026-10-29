// ignore_for_file: sort_child_properties_last
import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/data/db/mirror_template_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/mirror_global_section.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/auto_update_runner.dart';
import 'package:diting/state/global_mirror_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Subscription auto-update (upstream `SubscriptionAutoUpdateIntervalScreen`). No local state: the
/// switch and interval live in `subscription_auto_update_enabled` / `..._interval_hours`.
class AutoUpdateSettingsPage extends ConsumerWidget {
  const AutoUpdateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(autoUpdateSettingsProvider);
    final groups = ref.watch(autoUpdateGroupsProvider).value;
    final actions = ref.read(autoUpdateActionsProvider);
    final candidates = ref.watch(autoUpdatableSubscriptionsProvider).value;
    final lastRun = ref.watch(autoUpdateLastRunProvider);
    final enabled = settings.enabled;
    return CommonScaffold(
      title: context.l10n.autoUpdateTitle,
      body: PageBody(
        children: [
          generateSection(
            title: context.l10n.autoUpdateSection,
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.refresh),
                title: Text(context.l10n.autoUpdateRulesSwitch),
                subtitle: Text(context.l10n.autoUpdateRulesSwitchSubtitle),
                value: enabled,
                onChanged: actions.setEnabled,
              ),
            ],
          ),
          generateSection(
            title: context.l10n.autoUpdateIntervalSection,
            items: [
              for (final hours
                  in LegacySettings.subscriptionAutoUpdatePresetHours)
                ListItem(
                  leading: GlyphIcon(
                    settings.intervalHours == hours
                        ? AppGlyphs.checkCircle
                        : AppGlyphs.clock,
                    size: 20,
                  ),
                  title: Text(context.l10n.autoUpdateEveryHours(hours)),
                  trailing: settings.intervalHours == hours
                      ? const SelectionCheck()
                      : null,
                  onTap: enabled ? () => actions.setIntervalHours(hours) : null,
                ),
              ListItem(
                leading: GlyphIcon(
                  settings.isCustom ? AppGlyphs.checkCircle : AppGlyphs.sliders,
                  size: 20,
                ),
                title: Text(context.l10n.autoUpdateCustomInterval),
                subtitle: Text(
                  settings.isCustom
                      ? context.l10n.autoUpdateEveryHours(settings.intervalHours)
                      : context.l10n.autoUpdateCustomHint,
                ),
                trailing: settings.isCustom ? const SelectionCheck() : null,
                onTap: enabled
                    ? () => _editCustom(context, ref, settings)
                    : null,
              ),
            ],
            footer: context.l10n.autoUpdateIntervalFooter,
          ),
          generateSection(
            title: context.l10n.autoUpdateStatusSection,
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.clock),
                title: Text(context.l10n.autoUpdateNext),
                subtitle: Text(
                  _nextUpdateText(context.l10n, enabled, settings, candidates),
                ),
              ),
              ListItem(
                leading: GlyphIcon(
                  lastRun == null ? AppGlyphs.info : AppGlyphs.checkCircle,
                  size: 20,
                ),
                title: Text(context.l10n.autoUpdateLast),
                subtitle: Text(
                  lastRun == null
                      ? context.l10n.autoUpdateNoRunYet
                      : '${lastRun.summary ?? ''}'
                            '${context.l10n.autoUpdateRunCount(lastRun.ranCount)}',
                ),
              ),
            ],
            footer: context.l10n.autoUpdateStatusFooter,
          ),
          generateSection(
            title: context.l10n.autoUpdateGroupsSection,
            items: [
              if (groups == null)
                ListItem(
                  leading: GlyphIcon(AppGlyphs.layers),
                  title: Text(context.l10n.autoUpdateReadingGroups),
                )
              else if (groups.isEmpty)
                ListItem(
                  leading: GlyphIcon(AppGlyphs.layers),
                  title: Text(context.l10n.autoUpdateNoGroups),
                  subtitle: Text(context.l10n.autoUpdateNoGroupsSubtitle),
                )
              else
                for (final group in groups)
                  ListItem.toggle(
                    leading: const GlyphIcon(AppGlyphs.layers),
                    title: Text(group.name),
                    value: group.autoUpdateEnabled,
                    onChanged: enabled
                        ? (value) => actions.setGroupEnabled(group.id, value)
                        : null,
                  ),
            ],
            footer: context.l10n.autoUpdateGroupsFooter,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editCustom(
    BuildContext context,
    WidgetRef ref,
    AutoUpdateSettings settings,
  ) async {
    final value = await showFloatingDialog<int>(
      context: context,
      child: _IntervalDialog(initial: settings.intervalHours),
    );
    if (value != null) {
      ref.read(autoUpdateActionsProvider).setIntervalHours(value);
    }
  }

  /// The "next update" line, covering switch off, no candidates and the earliest due one;
  /// [AutoUpdateRunner.nextDueAt] derives it from the real `lastAttemptAt`.
  String _nextUpdateText(
    AppL10n l10n,
    bool enabled,
    AutoUpdateSettings settings,
    List<SubscriptionRecord>? candidates,
  ) {
    if (!enabled) {
      return l10n.autoUpdateDisabled;
    }
    if (candidates == null) {
      return l10n.autoUpdateReadingSubs;
    }
    if (candidates.isEmpty) {
      return l10n.autoUpdateNoCandidates;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = AutoUpdateRunner.nextDueAt(
      candidates,
      settings.intervalHours,
      now,
    );
    if (due == null) {
      return l10n.autoUpdateNoSubscriptions;
    }
    if (due <= now) {
      return l10n.autoUpdateDueNow;
    }
    final when = DateTime.fromMillisecondsSinceEpoch(due);
    final remaining = due - now;
    final hours = remaining ~/ 3600000;
    final minutes = (remaining % 3600000) ~/ 60000;
    final left = hours > 0
        ? l10n.autoUpdateRemainingHours(hours, minutes)
        : l10n.autoUpdateRemainingMinutes(minutes);
    return l10n.autoUpdateNextAt(_formatMoment(when, l10n), left);
  }

  static String _formatMoment(DateTime time, AppL10n l10n) {
    String two(int value) => value.toString().padLeft(2, '0');
    return l10n.autoUpdateMoment(
      time.month,
      time.day,
      '${two(time.hour)}:${two(time.minute)}',
    );
  }
}

/// Custom interval dialog. The controller is owned by the dialog: disposing it right after
/// `await` trips a framework assertion while the exit animation still shows the `TextField`.
class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog({required this.initial});

  final int initial;

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed == null ||
        parsed < LegacySettings.minSubscriptionAutoUpdateIntervalHours ||
        parsed > LegacySettings.maxSubscriptionAutoUpdateIntervalHours) {
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: context.l10n.autoUpdateCustomInterval,
      hasFields: true,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: context.l10n.autoUpdateIntervalLabel,
          helperText: context.l10n.autoUpdateIntervalHelper,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.uiCancel),
        ),
        TextButton(onPressed: _submit, child: Text(context.l10n.commonSave)),
      ],
    );
  }
}

/// Mirror templates (upstream `MirrorTemplateScreen`), stored in the legacy
/// `mirror_template` table through `MirrorTemplateRepository` so they survive a restart.
class MirrorTemplatesPage extends ConsumerWidget {
  const MirrorTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(mirrorTemplatesProvider);
    final rows = templates.value;
    return CommonScaffold(
      title: context.l10n.mirrorTplTitle,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: context.l10n.mirrorTplAdd,
          onPressed: () => _add(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          PageIntroCard(text: context.l10n.mirrorTplIntro),
          if (rows != null) GlobalMirrorSection(templates: rows),
          generateSection(
            title: context.l10n.mirrorTplActions,
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: Text(context.l10n.mirrorTplFormatExample),
                subtitle: Text(context.l10n.mirrorTplFormatExampleSubtitle),
                onTap: () => _showFormatGuide(context),
              ),
            ],
          ),
          if (templates.hasError)
            generateSection(
              title: context.l10n.mirrorTplSaved,
              items: [
                ListItem(
                  leading: GlyphIcon(AppGlyphs.error),
                  title: Text(context.l10n.mirrorTplReadFailed),
                  subtitle: Text(context.l10n.mirrorTplReadFailedSubtitle),
                ),
              ],
            )
          else
            generateSection(
              title: context.l10n.mirrorTplSavedCount(rows?.length ?? 0),
              items: [
                for (final row in rows ?? const <MirrorTemplateRecord>[])
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.layers, size: 20),
                    title: Text(row.name),
                    subtitle: Text(row.template),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.l10n.commonEdit,
                          onPressed: () => _edit(context, ref, row),
                          icon: const GlyphIcon(AppGlyphs.edit, size: 20),
                        ),
                        IconButton(
                          tooltip: context.l10n.commonDelete,
                          onPressed: () async {
                            await ref
                                .read(mirrorTemplateActionsProvider)
                                .remove(row.id);
                            ref
                                .read(globalMirrorProvider.notifier)
                                .templateRemoved(row.template);
                          },
                          icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
              footer: rows == null
                  ? context.l10n.mirrorTplReading
                  : rows.isEmpty
                  ? context.l10n.mirrorTplEmpty
                  : null,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await _editTemplate(context);
    if (result == null) return;
    final id = await ref
        .read(mirrorTemplateActionsProvider)
        .create(name: result.name, template: result.template);
    if (id == null && context.mounted) {
      // The unique index on the name rejects the insert; report it instead of silently
      // doing nothing.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.mirrorTplDuplicate),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MirrorTemplateRecord row,
  ) async {
    final result = await _editTemplate(
      context,
      initial: (name: row.name, template: row.template),
    );
    if (result == null) return;
    final ok = await ref
        .read(mirrorTemplateActionsProvider)
        .update(id: row.id, name: result.name, template: result.template);
    if (ok) {
      ref
          .read(globalMirrorProvider.notifier)
          .templateChanged(row.template, result.template);
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.mirrorTplDuplicateSave),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<({String name, String template})?> _editTemplate(
    BuildContext context, {
    ({String name, String template})? initial,
  }) {
    return showFloatingDialog<({String name, String template})>(
      context: context,
      child: _TemplateDialog(initial: initial),
    );
  }

  void _showFormatGuide(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: context.l10n.mirrorTplFormatTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(context.l10n.mirrorTplFormatIntro),
            Text(context.l10n.mirrorTplFormatUrl('{url}')),
            Text(context.l10n.mirrorTplFormatScheme('{scheme}')),
            Text(context.l10n.mirrorTplFormatUrlEncoded('{urlEncoded}')),
            Text(context.l10n.mirrorTplFormatHost('{host}')),
            Text(context.l10n.mirrorTplFormatPath('{path}')),
            Text(context.l10n.mirrorTplFormatPathAndQuery('{pathAndQuery}')),
            Text(context.l10n.mirrorTplFormatSample('{url}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.uiClose),
          ),
        ],
      ),
    );
  }
}

/// Mirror template editor. The controller is owned by the dialog: disposing it from
/// `whenComplete` fires on `pop` while the `TextField` is still animating out.
class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({this.initial});

  final ({String name, String template})? initial;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  static final _placeholder = RegExp(
    r'\{(url|scheme|urlEncoded|host|path|pathAndQuery)\}',
  );

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _template = TextEditingController(
    text: widget.initial?.template ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _template.dispose();
    super.dispose();
  }

  bool get _valid =>
      _template.text.startsWith('http') &&
      _placeholder.hasMatch(_template.text);

  void _submit() {
    if (!_valid || _name.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context)
        .pop((name: _name.text.trim(), template: _template.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.initial == null ? context.l10n.mirrorTplAddTitle : context.l10n.mirrorTplEditTitle,
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.mirrorTplNameLabel,
              hintText: context.l10n.mirrorTplNameHint,
            ),
          ),
          TextField(
            controller: _template,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.mirrorTplAddressLabel,
              hintText: 'https://mirror.example.com/{url}',
            ),
          ),
          Text(
            _valid
                ? context.l10n.mirrorTplFormatPlaceholders(
                    '{url}',
                    '{scheme}',
                    '{urlEncoded}',
                    '{host}',
                    '{path}',
                    '{pathAndQuery}',
                  )
                : context.l10n.mirrorTplInvalid,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(
                  color: _valid
                      ? context.colorScheme.onSurfaceVariant
                      : context.colorScheme.error,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.uiCancel),
        ),
        TextButton(
          onPressed: _valid && _name.text.trim().isNotEmpty ? _submit : null,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}
