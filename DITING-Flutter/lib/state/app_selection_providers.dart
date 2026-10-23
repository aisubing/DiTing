/// Which apps take part in routing; the single source of truth the app rules pages read too.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected package names; a `Set` dedupes and gives O(1) `contains`, which matters every frame.
class AppSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String packageName) {
    final next = {...state};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    state = next;
  }

  /// Selects all candidates, never adding packages outside the given set.
  void selectAll(Iterable<String> packageNames) => state = {...packageNames};

  /// Inverts within the candidates; selections outside them are kept.
  void invert(Iterable<String> packageNames) {
    final next = {...state};
    for (final packageName in packageNames) {
      if (!next.remove(packageName)) {
        next.add(packageName);
      }
    }
    state = next;
  }

  void clear() => state = const {};
}

final appSelectionProvider =
    NotifierProvider<AppSelectionNotifier, Set<String>>(
      AppSelectionNotifier.new,
    );
