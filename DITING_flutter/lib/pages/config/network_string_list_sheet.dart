part of 'network_page.dart';

/// 可以在面板里增删的三个字符串列表。
///
/// 三处交互完全一致（一行一个值、行尾删除、右上角加号），只有标题与文案不同，
/// 所以做成同一个面板 + 一个枚举参数，而不是三份几乎相同的代码。
enum NetworkStringList {
  bypassDomain(
    title: '绕过域名',
    hint: '域名或通配符，如 *.lan',
    footer: '同一域名只需添加一次；通配符只支持前缀形式（*.example.com）。',
  ),
  routeAddress(
    title: '路由网段',
    hint: 'CIDR，如 198.18.0.1/16',
    footer: '只有这些网段的流量会进入 TUN；留空表示使用内核默认值。',
  ),
  routeExcludeAddress(
    title: '排除网段',
    hint: 'CIDR，如 10.0.0.0/8',
    footer: '这些网段永远不进入 TUN，适合保留内网与组播。',
  );

  const NetworkStringList({
    required this.title,
    required this.hint,
    required this.footer,
  });

  final String title;
  final String hint;
  final String footer;

  List<String> read(MockNetworkSnapshot state) => switch (this) {
    bypassDomain => state.bypassDomain,
    routeAddress => state.routeAddress,
    routeExcludeAddress => state.routeExcludeAddress,
  };

  MockNetworkSnapshot write(MockNetworkSnapshot state, List<String> value) =>
      switch (this) {
        bypassDomain => state.copyWith(bypassDomain: value),
        routeAddress => state.copyWith(routeAddress: value),
        routeExcludeAddress => state.copyWith(routeExcludeAddress: value),
      };
}

/// 打开某个字符串列表的编辑面板。
Future<void> showNetworkStringListSheet(
  BuildContext context,
  NetworkStringList list,
) => showSheet<void>(
  context: context,
  builder: (_) => _StringListSheet(list: list),
);

class _StringListSheet extends ConsumerWidget {
  const _StringListSheet({required this.list});

  final NetworkStringList list;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final current = list.read(ref.read(networkConfigProvider));
    final value = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '添加${list.title}',
        value: '',
        hintText: list.hint,
        maxLength: TextInputLimits.domain,
        validator: (text) {
          final trimmed = (text ?? '').trim();
          if (trimmed.isEmpty) {
            return '内容不能为空';
          }
          if (current.contains(trimmed)) {
            return '该条目已存在';
          }
          return null;
        },
      ),
    );
    if (value == null) {
      return;
    }
    ref
        .read(networkConfigProvider.notifier)
        .addToStringList(
          (state) => list.read(state),
          (state, next) => list.write(state, next),
          value,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = list.read(ref.watch(networkConfigProvider));
    return CommonScaffold(
      title: list.title,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加${list.title}',
          onPressed: () => _add(context, ref),
        ),
      ],
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
        children: [
          if (items.isEmpty)
            SizedBox(
              height: 240,
              child: NullStatus(
                label: '还没有条目',
                description: '点右上角的加号添加第一条',
                illustration: NullStatusIllustration.data,
              ),
            )
          else
            generateSection(
              title: '共 ${items.length} 项',
              items: [
                for (final item in items)
                  ListItem(
                    title: Text(item),
                    trailing: ConfigRemoveButton(
                      tooltip: '删除 $item',
                      onPressed: () => ref
                          .read(networkConfigProvider.notifier)
                          .removeFromStringList(
                            (state) => list.read(state),
                            (state, next) => list.write(state, next),
                            item,
                          ),
                    ),
                  ),
              ],
              footer: list.footer,
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}
