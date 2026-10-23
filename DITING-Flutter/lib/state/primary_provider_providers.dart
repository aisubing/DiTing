/// Active primary provider plus shared relative-time labels, so the status and speed-test cards
/// cannot disagree.
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected one in single mode, otherwise the first of the race set in catalog order; null when
/// absent.
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

/// Relative time from the real timestamp; without one, "not tested yet".
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
