import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/settings_providers.dart';
// `Override` is only exported from `misc.dart`, not `flutter_riverpod.dart`.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Call once before mounting `DitingApp`: stops the demo rate curve (a frame per second, so
/// `pumpAndSettle` times out) and skips the agreement dialog that would block taps
void installGlobalTestHooks({bool skipInitialAgreement = true}) {
  setUp(() {
    debugDisableDashboardLiveUpdates = true;
  });
  tearDown(() {
    debugDisableDashboardLiveUpdates = false;
  });
}

/// Every test mounting `DitingApp` should use this list, so a new global prerequisite is one edit
List<Override> appTestOverrides({bool skipInitialAgreement = true}) => [
  if (skipInitialAgreement)
    initialAgreementProvider.overrideWith(InitialAgreementAccepted.new),
];

/// Always reports the agreement as accepted, injected by [appTestOverrides].
class InitialAgreementAccepted extends InitialAgreementNotifier {
  @override
  bool build() => true;
}
