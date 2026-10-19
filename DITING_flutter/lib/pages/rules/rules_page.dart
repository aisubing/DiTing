import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 占位：待实现。
class RulesPage extends StatelessWidget {
  const RulesPage({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '规则',
      body: const NullStatus(label: '待实现', description: '该页尚未编写'),
    );
  }
}
