// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DITING';

  @override
  String get uiBack => 'Back';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiClearSearch => 'Clear search';

  @override
  String get uiClose => 'Close';

  @override
  String get uiHidePassword => 'Hide password';

  @override
  String get uiMore => 'More';

  @override
  String get uiNoSearchResults => 'No results';

  @override
  String get uiReset => 'Reset';

  @override
  String get uiSearch => 'Search';

  @override
  String get uiShowLess => 'Show less';

  @override
  String get uiShowMore => 'Show more';

  @override
  String get uiShowPassword => 'Show password';

  @override
  String get uiSort => 'Sort';

  @override
  String get uiSubmit => 'Submit';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageInterfaceSection => 'Interface language';

  @override
  String get languageInterfaceFooter =>
      'Choose the interface language. \"Follow system\" uses the device language and falls back to Chinese for other languages.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonFollowSystem => 'Follow system';

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonInvertSelection => 'Invert selection';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDiscard => 'Don\'t save';

  @override
  String get commonSaveChangesTitle => 'Save changes?';

  @override
  String get commonSaveChangesMessage =>
      'Your changes have not been saved yet. Save them before leaving, or discard them?';

  @override
  String commonSaveChangesMessageFor(Object name) {
    return 'The selection for \"$name\" has not been saved yet. Save it before leaving, or discard the changes?';
  }

  @override
  String get commonGrantPermission => 'Grant access';

  @override
  String get palettePurple => 'Iris purple';

  @override
  String get paletteBlue => 'Water lily blue';

  @override
  String get paletteCyan => 'Pool cyan';

  @override
  String get paletteGreen => 'Willow green';

  @override
  String get paletteOrange => 'Dusk ochre';

  @override
  String get paletteRed => 'Poppy red';

  @override
  String get palettePink => 'Sunset pink';

  @override
  String get paletteGold => 'Wheat gold';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get appListUnavailable => 'Can\'t read the app list';

  @override
  String get appListFilterAll => 'All apps';

  @override
  String get appListFilterSystem => 'System apps';

  @override
  String get appListFilterUser => 'User apps';

  @override
  String get appListFilterSelected => 'Selected apps';

  @override
  String get appListSortLabelAsc => 'App name A-Z';

  @override
  String get appListSortLabelDesc => 'App name Z-A';

  @override
  String get appListSortPackageAsc => 'Package A-Z';

  @override
  String get appListSortPackageDesc => 'Package Z-A';

  @override
  String get appListNotRegistered => 'not registered';

  @override
  String appListChannelUnavailable(Object detail) {
    return 'App list channel unavailable: $detail';
  }

  @override
  String appListReadFailed(Object detail) {
    return 'Failed to read the app list: $detail';
  }

  @override
  String appListReadFailedCode(Object code) {
    return 'Failed to read the app list ($code)';
  }

  @override
  String dbWriteUnhealthy(Object dropped, Object failures) {
    return 'Log writes are failing: $dropped rows dropped and $failures failed opens. See Troubleshooting for details.';
  }

  @override
  String get agreementDeclinedTitle => 'Notice declined';

  @override
  String get agreementDeclinedMessage =>
      'DITING can\'t be used without accepting the notice and disclaimer. You can quit the app, or review the terms again and then decide.';

  @override
  String get agreementReviewAgain => 'Review again';

  @override
  String get agreementTitle => 'Notice and disclaimer';

  @override
  String get agreementDecline => 'Decline and exit';

  @override
  String get agreementAccept => 'Accept and continue';

  @override
  String get agreementMessage =>
      'About the app\nDITING is an open-source tool focused on local DNS resolution optimisation and network rule filtering. It offers three work modes: Normal (full-tunnel control), Turbo (a lightweight pure-Kotlin narrow route) and Standalone server (a LAN service that needs no VPN). Everything runs locally on the device: no remote data upload and no privacy tracking.\n\nHow it works\nNormal and Turbo modes take over DNS resolution through the Android local VPN interface and never connect to a remote VPN server; Standalone server mode needs no VPN permission and listens on local port 1053 for LAN devices. Rules and logs stay on the device. Please understand the impact before enabling advanced extensions.\n\nDisclaimer\nThis software is provided as is. Users must comply with applicable laws and verify the legality and safety of the rules and upstream resolvers they configure. Any illegal use is strictly forbidden, and users bear all consequences of their own configuration or use of this software.';

  @override
  String get homeProviderSingleLabel => 'Resolver';

  @override
  String get homeProviderRaceLabel => 'Racing resolvers';

  @override
  String get homeChartEmptyLabel => 'No samples yet';

  @override
  String durationHours(Object hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String durationSeconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String get dashboardDetailTooltip => 'Details';

  @override
  String get dashboardEmptyLabel => 'No dashboard cards yet';

  @override
  String get dashboardEmptyDescription =>
      'Enter edit mode and pick a few cards from \"Add card\".';

  @override
  String get dashboardEnterEditMode => 'Enter edit mode';

  @override
  String get dashboardEditHint =>
      'Drag the handle to reorder, tap the top-right corner to remove; tap \"Done\" when finished.';

  @override
  String get dashboardAllRemovedLabel => 'All cards removed';

  @override
  String get dashboardAllRemovedDescription =>
      'Tap \"Add card\" below to pick one.';

  @override
  String get dashboardAddCard => 'Add card';

  @override
  String get providerSheetSingleTitle => 'Choose a resolver';

  @override
  String get providerSheetRaceTitle => 'Choose racing resolvers';

  @override
  String get providerSheetSingleOptions => 'Available resolvers';

  @override
  String get providerSheetRaceMinimum => 'Pick at least 2';

  @override
  String get providerSheetManage => 'Manage resolvers...';

  @override
  String get providerSheetVisibility => 'Resolver visibility...';

  @override
  String get providerSheetSingleFooter =>
      'Latency comes from the last resolution health record, not a live measurement.';

  @override
  String get providerSheetRaceFooter =>
      'In racing mode every query is sent to all selected resolvers concurrently.';

  @override
  String get powerButtonStop => 'Stop';

  @override
  String get powerButtonStart => 'Start';

  @override
  String get powerButtonStarting => 'Starting';

  @override
  String get homeEditDashboard => 'Edit dashboard';

  @override
  String get homeDone => 'Done';

  @override
  String get homeSwitchWorkMode => 'Switch work mode';

  @override
  String get homeTitleNormal => 'DITING · Normal';

  @override
  String get homeTitleServer => 'DITING · Server';

  @override
  String get homeTitleExpress => 'DITING · Express';

  @override
  String get logRequestsOverview => 'Request overview';

  @override
  String get logTodayRequests => 'Requests today';

  @override
  String get logPassed => 'Passed';

  @override
  String get logFiltered => 'Filtered';

  @override
  String get logCacheHits => 'Cache hits';

  @override
  String get logHighlights => 'Key records';

  @override
  String get logBlocked => 'Blocked';

  @override
  String get logFailed => 'Failed';

  @override
  String get logBypassed => 'Bypassed';

  @override
  String get logOffModeTitle => 'Resolution overview';

  @override
  String get logCacheEntries => 'Live cache entries';

  @override
  String get logCacheHitsTotal => 'Total cache hits';

  @override
  String get logRaceRequests => 'Concurrent race queries';

  @override
  String get logBootstrapAttempts => 'Bootstrap attempts';

  @override
  String get logRecentRequests => 'Recent requests';

  @override
  String get logRecentRequestsEmpty => 'No requests yet';

  @override
  String get logRecentBlocked => 'Recent blocks and errors';

  @override
  String get logRecentBlockedEmpty => 'No blocks or errors yet';

  @override
  String get logCacheHotspots => 'Cache hotspots';

  @override
  String get logCacheHotspotsEmpty => 'No live cache entries';

  @override
  String logExpiresIn(Object duration) {
    return 'expires in $duration';
  }

  @override
  String logTimes(Object count) {
    return '$count times';
  }

  @override
  String get logRaceWinners => 'Race winners';

  @override
  String get logRaceWinnersEmpty => 'No race data yet';

  @override
  String logAverageWinLatency(Object latency) {
    return 'Won in $latency on average';
  }

  @override
  String get logBootstrapDnsEmpty => 'No Bootstrap data yet';

  @override
  String logBootstrapRow(Object ip, Object latency, Object percent) {
    return '$ip · $percent success · $latency';
  }

  @override
  String get logRuleBlocks => 'Rule blocks';

  @override
  String get logRuleBlocksEmpty => 'No rule blocks yet';

  @override
  String logShareRow(Object percent, Object status) {
    return '$status · $percent of all requests';
  }

  @override
  String get logPrivacyMode => 'Privacy mode is on';

  @override
  String get logLoggingOff => 'Logging off';

  @override
  String get logPrivacyModeBody =>
      'After logging is turned back on the dashboard counts from the requests recorded from then on. Resolution services and cache hotspots keep working meanwhile.';

  @override
  String get logPerfTitle => 'Resolution performance';

  @override
  String get logTodayStats => 'Today';

  @override
  String get logAverageLatency => 'Average resolution time';

  @override
  String get logNoTimingSamples => '— · No timing samples today';

  @override
  String logSampleValue(Object count, Object value) {
    return '$value · $count samples';
  }

  @override
  String get logCacheHitRate => 'Cache hit rate';

  @override
  String logCacheHitRateValue(Object percent) {
    return '$percent · denominator is passed + failed';
  }

  @override
  String get logRaceSuccessRate => 'Race success rate';

  @override
  String get logBootstrapSuccessRate => 'Bootstrap success rate';

  @override
  String logRateValue(Object count, Object latency, Object percent) {
    return '$percent · $count times · $latency';
  }

  @override
  String get dashboardRestoreDefaults => 'Restore defaults';

  @override
  String get dashboardAllCardsAdded => 'All cards are on the dashboard';

  @override
  String get dashboardAllCardsAddedDescription =>
      'To remove one, go back to edit mode and tap the remove button in its top-right corner.';

  @override
  String get dashboardAvailableCards => 'Available cards';

  @override
  String get dashboardOrderHint =>
      'Drag cards in edit mode to change their order.';

  @override
  String get dashboardCardProviderDescription =>
      'The active resolver; open it to switch or adjust the racing list';

  @override
  String get dashboardCardResolutionDescription =>
      'Resolution mode, a one-line summary and the DNS address in effect';

  @override
  String get dashboardCardStatusDescription =>
      'Core state, uptime, active resolver and today\'s queries';

  @override
  String get dashboardCardSpeedDescription =>
      'Live up/down rate curves and today\'s total traffic';

  @override
  String get dashboardCardSiteLatencyDescription =>
      'Measured latency of four custom sites; the detail page tests each category';

  @override
  String get dashboardCardMemoryDescription =>
      'This process\'s PSS split into Java and native heap';

  @override
  String get dashboardCardIntranetDescription =>
      'Current LAN address, listening state and a copy action';

  @override
  String get intranetIpTitle => 'LAN IP';

  @override
  String get intranetCopyAddress => 'Copy address';

  @override
  String get intranetReading => 'Reading…';

  @override
  String get intranetNoActiveNetwork => 'No active network';

  @override
  String get intranetLanAccess => 'LAN access';

  @override
  String get intranetConnectHint =>
      'Connect to Wi-Fi or Ethernet to see a usable address here';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryJavaHeap => 'Java heap';

  @override
  String get memoryNativeHeap => 'Native heap';

  @override
  String get memorySystemAvailable => 'System available';

  @override
  String get speedTitle => 'Network speed';

  @override
  String get speedUpload => 'Upload';

  @override
  String get speedDownload => 'Download';

  @override
  String get speedExpressNoStats => 'Not measured in express mode';

  @override
  String get speedNoChannel => 'No rate channel in this environment';

  @override
  String get resolutionModeTitle => 'Resolution mode';

  @override
  String get resolutionNoProvider => 'No resolver selected';

  @override
  String get resolutionSingleSummary =>
      'Uses only the selected resolver: fastest, but availability depends on it.';

  @override
  String get resolutionSmartSummary =>
      'Picks one by historical success rate and falls back to the next on failure.';

  @override
  String get resolutionParallelSummary =>
      'Asks every resolver at once and takes the first answer.';

  @override
  String get resolutionPrimaryBackupSummary =>
      'Primary first, backups only after a timeout.';

  @override
  String get siteLatencyTesting => 'Testing…';

  @override
  String get siteLatencyNotTested => 'Not tested yet';

  @override
  String get siteLatencyTitle => 'Site latency';

  @override
  String get siteLatencyRetest => 'Test again';

  @override
  String get commonFailed => 'Failed';

  @override
  String get siteLatencyNoReply => 'No reply';

  @override
  String get statusTitle => 'Status';

  @override
  String get statusUptime => 'Uptime';

  @override
  String get statusActiveProvider => 'Active resolver';

  @override
  String get statusNotSelected => 'None';

  @override
  String get statusTodayQueries => 'Queries today';

  @override
  String get statusDetailTitle => 'Status details';

  @override
  String get statusNotTiming => 'Not counting';

  @override
  String get statusCoreSection => 'Core';

  @override
  String get statusWorkMode => 'Work mode';

  @override
  String get statusCoreState => 'Core state';

  @override
  String get statusListenPort => 'Listening port';

  @override
  String get statusNotListening => 'Not listening';

  @override
  String get statusProviderFooter =>
      'Latency is the resolver\'s last measured value, not this device\'s round trip to the target.';

  @override
  String get statusNoProviderHint =>
      'No resolver selected yet. Pick one in resolver management so resolution uses a real upstream.';

  @override
  String get statusTodayCounts => 'Today\'s counts';

  @override
  String get statusCountsFooter =>
      'Counts accumulate from this core start and reset when it restarts or the work mode changes; the reset in server mode clears only the counts, never rules or cache.';

  @override
  String get statusQueries => 'Queries';

  @override
  String get statusBlocked => 'Blocked';

  @override
  String get statusAverageLatency => 'Average latency';

  @override
  String get statusCacheHitRate => 'Cache hit rate';

  @override
  String get statusServerPortReady =>
      'The local DNS port is available; LAN devices can use it as their DNS';

  @override
  String get statusTunnelActive =>
      'This device\'s traffic goes through DITING, so resolution and rules are in effect';

  @override
  String get statusServerPortClosed =>
      'The DNS port is not listening, so server mode is not serving resolution';

  @override
  String get statusCoreStopped =>
      'The core is not running, so this device uses the system\'s default network';

  @override
  String get siteLatencySheetLatency => 'Latency';

  @override
  String get siteLatencySheetCategory => 'Category';

  @override
  String get siteLatencySheetTarget => 'Target';

  @override
  String get siteLatencySheetAverage => 'Average RTT';

  @override
  String get siteLatencySheetMinMax => 'Min / max';

  @override
  String get siteLatencySheetJitter => 'Jitter';

  @override
  String get siteLatencySheetLoss => 'Loss';

  @override
  String get siteLatencySheetDns => 'Resolved address';

  @override
  String get siteLatencySheetLastRun => 'Last test';

  @override
  String get siteLatencySheetNotTested =>
      'Not tested yet. Tap the test button to start.';

  @override
  String get siteLatencySheetNoReply =>
      'None of the three echo requests was answered: the site may be rate limiting or the network is down.';

  @override
  String get siteLatencySheetFallbackFooter =>
      'System ping is unavailable, so these numbers come from the TCP handshake / isReachable: they measure connection setup, not ICMP echo, and read slightly higher than the real round trip.';

  @override
  String get siteLatencySheetIcmpFooter =>
      'Numbers come from ICMP echo via system ping (average of three). This app\'s own traffic bypasses the VPN, so the physical network is measured.';

  @override
  String get trafficStructureLive => 'Live summary';

  @override
  String get trafficStructureFocused => 'Key traffic structure';

  @override
  String get trafficStructureToday => 'Today\'s traffic structure';

  @override
  String get trafficStructureBypass => 'Bypass';

  @override
  String get trafficStructureCache => 'Cache';

  @override
  String get trafficStructureRaceRate => 'Race success rate';

  @override
  String get trafficStructureBootstrapRate => 'Bootstrap success rate';

  @override
  String get trafficStructureBlockedShare => 'Blocked share';

  @override
  String get trafficStructureBlockRate => 'Block rate';

  @override
  String get trafficStructureCacheRate => 'Cache rate';

  @override
  String get dashboardSitesTitle => 'Dashboard sites';

  @override
  String get dashboardSitesCardSection => 'Dashboard card';

  @override
  String get dashboardSitesAtLeastOne => 'Keep at least one site on the card';

  @override
  String get dashboardSitesFooter =>
      'These four cards share one dashboard card, so changes apply immediately; tests run per category from the detail page.';

  @override
  String get trafficMonitorTitle => 'Traffic monitor';

  @override
  String get trafficMonitorToday => 'Proxy traffic today';

  @override
  String get trafficMonitorLiveRate => 'Live rate';

  @override
  String get trafficMonitorNoStats => 'Not measured in this mode';

  @override
  String get memoryDetailTitle => 'Memory details';

  @override
  String get memoryResample => 'Resample';

  @override
  String get memoryProcessPss => 'This process PSS';

  @override
  String get memoryUnavailable => 'Unavailable';

  @override
  String get memoryOther => 'Other';

  @override
  String get memoryComposition => 'Process composition';

  @override
  String get memoryCompositionFooter =>
      'PSS counts shared pages proportionally, so the Java and native heaps add up to less than the PSS; the remainder is code, graphics buffers and shared libraries.';

  @override
  String get memoryOtherCode => 'Other (code / shared libraries)';

  @override
  String get memorySystemSection => 'System memory';

  @override
  String get memorySystemFooter =>
      'System usage = total - available, covering the system and every app; this process is only one part of it.';

  @override
  String get memorySystemUsed => 'System used';

  @override
  String get memoryRecentPss => 'Recent PSS';

  @override
  String get memorySampling => 'Sampling…';

  @override
  String get memoryRecentPssCaption =>
      'This page samples every 2 seconds and keeps at most 60 points; a curve that keeps climbing means memory is not being released.';

  @override
  String get memorySourceFooter =>
      'Data comes from ActivityManager\'s MemoryInfo; the numbers drop noticeably after the app is backgrounded or the system reclaims memory.';

  @override
  String get siteLatencyDetailTitle => 'Latency details';

  @override
  String get siteLatencyTestAll => 'Test all';

  @override
  String get siteLatencyCustomSites => 'Custom dashboard sites';

  @override
  String get siteLatencyConnectivity => 'Site connectivity';

  @override
  String get siteLatencyTestingShort => 'Testing';

  @override
  String get siteLatencyNoTest => 'Not tested';

  @override
  String get siteLatencyInProgress => 'In progress';

  @override
  String get siteLatencyPending => 'Pending';

  @override
  String get siteLatencyAllReachable => 'All reachable';

  @override
  String get siteLatencyTestingEach => 'Testing the sites one by one…';

  @override
  String get siteLatencyPickCategory =>
      'Pick a category and start a test, or tap the top-right corner to test everything.';

  @override
  String get siteLatencyThisRun => 'This run';

  @override
  String get siteLatencyReachable => 'Reachable';

  @override
  String get siteLatencyMeasuredSites => 'Sites tested';

  @override
  String get siteLatencyDetailFooter =>
      'Each site gets three ICMP echo requests and the average is used; when system ping is unavailable the TCP handshake is used instead, marked with *, and reads slightly higher than the real round trip. This app\'s own traffic bypasses the VPN, so the physical network is measured.';

  @override
  String get intranetDetailTitle => 'LAN IP details';

  @override
  String get intranetRefresh => 'Refresh network info';

  @override
  String get intranetLocalAddress => 'Local LAN address';

  @override
  String get intranetUsableAsDns => 'Usable as DNS';

  @override
  String get intranetLocalOnly => 'Local only';

  @override
  String get intranetSameSubnetHint =>
      'Point devices on the same subnet at this address to use local resolution.';

  @override
  String get intranetNetworkOverview => 'Network overview';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get intranetDnsServers => 'DNS servers';

  @override
  String get intranetInterfaces => 'Interfaces';

  @override
  String get intranetNoInterface =>
      'The system reports no active network interface: airplane mode may be on or there is no connection.';

  @override
  String get intranetAdapter => 'Adapter';

  @override
  String get intranetGateway => 'Gateway';

  @override
  String get intranetPrivateDnsOff =>
      'System Private DNS is off, so requests are handled locally and by the proxy according to the mode.';

  @override
  String get intranetNoDnsServer =>
      'No DNS server was read: the interface provides none, or there is no diagnostic channel here.';

  @override
  String get intranetPrimaryDns => 'Primary';

  @override
  String get intranetPrivateDns => 'Private DNS';

  @override
  String get intranetPortFooter =>
      'The port is bound only when the service starts, so restart it after changing the port; point devices on the same subnet at the address above to use local resolution.';

  @override
  String get intranetCopyAddressWithPort => 'Copy address (with port)';

  @override
  String get speedDetailTitle => 'Speed details';

  @override
  String get speedCurrentDownload => 'Current download';

  @override
  String get speedSamplingPaused => 'Sampling paused';

  @override
  String get speedLive => 'Live';

  @override
  String get speedSamplingHint =>
      'Sampled once per second; the chart shows the last minute.';

  @override
  String get speedCurrentUpload => 'Current upload';

  @override
  String get speedDownloadPeak => 'Download peak';

  @override
  String get speedUploadPeak => 'Upload peak';

  @override
  String get speedSamples => 'Samples';

  @override
  String get speedTodayTotal => 'Today\'s total';

  @override
  String get speedNoTrafficToday =>
      'The traffic store has no records for today yet.';

  @override
  String get speedTotal => 'Total';

  @override
  String get speedRateFooter =>
      'Rates come from the core data plane\'s live counters and cover only tunneled traffic; this app\'s own probes and speed tests are excluded. Today\'s totals come from the app traffic statistics, the same data as the Traffic page.';

  @override
  String get speedExpressSource =>
      'Express mode bypasses the core data plane, so there is no per-second rate; switch back to normal mode to restore it.';

  @override
  String get speedNoChannelSource =>
      'This environment has no rate channel (desktop or pure Dart tests), so no live rate can be read.';

  @override
  String get speedNoDataInMode => 'No rate data in this mode';

  @override
  String get speedWaitingSample => 'Waiting for the first sample';

  @override
  String get commonNoData => 'No data';

  @override
  String intranetModeNotListening(Object mode) {
    return '$mode does not listen on the LAN, so other devices cannot use this as their DNS';
  }

  @override
  String intranetListeningOn(Object port) {
    return 'Listening on 0.0.0.0:$port; point other devices\' DNS at the address above';
  }

  @override
  String intranetServiceStopped(Object port) {
    return 'Service not started: port $port is bound once it starts';
  }

  @override
  String commonCopied(Object text) {
    return 'Copied $text';
  }

  @override
  String intranetGatewaySuffix(Object gateway) {
    return ' · Gateway $gateway';
  }

  @override
  String get speedTotalDash => 'Total —';

  @override
  String siteLatencyAliveRatio(Object alive, Object total) {
    return '$alive / $total reachable';
  }

  @override
  String siteLatencyLastRun(Object ago) {
    return 'Last test $ago';
  }

  @override
  String siteLatencyProviderSuffix(Object name) {
    return ' · Resolver $name';
  }

  @override
  String siteLatencySitesCount(Object count) {
    return '$count sites';
  }

  @override
  String siteLatencyTestCategory(Object category) {
    return 'Test $category';
  }

  @override
  String memorySystemShare(Object percent) {
    return '$percent of the system';
  }

  @override
  String memorySystemUsedOf(Object total, Object used) {
    return 'System used $used / $total';
  }

  @override
  String get memoryNoChannel =>
      'Memory data is unavailable here (desktop or pure Dart tests).';

  @override
  String trafficStructureRateValue(
    Object count,
    Object latency,
    Object percent,
  ) {
    return '$percent · $count times · $latency';
  }

  @override
  String trafficStructureShareValue(Object count, Object percent) {
    return '$percent · $count times';
  }

  @override
  String statusPausedSummary(Object core, Object mode) {
    return '$mode $core, timing paused';
  }

  @override
  String speedTotalsDown(Object percent) {
    return 'Down $percent';
  }

  @override
  String speedTotalsUp(Object percent) {
    return 'Up $percent';
  }

  @override
  String speedPeakAverage(Object average, Object peak) {
    return 'Peak $peak · Average $average';
  }

  @override
  String get intranetConnectHintSentence =>
      'Connect to Wi-Fi or Ethernet to see a usable address here.';

  @override
  String intranetModeNotListeningSentence(Object mode) {
    return '$mode does not listen on the LAN, so other devices cannot use this as their DNS.';
  }

  @override
  String intranetPrivateDnsOn(Object dns) {
    return 'System Private DNS is on ($dns); system lookups use an encrypted channel and may bypass the local service.';
  }

  @override
  String intranetSecondaryDns(Object index) {
    return 'Secondary $index';
  }

  @override
  String intranetCopyAddressSemantics(Object address) {
    return 'Copy address $address';
  }

  @override
  String speedTotalAccumulated(Object value) {
    return 'Total $value';
  }

  @override
  String dashboardSitesFull(Object count) {
    return 'The card holds $count sites; turn one off before adding another.';
  }

  @override
  String dashboardSitesRemaining(Object count) {
    return 'You can add $count more sites.';
  }

  @override
  String dashboardSitesMax(Object count) {
    return 'The card holds at most $count sites; deselect one first.';
  }

  @override
  String dashboardSitesPosition(Object index) {
    return 'Position $index';
  }

  @override
  String siteLatencyFailedCount(Object count) {
    return '$count failed';
  }

  @override
  String get siteLatencyDetailFooterLong =>
      'Each site gets three ICMP echo requests and the average is used; when system ping is unavailable the TCP handshake is used instead, marked with *, and reads slightly higher than the real round trip. This app\'s own traffic bypasses the VPN, so the physical network is measured.';
}
