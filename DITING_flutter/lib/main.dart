import 'package:diting/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 入口。工程只有这一处 `runApp`；测试挂 [DitingApp] 时自己建 `ProviderScope`，
/// 以免与真实的全局容器互相污染。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DitingApp()));
}
