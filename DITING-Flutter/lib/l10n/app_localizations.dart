import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'谛听 DITING'**
  String get appTitle;

  /// No description provided for @uiBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get uiBack;

  /// No description provided for @uiCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get uiCancel;

  /// No description provided for @uiClearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get uiClearSearch;

  /// No description provided for @uiClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get uiClose;

  /// No description provided for @uiHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get uiHidePassword;

  /// No description provided for @uiMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get uiMore;

  /// No description provided for @uiNoSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'无搜索结果'**
  String get uiNoSearchResults;

  /// No description provided for @uiReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get uiReset;

  /// No description provided for @uiSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get uiSearch;

  /// No description provided for @uiShowLess.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get uiShowLess;

  /// No description provided for @uiShowMore.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get uiShowMore;

  /// No description provided for @uiShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get uiShowPassword;

  /// No description provided for @uiSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get uiSort;

  /// No description provided for @uiSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get uiSubmit;

  /// No description provided for @languageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get languageTitle;

  /// No description provided for @languageInterfaceSection.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get languageInterfaceSection;

  /// No description provided for @languageInterfaceFooter.
  ///
  /// In zh, this message translates to:
  /// **'选择应用界面语言。「跟随系统」会跟随设备语言，非中文或英文的系统显示中文。'**
  String get languageInterfaceFooter;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @commonFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get commonFollowSystem;

  /// No description provided for @commonSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get commonSelectAll;

  /// No description provided for @commonClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get commonClear;

  /// No description provided for @commonInvertSelection.
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get commonInvertSelection;

  /// No description provided for @commonFilter.
  ///
  /// In zh, this message translates to:
  /// **'过滤'**
  String get commonFilter;

  /// No description provided for @commonSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get commonSort;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDiscard.
  ///
  /// In zh, this message translates to:
  /// **'不保存'**
  String get commonDiscard;

  /// No description provided for @commonSaveChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存更改？'**
  String get commonSaveChangesTitle;

  /// No description provided for @commonSaveChangesMessage.
  ///
  /// In zh, this message translates to:
  /// **'你的选择还没保存。保存后离开，还是放弃这些修改？'**
  String get commonSaveChangesMessage;

  /// No description provided for @commonSaveChangesMessageFor.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」的选择还没保存。保存后离开，还是放弃这些修改？'**
  String commonSaveChangesMessageFor(Object name);

  /// No description provided for @commonGrantPermission.
  ///
  /// In zh, this message translates to:
  /// **'去授权'**
  String get commonGrantPermission;

  /// No description provided for @palettePurple.
  ///
  /// In zh, this message translates to:
  /// **'鸢尾紫'**
  String get palettePurple;

  /// No description provided for @paletteBlue.
  ///
  /// In zh, this message translates to:
  /// **'睡莲蓝'**
  String get paletteBlue;

  /// No description provided for @paletteCyan.
  ///
  /// In zh, this message translates to:
  /// **'池水青'**
  String get paletteCyan;

  /// No description provided for @paletteGreen.
  ///
  /// In zh, this message translates to:
  /// **'柳叶绿'**
  String get paletteGreen;

  /// No description provided for @paletteOrange.
  ///
  /// In zh, this message translates to:
  /// **'暮光赭'**
  String get paletteOrange;

  /// No description provided for @paletteRed.
  ///
  /// In zh, this message translates to:
  /// **'罂粟红'**
  String get paletteRed;

  /// No description provided for @palettePink.
  ///
  /// In zh, this message translates to:
  /// **'暮霞粉'**
  String get palettePink;

  /// No description provided for @paletteGold.
  ///
  /// In zh, this message translates to:
  /// **'麦穗金'**
  String get paletteGold;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get themeModeDark;

  /// No description provided for @appListUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'读不到应用列表'**
  String get appListUnavailable;

  /// No description provided for @appListFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部应用'**
  String get appListFilterAll;

  /// No description provided for @appListFilterSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统应用'**
  String get appListFilterSystem;

  /// No description provided for @appListFilterUser.
  ///
  /// In zh, this message translates to:
  /// **'用户应用'**
  String get appListFilterUser;

  /// No description provided for @appListFilterSelected.
  ///
  /// In zh, this message translates to:
  /// **'已勾选应用'**
  String get appListFilterSelected;

  /// No description provided for @appListSortLabelAsc.
  ///
  /// In zh, this message translates to:
  /// **'应用名称 A-Z'**
  String get appListSortLabelAsc;

  /// No description provided for @appListSortLabelDesc.
  ///
  /// In zh, this message translates to:
  /// **'应用名称 Z-A'**
  String get appListSortLabelDesc;

  /// No description provided for @appListSortPackageAsc.
  ///
  /// In zh, this message translates to:
  /// **'包名 A-Z'**
  String get appListSortPackageAsc;

  /// No description provided for @appListSortPackageDesc.
  ///
  /// In zh, this message translates to:
  /// **'包名 Z-A'**
  String get appListSortPackageDesc;

  /// No description provided for @appListNotRegistered.
  ///
  /// In zh, this message translates to:
  /// **'未注册'**
  String get appListNotRegistered;

  /// No description provided for @appListChannelUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'应用列表通道不可用：{detail}'**
  String appListChannelUnavailable(Object detail);

  /// No description provided for @appListReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取应用列表失败：{detail}'**
  String appListReadFailed(Object detail);

  /// No description provided for @appListReadFailedCode.
  ///
  /// In zh, this message translates to:
  /// **'读取应用列表失败（{code}）'**
  String appListReadFailedCode(Object code);

  /// No description provided for @dbWriteUnhealthy.
  ///
  /// In zh, this message translates to:
  /// **'日志写入异常：已丢弃 {dropped} 条、打开失败 {failures} 次，可在「故障排查」查看详情'**
  String dbWriteUnhealthy(Object dropped, Object failures);

  /// No description provided for @agreementDeclinedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝使用须知'**
  String get agreementDeclinedTitle;

  /// No description provided for @agreementDeclinedMessage.
  ///
  /// In zh, this message translates to:
  /// **'未同意使用须知与免责声明，无法继续使用谛听。你可以直接退出应用，或重新查看条款后再决定。'**
  String get agreementDeclinedMessage;

  /// No description provided for @agreementReviewAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新查看'**
  String get agreementReviewAgain;

  /// No description provided for @agreementTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用须知与免责声明'**
  String get agreementTitle;

  /// No description provided for @agreementDecline.
  ///
  /// In zh, this message translates to:
  /// **'不同意并退出'**
  String get agreementDecline;

  /// No description provided for @agreementAccept.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get agreementAccept;

  /// No description provided for @agreementMessage.
  ///
  /// In zh, this message translates to:
  /// **'软件说明\n谛听是一款专注于本地 DNS 解析优化与网络规则过滤的开源工具。提供三种工作模式：普通模式（全隧道深度管控）、极速模式（纯 Kotlin 原生轻量窄路由）与独立服务器模式（局域网免 VPN 服务）。本软件完全在设备本地闭环运行，无任何远程数据上传与隐私追踪。\n\n运行机制与注意事项\n普通模式与极速模式依赖 Android 本地 VPN 接口接管 DNS 解析，不连接任何远程 VPN 服务器；独立服务器模式无需 VPN 权限，直接监听本地 1053 端口供局域网设备接入。规则与日志完整保存在本机，启用高级扩展功能前请了解其具体影响。\n\n免责条款\n本软件按现状提供。使用者须遵守相关法律法规，自行确认规则与上游解析来源的合法性及安全性。严禁将本软件用于任何违法用途；使用者因自行配置或使用本软件所产生的后果由使用者自行承担。'**
  String get agreementMessage;

  /// No description provided for @homeProviderSingleLabel.
  ///
  /// In zh, this message translates to:
  /// **'解析服务商'**
  String get homeProviderSingleLabel;

  /// No description provided for @homeProviderRaceLabel.
  ///
  /// In zh, this message translates to:
  /// **'竞速服务商'**
  String get homeProviderRaceLabel;

  /// No description provided for @homeChartEmptyLabel.
  ///
  /// In zh, this message translates to:
  /// **'还没有采到样本'**
  String get homeChartEmptyLabel;

  /// No description provided for @durationHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时'**
  String durationHours(Object hours);

  /// No description provided for @durationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String durationMinutes(Object minutes);

  /// No description provided for @durationSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String durationSeconds(Object seconds);

  /// No description provided for @dashboardDetailTooltip.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get dashboardDetailTooltip;

  /// No description provided for @dashboardEmptyLabel.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘还没有卡片'**
  String get dashboardEmptyLabel;

  /// No description provided for @dashboardEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入编辑模式，从「添加卡片」里挑几个放上来。'**
  String get dashboardEmptyDescription;

  /// No description provided for @dashboardEnterEditMode.
  ///
  /// In zh, this message translates to:
  /// **'进入编辑模式'**
  String get dashboardEnterEditMode;

  /// No description provided for @dashboardEditHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动手柄排序，点右上角移除；改完点右上角「完成」。'**
  String get dashboardEditHint;

  /// No description provided for @dashboardAllRemovedLabel.
  ///
  /// In zh, this message translates to:
  /// **'卡片都移除了'**
  String get dashboardAllRemovedLabel;

  /// No description provided for @dashboardAllRemovedDescription.
  ///
  /// In zh, this message translates to:
  /// **'点下面的「添加卡片」挑一个。'**
  String get dashboardAllRemovedDescription;

  /// No description provided for @dashboardAddCard.
  ///
  /// In zh, this message translates to:
  /// **'添加卡片'**
  String get dashboardAddCard;

  /// No description provided for @providerSheetSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择解析服务商'**
  String get providerSheetSingleTitle;

  /// No description provided for @providerSheetRaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择竞速服务商'**
  String get providerSheetRaceTitle;

  /// No description provided for @providerSheetSingleOptions.
  ///
  /// In zh, this message translates to:
  /// **'可选服务商'**
  String get providerSheetSingleOptions;

  /// No description provided for @providerSheetRaceMinimum.
  ///
  /// In zh, this message translates to:
  /// **'至少选 2 个'**
  String get providerSheetRaceMinimum;

  /// No description provided for @providerSheetManage.
  ///
  /// In zh, this message translates to:
  /// **'管理服务...'**
  String get providerSheetManage;

  /// No description provided for @providerSheetVisibility.
  ///
  /// In zh, this message translates to:
  /// **'服务显示...'**
  String get providerSheetVisibility;

  /// No description provided for @providerSheetSingleFooter.
  ///
  /// In zh, this message translates to:
  /// **'延迟取自上一次解析的健康记录，不是实时值。'**
  String get providerSheetSingleFooter;

  /// No description provided for @providerSheetRaceFooter.
  ///
  /// In zh, this message translates to:
  /// **'竞速模式下每个查询会并发发往所有选中服务商。'**
  String get providerSheetRaceFooter;

  /// No description provided for @powerButtonStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get powerButtonStop;

  /// No description provided for @powerButtonStart.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get powerButtonStart;

  /// No description provided for @powerButtonStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中'**
  String get powerButtonStarting;

  /// No description provided for @homeEditDashboard.
  ///
  /// In zh, this message translates to:
  /// **'编辑仪表盘'**
  String get homeEditDashboard;

  /// No description provided for @homeDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get homeDone;

  /// No description provided for @homeSwitchWorkMode.
  ///
  /// In zh, this message translates to:
  /// **'切换工作模式'**
  String get homeSwitchWorkMode;

  /// No description provided for @homeTitleNormal.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 普通'**
  String get homeTitleNormal;

  /// No description provided for @homeTitleServer.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 服务器'**
  String get homeTitleServer;

  /// No description provided for @homeTitleExpress.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 极速'**
  String get homeTitleExpress;

  /// No description provided for @logRequestsOverview.
  ///
  /// In zh, this message translates to:
  /// **'请求概览'**
  String get logRequestsOverview;

  /// No description provided for @logTodayRequests.
  ///
  /// In zh, this message translates to:
  /// **'今日请求'**
  String get logTodayRequests;

  /// No description provided for @logPassed.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get logPassed;

  /// No description provided for @logFiltered.
  ///
  /// In zh, this message translates to:
  /// **'过滤'**
  String get logFiltered;

  /// No description provided for @logCacheHits.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get logCacheHits;

  /// No description provided for @logHighlights.
  ///
  /// In zh, this message translates to:
  /// **'重点记录'**
  String get logHighlights;

  /// No description provided for @logBlocked.
  ///
  /// In zh, this message translates to:
  /// **'过滤拦截'**
  String get logBlocked;

  /// No description provided for @logFailed.
  ///
  /// In zh, this message translates to:
  /// **'异常失败'**
  String get logFailed;

  /// No description provided for @logBypassed.
  ///
  /// In zh, this message translates to:
  /// **'旁路直连'**
  String get logBypassed;

  /// No description provided for @logOffModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析服务概况'**
  String get logOffModeTitle;

  /// No description provided for @logCacheEntries.
  ///
  /// In zh, this message translates to:
  /// **'有效缓存'**
  String get logCacheEntries;

  /// No description provided for @logCacheHitsTotal.
  ///
  /// In zh, this message translates to:
  /// **'累计缓存命中'**
  String get logCacheHitsTotal;

  /// No description provided for @logRaceRequests.
  ///
  /// In zh, this message translates to:
  /// **'并发竞速请求'**
  String get logRaceRequests;

  /// No description provided for @logBootstrapAttempts.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 尝试'**
  String get logBootstrapAttempts;

  /// No description provided for @logRecentRequests.
  ///
  /// In zh, this message translates to:
  /// **'最近请求'**
  String get logRecentRequests;

  /// No description provided for @logRecentRequestsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无请求日志'**
  String get logRecentRequestsEmpty;

  /// No description provided for @logRecentBlocked.
  ///
  /// In zh, this message translates to:
  /// **'最近拦截与错误'**
  String get logRecentBlocked;

  /// No description provided for @logRecentBlockedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无拦截或错误记录'**
  String get logRecentBlockedEmpty;

  /// No description provided for @logCacheHotspots.
  ///
  /// In zh, this message translates to:
  /// **'缓存热点'**
  String get logCacheHotspots;

  /// No description provided for @logCacheHotspotsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无有效缓存'**
  String get logCacheHotspotsEmpty;

  /// No description provided for @logExpiresIn.
  ///
  /// In zh, this message translates to:
  /// **'{duration} 后过期'**
  String logExpiresIn(Object duration);

  /// No description provided for @logTimes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String logTimes(Object count);

  /// No description provided for @logRaceWinners.
  ///
  /// In zh, this message translates to:
  /// **'竞速胜出'**
  String get logRaceWinners;

  /// No description provided for @logRaceWinnersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无竞速数据'**
  String get logRaceWinnersEmpty;

  /// No description provided for @logAverageWinLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均胜出耗时 {latency}'**
  String logAverageWinLatency(Object latency);

  /// No description provided for @logBootstrapDnsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无 Bootstrap 数据'**
  String get logBootstrapDnsEmpty;

  /// No description provided for @logBootstrapRow.
  ///
  /// In zh, this message translates to:
  /// **'{ip} · 成功 {percent} · {latency}'**
  String logBootstrapRow(Object ip, Object latency, Object percent);

  /// No description provided for @logRuleBlocks.
  ///
  /// In zh, this message translates to:
  /// **'规则拦截'**
  String get logRuleBlocks;

  /// No description provided for @logRuleBlocksEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无规则拦截数据'**
  String get logRuleBlocksEmpty;

  /// No description provided for @logShareRow.
  ///
  /// In zh, this message translates to:
  /// **'{status} · 占全部请求 {percent}'**
  String logShareRow(Object percent, Object status);

  /// No description provided for @logPrivacyMode.
  ///
  /// In zh, this message translates to:
  /// **'隐私模式保护中'**
  String get logPrivacyMode;

  /// No description provided for @logLoggingOff.
  ///
  /// In zh, this message translates to:
  /// **'日志已关闭'**
  String get logLoggingOff;

  /// No description provided for @logPrivacyModeBody.
  ///
  /// In zh, this message translates to:
  /// **'重新开启日志后，仪表盘将从新产生的请求开始统计。当前各类解析服务与缓存热点均正常工作。'**
  String get logPrivacyModeBody;

  /// No description provided for @logPerfTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析效能概况'**
  String get logPerfTitle;

  /// No description provided for @logTodayStats.
  ///
  /// In zh, this message translates to:
  /// **'今日统计'**
  String get logTodayStats;

  /// No description provided for @logAverageLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均解析耗时'**
  String get logAverageLatency;

  /// No description provided for @logNoTimingSamples.
  ///
  /// In zh, this message translates to:
  /// **'— · 今日暂无计时样本'**
  String get logNoTimingSamples;

  /// No description provided for @logSampleValue.
  ///
  /// In zh, this message translates to:
  /// **'{value} · {count} 个样本'**
  String logSampleValue(Object count, Object value);

  /// No description provided for @logCacheHitRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中率'**
  String get logCacheHitRate;

  /// No description provided for @logCacheHitRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · 分母为通过 + 失败'**
  String logCacheHitRateValue(Object percent);

  /// No description provided for @logRaceSuccessRate.
  ///
  /// In zh, this message translates to:
  /// **'竞速成功率'**
  String get logRaceSuccessRate;

  /// No description provided for @logBootstrapSuccessRate.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 成功率'**
  String get logBootstrapSuccessRate;

  /// No description provided for @logRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次 · {latency}'**
  String logRateValue(Object count, Object latency, Object percent);

  /// No description provided for @dashboardRestoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get dashboardRestoreDefaults;

  /// No description provided for @dashboardAllCardsAdded.
  ///
  /// In zh, this message translates to:
  /// **'卡片都放上来了'**
  String get dashboardAllCardsAdded;

  /// No description provided for @dashboardAllCardsAddedDescription.
  ///
  /// In zh, this message translates to:
  /// **'想减少卡片，请回到编辑模式点卡片右上角的移除。'**
  String get dashboardAllCardsAddedDescription;

  /// No description provided for @dashboardAvailableCards.
  ///
  /// In zh, this message translates to:
  /// **'可添加的卡片'**
  String get dashboardAvailableCards;

  /// No description provided for @dashboardOrderHint.
  ///
  /// In zh, this message translates to:
  /// **'卡片顺序可在编辑模式下拖拽调整。'**
  String get dashboardOrderHint;

  /// No description provided for @dashboardCardProviderDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前解析服务商，点开即可切换或调整竞速列表'**
  String get dashboardCardProviderDescription;

  /// No description provided for @dashboardCardResolutionDescription.
  ///
  /// In zh, this message translates to:
  /// **'解析模式选择、一句话说明与当前生效的 DNS 地址'**
  String get dashboardCardResolutionDescription;

  /// No description provided for @dashboardCardStatusDescription.
  ///
  /// In zh, this message translates to:
  /// **'内核状态、运行时长、当前服务商与今日查询'**
  String get dashboardCardStatusDescription;

  /// No description provided for @dashboardCardSpeedDescription.
  ///
  /// In zh, this message translates to:
  /// **'上下行实时速率曲线与今日累计流量'**
  String get dashboardCardSpeedDescription;

  /// No description provided for @dashboardCardSiteLatencyDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义 4 个站点的实测延迟，详情页可按分类测速'**
  String get dashboardCardSiteLatencyDescription;

  /// No description provided for @dashboardCardMemoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'本进程 PSS 与 Java / 原生堆构成'**
  String get dashboardCardMemoryDescription;

  /// No description provided for @dashboardCardIntranetDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前局域网地址、监听状态与复制入口'**
  String get dashboardCardIntranetDescription;

  /// No description provided for @intranetIpTitle.
  ///
  /// In zh, this message translates to:
  /// **'内网 IP'**
  String get intranetIpTitle;

  /// No description provided for @intranetCopyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get intranetCopyAddress;

  /// No description provided for @intranetReading.
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get intranetReading;

  /// No description provided for @intranetNoActiveNetwork.
  ///
  /// In zh, this message translates to:
  /// **'无活动网络'**
  String get intranetNoActiveNetwork;

  /// No description provided for @intranetLanAccess.
  ///
  /// In zh, this message translates to:
  /// **'局域网接入'**
  String get intranetLanAccess;

  /// No description provided for @intranetConnectHint.
  ///
  /// In zh, this message translates to:
  /// **'连上 Wi-Fi 或以太网后这里会显示可用地址'**
  String get intranetConnectHint;

  /// No description provided for @memoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'内存信息'**
  String get memoryTitle;

  /// No description provided for @memoryJavaHeap.
  ///
  /// In zh, this message translates to:
  /// **'Java 堆'**
  String get memoryJavaHeap;

  /// No description provided for @memoryNativeHeap.
  ///
  /// In zh, this message translates to:
  /// **'原生堆'**
  String get memoryNativeHeap;

  /// No description provided for @memorySystemAvailable.
  ///
  /// In zh, this message translates to:
  /// **'整机可用'**
  String get memorySystemAvailable;

  /// No description provided for @speedTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络速度'**
  String get speedTitle;

  /// No description provided for @speedUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get speedUpload;

  /// No description provided for @speedDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get speedDownload;

  /// No description provided for @speedExpressNoStats.
  ///
  /// In zh, this message translates to:
  /// **'极速模式不统计'**
  String get speedExpressNoStats;

  /// No description provided for @speedNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'当前环境无速率通道'**
  String get speedNoChannel;

  /// No description provided for @resolutionModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析模式'**
  String get resolutionModeTitle;

  /// No description provided for @resolutionNoProvider.
  ///
  /// In zh, this message translates to:
  /// **'未选择服务商'**
  String get resolutionNoProvider;

  /// No description provided for @resolutionSingleSummary.
  ///
  /// In zh, this message translates to:
  /// **'只用当前选中的服务商，最快但可用性取决于它。'**
  String get resolutionSingleSummary;

  /// No description provided for @resolutionSmartSummary.
  ///
  /// In zh, this message translates to:
  /// **'按历史成功率挑一个，失败后自动换下一个。'**
  String get resolutionSmartSummary;

  /// No description provided for @resolutionParallelSummary.
  ///
  /// In zh, this message translates to:
  /// **'同时向所有服务商发起，取最先返回的结果。'**
  String get resolutionParallelSummary;

  /// No description provided for @resolutionPrimaryBackupSummary.
  ///
  /// In zh, this message translates to:
  /// **'主服务商优先，超时后才动备用。'**
  String get resolutionPrimaryBackupSummary;

  /// No description provided for @siteLatencyTesting.
  ///
  /// In zh, this message translates to:
  /// **'测速中…'**
  String get siteLatencyTesting;

  /// No description provided for @siteLatencyNotTested.
  ///
  /// In zh, this message translates to:
  /// **'尚未测速'**
  String get siteLatencyNotTested;

  /// No description provided for @siteLatencyTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络测速'**
  String get siteLatencyTitle;

  /// No description provided for @siteLatencyRetest.
  ///
  /// In zh, this message translates to:
  /// **'重新测速'**
  String get siteLatencyRetest;

  /// No description provided for @commonFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get commonFailed;

  /// No description provided for @siteLatencyNoReply.
  ///
  /// In zh, this message translates to:
  /// **'无回包'**
  String get siteLatencyNoReply;

  /// No description provided for @statusTitle.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get statusTitle;

  /// No description provided for @statusUptime.
  ///
  /// In zh, this message translates to:
  /// **'运行时长'**
  String get statusUptime;

  /// No description provided for @statusActiveProvider.
  ///
  /// In zh, this message translates to:
  /// **'当前服务商'**
  String get statusActiveProvider;

  /// No description provided for @statusNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get statusNotSelected;

  /// No description provided for @statusTodayQueries.
  ///
  /// In zh, this message translates to:
  /// **'今日查询'**
  String get statusTodayQueries;

  /// No description provided for @statusDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'状态详情'**
  String get statusDetailTitle;

  /// No description provided for @statusNotTiming.
  ///
  /// In zh, this message translates to:
  /// **'未计时'**
  String get statusNotTiming;

  /// No description provided for @statusCoreSection.
  ///
  /// In zh, this message translates to:
  /// **'内核'**
  String get statusCoreSection;

  /// No description provided for @statusWorkMode.
  ///
  /// In zh, this message translates to:
  /// **'工作模式'**
  String get statusWorkMode;

  /// No description provided for @statusCoreState.
  ///
  /// In zh, this message translates to:
  /// **'内核状态'**
  String get statusCoreState;

  /// No description provided for @statusListenPort.
  ///
  /// In zh, this message translates to:
  /// **'监听端口'**
  String get statusListenPort;

  /// No description provided for @statusNotListening.
  ///
  /// In zh, this message translates to:
  /// **'未监听'**
  String get statusNotListening;

  /// No description provided for @statusProviderFooter.
  ///
  /// In zh, this message translates to:
  /// **'延迟是该服务商的最近一次实测值，不是本机到目标的往返。'**
  String get statusProviderFooter;

  /// No description provided for @statusNoProviderHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有选择服务商。在服务商管理里挑一个，解析才会走真实上游。'**
  String get statusNoProviderHint;

  /// No description provided for @statusTodayCounts.
  ///
  /// In zh, this message translates to:
  /// **'今日计数'**
  String get statusTodayCounts;

  /// No description provided for @statusCountsFooter.
  ///
  /// In zh, this message translates to:
  /// **'计数从本次内核启动开始累计，重启或切换工作模式后归零；已在服务器模式里做的重置也只清计数，不动规则与缓存。'**
  String get statusCountsFooter;

  /// No description provided for @statusQueries.
  ///
  /// In zh, this message translates to:
  /// **'查询'**
  String get statusQueries;

  /// No description provided for @statusBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已拦截'**
  String get statusBlocked;

  /// No description provided for @statusAverageLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均时延'**
  String get statusAverageLatency;

  /// No description provided for @statusCacheHitRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中率'**
  String get statusCacheHitRate;

  /// No description provided for @statusServerPortReady.
  ///
  /// In zh, this message translates to:
  /// **'本机 DNS 端口可用，局域网设备可把它当作 DNS'**
  String get statusServerPortReady;

  /// No description provided for @statusTunnelActive.
  ///
  /// In zh, this message translates to:
  /// **'本机流量已经过谛听，解析与规则都在生效'**
  String get statusTunnelActive;

  /// No description provided for @statusServerPortClosed.
  ///
  /// In zh, this message translates to:
  /// **'DNS 端口未监听，服务器模式当前不提供解析'**
  String get statusServerPortClosed;

  /// No description provided for @statusCoreStopped.
  ///
  /// In zh, this message translates to:
  /// **'内核未运行，本机流量按系统默认网络走'**
  String get statusCoreStopped;

  /// No description provided for @siteLatencySheetLatency.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get siteLatencySheetLatency;

  /// No description provided for @siteLatencySheetCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get siteLatencySheetCategory;

  /// No description provided for @siteLatencySheetTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get siteLatencySheetTarget;

  /// No description provided for @siteLatencySheetAverage.
  ///
  /// In zh, this message translates to:
  /// **'平均往返'**
  String get siteLatencySheetAverage;

  /// No description provided for @siteLatencySheetMinMax.
  ///
  /// In zh, this message translates to:
  /// **'最小 / 最大'**
  String get siteLatencySheetMinMax;

  /// No description provided for @siteLatencySheetJitter.
  ///
  /// In zh, this message translates to:
  /// **'抖动'**
  String get siteLatencySheetJitter;

  /// No description provided for @siteLatencySheetLoss.
  ///
  /// In zh, this message translates to:
  /// **'丢包'**
  String get siteLatencySheetLoss;

  /// No description provided for @siteLatencySheetDns.
  ///
  /// In zh, this message translates to:
  /// **'解析地址'**
  String get siteLatencySheetDns;

  /// No description provided for @siteLatencySheetLastRun.
  ///
  /// In zh, this message translates to:
  /// **'最近测速'**
  String get siteLatencySheetLastRun;

  /// No description provided for @siteLatencySheetNotTested.
  ///
  /// In zh, this message translates to:
  /// **'尚未测速。点测速按钮开始测量。'**
  String get siteLatencySheetNotTested;

  /// No description provided for @siteLatencySheetNoReply.
  ///
  /// In zh, this message translates to:
  /// **'三个回显请求都没有收到应答，可能是站点限流或当前网络不通。'**
  String get siteLatencySheetNoReply;

  /// No description provided for @siteLatencySheetFallbackFooter.
  ///
  /// In zh, this message translates to:
  /// **'系统 ping 不可用，这次数值来自 TCP 握手 / isReachable，衡量的是建连时延而不是 ICMP 回显，会略高于真实往返。'**
  String get siteLatencySheetFallbackFooter;

  /// No description provided for @siteLatencySheetIcmpFooter.
  ///
  /// In zh, this message translates to:
  /// **'数值来自系统 ping 的 ICMP 回显（3 次取平均）。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencySheetIcmpFooter;

  /// No description provided for @trafficStructureLive.
  ///
  /// In zh, this message translates to:
  /// **'实时汇总'**
  String get trafficStructureLive;

  /// No description provided for @trafficStructureFocused.
  ///
  /// In zh, this message translates to:
  /// **'重点流量结构'**
  String get trafficStructureFocused;

  /// No description provided for @trafficStructureToday.
  ///
  /// In zh, this message translates to:
  /// **'今日流量结构'**
  String get trafficStructureToday;

  /// No description provided for @trafficStructureBypass.
  ///
  /// In zh, this message translates to:
  /// **'旁路'**
  String get trafficStructureBypass;

  /// No description provided for @trafficStructureCache.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get trafficStructureCache;

  /// No description provided for @trafficStructureRaceRate.
  ///
  /// In zh, this message translates to:
  /// **'竞速成功率'**
  String get trafficStructureRaceRate;

  /// No description provided for @trafficStructureBootstrapRate.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 成功率'**
  String get trafficStructureBootstrapRate;

  /// No description provided for @trafficStructureBlockedShare.
  ///
  /// In zh, this message translates to:
  /// **'拦截占比'**
  String get trafficStructureBlockedShare;

  /// No description provided for @trafficStructureBlockRate.
  ///
  /// In zh, this message translates to:
  /// **'拦截率'**
  String get trafficStructureBlockRate;

  /// No description provided for @trafficStructureCacheRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存率'**
  String get trafficStructureCacheRate;

  /// No description provided for @dashboardSitesTitle.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘站点'**
  String get dashboardSitesTitle;

  /// No description provided for @dashboardSitesCardSection.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘卡片'**
  String get dashboardSitesCardSection;

  /// No description provided for @dashboardSitesAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'卡片至少保留 1 个站点'**
  String get dashboardSitesAtLeastOne;

  /// No description provided for @dashboardSitesFooter.
  ///
  /// In zh, this message translates to:
  /// **'这四张卡片用的是同一个仪表盘卡片，改动立刻生效；测速在详情页按分类手动触发。'**
  String get dashboardSitesFooter;

  /// No description provided for @trafficMonitorTitle.
  ///
  /// In zh, this message translates to:
  /// **'流量监控'**
  String get trafficMonitorTitle;

  /// No description provided for @trafficMonitorToday.
  ///
  /// In zh, this message translates to:
  /// **'今日代理流量'**
  String get trafficMonitorToday;

  /// No description provided for @trafficMonitorLiveRate.
  ///
  /// In zh, this message translates to:
  /// **'实时速率'**
  String get trafficMonitorLiveRate;

  /// No description provided for @trafficMonitorNoStats.
  ///
  /// In zh, this message translates to:
  /// **'本模式不统计'**
  String get trafficMonitorNoStats;

  /// No description provided for @memoryDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'内存详情'**
  String get memoryDetailTitle;

  /// No description provided for @memoryResample.
  ///
  /// In zh, this message translates to:
  /// **'重新采样'**
  String get memoryResample;

  /// No description provided for @memoryProcessPss.
  ///
  /// In zh, this message translates to:
  /// **'本进程 PSS'**
  String get memoryProcessPss;

  /// No description provided for @memoryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get memoryUnavailable;

  /// No description provided for @memoryOther.
  ///
  /// In zh, this message translates to:
  /// **'其它'**
  String get memoryOther;

  /// No description provided for @memoryComposition.
  ///
  /// In zh, this message translates to:
  /// **'进程构成'**
  String get memoryComposition;

  /// No description provided for @memoryCompositionFooter.
  ///
  /// In zh, this message translates to:
  /// **'PSS 按共享页的比例计入本进程，因此 Java 堆与原生堆之和小于 PSS，差额是代码、图形缓冲与共享库。'**
  String get memoryCompositionFooter;

  /// No description provided for @memoryOtherCode.
  ///
  /// In zh, this message translates to:
  /// **'其它（代码 / 共享库）'**
  String get memoryOtherCode;

  /// No description provided for @memorySystemSection.
  ///
  /// In zh, this message translates to:
  /// **'整机内存'**
  String get memorySystemSection;

  /// No description provided for @memorySystemFooter.
  ///
  /// In zh, this message translates to:
  /// **'整机占用 = 总量 - 可用量，包含系统与所有应用；本进程只是其中一份。'**
  String get memorySystemFooter;

  /// No description provided for @memorySystemUsed.
  ///
  /// In zh, this message translates to:
  /// **'整机已用'**
  String get memorySystemUsed;

  /// No description provided for @memoryRecentPss.
  ///
  /// In zh, this message translates to:
  /// **'最近 PSS'**
  String get memoryRecentPss;

  /// No description provided for @memorySampling.
  ///
  /// In zh, this message translates to:
  /// **'正在采样…'**
  String get memorySampling;

  /// No description provided for @memoryRecentPssCaption.
  ///
  /// In zh, this message translates to:
  /// **'打开本页后每 2 秒采样一次，最多保留 60 个点；曲线持续上扬说明有内存未释放。'**
  String get memoryRecentPssCaption;

  /// No description provided for @memorySourceFooter.
  ///
  /// In zh, this message translates to:
  /// **'数据来自 ActivityManager 的 MemoryInfo；切到后台或系统回收后数值会明显下降。'**
  String get memorySourceFooter;

  /// No description provided for @siteLatencyDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'测速详情'**
  String get siteLatencyDetailTitle;

  /// No description provided for @siteLatencyTestAll.
  ///
  /// In zh, this message translates to:
  /// **'测全部'**
  String get siteLatencyTestAll;

  /// No description provided for @siteLatencyCustomSites.
  ///
  /// In zh, this message translates to:
  /// **'自定义仪表盘站点'**
  String get siteLatencyCustomSites;

  /// No description provided for @siteLatencyConnectivity.
  ///
  /// In zh, this message translates to:
  /// **'站点连通性'**
  String get siteLatencyConnectivity;

  /// No description provided for @siteLatencyTestingShort.
  ///
  /// In zh, this message translates to:
  /// **'测速中'**
  String get siteLatencyTestingShort;

  /// No description provided for @siteLatencyNoTest.
  ///
  /// In zh, this message translates to:
  /// **'未测速'**
  String get siteLatencyNoTest;

  /// No description provided for @siteLatencyInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get siteLatencyInProgress;

  /// No description provided for @siteLatencyPending.
  ///
  /// In zh, this message translates to:
  /// **'待测'**
  String get siteLatencyPending;

  /// No description provided for @siteLatencyAllReachable.
  ///
  /// In zh, this message translates to:
  /// **'全部通畅'**
  String get siteLatencyAllReachable;

  /// No description provided for @siteLatencyTestingEach.
  ///
  /// In zh, this message translates to:
  /// **'正在逐个站点测速…'**
  String get siteLatencyTestingEach;

  /// No description provided for @siteLatencyPickCategory.
  ///
  /// In zh, this message translates to:
  /// **'选一个分类点测速，或点右上角测全部。'**
  String get siteLatencyPickCategory;

  /// No description provided for @siteLatencyThisRun.
  ///
  /// In zh, this message translates to:
  /// **'本次结果'**
  String get siteLatencyThisRun;

  /// No description provided for @siteLatencyReachable.
  ///
  /// In zh, this message translates to:
  /// **'通畅'**
  String get siteLatencyReachable;

  /// No description provided for @siteLatencyMeasuredSites.
  ///
  /// In zh, this message translates to:
  /// **'已测站点'**
  String get siteLatencyMeasuredSites;

  /// No description provided for @siteLatencyDetailFooter.
  ///
  /// In zh, this message translates to:
  /// **'每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencyDetailFooter;

  /// No description provided for @intranetDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'内网 IP 详情'**
  String get intranetDetailTitle;

  /// No description provided for @intranetRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新网络信息'**
  String get intranetRefresh;

  /// No description provided for @intranetLocalAddress.
  ///
  /// In zh, this message translates to:
  /// **'本机局域网地址'**
  String get intranetLocalAddress;

  /// No description provided for @intranetUsableAsDns.
  ///
  /// In zh, this message translates to:
  /// **'可作 DNS'**
  String get intranetUsableAsDns;

  /// No description provided for @intranetLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本机'**
  String get intranetLocalOnly;

  /// No description provided for @intranetSameSubnetHint.
  ///
  /// In zh, this message translates to:
  /// **'同网段设备把 DNS 指到这个地址即可走本机解析。'**
  String get intranetSameSubnetHint;

  /// No description provided for @intranetNetworkOverview.
  ///
  /// In zh, this message translates to:
  /// **'网络概况'**
  String get intranetNetworkOverview;

  /// No description provided for @commonEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get commonDisabled;

  /// No description provided for @intranetDnsServers.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务器'**
  String get intranetDnsServers;

  /// No description provided for @intranetInterfaces.
  ///
  /// In zh, this message translates to:
  /// **'接口'**
  String get intranetInterfaces;

  /// No description provided for @intranetNoInterface.
  ///
  /// In zh, this message translates to:
  /// **'系统没有报告活动网络接口，可能是飞行模式或未联网。'**
  String get intranetNoInterface;

  /// No description provided for @intranetAdapter.
  ///
  /// In zh, this message translates to:
  /// **'网卡'**
  String get intranetAdapter;

  /// No description provided for @intranetGateway.
  ///
  /// In zh, this message translates to:
  /// **'网关'**
  String get intranetGateway;

  /// No description provided for @intranetPrivateDnsOff.
  ///
  /// In zh, this message translates to:
  /// **'系统私人 DNS 未开启，解析请求由本机与代理按模式处理。'**
  String get intranetPrivateDnsOff;

  /// No description provided for @intranetNoDnsServer.
  ///
  /// In zh, this message translates to:
  /// **'没有读到 DNS 服务器：接口未下发 DNS，或当前环境没有诊断通道。'**
  String get intranetNoDnsServer;

  /// No description provided for @intranetPrimaryDns.
  ///
  /// In zh, this message translates to:
  /// **'首选'**
  String get intranetPrimaryDns;

  /// No description provided for @intranetPrivateDns.
  ///
  /// In zh, this message translates to:
  /// **'私人 DNS'**
  String get intranetPrivateDns;

  /// No description provided for @intranetPortFooter.
  ///
  /// In zh, this message translates to:
  /// **'端口只在服务启动时绑定，改动端口后需要重启服务；把同网段设备的 DNS 指向上面的地址即可让它们走本机解析。'**
  String get intranetPortFooter;

  /// No description provided for @intranetCopyAddressWithPort.
  ///
  /// In zh, this message translates to:
  /// **'复制地址（含端口）'**
  String get intranetCopyAddressWithPort;

  /// No description provided for @speedDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'网速详情'**
  String get speedDetailTitle;

  /// No description provided for @speedCurrentDownload.
  ///
  /// In zh, this message translates to:
  /// **'当前下载'**
  String get speedCurrentDownload;

  /// No description provided for @speedSamplingPaused.
  ///
  /// In zh, this message translates to:
  /// **'暂停采样'**
  String get speedSamplingPaused;

  /// No description provided for @speedLive.
  ///
  /// In zh, this message translates to:
  /// **'实时'**
  String get speedLive;

  /// No description provided for @speedSamplingHint.
  ///
  /// In zh, this message translates to:
  /// **'每秒采样一次，下图是最近一分钟。'**
  String get speedSamplingHint;

  /// No description provided for @speedCurrentUpload.
  ///
  /// In zh, this message translates to:
  /// **'当前上传'**
  String get speedCurrentUpload;

  /// No description provided for @speedDownloadPeak.
  ///
  /// In zh, this message translates to:
  /// **'下行峰值'**
  String get speedDownloadPeak;

  /// No description provided for @speedUploadPeak.
  ///
  /// In zh, this message translates to:
  /// **'上行峰值'**
  String get speedUploadPeak;

  /// No description provided for @speedSamples.
  ///
  /// In zh, this message translates to:
  /// **'样本'**
  String get speedSamples;

  /// No description provided for @speedTodayTotal.
  ///
  /// In zh, this message translates to:
  /// **'今日累计'**
  String get speedTodayTotal;

  /// No description provided for @speedNoTrafficToday.
  ///
  /// In zh, this message translates to:
  /// **'流量库还没有今天的记录。'**
  String get speedNoTrafficToday;

  /// No description provided for @speedTotal.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get speedTotal;

  /// No description provided for @speedRateFooter.
  ///
  /// In zh, this message translates to:
  /// **'速率来自内核数据面的实时计数，只包含经过隧道转发的流量；本应用自身的探测与测速不计入。今日累计来自应用流量统计，与「流量统计」页同一份数据。'**
  String get speedRateFooter;

  /// No description provided for @speedExpressSource.
  ///
  /// In zh, this message translates to:
  /// **'极速模式不经过内核数据面，因此没有逐秒速率；切回普通模式后恢复。'**
  String get speedExpressSource;

  /// No description provided for @speedNoChannelSource.
  ///
  /// In zh, this message translates to:
  /// **'当前环境没有速率通道（桌面环境或纯 Dart 测试），读不到实时速率。'**
  String get speedNoChannelSource;

  /// No description provided for @speedNoDataInMode.
  ///
  /// In zh, this message translates to:
  /// **'当前模式下没有速率数据'**
  String get speedNoDataInMode;

  /// No description provided for @speedWaitingSample.
  ///
  /// In zh, this message translates to:
  /// **'正在等待第一个样本'**
  String get speedWaitingSample;

  /// No description provided for @commonNoData.
  ///
  /// In zh, this message translates to:
  /// **'无数据'**
  String get commonNoData;

  /// No description provided for @intranetModeNotListening.
  ///
  /// In zh, this message translates to:
  /// **'{mode}不监听局域网，其他设备无法把这里当 DNS'**
  String intranetModeNotListening(Object mode);

  /// No description provided for @intranetListeningOn.
  ///
  /// In zh, this message translates to:
  /// **'已监听 0.0.0.0:{port}，其他设备把 DNS 指到上面的地址'**
  String intranetListeningOn(Object port);

  /// No description provided for @intranetServiceStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务未启动：启动后才会绑定 {port} 端口'**
  String intranetServiceStopped(Object port);

  /// No description provided for @commonCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {text}'**
  String commonCopied(Object text);

  /// No description provided for @intranetGatewaySuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 网关 {gateway}'**
  String intranetGatewaySuffix(Object gateway);

  /// No description provided for @speedTotalDash.
  ///
  /// In zh, this message translates to:
  /// **'累计 —'**
  String get speedTotalDash;

  /// No description provided for @siteLatencyAliveRatio.
  ///
  /// In zh, this message translates to:
  /// **'{alive} / {total} 通畅'**
  String siteLatencyAliveRatio(Object alive, Object total);

  /// No description provided for @siteLatencyLastRun.
  ///
  /// In zh, this message translates to:
  /// **'最近测速 {ago}'**
  String siteLatencyLastRun(Object ago);

  /// No description provided for @siteLatencyProviderSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 解析服务商 {name}'**
  String siteLatencyProviderSuffix(Object name);

  /// No description provided for @siteLatencySitesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个站点'**
  String siteLatencySitesCount(Object count);

  /// No description provided for @siteLatencyTestCategory.
  ///
  /// In zh, this message translates to:
  /// **'测速{category}'**
  String siteLatencyTestCategory(Object category);

  /// No description provided for @memorySystemShare.
  ///
  /// In zh, this message translates to:
  /// **'占整机 {percent}'**
  String memorySystemShare(Object percent);

  /// No description provided for @memorySystemUsedOf.
  ///
  /// In zh, this message translates to:
  /// **'整机已用 {used} / {total}'**
  String memorySystemUsedOf(Object total, Object used);

  /// No description provided for @memoryNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'当前环境读不到内存数据（桌面环境或纯 Dart 测试）。'**
  String get memoryNoChannel;

  /// No description provided for @trafficStructureRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次 · {latency}'**
  String trafficStructureRateValue(
    Object count,
    Object latency,
    Object percent,
  );

  /// No description provided for @trafficStructureShareValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次'**
  String trafficStructureShareValue(Object count, Object percent);

  /// No description provided for @statusPausedSummary.
  ///
  /// In zh, this message translates to:
  /// **'{mode}{core}，计时已暂停'**
  String statusPausedSummary(Object core, Object mode);

  /// No description provided for @speedTotalsDown.
  ///
  /// In zh, this message translates to:
  /// **'下行 {percent}'**
  String speedTotalsDown(Object percent);

  /// No description provided for @speedTotalsUp.
  ///
  /// In zh, this message translates to:
  /// **'上行 {percent}'**
  String speedTotalsUp(Object percent);

  /// No description provided for @speedPeakAverage.
  ///
  /// In zh, this message translates to:
  /// **'峰值 {peak} · 平均 {average}'**
  String speedPeakAverage(Object average, Object peak);

  /// No description provided for @intranetConnectHintSentence.
  ///
  /// In zh, this message translates to:
  /// **'连上 Wi-Fi 或以太网后这里会显示可用地址。'**
  String get intranetConnectHintSentence;

  /// No description provided for @intranetModeNotListeningSentence.
  ///
  /// In zh, this message translates to:
  /// **'{mode}不监听局域网，其它设备无法把这里当 DNS。'**
  String intranetModeNotListeningSentence(Object mode);

  /// No description provided for @intranetPrivateDnsOn.
  ///
  /// In zh, this message translates to:
  /// **'系统开启了私人 DNS（{dns}），系统解析会走加密通道，可能绕过本地服务。'**
  String intranetPrivateDnsOn(Object dns);

  /// No description provided for @intranetSecondaryDns.
  ///
  /// In zh, this message translates to:
  /// **'备用 {index}'**
  String intranetSecondaryDns(Object index);

  /// No description provided for @intranetCopyAddressSemantics.
  ///
  /// In zh, this message translates to:
  /// **'复制地址 {address}'**
  String intranetCopyAddressSemantics(Object address);

  /// No description provided for @speedTotalAccumulated.
  ///
  /// In zh, this message translates to:
  /// **'累计 {value}'**
  String speedTotalAccumulated(Object value);

  /// No description provided for @dashboardSitesFull.
  ///
  /// In zh, this message translates to:
  /// **'卡片只能放 {count} 个站点，先点掉一个再换别的。'**
  String dashboardSitesFull(Object count);

  /// No description provided for @dashboardSitesRemaining.
  ///
  /// In zh, this message translates to:
  /// **'还可以再放 {count} 个站点。'**
  String dashboardSitesRemaining(Object count);

  /// No description provided for @dashboardSitesMax.
  ///
  /// In zh, this message translates to:
  /// **'卡片最多放 {count} 个站点，先取消一个再选。'**
  String dashboardSitesMax(Object count);

  /// No description provided for @dashboardSitesPosition.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 位'**
  String dashboardSitesPosition(Object index);

  /// No description provided for @siteLatencyFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个失败'**
  String siteLatencyFailedCount(Object count);

  /// No description provided for @siteLatencyDetailFooterLong.
  ///
  /// In zh, this message translates to:
  /// **'每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencyDetailFooterLong;

  /// No description provided for @homeLayerPowerButton.
  ///
  /// In zh, this message translates to:
  /// **'启动按钮'**
  String get homeLayerPowerButton;

  /// No description provided for @homeLayerPoem.
  ///
  /// In zh, this message translates to:
  /// **'首页古诗'**
  String get homeLayerPoem;

  /// No description provided for @bottomBarHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get bottomBarHome;

  /// No description provided for @bottomBarFeatureHub.
  ///
  /// In zh, this message translates to:
  /// **'功能中心'**
  String get bottomBarFeatureHub;

  /// No description provided for @bottomBarLogDashboard.
  ///
  /// In zh, this message translates to:
  /// **'日志仪表盘'**
  String get bottomBarLogDashboard;

  /// No description provided for @bottomBarAppTraffic.
  ///
  /// In zh, this message translates to:
  /// **'应用流量'**
  String get bottomBarAppTraffic;

  /// No description provided for @bottomBarNetworkTools.
  ///
  /// In zh, this message translates to:
  /// **'网络工具'**
  String get bottomBarNetworkTools;

  /// No description provided for @bottomBarSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get bottomBarSettings;

  /// No description provided for @bottomBarStyleFloating.
  ///
  /// In zh, this message translates to:
  /// **'浮条'**
  String get bottomBarStyleFloating;

  /// No description provided for @bottomBarStyleDocked.
  ///
  /// In zh, this message translates to:
  /// **'普通'**
  String get bottomBarStyleDocked;

  /// No description provided for @tabTransitionNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get tabTransitionNone;

  /// No description provided for @tabTransitionFade.
  ///
  /// In zh, this message translates to:
  /// **'淡入'**
  String get tabTransitionFade;

  /// No description provided for @tabTransitionSlide.
  ///
  /// In zh, this message translates to:
  /// **'滑动'**
  String get tabTransitionSlide;

  /// No description provided for @tabTransitionScale.
  ///
  /// In zh, this message translates to:
  /// **'缩放'**
  String get tabTransitionScale;

  /// No description provided for @commonOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonOff;

  /// No description provided for @glassModeStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get glassModeStandard;

  /// No description provided for @glassModeUltra.
  ///
  /// In zh, this message translates to:
  /// **'极致'**
  String get glassModeUltra;

  /// No description provided for @previewBrightnessLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get previewBrightnessLight;

  /// No description provided for @previewBrightnessDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get previewBrightnessDark;

  /// No description provided for @resolutionModeSingle.
  ///
  /// In zh, this message translates to:
  /// **'单服务商'**
  String get resolutionModeSingle;

  /// No description provided for @resolutionModeSmart.
  ///
  /// In zh, this message translates to:
  /// **'智能选择'**
  String get resolutionModeSmart;

  /// No description provided for @resolutionModeParallel.
  ///
  /// In zh, this message translates to:
  /// **'并行竞速'**
  String get resolutionModeParallel;

  /// No description provided for @resolutionModePrimaryBackup.
  ///
  /// In zh, this message translates to:
  /// **'主备切换'**
  String get resolutionModePrimaryBackup;

  /// No description provided for @workModeNormalTitle.
  ///
  /// In zh, this message translates to:
  /// **'普通模式'**
  String get workModeNormalTitle;

  /// No description provided for @workModeNormalBadge.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get workModeNormalBadge;

  /// No description provided for @workModeNormalSummary.
  ///
  /// In zh, this message translates to:
  /// **'全量域名解析、黑白名单、HTTPS 检查、网络管控'**
  String get workModeNormalSummary;

  /// No description provided for @workModeServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式'**
  String get workModeServerTitle;

  /// No description provided for @workModeServerBadge.
  ///
  /// In zh, this message translates to:
  /// **'轻量'**
  String get workModeServerBadge;

  /// No description provided for @workModeServerSummary.
  ///
  /// In zh, this message translates to:
  /// **'纯 DNS 代理与解析加速、低功耗'**
  String get workModeServerSummary;

  /// No description provided for @workModeExpressTitle.
  ///
  /// In zh, this message translates to:
  /// **'极速模式'**
  String get workModeExpressTitle;

  /// No description provided for @workModeExpressBadge.
  ///
  /// In zh, this message translates to:
  /// **'极速'**
  String get workModeExpressBadge;

  /// No description provided for @workModeExpressSummary.
  ///
  /// In zh, this message translates to:
  /// **'纯 Kotlin、DNS 加速与规则过滤、Android 7+（64 位）'**
  String get workModeExpressSummary;

  /// No description provided for @stateStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get stateStopped;

  /// No description provided for @stateStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中'**
  String get stateStarting;

  /// No description provided for @stateRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get stateRunning;

  /// No description provided for @stateStopping.
  ///
  /// In zh, this message translates to:
  /// **'停止中'**
  String get stateStopping;

  /// No description provided for @powerStateError.
  ///
  /// In zh, this message translates to:
  /// **'启动失败'**
  String get powerStateError;

  /// No description provided for @serverStatusError.
  ///
  /// In zh, this message translates to:
  /// **'异常'**
  String get serverStatusError;

  /// No description provided for @logModeAllLabel.
  ///
  /// In zh, this message translates to:
  /// **'记录全部'**
  String get logModeAllLabel;

  /// No description provided for @logModeAllDescription.
  ///
  /// In zh, this message translates to:
  /// **'请求、命中、竞速与拦截都进日志'**
  String get logModeAllDescription;

  /// No description provided for @logModeBlockedLabel.
  ///
  /// In zh, this message translates to:
  /// **'仅拦截与错误'**
  String get logModeBlockedLabel;

  /// No description provided for @logModeBlockedDescription.
  ///
  /// In zh, this message translates to:
  /// **'只记录被拦截与出错的请求'**
  String get logModeBlockedDescription;

  /// No description provided for @logModeOffLabel.
  ///
  /// In zh, this message translates to:
  /// **'关闭日志'**
  String get logModeOffLabel;

  /// No description provided for @logModeOffDescription.
  ///
  /// In zh, this message translates to:
  /// **'不记录任何请求，节省空间'**
  String get logModeOffDescription;

  /// No description provided for @ipv6AutoLabel.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get ipv6AutoLabel;

  /// No description provided for @ipv6AutoDescription.
  ///
  /// In zh, this message translates to:
  /// **'按当前网络能力决定是否启用'**
  String get ipv6AutoDescription;

  /// No description provided for @ipv6DisableLabel.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get ipv6DisableLabel;

  /// No description provided for @ipv6DisableDescription.
  ///
  /// In zh, this message translates to:
  /// **'隧道内不启用 IPv6'**
  String get ipv6DisableDescription;

  /// No description provided for @ipv6PreferLabel.
  ///
  /// In zh, this message translates to:
  /// **'优先'**
  String get ipv6PreferLabel;

  /// No description provided for @ipv6PreferDescription.
  ///
  /// In zh, this message translates to:
  /// **'尽量走 IPv6，失败再回落'**
  String get ipv6PreferDescription;

  /// No description provided for @commonToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get commonToday;

  /// No description provided for @logWindowSevenDays.
  ///
  /// In zh, this message translates to:
  /// **'7 天'**
  String get logWindowSevenDays;

  /// No description provided for @logWindowSevenDaysRecent.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天'**
  String get logWindowSevenDaysRecent;

  /// No description provided for @commonAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// No description provided for @trafficWindowWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get trafficWindowWeek;

  /// No description provided for @trafficWindowMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get trafficWindowMonth;

  /// No description provided for @trafficSortTotal.
  ///
  /// In zh, this message translates to:
  /// **'按总流量'**
  String get trafficSortTotal;

  /// No description provided for @trafficSortDownload.
  ///
  /// In zh, this message translates to:
  /// **'按下载流量'**
  String get trafficSortDownload;

  /// No description provided for @trafficSortUpload.
  ///
  /// In zh, this message translates to:
  /// **'按上传流量'**
  String get trafficSortUpload;

  /// No description provided for @davStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get davStatusIdle;

  /// No description provided for @davStatusConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get davStatusConnecting;

  /// No description provided for @davStatusConnected.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get davStatusConnected;

  /// No description provided for @davStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get davStatusFailed;

  /// No description provided for @updateStageIdle.
  ///
  /// In zh, this message translates to:
  /// **'未检查'**
  String get updateStageIdle;

  /// No description provided for @updateStageChecking.
  ///
  /// In zh, this message translates to:
  /// **'检查中'**
  String get updateStageChecking;

  /// No description provided for @updateStageUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新'**
  String get updateStageUpToDate;

  /// No description provided for @updateStageAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateStageAvailable;

  /// No description provided for @updateStageDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get updateStageDownloading;

  /// No description provided for @updateStageDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get updateStageDownloaded;

  /// No description provided for @ipQualityStageIdle.
  ///
  /// In zh, this message translates to:
  /// **'未检测'**
  String get ipQualityStageIdle;

  /// No description provided for @ipQualityStageLoading.
  ///
  /// In zh, this message translates to:
  /// **'检测中'**
  String get ipQualityStageLoading;

  /// No description provided for @ipQualityStageLoaded.
  ///
  /// In zh, this message translates to:
  /// **'检测完成'**
  String get ipQualityStageLoaded;

  /// No description provided for @ipQualityStageFailed.
  ///
  /// In zh, this message translates to:
  /// **'检测失败'**
  String get ipQualityStageFailed;

  /// No description provided for @subscriptionDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get subscriptionDeleted;

  /// No description provided for @subscriptionDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get subscriptionDisabled;

  /// No description provided for @subscriptionUngrouped.
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get subscriptionUngrouped;

  /// No description provided for @providerNotTested.
  ///
  /// In zh, this message translates to:
  /// **'未测速'**
  String get providerNotTested;

  /// No description provided for @elapsedJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get elapsedJustNow;

  /// No description provided for @elapsedSecondsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒前'**
  String elapsedSecondsAgo(Object count);

  /// No description provided for @elapsedMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String elapsedMinutesAgo(Object count);

  /// No description provided for @elapsedHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String elapsedHoursAgo(Object count);

  /// No description provided for @elapsedDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String elapsedDaysAgo(Object count);

  /// No description provided for @providerRaceSummary.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 个：{names}'**
  String providerRaceSummary(Object count, Object names);

  /// No description provided for @rulesDbUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前环境无法读写规则库'**
  String get rulesDbUnavailable;

  /// No description provided for @agentApiKeyMissing.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置可用的 API Key，请先在「AI 厂商管理」里填写并选中该厂商。'**
  String get agentApiKeyMissing;

  /// No description provided for @agentNoExtraInfo.
  ///
  /// In zh, this message translates to:
  /// **'（无附加信息）'**
  String get agentNoExtraInfo;

  /// No description provided for @agentNoLegacyDatabase.
  ///
  /// In zh, this message translates to:
  /// **'未找到旧版数据库，无法读取 DNS 与 HTTPS 日志；请先启动一次服务。'**
  String get agentNoLegacyDatabase;

  /// No description provided for @agentExpressNoHttps.
  ///
  /// In zh, this message translates to:
  /// **'极速模式只做窄路由 DNS 加速，不产生 HTTPS 检查记录'**
  String get agentExpressNoHttps;

  /// No description provided for @autoUpdateDisabled.
  ///
  /// In zh, this message translates to:
  /// **'自动更新已关闭'**
  String get autoUpdateDisabled;

  /// No description provided for @autoUpdateNoSubscriptions.
  ///
  /// In zh, this message translates to:
  /// **'没有可自动更新的订阅'**
  String get autoUpdateNoSubscriptions;

  /// No description provided for @autoUpdateNotDue.
  ///
  /// In zh, this message translates to:
  /// **'未到更新时间'**
  String get autoUpdateNotDue;

  /// No description provided for @autoUpdateBusy.
  ///
  /// In zh, this message translates to:
  /// **'正在手动更新，本轮跳过'**
  String get autoUpdateBusy;

  /// No description provided for @cleanupGroupRuntime.
  ///
  /// In zh, this message translates to:
  /// **'运行数据'**
  String get cleanupGroupRuntime;

  /// No description provided for @cleanupGroupWeights.
  ///
  /// In zh, this message translates to:
  /// **'权重数据'**
  String get cleanupGroupWeights;

  /// No description provided for @cleanupGroupRules.
  ///
  /// In zh, this message translates to:
  /// **'规则与订阅'**
  String get cleanupGroupRules;

  /// No description provided for @cleanupGroupStorage.
  ///
  /// In zh, this message translates to:
  /// **'存储与安全'**
  String get cleanupGroupStorage;

  /// No description provided for @cleanupGroupGuides.
  ///
  /// In zh, this message translates to:
  /// **'引导与重置'**
  String get cleanupGroupGuides;

  /// No description provided for @backupReadFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选文件'**
  String get backupReadFileFailed;

  /// No description provided for @caChannelUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'证书通道不可用'**
  String get caChannelUnavailable;

  /// No description provided for @caInstallUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法调起证书安装界面'**
  String get caInstallUnavailable;

  /// No description provided for @caDownloadDirUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法写入下载目录'**
  String get caDownloadDirUnavailable;

  /// No description provided for @fontSystemDefault.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get fontSystemDefault;

  /// No description provided for @diagnosticsChannelUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'诊断通道不可用（当前平台没有原生实现）'**
  String get diagnosticsChannelUnavailable;

  /// No description provided for @diagnosticsUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前环境不支持该诊断能力'**
  String get diagnosticsUnsupported;

  /// No description provided for @diagnosticsPingUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前环境不支持 Ping 探测'**
  String get diagnosticsPingUnsupported;

  /// No description provided for @diagnosticsTraceUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前环境不支持路由追踪'**
  String get diagnosticsTraceUnsupported;

  /// No description provided for @diagnosticsDnsUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前环境不支持 DNS 查询'**
  String get diagnosticsDnsUnsupported;

  /// No description provided for @diagnosticsEmptyTarget.
  ///
  /// In zh, this message translates to:
  /// **'请输入探测目标'**
  String get diagnosticsEmptyTarget;

  /// No description provided for @diagnosticsTargetHasSpace.
  ///
  /// In zh, this message translates to:
  /// **'目标不能包含空格'**
  String get diagnosticsTargetHasSpace;

  /// No description provided for @diagnosticsAnswerUpstream.
  ///
  /// In zh, this message translates to:
  /// **'上游解析'**
  String get diagnosticsAnswerUpstream;

  /// No description provided for @diagnosticsAnswerCache.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get diagnosticsAnswerCache;

  /// No description provided for @diagnosticsAnswerRewrite.
  ///
  /// In zh, this message translates to:
  /// **'覆写规则'**
  String get diagnosticsAnswerRewrite;

  /// No description provided for @diagnosticsAnswerBlocked.
  ///
  /// In zh, this message translates to:
  /// **'被规则拦截'**
  String get diagnosticsAnswerBlocked;

  /// No description provided for @diagnosticsAnswerFailed.
  ///
  /// In zh, this message translates to:
  /// **'查询失败'**
  String get diagnosticsAnswerFailed;

  /// No description provided for @diagnosticsNoActiveNetwork.
  ///
  /// In zh, this message translates to:
  /// **'无活动网络'**
  String get diagnosticsNoActiveNetwork;

  /// No description provided for @aiPresetMainland.
  ///
  /// In zh, this message translates to:
  /// **'国内厂商'**
  String get aiPresetMainland;

  /// No description provided for @aiPresetOverseas.
  ///
  /// In zh, this message translates to:
  /// **'海外厂商'**
  String get aiPresetOverseas;

  /// No description provided for @aiPresetAggregator.
  ///
  /// In zh, this message translates to:
  /// **'聚合与本地部署'**
  String get aiPresetAggregator;

  /// No description provided for @aiProviderConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置厂商'**
  String get aiProviderConfigured;

  /// No description provided for @logSubscriptionDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除订阅'**
  String get logSubscriptionDeleted;

  /// No description provided for @logRaceFastest.
  ///
  /// In zh, this message translates to:
  /// **'最快响应'**
  String get logRaceFastest;

  /// No description provided for @logRaceSmart.
  ///
  /// In zh, this message translates to:
  /// **'智能选择'**
  String get logRaceSmart;

  /// No description provided for @logRaceSequential.
  ///
  /// In zh, this message translates to:
  /// **'依次尝试'**
  String get logRaceSequential;

  /// No description provided for @logRaceSingle.
  ///
  /// In zh, this message translates to:
  /// **'单服务商'**
  String get logRaceSingle;

  /// No description provided for @providerNoProviderSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择服务商'**
  String get providerNoProviderSelected;

  /// No description provided for @onDemandDisabled.
  ///
  /// In zh, this message translates to:
  /// **'按需连接已关闭，未做改动'**
  String get onDemandDisabled;

  /// No description provided for @onDemandServerMode.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式不使用隧道，未做改动'**
  String get onDemandServerMode;

  /// No description provided for @onDemandUnknownSsid.
  ///
  /// In zh, this message translates to:
  /// **'无法读取当前 Wi-Fi，未做改动'**
  String get onDemandUnknownSsid;

  /// No description provided for @onDemandSameNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络未变化，保持当前 VPN 状态'**
  String get onDemandSameNetwork;

  /// No description provided for @onDemandNoWifi.
  ///
  /// In zh, this message translates to:
  /// **'当前不在 Wi-Fi 上，已断开 VPN'**
  String get onDemandNoWifi;

  /// No description provided for @onDemandStarted.
  ///
  /// In zh, this message translates to:
  /// **'已匹配白名单，VPN 已启动'**
  String get onDemandStarted;

  /// No description provided for @onDemandAlreadyRunning.
  ///
  /// In zh, this message translates to:
  /// **'已匹配白名单，VPN 正在运行'**
  String get onDemandAlreadyRunning;

  /// No description provided for @onDemandStopped.
  ///
  /// In zh, this message translates to:
  /// **'当前网络不在白名单，已断开 VPN'**
  String get onDemandStopped;

  /// No description provided for @onDemandAlreadyStopped.
  ///
  /// In zh, this message translates to:
  /// **'当前网络不在白名单，VPN 未启动'**
  String get onDemandAlreadyStopped;

  /// No description provided for @onDemandBusy.
  ///
  /// In zh, this message translates to:
  /// **'VPN 正在切换状态，稍后再试'**
  String get onDemandBusy;

  /// No description provided for @onDemandNeedsConsent.
  ///
  /// In zh, this message translates to:
  /// **'已匹配白名单，等待系统 VPN 授权'**
  String get onDemandNeedsConsent;

  /// No description provided for @speedTestSelectProvider.
  ///
  /// In zh, this message translates to:
  /// **'请先选择至少一个测速服务商'**
  String get speedTestSelectProvider;

  /// No description provided for @speedTestEmptyDomain.
  ///
  /// In zh, this message translates to:
  /// **'请输入用于测速的域名'**
  String get speedTestEmptyDomain;

  /// No description provided for @imagePickerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前设备没有可用的图片选择器'**
  String get imagePickerUnavailable;

  /// No description provided for @serverModeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先切换到服务器模式'**
  String get serverModeRequired;

  /// No description provided for @serverStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务启动失败'**
  String get serverStartFailed;

  /// No description provided for @serverStartTimeout.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务启动超时'**
  String get serverStartTimeout;

  /// No description provided for @recognitionInvalidConfig.
  ///
  /// In zh, this message translates to:
  /// **'云端名单配置无效'**
  String get recognitionInvalidConfig;

  /// No description provided for @recognitionGithubInterrupted.
  ///
  /// In zh, this message translates to:
  /// **'与 GitHub 的连接被中断，请稍后重试'**
  String get recognitionGithubInterrupted;

  /// No description provided for @recognitionGithubTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接 GitHub 超时，请检查网络后重试'**
  String get recognitionGithubTimeout;

  /// No description provided for @recognitionNetworkUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用，无法更新名单'**
  String get recognitionNetworkUnavailable;

  /// No description provided for @recognitionUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'名单更新失败'**
  String get recognitionUpdateFailed;

  /// No description provided for @subscriptionNotFound.
  ///
  /// In zh, this message translates to:
  /// **'订阅不存在或数据库不可用'**
  String get subscriptionNotFound;

  /// No description provided for @subscriptionDatabaseUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'订阅数据库不可用'**
  String get subscriptionDatabaseUnavailable;

  /// No description provided for @subscriptionRuleDbUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'规则库不可用，下载的规则无法入库'**
  String get subscriptionRuleDbUnavailable;

  /// No description provided for @subscriptionUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get subscriptionUpdateFailed;

  /// No description provided for @subscriptionLocalFileUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取本地文件'**
  String get subscriptionLocalFileUnreadable;

  /// No description provided for @subscriptionLocalRuleDbUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'规则库不可用，本地规则无法入库'**
  String get subscriptionLocalRuleDbUnavailable;

  /// No description provided for @subscriptionNothingToUpdate.
  ///
  /// In zh, this message translates to:
  /// **'没有可更新的订阅'**
  String get subscriptionNothingToUpdate;

  /// No description provided for @subscriptionPickRuleFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个规则文件'**
  String get subscriptionPickRuleFile;

  /// No description provided for @subscriptionPickTxtFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择扩展名为 .txt 的规则文件'**
  String get subscriptionPickTxtFile;

  /// No description provided for @subscriptionLegacyDatabaseMissing.
  ///
  /// In zh, this message translates to:
  /// **'订阅数据库不可用（未找到 1.4.3 数据库）'**
  String get subscriptionLegacyDatabaseMissing;

  /// No description provided for @subscriptionThisFile.
  ///
  /// In zh, this message translates to:
  /// **'该文件'**
  String get subscriptionThisFile;

  /// No description provided for @subscriptionThisLink.
  ///
  /// In zh, this message translates to:
  /// **'该订阅链接'**
  String get subscriptionThisLink;

  /// No description provided for @subscriptionLocalRuleFile.
  ///
  /// In zh, this message translates to:
  /// **'本地规则文件'**
  String get subscriptionLocalRuleFile;

  /// No description provided for @webdavEmptyCredentials.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址与用户名不能为空'**
  String get webdavEmptyCredentials;

  /// No description provided for @webdavDirectoryCreated.
  ///
  /// In zh, this message translates to:
  /// **'目录不存在，已自动创建'**
  String get webdavDirectoryCreated;

  /// No description provided for @webdavUploaded.
  ///
  /// In zh, this message translates to:
  /// **'已上传到云端'**
  String get webdavUploaded;

  /// No description provided for @webdavNoBackup.
  ///
  /// In zh, this message translates to:
  /// **'云端还没有备份文件'**
  String get webdavNoBackup;

  /// No description provided for @webdavDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'已从云端取回备份'**
  String get webdavDownloaded;

  /// No description provided for @updateCheckFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先检查更新'**
  String get updateCheckFirst;

  /// No description provided for @updateDownloadFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先下载更新包'**
  String get updateDownloadFirst;

  /// No description provided for @updateInstallerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法调起系统安装器，请稍后重试'**
  String get updateInstallerUnavailable;

  /// No description provided for @workModeNoDataPlane.
  ///
  /// In zh, this message translates to:
  /// **'当前工作模式尚未接入数据面'**
  String get workModeNoDataPlane;

  /// No description provided for @workModeNoVpnConsent.
  ///
  /// In zh, this message translates to:
  /// **'没有获得 VPN 授权'**
  String get workModeNoVpnConsent;

  /// No description provided for @workModeStartTimeout.
  ///
  /// In zh, this message translates to:
  /// **'服务启动超时'**
  String get workModeStartTimeout;

  /// No description provided for @workModeVpnStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'VPN 启动失败'**
  String get workModeVpnStartFailed;

  /// No description provided for @aiProviderZhipu.
  ///
  /// In zh, this message translates to:
  /// **'智谱 GLM'**
  String get aiProviderZhipu;

  /// No description provided for @aiProviderMoonshot.
  ///
  /// In zh, this message translates to:
  /// **'Kimi（月之暗面）'**
  String get aiProviderMoonshot;

  /// No description provided for @aiProviderDashscope.
  ///
  /// In zh, this message translates to:
  /// **'阿里云百炼（通义千问）'**
  String get aiProviderDashscope;

  /// No description provided for @aiProviderVolcengine.
  ///
  /// In zh, this message translates to:
  /// **'火山方舟（豆包）'**
  String get aiProviderVolcengine;

  /// No description provided for @aiProviderQianfan.
  ///
  /// In zh, this message translates to:
  /// **'百度千帆（ERNIE）'**
  String get aiProviderQianfan;

  /// No description provided for @aiProviderStepfun.
  ///
  /// In zh, this message translates to:
  /// **'阶跃星辰'**
  String get aiProviderStepfun;

  /// No description provided for @aiProviderSiliconflow.
  ///
  /// In zh, this message translates to:
  /// **'硅基流动'**
  String get aiProviderSiliconflow;

  /// No description provided for @aiProviderOllamaLocal.
  ///
  /// In zh, this message translates to:
  /// **'Ollama（本机）'**
  String get aiProviderOllamaLocal;

  /// No description provided for @rulesReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取应用规则失败：{detail}'**
  String rulesReadFailed(Object detail);

  /// No description provided for @autoUpdateChecked.
  ///
  /// In zh, this message translates to:
  /// **'已检查 {count} 个订阅'**
  String autoUpdateChecked(Object count);

  /// No description provided for @caChannelUnavailableDetail.
  ///
  /// In zh, this message translates to:
  /// **'证书通道不可用：{detail}'**
  String caChannelUnavailableDetail(Object detail);

  /// No description provided for @caReadFailedCode.
  ///
  /// In zh, this message translates to:
  /// **'读取根证书失败（{code}）'**
  String caReadFailedCode(Object code);

  /// No description provided for @caReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取根证书失败：{detail}'**
  String caReadFailed(Object detail);

  /// No description provided for @agentAnalysisFailed.
  ///
  /// In zh, this message translates to:
  /// **'分析失败：{detail}'**
  String agentAnalysisFailed(Object detail);

  /// No description provided for @diagnosticsFailedCode.
  ///
  /// In zh, this message translates to:
  /// **'诊断执行失败（{code}）'**
  String diagnosticsFailedCode(Object code);

  /// No description provided for @diagnosticsFailed.
  ///
  /// In zh, this message translates to:
  /// **'诊断执行失败：{detail}'**
  String diagnosticsFailed(Object detail);

  /// No description provided for @subscriptionDeletedWithId.
  ///
  /// In zh, this message translates to:
  /// **'已删除订阅 #{id}'**
  String subscriptionDeletedWithId(Object id);

  /// No description provided for @providerLatencyValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}ms'**
  String providerLatencyValue(Object value);

  /// No description provided for @providerRaceSummaryNames.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 个：{names}'**
  String providerRaceSummaryNames(Object count, Object names);

  /// No description provided for @providerNamesSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get providerNamesSeparator;

  /// No description provided for @recognitionInvalidConfigKept.
  ///
  /// In zh, this message translates to:
  /// **'云端名单配置无效（{detail}），已保留本地缓存'**
  String recognitionInvalidConfigKept(Object detail);

  /// No description provided for @recognitionFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'云端名单拉取失败（{detail}）'**
  String recognitionFetchFailed(Object detail);

  /// No description provided for @recognitionUpdateFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'名单更新失败：{detail}'**
  String recognitionUpdateFailedDetail(Object detail);

  /// No description provided for @subscriptionAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'{what}已作为{kind}存在'**
  String subscriptionAlreadyExists(Object kind, Object what);

  /// No description provided for @subscriptionUpdatedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个已更新'**
  String subscriptionUpdatedCount(Object count);

  /// No description provided for @subscriptionUnchangedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个未变化'**
  String subscriptionUnchangedCount(Object count);

  /// No description provided for @subscriptionFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个失败'**
  String subscriptionFailedCount(Object count);

  /// No description provided for @subscriptionAlreadyExistsNamed.
  ///
  /// In zh, this message translates to:
  /// **'{what}已作为{kind}存在（「{name}」）'**
  String subscriptionAlreadyExistsNamed(Object kind, Object name, Object what);

  /// No description provided for @commonBypass.
  ///
  /// In zh, this message translates to:
  /// **'旁路'**
  String get commonBypass;

  /// No description provided for @commonRewrite.
  ///
  /// In zh, this message translates to:
  /// **'覆写'**
  String get commonRewrite;

  /// No description provided for @cleanupLogs.
  ///
  /// In zh, this message translates to:
  /// **'删除请求日志'**
  String get cleanupLogs;

  /// No description provided for @cleanupTraffic.
  ///
  /// In zh, this message translates to:
  /// **'删除流量统计'**
  String get cleanupTraffic;

  /// No description provided for @cleanupCrash.
  ///
  /// In zh, this message translates to:
  /// **'删除崩溃日志'**
  String get cleanupCrash;

  /// No description provided for @cleanupDnsCache.
  ///
  /// In zh, this message translates to:
  /// **'删除 DNS 缓存'**
  String get cleanupDnsCache;

  /// No description provided for @cleanupProviderWeights.
  ///
  /// In zh, this message translates to:
  /// **'恢复 DNS 默认权重'**
  String get cleanupProviderWeights;

  /// No description provided for @cleanupBootstrapWeights.
  ///
  /// In zh, this message translates to:
  /// **'恢复 Bootstrap 权重'**
  String get cleanupBootstrapWeights;

  /// No description provided for @cleanupDomainRules.
  ///
  /// In zh, this message translates to:
  /// **'删除全部域名规则'**
  String get cleanupDomainRules;

  /// No description provided for @cleanupAddressRules.
  ///
  /// In zh, this message translates to:
  /// **'删除全部地址规则'**
  String get cleanupAddressRules;

  /// No description provided for @cleanupSubscriptions.
  ///
  /// In zh, this message translates to:
  /// **'删除全部规则订阅'**
  String get cleanupSubscriptions;

  /// No description provided for @cleanupAppRules.
  ///
  /// In zh, this message translates to:
  /// **'重置应用控制名单'**
  String get cleanupAppRules;

  /// No description provided for @cleanupOutboundProxy.
  ///
  /// In zh, this message translates to:
  /// **'重置出站代理配置'**
  String get cleanupOutboundProxy;

  /// No description provided for @cleanupCaCertificate.
  ///
  /// In zh, this message translates to:
  /// **'重置 HTTPS 抓包证书'**
  String get cleanupCaCertificate;

  /// No description provided for @cleanupDownloadCache.
  ///
  /// In zh, this message translates to:
  /// **'清理下载与临时缓存'**
  String get cleanupDownloadCache;

  /// No description provided for @cleanupCustomBackground.
  ///
  /// In zh, this message translates to:
  /// **'清除自定义背景缓存'**
  String get cleanupCustomBackground;

  /// No description provided for @cleanupSettingsGuides.
  ///
  /// In zh, this message translates to:
  /// **'重置所有新手引导'**
  String get cleanupSettingsGuides;

  /// No description provided for @cleanupAllData.
  ///
  /// In zh, this message translates to:
  /// **'清理全部本地数据'**
  String get cleanupAllData;

  /// No description provided for @cleanupDoneItems.
  ///
  /// In zh, this message translates to:
  /// **'已{action}：{count} 项{detail}'**
  String cleanupDoneItems(Object action, Object count, Object detail);

  /// No description provided for @cleanupDoneEmpty.
  ///
  /// In zh, this message translates to:
  /// **'已{action}：没有可清理的数据'**
  String cleanupDoneEmpty(Object action);

  /// No description provided for @blockResponseNxdomain.
  ///
  /// In zh, this message translates to:
  /// **'返回 NXDOMAIN'**
  String get blockResponseNxdomain;

  /// No description provided for @blockResponseNxdomainDescription.
  ///
  /// In zh, this message translates to:
  /// **'返回域名不存在，并提供 5 分钟负缓存以减少重复查询'**
  String get blockResponseNxdomainDescription;

  /// No description provided for @blockResponseNodata.
  ///
  /// In zh, this message translates to:
  /// **'返回 NODATA'**
  String get blockResponseNodata;

  /// No description provided for @blockResponseNodataDescription.
  ///
  /// In zh, this message translates to:
  /// **'返回域名存在但没有该记录，并提供 5 分钟负缓存'**
  String get blockResponseNodataDescription;

  /// No description provided for @blockResponseRefused.
  ///
  /// In zh, this message translates to:
  /// **'返回 REFUSED'**
  String get blockResponseRefused;

  /// No description provided for @blockResponseRefusedDescription.
  ///
  /// In zh, this message translates to:
  /// **'返回服务器拒绝该查询，不提供缓存记录'**
  String get blockResponseRefusedDescription;

  /// No description provided for @blockResponseZeroAddress.
  ///
  /// In zh, this message translates to:
  /// **'返回 0.0.0.0 / ::'**
  String get blockResponseZeroAddress;

  /// No description provided for @blockResponseZeroAddressDescription.
  ///
  /// In zh, this message translates to:
  /// **'A 返回 0.0.0.0，AAAA 返回 ::，其他类型返回空结果'**
  String get blockResponseZeroAddressDescription;

  /// No description provided for @subscriptionSourceRemote.
  ///
  /// In zh, this message translates to:
  /// **'网络订阅'**
  String get subscriptionSourceRemote;

  /// No description provided for @subscriptionSourceLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地文件'**
  String get subscriptionSourceLocal;

  /// No description provided for @subscriptionKindDomain.
  ///
  /// In zh, this message translates to:
  /// **'黑白名单规则'**
  String get subscriptionKindDomain;

  /// No description provided for @subscriptionKindHosts.
  ///
  /// In zh, this message translates to:
  /// **'hosts 规则'**
  String get subscriptionKindHosts;

  /// No description provided for @logRowDirect.
  ///
  /// In zh, this message translates to:
  /// **'{protocol} 直连'**
  String logRowDirect(Object protocol);

  /// No description provided for @logRowDirectWithPackage.
  ///
  /// In zh, this message translates to:
  /// **'{protocol} 直连 · {package}'**
  String logRowDirectWithPackage(Object package, Object protocol);

  /// No description provided for @logRowCacheHit.
  ///
  /// In zh, this message translates to:
  /// **'命中缓存'**
  String get logRowCacheHit;

  /// No description provided for @logRowNoAuthority.
  ///
  /// In zh, this message translates to:
  /// **'未取得 authority'**
  String get logRowNoAuthority;

  /// No description provided for @cachePresetConservativeName.
  ///
  /// In zh, this message translates to:
  /// **'保守'**
  String get cachePresetConservativeName;

  /// No description provided for @cachePresetConservativeSummary.
  ///
  /// In zh, this message translates to:
  /// **'遵从服务器有效期 (TTL)'**
  String get cachePresetConservativeSummary;

  /// No description provided for @cachePresetConservativeDescription.
  ///
  /// In zh, this message translates to:
  /// **'遵从 DNS 服务器返回的有效期，不主动延长缓存时间，适合经常切换网络或对实时性敏感的场景。'**
  String get cachePresetConservativeDescription;

  /// No description provided for @cachePresetStandardName.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get cachePresetStandardName;

  /// No description provided for @cachePresetStandardSummary.
  ///
  /// In zh, this message translates to:
  /// **'最长 1 小时，短记录至少 1 分钟'**
  String get cachePresetStandardSummary;

  /// No description provided for @cachePresetStandardDescription.
  ///
  /// In zh, this message translates to:
  /// **'减少重复查询，同时避免记录过期滞后。解析失败时可短暂使用 5 分钟内的旧记录应急。'**
  String get cachePresetStandardDescription;

  /// No description provided for @cachePresetAggressiveName.
  ///
  /// In zh, this message translates to:
  /// **'高命中'**
  String get cachePresetAggressiveName;

  /// No description provided for @cachePresetAggressiveSummary.
  ///
  /// In zh, this message translates to:
  /// **'最长 6 小时，短记录至少 2 分钟'**
  String get cachePresetAggressiveSummary;

  /// No description provided for @cachePresetAggressiveDescription.
  ///
  /// In zh, this message translates to:
  /// **'更偏向降低网络请求次数和提升弱网可用性。域名变更时更新可能会稍慢一些。'**
  String get cachePresetAggressiveDescription;

  /// No description provided for @cacheDisabledSummary.
  ///
  /// In zh, this message translates to:
  /// **'已关闭 · 每次解析都会请求上游'**
  String get cacheDisabledSummary;

  /// No description provided for @upstreamNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get upstreamNameRequired;

  /// No description provided for @upstreamAddressRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写地址'**
  String get upstreamAddressRequired;

  /// No description provided for @upstreamDohNeedsHttps.
  ///
  /// In zh, this message translates to:
  /// **'DoH 地址必须以 https:// 开头'**
  String get upstreamDohNeedsHttps;

  /// No description provided for @upstreamDohInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'DoH 地址不是合法的 URL'**
  String get upstreamDohInvalidUrl;

  /// No description provided for @upstreamPortRange.
  ///
  /// In zh, this message translates to:
  /// **'端口需在 1–65535 之间'**
  String get upstreamPortRange;

  /// No description provided for @upstreamIpv6Invalid.
  ///
  /// In zh, this message translates to:
  /// **'IPv6 地址格式不正确'**
  String get upstreamIpv6Invalid;

  /// No description provided for @upstreamPresetAliyun.
  ///
  /// In zh, this message translates to:
  /// **'阿里云'**
  String get upstreamPresetAliyun;

  /// No description provided for @upstreamPresetTencent.
  ///
  /// In zh, this message translates to:
  /// **'腾讯云 DNSPod'**
  String get upstreamPresetTencent;

  /// No description provided for @upstreamPresetByteDance.
  ///
  /// In zh, this message translates to:
  /// **'字节跳动'**
  String get upstreamPresetByteDance;

  /// No description provided for @cleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理失败：{detail}'**
  String cleanupFailed(Object detail);

  /// No description provided for @cleanupProxyRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复直连'**
  String get cleanupProxyRestored;

  /// No description provided for @cleanupCaNeedsReimport.
  ///
  /// In zh, this message translates to:
  /// **'需重新生成并导入系统证书'**
  String get cleanupCaNeedsReimport;

  /// No description provided for @hubCategoryDns.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务'**
  String get hubCategoryDns;

  /// No description provided for @hubProviderManagement.
  ///
  /// In zh, this message translates to:
  /// **'服务商管理'**
  String get hubProviderManagement;

  /// No description provided for @hubProviderManagementDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置与管理 DoH、DoT 与传统 DNS 解析服务商'**
  String get hubProviderManagementDescription;

  /// No description provided for @hubBootstrap.
  ///
  /// In zh, this message translates to:
  /// **'引导解析设置'**
  String get hubBootstrap;

  /// No description provided for @hubBootstrapDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置用于首次解析加密上游域名的引导 DNS 节点'**
  String get hubBootstrapDescription;

  /// No description provided for @hubResolution.
  ///
  /// In zh, this message translates to:
  /// **'解析模式'**
  String get hubResolution;

  /// No description provided for @hubResolutionDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择单一服务、智能选择、最快响应或依次尝试策略'**
  String get hubResolutionDescription;

  /// No description provided for @hubCache.
  ///
  /// In zh, this message translates to:
  /// **'缓存设置'**
  String get hubCache;

  /// No description provided for @hubCacheDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置 DNS 缓存开关、缓存策略与最大最小生存时间 (TTL)'**
  String get hubCacheDescription;

  /// No description provided for @hubCategoryRules.
  ///
  /// In zh, this message translates to:
  /// **'策略与规则'**
  String get hubCategoryRules;

  /// No description provided for @hubRuleControl.
  ///
  /// In zh, this message translates to:
  /// **'规则控制'**
  String get hubRuleControl;

  /// No description provided for @hubRuleControlDescription.
  ///
  /// In zh, this message translates to:
  /// **'统一管理拦截策略开关与在线网络规则订阅'**
  String get hubRuleControlDescription;

  /// No description provided for @hubBlocklist.
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get hubBlocklist;

  /// No description provided for @hubBlocklistDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义屏蔽域名列表，匹配时返回拦截响应'**
  String get hubBlocklistDescription;

  /// No description provided for @hubAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'白名单'**
  String get hubAllowlist;

  /// No description provided for @hubAllowlistDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义放行域名列表，豁免所有规则直接放行'**
  String get hubAllowlistDescription;

  /// No description provided for @hubRewrite.
  ///
  /// In zh, this message translates to:
  /// **'覆写名单'**
  String get hubRewrite;

  /// No description provided for @hubRewriteDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义域名覆写指向特定 IPv4/IPv6 或 CNAME'**
  String get hubRewriteDescription;

  /// No description provided for @hubCategoryNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络控制'**
  String get hubCategoryNetwork;

  /// No description provided for @hubAppTraffic.
  ///
  /// In zh, this message translates to:
  /// **'应用流量统计'**
  String get hubAppTraffic;

  /// No description provided for @hubAppTrafficDescription.
  ///
  /// In zh, this message translates to:
  /// **'统计各应用的网络连接数、上传与下载流量明细'**
  String get hubAppTrafficDescription;

  /// No description provided for @hubAppRules.
  ///
  /// In zh, this message translates to:
  /// **'应用独立规则'**
  String get hubAppRules;

  /// No description provided for @hubAppRulesDescription.
  ///
  /// In zh, this message translates to:
  /// **'为特定应用单独指定专属域名放行与网络规则'**
  String get hubAppRulesDescription;

  /// No description provided for @hubBlockedApps.
  ///
  /// In zh, this message translates to:
  /// **'禁止联网应用'**
  String get hubBlockedApps;

  /// No description provided for @hubBlockedAppsDescription.
  ///
  /// In zh, this message translates to:
  /// **'在本地隧道层拦截指定应用的全部网络外联'**
  String get hubBlockedAppsDescription;

  /// No description provided for @hubExcludedApps.
  ///
  /// In zh, this message translates to:
  /// **'排除应用'**
  String get hubExcludedApps;

  /// No description provided for @hubExcludedAppsDescription.
  ///
  /// In zh, this message translates to:
  /// **'允许指定应用绕过本软件直连网络'**
  String get hubExcludedAppsDescription;

  /// No description provided for @hubCategoryAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级与诊断'**
  String get hubCategoryAdvanced;

  /// No description provided for @hubHttpsInspection.
  ///
  /// In zh, this message translates to:
  /// **'HTTPS 流量检查'**
  String get hubHttpsInspection;

  /// No description provided for @hubHttpsInspectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'解密并检查特定应用的 HTTP(S) 流量，支持域名与 URL 过滤'**
  String get hubHttpsInspectionDescription;

  /// No description provided for @hubOutboundProxy.
  ///
  /// In zh, this message translates to:
  /// **'出站代理'**
  String get hubOutboundProxy;

  /// No description provided for @hubOutboundProxyDescription.
  ///
  /// In zh, this message translates to:
  /// **'将过滤后的流量转发到本地 SOCKS5 或 HTTP 代理'**
  String get hubOutboundProxyDescription;

  /// No description provided for @hubDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'网络诊断'**
  String get hubDiagnostics;

  /// No description provided for @hubDiagnosticsDescription.
  ///
  /// In zh, this message translates to:
  /// **'提供 DNS 查询、Ping 延迟测试与网络连通性诊断工具'**
  String get hubDiagnosticsDescription;

  /// No description provided for @hubAiAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析'**
  String get hubAiAnalysis;

  /// No description provided for @hubAiAnalysisDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置大语言模型接口与密钥，用于日志研判与网络流量分析'**
  String get hubAiAnalysisDescription;

  /// No description provided for @hubCategoryInterface.
  ///
  /// In zh, this message translates to:
  /// **'界面与设置'**
  String get hubCategoryInterface;

  /// No description provided for @hubAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观调整'**
  String get hubAppearance;

  /// No description provided for @hubAppearanceDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义日夜模式、主题色彩、组件透明度与软件壁纸背景'**
  String get hubAppearanceDescription;

  /// No description provided for @hubProviderVisibility.
  ///
  /// In zh, this message translates to:
  /// **'服务显示'**
  String get hubProviderVisibility;

  /// No description provided for @hubProviderVisibilityDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义在首页解析服务下拉列表中显示的服务商'**
  String get hubProviderVisibilityDescription;

  /// No description provided for @hubHiddenFeatures.
  ///
  /// In zh, this message translates to:
  /// **'隐藏功能'**
  String get hubHiddenFeatures;

  /// No description provided for @hubHiddenFeaturesDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义在功能中心显示的功能卡片，不改后台运行'**
  String get hubHiddenFeaturesDescription;

  /// No description provided for @hubOtherSettings.
  ///
  /// In zh, this message translates to:
  /// **'其他设置'**
  String get hubOtherSettings;

  /// No description provided for @hubOtherSettingsDescription.
  ///
  /// In zh, this message translates to:
  /// **'语言切换、前后台行为、通知设置等全局配置'**
  String get hubOtherSettingsDescription;

  /// No description provided for @hubCategoryData.
  ///
  /// In zh, this message translates to:
  /// **'数据与维护'**
  String get hubCategoryData;

  /// No description provided for @hubLogs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get hubLogs;

  /// No description provided for @hubLogsDescription.
  ///
  /// In zh, this message translates to:
  /// **'实时解析统计、请求明细查询与日志导出'**
  String get hubLogsDescription;

  /// No description provided for @hubBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份与迁移'**
  String get hubBackup;

  /// No description provided for @hubBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'导出与导入服务商、规则订阅及个性化设置'**
  String get hubBackupDescription;

  /// No description provided for @hubDataCleanup.
  ///
  /// In zh, this message translates to:
  /// **'数据清理'**
  String get hubDataCleanup;

  /// No description provided for @hubDataCleanupDescription.
  ///
  /// In zh, this message translates to:
  /// **'删除缓存、日志或域名与地址过滤规则'**
  String get hubDataCleanupDescription;

  /// No description provided for @hubTroubleshooting.
  ///
  /// In zh, this message translates to:
  /// **'故障排查'**
  String get hubTroubleshooting;

  /// No description provided for @hubTroubleshootingDescription.
  ///
  /// In zh, this message translates to:
  /// **'导出崩溃日志，手动抓取并导出运行日志发给开发者'**
  String get hubTroubleshootingDescription;

  /// No description provided for @hubCategoryAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于谛听'**
  String get hubCategoryAbout;

  /// No description provided for @hubAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get hubAbout;

  /// No description provided for @hubAboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看版本信息、检查更新、开源地址与贡献者名单'**
  String get hubAboutDescription;

  /// No description provided for @hubSponsor.
  ///
  /// In zh, this message translates to:
  /// **'赞助'**
  String get hubSponsor;

  /// No description provided for @hubSponsorDescription.
  ///
  /// In zh, this message translates to:
  /// **'支持谛听项目持续维护与开发'**
  String get hubSponsorDescription;

  /// No description provided for @hubSponsors.
  ///
  /// In zh, this message translates to:
  /// **'赞助者名单'**
  String get hubSponsors;

  /// No description provided for @hubSponsorsDescription.
  ///
  /// In zh, this message translates to:
  /// **'鸣谢支持谛听项目的赞助者'**
  String get hubSponsorsDescription;

  /// No description provided for @hubContributors.
  ///
  /// In zh, this message translates to:
  /// **'共建者名单'**
  String get hubContributors;

  /// No description provided for @hubContributorsDescription.
  ///
  /// In zh, this message translates to:
  /// **'感谢为谛听贡献代码与建议的共建者'**
  String get hubContributorsDescription;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get fontSizeStandard;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontSizeLarge;

  /// No description provided for @fontSizeExtraLarge.
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get fontSizeExtraLarge;

  /// No description provided for @fontSizeFooter.
  ///
  /// In zh, this message translates to:
  /// **'字号会同时放大正文、标题与列表行，不会改变系统设置；界面已按所选比例排版，无需重启。'**
  String get fontSizeFooter;

  /// No description provided for @fontSizePreview.
  ///
  /// In zh, this message translates to:
  /// **'实时预览'**
  String get fontSizePreview;

  /// No description provided for @appearancePoem.
  ///
  /// In zh, this message translates to:
  /// **'谛听万象，明察清浊'**
  String get appearancePoem;

  /// No description provided for @appearancePoemBody.
  ///
  /// In zh, this message translates to:
  /// **'网络连通性、规则命中与设备状态，都在这一页里说清楚。'**
  String get appearancePoemBody;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get appearanceTitle;

  /// No description provided for @appearanceInterfaceSection.
  ///
  /// In zh, this message translates to:
  /// **'界面显示'**
  String get appearanceInterfaceSection;

  /// No description provided for @appearanceHomeOpacitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'交互组件与文字的透明度'**
  String get appearanceHomeOpacitySubtitle;

  /// No description provided for @appearancePureBlackOn.
  ///
  /// In zh, this message translates to:
  /// **'深色表面折叠为纯黑，OLED 更省电'**
  String get appearancePureBlackOn;

  /// No description provided for @appearancePureBlackOff.
  ///
  /// In zh, this message translates to:
  /// **'切到深色模式后才可开启'**
  String get appearancePureBlackOff;

  /// No description provided for @appearanceHomeSection.
  ///
  /// In zh, this message translates to:
  /// **'首页内容'**
  String get appearanceHomeSection;

  /// No description provided for @appearanceHomeSentenceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'运行与停止两种状态各一句'**
  String get appearanceHomeSentenceSubtitle;

  /// No description provided for @appearanceNotification.
  ///
  /// In zh, this message translates to:
  /// **'通知栏设置'**
  String get appearanceNotification;

  /// No description provided for @appearanceNotificationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'常驻通知、实时速率与自定义文案'**
  String get appearanceNotificationSubtitle;

  /// No description provided for @appearanceBackgroundSection.
  ///
  /// In zh, this message translates to:
  /// **'背景与动效'**
  String get appearanceBackgroundSection;

  /// No description provided for @appearanceHapticSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换 tab 时给一次轻震'**
  String get appearanceHapticSubtitle;

  /// No description provided for @appearanceBottomBarStyleFloating.
  ///
  /// In zh, this message translates to:
  /// **'浮在页面之上'**
  String get appearanceBottomBarStyleFloating;

  /// No description provided for @appearanceBottomBarStyleDocked.
  ///
  /// In zh, this message translates to:
  /// **'贴底排列'**
  String get appearanceBottomBarStyleDocked;

  /// No description provided for @appearanceTabTransitionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换底部标签时的动画方式'**
  String get appearanceTabTransitionSubtitle;

  /// No description provided for @appearanceMotionFooter.
  ///
  /// In zh, this message translates to:
  /// **'底栏样式、动画与玻璃只作用于浮条；普通底栏始终是实色。'**
  String get appearanceMotionFooter;

  /// No description provided for @appearancePaletteGoldLegacy.
  ///
  /// In zh, this message translates to:
  /// **'落盘值沿用旧版的 indigo'**
  String get appearancePaletteGoldLegacy;

  /// No description provided for @appearancePaletteFooter.
  ///
  /// In zh, this message translates to:
  /// **'色板只提供种子，上屏的是 HCT 推导出的整套角色色。旧版没有自定义取色，因此这里也不提供。'**
  String get appearancePaletteFooter;

  /// No description provided for @fontFamilySizeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前 {percent}%'**
  String fontFamilySizeSubtitle(Object percent);

  /// No description provided for @fontFamilySystemDefault.
  ///
  /// In zh, this message translates to:
  /// **'跟随宿主平台的中文界面字体，最稳妥的选择'**
  String get fontFamilySystemDefault;

  /// No description provided for @fontFamilyImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入的第三方字体'**
  String get fontFamilyImported;

  /// No description provided for @fontFamilyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有导入字体。导入后即可在这里切换，字体文件只保存在本机。'**
  String get fontFamilyEmpty;

  /// No description provided for @fontFamilyFooter.
  ///
  /// In zh, this message translates to:
  /// **'导入的字体只影响本机显示，删除后会自动回退到系统默认。'**
  String get fontFamilyFooter;

  /// No description provided for @fontFamilyLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'选择只影响本机显示，不改动服务端规则。'**
  String get fontFamilyLocalOnly;

  /// No description provided for @fontFamilyImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get fontFamilyImportFailed;

  /// No description provided for @fontFamilyDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除字体'**
  String get fontFamilyDeleteTitle;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @fontFamilyDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」后，使用该字体的界面会回退到系统默认。'**
  String fontFamilyDeleteConfirm(Object name);

  /// No description provided for @fontFamilyImport.
  ///
  /// In zh, this message translates to:
  /// **'导入字体'**
  String get fontFamilyImport;

  /// No description provided for @fontFamilyReading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取字体文件…'**
  String get fontFamilyReading;

  /// No description provided for @fontFamilyPickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择本机的 TTF / OTF 文件'**
  String get fontFamilyPickFile;

  /// No description provided for @notificationPersistentSection.
  ///
  /// In zh, this message translates to:
  /// **'常驻通知'**
  String get notificationPersistentSection;

  /// No description provided for @notificationPersistentFooter.
  ///
  /// In zh, this message translates to:
  /// **'关闭后服务运行时不再显示常驻通知，系统可能因此更快回收进程。'**
  String get notificationPersistentFooter;

  /// No description provided for @notificationPersistent.
  ///
  /// In zh, this message translates to:
  /// **'通知常驻'**
  String get notificationPersistent;

  /// No description provided for @notificationPersistentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务运行时保留一条不可划掉的通知'**
  String get notificationPersistentSubtitle;

  /// No description provided for @notificationShowSpeed.
  ///
  /// In zh, this message translates to:
  /// **'显示实时速率'**
  String get notificationShowSpeed;

  /// No description provided for @notificationShowSpeedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在通知里显示当前上下行速率'**
  String get notificationShowSpeedSubtitle;

  /// No description provided for @notificationTextRunning.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务开启时'**
  String get notificationTextRunning;

  /// No description provided for @notificationTextStopped.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务关闭时'**
  String get notificationTextStopped;

  /// No description provided for @notificationTextHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用默认文案'**
  String get notificationTextHint;

  /// No description provided for @notificationTextFooter.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用默认文案；文案只影响通知栏，不改变服务行为。'**
  String get notificationTextFooter;

  /// No description provided for @notificationPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限'**
  String get notificationPermissions;

  /// No description provided for @notificationSystemPermission.
  ///
  /// In zh, this message translates to:
  /// **'系统通知权限'**
  String get notificationSystemPermission;

  /// No description provided for @notificationSystemPermissionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开系统的通知设置页'**
  String get notificationSystemPermissionSubtitle;

  /// No description provided for @backgroundTitle.
  ///
  /// In zh, this message translates to:
  /// **'软件背景'**
  String get backgroundTitle;

  /// No description provided for @backgroundSection.
  ///
  /// In zh, this message translates to:
  /// **'自定义背景'**
  String get backgroundSection;

  /// No description provided for @backgroundFooter.
  ///
  /// In zh, this message translates to:
  /// **'壁纸只保存在本机，不随备份导出。'**
  String get backgroundFooter;

  /// No description provided for @backgroundEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用自定义背景'**
  String get backgroundEnable;

  /// No description provided for @backgroundPickFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先添加一张图片'**
  String get backgroundPickFirst;

  /// No description provided for @backgroundBehindPages.
  ///
  /// In zh, this message translates to:
  /// **'在全部页面下垫一层壁纸'**
  String get backgroundBehindPages;

  /// No description provided for @backgroundAddImage.
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get backgroundAddImage;

  /// No description provided for @backgroundAddImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择一张'**
  String get backgroundAddImageSubtitle;

  /// No description provided for @backgroundAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加壁纸'**
  String get backgroundAdded;

  /// No description provided for @backgroundAddedFooter.
  ///
  /// In zh, this message translates to:
  /// **'点一下切换，长按删除。'**
  String get backgroundAddedFooter;

  /// No description provided for @backgroundEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有背景图'**
  String get backgroundEmpty;

  /// No description provided for @backgroundEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'点「添加图片」从相册里挑一张。'**
  String get backgroundEmptyDescription;

  /// No description provided for @backgroundDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除壁纸'**
  String get backgroundDeleteTitle;

  /// No description provided for @backgroundDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这张已添加的壁纸吗？'**
  String get backgroundDeleteConfirm;

  /// No description provided for @foregroundTitle.
  ///
  /// In zh, this message translates to:
  /// **'前后台行为'**
  String get foregroundTitle;

  /// No description provided for @foregroundPrivacySection.
  ///
  /// In zh, this message translates to:
  /// **'后台与隐私'**
  String get foregroundPrivacySection;

  /// No description provided for @foregroundPrivacyFooter.
  ///
  /// In zh, this message translates to:
  /// **'「后台隐藏」会从最近任务列表里移除本应用；下次从桌面图标进入即可。'**
  String get foregroundPrivacyFooter;

  /// No description provided for @foregroundHide.
  ///
  /// In zh, this message translates to:
  /// **'后台隐藏'**
  String get foregroundHide;

  /// No description provided for @foregroundHideSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不在最近任务列表中显示'**
  String get foregroundHideSubtitle;

  /// No description provided for @foregroundRouting.
  ///
  /// In zh, this message translates to:
  /// **'路由'**
  String get foregroundRouting;

  /// No description provided for @foregroundBypassLan.
  ///
  /// In zh, this message translates to:
  /// **'绕过局域网'**
  String get foregroundBypassLan;

  /// No description provided for @foregroundBypassLanSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地网段与本机地址不走隧道'**
  String get foregroundBypassLanSubtitle;

  /// No description provided for @foregroundStability.
  ///
  /// In zh, this message translates to:
  /// **'稳定性'**
  String get foregroundStability;

  /// No description provided for @foregroundBatteryFooter.
  ///
  /// In zh, this message translates to:
  /// **'关闭电池优化后，系统在后台更不容易回收服务进程。'**
  String get foregroundBatteryFooter;

  /// No description provided for @foregroundIgnoreBattery.
  ///
  /// In zh, this message translates to:
  /// **'忽略电池优化'**
  String get foregroundIgnoreBattery;

  /// No description provided for @foregroundIgnoreBatterySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请求把本应用加入系统白名单'**
  String get foregroundIgnoreBatterySubtitle;

  /// No description provided for @dayNightTitle.
  ///
  /// In zh, this message translates to:
  /// **'日夜模式'**
  String get dayNightTitle;

  /// No description provided for @dayNightFollowSystemDescription.
  ///
  /// In zh, this message translates to:
  /// **'系统切换深色时一起切换'**
  String get dayNightFollowSystemDescription;

  /// No description provided for @dayNightFooter.
  ///
  /// In zh, this message translates to:
  /// **'纯黑只在深色模式下生效，开关在「外观设置」的界面显示组里。'**
  String get dayNightFooter;

  /// No description provided for @homeOpacityTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页透明度'**
  String get homeOpacityTitle;

  /// No description provided for @homeOpacityComponents.
  ///
  /// In zh, this message translates to:
  /// **'交互组件'**
  String get homeOpacityComponents;

  /// No description provided for @homeOpacityComponentsFooter.
  ///
  /// In zh, this message translates to:
  /// **'透明度只影响可见度，不影响这些组件的点击区域。'**
  String get homeOpacityComponentsFooter;

  /// No description provided for @homeOpacityText.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get homeOpacityText;

  /// No description provided for @bottomBarHomeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'首页与仪表盘'**
  String get bottomBarHomeSubtitle;

  /// No description provided for @bottomBarFeatureHubSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'全部功能入口'**
  String get bottomBarFeatureHubSubtitle;

  /// No description provided for @bottomBarLogDashboardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'日志仪表盘'**
  String get bottomBarLogDashboardSubtitle;

  /// No description provided for @bottomBarAppTrafficSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'应用流量排行'**
  String get bottomBarAppTrafficSubtitle;

  /// No description provided for @bottomBarNetworkToolsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'测速与网络诊断'**
  String get bottomBarNetworkToolsSubtitle;

  /// No description provided for @bottomBarSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'全部设置项'**
  String get bottomBarSettingsSubtitle;

  /// No description provided for @bottomBarMinimumHint.
  ///
  /// In zh, this message translates to:
  /// **'底栏至少保留 2 项'**
  String get bottomBarMinimumHint;

  /// No description provided for @bottomBarCustomTitle.
  ///
  /// In zh, this message translates to:
  /// **'底栏自定义'**
  String get bottomBarCustomTitle;

  /// No description provided for @bottomBarItemsHeader.
  ///
  /// In zh, this message translates to:
  /// **'底栏项（{count}/{max}）'**
  String bottomBarItemsHeader(Object count, Object max);

  /// No description provided for @bottomBarDragHint.
  ///
  /// In zh, this message translates to:
  /// **'按住右侧把手或长按整行拖动排序，顺序即底栏从左到右的顺序。至少 2 项、最多 {max} 项：浮条按项数等比分配宽度，再多就挤到看不清图标。'**
  String bottomBarDragHint(Object max);

  /// No description provided for @bottomBarDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get bottomBarDisabled;

  /// No description provided for @bottomBarNewItemFooter.
  ///
  /// In zh, this message translates to:
  /// **'新启用的项排在底栏最右侧。'**
  String get bottomBarNewItemFooter;

  /// No description provided for @bottomBarFeel.
  ///
  /// In zh, this message translates to:
  /// **'手感'**
  String get bottomBarFeel;

  /// No description provided for @homeSentenceTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页句子'**
  String get homeSentenceTitle;

  /// No description provided for @homeSentenceFooter.
  ///
  /// In zh, this message translates to:
  /// **'两项均可留空；留空后对应状态下首页不显示句子，句子只在首页电源区下方出现一次。'**
  String get homeSentenceFooter;

  /// No description provided for @appearancePaletteTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题色配置'**
  String get appearancePaletteTitle;

  /// No description provided for @appearancePaletteInfoLabel.
  ///
  /// In zh, this message translates to:
  /// **'色板'**
  String get appearancePaletteInfoLabel;

  /// No description provided for @appearancePaletteBody.
  ///
  /// In zh, this message translates to:
  /// **'色板只提供种子，上屏的是 HCT 推导出的整套角色色。旧版没有自定义取色，因此这里也不提供。'**
  String get appearancePaletteBody;

  /// No description provided for @dayNightInfoLabel.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get dayNightInfoLabel;

  /// No description provided for @appearanceFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get appearanceFontSizeLabel;

  /// No description provided for @appearanceFontSizeCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前 {percent}%'**
  String appearanceFontSizeCurrent(Object percent);

  /// No description provided for @appearanceFontSection.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get appearanceFontSection;

  /// No description provided for @appearanceFontImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {name}'**
  String appearanceFontImported(Object name);

  /// No description provided for @appearanceFontDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {name}'**
  String appearanceFontDeleted(Object name);

  /// No description provided for @appearanceBottomBarMax.
  ///
  /// In zh, this message translates to:
  /// **'底栏最多 {max} 项'**
  String appearanceBottomBarMax(Object max);

  /// No description provided for @appearanceBottomBarHeader.
  ///
  /// In zh, this message translates to:
  /// **'底栏项（{count}/{max}）'**
  String appearanceBottomBarHeader(Object count, Object max);

  /// No description provided for @appearanceBottomBarDragBody.
  ///
  /// In zh, this message translates to:
  /// **'按住右侧把手或长按整行拖动排序，顺序即底栏从左到右的顺序。至少 2 项、最多 {max} 项：浮条按项数等比分配宽度，再多就挤到看不清图标。'**
  String appearanceBottomBarDragBody(Object max);

  /// No description provided for @appearanceBottomBarSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项，可配置 2–4 项'**
  String appearanceBottomBarSelected(Object count);

  /// No description provided for @appearanceHaptic.
  ///
  /// In zh, this message translates to:
  /// **'底栏触感反馈'**
  String get appearanceHaptic;

  /// No description provided for @appearancePureBlack.
  ///
  /// In zh, this message translates to:
  /// **'纯黑'**
  String get appearancePureBlack;

  /// No description provided for @appearanceBottomBarStyle.
  ///
  /// In zh, this message translates to:
  /// **'底栏样式'**
  String get appearanceBottomBarStyle;

  /// No description provided for @appearanceTabTransition.
  ///
  /// In zh, this message translates to:
  /// **'tab 切换动画'**
  String get appearanceTabTransition;

  /// No description provided for @appearanceLiquidGlass.
  ///
  /// In zh, this message translates to:
  /// **'Liquid 玻璃'**
  String get appearanceLiquidGlass;

  /// No description provided for @fontFamilyTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体设置'**
  String get fontFamilyTitle;

  /// No description provided for @fontSizeRestoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get fontSizeRestoreDefaults;

  /// No description provided for @fontFamilyHapticSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换 tab 时给一次轻震'**
  String get fontFamilyHapticSubtitle;

  /// No description provided for @ruleKindBlockTitle.
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get ruleKindBlockTitle;

  /// No description provided for @ruleKindBlockSummary.
  ///
  /// In zh, this message translates to:
  /// **'拦截匹配的域名'**
  String get ruleKindBlockSummary;

  /// No description provided for @ruleKindAllowTitle.
  ///
  /// In zh, this message translates to:
  /// **'白名单'**
  String get ruleKindAllowTitle;

  /// No description provided for @ruleKindAllowSummary.
  ///
  /// In zh, this message translates to:
  /// **'放行匹配的域名'**
  String get ruleKindAllowSummary;

  /// No description provided for @ruleKindRewriteTitle.
  ///
  /// In zh, this message translates to:
  /// **'覆写'**
  String get ruleKindRewriteTitle;

  /// No description provided for @ruleKindRewriteSummary.
  ///
  /// In zh, this message translates to:
  /// **'改写域名解析结果'**
  String get ruleKindRewriteSummary;

  /// No description provided for @ruleSourceUser.
  ///
  /// In zh, this message translates to:
  /// **'用户自定义'**
  String get ruleSourceUser;

  /// No description provided for @ruleSourceSubscription.
  ///
  /// In zh, this message translates to:
  /// **'规则订阅'**
  String get ruleSourceSubscription;

  /// No description provided for @ruleSourcePreset.
  ///
  /// In zh, this message translates to:
  /// **'内置预设'**
  String get ruleSourcePreset;

  /// No description provided for @rulePatternRequired.
  ///
  /// In zh, this message translates to:
  /// **'规则内容不能为空'**
  String get rulePatternRequired;

  /// No description provided for @ruleAllowNeedsAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'该规则为放行规则，请在白名单中添加'**
  String get ruleAllowNeedsAllowlist;

  /// No description provided for @ruleAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'该规则已存在'**
  String get ruleAlreadyExists;

  /// No description provided for @ruleDomainHint.
  ///
  /// In zh, this message translates to:
  /// **'域名，如 cdn.example.com'**
  String get ruleDomainHint;

  /// No description provided for @ruleTargetRequired.
  ///
  /// In zh, this message translates to:
  /// **'目标值不能为空'**
  String get ruleTargetRequired;

  /// No description provided for @ruleTargetHint.
  ///
  /// In zh, this message translates to:
  /// **'目标值，如 10.0.0.8'**
  String get ruleTargetHint;

  /// No description provided for @ruleImportant.
  ///
  /// In zh, this message translates to:
  /// **'重要'**
  String get ruleImportant;

  /// No description provided for @ruleReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'只读'**
  String get ruleReadOnly;

  /// No description provided for @ruleEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑规则'**
  String get ruleEdit;

  /// No description provided for @ruleDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除规则'**
  String get ruleDelete;

  /// No description provided for @batchImportDone.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get batchImportDone;

  /// No description provided for @batchAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量添加规则'**
  String get batchAddTitle;

  /// No description provided for @batchTarget.
  ///
  /// In zh, this message translates to:
  /// **'导入到'**
  String get batchTarget;

  /// No description provided for @batchTargetTable.
  ///
  /// In zh, this message translates to:
  /// **'目标规则表'**
  String get batchTargetTable;

  /// No description provided for @batchTargetTableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入的规则将写入所选规则表'**
  String get batchTargetTableSubtitle;

  /// No description provided for @batchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'每行一条规则，例如：\n||ads.example.com^\n\n空行会被忽略，重复规则自动跳过。'**
  String get batchPlaceholder;

  /// No description provided for @batchImportable.
  ///
  /// In zh, this message translates to:
  /// **'可导入'**
  String get batchImportable;

  /// No description provided for @batchDuplicated.
  ///
  /// In zh, this message translates to:
  /// **'重复'**
  String get batchDuplicated;

  /// No description provided for @batchInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无效'**
  String get batchInvalid;

  /// No description provided for @batchInvalidHeader.
  ///
  /// In zh, this message translates to:
  /// **'以下规则未通过校验'**
  String get batchInvalidHeader;

  /// No description provided for @batchDuplicateHeader.
  ///
  /// In zh, this message translates to:
  /// **'已存在，将跳过'**
  String get batchDuplicateHeader;

  /// No description provided for @ruleClearCustomTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空自定义规则'**
  String get ruleClearCustomTitle;

  /// No description provided for @commonClearAll.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClearAll;

  /// No description provided for @ruleResetDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置默认白名单'**
  String get ruleResetDefault;

  /// No description provided for @commonReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get commonReset;

  /// No description provided for @rulePresetProtectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'预设规则受保护'**
  String get rulePresetProtectedTitle;

  /// No description provided for @ruleAllowEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'允许编辑默认白名单？'**
  String get ruleAllowEditTitle;

  /// No description provided for @ruleAllowEditConfirm.
  ///
  /// In zh, this message translates to:
  /// **'仍然开启'**
  String get ruleAllowEditConfirm;

  /// No description provided for @ruleTotal.
  ///
  /// In zh, this message translates to:
  /// **'规则总数'**
  String get ruleTotal;

  /// No description provided for @ruleEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get ruleEnabled;

  /// No description provided for @ruleRewriteEntries.
  ///
  /// In zh, this message translates to:
  /// **'覆写条目'**
  String get ruleRewriteEntries;

  /// No description provided for @ruleCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get ruleCustom;

  /// No description provided for @ruleAllowEditDefault.
  ///
  /// In zh, this message translates to:
  /// **'允许编辑默认白名单'**
  String get ruleAllowEditDefault;

  /// No description provided for @ruleAllowEditDefaultSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭时预设规则只读，避免误放宽放行范围'**
  String get ruleAllowEditDefaultSubtitle;

  /// No description provided for @ruleNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的规则'**
  String get ruleNoMatch;

  /// No description provided for @ruleNoMatchDescription.
  ///
  /// In zh, this message translates to:
  /// **'换个关键词或筛选条件再试'**
  String get ruleNoMatchDescription;

  /// No description provided for @ruleAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get ruleAll;

  /// No description provided for @formIssuesTitle.
  ///
  /// In zh, this message translates to:
  /// **'有几点需要先修正'**
  String get formIssuesTitle;

  /// No description provided for @formSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get formSave;

  /// No description provided for @formProcessing.
  ///
  /// In zh, this message translates to:
  /// **'处理中…'**
  String get formProcessing;

  /// No description provided for @formAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get formAdd;

  /// No description provided for @formDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get formDelete;

  /// No description provided for @formHelp.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get formHelp;

  /// No description provided for @formGotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get formGotIt;

  /// No description provided for @rulePatternHint.
  ///
  /// In zh, this message translates to:
  /// **'规则内容，如 ||ads.example.com^'**
  String get rulePatternHint;

  /// No description provided for @ruleBatchImported.
  ///
  /// In zh, this message translates to:
  /// **'已向{kind}导入 {count} 条规则。'**
  String ruleBatchImported(Object count, Object kind);

  /// No description provided for @ruleBatchSkippedDuplicates.
  ///
  /// In zh, this message translates to:
  /// **'跳过 {count} 条重复规则。'**
  String ruleBatchSkippedDuplicates(Object count);

  /// No description provided for @ruleBatchAllowRejected.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条放行规则（含 #@#）未导入：该规则为放行规则，请在白名单中添加。'**
  String ruleBatchAllowRejected(Object count);

  /// No description provided for @ruleBatchImportCount.
  ///
  /// In zh, this message translates to:
  /// **'导入 {count} 条'**
  String ruleBatchImportCount(Object count);

  /// No description provided for @ruleBatchMoreDuplicates.
  ///
  /// In zh, this message translates to:
  /// **'等 {count} 条'**
  String ruleBatchMoreDuplicates(Object count);

  /// No description provided for @ruleAddForKind.
  ///
  /// In zh, this message translates to:
  /// **'添加{kind}规则'**
  String ruleAddForKind(Object kind);

  /// No description provided for @ruleEditDefaultPreset.
  ///
  /// In zh, this message translates to:
  /// **'编辑默认预设规则'**
  String get ruleEditDefaultPreset;

  /// No description provided for @ruleEditForKind.
  ///
  /// In zh, this message translates to:
  /// **'编辑{kind}规则'**
  String ruleEditForKind(Object kind);

  /// No description provided for @ruleDeletePresetMessage.
  ///
  /// In zh, this message translates to:
  /// **'「{pattern}」是内置预设规则，删除后可通过重置默认恢复。'**
  String ruleDeletePresetMessage(Object pattern);

  /// No description provided for @ruleDeleteSubscriptionMessage.
  ///
  /// In zh, this message translates to:
  /// **'「{pattern}」来自订阅「{name}」，删除后下次更新订阅可能重新出现。'**
  String ruleDeleteSubscriptionMessage(Object name, Object pattern);

  /// No description provided for @ruleDeleteUserMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{pattern}」吗？此操作不可撤销。'**
  String ruleDeleteUserMessage(Object pattern);

  /// No description provided for @ruleClearCustomMessage.
  ///
  /// In zh, this message translates to:
  /// **'将删除全部用户自定义的{kind}规则，订阅与预设规则不受影响。'**
  String ruleClearCustomMessage(Object kind);

  /// No description provided for @ruleResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'将内置预设规则恢复为初始内容，你自己添加与订阅带来的规则保留。'**
  String get ruleResetMessage;

  /// No description provided for @rulePresetProtectedMessage.
  ///
  /// In zh, this message translates to:
  /// **'默认白名单规则处于只读状态。请先开启页面顶部的「允许编辑默认白名单」开关，再修改或删除这些规则。'**
  String get rulePresetProtectedMessage;

  /// No description provided for @ruleAllowEditMessage.
  ///
  /// In zh, this message translates to:
  /// **'白名单是放行名单，改动它可能让本应被拦截的流量通过。确认你清楚这条风险后再开启。'**
  String get ruleAllowEditMessage;

  /// No description provided for @ruleTally.
  ///
  /// In zh, this message translates to:
  /// **'共 {matched} 条 · 启用 {enabled}'**
  String ruleTally(Object enabled, Object matched);

  /// No description provided for @ruleNoRulesForKind.
  ///
  /// In zh, this message translates to:
  /// **'还没有{kind}规则'**
  String ruleNoRulesForKind(Object kind);

  /// No description provided for @ruleClearCustomForKind.
  ///
  /// In zh, this message translates to:
  /// **'清空自定义{kind}'**
  String ruleClearCustomForKind(Object kind);

  /// No description provided for @subsPickTxt.
  ///
  /// In zh, this message translates to:
  /// **'请选择扩展名为 .txt 的规则文件'**
  String get subsPickTxt;

  /// No description provided for @subsNoPersistPermission.
  ///
  /// In zh, this message translates to:
  /// **'系统未授予长期读取权限，更新时需要重新选择文件'**
  String get subsNoPersistPermission;

  /// No description provided for @subsGroupNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'分组名称不能为空'**
  String get subsGroupNameRequired;

  /// No description provided for @subsEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑订阅'**
  String get subsEdit;

  /// No description provided for @subsAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加订阅'**
  String get subsAdd;

  /// No description provided for @subsSaveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存订阅'**
  String get subsSaveTooltip;

  /// No description provided for @subsInfoSection.
  ///
  /// In zh, this message translates to:
  /// **'订阅信息'**
  String get subsInfoSection;

  /// No description provided for @subsSourceType.
  ///
  /// In zh, this message translates to:
  /// **'订阅方式'**
  String get subsSourceType;

  /// No description provided for @subsSourceLocalPick.
  ///
  /// In zh, this message translates to:
  /// **'从存储中选择一个 .txt 文件'**
  String get subsSourceLocalPick;

  /// No description provided for @subsSourceRemoteDownload.
  ///
  /// In zh, this message translates to:
  /// **'从网络地址下载规则正文'**
  String get subsSourceRemoteDownload;

  /// No description provided for @subsLocalRuleFile.
  ///
  /// In zh, this message translates to:
  /// **'本地规则文件'**
  String get subsLocalRuleFile;

  /// No description provided for @subsLocalFileSubscription.
  ///
  /// In zh, this message translates to:
  /// **'本地文件订阅'**
  String get subsLocalFileSubscription;

  /// No description provided for @subsPickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择规则文件'**
  String get subsPickFile;

  /// No description provided for @subsLocalFileHint.
  ///
  /// In zh, this message translates to:
  /// **'仅支持 .txt，点击从存储中选择'**
  String get subsLocalFileHint;

  /// No description provided for @subsLocalFileRepick.
  ///
  /// In zh, this message translates to:
  /// **'点击可重新选择文件'**
  String get subsLocalFileRepick;

  /// No description provided for @subsChoose.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get subsChoose;

  /// No description provided for @subsNameOptional.
  ///
  /// In zh, this message translates to:
  /// **'名称（可选）'**
  String get subsNameOptional;

  /// No description provided for @subsNameEmptyFileName.
  ///
  /// In zh, this message translates to:
  /// **'留空则取文件名'**
  String get subsNameEmptyFileName;

  /// No description provided for @subsUrl.
  ///
  /// In zh, this message translates to:
  /// **'订阅地址'**
  String get subsUrl;

  /// No description provided for @subsNameEmptyUrlTail.
  ///
  /// In zh, this message translates to:
  /// **'留空则取链接末段'**
  String get subsNameEmptyUrlTail;

  /// No description provided for @subsRuleType.
  ///
  /// In zh, this message translates to:
  /// **'规则类型'**
  String get subsRuleType;

  /// No description provided for @subsKindHostsHint.
  ///
  /// In zh, this message translates to:
  /// **'仅导入 hosts 地址与 CNAME 覆写规则'**
  String get subsKindHostsHint;

  /// No description provided for @subsKindDomainHint.
  ///
  /// In zh, this message translates to:
  /// **'导入域名规则与黑白名单'**
  String get subsKindDomainHint;

  /// No description provided for @subsGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'分组只影响订阅页的筛选与批量更新，可稍后调整。'**
  String get subsGroupHint;

  /// No description provided for @subsNewGroupShort.
  ///
  /// In zh, this message translates to:
  /// **'+ 新建'**
  String get subsNewGroupShort;

  /// No description provided for @subsMirrorTemplateFooter.
  ///
  /// In zh, this message translates to:
  /// **'镜像地址会把原始订阅地址改写成镜像前缀，常用于加速 GitHub 等慢速源。'**
  String get subsMirrorTemplateFooter;

  /// No description provided for @subsAddMirrorTemplate.
  ///
  /// In zh, this message translates to:
  /// **'添加镜像站模板'**
  String get subsAddMirrorTemplate;

  /// No description provided for @subsAddMirrorTemplateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有模板，先去保存一个常用的镜像前缀'**
  String get subsAddMirrorTemplateSubtitle;

  /// No description provided for @subsMirrorFooter.
  ///
  /// In zh, this message translates to:
  /// **'下载时先请求镜像地址；镜像失败且开启回退时，再试原始地址。'**
  String get subsMirrorFooter;

  /// No description provided for @subsUseMirrorTemplate.
  ///
  /// In zh, this message translates to:
  /// **'使用镜像站模板'**
  String get subsUseMirrorTemplate;

  /// No description provided for @subsUseMirrorTemplateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅源较慢或被限速时，改写下载地址'**
  String get subsUseMirrorTemplateSubtitle;

  /// No description provided for @subsMirrorTemplate.
  ///
  /// In zh, this message translates to:
  /// **'镜像模板'**
  String get subsMirrorTemplate;

  /// No description provided for @subsMirrorFallback.
  ///
  /// In zh, this message translates to:
  /// **'失败后回退直连'**
  String get subsMirrorFallback;

  /// No description provided for @subsMirrorFallbackSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'镜像请求失败时，改用原始订阅地址'**
  String get subsMirrorFallbackSubtitle;

  /// No description provided for @subsEffectiveUrl.
  ///
  /// In zh, this message translates to:
  /// **'实际请求地址'**
  String get subsEffectiveUrl;

  /// No description provided for @subsNothingToUpdate.
  ///
  /// In zh, this message translates to:
  /// **'没有可更新的远程订阅'**
  String get subsNothingToUpdate;

  /// No description provided for @subsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除订阅'**
  String get subsDeleteTitle;

  /// No description provided for @subsRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名订阅'**
  String get subsRenameTitle;

  /// No description provided for @subsNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空'**
  String get subsNameRequired;

  /// No description provided for @subsTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get subsTitle;

  /// No description provided for @subsUpdateAll.
  ///
  /// In zh, this message translates to:
  /// **'更新全部订阅'**
  String get subsUpdateAll;

  /// No description provided for @subsCount.
  ///
  /// In zh, this message translates to:
  /// **'订阅数'**
  String get subsCount;

  /// No description provided for @subsRuleCount.
  ///
  /// In zh, this message translates to:
  /// **'已入库规则'**
  String get subsRuleCount;

  /// No description provided for @subsAbnormal.
  ///
  /// In zh, this message translates to:
  /// **'异常'**
  String get subsAbnormal;

  /// No description provided for @subsUpdating.
  ///
  /// In zh, this message translates to:
  /// **'正在更新订阅…'**
  String get subsUpdating;

  /// No description provided for @subsEmptyLabel.
  ///
  /// In zh, this message translates to:
  /// **'还没有订阅'**
  String get subsEmptyLabel;

  /// No description provided for @subsEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'订阅可以批量维护规则；更新会下载正文、解析并写入规则库，拦截随之生效。'**
  String get subsEmptyDescription;

  /// No description provided for @subsUpdateFooter.
  ///
  /// In zh, this message translates to:
  /// **'更新会下载正文、解析成黑/白名单与覆写规则并写入规则库，同时替换该订阅上一次贡献的规则；元素隐藏规则本仓不注入，不计入条数。'**
  String get subsUpdateFooter;

  /// No description provided for @subsAllGroups.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get subsAllGroups;

  /// No description provided for @subsNewGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建分组'**
  String get subsNewGroupTitle;

  /// No description provided for @subsEditRemoteHint.
  ///
  /// In zh, this message translates to:
  /// **'修改链接或收录类型后会立即重新下载，并替换该订阅原有的规则；订阅方式与本地文件不可更改。'**
  String get subsEditRemoteHint;

  /// No description provided for @subsEditLocalHint.
  ///
  /// In zh, this message translates to:
  /// **'本地文件通过系统文件选择器读取，应用只保留读取权限；同名的黑白名单与 hosts 订阅互不影响。'**
  String get subsEditLocalHint;

  /// No description provided for @subsAddRemoteHint.
  ///
  /// In zh, this message translates to:
  /// **'同一条链接可以为黑白名单和 hosts 各建一条订阅（唯一性按「链接 + 类型」判定），保存后会立即下载一次正文并写入规则库。'**
  String get subsAddRemoteHint;

  /// No description provided for @subsKindLabel.
  ///
  /// In zh, this message translates to:
  /// **'收录类型'**
  String get subsKindLabel;

  /// No description provided for @subsGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'所属分组'**
  String get subsGroupLabel;

  /// No description provided for @subsMirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'镜像加速'**
  String get subsMirrorTitle;

  /// No description provided for @subsDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」后不可撤销。\n\n删除会同时移除这条订阅贡献的全部规则（来源标签 sub_<id>）。'**
  String subsDeleteMessage(Object name);

  /// No description provided for @subsTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个订阅'**
  String subsTotal(Object count);

  /// No description provided for @subsGroupTotal.
  ///
  /// In zh, this message translates to:
  /// **'「{group}」下 {count} 个订阅'**
  String subsGroupTotal(Object count, Object group);

  /// No description provided for @subsUpdateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get subsUpdateNow;

  /// No description provided for @subsReimport.
  ///
  /// In zh, this message translates to:
  /// **'重新导入文件'**
  String get subsReimport;

  /// No description provided for @subsRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get subsRename;

  /// No description provided for @subsConsecutiveFailures.
  ///
  /// In zh, this message translates to:
  /// **'连续失败 {count} 次'**
  String subsConsecutiveFailures(Object count);

  /// No description provided for @subsMirrorFallbackShort.
  ///
  /// In zh, this message translates to:
  /// **'镜像 · 可回退'**
  String get subsMirrorFallbackShort;

  /// No description provided for @subsMirrorNoFallback.
  ///
  /// In zh, this message translates to:
  /// **'镜像 · 不回退'**
  String get subsMirrorNoFallback;

  /// No description provided for @subsLastUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'上次更新失败'**
  String get subsLastUpdateFailed;

  /// No description provided for @subsNeverUpdated.
  ///
  /// In zh, this message translates to:
  /// **'从未成功更新'**
  String get subsNeverUpdated;

  /// No description provided for @subsRuleCountValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String subsRuleCountValue(Object count);

  /// No description provided for @subsRulesStored.
  ///
  /// In zh, this message translates to:
  /// **'已入库 {count} 条规则；{action}该订阅贡献的规则。'**
  String subsRulesStored(Object action, Object count);

  /// No description provided for @subsActionRemote.
  ///
  /// In zh, this message translates to:
  /// **'更新会重新下载并替换'**
  String get subsActionRemote;

  /// No description provided for @subsActionLocal.
  ///
  /// In zh, this message translates to:
  /// **'重新导入会重新读取该文件并替换'**
  String get subsActionLocal;

  /// No description provided for @subsPickRuleFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个规则文件'**
  String get subsPickRuleFile;

  /// No description provided for @subsChange.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get subsChange;

  /// No description provided for @subsGroupShort.
  ///
  /// In zh, this message translates to:
  /// **'+ 分组'**
  String get subsGroupShort;

  /// No description provided for @subsMirrorName.
  ///
  /// In zh, this message translates to:
  /// **'镜像 {mirror}'**
  String subsMirrorName(Object mirror);

  /// No description provided for @trafficPackageName.
  ///
  /// In zh, this message translates to:
  /// **'包名'**
  String get trafficPackageName;

  /// No description provided for @trafficAppName.
  ///
  /// In zh, this message translates to:
  /// **'应用名'**
  String get trafficAppName;

  /// No description provided for @trafficDown.
  ///
  /// In zh, this message translates to:
  /// **'下行流量'**
  String get trafficDown;

  /// No description provided for @trafficUp.
  ///
  /// In zh, this message translates to:
  /// **'上行流量'**
  String get trafficUp;

  /// No description provided for @trafficTotal.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get trafficTotal;

  /// No description provided for @trafficShare.
  ///
  /// In zh, this message translates to:
  /// **'占比'**
  String get trafficShare;

  /// No description provided for @trafficStartDate.
  ///
  /// In zh, this message translates to:
  /// **'统计起始日'**
  String get trafficStartDate;

  /// No description provided for @trafficLastUpdate.
  ///
  /// In zh, this message translates to:
  /// **'最后更新'**
  String get trafficLastUpdate;

  /// No description provided for @trafficAttributionFooter.
  ///
  /// In zh, this message translates to:
  /// **'流量按 UID 归因到应用（上游 TrafficAttributionDialog 的口径）；同一应用的多进程流量合并计算。'**
  String get trafficAttributionFooter;

  /// No description provided for @trafficAttributionTitle.
  ///
  /// In zh, this message translates to:
  /// **'流量归因说明'**
  String get trafficAttributionTitle;

  /// No description provided for @trafficScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计口径'**
  String get trafficScopeTitle;

  /// No description provided for @trafficScopeBody.
  ///
  /// In zh, this message translates to:
  /// **'流量按 UID 归因：每个应用的上下行字节数由引擎按 UID 累计后按天落库（表 app_traffic_daily，主键是「日期 + 包名」），不走包名匹配，因此共享 UID 的应用会合并成一项。'**
  String get trafficScopeBody;

  /// No description provided for @trafficWhyLowerTitle.
  ///
  /// In zh, this message translates to:
  /// **'为什么数字比系统设置里少'**
  String get trafficWhyLowerTitle;

  /// No description provided for @trafficWhyLowerBody.
  ///
  /// In zh, this message translates to:
  /// **'这里只统计经过本机隧道处理的流量，未进入隧道的直连流量不计入；系统设置里的统计包含全部网卡流量。'**
  String get trafficWhyLowerBody;

  /// No description provided for @trafficWhyNoRateTitle.
  ///
  /// In zh, this message translates to:
  /// **'为什么没有实时速率'**
  String get trafficWhyNoRateTitle;

  /// No description provided for @trafficWhyNoRateBody.
  ///
  /// In zh, this message translates to:
  /// **'实时速率需要内核每秒回报的速率序列；本仓的按天流量表只有「日期 + 包名 + 上下行累计字节」，没有速率列。因此「本次会话」窗口与「按实时速率」排序不可用，页面上也没有速率曲线——页面里出现的每个数字都是真实字节数。'**
  String get trafficWhyNoRateBody;

  /// No description provided for @trafficRetentionTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录保留多久'**
  String get trafficRetentionTitle;

  /// No description provided for @trafficRetentionBody.
  ///
  /// In zh, this message translates to:
  /// **'按天保留，由原生侧的清理策略删除过期行；「全部历史」档位汇总表里现存的全部日期。'**
  String get trafficRetentionBody;

  /// No description provided for @trafficSystemAppsTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统应用怎么识别'**
  String get trafficSystemAppsTitle;

  /// No description provided for @trafficSystemAppsBody.
  ///
  /// In zh, this message translates to:
  /// **'流量表里没有系统应用标记，页面按旧版 SystemAppClassifier 的同一份前缀表识别（android、com.android.*、各厂商预装前缀等）。「隐藏系统应用」开关的状态落在 traffic_stats_hide_system_apps。'**
  String get trafficSystemAppsBody;

  /// No description provided for @trafficUpstreamFooter.
  ///
  /// In zh, this message translates to:
  /// **'上游对应 ui/traffic/TrafficAttributionDialog.kt 与 AppTrafficDetailDialog.kt；本页数字来自 app_traffic_daily。'**
  String get trafficUpstreamFooter;

  /// No description provided for @trafficTitle.
  ///
  /// In zh, this message translates to:
  /// **'流量统计'**
  String get trafficTitle;

  /// No description provided for @trafficClearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清除历史'**
  String get trafficClearHistory;

  /// No description provided for @trafficRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get trafficRefresh;

  /// No description provided for @trafficAttribution.
  ///
  /// In zh, this message translates to:
  /// **'归因说明'**
  String get trafficAttribution;

  /// No description provided for @trafficLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取流量记录'**
  String get trafficLoadFailed;

  /// No description provided for @trafficLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取流量记录'**
  String get trafficLoading;

  /// No description provided for @trafficAppCount.
  ///
  /// In zh, this message translates to:
  /// **'应用数'**
  String get trafficAppCount;

  /// No description provided for @trafficAppCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'个'**
  String get trafficAppCountUnit;

  /// No description provided for @trafficNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无流量数据'**
  String get trafficNoData;

  /// No description provided for @trafficNoMatchingApps.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的应用'**
  String get trafficNoMatchingApps;

  /// No description provided for @trafficRankingTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用流量排行'**
  String get trafficRankingTitle;

  /// No description provided for @trafficShareFooter.
  ///
  /// In zh, this message translates to:
  /// **'占比按{window}总字节数（下行 + 上行）计算；{range}。点按一行查看该应用的上下行明细。'**
  String trafficShareFooter(Object range, Object window);

  /// No description provided for @trafficClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除全部流量记录？'**
  String get trafficClearTitle;

  /// No description provided for @trafficConfirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get trafficConfirmClear;

  /// No description provided for @trafficClearBody.
  ///
  /// In zh, this message translates to:
  /// **'此操作将清空所有已持久化的应用历史流量统计，清除后无法恢复。'**
  String get trafficClearBody;

  /// No description provided for @trafficRangeAllHistory.
  ///
  /// In zh, this message translates to:
  /// **'范围为全部历史记录'**
  String get trafficRangeAllHistory;

  /// No description provided for @trafficSessionRange.
  ///
  /// In zh, this message translates to:
  /// **'本次会话'**
  String get trafficSessionRange;

  /// No description provided for @trafficSessionUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'「本次会话」需要内核按会话回报流量，本仓只有按天落库的历史记录'**
  String get trafficSessionUnavailable;

  /// No description provided for @trafficLiveRate.
  ///
  /// In zh, this message translates to:
  /// **'按实时速率'**
  String get trafficLiveRate;

  /// No description provided for @trafficHideSystemApps.
  ///
  /// In zh, this message translates to:
  /// **'隐藏系统应用'**
  String get trafficHideSystemApps;

  /// No description provided for @trafficSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索应用名或包名'**
  String get trafficSearchHint;

  /// No description provided for @trafficAllHistory.
  ///
  /// In zh, this message translates to:
  /// **'全部历史'**
  String get trafficAllHistory;

  /// No description provided for @trafficLiveRateUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'「按实时网速」需要每秒速率，本仓的按天表里没有速率列'**
  String get trafficLiveRateUnavailable;

  /// No description provided for @trafficHideSystemAppsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按系统应用标记与厂商预装前缀识别，隐藏后不计入排行'**
  String get trafficHideSystemAppsSubtitle;

  /// No description provided for @trafficWindowLabelDate.
  ///
  /// In zh, this message translates to:
  /// **'统计日期 {date}'**
  String trafficWindowLabelDate(Object date);

  /// No description provided for @trafficWindowLabelRange.
  ///
  /// In zh, this message translates to:
  /// **'统计范围 {start} 至 {end}'**
  String trafficWindowLabelRange(Object end, Object start);

  /// No description provided for @trafficShareWindow.
  ///
  /// In zh, this message translates to:
  /// **'占比按{window}总字节数（下行 + 上行）计算；{range}。点按一行查看该应用的上下行明细。'**
  String trafficShareWindow(Object range, Object window);

  /// No description provided for @trafficTotalApps.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个应用产生流量 · 合计 {total}'**
  String trafficTotalApps(Object count, Object total);

  /// No description provided for @trafficSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有应用名或包名包含「{search}」。'**
  String trafficSearchEmpty(Object search);

  /// No description provided for @trafficHiddenCount.
  ///
  /// In zh, this message translates to:
  /// **'本次共有 {count} 个应用被「隐藏系统应用」过滤掉，关闭该开关即可看到。'**
  String trafficHiddenCount(Object count);

  /// No description provided for @trafficNoRecordsBody.
  ///
  /// In zh, this message translates to:
  /// **'流量按天由原生侧汇总落库；启动隧道并产生流量后，这里会出现各应用的下行 / 上行字节数。'**
  String get trafficNoRecordsBody;

  /// No description provided for @trafficNoRecordsForWindow.
  ///
  /// In zh, this message translates to:
  /// **'「{window}」还没有流量记录。流量按天由原生侧汇总落库，换个时间窗口或启动隧道产生流量后再看。'**
  String trafficNoRecordsForWindow(Object window);

  /// No description provided for @trafficOptionUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'「{label}」不可用：{reason}'**
  String trafficOptionUnavailable(Object label, Object reason);

  /// No description provided for @trafficNoSourceReason.
  ///
  /// In zh, this message translates to:
  /// **'本仓没有对应的数据来源'**
  String get trafficNoSourceReason;

  /// No description provided for @trafficCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除 {count} 条流量记录'**
  String trafficCleared(Object count);

  /// No description provided for @trafficClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清除失败：{detail}'**
  String trafficClearFailed(Object detail);

  /// No description provided for @trafficShareBarTooltip.
  ///
  /// In zh, this message translates to:
  /// **'占比条长度是这一行按「{sort}」在当前窗口总量里的份额（当前 {value}），与列表排序一致。'**
  String trafficShareBarTooltip(Object sort, Object value);

  /// No description provided for @trafficWhyDaemonTitle.
  ///
  /// In zh, this message translates to:
  /// **'为什么系统设置将全部流量算给谛听？'**
  String get trafficWhyDaemonTitle;

  /// No description provided for @trafficWhyDaemonBody.
  ///
  /// In zh, this message translates to:
  /// **'因 Android VPN 机制，系统将代理出站归属于守护进程。谛听自身不偷跑流量，点按查看统计口径。'**
  String get trafficWhyDaemonBody;

  /// No description provided for @trafficLiveRateTitle.
  ///
  /// In zh, this message translates to:
  /// **'实时速率'**
  String get trafficLiveRateTitle;

  /// No description provided for @trafficNoLiveRate.
  ///
  /// In zh, this message translates to:
  /// **'本模式不统计实时速率：极速模式的窄路由不经过引擎的流量计数器，本仓也没有它的累计表。上面的 {window} 下行 / 上行与下方排行都是真实数字。'**
  String trafficNoLiveRate(Object window);

  /// No description provided for @trafficLiveRateBody.
  ///
  /// In zh, this message translates to:
  /// **'来自引擎的每秒速率（本次会话），与常驻通知里的读数同源；上面的 {window} 下行 / 上行是 `app_traffic_daily` 的累计字节，两者口径不同，数字不必相等。'**
  String trafficLiveRateBody(Object window);

  /// No description provided for @trafficSearchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索应用或包名...'**
  String get trafficSearchPlaceholder;

  /// No description provided for @trafficWindowDown.
  ///
  /// In zh, this message translates to:
  /// **'{window}下行'**
  String trafficWindowDown(Object window);

  /// No description provided for @trafficWindowUp.
  ///
  /// In zh, this message translates to:
  /// **'{window}上行'**
  String trafficWindowUp(Object window);

  /// No description provided for @obsRequestsTitle.
  ///
  /// In zh, this message translates to:
  /// **'请求'**
  String get obsRequestsTitle;

  /// No description provided for @obsSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get obsSource;

  /// No description provided for @obsStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get obsStatus;

  /// No description provided for @obsRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get obsRefresh;

  /// No description provided for @obsClearFilter.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get obsClearFilter;

  /// No description provided for @obsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取请求记录'**
  String get obsLoadFailed;

  /// No description provided for @obsLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取请求记录'**
  String get obsLoading;

  /// No description provided for @obsNoRecords.
  ///
  /// In zh, this message translates to:
  /// **'还没有请求记录'**
  String get obsNoRecords;

  /// No description provided for @obsNoMatchingRequests.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的请求'**
  String get obsNoMatchingRequests;

  /// No description provided for @obsNoRecordsBody.
  ///
  /// In zh, this message translates to:
  /// **'应用发出请求后会在这里留下记录；HTTPS 记录需要开启流量检查。'**
  String get obsNoRecordsBody;

  /// No description provided for @obsResetFilter.
  ///
  /// In zh, this message translates to:
  /// **'重置筛选条件'**
  String get obsResetFilter;

  /// No description provided for @obsRecordsHeader.
  ///
  /// In zh, this message translates to:
  /// **'请求记录'**
  String get obsRecordsHeader;

  /// No description provided for @obsRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get obsRetry;

  /// No description provided for @obsBypassedDns.
  ///
  /// In zh, this message translates to:
  /// **'直连，未经过 DNS 解析流程'**
  String get obsBypassedDns;

  /// No description provided for @obsBlockedDns.
  ///
  /// In zh, this message translates to:
  /// **'被过滤规则拦截，未发出查询'**
  String get obsBlockedDns;

  /// No description provided for @obsRewrittenDns.
  ///
  /// In zh, this message translates to:
  /// **'命中了覆写规则，返回改写后的结果'**
  String get obsRewrittenDns;

  /// No description provided for @obsErrorDns.
  ///
  /// In zh, this message translates to:
  /// **'解析过程出错，未取得应答'**
  String get obsErrorDns;

  /// No description provided for @obsPassedDns.
  ///
  /// In zh, this message translates to:
  /// **'按规则解析并正常返回'**
  String get obsPassedDns;

  /// No description provided for @obsPassedHttps.
  ///
  /// In zh, this message translates to:
  /// **'按规则转发成功'**
  String get obsPassedHttps;

  /// No description provided for @obsRewrittenHttps.
  ///
  /// In zh, this message translates to:
  /// **'命中了覆写规则，返回改写后的请求'**
  String get obsRewrittenHttps;

  /// No description provided for @obsBlockedHttps.
  ///
  /// In zh, this message translates to:
  /// **'被过滤规则拦截，未建立连接'**
  String get obsBlockedHttps;

  /// No description provided for @obsBypassedHttps.
  ///
  /// In zh, this message translates to:
  /// **'未解密直接转发（旁路）'**
  String get obsBypassedHttps;

  /// No description provided for @obsErrorHttps.
  ///
  /// In zh, this message translates to:
  /// **'处理过程出错'**
  String get obsErrorHttps;

  /// No description provided for @obsNoRuleHttps.
  ///
  /// In zh, this message translates to:
  /// **'未命中规则（或未记录规则）'**
  String get obsNoRuleHttps;

  /// No description provided for @obsNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get obsNone;

  /// No description provided for @obsRequestDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'请求详情'**
  String get obsRequestDetailTitle;

  /// No description provided for @obsCachedChip.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get obsCachedChip;

  /// No description provided for @obsBasicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基础信息'**
  String get obsBasicInfo;

  /// No description provided for @obsTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get obsTime;

  /// No description provided for @obsProtocol.
  ///
  /// In zh, this message translates to:
  /// **'协议'**
  String get obsProtocol;

  /// No description provided for @obsAppPackage.
  ///
  /// In zh, this message translates to:
  /// **'应用包名'**
  String get obsAppPackage;

  /// No description provided for @obsResolved.
  ///
  /// In zh, this message translates to:
  /// **'解析结果'**
  String get obsResolved;

  /// No description provided for @obsElapsed.
  ///
  /// In zh, this message translates to:
  /// **'耗时'**
  String get obsElapsed;

  /// No description provided for @obsBlockingSubscription.
  ///
  /// In zh, this message translates to:
  /// **'拦截订阅'**
  String get obsBlockingSubscription;

  /// No description provided for @obsRuleMatch.
  ///
  /// In zh, this message translates to:
  /// **'规则命中'**
  String get obsRuleMatch;

  /// No description provided for @obsRule.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get obsRule;

  /// No description provided for @obsHandling.
  ///
  /// In zh, this message translates to:
  /// **'处理方式'**
  String get obsHandling;

  /// No description provided for @obsError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get obsError;

  /// No description provided for @obsAiAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析'**
  String get obsAiAnalysis;

  /// No description provided for @obsRawRecord.
  ///
  /// In zh, this message translates to:
  /// **'原始记录'**
  String get obsRawRecord;

  /// No description provided for @obsRawRecordFooter.
  ///
  /// In zh, this message translates to:
  /// **'引擎写入 message 字段的原文，未经改写。'**
  String get obsRawRecordFooter;

  /// No description provided for @obsFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'处理失败的请求可在「连接」页配合查看对应的活动连接。'**
  String get obsFailedHint;

  /// No description provided for @obsRulesHint.
  ///
  /// In zh, this message translates to:
  /// **'加入的黑白名单可在「规则」页查看和撤销。'**
  String get obsRulesHint;

  /// No description provided for @obsCacheHit.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get obsCacheHit;

  /// No description provided for @obsCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {text}'**
  String obsCopied(Object text);

  /// No description provided for @obsCopyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get obsCopyAddress;

  /// No description provided for @obsCopyDomain.
  ///
  /// In zh, this message translates to:
  /// **'复制域名'**
  String get obsCopyDomain;

  /// No description provided for @obsInBlocklist.
  ///
  /// In zh, this message translates to:
  /// **'已在黑名单'**
  String get obsInBlocklist;

  /// No description provided for @obsAddToBlocklist.
  ///
  /// In zh, this message translates to:
  /// **'加入黑名单'**
  String get obsAddToBlocklist;

  /// No description provided for @obsInAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'已在白名单'**
  String get obsInAllowlist;

  /// No description provided for @obsAddToAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'加入白名单'**
  String get obsAddToAllowlist;

  /// No description provided for @obsIpOnlyFooter.
  ///
  /// In zh, this message translates to:
  /// **'该记录只有 IP 地址，域名规则无法匹配，因此不能加入黑白名单。'**
  String get obsIpOnlyFooter;

  /// No description provided for @obsAnalyzeRequest.
  ///
  /// In zh, this message translates to:
  /// **'分析这条请求'**
  String get obsAnalyzeRequest;

  /// No description provided for @obsAnalyzeRequestBody.
  ///
  /// In zh, this message translates to:
  /// **'用配置的模型研判归属、风险与处置建议'**
  String get obsAnalyzeRequestBody;

  /// No description provided for @obsCopiedHost.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {host}'**
  String obsCopiedHost(Object host);

  /// No description provided for @obsAddedToKind.
  ///
  /// In zh, this message translates to:
  /// **'已将 {domain} 加入{kind}'**
  String obsAddedToKind(Object domain, Object kind);

  /// No description provided for @obsAlreadyInKind.
  ///
  /// In zh, this message translates to:
  /// **'{domain} 已在{kind}中'**
  String obsAlreadyInKind(Object domain, Object kind);

  /// No description provided for @obsCurrentFilter.
  ///
  /// In zh, this message translates to:
  /// **'当前筛选：{filter}。'**
  String obsCurrentFilter(Object filter);

  /// No description provided for @obsFooterCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条，其中 {failed} 条处理失败{filter}{more}。点按一行查看规则命中与处理结果。'**
  String obsFooterCount(
    Object count,
    Object failed,
    Object filter,
    Object more,
  );

  /// No description provided for @obsFooterFilter.
  ///
  /// In zh, this message translates to:
  /// **'（筛选：{filter}）'**
  String obsFooterFilter(Object filter);

  /// No description provided for @obsFooterMore.
  ///
  /// In zh, this message translates to:
  /// **'；继续下滑加载更多'**
  String get obsFooterMore;

  /// No description provided for @obsFooterAll.
  ///
  /// In zh, this message translates to:
  /// **'；已加载全部'**
  String get obsFooterAll;

  /// No description provided for @logsSubStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅拦截率'**
  String get logsSubStatsTitle;

  /// No description provided for @logsRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get logsRefresh;

  /// No description provided for @logsTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'时间范围'**
  String get logsTimeRange;

  /// No description provided for @logsSubStatsFooter.
  ///
  /// In zh, this message translates to:
  /// **'拦截率为所选时间范围内，该订阅拦截请求数占全部已记录请求（DNS + HTTPS）的比例。'**
  String get logsSubStatsFooter;

  /// No description provided for @logsOverview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get logsOverview;

  /// No description provided for @logsSubStatsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取拦截统计'**
  String get logsSubStatsLoadFailed;

  /// No description provided for @logsLoadingStats.
  ///
  /// In zh, this message translates to:
  /// **'正在加载统计数据'**
  String get logsLoadingStats;

  /// No description provided for @logsBlockingSubs.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽订阅'**
  String get logsBlockingSubs;

  /// No description provided for @logsMissingSubColumn.
  ///
  /// In zh, this message translates to:
  /// **'当前数据库缺少订阅标记列'**
  String get logsMissingSubColumn;

  /// No description provided for @logsMissingSubColumnBody.
  ///
  /// In zh, this message translates to:
  /// **'这张库是在加入「订阅拦截统计」之前创建的，日志行里没有记录 blockSubscriptionId。重新产生请求日志后即可统计，历史数据无法补算。'**
  String get logsMissingSubColumnBody;

  /// No description provided for @logsAllRecordedRequests.
  ///
  /// In zh, this message translates to:
  /// **'全部已记录请求'**
  String get logsAllRecordedRequests;

  /// No description provided for @logsAllRecordedFooter.
  ///
  /// In zh, this message translates to:
  /// **'DNS 与 HTTPS 日志合计，含通过、屏蔽和失败。'**
  String get logsAllRecordedFooter;

  /// No description provided for @logsNoBlockingSubs.
  ///
  /// In zh, this message translates to:
  /// **'暂无屏蔽订阅'**
  String get logsNoBlockingSubs;

  /// No description provided for @logsNoBlockingSubsBody.
  ///
  /// In zh, this message translates to:
  /// **'导入屏蔽订阅并产生 DNS 或 HTTPS 请求后，此处将显示其拦截率。'**
  String get logsNoBlockingSubsBody;

  /// No description provided for @logsBlockingSubsFooter.
  ///
  /// In zh, this message translates to:
  /// **'按拦截次数排序；「已删除」表示订阅已移除，但历史命中仍保留。'**
  String get logsBlockingSubsFooter;

  /// No description provided for @logsExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get logsExpired;

  /// No description provided for @logsRaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'竞速统计'**
  String get logsRaceTitle;

  /// No description provided for @logsRaceFooter.
  ///
  /// In zh, this message translates to:
  /// **'只统计真实发出过 DoH 请求的竞速解析；本机缓存命中的查询不进这张表。'**
  String get logsRaceFooter;

  /// No description provided for @logsRaceLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取竞速记录'**
  String get logsRaceLoadFailed;

  /// No description provided for @logsLoadingRace.
  ///
  /// In zh, this message translates to:
  /// **'正在读取竞速记录'**
  String get logsLoadingRace;

  /// No description provided for @logsRaceSummary.
  ///
  /// In zh, this message translates to:
  /// **'{range}内共 {count} 次竞速解析。'**
  String logsRaceSummary(Object count, Object range);

  /// No description provided for @logsRaceEmptyRange.
  ///
  /// In zh, this message translates to:
  /// **'所选时间范围内还没有竞速记录。'**
  String get logsRaceEmptyRange;

  /// No description provided for @logsRaceRequests.
  ///
  /// In zh, this message translates to:
  /// **'竞速请求'**
  String get logsRaceRequests;

  /// No description provided for @logsSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get logsSuccess;

  /// No description provided for @logsAverageElapsed.
  ///
  /// In zh, this message translates to:
  /// **'平均耗时'**
  String get logsAverageElapsed;

  /// No description provided for @logsStrategyOverview.
  ///
  /// In zh, this message translates to:
  /// **'策略概览'**
  String get logsStrategyOverview;

  /// No description provided for @logsStrategyFooter.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中的请求不触发竞速，因此不进这张表；首选命中率 = 首选服务商即胜出且成功的比例。'**
  String get logsStrategyFooter;

  /// No description provided for @logsWinnerProviders.
  ///
  /// In zh, this message translates to:
  /// **'胜出服务商'**
  String get logsWinnerProviders;

  /// No description provided for @logsNoWinners.
  ///
  /// In zh, this message translates to:
  /// **'还没有胜出记录'**
  String get logsNoWinners;

  /// No description provided for @logsNoWinnersBody.
  ///
  /// In zh, this message translates to:
  /// **'竞速解析成功后，胜出的服务商会在这里按次数排序。'**
  String get logsNoWinnersBody;

  /// No description provided for @logsWinnerFooter.
  ///
  /// In zh, this message translates to:
  /// **'按胜出次数排序；平均耗时是该服务商胜出时的耗时均值。'**
  String get logsWinnerFooter;

  /// No description provided for @logsAverageWinLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均胜出耗时 {latency}'**
  String logsAverageWinLatency(Object latency);

  /// No description provided for @logsSmartPrimary.
  ///
  /// In zh, this message translates to:
  /// **'智能选择首选'**
  String get logsSmartPrimary;

  /// No description provided for @logsSmartPrimaryFooter.
  ///
  /// In zh, this message translates to:
  /// **'只有智能选择策略下才有意义；首选命中率统计「首选服务商就是胜出者」的比例，兜底救回的查询不计入。'**
  String get logsSmartPrimaryFooter;

  /// No description provided for @logsPrimaryHit.
  ///
  /// In zh, this message translates to:
  /// **'首选命中 {percent} · 平均首选耗时 {latency}'**
  String logsPrimaryHit(Object latency, Object percent);

  /// No description provided for @logsDashboardTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志仪表盘'**
  String get logsDashboardTitle;

  /// No description provided for @logsModeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'日志模式'**
  String get logsModeTooltip;

  /// No description provided for @logsRequestsDashboard.
  ///
  /// In zh, this message translates to:
  /// **'请求日志仪表盘'**
  String get logsRequestsDashboard;

  /// No description provided for @logsRequestsDashboardBody.
  ///
  /// In zh, this message translates to:
  /// **'全部 DNS、HTTPS、缓存、竞速与规则拦截的实时概览'**
  String get logsRequestsDashboardBody;

  /// No description provided for @logsFocusedDashboard.
  ///
  /// In zh, this message translates to:
  /// **'重点请求仪表盘'**
  String get logsFocusedDashboard;

  /// No description provided for @logsFocusedDashboardBody.
  ///
  /// In zh, this message translates to:
  /// **'DNS 与 HTTPS 拦截、错误、旁路记录及解析状态概览'**
  String get logsFocusedDashboardBody;

  /// No description provided for @logsServiceOverview.
  ///
  /// In zh, this message translates to:
  /// **'服务状态与解析概览'**
  String get logsServiceOverview;

  /// No description provided for @logsPrivacyBody.
  ///
  /// In zh, this message translates to:
  /// **'当前处于隐私模式，不记录请求明细。DNS 缓存、并发竞速与网络流量监控仍正常运行。'**
  String get logsPrivacyBody;

  /// No description provided for @logsCacheTableTitle.
  ///
  /// In zh, this message translates to:
  /// **'DNS 缓存表'**
  String get logsCacheTableTitle;

  /// No description provided for @logsCacheLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取缓存表：{detail}'**
  String logsCacheLoadFailed(Object detail);

  /// No description provided for @logsLoadingCache.
  ///
  /// In zh, this message translates to:
  /// **'正在读取缓存表'**
  String get logsLoadingCache;

  /// No description provided for @logsCacheEmpty.
  ///
  /// In zh, this message translates to:
  /// **'缓存表还没有条目'**
  String get logsCacheEmpty;

  /// No description provided for @logsCacheNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的缓存'**
  String get logsCacheNoMatch;

  /// No description provided for @logsCacheEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'引擎解析成功后会把应答写进 dns_cache；全新安装或隧道刚启动时这张表可能还是空的。'**
  String get logsCacheEmptyBody;

  /// No description provided for @logsCurrentSearch.
  ///
  /// In zh, this message translates to:
  /// **'当前搜索：{query}'**
  String logsCurrentSearch(Object query);

  /// No description provided for @logsLiveCache.
  ///
  /// In zh, this message translates to:
  /// **'有效缓存'**
  String get logsLiveCache;

  /// No description provided for @logsNeverHit.
  ///
  /// In zh, this message translates to:
  /// **'尚未命中'**
  String get logsNeverHit;

  /// No description provided for @logsCacheFooter.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条，按命中次数与过期时间排序。剩余 TTL 少于 30 秒的条目标橙色。点按一行查看详情，可复制域名、加入黑白名单或用 AI 分析。'**
  String logsCacheFooter(Object count);

  /// No description provided for @logsBootstrapTitle.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 统计'**
  String get logsBootstrapTitle;

  /// No description provided for @logsBootstrapFooter.
  ///
  /// In zh, this message translates to:
  /// **'成功率为成功次数 ÷ 尝试次数；平均耗时按各节点的尝试次数加权。'**
  String get logsBootstrapFooter;

  /// No description provided for @logsBootstrapLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 Bootstrap 记录'**
  String get logsBootstrapLoadFailed;

  /// No description provided for @logsLoadingBootstrap.
  ///
  /// In zh, this message translates to:
  /// **'正在读取 Bootstrap 记录'**
  String get logsLoadingBootstrap;

  /// No description provided for @logsBootstrapSummary.
  ///
  /// In zh, this message translates to:
  /// **'{range}内共 {count} 次 Bootstrap 探测。'**
  String logsBootstrapSummary(Object count, Object range);

  /// No description provided for @logsBootstrapEmptyRange.
  ///
  /// In zh, this message translates to:
  /// **'所选时间范围内还没有 Bootstrap 探测记录。'**
  String get logsBootstrapEmptyRange;

  /// No description provided for @logsAttempts.
  ///
  /// In zh, this message translates to:
  /// **'尝试次数'**
  String get logsAttempts;

  /// No description provided for @logsSuccessRate.
  ///
  /// In zh, this message translates to:
  /// **'成功率'**
  String get logsSuccessRate;

  /// No description provided for @logsNodes.
  ///
  /// In zh, this message translates to:
  /// **'节点'**
  String get logsNodes;

  /// No description provided for @logsNoProbes.
  ///
  /// In zh, this message translates to:
  /// **'还没有探测记录'**
  String get logsNoProbes;

  /// No description provided for @logsNoProbesBody.
  ///
  /// In zh, this message translates to:
  /// **'开启「启用 Bootstrap IP」并产生解析后，各节点的尝试与成功率会出现在这里。'**
  String get logsNoProbesBody;

  /// No description provided for @logsNodesFooter.
  ///
  /// In zh, this message translates to:
  /// **'按尝试次数排序；显示最近窗口内的聚合值。'**
  String get logsNodesFooter;

  /// No description provided for @logsCacheDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存详情'**
  String get logsCacheDetailTitle;

  /// No description provided for @logsCacheExpiringBody.
  ///
  /// In zh, this message translates to:
  /// **'缓存即将过期，过期后下一次查询会重新向上游解析'**
  String get logsCacheExpiringBody;

  /// No description provided for @logsCacheValidBody.
  ///
  /// In zh, this message translates to:
  /// **'缓存有效，命中时直接返回应答，不再请求上游'**
  String get logsCacheValidBody;

  /// No description provided for @logsExpiring.
  ///
  /// In zh, this message translates to:
  /// **'即将过期'**
  String get logsExpiring;

  /// No description provided for @logsValid.
  ///
  /// In zh, this message translates to:
  /// **'有效'**
  String get logsValid;

  /// No description provided for @logsHitTimes.
  ///
  /// In zh, this message translates to:
  /// **'命中 {count} 次'**
  String logsHitTimes(Object count);

  /// No description provided for @logsCacheInfo.
  ///
  /// In zh, this message translates to:
  /// **'缓存信息'**
  String get logsCacheInfo;

  /// No description provided for @logsRecordType.
  ///
  /// In zh, this message translates to:
  /// **'记录类型'**
  String get logsRecordType;

  /// No description provided for @logsRemainingTtl.
  ///
  /// In zh, this message translates to:
  /// **'剩余 TTL'**
  String get logsRemainingTtl;

  /// No description provided for @logsOriginalTtl.
  ///
  /// In zh, this message translates to:
  /// **'原始 TTL'**
  String get logsOriginalTtl;

  /// No description provided for @logsExpiry.
  ///
  /// In zh, this message translates to:
  /// **'过期时间'**
  String get logsExpiry;

  /// No description provided for @logsHitCount.
  ///
  /// In zh, this message translates to:
  /// **'命中次数'**
  String get logsHitCount;

  /// No description provided for @logsLastHit.
  ///
  /// In zh, this message translates to:
  /// **'最后命中'**
  String get logsLastHit;

  /// No description provided for @logsResponseSize.
  ///
  /// In zh, this message translates to:
  /// **'应答大小'**
  String get logsResponseSize;

  /// No description provided for @logsAnalyzeDomain.
  ///
  /// In zh, this message translates to:
  /// **'分析这个域名'**
  String get logsAnalyzeDomain;

  /// No description provided for @logsCacheDetailFooter.
  ///
  /// In zh, this message translates to:
  /// **'缓存表每 10 秒从引擎内存同步一次，这里是打开时的快照。加入的黑白名单可在「规则」页查看和撤销。'**
  String get logsCacheDetailFooter;

  /// No description provided for @logsAiInsight.
  ///
  /// In zh, this message translates to:
  /// **'AI 研判'**
  String get logsAiInsight;

  /// No description provided for @logsNotAnalysed.
  ///
  /// In zh, this message translates to:
  /// **'未分析'**
  String get logsNotAnalysed;

  /// No description provided for @logsHasReport.
  ///
  /// In zh, this message translates to:
  /// **'已有结论'**
  String get logsHasReport;

  /// No description provided for @logsAiInsightBody.
  ///
  /// In zh, this message translates to:
  /// **'把最近的 DNS 与 HTTPS 记录交给配置的模型，汇总异常请求、防护效果与优化建议。'**
  String get logsAiInsightBody;

  /// No description provided for @logsAnalyseTraffic.
  ///
  /// In zh, this message translates to:
  /// **'用 AI 研判最近流量'**
  String get logsAnalyseTraffic;

  /// No description provided for @logsViewFullReport.
  ///
  /// In zh, this message translates to:
  /// **'查看完整报告'**
  String get logsViewFullReport;

  /// No description provided for @logsModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型 {model}'**
  String logsModelName(Object model);

  /// No description provided for @logsSuccessWith.
  ///
  /// In zh, this message translates to:
  /// **'成功 {percent}'**
  String logsSuccessWith(Object percent);

  /// No description provided for @logsAverageWith.
  ///
  /// In zh, this message translates to:
  /// **'平均 {latency}'**
  String logsAverageWith(Object latency);

  /// No description provided for @logsPrimaryHitOnly.
  ///
  /// In zh, this message translates to:
  /// **'首选命中 {percent}'**
  String logsPrimaryHitOnly(Object percent);

  /// No description provided for @logsFallbackUses.
  ///
  /// In zh, this message translates to:
  /// **'兜底 {count} 次'**
  String logsFallbackUses(Object count);

  /// No description provided for @logsBootstrapRow.
  ///
  /// In zh, this message translates to:
  /// **'{ip} · 成功 {percent} · 平均 {latency}{failures}'**
  String logsBootstrapRow(
    Object failures,
    Object ip,
    Object latency,
    Object percent,
  );

  /// No description provided for @logsBootstrapFailures.
  ///
  /// In zh, this message translates to:
  /// **' · 失败 {count} 次'**
  String logsBootstrapFailures(Object count);

  /// No description provided for @logsEntryCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String logsEntryCount(Object count);

  /// No description provided for @logsCacheRow.
  ///
  /// In zh, this message translates to:
  /// **'{ttl} · 命中 {count} 次 · {size} B'**
  String logsCacheRow(Object count, Object size, Object ttl);

  /// No description provided for @logsLastHitAt.
  ///
  /// In zh, this message translates to:
  /// **'最后命中 {time}'**
  String logsLastHitAt(Object time);

  /// No description provided for @logsCacheFooterCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条，按命中次数与过期时间排序。剩余 TTL 少于 30 秒的条目标橙色。点按一行查看详情，可复制域名、加入黑白名单或用 AI 分析。'**
  String logsCacheFooterCount(Object count);

  /// No description provided for @logsSubStatsRow.
  ///
  /// In zh, this message translates to:
  /// **'{status} | 拦截 {count} 次 | {percent}'**
  String logsSubStatsRow(Object count, Object percent, Object status);

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get aboutMore;

  /// No description provided for @aboutProject.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get aboutProject;

  /// No description provided for @aboutJoinQq.
  ///
  /// In zh, this message translates to:
  /// **'加入 QQ 群'**
  String get aboutJoinQq;

  /// No description provided for @aboutQqGroup.
  ///
  /// In zh, this message translates to:
  /// **'群号 {number}'**
  String aboutQqGroup(Object number);

  /// No description provided for @aboutSponsor.
  ///
  /// In zh, this message translates to:
  /// **'赞助'**
  String get aboutSponsor;

  /// No description provided for @aboutCredits.
  ///
  /// In zh, this message translates to:
  /// **'开源致谢'**
  String get aboutCredits;

  /// No description provided for @aboutCreditsUi.
  ///
  /// In zh, this message translates to:
  /// **'界面组件与交互实现复用自该项目'**
  String get aboutCreditsUi;

  /// No description provided for @aboutCreditsCore.
  ///
  /// In zh, this message translates to:
  /// **'Go 隧道内核最初魔改自该项目'**
  String get aboutCreditsCore;

  /// No description provided for @aboutCreditsBody.
  ///
  /// In zh, this message translates to:
  /// **'上述两个项目均以 GPL-3.0 协议开源，相关代码与设计的版权归各自作者所有。谛听的界面层大量借鉴了 FlClash 的实现思路，隧道内核也源自 blockads-android 的早期改造；在此向它们的作者与所有贡献者致以诚挚谢意。'**
  String get aboutCreditsBody;

  /// No description provided for @aboutSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get aboutSettings;

  /// No description provided for @aboutStartupCheck.
  ///
  /// In zh, this message translates to:
  /// **'关闭启动时检查更新'**
  String get aboutStartupCheck;

  /// No description provided for @aboutStartupCheckOn.
  ///
  /// In zh, this message translates to:
  /// **'应用启动时不自动检查，可随时手动检查'**
  String get aboutStartupCheckOn;

  /// No description provided for @aboutStartupCheckOff.
  ///
  /// In zh, this message translates to:
  /// **'应用启动时自动检查新版本'**
  String get aboutStartupCheckOff;

  /// No description provided for @aboutDisclaimerEntry.
  ///
  /// In zh, this message translates to:
  /// **'使用须知与免责声明'**
  String get aboutDisclaimerEntry;

  /// No description provided for @aboutDisclaimerEntryBody.
  ///
  /// In zh, this message translates to:
  /// **'软件说明、运行机制与免责条款全文'**
  String get aboutDisclaimerEntryBody;

  /// No description provided for @aboutOtherContributors.
  ///
  /// In zh, this message translates to:
  /// **'其他贡献者'**
  String get aboutOtherContributors;

  /// No description provided for @aboutSponsorList.
  ///
  /// In zh, this message translates to:
  /// **'赞助者名单'**
  String get aboutSponsorList;

  /// No description provided for @aboutSponsorListBody.
  ///
  /// In zh, this message translates to:
  /// **'鸣谢支持谛听项目的赞助者'**
  String get aboutSponsorListBody;

  /// No description provided for @aboutBuilderList.
  ///
  /// In zh, this message translates to:
  /// **'共建者名单'**
  String get aboutBuilderList;

  /// No description provided for @aboutBuilderListBody.
  ///
  /// In zh, this message translates to:
  /// **'感谢为谛听贡献代码与建议的共建者'**
  String get aboutBuilderListBody;

  /// No description provided for @aboutInstallerFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法调起系统安装器'**
  String get aboutInstallerFailed;

  /// No description provided for @aboutAppName.
  ///
  /// In zh, this message translates to:
  /// **'谛听'**
  String get aboutAppName;

  /// No description provided for @aboutTagline.
  ///
  /// In zh, this message translates to:
  /// **'基于 Android VpnService 的本地优先 DNS 加速与流量过滤工具，简单易用，开源无广告。'**
  String get aboutTagline;

  /// No description provided for @aboutChecking.
  ///
  /// In zh, this message translates to:
  /// **'检查中…'**
  String get aboutChecking;

  /// No description provided for @aboutCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdate;

  /// No description provided for @aboutDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中…'**
  String get aboutDownloading;

  /// No description provided for @aboutInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get aboutInstall;

  /// No description provided for @aboutDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get aboutDownload;

  /// No description provided for @aboutCheckingRelease.
  ///
  /// In zh, this message translates to:
  /// **'正在检查 GitHub Release'**
  String get aboutCheckingRelease;

  /// No description provided for @aboutUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本{version}'**
  String aboutUpToDate(Object version);

  /// No description provided for @aboutVersionSuffix.
  ///
  /// In zh, this message translates to:
  /// **'（{version}）'**
  String aboutVersionSuffix(Object version);

  /// No description provided for @aboutFoundVersion.
  ///
  /// In zh, this message translates to:
  /// **'发现 {version}版本'**
  String aboutFoundVersion(Object version);

  /// No description provided for @aboutCurrentSuffix.
  ///
  /// In zh, this message translates to:
  /// **'（当前 {version}）'**
  String aboutCurrentSuffix(Object version);

  /// No description provided for @aboutNew.
  ///
  /// In zh, this message translates to:
  /// **'新'**
  String get aboutNew;

  /// No description provided for @aboutNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'新版本'**
  String get aboutNewVersion;

  /// No description provided for @aboutUpdatePackage.
  ///
  /// In zh, this message translates to:
  /// **'{version} 更新包'**
  String aboutUpdatePackage(Object version);

  /// No description provided for @aboutLinkCopyFallback.
  ///
  /// In zh, this message translates to:
  /// **'未能打开浏览器，链接已复制：{url}'**
  String aboutLinkCopyFallback(Object url);

  /// No description provided for @devStressLogs.
  ///
  /// In zh, this message translates to:
  /// **'日志压测'**
  String get devStressLogs;

  /// No description provided for @devStressLogsBody.
  ///
  /// In zh, this message translates to:
  /// **'向当前模式的日志库真实写入 {count} 条 DNS 日志'**
  String devStressLogsBody(Object count);

  /// No description provided for @devErrorReport.
  ///
  /// In zh, this message translates to:
  /// **'错误上报自检'**
  String get devErrorReport;

  /// No description provided for @devErrorReportBody.
  ///
  /// In zh, this message translates to:
  /// **'通过 FlutterError 上报一条测试异常，验证错误链路'**
  String get devErrorReportBody;

  /// No description provided for @devClearAll.
  ///
  /// In zh, this message translates to:
  /// **'清空全部数据'**
  String get devClearAll;

  /// No description provided for @devClearAllBody.
  ///
  /// In zh, this message translates to:
  /// **'删除配置、规则与日志，恢复出厂状态'**
  String get devClearAllBody;

  /// No description provided for @devVacuum.
  ///
  /// In zh, this message translates to:
  /// **'压缩数据库'**
  String get devVacuum;

  /// No description provided for @devVacuumBody.
  ///
  /// In zh, this message translates to:
  /// **'对三个本地库执行 VACUUM，回收已删除记录占用的空间'**
  String get devVacuumBody;

  /// No description provided for @devCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get devCancel;

  /// No description provided for @devRun.
  ///
  /// In zh, this message translates to:
  /// **'执行'**
  String get devRun;

  /// No description provided for @devConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'{action}\n\n该操作会真正改写本机数据，无法撤销。'**
  String devConfirmBody(Object action);

  /// No description provided for @devActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败：{error}'**
  String devActionFailed(Object action, Object error);

  /// No description provided for @devStressNoDb.
  ///
  /// In zh, this message translates to:
  /// **'日志压测失败：无法打开日志数据库'**
  String get devStressNoDb;

  /// No description provided for @devStressDone.
  ///
  /// In zh, this message translates to:
  /// **'日志压测完成：写入 {count} 条到 {file}'**
  String devStressDone(Object count, Object file);

  /// No description provided for @devTestException.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项触发的测试异常'**
  String get devTestException;

  /// No description provided for @devErrorReported.
  ///
  /// In zh, this message translates to:
  /// **'已上报一条 FlutterError：开发者选项触发的测试异常'**
  String get devErrorReported;

  /// No description provided for @devVacuumNoDb.
  ///
  /// In zh, this message translates to:
  /// **'压缩数据库失败：本机还没有数据库文件'**
  String get devVacuumNoDb;

  /// No description provided for @devVacuumDone.
  ///
  /// In zh, this message translates to:
  /// **'已压缩 {files}，回收 {kb} KB'**
  String devVacuumDone(Object files, Object kb);

  /// No description provided for @devRestartNeeded.
  ///
  /// In zh, this message translates to:
  /// **'需要重启'**
  String get devRestartNeeded;

  /// No description provided for @devLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get devLater;

  /// No description provided for @devQuitNow.
  ///
  /// In zh, this message translates to:
  /// **'立即退出'**
  String get devQuitNow;

  /// No description provided for @devClearAllDone.
  ///
  /// In zh, this message translates to:
  /// **'全部数据已清空，需要重新启动应用才能从出厂状态进入。'**
  String get devClearAllDone;

  /// No description provided for @devOptions.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项'**
  String get devOptions;

  /// No description provided for @devDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'诊断与观测'**
  String get devDiagnostics;

  /// No description provided for @devIpQuality.
  ///
  /// In zh, this message translates to:
  /// **'IP 质量'**
  String get devIpQuality;

  /// No description provided for @devIpQualityBody.
  ///
  /// In zh, this message translates to:
  /// **'实测出口地址与三个公开情报源的类型判断'**
  String get devIpQualityBody;

  /// No description provided for @devRequestLogs.
  ///
  /// In zh, this message translates to:
  /// **'请求日志'**
  String get devRequestLogs;

  /// No description provided for @devRequestLogsBody.
  ///
  /// In zh, this message translates to:
  /// **'合并 http_request_log 与 dns_log 的实时请求记录'**
  String get devRequestLogsBody;

  /// No description provided for @devLogRetention.
  ///
  /// In zh, this message translates to:
  /// **'日志保留'**
  String get devLogRetention;

  /// No description provided for @devLogRetentionBody.
  ///
  /// In zh, this message translates to:
  /// **'日志容量上限与 DNS 请求日志的记录范围'**
  String get devLogRetentionBody;

  /// No description provided for @devTroubleshoot.
  ///
  /// In zh, this message translates to:
  /// **'故障排查'**
  String get devTroubleshoot;

  /// No description provided for @devTroubleshootBody.
  ///
  /// In zh, this message translates to:
  /// **'导出崩溃日志，手动抓取并导出运行日志'**
  String get devTroubleshootBody;

  /// No description provided for @devDataCleanup.
  ///
  /// In zh, this message translates to:
  /// **'数据清理'**
  String get devDataCleanup;

  /// No description provided for @devUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'实验动作已解锁'**
  String get devUnlocked;

  /// No description provided for @devLocked.
  ///
  /// In zh, this message translates to:
  /// **'关闭时下面的动作不可用'**
  String get devLocked;

  /// No description provided for @devWarning.
  ///
  /// In zh, this message translates to:
  /// **'这里的动作会真的改写本机数据（日志库、prefs、数据库文件），其中「清空全部数据」不可撤销，不要在生产环境打开。'**
  String get devWarning;

  /// No description provided for @devRunning.
  ///
  /// In zh, this message translates to:
  /// **'执行中…'**
  String get devRunning;

  /// No description provided for @sponsorGithub.
  ///
  /// In zh, this message translates to:
  /// **'在 GitHub 查看赞助方式'**
  String get sponsorGithub;

  /// No description provided for @sponsorReadme.
  ///
  /// In zh, this message translates to:
  /// **'查看 README 中的赞助说明'**
  String get sponsorReadme;

  /// No description provided for @sponsorReadmeCopied.
  ///
  /// In zh, this message translates to:
  /// **'未能打开浏览器，README 地址已复制'**
  String get sponsorReadmeCopied;

  /// No description provided for @sponsorThanks.
  ///
  /// In zh, this message translates to:
  /// **'致谢名单'**
  String get sponsorThanks;

  /// No description provided for @sponsorThanksBody.
  ///
  /// In zh, this message translates to:
  /// **'感谢每一位支持项目的朋友'**
  String get sponsorThanksBody;

  /// No description provided for @sponsorBuildersBody.
  ///
  /// In zh, this message translates to:
  /// **'感谢提出建议与帮助测试的伙伴'**
  String get sponsorBuildersBody;

  /// No description provided for @sponsorUsage.
  ///
  /// In zh, this message translates to:
  /// **'你的每一笔支持都会用于'**
  String get sponsorUsage;

  /// No description provided for @sponsorUsageNewFeatures.
  ///
  /// In zh, this message translates to:
  /// **'持续开发新功能'**
  String get sponsorUsageNewFeatures;

  /// No description provided for @sponsorUsageBugs.
  ///
  /// In zh, this message translates to:
  /// **'修复 Bug'**
  String get sponsorUsageBugs;

  /// No description provided for @sponsorUsageTokens.
  ///
  /// In zh, this message translates to:
  /// **'购买词元'**
  String get sponsorUsageTokens;

  /// No description provided for @sponsorFreeWays.
  ///
  /// In zh, this message translates to:
  /// **'即使不捐赠，也欢迎'**
  String get sponsorFreeWays;

  /// No description provided for @sponsorFreeStar.
  ///
  /// In zh, this message translates to:
  /// **'点一个 Star⭐'**
  String get sponsorFreeStar;

  /// No description provided for @sponsorFreeIssue.
  ///
  /// In zh, this message translates to:
  /// **'提交 Issue'**
  String get sponsorFreeIssue;

  /// No description provided for @sponsorFreePr.
  ///
  /// In zh, this message translates to:
  /// **'提交 PR'**
  String get sponsorFreePr;

  /// No description provided for @sponsorFreeShare.
  ///
  /// In zh, this message translates to:
  /// **'分享给更多人'**
  String get sponsorFreeShare;

  /// No description provided for @sponsorFooter.
  ///
  /// In zh, this message translates to:
  /// **'感谢每一位支持项目的朋友！'**
  String get sponsorFooter;

  /// No description provided for @sponsorBuyDrink.
  ///
  /// In zh, this message translates to:
  /// **'请作者喝杯蜜雪 🧋'**
  String get sponsorBuyDrink;

  /// No description provided for @sponsorNote.
  ///
  /// In zh, this message translates to:
  /// **'如果这个项目帮助到了你，欢迎请作者喝杯蜜雪。付款时请备注昵称，以便同步加入赞助者名单。'**
  String get sponsorNote;

  /// No description provided for @sponsorAlipay.
  ///
  /// In zh, this message translates to:
  /// **'支付宝'**
  String get sponsorAlipay;

  /// No description provided for @sponsorWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信支付'**
  String get sponsorWechat;

  /// No description provided for @sponsorNickname.
  ///
  /// In zh, this message translates to:
  /// **'备注昵称'**
  String get sponsorNickname;

  /// No description provided for @sponsorScan.
  ///
  /// In zh, this message translates to:
  /// **'扫码赞助'**
  String get sponsorScan;

  /// No description provided for @sponsorQrCode.
  ///
  /// In zh, this message translates to:
  /// **'{label} 收款码'**
  String sponsorQrCode(Object label);

  /// No description provided for @sponsorClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get sponsorClose;

  /// No description provided for @sponsorNoteShort.
  ///
  /// In zh, this message translates to:
  /// **'付款时请备注昵称，以便同步加入赞助者名单。'**
  String get sponsorNoteShort;

  /// No description provided for @aboutQqCopied.
  ///
  /// In zh, this message translates to:
  /// **'未检测到 QQ，群号已复制：{number}'**
  String aboutQqCopied(Object number);

  /// No description provided for @disclaimerTitle.
  ///
  /// In zh, this message translates to:
  /// **'免责声明'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerTerms.
  ///
  /// In zh, this message translates to:
  /// **'条款全文'**
  String get disclaimerTerms;

  /// No description provided for @disclaimerSource.
  ///
  /// In zh, this message translates to:
  /// **'正式条款以仓库 NOTICE.md 与随包 LICENSE 为准。'**
  String get disclaimerSource;

  /// No description provided for @ipQualityRedetect.
  ///
  /// In zh, this message translates to:
  /// **'重新检测'**
  String get ipQualityRedetect;

  /// No description provided for @ipQualityEgress.
  ///
  /// In zh, this message translates to:
  /// **'当前出口地址'**
  String get ipQualityEgress;

  /// No description provided for @ipQualitySources.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get ipQualitySources;

  /// No description provided for @ipQualitySourcesFooter.
  ///
  /// In zh, this message translates to:
  /// **'各来源对「住宅 / 机房」的判断经常互相矛盾：命中数越多越可信，但单一来源的「风险」标签不足以作为结论。'**
  String get ipQualitySourcesFooter;

  /// No description provided for @ipQualityQuerying.
  ///
  /// In zh, this message translates to:
  /// **'正在查询出口 IP 与 3 个情报源…'**
  String get ipQualityQuerying;

  /// No description provided for @ipQualityChecking.
  ///
  /// In zh, this message translates to:
  /// **'检测中…'**
  String get ipQualityChecking;

  /// No description provided for @ipQualityDetecting.
  ///
  /// In zh, this message translates to:
  /// **'正在检测'**
  String get ipQualityDetecting;

  /// No description provided for @ipQualityFailed.
  ///
  /// In zh, this message translates to:
  /// **'检测失败'**
  String get ipQualityFailed;

  /// No description provided for @ipQualityNotYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未检测'**
  String get ipQualityNotYet;

  /// No description provided for @ipQualityDetectingBody.
  ///
  /// In zh, this message translates to:
  /// **'正在获取出口 IP 并查询情报源，请稍候'**
  String get ipQualityDetectingBody;

  /// No description provided for @ipQualityStartBody.
  ///
  /// In zh, this message translates to:
  /// **'点下方按钮开始检测当前出口 IP 的质量'**
  String get ipQualityStartBody;

  /// No description provided for @ipQualityStart.
  ///
  /// In zh, this message translates to:
  /// **'开始检测'**
  String get ipQualityStart;

  /// No description provided for @ipQualityJudgedAs.
  ///
  /// In zh, this message translates to:
  /// **'判定为{type}'**
  String ipQualityJudgedAs(Object type);

  /// No description provided for @ipQualityNotUsed.
  ///
  /// In zh, this message translates to:
  /// **'未采用'**
  String get ipQualityNotUsed;

  /// No description provided for @ipQualityUsed.
  ///
  /// In zh, this message translates to:
  /// **'已采用'**
  String get ipQualityUsed;

  /// No description provided for @devFooterWarning.
  ///
  /// In zh, this message translates to:
  /// **'这些动作直接作用于本机的数据库、prefs 与 native 通道：日志压测会真的写入 {count} 条日志，压缩数据库执行的是 SQLite VACUUM，清空全部数据会删除所有本地数据并要求重启。'**
  String devFooterWarning(Object count);

  /// No description provided for @devDataCleanupBody.
  ///
  /// In zh, this message translates to:
  /// **'按类别删除日志、权重、规则与缓存'**
  String get devDataCleanupBody;

  /// No description provided for @devConfigSection.
  ///
  /// In zh, this message translates to:
  /// **'配置与资源'**
  String get devConfigSection;

  /// No description provided for @devCustomResources.
  ///
  /// In zh, this message translates to:
  /// **'自定义资源'**
  String get devCustomResources;

  /// No description provided for @devCustomResourcesBody.
  ///
  /// In zh, this message translates to:
  /// **'User-Agent、按需连接等配置资源入口'**
  String get devCustomResourcesBody;

  /// No description provided for @devUserAgentBody.
  ///
  /// In zh, this message translates to:
  /// **'订阅下载与测速请求携带的 UA'**
  String get devUserAgentBody;

  /// No description provided for @devOnDemand.
  ///
  /// In zh, this message translates to:
  /// **'按需连接'**
  String get devOnDemand;

  /// No description provided for @devOnDemandBody.
  ///
  /// In zh, this message translates to:
  /// **'按 SSID 决定是否启动 VPN'**
  String get devOnDemandBody;

  /// No description provided for @devWebdav.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 云同步'**
  String get devWebdav;

  /// No description provided for @devWebdavBody.
  ///
  /// In zh, this message translates to:
  /// **'把备份真实上传到自建的 WebDAV 服务'**
  String get devWebdavBody;

  /// No description provided for @devUiSection.
  ///
  /// In zh, this message translates to:
  /// **'界面与外观保留项'**
  String get devUiSection;

  /// No description provided for @devFontFamilyBody.
  ///
  /// In zh, this message translates to:
  /// **'选择界面字体族，独立页'**
  String get devFontFamilyBody;

  /// No description provided for @devFontSizeBody.
  ///
  /// In zh, this message translates to:
  /// **'全局文字缩放；在外观设置「界面显示」组内联滑杆'**
  String get devFontSizeBody;

  /// No description provided for @devTabAnimation.
  ///
  /// In zh, this message translates to:
  /// **'Tab 动画'**
  String get devTabAnimation;

  /// No description provided for @devTabAnimationBody.
  ///
  /// In zh, this message translates to:
  /// **'切换底部标签时的入场动画；在外观设置「背景与动效」组内联选项'**
  String get devTabAnimationBody;

  /// No description provided for @devExperimental.
  ///
  /// In zh, this message translates to:
  /// **'实验动作'**
  String get devExperimental;

  /// No description provided for @devLegacyFooter.
  ///
  /// In zh, this message translates to:
  /// **'以上「诊断与观测」「配置与资源」「界面与外观保留项」里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；旧版对应的功能仍按旧版菜单进入，不经过本页。'**
  String get devLegacyFooter;

  /// No description provided for @unknownRouteTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面不存在'**
  String get unknownRouteTitle;

  /// No description provided for @unknownRouteBody.
  ///
  /// In zh, this message translates to:
  /// **'找不到这个页面'**
  String get unknownRouteBody;

  /// No description provided for @unknownRouteBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get unknownRouteBack;

  /// No description provided for @disclaimerReadFirst.
  ///
  /// In zh, this message translates to:
  /// **'使用前请阅读'**
  String get disclaimerReadFirst;

  /// No description provided for @disclaimerIntro.
  ///
  /// In zh, this message translates to:
  /// **'谛听是一款开源的本地域名解析与流量观测工具。软件本身不提供、不代理、也不转发任何网络接入服务，全部数据都在本机处理。'**
  String get disclaimerIntro;

  /// No description provided for @disclaimerLawful.
  ///
  /// In zh, this message translates to:
  /// **'请在遵守所在地法律法规的前提下使用本软件。将本软件用于任何未经授权的网络环境，后果由使用者自行承担。'**
  String get disclaimerLawful;

  /// No description provided for @disclaimerFirstRun.
  ///
  /// In zh, this message translates to:
  /// **'首次启动时确认的文本'**
  String get disclaimerFirstRun;

  /// No description provided for @disclaimerImmutable.
  ///
  /// In zh, this message translates to:
  /// **'不可修改'**
  String get disclaimerImmutable;

  /// No description provided for @devFontFamily.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get devFontFamily;

  /// No description provided for @devFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get devFontSize;

  /// No description provided for @devWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者模式'**
  String get devWarningTitle;

  /// No description provided for @devFooterLegacy.
  ///
  /// In zh, this message translates to:
  /// **'以上「诊断与观测」「配置与资源」「界面与外观保留项」里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；旧版对应的功能仍按旧版菜单进入，不经过本页。'**
  String get devFooterLegacy;

  /// No description provided for @ipTypeResidential.
  ///
  /// In zh, this message translates to:
  /// **'住宅'**
  String get ipTypeResidential;

  /// No description provided for @ipTypeMobile.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get ipTypeMobile;

  /// No description provided for @ipTypeBusiness.
  ///
  /// In zh, this message translates to:
  /// **'商业'**
  String get ipTypeBusiness;

  /// No description provided for @ipTypeHosting.
  ///
  /// In zh, this message translates to:
  /// **'机房'**
  String get ipTypeHosting;

  /// No description provided for @ipLevelGood.
  ///
  /// In zh, this message translates to:
  /// **'优秀'**
  String get ipLevelGood;

  /// No description provided for @ipLevelNormal.
  ///
  /// In zh, this message translates to:
  /// **'一般'**
  String get ipLevelNormal;

  /// No description provided for @ipLevelRisky.
  ///
  /// In zh, this message translates to:
  /// **'风险'**
  String get ipLevelRisky;

  /// No description provided for @ipStatusOk.
  ///
  /// In zh, this message translates to:
  /// **'命中'**
  String get ipStatusOk;

  /// No description provided for @ipStatusNoType.
  ///
  /// In zh, this message translates to:
  /// **'无类型'**
  String get ipStatusNoType;

  /// No description provided for @ipStatusTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时'**
  String get ipStatusTimeout;

  /// No description provided for @ipStatusRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'限流'**
  String get ipStatusRateLimited;

  /// No description provided for @ipStatusMismatch.
  ///
  /// In zh, this message translates to:
  /// **'IP 不一致'**
  String get ipStatusMismatch;

  /// No description provided for @modeSelectTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择工作模式'**
  String get modeSelectTitle;

  /// No description provided for @modeContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get modeContinue;

  /// No description provided for @modeSwitchNote.
  ///
  /// In zh, this message translates to:
  /// **'随时可以在设置里重新选择；切换模式会先停止当前模式的服务，两个模式不会同时运行。'**
  String get modeSwitchNote;

  /// No description provided for @modeSharedNote.
  ///
  /// In zh, this message translates to:
  /// **'三种模式共用一套规则与缓存，区别在接管方式：普通模式走全隧道，服务器模式只做局域网 DNS，极速模式是纯 Kotlin 窄路由。'**
  String get modeSharedNote;

  /// No description provided for @modeNormalFeature1.
  ///
  /// In zh, this message translates to:
  /// **'全隧道接管'**
  String get modeNormalFeature1;

  /// No description provided for @modeNormalFeature1Body.
  ///
  /// In zh, this message translates to:
  /// **'Go 栈接管全部流量，可按应用分流'**
  String get modeNormalFeature1Body;

  /// No description provided for @modeNormalFeature2.
  ///
  /// In zh, this message translates to:
  /// **'全功能规则'**
  String get modeNormalFeature2;

  /// No description provided for @modeNormalFeature2Body.
  ///
  /// In zh, this message translates to:
  /// **'黑白名单、覆写、HTTPS 检查全部可用'**
  String get modeNormalFeature2Body;

  /// No description provided for @modeNormalFeature3.
  ///
  /// In zh, this message translates to:
  /// **'可选 HTTPS 检查'**
  String get modeNormalFeature3;

  /// No description provided for @modeNormalFeature3Body.
  ///
  /// In zh, this message translates to:
  /// **'需要安装并信任本地 CA 证书'**
  String get modeNormalFeature3Body;

  /// No description provided for @modeNormalFeature4.
  ///
  /// In zh, this message translates to:
  /// **'应用流量统计'**
  String get modeNormalFeature4;

  /// No description provided for @modeNormalFeature4Body.
  ///
  /// In zh, this message translates to:
  /// **'按应用记录上下行与查询数'**
  String get modeNormalFeature4Body;

  /// No description provided for @modeServerFeature1.
  ///
  /// In zh, this message translates to:
  /// **'局域网 DNS 服务'**
  String get modeServerFeature1;

  /// No description provided for @modeServerFeature1Body.
  ///
  /// In zh, this message translates to:
  /// **'监听 0.0.0.0，供同一网段设备使用'**
  String get modeServerFeature1Body;

  /// No description provided for @modeServerFeature2.
  ///
  /// In zh, this message translates to:
  /// **'不占 VPN 槽位'**
  String get modeServerFeature2;

  /// No description provided for @modeServerFeature2Body.
  ///
  /// In zh, this message translates to:
  /// **'本机不建立隧道，可与其它 VPN 共存'**
  String get modeServerFeature2Body;

  /// No description provided for @modeServerFeature3.
  ///
  /// In zh, this message translates to:
  /// **'共享规则与缓存'**
  String get modeServerFeature3;

  /// No description provided for @modeServerFeature3Body.
  ///
  /// In zh, this message translates to:
  /// **'与普通模式共用同一套规则库'**
  String get modeServerFeature3Body;

  /// No description provided for @modeServerFeature4.
  ///
  /// In zh, this message translates to:
  /// **'低功耗'**
  String get modeServerFeature4;

  /// No description provided for @modeServerFeature4Body.
  ///
  /// In zh, this message translates to:
  /// **'只处理 DNS 查询，无流量转发'**
  String get modeServerFeature4Body;

  /// No description provided for @modeExpressFeature1.
  ///
  /// In zh, this message translates to:
  /// **'纯 Kotlin 实现'**
  String get modeExpressFeature1;

  /// No description provided for @modeExpressFeature1Body.
  ///
  /// In zh, this message translates to:
  /// **'窄路由，启动与切换都更快'**
  String get modeExpressFeature1Body;

  /// No description provided for @modeExpressFeature2.
  ///
  /// In zh, this message translates to:
  /// **'四种上游调度'**
  String get modeExpressFeature2;

  /// No description provided for @modeExpressFeature2Body.
  ///
  /// In zh, this message translates to:
  /// **'单服务商 / 智能 / 竞速 / 主备'**
  String get modeExpressFeature2Body;

  /// No description provided for @modeExpressFeature3.
  ///
  /// In zh, this message translates to:
  /// **'64 分片 LRU 缓存'**
  String get modeExpressFeature3;

  /// No description provided for @modeExpressFeature3Body.
  ///
  /// In zh, this message translates to:
  /// **'命中率高、内存占用可控'**
  String get modeExpressFeature3Body;

  /// No description provided for @modeExpressFeature4.
  ///
  /// In zh, this message translates to:
  /// **'兼容更旧系统'**
  String get modeExpressFeature4;

  /// No description provided for @modeExpressFeature4Body.
  ///
  /// In zh, this message translates to:
  /// **'Android 7+（需 64 位）'**
  String get modeExpressFeature4Body;

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'引导'**
  String get onboardingTitle;

  /// No description provided for @onboardingSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过引导'**
  String get onboardingSkip;

  /// No description provided for @onboardingPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get onboardingPrev;

  /// No description provided for @onboardingStart.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get onboardingStart;

  /// No description provided for @onboardingNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get onboardingNext;

  /// No description provided for @onboardingChosen.
  ///
  /// In zh, this message translates to:
  /// **'你选择了{mode}'**
  String onboardingChosen(Object mode);

  /// No description provided for @onboardingChangeable.
  ///
  /// In zh, this message translates to:
  /// **'之后还能改'**
  String get onboardingChangeable;

  /// No description provided for @onboardingChangeableBody.
  ///
  /// In zh, this message translates to:
  /// **'设置 → 重新选择工作模式，随时可以切换。切换会先停止当前模式的服务。'**
  String get onboardingChangeableBody;

  /// No description provided for @onboardingSharedRules.
  ///
  /// In zh, this message translates to:
  /// **'规则与缓存共用'**
  String get onboardingSharedRules;

  /// No description provided for @onboardingSharedRulesBody.
  ///
  /// In zh, this message translates to:
  /// **'三种模式共享同一套黑白名单与 DNS 缓存，不必为每个模式重配一遍。'**
  String get onboardingSharedRulesBody;

  /// No description provided for @onboardingExclusive.
  ///
  /// In zh, this message translates to:
  /// **'模式互斥'**
  String get onboardingExclusive;

  /// No description provided for @onboardingExclusiveBody.
  ///
  /// In zh, this message translates to:
  /// **'同一时刻只有一个模式在运行；离开时会先停掉上一个模式。'**
  String get onboardingExclusiveBody;

  /// No description provided for @permVpn.
  ///
  /// In zh, this message translates to:
  /// **'VPN 连接'**
  String get permVpn;

  /// No description provided for @permNotification.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get permNotification;

  /// No description provided for @permAppList.
  ///
  /// In zh, this message translates to:
  /// **'应用列表'**
  String get permAppList;

  /// No description provided for @permBattery.
  ///
  /// In zh, this message translates to:
  /// **'忽略电池优化'**
  String get permBattery;

  /// No description provided for @permRequired.
  ///
  /// In zh, this message translates to:
  /// **'必需'**
  String get permRequired;

  /// No description provided for @permOptional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get permOptional;

  /// No description provided for @permVpnNormalBody.
  ///
  /// In zh, this message translates to:
  /// **'建立本地隧道接管流量；拒绝则无法启动'**
  String get permVpnNormalBody;

  /// No description provided for @permNotificationBody.
  ///
  /// In zh, this message translates to:
  /// **'前台服务常驻通知；拒绝则服务可能被系统回收'**
  String get permNotificationBody;

  /// No description provided for @permAppListBody.
  ///
  /// In zh, this message translates to:
  /// **'按应用分流与统计；拒绝则只能按域名规则'**
  String get permAppListBody;

  /// No description provided for @permBatteryBody.
  ///
  /// In zh, this message translates to:
  /// **'避免后台被杀；拒绝则长时间待机可能断开'**
  String get permBatteryBody;

  /// No description provided for @permBatteryServerBody.
  ///
  /// In zh, this message translates to:
  /// **'避免后台被杀；拒绝则局域网内会间歇不可用'**
  String get permBatteryServerBody;

  /// No description provided for @permVpnExpressBody.
  ///
  /// In zh, this message translates to:
  /// **'建立窄路由隧道；拒绝则无法启动'**
  String get permVpnExpressBody;

  /// No description provided for @permNeeded.
  ///
  /// In zh, this message translates to:
  /// **'需要这些权限'**
  String get permNeeded;

  /// No description provided for @permAllLocal.
  ///
  /// In zh, this message translates to:
  /// **'全部权限只在本机使用，不会上传任何数据。'**
  String get permAllLocal;

  /// No description provided for @permGrantedCount.
  ///
  /// In zh, this message translates to:
  /// **'已授予 {granted} / {total} 项；全部权限只在本机使用，不会上传任何数据。'**
  String permGrantedCount(Object granted, Object total);

  /// No description provided for @onboardingTipNormal1.
  ///
  /// In zh, this message translates to:
  /// **'点首页的大圆钮启动服务，第一次会弹出系统 VPN 授权。'**
  String get onboardingTipNormal1;

  /// No description provided for @onboardingTipNormal2.
  ///
  /// In zh, this message translates to:
  /// **'黑名单 / 白名单在「功能中心 → 规则与订阅」里维护。'**
  String get onboardingTipNormal2;

  /// No description provided for @onboardingTipNormal3.
  ///
  /// In zh, this message translates to:
  /// **'首页句子和透明度都能在设置里改。'**
  String get onboardingTipNormal3;

  /// No description provided for @onboardingTipServer1.
  ///
  /// In zh, this message translates to:
  /// **'启动后把同网段设备的 DNS 指向「局域网接入」里显示的地址。'**
  String get onboardingTipServer1;

  /// No description provided for @onboardingTipServer2.
  ///
  /// In zh, this message translates to:
  /// **'端口可在「服务器模式」页改，默认 5353。'**
  String get onboardingTipServer2;

  /// No description provided for @onboardingTipServer3.
  ///
  /// In zh, this message translates to:
  /// **'本模式不建立 VPN，可与其它 VPN 同时运行。'**
  String get onboardingTipServer3;

  /// No description provided for @onboardingTipExpress1.
  ///
  /// In zh, this message translates to:
  /// **'极速模式启动更快，但功能是普通模式的子集。'**
  String get onboardingTipExpress1;

  /// No description provided for @onboardingTipExpress2.
  ///
  /// In zh, this message translates to:
  /// **'多路竞速至少要选 2 家服务商。'**
  String get onboardingTipExpress2;

  /// No description provided for @onboardingTipExpress3.
  ///
  /// In zh, this message translates to:
  /// **'需要 HTTPS 检查或应用管控时请切回普通模式。'**
  String get onboardingTipExpress3;

  /// No description provided for @onboardingReady.
  ///
  /// In zh, this message translates to:
  /// **'可以开始了'**
  String get onboardingReady;

  /// No description provided for @onboardingReadyBody.
  ///
  /// In zh, this message translates to:
  /// **'下面是三条最常用的上手要点。'**
  String get onboardingReadyBody;

  /// No description provided for @onboardingTipIndex.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 条'**
  String onboardingTipIndex(Object index);

  /// No description provided for @permStillDenied.
  ///
  /// In zh, this message translates to:
  /// **'{name} 仍未授予，请在系统设置里允许后返回本页'**
  String permStillDenied(Object name);

  /// No description provided for @permGranted.
  ///
  /// In zh, this message translates to:
  /// **'已授予'**
  String get permGranted;

  /// No description provided for @permDenied.
  ///
  /// In zh, this message translates to:
  /// **'未授予'**
  String get permDenied;

  /// No description provided for @permUnknown.
  ///
  /// In zh, this message translates to:
  /// **'状态未知'**
  String get permUnknown;

  /// No description provided for @permGrant.
  ///
  /// In zh, this message translates to:
  /// **'去授予'**
  String get permGrant;

  /// No description provided for @toolSpeedTest.
  ///
  /// In zh, this message translates to:
  /// **'测速'**
  String get toolSpeedTest;

  /// No description provided for @toolPing.
  ///
  /// In zh, this message translates to:
  /// **'Ping 测试'**
  String get toolPing;

  /// No description provided for @toolDnsLookup.
  ///
  /// In zh, this message translates to:
  /// **'DNS 解析'**
  String get toolDnsLookup;

  /// No description provided for @toolTraceroute.
  ///
  /// In zh, this message translates to:
  /// **'路由追踪'**
  String get toolTraceroute;

  /// No description provided for @toolDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'网络诊断'**
  String get toolDiagnostics;

  /// No description provided for @toolRefreshInfo.
  ///
  /// In zh, this message translates to:
  /// **'刷新网络信息'**
  String get toolRefreshInfo;

  /// No description provided for @toolActiveInterface.
  ///
  /// In zh, this message translates to:
  /// **'活动接口'**
  String get toolActiveInterface;

  /// No description provided for @toolLocalAddress.
  ///
  /// In zh, this message translates to:
  /// **'本机地址'**
  String get toolLocalAddress;

  /// No description provided for @toolDnsServers.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务器'**
  String get toolDnsServers;

  /// No description provided for @toolCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'个'**
  String get toolCountUnit;

  /// No description provided for @toolPrivateDnsProbe.
  ///
  /// In zh, this message translates to:
  /// **'探测走物理网络（本应用流量不经过隧道）；系统私人 DNS：{dns}'**
  String toolPrivateDnsProbe(Object dns);

  /// No description provided for @toolPhysicalProbe.
  ///
  /// In zh, this message translates to:
  /// **'探测走物理网络：本应用自身流量被排除在隧道外，下面四个工具测的都是物理链路的真实时延。'**
  String get toolPhysicalProbe;

  /// No description provided for @toolInputHostOrIp.
  ///
  /// In zh, this message translates to:
  /// **'输入 IP 或域名'**
  String get toolInputHostOrIp;

  /// No description provided for @toolPingCount4.
  ///
  /// In zh, this message translates to:
  /// **'4 次'**
  String get toolPingCount4;

  /// No description provided for @toolPingCount10.
  ///
  /// In zh, this message translates to:
  /// **'10 次'**
  String get toolPingCount10;

  /// No description provided for @toolPingOptions.
  ///
  /// In zh, this message translates to:
  /// **'探测选项'**
  String get toolPingOptions;

  /// No description provided for @toolViaTunnel.
  ///
  /// In zh, this message translates to:
  /// **'通过 Go 隧道解析'**
  String get toolViaTunnel;

  /// No description provided for @toolViaTunnelPingBody.
  ///
  /// In zh, this message translates to:
  /// **'域名经运行中的 Go 隧道解析（应用覆写与过滤规则），探测仍走物理网络'**
  String get toolViaTunnelPingBody;

  /// No description provided for @toolStartPing.
  ///
  /// In zh, this message translates to:
  /// **'开始 Ping'**
  String get toolStartPing;

  /// No description provided for @toolPinging.
  ///
  /// In zh, this message translates to:
  /// **'正在探测…'**
  String get toolPinging;

  /// No description provided for @toolTcpFallback.
  ///
  /// In zh, this message translates to:
  /// **'系统 ICMP 受限，已用 TCP 回退测量。此时的时延是连接建立耗时，不能与 ICMP 往返时延直接比较。'**
  String get toolTcpFallback;

  /// No description provided for @toolPingFailed.
  ///
  /// In zh, this message translates to:
  /// **'探测失败：未收到任何回复'**
  String get toolPingFailed;

  /// No description provided for @toolTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get toolTarget;

  /// No description provided for @toolResolvedAddress.
  ///
  /// In zh, this message translates to:
  /// **'解析地址'**
  String get toolResolvedAddress;

  /// No description provided for @toolAddressFamily.
  ///
  /// In zh, this message translates to:
  /// **'地址族'**
  String get toolAddressFamily;

  /// No description provided for @toolSentReceived.
  ///
  /// In zh, this message translates to:
  /// **'发送 / 接收'**
  String get toolSentReceived;

  /// No description provided for @toolPacketLoss.
  ///
  /// In zh, this message translates to:
  /// **'丢包率'**
  String get toolPacketLoss;

  /// No description provided for @toolMinAvgMax.
  ///
  /// In zh, this message translates to:
  /// **'最小 / 平均 / 最大'**
  String get toolMinAvgMax;

  /// No description provided for @toolJitter.
  ///
  /// In zh, this message translates to:
  /// **'抖动'**
  String get toolJitter;

  /// No description provided for @toolJitterFooter.
  ///
  /// In zh, this message translates to:
  /// **'抖动按各包时延与均值的平均绝对偏差计算。'**
  String get toolJitterFooter;

  /// No description provided for @toolPacketN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 个包'**
  String toolPacketN(Object n);

  /// No description provided for @toolTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时'**
  String get toolTimeout;

  /// No description provided for @toolPingSummary.
  ///
  /// In zh, this message translates to:
  /// **'本次共发送 {sent} 个探测包，失败 {failed} 个。'**
  String toolPingSummary(Object failed, Object sent);

  /// No description provided for @toolPingFooter.
  ///
  /// In zh, this message translates to:
  /// **'Ping 由原生侧执行：优先调用系统 ping 二进制，不可用时回退到地址可达性与 TCP 端口握手计时，并会明确标注。'**
  String get toolPingFooter;

  /// No description provided for @toolDnsSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get toolDnsSystem;

  /// No description provided for @toolDnsCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get toolDnsCustom;

  /// No description provided for @toolCustomDnsError.
  ///
  /// In zh, this message translates to:
  /// **'请输入自定义 DNS 服务器 IP'**
  String get toolCustomDnsError;

  /// No description provided for @toolInputDomain.
  ///
  /// In zh, this message translates to:
  /// **'输入要解析的域名'**
  String get toolInputDomain;

  /// No description provided for @toolCustomDnsHint.
  ///
  /// In zh, this message translates to:
  /// **'自定义 DNS 服务器 IP（如 1.1.1.1）'**
  String get toolCustomDnsHint;

  /// No description provided for @toolQueryOptions.
  ///
  /// In zh, this message translates to:
  /// **'查询选项'**
  String get toolQueryOptions;

  /// No description provided for @toolViaTunnelDnsBody.
  ///
  /// In zh, this message translates to:
  /// **'开启后由隧道引擎解析，会套用拦截规则与缓存；关闭时直接问系统解析器'**
  String get toolViaTunnelDnsBody;

  /// No description provided for @toolStartQuery.
  ///
  /// In zh, this message translates to:
  /// **'开始查询'**
  String get toolStartQuery;

  /// No description provided for @toolQuerying.
  ///
  /// In zh, this message translates to:
  /// **'查询中…'**
  String get toolQuerying;

  /// No description provided for @toolQueryDomain.
  ///
  /// In zh, this message translates to:
  /// **'查询域名'**
  String get toolQueryDomain;

  /// No description provided for @toolRecordType.
  ///
  /// In zh, this message translates to:
  /// **'记录类型'**
  String get toolRecordType;

  /// No description provided for @toolAnswerSource.
  ///
  /// In zh, this message translates to:
  /// **'答案来源'**
  String get toolAnswerSource;

  /// No description provided for @toolElapsed.
  ///
  /// In zh, this message translates to:
  /// **'耗时'**
  String get toolElapsed;

  /// No description provided for @toolAnswerCount.
  ///
  /// In zh, this message translates to:
  /// **'答案条数'**
  String get toolAnswerCount;

  /// No description provided for @toolDnsBlockedBody.
  ///
  /// In zh, this message translates to:
  /// **'该域名被隧道规则拦截，因此没有真实上游应答。'**
  String get toolDnsBlockedBody;

  /// No description provided for @toolDnsNoAnswers.
  ///
  /// In zh, this message translates to:
  /// **'没有返回任何应答记录。若来源是「被规则拦截」，说明该域名在本机规则里被拦掉了。'**
  String get toolDnsNoAnswers;

  /// No description provided for @toolDnsFooter.
  ///
  /// In zh, this message translates to:
  /// **'「走隧道查询」问的是本软件的解析链路（含规则与缓存），此时服务器由隧道决定；关闭后可选择跟随系统或指定一台 DNS 服务器，两者结果可能不同。'**
  String get toolDnsFooter;

  /// No description provided for @toolTunnelEngine.
  ///
  /// In zh, this message translates to:
  /// **'隧道引擎'**
  String get toolTunnelEngine;

  /// No description provided for @toolSpeedChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查测速通道…'**
  String get toolSpeedChecking;

  /// No description provided for @toolSpeedUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持测速：本机没有提供 DNS 查询耗时测量的原生通道，页面不会显示任何模拟耗时。'**
  String get toolSpeedUnsupported;

  /// No description provided for @toolSpeedDomainHint.
  ///
  /// In zh, this message translates to:
  /// **'用于测速的域名'**
  String get toolSpeedDomainHint;

  /// No description provided for @toolSpeedProviders.
  ///
  /// In zh, this message translates to:
  /// **'测速服务商'**
  String get toolSpeedProviders;

  /// No description provided for @toolNoProviders.
  ///
  /// In zh, this message translates to:
  /// **'暂无 {protocol} DNS 服务商'**
  String toolNoProviders(Object protocol);

  /// No description provided for @toolNoProvidersBody.
  ///
  /// In zh, this message translates to:
  /// **'在「服务商管理」里添加后即可参与测速'**
  String get toolNoProvidersBody;

  /// No description provided for @toolSpeedSelectionNote.
  ///
  /// In zh, this message translates to:
  /// **'可选择 1 个或多个服务商；这里的选择只用于 DNS 查询测速，不影响竞速模式。'**
  String get toolSpeedSelectionNote;

  /// No description provided for @toolTestQueryTime.
  ///
  /// In zh, this message translates to:
  /// **'测试查询耗时'**
  String get toolTestQueryTime;

  /// No description provided for @toolSpeedRunning.
  ///
  /// In zh, this message translates to:
  /// **'测速中…'**
  String get toolSpeedRunning;

  /// No description provided for @toolSpeedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未测速。选好服务商后点上面的按钮，本应用会直接向每个服务商发送 3 次真实 DNS 查询并记录往返耗时。'**
  String get toolSpeedEmpty;

  /// No description provided for @toolSpeedResults.
  ///
  /// In zh, this message translates to:
  /// **'查询耗时结果'**
  String get toolSpeedResults;

  /// No description provided for @toolSpeedResultsFooter.
  ///
  /// In zh, this message translates to:
  /// **'测速结果按成功优先、平均耗时从低到高排序；结果只反映本次查询时的网络状态。域名当前为「{domain}」。'**
  String toolSpeedResultsFooter(Object domain);

  /// No description provided for @toolSpeedFooter.
  ///
  /// In zh, this message translates to:
  /// **'测速由原生侧执行：向每个服务商分别发送真实的 DoH / DoT / 明文 DNS 查询，只有拿到成功应答的样本才计入耗时。'**
  String get toolSpeedFooter;

  /// No description provided for @toolFastest.
  ///
  /// In zh, this message translates to:
  /// **'最快'**
  String get toolFastest;

  /// No description provided for @toolSampleCount.
  ///
  /// In zh, this message translates to:
  /// **'{rate} · 样本 {count}'**
  String toolSampleCount(Object count, Object rate);

  /// No description provided for @toolAllFailed.
  ///
  /// In zh, this message translates to:
  /// **'全部失败（{count} 次）'**
  String toolAllFailed(Object count);

  /// No description provided for @toolTraceOptions.
  ///
  /// In zh, this message translates to:
  /// **'追踪选项'**
  String get toolTraceOptions;

  /// No description provided for @toolStartTrace.
  ///
  /// In zh, this message translates to:
  /// **'开始追踪'**
  String get toolStartTrace;

  /// No description provided for @toolTracing.
  ///
  /// In zh, this message translates to:
  /// **'追踪中…'**
  String get toolTracing;

  /// No description provided for @toolTraceFailed.
  ///
  /// In zh, this message translates to:
  /// **'追踪失败：未收到任何回应'**
  String get toolTraceFailed;

  /// No description provided for @toolTraceCancelled.
  ///
  /// In zh, this message translates to:
  /// **'追踪已取消。'**
  String get toolTraceCancelled;

  /// No description provided for @toolHopCount.
  ///
  /// In zh, this message translates to:
  /// **'跳数'**
  String get toolHopCount;

  /// No description provided for @toolHopCountValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} / 最多 {max}'**
  String toolHopCountValue(Object count, Object max);

  /// No description provided for @toolNoResponse.
  ///
  /// In zh, this message translates to:
  /// **'无响应'**
  String get toolNoResponse;

  /// No description provided for @toolTraceFooter.
  ///
  /// In zh, this message translates to:
  /// **'星号表示该跳在超时时间内没有回包——不代表链路断了，很多路由器不响应探测包。绿色一行表示已到达目标。'**
  String get toolTraceFooter;

  /// No description provided for @toolTraceHops15.
  ///
  /// In zh, this message translates to:
  /// **'15 跳'**
  String get toolTraceHops15;

  /// No description provided for @toolTraceHops30.
  ///
  /// In zh, this message translates to:
  /// **'30 跳'**
  String get toolTraceHops30;

  /// No description provided for @uaDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 User-Agent'**
  String get uaDeleteTitle;

  /// No description provided for @uaDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这一条吗？只删候选，不影响当前已选中的 UA。'**
  String get uaDeleteBody;

  /// No description provided for @uaAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加 User-Agent'**
  String get uaAdd;

  /// No description provided for @uaEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑 User-Agent'**
  String get uaEdit;

  /// No description provided for @uaNote.
  ///
  /// In zh, this message translates to:
  /// **'UA 会随订阅下载、规则集拉取与订阅测速请求一起发送；部分服务端按 UA 拒绝请求，改这里可以绕过。'**
  String get uaNote;

  /// No description provided for @uaCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前选择'**
  String get uaCurrent;

  /// No description provided for @uaNoOverride.
  ///
  /// In zh, this message translates to:
  /// **'不覆写'**
  String get uaNoOverride;

  /// No description provided for @uaNoOverrideBody.
  ///
  /// In zh, this message translates to:
  /// **'沿用订阅或内核自带的 UA'**
  String get uaNoOverrideBody;

  /// No description provided for @uaBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get uaBuiltin;

  /// No description provided for @uaCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get uaCustom;

  /// No description provided for @uaBuiltinNote.
  ///
  /// In zh, this message translates to:
  /// **'内置 UA 不可删除：删掉之后内核回落到默认值，用户会误以为「设置没生效」。'**
  String get uaBuiltinNote;

  /// No description provided for @uaHint.
  ///
  /// In zh, this message translates to:
  /// **'如：clash-verge/v2.0.0'**
  String get uaHint;

  /// No description provided for @uaEmptyError.
  ///
  /// In zh, this message translates to:
  /// **'UA 不能为空'**
  String get uaEmptyError;

  /// No description provided for @uaDuplicateError.
  ///
  /// In zh, this message translates to:
  /// **'该 UA 已存在'**
  String get uaDuplicateError;

  /// No description provided for @ssidInvalid.
  ///
  /// In zh, this message translates to:
  /// **'SSID 不能为空或已存在'**
  String get ssidInvalid;

  /// No description provided for @ssidAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加 SSID'**
  String get ssidAdd;

  /// No description provided for @ssidEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑 SSID'**
  String get ssidEdit;

  /// No description provided for @ssidSave.
  ///
  /// In zh, this message translates to:
  /// **'保存 SSID'**
  String get ssidSave;

  /// No description provided for @ssidHint.
  ///
  /// In zh, this message translates to:
  /// **'区分大小写，与系统 Wi-Fi 列表里的名字完全一致'**
  String get ssidHint;

  /// No description provided for @ssidExample.
  ///
  /// In zh, this message translates to:
  /// **'如：Home-5G'**
  String get ssidExample;

  /// No description provided for @ssidEmptyError.
  ///
  /// In zh, this message translates to:
  /// **'SSID 不能为空'**
  String get ssidEmptyError;

  /// No description provided for @ssidConnection.
  ///
  /// In zh, this message translates to:
  /// **'连接方式'**
  String get ssidConnection;

  /// No description provided for @ssidCellular.
  ///
  /// In zh, this message translates to:
  /// **'蜂窝网络'**
  String get ssidCellular;

  /// No description provided for @ssidCellularBody.
  ///
  /// In zh, this message translates to:
  /// **'在该网络下也启动 VPN'**
  String get ssidCellularBody;

  /// No description provided for @ssidWifiBody.
  ///
  /// In zh, this message translates to:
  /// **'连上该 SSID 时启动 VPN'**
  String get ssidWifiBody;

  /// No description provided for @ssidBothOff.
  ///
  /// In zh, this message translates to:
  /// **'两种都关掉，等于把这条 SSID 从白名单里排除（VPN 不会启动）。'**
  String get ssidBothOff;

  /// No description provided for @ssidDelay.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get ssidDelay;

  /// No description provided for @ssidStartDelay.
  ///
  /// In zh, this message translates to:
  /// **'启动延迟'**
  String get ssidStartDelay;

  /// No description provided for @ssidStartDelayBody.
  ///
  /// In zh, this message translates to:
  /// **'等待网络就绪后再启动 VPN'**
  String get ssidStartDelayBody;

  /// No description provided for @ssidImmediate.
  ///
  /// In zh, this message translates to:
  /// **'立即连接'**
  String get ssidImmediate;

  /// No description provided for @odTitle.
  ///
  /// In zh, this message translates to:
  /// **'按需连接'**
  String get odTitle;

  /// No description provided for @odApplyNow.
  ///
  /// In zh, this message translates to:
  /// **'立即应用'**
  String get odApplyNow;

  /// No description provided for @odEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用按需连接'**
  String get odEnable;

  /// No description provided for @odEnableBody.
  ///
  /// In zh, this message translates to:
  /// **'连上白名单里的 SSID 时自动启动 VPN'**
  String get odEnableBody;

  /// No description provided for @odDisableBody.
  ///
  /// In zh, this message translates to:
  /// **'关闭时 VPN 始终在线，不随网络切换'**
  String get odDisableBody;

  /// No description provided for @odNote.
  ///
  /// In zh, this message translates to:
  /// **'开启后，只有连上白名单里的 SSID 时才会自动启动 VPN；其余网络保持断开，省电也更可控。自动判定只在网络变化时启停 VPN，不会覆盖手动开关的结果；点右上角「立即应用」可立即按当前网络重新判定。'**
  String get odNote;

  /// No description provided for @odAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'SSID 白名单'**
  String get odAllowlist;

  /// No description provided for @odNoSsid.
  ///
  /// In zh, this message translates to:
  /// **'还没有 SSID'**
  String get odNoSsid;

  /// No description provided for @odNoSsidBody.
  ///
  /// In zh, this message translates to:
  /// **'没有白名单时按需连接不会触发'**
  String get odNoSsidBody;

  /// No description provided for @odDelayNote.
  ///
  /// In zh, this message translates to:
  /// **'延迟用于等 Wi-Fi 完成认证与 DHCP；过早启动 VPN 会让首个请求落到尚未就绪的网络上。'**
  String get odDelayNote;

  /// No description provided for @odCellular.
  ///
  /// In zh, this message translates to:
  /// **'蜂窝'**
  String get odCellular;

  /// No description provided for @odKindsNone.
  ///
  /// In zh, this message translates to:
  /// **'不启用'**
  String get odKindsNone;

  /// No description provided for @odDelayValue.
  ///
  /// In zh, this message translates to:
  /// **'延迟 {ms} ms'**
  String odDelayValue(Object ms);

  /// No description provided for @odStateDisabled.
  ///
  /// In zh, this message translates to:
  /// **'按需连接已关闭'**
  String get odStateDisabled;

  /// No description provided for @odStateUnknown.
  ///
  /// In zh, this message translates to:
  /// **'无法读取当前 Wi-Fi，白名单不会触发'**
  String get odStateUnknown;

  /// No description provided for @odStateNoWifi.
  ///
  /// In zh, this message translates to:
  /// **'当前不在 Wi-Fi 上，VPN 保持断开'**
  String get odStateNoWifi;

  /// No description provided for @odStateMatched.
  ///
  /// In zh, this message translates to:
  /// **'已匹配 {ssid}，VPN 会自动启动'**
  String odStateMatched(Object ssid);

  /// No description provided for @odStateUnmatched.
  ///
  /// In zh, this message translates to:
  /// **'当前 Wi-Fi 不在白名单，VPN 保持断开'**
  String get odStateUnmatched;

  /// No description provided for @odDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'按需连接已关闭，VPN 不再随网络切换'**
  String get odDisabledHint;

  /// No description provided for @odPillDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get odPillDisabled;

  /// No description provided for @odPillUnknown.
  ///
  /// In zh, this message translates to:
  /// **'无法判断'**
  String get odPillUnknown;

  /// No description provided for @odPillNoWifi.
  ///
  /// In zh, this message translates to:
  /// **'未连接 Wi-Fi'**
  String get odPillNoWifi;

  /// No description provided for @odPillWillStart.
  ///
  /// In zh, this message translates to:
  /// **'会启动 VPN'**
  String get odPillWillStart;

  /// No description provided for @odPillWillNotStart.
  ///
  /// In zh, this message translates to:
  /// **'不会启动 VPN'**
  String get odPillWillNotStart;

  /// No description provided for @odDecision.
  ///
  /// In zh, this message translates to:
  /// **'当前判定'**
  String get odDecision;

  /// No description provided for @odDecisionFooter.
  ///
  /// In zh, this message translates to:
  /// **'判定按当前网络实时计算：切换 Wi-Fi 后重新读取即可看到结果。SSID 区分大小写。'**
  String get odDecisionFooter;

  /// No description provided for @odCurrentNetwork.
  ///
  /// In zh, this message translates to:
  /// **'当前网络'**
  String get odCurrentNetwork;

  /// No description provided for @odWifiName.
  ///
  /// In zh, this message translates to:
  /// **'Wi-Fi 名称'**
  String get odWifiName;

  /// No description provided for @odReadAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get odReadAgain;

  /// No description provided for @odPermission.
  ///
  /// In zh, this message translates to:
  /// **'读取权限'**
  String get odPermission;

  /// No description provided for @odPermissionBody.
  ///
  /// In zh, this message translates to:
  /// **'Android 10 起读取 Wi-Fi 名称需要位置权限'**
  String get odPermissionBody;

  /// No description provided for @odNotGranted.
  ///
  /// In zh, this message translates to:
  /// **'未授权'**
  String get odNotGranted;

  /// No description provided for @odWifiUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'本机当前无法读取 Wi-Fi 名称：请在系统设置里授予本应用位置权限后重新读取。'**
  String get odWifiUnreadable;

  /// No description provided for @odSsidPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'SSID 只用于匹配白名单，不会被上传；手动添加的 SSID 在无法读取时仍然可用。'**
  String get odSsidPrivacy;

  /// No description provided for @odBatteryJoined.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get odBatteryJoined;

  /// No description provided for @odBatteryNotJoined.
  ///
  /// In zh, this message translates to:
  /// **'未加入'**
  String get odBatteryNotJoined;

  /// No description provided for @odBatteryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get odBatteryUnavailable;

  /// No description provided for @odPrerequisites.
  ///
  /// In zh, this message translates to:
  /// **'前置条件'**
  String get odPrerequisites;

  /// No description provided for @odIgnoreBattery.
  ///
  /// In zh, this message translates to:
  /// **'忽略电池优化'**
  String get odIgnoreBattery;

  /// No description provided for @odBatteryOk.
  ///
  /// In zh, this message translates to:
  /// **'系统不会在后台冻结 VPN 进程'**
  String get odBatteryOk;

  /// No description provided for @odBatteryAsk.
  ///
  /// In zh, this message translates to:
  /// **'未加入时后台 VPN 可能被系统冻结，点击申请'**
  String get odBatteryAsk;

  /// No description provided for @odBatteryNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'当前构建没有提供电池优化通道'**
  String get odBatteryNoChannel;

  /// No description provided for @odBatteryFooter.
  ///
  /// In zh, this message translates to:
  /// **'点击「未加入」会打开系统授权页；返回后会重新读取真实状态，取消则保持未加入。'**
  String get odBatteryFooter;

  /// No description provided for @odBatteryJoinedHint.
  ///
  /// In zh, this message translates to:
  /// **'已加入电池优化白名单'**
  String get odBatteryJoinedHint;

  /// No description provided for @odBatteryStillOff.
  ///
  /// In zh, this message translates to:
  /// **'仍未加入，VPN 可能被系统冻结'**
  String get odBatteryStillOff;

  /// No description provided for @odBatteryUnsupportedHint.
  ///
  /// In zh, this message translates to:
  /// **'当前构建不支持该授权'**
  String get odBatteryUnsupportedHint;

  /// No description provided for @odCapNoPermission.
  ///
  /// In zh, this message translates to:
  /// **'无法读取：需要位置权限'**
  String get odCapNoPermission;

  /// No description provided for @odCapCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前连接：{name}'**
  String odCapCurrent(Object name);

  /// No description provided for @customResourcesTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义资源'**
  String get customResourcesTitle;

  /// No description provided for @customResourcesNote.
  ///
  /// In zh, this message translates to:
  /// **'这些资源按名字被引用：改名字等于断开引用，改内容则在下一次加载配置时生效。它们不属于旧版 1.4.3 的界面，保留在此供调试使用。'**
  String get customResourcesNote;

  /// No description provided for @customResourcesSection.
  ///
  /// In zh, this message translates to:
  /// **'资源'**
  String get customResourcesSection;

  /// No description provided for @configDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get configDelete;

  /// No description provided for @configCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get configCancel;

  /// No description provided for @configNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get configNotSet;

  /// No description provided for @configItemCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 项'**
  String configItemCount(Object count);

  /// No description provided for @odEditSsidTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑 {ssid}'**
  String odEditSsidTooltip(Object ssid);

  /// No description provided for @odDeleteSsidTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除 {ssid}'**
  String odDeleteSsidTooltip(Object ssid);

  /// No description provided for @serverSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {name}，重启服务后生效'**
  String serverSwitched(Object name);

  /// No description provided for @serverSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {name}'**
  String serverSelected(Object name);

  /// No description provided for @serverAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {name}'**
  String serverAdded(Object name);

  /// No description provided for @serverSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {name}'**
  String serverSaved(Object name);

  /// No description provided for @serverDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除 {name}？'**
  String serverDeleteConfirm(Object name);

  /// No description provided for @serverDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'如果它正被使用，删除后会回落到第一个内置服务商。'**
  String get serverDeleteBody;

  /// No description provided for @serverDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {name}'**
  String serverDeleted(Object name);

  /// No description provided for @serverUpstreamTitle.
  ///
  /// In zh, this message translates to:
  /// **'上游服务器'**
  String get serverUpstreamTitle;

  /// No description provided for @serverAddCustom.
  ///
  /// In zh, this message translates to:
  /// **'添加自定义服务商'**
  String get serverAddCustom;

  /// No description provided for @serverCurrentUpstream.
  ///
  /// In zh, this message translates to:
  /// **'当前用于解析 DNS：({protocol}) {name}'**
  String serverCurrentUpstream(Object name, Object protocol);

  /// No description provided for @serverBuiltinProviders.
  ///
  /// In zh, this message translates to:
  /// **'内置 DNS 服务商'**
  String get serverBuiltinProviders;

  /// No description provided for @serverNoBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'暂无内置服务商'**
  String get serverNoBuiltin;

  /// No description provided for @serverCustomProviders.
  ///
  /// In zh, this message translates to:
  /// **'自定义 DNS 服务商'**
  String get serverCustomProviders;

  /// No description provided for @serverNoCustom.
  ///
  /// In zh, this message translates to:
  /// **'暂无自定义服务商'**
  String get serverNoCustom;

  /// No description provided for @serverNoCustomBody.
  ///
  /// In zh, this message translates to:
  /// **'点右上角加号添加 DoH / DoT / 明文 DNS 上游'**
  String get serverNoCustomBody;

  /// No description provided for @serverUpstreamFooter.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式只用一家上游；需要多路竞速请切到普通或极速模式。内置服务商由应用维护，只能切换；自定义项长按可编辑或删除。'**
  String get serverUpstreamFooter;

  /// No description provided for @serverEditName.
  ///
  /// In zh, this message translates to:
  /// **'编辑 {name}'**
  String serverEditName(Object name);

  /// No description provided for @serverDeleteName.
  ///
  /// In zh, this message translates to:
  /// **'删除 {name}'**
  String serverDeleteName(Object name);

  /// No description provided for @serverEditCustom.
  ///
  /// In zh, this message translates to:
  /// **'编辑自定义服务商'**
  String get serverEditCustom;

  /// No description provided for @serverSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get serverSave;

  /// No description provided for @serverName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get serverName;

  /// No description provided for @serverDohAddress.
  ///
  /// In zh, this message translates to:
  /// **'DoH 地址'**
  String get serverDohAddress;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @serverDohPrefix.
  ///
  /// In zh, this message translates to:
  /// **'必须以 https:// 开头'**
  String get serverDohPrefix;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'IPv4 / IPv6 均可；IPv6 可直接填 [::1]'**
  String get serverAddressHint;

  /// No description provided for @serverPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get serverPort;

  /// No description provided for @serverPortHint.
  ///
  /// In zh, this message translates to:
  /// **'DNS 通常 53，DoT 通常 853'**
  String get serverPortHint;

  /// No description provided for @serverUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不可用'**
  String get serverUnavailable;

  /// No description provided for @serverBatteryJoined.
  ///
  /// In zh, this message translates to:
  /// **'已加入电池优化白名单'**
  String get serverBatteryJoined;

  /// No description provided for @serverBatteryNotJoined.
  ///
  /// In zh, this message translates to:
  /// **'尚未加入电池优化白名单'**
  String get serverBatteryNotJoined;

  /// No description provided for @serverClearCache.
  ///
  /// In zh, this message translates to:
  /// **'清空缓存'**
  String get serverClearCache;

  /// No description provided for @serverClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get serverClear;

  /// No description provided for @serverClearCacheBody.
  ///
  /// In zh, this message translates to:
  /// **'将清空本机已缓存的解析结果，下一次查询会重新向上游请求。'**
  String get serverClearCacheBody;

  /// No description provided for @serverCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'缓存已清空'**
  String get serverCacheCleared;

  /// No description provided for @serverCacheClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空失败：请先启动解析服务再试'**
  String get serverCacheClearFailed;

  /// No description provided for @serverCacheOn.
  ///
  /// In zh, this message translates to:
  /// **'{preset} · 命中缓存的查询不再请求上游'**
  String serverCacheOn(Object preset);

  /// No description provided for @serverCacheOff.
  ///
  /// In zh, this message translates to:
  /// **'已关闭 · 每次解析都请求上游 DNS'**
  String get serverCacheOff;

  /// No description provided for @serverModeSettings.
  ///
  /// In zh, this message translates to:
  /// **'模式设置'**
  String get serverModeSettings;

  /// No description provided for @serverProxySettings.
  ///
  /// In zh, this message translates to:
  /// **'代理与解析设置'**
  String get serverProxySettings;

  /// No description provided for @serverCacheSettings.
  ///
  /// In zh, this message translates to:
  /// **'缓存设置'**
  String get serverCacheSettings;

  /// No description provided for @serverRuleControl.
  ///
  /// In zh, this message translates to:
  /// **'规则控制'**
  String get serverRuleControl;

  /// No description provided for @serverRuleControlOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启 · 命中规则按拦截策略返回'**
  String get serverRuleControlOn;

  /// No description provided for @serverRuleControlOff.
  ///
  /// In zh, this message translates to:
  /// **'已关闭 · 使用独立的过滤规则库'**
  String get serverRuleControlOff;

  /// No description provided for @serverListenPort.
  ///
  /// In zh, this message translates to:
  /// **'本地监听端口'**
  String get serverListenPort;

  /// No description provided for @serverListenPortBody.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务在本机监听的端口，默认 1053'**
  String get serverListenPortBody;

  /// No description provided for @serverRuleManagement.
  ///
  /// In zh, this message translates to:
  /// **'规则管理'**
  String get serverRuleManagement;

  /// No description provided for @serverBlocklist.
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get serverBlocklist;

  /// No description provided for @serverBlocklistBody.
  ///
  /// In zh, this message translates to:
  /// **'管理域名屏蔽规则，独立规则库'**
  String get serverBlocklistBody;

  /// No description provided for @serverAllowlist.
  ///
  /// In zh, this message translates to:
  /// **'白名单'**
  String get serverAllowlist;

  /// No description provided for @serverAllowlistBody.
  ///
  /// In zh, this message translates to:
  /// **'管理域名放行规则，独立规则库'**
  String get serverAllowlistBody;

  /// No description provided for @serverHosts.
  ///
  /// In zh, this message translates to:
  /// **'Hosts 覆写'**
  String get serverHosts;

  /// No description provided for @serverHostsBody.
  ///
  /// In zh, this message translates to:
  /// **'将指定域名解析到配置的 IP 或 CNAME'**
  String get serverHostsBody;

  /// No description provided for @serverRulesFooter.
  ///
  /// In zh, this message translates to:
  /// **'这三张表只影响服务器模式的独立规则库，与普通模式的规则互不覆盖。'**
  String get serverRulesFooter;

  /// No description provided for @serverDataReset.
  ///
  /// In zh, this message translates to:
  /// **'数据与重置'**
  String get serverDataReset;

  /// No description provided for @serverResetStats.
  ///
  /// In zh, this message translates to:
  /// **'重置运行统计'**
  String get serverResetStats;

  /// No description provided for @serverResetStatsBody.
  ///
  /// In zh, this message translates to:
  /// **'清空本次运行的统计数据'**
  String get serverResetStatsBody;

  /// No description provided for @serverBackground.
  ///
  /// In zh, this message translates to:
  /// **'后台稳定性'**
  String get serverBackground;

  /// No description provided for @serverBackgroundBody.
  ///
  /// In zh, this message translates to:
  /// **'系统会在后台冻结省电名单之外的应用；把它加入白名单，DNS 服务才能在息屏后继续应答局域网查询。'**
  String get serverBackgroundBody;

  /// No description provided for @serverRunMode.
  ///
  /// In zh, this message translates to:
  /// **'运行模式'**
  String get serverRunMode;

  /// No description provided for @serverWizard.
  ///
  /// In zh, this message translates to:
  /// **'使用向导'**
  String get serverWizard;

  /// No description provided for @serverWizardBody.
  ///
  /// In zh, this message translates to:
  /// **'查看服务器模式架构原理、局域网配置与就绪指引'**
  String get serverWizardBody;

  /// No description provided for @serverReselectMode.
  ///
  /// In zh, this message translates to:
  /// **'重新选择工作模式'**
  String get serverReselectMode;

  /// No description provided for @serverReselectModeBody.
  ///
  /// In zh, this message translates to:
  /// **'浏览所有工作模式详情并重新选择'**
  String get serverReselectModeBody;

  /// No description provided for @serverBatteryIgnored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略电池优化'**
  String get serverBatteryIgnored;

  /// No description provided for @serverBatteryIgnoredShort.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get serverBatteryIgnoredShort;

  /// No description provided for @serverBatteryKeepAlive.
  ///
  /// In zh, this message translates to:
  /// **'保持 DNS 服务在后台稳定运行'**
  String get serverBatteryKeepAlive;

  /// No description provided for @serverIgnoreBattery.
  ///
  /// In zh, this message translates to:
  /// **'忽略电池优化'**
  String get serverIgnoreBattery;

  /// No description provided for @serverCachePresetConservative.
  ///
  /// In zh, this message translates to:
  /// **'保守'**
  String get serverCachePresetConservative;

  /// No description provided for @serverCachePresetHighHit.
  ///
  /// In zh, this message translates to:
  /// **'高命中'**
  String get serverCachePresetHighHit;

  /// No description provided for @serverCachePresetStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get serverCachePresetStandard;

  /// No description provided for @serverNavOverview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get serverNavOverview;

  /// No description provided for @serverPortInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入数字'**
  String get serverPortInvalid;

  /// No description provided for @serverPortRange.
  ///
  /// In zh, this message translates to:
  /// **'范围 {min}–{max}'**
  String serverPortRange(Object max, Object min);

  /// No description provided for @serverPortChanged.
  ///
  /// In zh, this message translates to:
  /// **'端口已改为 {port}，重启服务后生效'**
  String serverPortChanged(Object port);

  /// No description provided for @serverResetConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认重置'**
  String get serverResetConfirm;

  /// No description provided for @serverResetStatsConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将清空本次运行的全部统计数据，确认继续吗？'**
  String get serverResetStatsConfirmBody;

  /// No description provided for @serverStatsReset.
  ///
  /// In zh, this message translates to:
  /// **'运行统计已重置'**
  String get serverStatsReset;

  /// No description provided for @serverOverviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 服务器模式'**
  String get serverOverviewTitle;

  /// No description provided for @serverSwitchMode.
  ///
  /// In zh, this message translates to:
  /// **'切换工作模式'**
  String get serverSwitchMode;

  /// No description provided for @serverChangePort.
  ///
  /// In zh, this message translates to:
  /// **'修改监听端口'**
  String get serverChangePort;

  /// No description provided for @serverCurrentUpstreamCard.
  ///
  /// In zh, this message translates to:
  /// **'当前上游'**
  String get serverCurrentUpstreamCard;

  /// No description provided for @serverLanAccess.
  ///
  /// In zh, this message translates to:
  /// **'局域网接入'**
  String get serverLanAccess;

  /// No description provided for @serverLanBody.
  ///
  /// In zh, this message translates to:
  /// **'把同网段设备的 DNS 指向上面这个地址即可；端口只在启动时绑定，改动后需要重启服务。'**
  String get serverLanBody;

  /// No description provided for @serverNoNetwork.
  ///
  /// In zh, this message translates to:
  /// **'未连接网络'**
  String get serverNoNetwork;

  /// No description provided for @serverLanConnectHint.
  ///
  /// In zh, this message translates to:
  /// **'连上 Wi-Fi 或以太网后这里会显示可用地址'**
  String get serverLanConnectHint;

  /// No description provided for @serverLanPointHint.
  ///
  /// In zh, this message translates to:
  /// **'将局域网其他设备的 DNS 指向此地址'**
  String get serverLanPointHint;

  /// No description provided for @serverCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {text}'**
  String serverCopied(Object text);

  /// No description provided for @serverServiceStatus.
  ///
  /// In zh, this message translates to:
  /// **'服务状态'**
  String get serverServiceStatus;

  /// No description provided for @serverTotalQueries.
  ///
  /// In zh, this message translates to:
  /// **'总查询量'**
  String get serverTotalQueries;

  /// No description provided for @serverCacheHits.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get serverCacheHits;

  /// No description provided for @serverBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已拦截'**
  String get serverBlocked;

  /// No description provided for @serverAverageLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均时延'**
  String get serverAverageLatency;

  /// No description provided for @serverUptime.
  ///
  /// In zh, this message translates to:
  /// **'运行时长'**
  String get serverUptime;

  /// No description provided for @serverResetStatsBodyShort.
  ///
  /// In zh, this message translates to:
  /// **'清空本次运行的全部计数，不清规则与缓存'**
  String get serverResetStatsBodyShort;

  /// No description provided for @serverModeSettingsBody.
  ///
  /// In zh, this message translates to:
  /// **'缓存、规则、后台稳定性与运行模式'**
  String get serverModeSettingsBody;

  /// No description provided for @serverModeNote.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式不建立 VPN 隧道：它只在本机监听 DNS 端口，因此可以与其它 VPN 共存，也不占用系统的 VPN 槽位；本机应用的查询不会自动经过该服务。'**
  String get serverModeNote;

  /// No description provided for @serverBusyStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中'**
  String get serverBusyStarting;

  /// No description provided for @serverBusyStopping.
  ///
  /// In zh, this message translates to:
  /// **'停止中'**
  String get serverBusyStopping;

  /// No description provided for @serverRunning.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get serverRunning;

  /// No description provided for @serverStopped.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get serverStopped;

  /// No description provided for @serverListening.
  ///
  /// In zh, this message translates to:
  /// **'监听 0.0.0.0:{port}'**
  String serverListening(Object port);

  /// No description provided for @serverStatusStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式已停止'**
  String get serverStatusStopped;

  /// No description provided for @serverStatusStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在启动服务...'**
  String get serverStatusStarting;

  /// No description provided for @serverStatusRunning.
  ///
  /// In zh, this message translates to:
  /// **'服务器模式运行中'**
  String get serverStatusRunning;

  /// No description provided for @serverStatusStopping.
  ///
  /// In zh, this message translates to:
  /// **'正在停止服务...'**
  String get serverStatusStopping;

  /// No description provided for @serverStatusErrorText.
  ///
  /// In zh, this message translates to:
  /// **'服务异常：端口可能已被占用'**
  String get serverStatusErrorText;

  /// No description provided for @troubleshootTitle.
  ///
  /// In zh, this message translates to:
  /// **'故障排查'**
  String get troubleshootTitle;

  /// No description provided for @troubleshootRuntimeLogs.
  ///
  /// In zh, this message translates to:
  /// **'运行日志'**
  String get troubleshootRuntimeLogs;

  /// No description provided for @troubleshootRecordLogs.
  ///
  /// In zh, this message translates to:
  /// **'记录运行日志'**
  String get troubleshootRecordLogs;

  /// No description provided for @troubleshootExportLogs.
  ///
  /// In zh, this message translates to:
  /// **'导出运行日志'**
  String get troubleshootExportLogs;

  /// No description provided for @troubleshootClearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空运行日志'**
  String get troubleshootClearLogs;

  /// No description provided for @troubleshootClearLogsBody.
  ///
  /// In zh, this message translates to:
  /// **'删除本地已记录的全部运行日志文件'**
  String get troubleshootClearLogsBody;

  /// No description provided for @troubleshootRecordNote.
  ///
  /// In zh, this message translates to:
  /// **'默认关闭。开启后会在通知栏显示状态，关闭软件或手动关闭后即停止记录；日志只保存在本机，不会自动上传。'**
  String get troubleshootRecordNote;

  /// No description provided for @troubleshootLocalDb.
  ///
  /// In zh, this message translates to:
  /// **'本地数据库'**
  String get troubleshootLocalDb;

  /// No description provided for @troubleshootWriteStatus.
  ///
  /// In zh, this message translates to:
  /// **'日志写入状态'**
  String get troubleshootWriteStatus;

  /// No description provided for @troubleshootWriteStatusNote.
  ///
  /// In zh, this message translates to:
  /// **'日志、竞速记录与流量统计由后台直接写入本地数据库。出现丢弃或打开失败时，多为数据库被长时间占用，点击可重新读取；反复出现请导出运行日志反馈。'**
  String get troubleshootWriteStatusNote;

  /// No description provided for @troubleshootCrashLogs.
  ///
  /// In zh, this message translates to:
  /// **'崩溃日志'**
  String get troubleshootCrashLogs;

  /// No description provided for @troubleshootExportCrashes.
  ///
  /// In zh, this message translates to:
  /// **'导出崩溃日志'**
  String get troubleshootExportCrashes;

  /// No description provided for @troubleshootClearCrashes.
  ///
  /// In zh, this message translates to:
  /// **'清空崩溃日志'**
  String get troubleshootClearCrashes;

  /// No description provided for @troubleshootClearCrashesBody.
  ///
  /// In zh, this message translates to:
  /// **'删除本地所有已记录的崩溃文件'**
  String get troubleshootClearCrashesBody;

  /// No description provided for @troubleshootCrashNote.
  ///
  /// In zh, this message translates to:
  /// **'发生未捕获异常时自动保存诊断信息与关键日志，仅保存在设备本地，导出后可反馈给开发者。'**
  String get troubleshootCrashNote;

  /// No description provided for @troubleshootCaptureWarning.
  ///
  /// In zh, this message translates to:
  /// **'抓取运行日志会持续读写少量文件，可能导致功耗升高、存储占用增加或产生其他未知影响，不需要时请及时关闭。导出的文件可发送给开发者，配合问题现象与发生时间能更快定位原因。'**
  String get troubleshootCaptureWarning;

  /// No description provided for @troubleshootReadingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在读取抓取状态…'**
  String get troubleshootReadingStatus;

  /// No description provided for @troubleshootRecording.
  ///
  /// In zh, this message translates to:
  /// **'正在记录，已占用 {size}，再次点击可关闭'**
  String troubleshootRecording(Object size);

  /// No description provided for @troubleshootStoppedWithLogs.
  ///
  /// In zh, this message translates to:
  /// **'已关闭，本地已有 {size} 日志可导出'**
  String troubleshootStoppedWithLogs(Object size);

  /// No description provided for @troubleshootStoppedNoLogs.
  ///
  /// In zh, this message translates to:
  /// **'已关闭，开启后才会记录运行日志'**
  String get troubleshootStoppedNoLogs;

  /// No description provided for @troubleshootReadingLogs.
  ///
  /// In zh, this message translates to:
  /// **'正在读取本地日志…'**
  String get troubleshootReadingLogs;

  /// No description provided for @troubleshootNoLogs.
  ///
  /// In zh, this message translates to:
  /// **'当前设备没有运行日志'**
  String get troubleshootNoLogs;

  /// No description provided for @troubleshootLogCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个文件，{size}，点击导出文件'**
  String troubleshootLogCount(Object count, Object size);

  /// No description provided for @troubleshootReadingHealth.
  ///
  /// In zh, this message translates to:
  /// **'正在读取写入状态…'**
  String get troubleshootReadingHealth;

  /// No description provided for @troubleshootHealthy.
  ///
  /// In zh, this message translates to:
  /// **'正常，没有日志被丢弃'**
  String get troubleshootHealthy;

  /// No description provided for @troubleshootHealthyDetail.
  ///
  /// In zh, this message translates to:
  /// **'正常，没有日志被丢弃（{mode} · {detail}）'**
  String troubleshootHealthyDetail(Object detail, Object mode);

  /// No description provided for @troubleshootDropped.
  ///
  /// In zh, this message translates to:
  /// **'已丢弃 {dropped} 条日志{split}，打开失败 {failed} 次{reason}'**
  String troubleshootDropped(
    Object dropped,
    Object failed,
    Object reason,
    Object split,
  );

  /// No description provided for @troubleshootOverflow.
  ///
  /// In zh, this message translates to:
  /// **'队列溢出'**
  String get troubleshootOverflow;

  /// No description provided for @troubleshootTableMissing.
  ///
  /// In zh, this message translates to:
  /// **'表缺失'**
  String get troubleshootTableMissing;

  /// No description provided for @troubleshootNoDatabase.
  ///
  /// In zh, this message translates to:
  /// **'无数据库'**
  String get troubleshootNoDatabase;

  /// No description provided for @troubleshootClosed.
  ///
  /// In zh, this message translates to:
  /// **'停止时未写完'**
  String get troubleshootClosed;

  /// No description provided for @troubleshootReadingCrashes.
  ///
  /// In zh, this message translates to:
  /// **'正在读取本机崩溃日志…'**
  String get troubleshootReadingCrashes;

  /// No description provided for @troubleshootNoCrashes.
  ///
  /// In zh, this message translates to:
  /// **'当前设备没有崩溃日志'**
  String get troubleshootNoCrashes;

  /// No description provided for @troubleshootCrashCount.
  ///
  /// In zh, this message translates to:
  /// **'已记录 {count} 份崩溃日志，点击导出文件'**
  String troubleshootCrashCount(Object count);

  /// No description provided for @troubleshootStoppedToast.
  ///
  /// In zh, this message translates to:
  /// **'已停止记录运行日志'**
  String get troubleshootStoppedToast;

  /// No description provided for @troubleshootStartTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启运行日志抓取'**
  String get troubleshootStartTitle;

  /// No description provided for @troubleshootCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get troubleshootCancel;

  /// No description provided for @troubleshootConfirmStart.
  ///
  /// In zh, this message translates to:
  /// **'确定开启'**
  String get troubleshootConfirmStart;

  /// No description provided for @troubleshootStartBody.
  ///
  /// In zh, this message translates to:
  /// **'该功能主要用于协助开发者排查问题，开启后会开始记录软件的运行日志，并持续写入本机存储。\n\n抓取期间可能导致功耗升高、存储占用增加，或产生其他未知影响。如非排查问题所需，建议用完即关。\n\n日志只保存在本机，关闭后停止记录；导出后你可以自行发送给开发者。'**
  String get troubleshootStartBody;

  /// No description provided for @troubleshootStartedToast.
  ///
  /// In zh, this message translates to:
  /// **'已开始记录运行日志'**
  String get troubleshootStartedToast;

  /// No description provided for @troubleshootStartFailedToast.
  ///
  /// In zh, this message translates to:
  /// **'无法开启日志抓取，请稍后重试'**
  String get troubleshootStartFailedToast;

  /// No description provided for @troubleshootNoExportableLogs.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的运行日志'**
  String get troubleshootNoExportableLogs;

  /// No description provided for @troubleshootExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：本机没有可写的导出目录'**
  String get troubleshootExportFailed;

  /// No description provided for @troubleshootExported.
  ///
  /// In zh, this message translates to:
  /// **'已导出到 {path}'**
  String troubleshootExported(Object path);

  /// No description provided for @troubleshootConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get troubleshootConfirm;

  /// No description provided for @troubleshootClearLogsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认清空所有已保存的运行日志吗？该操作不可恢复。'**
  String get troubleshootClearLogsConfirm;

  /// No description provided for @troubleshootClearedLogs.
  ///
  /// In zh, this message translates to:
  /// **'已清空 {count} 个日志文件'**
  String troubleshootClearedLogs(Object count);

  /// No description provided for @troubleshootNoClearableLogs.
  ///
  /// In zh, this message translates to:
  /// **'没有可清空的运行日志'**
  String get troubleshootNoClearableLogs;

  /// No description provided for @troubleshootNoExportableCrashes.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的崩溃日志'**
  String get troubleshootNoExportableCrashes;

  /// No description provided for @troubleshootClearCrashesConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认清空所有已保存的崩溃日志吗？'**
  String get troubleshootClearCrashesConfirm;

  /// No description provided for @troubleshootClearedCrashes.
  ///
  /// In zh, this message translates to:
  /// **'已清空 {count} 份崩溃日志'**
  String troubleshootClearedCrashes(Object count);

  /// No description provided for @troubleshootNoClearableCrashes.
  ///
  /// In zh, this message translates to:
  /// **'没有可清空的崩溃日志'**
  String get troubleshootNoClearableCrashes;

  /// No description provided for @bypassAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加绕过域名'**
  String get bypassAddTitle;

  /// No description provided for @bypassAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get bypassAdd;

  /// No description provided for @bypassSuffix.
  ///
  /// In zh, this message translates to:
  /// **'域名后缀'**
  String get bypassSuffix;

  /// No description provided for @bypassSuffixBody.
  ///
  /// In zh, this message translates to:
  /// **'匹配该后缀及其子域名；不参与 HTTPS 解密'**
  String get bypassSuffixBody;

  /// No description provided for @mirrorGlobal.
  ///
  /// In zh, this message translates to:
  /// **'全局镜像'**
  String get mirrorGlobal;

  /// No description provided for @mirrorDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认使用镜像下载'**
  String get mirrorDefault;

  /// No description provided for @mirrorNeedTemplate.
  ///
  /// In zh, this message translates to:
  /// **'先添加一个模板后才能开启'**
  String get mirrorNeedTemplate;

  /// No description provided for @mirrorTemplateNote.
  ///
  /// In zh, this message translates to:
  /// **'订阅下载与软件更新都经由所选模板'**
  String get mirrorTemplateNote;

  /// No description provided for @mirrorTemplate.
  ///
  /// In zh, this message translates to:
  /// **'使用的模板'**
  String get mirrorTemplate;

  /// No description provided for @mirrorNote.
  ///
  /// In zh, this message translates to:
  /// **'开启后，未单独设置镜像的订阅、检查更新与下载安装包都会先请求镜像，镜像失败时自动改用原始地址。单独设置过镜像的订阅仍按自己的设置。'**
  String get mirrorNote;

  /// No description provided for @hiddenFeaturesTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏功能'**
  String get hiddenFeaturesTitle;

  /// No description provided for @hiddenFeaturesReset.
  ///
  /// In zh, this message translates to:
  /// **'恢复全部显示'**
  String get hiddenFeaturesReset;

  /// No description provided for @hiddenFeaturesNote.
  ///
  /// In zh, this message translates to:
  /// **'自定义在功能中心显示的功能卡片。关闭开关将从功能中心隐藏该卡片，默认全部显示。隐藏仅调整界面展示，不会影响功能的后台运行与规则生效。设置会保存到本机，重启后仍然有效。'**
  String get hiddenFeaturesNote;

  /// No description provided for @hiddenFeaturesFooter.
  ///
  /// In zh, this message translates to:
  /// **'「隐藏功能」卡片固定常驻，确保随时可以在这里恢复。'**
  String get hiddenFeaturesFooter;

  /// No description provided for @cacheSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'缓存设置'**
  String get cacheSettingsTitle;

  /// No description provided for @cacheSection.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get cacheSection;

  /// No description provided for @cacheLocalDns.
  ///
  /// In zh, this message translates to:
  /// **'本地 DNS 缓存'**
  String get cacheLocalDns;

  /// No description provided for @cacheOffNote.
  ///
  /// In zh, this message translates to:
  /// **'关闭后每次解析都会请求上游 DNS'**
  String get cacheOffNote;

  /// No description provided for @cachePresetSection.
  ///
  /// In zh, this message translates to:
  /// **'缓存档位'**
  String get cachePresetSection;

  /// No description provided for @cachePresetNote.
  ///
  /// In zh, this message translates to:
  /// **'建议使用「标准」。档位会自动设置最长 TTL、最短 TTL 和解析失败兜底时间，不再需要手动填写秒数。'**
  String get cachePresetNote;

  /// No description provided for @recognitionSponsorTitle.
  ///
  /// In zh, this message translates to:
  /// **'赞助者名单'**
  String get recognitionSponsorTitle;

  /// No description provided for @recognitionSponsorIntro.
  ///
  /// In zh, this message translates to:
  /// **'感谢每一位支持谛听项目的朋友！名单默认按赞助时间由早到晚排列，可通过右上角按钮切换为由晚到早；与赞助金额无关，每一份支持都同样珍贵。'**
  String get recognitionSponsorIntro;

  /// No description provided for @recognitionSponsorSection.
  ///
  /// In zh, this message translates to:
  /// **'赞助者'**
  String get recognitionSponsorSection;

  /// No description provided for @recognitionBuilderTitle.
  ///
  /// In zh, this message translates to:
  /// **'共建者名单'**
  String get recognitionBuilderTitle;

  /// No description provided for @recognitionBuilderIntro.
  ///
  /// In zh, this message translates to:
  /// **'感谢每一位为谛听提出建议、帮助测试的共建者！名单按用户名称的字母顺序排列，中文名称按拼音排序。'**
  String get recognitionBuilderIntro;

  /// No description provided for @recognitionBuilderSection.
  ///
  /// In zh, this message translates to:
  /// **'共建者'**
  String get recognitionBuilderSection;

  /// No description provided for @providerVisibilityTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务显示'**
  String get providerVisibilityTitle;

  /// No description provided for @providerVisibilityNote.
  ///
  /// In zh, this message translates to:
  /// **'关闭竞速模式时，首页解析服务下拉框仅显示这里选中的服务。当前正在使用的服务会始终保留。'**
  String get providerVisibilityNote;

  /// No description provided for @providerVisibilityProtocol.
  ///
  /// In zh, this message translates to:
  /// **'{protocol} 服务'**
  String providerVisibilityProtocol(Object protocol);

  /// No description provided for @providerVisibilityAll.
  ///
  /// In zh, this message translates to:
  /// **'全部 {protocol} 服务'**
  String providerVisibilityAll(Object protocol);

  /// No description provided for @providerVisibilityNone.
  ///
  /// In zh, this message translates to:
  /// **'不显示该类型的服务'**
  String get providerVisibilityNone;

  /// No description provided for @providerVisibilityAllOn.
  ///
  /// In zh, this message translates to:
  /// **'显示该类型的全部服务'**
  String get providerVisibilityAllOn;

  /// No description provided for @providerVisibilityCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 个服务'**
  String providerVisibilityCount(Object count);

  /// No description provided for @markdownCopyCode.
  ///
  /// In zh, this message translates to:
  /// **'复制代码'**
  String get markdownCopyCode;

  /// No description provided for @markdownCodeCopied.
  ///
  /// In zh, this message translates to:
  /// **'代码已复制到剪贴板'**
  String get markdownCodeCopied;

  /// No description provided for @recognitionUpdated.
  ///
  /// In zh, this message translates to:
  /// **'名单已更新'**
  String get recognitionUpdated;

  /// No description provided for @recognitionRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新名单'**
  String get recognitionRefresh;

  /// No description provided for @recognitionSortAsc.
  ///
  /// In zh, this message translates to:
  /// **'切换为由早到晚'**
  String get recognitionSortAsc;

  /// No description provided for @recognitionSortDesc.
  ///
  /// In zh, this message translates to:
  /// **'切换为由晚到早'**
  String get recognitionSortDesc;

  /// No description provided for @recognitionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有名单'**
  String get recognitionEmpty;

  /// No description provided for @recognitionLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'名单加载失败'**
  String get recognitionLoadFailed;

  /// No description provided for @recognitionEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'名单由云端下发，点这里拉取一次。'**
  String get recognitionEmptyBody;

  /// No description provided for @recognitionLoad.
  ///
  /// In zh, this message translates to:
  /// **'加载名单'**
  String get recognitionLoad;

  /// No description provided for @recognitionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get recognitionRetry;

  /// No description provided for @recognitionNoMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂时还没有成员'**
  String get recognitionNoMembers;

  /// No description provided for @recognitionNoMembersBody.
  ///
  /// In zh, this message translates to:
  /// **'名单会随云端配置更新，稍后再来看看。'**
  String get recognitionNoMembersBody;

  /// No description provided for @recognitionRefreshShort.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get recognitionRefreshShort;

  /// No description provided for @recognitionCached.
  ///
  /// In zh, this message translates to:
  /// **'正在显示本地缓存的名单'**
  String get recognitionCached;

  /// No description provided for @recognitionLastUpdate.
  ///
  /// In zh, this message translates to:
  /// **'上次更新：{time}'**
  String recognitionLastUpdate(Object time);

  /// No description provided for @recognitionCloudNote.
  ///
  /// In zh, this message translates to:
  /// **'名单由云端下发，进入页面时自动检查更新'**
  String get recognitionCloudNote;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
