import re


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b)
    open(path, 'w', encoding='utf-8').write(s)


# --- CleanupAction -------------------------------------------------------------------------
s = open('lib/data/cleanup/cleanup_models.dart', encoding='utf-8').read()
s = re.sub(r'enum CleanupAction \{.*?\n  final String title;\n', """enum CleanupAction {
  logs,
  traffic,
  crash,
  dnsCache,
  providerWeights,
  bootstrapWeights,
  domainRules,
  addressRules,
  subscriptions,
  appRules,
  outboundProxy,
  caCertificate,
  downloadCache,
  customBackground,
  settingsGuides,
  allData;

  String title(AppL10n l10n) => switch (this) {
    CleanupAction.logs => l10n.cleanupLogs,
    CleanupAction.traffic => l10n.cleanupTraffic,
    CleanupAction.crash => l10n.cleanupCrash,
    CleanupAction.dnsCache => l10n.cleanupDnsCache,
    CleanupAction.providerWeights => l10n.cleanupProviderWeights,
    CleanupAction.bootstrapWeights => l10n.cleanupBootstrapWeights,
    CleanupAction.domainRules => l10n.cleanupDomainRules,
    CleanupAction.addressRules => l10n.cleanupAddressRules,
    CleanupAction.subscriptions => l10n.cleanupSubscriptions,
    CleanupAction.appRules => l10n.cleanupAppRules,
    CleanupAction.outboundProxy => l10n.cleanupOutboundProxy,
    CleanupAction.caCertificate => l10n.cleanupCaCertificate,
    CleanupAction.downloadCache => l10n.cleanupDownloadCache,
    CleanupAction.customBackground => l10n.cleanupCustomBackground,
    CleanupAction.settingsGuides => l10n.cleanupSettingsGuides,
    CleanupAction.allData => l10n.cleanupAllData,
  };
""", s, flags=re.S)
s = s.replace("      return '已${action.title}：$removed 项$suffix';",
              "      return currentL10n.cleanupDoneItems(action.title(currentL10n), removed, suffix);")
s = s.replace("    return detail ?? '已${action.title}：没有可清理的数据';",
              "    return detail ??\n        currentL10n.cleanupDoneEmpty(action.title(currentL10n));")
open('lib/data/cleanup/cleanup_models.dart', 'w', encoding='utf-8').write(s)

# --- Subscription models -------------------------------------------------------------------
s = open('lib/data/db/subscription_models.dart', encoding='utf-8').read()
s = re.sub(r'enum SubscriptionSourceType \{.*?\n  final String label;\n', """enum SubscriptionSourceType {
  remote('remote'),
  local('local');

  const SubscriptionSourceType(this.storageValue);

  final String storageValue;

  String label(AppL10n l10n) => switch (this) {
    SubscriptionSourceType.remote => l10n.subscriptionSourceRemote,
    SubscriptionSourceType.local => l10n.subscriptionSourceLocal,
  };
""", s, flags=re.S)
s = re.sub(r'enum SubscriptionKind \{.*?\n  final String displayName;\n', """enum SubscriptionKind {
  domain('domain'),
  hosts('hosts');

  const SubscriptionKind(this.storageValue);

  final String storageValue;

  String displayName(AppL10n l10n) => switch (this) {
    SubscriptionKind.domain => l10n.subscriptionKindDomain,
    SubscriptionKind.hosts => l10n.subscriptionKindHosts,
  };
""", s, flags=re.S)
open('lib/data/db/subscription_models.dart', 'w', encoding='utf-8').write(s)

# --- Block response modes ------------------------------------------------------------------
s = open('lib/data/vpn/block_response_settings.dart', encoding='utf-8').read()
s = re.sub(r'enum BlockResponseMode \{.*?\n  final String description;\n', """enum BlockResponseMode {
  nxdomain('nxdomain'),
  nodata('nodata'),
  refused('refused'),
  zeroAddress('zero_address');

  const BlockResponseMode(this.storageValue);

  final String storageValue;

  String label(AppL10n l10n) => switch (this) {
    BlockResponseMode.nxdomain => l10n.blockResponseNxdomain,
    BlockResponseMode.nodata => l10n.blockResponseNodata,
    BlockResponseMode.refused => l10n.blockResponseRefused,
    BlockResponseMode.zeroAddress => l10n.blockResponseZeroAddress,
  };

  String description(AppL10n l10n) => switch (this) {
    BlockResponseMode.nxdomain => l10n.blockResponseNxdomainDescription,
    BlockResponseMode.nodata => l10n.blockResponseNodataDescription,
    BlockResponseMode.refused => l10n.blockResponseRefusedDescription,
    BlockResponseMode.zeroAddress => l10n.blockResponseZeroAddressDescription,
  };
""", s, flags=re.S)
open('lib/data/vpn/block_response_settings.dart', 'w', encoding='utf-8').write(s)

# --- Cache presets -------------------------------------------------------------------------
s = open('lib/data/vpn/cache_presets.dart', encoding='utf-8').read()
s = s.replace("    currentL10n.cachePresetConservativeName,\n"
              "    currentL10n.cachePresetConservativeSummary,\n"
              "    currentL10n.cachePresetConservativeDescription,\n", "")
s = s.replace("    currentL10n.cachePresetStandardName,\n"
              "    currentL10n.cachePresetStandardSummary,\n"
              "    currentL10n.cachePresetStandardDescription,\n", "")
s = s.replace("    currentL10n.cachePresetAggressiveName,\n"
              "    currentL10n.cachePresetAggressiveSummary,\n"
              "    currentL10n.cachePresetAggressiveDescription,\n", "")
s = s.replace("""  const DnsCachePreset(
    this.label,
    this.summary,
    this.description, {""", """  const DnsCachePreset({""")
s = s.replace("""  final String label;
  final String summary;
  final String description;
""", """  String label(AppL10n l10n) => switch (this) {
    DnsCachePreset.conservative => l10n.cachePresetConservativeName,
    DnsCachePreset.balanced => l10n.cachePresetStandardName,
    DnsCachePreset.highHitRate => l10n.cachePresetAggressiveName,
  };

  String summary(AppL10n l10n) => switch (this) {
    DnsCachePreset.conservative => l10n.cachePresetConservativeSummary,
    DnsCachePreset.balanced => l10n.cachePresetStandardSummary,
    DnsCachePreset.highHitRate => l10n.cachePresetAggressiveSummary,
  };

  String description(AppL10n l10n) => switch (this) {
    DnsCachePreset.conservative => l10n.cachePresetConservativeDescription,
    DnsCachePreset.balanced => l10n.cachePresetStandardDescription,
    DnsCachePreset.highHitRate => l10n.cachePresetAggressiveDescription,
  };
""")
s = s.replace("  return '${preset.label} · ${preset.summary}';",
              "  return '${preset.label(currentL10n)} · ${preset.summary(currentL10n)}';")
open('lib/data/vpn/cache_presets.dart', 'w', encoding='utf-8').write(s)

# --- Server presets ------------------------------------------------------------------------
s = open('lib/data/server/dns_server_config.dart', encoding='utf-8').read()
s = s.replace('const serverPresetUpstreams = <ServerUpstream>[',
              'List<ServerUpstream> serverPresetUpstreams(AppL10n l10n) => <ServerUpstream>[')
s = s.replace('    name: currentL10n.upstreamPresetAliyun,', '    name: l10n.upstreamPresetAliyun,')
s = s.replace('    name: currentL10n.upstreamPresetTencent,', '    name: l10n.upstreamPresetTencent,')
s = s.replace('      serverPresetUpstreams.first;', '      serverPresetUpstreams(currentL10n).first;')
s = s.replace('  ...serverPresetUpstreams,', '  ...serverPresetUpstreams(currentL10n),')
open('lib/data/server/dns_server_config.dart', 'w', encoding='utf-8').write(s)
print('ok')
