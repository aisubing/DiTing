/// 当前主服务商，以及「多久以前」这类共用文案。
///
/// 单独一个文件而不是塞进某张卡：状态卡与测速卡都要显示「现在走哪个服务商」，
/// 两处各算一遍，多路模式下「取竞速集合里目录顺序的第一个」的口径迟早会分叉。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前主服务商：单选模式取选中的那个，多路模式取竞速集合里目录顺序的第一个
/// （与首页「DNS 服务详情」块同序）。目录里找不到时为 null。
final primaryProviderProvider = Provider<MockProvider?>((ref) {
  final mode = ref.watch(workModeProvider);
  final catalog = ref.watch(dnsProviderCatalogProvider);
  final selectedId = ref.watch(selectedProviderProvider);
  final raceIds = ref.watch(raceProvidersProvider);
  final primaryId = mode == AppWorkMode.normal || mode == AppWorkMode.express
      ? selectedId
      : catalog
            .where((provider) => raceIds.contains(provider.id))
            .firstOrNull
            ?.id;
  return catalog.where((provider) => provider.id == primaryId).firstOrNull;
});

/// 「多久以前」：按真实时间差算，没有时间戳就写「尚未测速」。
String elapsedAgoLabel(DateTime? at) {
  if (at == null) return '尚未测速';
  final seconds = DateTime.now().difference(at).inSeconds;
  if (seconds < 5) return '刚刚';
  if (seconds < 60) return '$seconds 秒前';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes 分钟前';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours 小时前';
  return '${hours ~/ 24} 天前';
}
