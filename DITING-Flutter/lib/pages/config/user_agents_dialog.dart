part of 'user_agents_page.dart';

/// Add or edit a User-Agent; an empty [existing] means a new entry.
Future<void> showUserAgentDialog(
  BuildContext context,
  WidgetRef ref, {
  String? existing,
}) async {
  final agents = ref.read(configResourcesProvider).userAgents;
  final value = await showFloatingDialog<String>(
    context: context,
    child: InputDialog(
      title: existing == null ? '添加 User-Agent' : '编辑 User-Agent',
      value: existing ?? '',
      hintText: '如：clash-verge/v2.0.0',
      labelText: 'User-Agent',
      maxLength: TextInputLimits.userAgent,
      selectAll: existing != null,
      validator: (input) {
        final text = (input ?? '').trim();
        if (text.isEmpty) {
          return 'UA 不能为空';
        }
        if (text != existing && agents.any((item) => item.value == text)) {
          return '该 UA 已存在';
        }
        return null;
      },
    ),
  );
  if (value == null || !context.mounted) {
    return;
  }
  final notifier = ref.read(configResourcesProvider.notifier);
  final ok = existing == null
      ? notifier.addUserAgent(value)
      : notifier.updateUserAgent(existing, value);
  if (!ok) {
    showConfigHint(context, '该 UA 已存在');
  }
}
