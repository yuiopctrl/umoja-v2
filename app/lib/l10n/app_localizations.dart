import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('sw'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In sw, this message translates to:
  /// **'Umoja'**
  String get appTitle;

  /// No description provided for @continueButton.
  ///
  /// In sw, this message translates to:
  /// **'Endelea'**
  String get continueButton;

  /// No description provided for @cancelButton.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi'**
  String get cancelButton;

  /// No description provided for @closeButton.
  ///
  /// In sw, this message translates to:
  /// **'Funga'**
  String get closeButton;

  /// No description provided for @saveButton.
  ///
  /// In sw, this message translates to:
  /// **'Hifadhi'**
  String get saveButton;

  /// No description provided for @editAction.
  ///
  /// In sw, this message translates to:
  /// **'Hariri'**
  String get editAction;

  /// No description provided for @signOutButtonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Toka'**
  String get signOutButtonLabel;

  /// No description provided for @languageSelectorLabel.
  ///
  /// In sw, this message translates to:
  /// **'Lugha'**
  String get languageSelectorLabel;

  /// No description provided for @languageSwahili.
  ///
  /// In sw, this message translates to:
  /// **'Kiswahili'**
  String get languageSwahili;

  /// No description provided for @languageEnglish.
  ///
  /// In sw, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In sw, this message translates to:
  /// **'Karibu Umoja'**
  String get authWelcomeTitle;

  /// No description provided for @authPhoneSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza namba yako ya simu kuendelea.'**
  String get authPhoneSubtitle;

  /// No description provided for @authPhoneLabel.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya simu'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In sw, this message translates to:
  /// **'0712345678'**
  String get authPhoneHint;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza namba yako ya simu na PIN.'**
  String get authLoginSubtitle;

  /// No description provided for @authPinLabel.
  ///
  /// In sw, this message translates to:
  /// **'PIN'**
  String get authPinLabel;

  /// No description provided for @loginButton.
  ///
  /// In sw, this message translates to:
  /// **'Ingia'**
  String get loginButton;

  /// No description provided for @authFirstTimeLink.
  ///
  /// In sw, this message translates to:
  /// **'Mara ya kwanza? Thibitisha namba kwa OTP'**
  String get authFirstTimeLink;

  /// No description provided for @otpTitle.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Namba'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Weka msimbo uliotumwa kwa {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @otpCodeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya uthibitisho'**
  String get otpCodeLabel;

  /// No description provided for @otpVerifyButton.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha'**
  String get otpVerifyButton;

  /// No description provided for @otpChangeNumber.
  ///
  /// In sw, this message translates to:
  /// **'Badilisha Namba'**
  String get otpChangeNumber;

  /// No description provided for @otpResend.
  ///
  /// In sw, this message translates to:
  /// **'Tuma Tena'**
  String get otpResend;

  /// No description provided for @otpResendCountdown.
  ///
  /// In sw, this message translates to:
  /// **'Baada ya {seconds}s'**
  String otpResendCountdown(int seconds);

  /// No description provided for @pinSetupTitle.
  ///
  /// In sw, this message translates to:
  /// **'Tengeneza PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'PIN hii itatumika kuingia Umoja siku zijazo.'**
  String get pinSetupSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Weka PIN yako tena kuthibitisha.'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In sw, this message translates to:
  /// **'PIN hazifanani. Jaribu tena.'**
  String get pinMismatch;

  /// No description provided for @pinSetupSaveError.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuhifadhi PIN. Jaribu tena.'**
  String get pinSetupSaveError;

  /// No description provided for @pinForgot.
  ///
  /// In sw, this message translates to:
  /// **'Umesahau PIN?'**
  String get pinForgot;

  /// No description provided for @pinRecoveryVerifyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Namba Yako'**
  String get pinRecoveryVerifyTitle;

  /// No description provided for @pinRecoveryVerifySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Weka msimbo uliotumwa kuthibitisha namba yako.'**
  String get pinRecoveryVerifySubtitle;

  /// No description provided for @pinRecoveryVerifySubtitleWithPhone.
  ///
  /// In sw, this message translates to:
  /// **'Weka msimbo uliotumwa kwa {phone}'**
  String pinRecoveryVerifySubtitleWithPhone(String phone);

  /// No description provided for @profileOnboardingTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kamilisha Wasifu Wako'**
  String get profileOnboardingTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina kamili'**
  String get fullNameLabel;

  /// No description provided for @fullNameRequiredError.
  ///
  /// In sw, this message translates to:
  /// **'Weka jina lako kamili.'**
  String get fullNameRequiredError;

  /// No description provided for @phoneReadOnlyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Simu'**
  String get phoneReadOnlyLabel;

  /// No description provided for @profileSaveError.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuhifadhi wasifu wako. Jaribu tena.'**
  String get profileSaveError;

  /// No description provided for @groupOnboardingTitle.
  ///
  /// In sw, this message translates to:
  /// **'Tengeneza Kikundi Chako'**
  String get groupOnboardingTitle;

  /// No description provided for @groupOnboardingSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Huna kikundi kinachofanya kazi kwa sasa. Tengeneza kimoja kuendelea.'**
  String get groupOnboardingSubtitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la kikundi'**
  String get groupNameLabel;

  /// No description provided for @groupDescriptionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (si lazima)'**
  String get groupDescriptionLabel;

  /// No description provided for @createGroupButton.
  ///
  /// In sw, this message translates to:
  /// **'Tengeneza Kikundi'**
  String get createGroupButton;

  /// No description provided for @groupNameRequiredError.
  ///
  /// In sw, this message translates to:
  /// **'Jina la kikundi linahitajika.'**
  String get groupNameRequiredError;

  /// No description provided for @groupSaveError.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kutengeneza kikundi. Jaribu tena.'**
  String get groupSaveError;

  /// No description provided for @homeTitle.
  ///
  /// In sw, this message translates to:
  /// **'Nyumbani'**
  String get homeTitle;

  /// No description provided for @roleAdmin.
  ///
  /// In sw, this message translates to:
  /// **'Msimamizi'**
  String get roleAdmin;

  /// No description provided for @roleTreasurer.
  ///
  /// In sw, this message translates to:
  /// **'Mweka Hazina'**
  String get roleTreasurer;

  /// No description provided for @roleSecretary.
  ///
  /// In sw, this message translates to:
  /// **'Katibu'**
  String get roleSecretary;

  /// No description provided for @roleChairperson.
  ///
  /// In sw, this message translates to:
  /// **'Mwenyekiti'**
  String get roleChairperson;

  /// No description provided for @roleMember.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama'**
  String get roleMember;

  /// No description provided for @statusActive.
  ///
  /// In sw, this message translates to:
  /// **'Hai'**
  String get statusActive;

  /// No description provided for @statusSuspended.
  ///
  /// In sw, this message translates to:
  /// **'Amesitishwa'**
  String get statusSuspended;

  /// No description provided for @statusExited.
  ///
  /// In sw, this message translates to:
  /// **'Ametoka'**
  String get statusExited;

  /// No description provided for @retryButton.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu Tena'**
  String get retryButton;

  /// No description provided for @accountDisabledTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ufikiaji wa akaunti umezimwa'**
  String get accountDisabledTitle;

  /// No description provided for @accountDisabledMessage.
  ///
  /// In sw, this message translates to:
  /// **'Ufikiaji wa akaunti yako umezimwa. Wasiliana na msimamizi wa kikundi kama unadhani hii ni kosa.'**
  String get accountDisabledMessage;

  /// No description provided for @contextErrorTitle.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kupakia akaunti'**
  String get contextErrorTitle;

  /// No description provided for @contextErrorMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hatukuweza kupakia akaunti yako. Angalia mtandao wako kisha ujaribu tena.'**
  String get contextErrorMessage;

  /// No description provided for @groupClosedTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kikundi kimefungwa'**
  String get groupClosedTitle;

  /// No description provided for @groupClosedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kikundi hiki kimefungwa na hakifanyi kazi tena.'**
  String get groupClosedMessage;

  /// No description provided for @groupSuspendedTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ufikiaji wa kikundi umesitishwa'**
  String get groupSuspendedTitle;

  /// No description provided for @groupSuspendedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kikundi hiki kimesitishwa kwa sasa. Wasiliana na msimamizi wa kikundi kwa maelezo zaidi.'**
  String get groupSuspendedMessage;

  /// No description provided for @membershipRestrictedTitle.
  ///
  /// In sw, this message translates to:
  /// **'Uanachama umezuiwa'**
  String get membershipRestrictedTitle;

  /// No description provided for @membershipRestrictedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Uanachama wako kwenye kikundi hiki kwa sasa umesitishwa, kwa hiyo hakipatikani. Bado unaweza kutengeneza kikundi kipya.'**
  String get membershipRestrictedMessage;

  /// No description provided for @createNewGroupAction.
  ///
  /// In sw, this message translates to:
  /// **'Tengeneza Kikundi Kipya'**
  String get createNewGroupAction;

  /// No description provided for @selectGroupTitle.
  ///
  /// In sw, this message translates to:
  /// **'Chagua Kikundi'**
  String get selectGroupTitle;

  /// No description provided for @noRolesShort.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna majukumu'**
  String get noRolesShort;

  /// No description provided for @homeGreetingPlain.
  ///
  /// In sw, this message translates to:
  /// **'Habari'**
  String get homeGreetingPlain;

  /// No description provided for @homeGreetingNamed.
  ///
  /// In sw, this message translates to:
  /// **'Habari, {name}'**
  String homeGreetingNamed(String name);

  /// No description provided for @homeMembersShortcutSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Angalia na simamia wanachama wa kikundi'**
  String get homeMembersShortcutSubtitle;

  /// No description provided for @rolesNone.
  ///
  /// In sw, this message translates to:
  /// **'Majukumu: hakuna'**
  String get rolesNone;

  /// No description provided for @rolesList.
  ///
  /// In sw, this message translates to:
  /// **'Majukumu: {roles}'**
  String rolesList(String roles);

  /// No description provided for @membersTitle.
  ///
  /// In sw, this message translates to:
  /// **'Wanachama'**
  String get membersTitle;

  /// No description provided for @membersSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get membersSearchHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In sw, this message translates to:
  /// **'Futa utafutaji'**
  String get clearSearchTooltip;

  /// No description provided for @filterAll.
  ///
  /// In sw, this message translates to:
  /// **'Wote'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In sw, this message translates to:
  /// **'Hai'**
  String get filterActive;

  /// No description provided for @filterSuspended.
  ///
  /// In sw, this message translates to:
  /// **'Waliositishwa'**
  String get filterSuspended;

  /// No description provided for @filterExited.
  ///
  /// In sw, this message translates to:
  /// **'Waliotoka'**
  String get filterExited;

  /// No description provided for @addMemberAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Mwanachama'**
  String get addMemberAction;

  /// No description provided for @membersEmptyFilteredTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna mwanachama aliyepatikana'**
  String get membersEmptyFilteredTitle;

  /// No description provided for @membersEmptyFilteredMessage.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu kubadilisha maneno ya utafutaji au kichujio.'**
  String get membersEmptyFilteredMessage;

  /// No description provided for @membersEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Jaza Orodha ya Wanachama'**
  String get membersEmptyTitle;

  /// No description provided for @membersEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza mwanachama wa kwanza wa kikundi.'**
  String get membersEmptyMessage;

  /// No description provided for @loadMoreAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesha Zaidi'**
  String get loadMoreAction;

  /// No description provided for @paginationPrevious.
  ///
  /// In sw, this message translates to:
  /// **'Iliyotangulia'**
  String get paginationPrevious;

  /// No description provided for @paginationNext.
  ///
  /// In sw, this message translates to:
  /// **'Ifuatayo'**
  String get paginationNext;

  /// No description provided for @paginationPageIndicator.
  ///
  /// In sw, this message translates to:
  /// **'Ukurasa {page} / {total}'**
  String paginationPageIndicator(int page, int total);

  /// No description provided for @memberDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama'**
  String get memberDetailTitle;

  /// No description provided for @sectionIdentity.
  ///
  /// In sw, this message translates to:
  /// **'Taarifa za Mwanachama'**
  String get sectionIdentity;

  /// No description provided for @sectionMembership.
  ///
  /// In sw, this message translates to:
  /// **'Uanachama'**
  String get sectionMembership;

  /// No description provided for @sectionRoles.
  ///
  /// In sw, this message translates to:
  /// **'Majukumu'**
  String get sectionRoles;

  /// No description provided for @sectionActions.
  ///
  /// In sw, this message translates to:
  /// **'Vitendo'**
  String get sectionActions;

  /// No description provided for @manageRolesAction.
  ///
  /// In sw, this message translates to:
  /// **'Simamia Majukumu'**
  String get manageRolesAction;

  /// No description provided for @memberNumberLabel.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya mwanachama'**
  String get memberNumberLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In sw, this message translates to:
  /// **'Simu'**
  String get phoneLabel;

  /// No description provided for @accountLinkedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya kuingia: Imeunganishwa'**
  String get accountLinkedLabel;

  /// No description provided for @accountNotLinkedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya kuingia: Haijaunganishwa'**
  String get accountNotLinkedLabel;

  /// No description provided for @joinedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Alijiunga'**
  String get joinedLabel;

  /// No description provided for @exitedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Alitoka'**
  String get exitedLabel;

  /// No description provided for @noRolesAssigned.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna jukumu lililopangwa.'**
  String get noRolesAssigned;

  /// No description provided for @suspendButton.
  ///
  /// In sw, this message translates to:
  /// **'Sitisha'**
  String get suspendButton;

  /// No description provided for @reactivateButton.
  ///
  /// In sw, this message translates to:
  /// **'Rudisha'**
  String get reactivateButton;

  /// No description provided for @markExitedButton.
  ///
  /// In sw, this message translates to:
  /// **'Weka Ametoka'**
  String get markExitedButton;

  /// No description provided for @rejoinButton.
  ///
  /// In sw, this message translates to:
  /// **'Rudisha kwenye Kikundi'**
  String get rejoinButton;

  /// No description provided for @suspendConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Sitisha mwanachama?'**
  String get suspendConfirmTitle;

  /// No description provided for @suspendConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu hataweza kushiriki shughuli za kikundi hadi atakaporudishwa.'**
  String get suspendConfirmMessage;

  /// No description provided for @exitConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Weka mwanachama kama ametoka?'**
  String get exitConfirmTitle;

  /// No description provided for @exitConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hatua hii haiwezi kutenduliwa hapa.'**
  String get exitConfirmMessage;

  /// No description provided for @reactivateConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rudisha mwanachama?'**
  String get reactivateConfirmTitle;

  /// No description provided for @reactivateConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu ataweza kushiriki shughuli za kikundi tena.'**
  String get reactivateConfirmMessage;

  /// No description provided for @rejoinConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mrudishe mwanachama kwenye kikundi?'**
  String get rejoinConfirmTitle;

  /// No description provided for @rejoinConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama ataweza kushiriki shughuli za kikundi tena kuanzia leo. Historia ya awali ya kuondoka kwake inabaki kwenye kumbukumbu.'**
  String get rejoinConfirmMessage;

  /// No description provided for @statusChangeSuccessActive.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama amerudishwa.'**
  String get statusChangeSuccessActive;

  /// No description provided for @statusChangeSuccessSuspended.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama amesitishwa.'**
  String get statusChangeSuccessSuspended;

  /// No description provided for @statusChangeSuccessExited.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama ameondolewa kwenye kikundi.'**
  String get statusChangeSuccessExited;

  /// No description provided for @rejoinSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama amerudishwa kwenye kikundi.'**
  String get rejoinSuccessMessage;

  /// No description provided for @refreshFailedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kupakia upya taarifa mpya. Bado inaweza kuonyesha taarifa za zamani.'**
  String get refreshFailedMessage;

  /// No description provided for @editMemberTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Mwanachama'**
  String get editMemberTitle;

  /// No description provided for @formSectionContact.
  ///
  /// In sw, this message translates to:
  /// **'Mawasiliano'**
  String get formSectionContact;

  /// No description provided for @formFullNameLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina kamili *'**
  String get formFullNameLabel;

  /// No description provided for @phoneOptionalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya simu (si lazima)'**
  String get phoneOptionalLabel;

  /// No description provided for @memberNumberAutoNote.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya mwanachama itatengenezwa kiotomatiki.'**
  String get memberNumberAutoNote;

  /// No description provided for @memberNameRequiredError.
  ///
  /// In sw, this message translates to:
  /// **'Jina kamili linahitajika.'**
  String get memberNameRequiredError;

  /// No description provided for @memberSaveError.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuhifadhi mwanachama. Jaribu tena.'**
  String get memberSaveError;

  /// No description provided for @rolesSheetSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Chagua majukumu ya mwanachama huyu.'**
  String get rolesSheetSubtitle;

  /// No description provided for @moreTitle.
  ///
  /// In sw, this message translates to:
  /// **'Zaidi'**
  String get moreTitle;

  /// No description provided for @accountSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti'**
  String get accountSectionTitle;

  /// No description provided for @currentGroupSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kikundi cha Sasa'**
  String get currentGroupSectionTitle;

  /// No description provided for @actionsSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Vitendo'**
  String get actionsSectionTitle;

  /// No description provided for @securitySectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Usalama'**
  String get securitySectionTitle;

  /// No description provided for @switchGroupAction.
  ///
  /// In sw, this message translates to:
  /// **'Badili Kikundi'**
  String get switchGroupAction;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In sw, this message translates to:
  /// **'Namba hiyo ya simu haikubaliki. Tafadhali ikague na ujaribu tena.'**
  String get authErrorInvalidPhone;

  /// No description provided for @authErrorInvalidOtp.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya uthibitisho si sahihi.'**
  String get authErrorInvalidOtp;

  /// No description provided for @authErrorOtpExpired.
  ///
  /// In sw, this message translates to:
  /// **'Muda wa msimbo huu umeisha. Omba mpya.'**
  String get authErrorOtpExpired;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In sw, this message translates to:
  /// **'Umejaribu mara nyingi. Tafadhali subiri kidogo kisha ujaribu tena.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuunganisha. Jaribu tena.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Jaribu tena.'**
  String get authErrorUnexpected;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya simu au PIN si sahihi.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorPinLocked.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu tena baada ya dakika chache.'**
  String get authErrorPinLocked;

  /// No description provided for @memberErrorAccountDisabled.
  ///
  /// In sw, this message translates to:
  /// **'Ufikiaji wa akaunti yako umezimwa. Wasiliana na msimamizi wa kikundi.'**
  String get memberErrorAccountDisabled;

  /// No description provided for @memberErrorLastAdminRequired.
  ///
  /// In sw, this message translates to:
  /// **'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.'**
  String get memberErrorLastAdminRequired;

  /// No description provided for @memberErrorInvalidStatusTransition.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu tayari ametoka na hawezi kurudishwa kwa njia hii.'**
  String get memberErrorInvalidStatusTransition;

  /// No description provided for @memberErrorDuplicateMemberNumber.
  ///
  /// In sw, this message translates to:
  /// **'Namba hiyo ya mwanachama tayari inatumika kwenye kikundi hiki.'**
  String get memberErrorDuplicateMemberNumber;

  /// No description provided for @memberErrorPermissionDenied.
  ///
  /// In sw, this message translates to:
  /// **'Huna ruhusa ya kufanya hivyo.'**
  String get memberErrorPermissionDenied;

  /// No description provided for @memberErrorNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama hakupatikana.'**
  String get memberErrorNotFound;

  /// No description provided for @memberErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuunganisha. Jaribu tena.'**
  String get memberErrorNetwork;

  /// No description provided for @memberErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Jaribu tena.'**
  String get memberErrorUnexpected;

  /// No description provided for @memberErrorRejoinConflict.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu tayari ana uanachama mwingine amilifu kwenye kikundi hiki.'**
  String get memberErrorRejoinConflict;

  /// No description provided for @supabaseConfigMissing.
  ///
  /// In sw, this message translates to:
  /// **'Mipangilio ya Supabase haipo (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY haijawekwa).'**
  String get supabaseConfigMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
