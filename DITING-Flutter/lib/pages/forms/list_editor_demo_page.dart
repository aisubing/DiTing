/// 列表编辑器演示页（`/form/list-editor`）。
///
/// 把泛型 `ListEditorPage` 实例化成「定时服务器列表」，用来演示搜索、全选、
/// 排序与删除。真实页面（规则、订阅）会各自实例化同一个组件。
library;

import 'package:diting/pages/forms/list_editor_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一条演示用的服务器记录。
class _DemoServer {
  const _DemoServer(this.name, this.address);

  final String name;
  final String address;
}

const _seedServers = <_DemoServer>[
  _DemoServer('阿里 NTP', 'ntp.aliyun.com'),
  _DemoServer('腾讯 NTP', 'ntp.tencent.com'),
  _DemoServer('国家授时中心', 'ntp.ntsc.ac.cn'),
  _DemoServer('Google NTP', 'time.google.com'),
  _DemoServer('Cloudflare NTP', 'time.cloudflare.com'),
];

/// 列表编辑器演示页。
class ListEditorDemoPage extends StatefulWidget {
  const ListEditorDemoPage({super.key});

  @override
  State<ListEditorDemoPage> createState() => _ListEditorDemoPageState();
}

class _ListEditorDemoPageState extends State<ListEditorDemoPage> {
  var _servers = [..._seedServers];

  Future<void> _add() async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: _TextFieldDialog(
        title: '添加服务器',
        submitLabel: '添加',
        labelText: '名称',
        hintText: '如「备用 NTP」',
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _servers = [..._servers, _DemoServer(name, 'ntp.example.com')];
    });
  }

  Future<void> _edit(_DemoServer server) async {
    final address = await showFloatingDialog<String>(
      context: context,
      child: _TextFieldDialog(
        title: '编辑地址',
        submitLabel: '保存',
        labelText: '地址',
        initial: server.address,
      ),
    );
    if (address == null || address.isEmpty || !mounted) {
      return;
    }
    final index = _servers.indexOf(server);
    if (index < 0) {
      return;
    }
    setState(() {
      _servers = [..._servers]..[index] = _DemoServer(server.name, address);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListEditorPage<_DemoServer>(
      title: '定时服务器',
      items: _servers,
      labelBuilder: (server) => server.name,
      subtitleBuilder: (server) => server.address,
      emptyLabel: '还没有定时服务器',
      emptyDescription: '点右上角加号添加第一台',
      addLabel: '添加服务器',
      onAdd: _add,
      onEdit: _edit,
      onSave: (items) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('已保存 ${items.length} 条（演示：不落盘）'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ),
      ),
      footer: '排序与删除只改本页状态；离开页面再回来会恢复演示数据。',
    );
  }
}

/// 单行输入弹窗。
///
/// 控制器由弹窗自己持有：写成「调用方 new 一个 controller、`await` 之后立刻
/// `dispose()`」时，`pop` 一调用 future 就完成，而退场动画还没跑完、`TextField`
/// 仍挂在树上，dispose 会让它在动画中途重建到已失效的依赖上，实测整屏红
/// （`'_dependents.isEmpty': is not true`）。
class _TextFieldDialog extends StatefulWidget {
  const _TextFieldDialog({
    required this.title,
    required this.submitLabel,
    required this.labelText,
    this.hintText,
    this.initial = '',
  });

  final String title;
  final String submitLabel;
  final String labelText;
  final String? hintText;
  final String initial;

  @override
  State<_TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<_TextFieldDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.title,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.submitLabel),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
      ),
    );
  }
}
