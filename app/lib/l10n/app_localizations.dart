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

  /// No description provided for @contributionsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Michango'**
  String get contributionsTitle;

  /// No description provided for @homeContributionsShortcutSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Angalia na simamia michango ya kikundi'**
  String get homeContributionsShortcutSubtitle;

  /// No description provided for @contributionTypesEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Aina za Michango'**
  String get contributionTypesEntryTitle;

  /// No description provided for @contributionTypesEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia aina za michango za kikundi'**
  String get contributionTypesEntrySubtitle;

  /// No description provided for @contributionSetupsEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mipangilio ya Michango'**
  String get contributionSetupsEntryTitle;

  /// No description provided for @contributionSetupsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia jinsi michango inavyotozwa'**
  String get contributionSetupsEntrySubtitle;

  /// No description provided for @contributionPeriodsEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Vipindi vya Michango'**
  String get contributionPeriodsEntryTitle;

  /// No description provided for @contributionPeriodsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia vipindi na malipo ya michango'**
  String get contributionPeriodsEntrySubtitle;

  /// No description provided for @contributionTypesTitle.
  ///
  /// In sw, this message translates to:
  /// **'Aina za Michango'**
  String get contributionTypesTitle;

  /// No description provided for @contributionTypesSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta aina ya mchango'**
  String get contributionTypesSearchHint;

  /// No description provided for @addContributionTypeAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Aina ya Mchango'**
  String get addContributionTypeAction;

  /// No description provided for @contributionTypesEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Jaza Orodha ya Aina za Michango'**
  String get contributionTypesEmptyTitle;

  /// No description provided for @contributionTypesEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza aina ya kwanza ya mchango.'**
  String get contributionTypesEmptyMessage;

  /// No description provided for @contributionTypesEmptyFilteredTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna aina ya mchango iliyopatikana'**
  String get contributionTypesEmptyFilteredTitle;

  /// No description provided for @contributionTypesEmptyFilteredMessage.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu kubadilisha maneno ya utafutaji au kichujio.'**
  String get contributionTypesEmptyFilteredMessage;

  /// No description provided for @editContributionTypeTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Aina ya Mchango'**
  String get editContributionTypeTitle;

  /// No description provided for @sectionContributionTypeDetails.
  ///
  /// In sw, this message translates to:
  /// **'Taarifa za Aina ya Mchango'**
  String get sectionContributionTypeDetails;

  /// No description provided for @sectionContributionClassification.
  ///
  /// In sw, this message translates to:
  /// **'Uainishaji na Utaratibu wa Uhasibu'**
  String get sectionContributionClassification;

  /// No description provided for @contributionTypeNameLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la aina ya mchango *'**
  String get contributionTypeNameLabel;

  /// No description provided for @contributionTypeDescriptionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (si lazima)'**
  String get contributionTypeDescriptionLabel;

  /// No description provided for @contributionCategoryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina'**
  String get contributionCategoryLabel;

  /// No description provided for @contributionAccountingTreatmentLabel.
  ///
  /// In sw, this message translates to:
  /// **'Utaratibu wa Uhasibu'**
  String get contributionAccountingTreatmentLabel;

  /// No description provided for @contributionTypeActiveLabel.
  ///
  /// In sw, this message translates to:
  /// **'Inatumika'**
  String get contributionTypeActiveLabel;

  /// No description provided for @contributionInactiveBadgeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Haitumiki'**
  String get contributionInactiveBadgeLabel;

  /// No description provided for @contributionDisplayOrderLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mpangilio wa Kuonyesha (si lazima)'**
  String get contributionDisplayOrderLabel;

  /// No description provided for @contributionFilterActiveOnly.
  ///
  /// In sw, this message translates to:
  /// **'Zinazotumika'**
  String get contributionFilterActiveOnly;

  /// No description provided for @contributionFilterInactiveOnly.
  ///
  /// In sw, this message translates to:
  /// **'Hazitumiki'**
  String get contributionFilterInactiveOnly;

  /// No description provided for @contributionCategoryGeneral.
  ///
  /// In sw, this message translates to:
  /// **'Jumla'**
  String get contributionCategoryGeneral;

  /// No description provided for @contributionCategorySocial.
  ///
  /// In sw, this message translates to:
  /// **'Kijamii'**
  String get contributionCategorySocial;

  /// No description provided for @contributionCategoryShare.
  ///
  /// In sw, this message translates to:
  /// **'Hisa'**
  String get contributionCategoryShare;

  /// No description provided for @contributionTreatmentGroupIncome.
  ///
  /// In sw, this message translates to:
  /// **'Pato la Kikundi'**
  String get contributionTreatmentGroupIncome;

  /// No description provided for @contributionTreatmentPassThrough.
  ///
  /// In sw, this message translates to:
  /// **'Si Pato la Kikundi'**
  String get contributionTreatmentPassThrough;

  /// No description provided for @contributionTreatmentPassThroughHelp.
  ///
  /// In sw, this message translates to:
  /// **'Fedha hukusanywa kwa kusudi maalum na hazitambuliki kama pato la kawaida la kikundi.'**
  String get contributionTreatmentPassThroughHelp;

  /// No description provided for @contributionTreatmentShareCapital.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Hisa'**
  String get contributionTreatmentShareCapital;

  /// No description provided for @contributionTreatmentMemberSavingsUnavailable.
  ///
  /// In sw, this message translates to:
  /// **'Akiba ya Mwanachama (Haipatikani bado)'**
  String get contributionTreatmentMemberSavingsUnavailable;

  /// No description provided for @contributionSetupsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mipangilio ya Michango'**
  String get contributionSetupsTitle;

  /// No description provided for @addContributionSetupAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Mpangilio'**
  String get addContributionSetupAction;

  /// No description provided for @contributionSetupsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Jaza Orodha ya Mipangilio'**
  String get contributionSetupsEmptyTitle;

  /// No description provided for @contributionSetupsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza mpangilio wa kwanza wa mchango.'**
  String get contributionSetupsEmptyMessage;

  /// No description provided for @contributionSetupsEmptyFilteredTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna mpangilio uliopatikana'**
  String get contributionSetupsEmptyFilteredTitle;

  /// No description provided for @contributionSetupsEmptyFilteredMessage.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu kubadilisha kichujio.'**
  String get contributionSetupsEmptyFilteredMessage;

  /// No description provided for @editContributionSetupTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Mpangilio'**
  String get editContributionSetupTitle;

  /// No description provided for @sectionContributionSetupDetails.
  ///
  /// In sw, this message translates to:
  /// **'Taarifa za Mpangilio'**
  String get sectionContributionSetupDetails;

  /// No description provided for @sectionContributionChargingRules.
  ///
  /// In sw, this message translates to:
  /// **'Kanuni za Utozaji'**
  String get sectionContributionChargingRules;

  /// No description provided for @sectionContributionDueDateRules.
  ///
  /// In sw, this message translates to:
  /// **'Kanuni za Tarehe ya Malipo'**
  String get sectionContributionDueDateRules;

  /// No description provided for @sectionContributionPenaltyRules.
  ///
  /// In sw, this message translates to:
  /// **'Kanuni za Adhabu'**
  String get sectionContributionPenaltyRules;

  /// No description provided for @contributionSetupNameLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la mpangilio *'**
  String get contributionSetupNameLabel;

  /// No description provided for @contributionSetupDescriptionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (si lazima)'**
  String get contributionSetupDescriptionLabel;

  /// No description provided for @contributionSetupTypeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Mchango'**
  String get contributionSetupTypeLabel;

  /// No description provided for @contributionScheduleModeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Utaratibu wa Muda'**
  String get contributionScheduleModeLabel;

  /// No description provided for @contributionAmountModeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Utaratibu wa Kiasi'**
  String get contributionAmountModeLabel;

  /// No description provided for @contributionFixedAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi *'**
  String get contributionFixedAmountLabel;

  /// No description provided for @contributionDefaultDueDayLabel.
  ///
  /// In sw, this message translates to:
  /// **'Siku ya Mwisho ya Malipo (1–31)'**
  String get contributionDefaultDueDayLabel;

  /// No description provided for @contributionDefaultDueMonthOffsetLabel.
  ///
  /// In sw, this message translates to:
  /// **'Nyongeza ya Mwezi kwa Tarehe ya Mwisho'**
  String get contributionDefaultDueMonthOffsetLabel;

  /// No description provided for @contributionPenaltyModeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Utaratibu wa Adhabu'**
  String get contributionPenaltyModeLabel;

  /// No description provided for @contributionPenaltyGraceDaysLabel.
  ///
  /// In sw, this message translates to:
  /// **'Siku za Neema'**
  String get contributionPenaltyGraceDaysLabel;

  /// No description provided for @contributionPenaltyValueLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Adhabu *'**
  String get contributionPenaltyValueLabel;

  /// No description provided for @contributionPenaltyCapAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Juu cha Adhabu (si lazima)'**
  String get contributionPenaltyCapAmountLabel;

  /// No description provided for @contributionSetupActiveLabel.
  ///
  /// In sw, this message translates to:
  /// **'Inatumika'**
  String get contributionSetupActiveLabel;

  /// No description provided for @contributionScheduleMonthly.
  ///
  /// In sw, this message translates to:
  /// **'Kila Mwezi'**
  String get contributionScheduleMonthly;

  /// No description provided for @contributionScheduleOnDemand.
  ///
  /// In sw, this message translates to:
  /// **'Inapohitajika'**
  String get contributionScheduleOnDemand;

  /// No description provided for @contributionScheduleOneTime.
  ///
  /// In sw, this message translates to:
  /// **'Mara Moja'**
  String get contributionScheduleOneTime;

  /// No description provided for @contributionAmountFixed.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Kimoja'**
  String get contributionAmountFixed;

  /// No description provided for @contributionAmountCustomPerMember.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Tofauti kwa Kila Mwanachama'**
  String get contributionAmountCustomPerMember;

  /// No description provided for @contributionPenaltyNone.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna'**
  String get contributionPenaltyNone;

  /// No description provided for @contributionPenaltyFixedOnce.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Maalum (Mara Moja)'**
  String get contributionPenaltyFixedOnce;

  /// No description provided for @contributionPenaltyFixedRecurring.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Maalum (Kinachorudia)'**
  String get contributionPenaltyFixedRecurring;

  /// No description provided for @contributionPenaltyPercentageOnce.
  ///
  /// In sw, this message translates to:
  /// **'Asilimia (Mara Moja)'**
  String get contributionPenaltyPercentageOnce;

  /// No description provided for @contributionPenaltyPercentageRecurring.
  ///
  /// In sw, this message translates to:
  /// **'Asilimia (Inayorudia)'**
  String get contributionPenaltyPercentageRecurring;

  /// No description provided for @contributionPeriodsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Vipindi vya Michango'**
  String get contributionPeriodsTitle;

  /// No description provided for @addContributionPeriodAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Kipindi'**
  String get addContributionPeriodAction;

  /// No description provided for @contributionPeriodsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Jaza Orodha ya Vipindi'**
  String get contributionPeriodsEmptyTitle;

  /// No description provided for @contributionPeriodsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza kipindi cha kwanza cha mchango.'**
  String get contributionPeriodsEmptyMessage;

  /// No description provided for @contributionPeriodsEmptyFilteredTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna kipindi kilichopatikana'**
  String get contributionPeriodsEmptyFilteredTitle;

  /// No description provided for @contributionPeriodsEmptyFilteredMessage.
  ///
  /// In sw, this message translates to:
  /// **'Jaribu kubadilisha kichujio.'**
  String get contributionPeriodsEmptyFilteredMessage;

  /// No description provided for @contributionPeriodStatusDraft.
  ///
  /// In sw, this message translates to:
  /// **'Rasimu'**
  String get contributionPeriodStatusDraft;

  /// No description provided for @contributionPeriodStatusScheduled.
  ///
  /// In sw, this message translates to:
  /// **'Imepangwa'**
  String get contributionPeriodStatusScheduled;

  /// No description provided for @contributionPeriodStatusOpen.
  ///
  /// In sw, this message translates to:
  /// **'Iko Wazi'**
  String get contributionPeriodStatusOpen;

  /// No description provided for @contributionPeriodStatusClosed.
  ///
  /// In sw, this message translates to:
  /// **'Imefungwa'**
  String get contributionPeriodStatusClosed;

  /// No description provided for @contributionPeriodStatusCancelled.
  ///
  /// In sw, this message translates to:
  /// **'Imesitishwa'**
  String get contributionPeriodStatusCancelled;

  /// No description provided for @newContributionPeriodTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi Kipya cha Mchango'**
  String get newContributionPeriodTitle;

  /// No description provided for @contributionPeriodSetupLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mpangilio wa Mchango *'**
  String get contributionPeriodSetupLabel;

  /// No description provided for @contributionPeriodLabelLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la Kipindi *'**
  String get contributionPeriodLabelLabel;

  /// No description provided for @contributionPeriodMonthLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mwezi'**
  String get contributionPeriodMonthLabel;

  /// No description provided for @contributionPeriodYearLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mwaka'**
  String get contributionPeriodYearLabel;

  /// No description provided for @contributionMonthJanuary.
  ///
  /// In sw, this message translates to:
  /// **'Januari'**
  String get contributionMonthJanuary;

  /// No description provided for @contributionMonthFebruary.
  ///
  /// In sw, this message translates to:
  /// **'Februari'**
  String get contributionMonthFebruary;

  /// No description provided for @contributionMonthMarch.
  ///
  /// In sw, this message translates to:
  /// **'Machi'**
  String get contributionMonthMarch;

  /// No description provided for @contributionMonthApril.
  ///
  /// In sw, this message translates to:
  /// **'Aprili'**
  String get contributionMonthApril;

  /// No description provided for @contributionMonthMay.
  ///
  /// In sw, this message translates to:
  /// **'Mei'**
  String get contributionMonthMay;

  /// No description provided for @contributionMonthJune.
  ///
  /// In sw, this message translates to:
  /// **'Juni'**
  String get contributionMonthJune;

  /// No description provided for @contributionMonthJuly.
  ///
  /// In sw, this message translates to:
  /// **'Julai'**
  String get contributionMonthJuly;

  /// No description provided for @contributionMonthAugust.
  ///
  /// In sw, this message translates to:
  /// **'Agosti'**
  String get contributionMonthAugust;

  /// No description provided for @contributionMonthSeptember.
  ///
  /// In sw, this message translates to:
  /// **'Septemba'**
  String get contributionMonthSeptember;

  /// No description provided for @contributionMonthOctober.
  ///
  /// In sw, this message translates to:
  /// **'Oktoba'**
  String get contributionMonthOctober;

  /// No description provided for @contributionMonthNovember.
  ///
  /// In sw, this message translates to:
  /// **'Novemba'**
  String get contributionMonthNovember;

  /// No description provided for @contributionMonthDecember.
  ///
  /// In sw, this message translates to:
  /// **'Desemba'**
  String get contributionMonthDecember;

  /// No description provided for @contributionPeriodStartLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Kuanza'**
  String get contributionPeriodStartLabel;

  /// No description provided for @contributionPeriodEndLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Mwisho'**
  String get contributionPeriodEndLabel;

  /// No description provided for @contributionPeriodCreatedTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi Kimetengenezwa'**
  String get contributionPeriodCreatedTitle;

  /// No description provided for @contributionPeriodCreatedDueDateMessage.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya mwisho ya malipo: {date}'**
  String contributionPeriodCreatedDueDateMessage(String date);

  /// No description provided for @contributionPeriodDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi cha Mchango'**
  String get contributionPeriodDetailTitle;

  /// No description provided for @editContributionPeriodTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Kipindi'**
  String get editContributionPeriodTitle;

  /// No description provided for @sectionContributionPeriodDates.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe Muhimu'**
  String get sectionContributionPeriodDates;

  /// No description provided for @contributionObligationDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Wajibu'**
  String get contributionObligationDateLabel;

  /// No description provided for @contributionEligibilityDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Ustahiki'**
  String get contributionEligibilityDateLabel;

  /// No description provided for @contributionDueDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Mwisho ya Malipo'**
  String get contributionDueDateLabel;

  /// No description provided for @contributionScheduledOpenDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Kufungua Iliyopangwa'**
  String get contributionScheduledOpenDateLabel;

  /// No description provided for @sectionContributionSnapshot.
  ///
  /// In sw, this message translates to:
  /// **'Taarifa Zilizohifadhiwa'**
  String get sectionContributionSnapshot;

  /// No description provided for @sectionContributionSummary.
  ///
  /// In sw, this message translates to:
  /// **'Muhtasari'**
  String get sectionContributionSummary;

  /// No description provided for @contributionExcludedCountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Waliotolewa'**
  String get contributionExcludedCountLabel;

  /// No description provided for @contributionCustomAmountCountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Waliowekewa Kiasi Maalum'**
  String get contributionCustomAmountCountLabel;

  /// No description provided for @contributionTotalMembersChargedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Waliotozwa'**
  String get contributionTotalMembersChargedLabel;

  /// No description provided for @contributionTotalBaseAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla Iliyotozwa'**
  String get contributionTotalBaseAssessedLabel;

  /// No description provided for @contributionTotalPenaltyAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Adhabu Zilizotozwa'**
  String get contributionTotalPenaltyAssessedLabel;

  /// No description provided for @contributionPenaltyChargeCountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yenye Adhabu'**
  String get contributionPenaltyChargeCountLabel;

  /// No description provided for @contributionNoPenaltyPolicyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna kanuni ya adhabu iliyowekwa kwa kipindi hiki.'**
  String get contributionNoPenaltyPolicyMessage;

  /// No description provided for @editExclusionsAction.
  ///
  /// In sw, this message translates to:
  /// **'Simamia Walioondolewa'**
  String get editExclusionsAction;

  /// No description provided for @configureCustomAmountsAction.
  ///
  /// In sw, this message translates to:
  /// **'Weka Kiasi kwa Kila Mwanachama'**
  String get configureCustomAmountsAction;

  /// No description provided for @previewAndOpenAction.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki na Fungua'**
  String get previewAndOpenAction;

  /// No description provided for @cancelPeriodAction.
  ///
  /// In sw, this message translates to:
  /// **'Sitisha Kipindi'**
  String get cancelPeriodAction;

  /// No description provided for @viewChargesAction.
  ///
  /// In sw, this message translates to:
  /// **'Angalia Malipo Yaliyotozwa'**
  String get viewChargesAction;

  /// No description provided for @enrollMemberAction.
  ///
  /// In sw, this message translates to:
  /// **'Andikisha Mwanachama'**
  String get enrollMemberAction;

  /// No description provided for @closePeriodAction.
  ///
  /// In sw, this message translates to:
  /// **'Funga Kipindi'**
  String get closePeriodAction;

  /// No description provided for @cancelPeriodConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Sitisha kipindi hiki?'**
  String get cancelPeriodConfirmTitle;

  /// No description provided for @cancelPeriodConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hatua hii haiwezi kutenduliwa.'**
  String get cancelPeriodConfirmMessage;

  /// No description provided for @closePeriodConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Funga kipindi hiki?'**
  String get closePeriodConfirmTitle;

  /// No description provided for @closePeriodConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Baada ya kufungwa, wanachama wapya wataweza kuongezwa tu kwa kuandikishwa mmoja mmoja.'**
  String get closePeriodConfirmMessage;

  /// No description provided for @periodCancelledMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi kimesitishwa.'**
  String get periodCancelledMessage;

  /// No description provided for @periodClosedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi kimefungwa.'**
  String get periodClosedMessage;

  /// No description provided for @periodOpenedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi kimefunguliwa.'**
  String get periodOpenedMessage;

  /// No description provided for @assessPenaltiesAction.
  ///
  /// In sw, this message translates to:
  /// **'Tathmini Adhabu'**
  String get assessPenaltiesAction;

  /// No description provided for @assessPenaltiesConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Tathmini adhabu za kipindi hiki?'**
  String get assessPenaltiesConfirmTitle;

  /// No description provided for @assessPenaltiesConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hii itaangalia kila malipo yaliyochelewa na kutoza adhabu yoyote mpya inayostahili. Ni salama kuendesha tena — haitaweka adhabu mara mbili.'**
  String get assessPenaltiesConfirmMessage;

  /// No description provided for @assessPenaltiesResultTitle.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu Zimetathminiwa'**
  String get assessPenaltiesResultTitle;

  /// No description provided for @assessPenaltiesResultCreatedCount.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu Mpya Zilizowekwa: {count}'**
  String assessPenaltiesResultCreatedCount(Object count);

  /// No description provided for @assessPenaltiesResultAlreadyCurrentCount.
  ///
  /// In sw, this message translates to:
  /// **'Zilizokuwa Sahihi Tayari: {count}'**
  String assessPenaltiesResultAlreadyCurrentCount(Object count);

  /// No description provided for @assessPenaltiesResultTotalThisRun.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Adhabu Mpya'**
  String get assessPenaltiesResultTotalThisRun;

  /// No description provided for @openPreviewTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki Kufungua Kipindi'**
  String get openPreviewTitle;

  /// No description provided for @openPreviewEligibleCount.
  ///
  /// In sw, this message translates to:
  /// **'Wanachama Wanaostahili: {count}'**
  String openPreviewEligibleCount(int count);

  /// No description provided for @openPreviewExcludedCount.
  ///
  /// In sw, this message translates to:
  /// **'Wanachama Walioondolewa: {count}'**
  String openPreviewExcludedCount(int count);

  /// No description provided for @openPreviewMissingAmountCount.
  ///
  /// In sw, this message translates to:
  /// **'Wanaokosa Kiasi: {count}'**
  String openPreviewMissingAmountCount(int count);

  /// No description provided for @openPreviewExpectedTotal.
  ///
  /// In sw, this message translates to:
  /// **'Jumla Itakayotozwa'**
  String get openPreviewExpectedTotal;

  /// No description provided for @openPreviewMissingAmountWarning.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi kwa wanachama wote kabla ya kufungua kipindi hiki.'**
  String get openPreviewMissingAmountWarning;

  /// No description provided for @openPreviewConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Fungua kipindi hiki?'**
  String get openPreviewConfirmTitle;

  /// No description provided for @openPreviewConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hatua hii itatoza malipo kwa wanachama wote wanaostahili na haiwezi kutenduliwa.'**
  String get openPreviewConfirmMessage;

  /// No description provided for @openPreviewConfirmButton.
  ///
  /// In sw, this message translates to:
  /// **'Fungua Kipindi'**
  String get openPreviewConfirmButton;

  /// No description provided for @sectionEligibleMembers.
  ///
  /// In sw, this message translates to:
  /// **'Wanachama Wanaostahili'**
  String get sectionEligibleMembers;

  /// No description provided for @sectionExcludedMembers.
  ///
  /// In sw, this message translates to:
  /// **'Wanachama Walioondolewa'**
  String get sectionExcludedMembers;

  /// No description provided for @sectionMissingAmountMembers.
  ///
  /// In sw, this message translates to:
  /// **'Wanaokosa Kiasi'**
  String get sectionMissingAmountMembers;

  /// No description provided for @customAmountEditorTitle.
  ///
  /// In sw, this message translates to:
  /// **'Weka Kiasi kwa Kila Mwanachama'**
  String get customAmountEditorTitle;

  /// No description provided for @customAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get customAmountFieldLabel;

  /// No description provided for @customAmountMissingBadge.
  ///
  /// In sw, this message translates to:
  /// **'Haijawekwa'**
  String get customAmountMissingBadge;

  /// No description provided for @customAmountSaveAction.
  ///
  /// In sw, this message translates to:
  /// **'Hifadhi Kiasi'**
  String get customAmountSaveAction;

  /// No description provided for @customAmountSavedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi vimehifadhiwa.'**
  String get customAmountSavedMessage;

  /// No description provided for @customAmountSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get customAmountSearchHint;

  /// No description provided for @exclusionsScreenTitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia Walioondolewa'**
  String get exclusionsScreenTitle;

  /// No description provided for @exclusionSheetTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ondoa kwenye Kipindi Hiki'**
  String get exclusionSheetTitle;

  /// No description provided for @exclusionReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu (si lazima)'**
  String get exclusionReasonLabel;

  /// No description provided for @excludeMemberAction.
  ///
  /// In sw, this message translates to:
  /// **'Ondoa kwenye Kipindi Hiki'**
  String get excludeMemberAction;

  /// No description provided for @removeExclusionAction.
  ///
  /// In sw, this message translates to:
  /// **'Rudisha kwenye Kipindi'**
  String get removeExclusionAction;

  /// No description provided for @memberExcludedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama ameondolewa kwenye kipindi hiki.'**
  String get memberExcludedMessage;

  /// No description provided for @memberExclusionRemovedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama amerudishwa kwenye kipindi hiki.'**
  String get memberExclusionRemovedMessage;

  /// No description provided for @contributionExclusionReasonSuspended.
  ///
  /// In sw, this message translates to:
  /// **'Amesitishwa'**
  String get contributionExclusionReasonSuspended;

  /// No description provided for @contributionExclusionReasonExited.
  ///
  /// In sw, this message translates to:
  /// **'Ametoka'**
  String get contributionExclusionReasonExited;

  /// No description provided for @contributionExclusionReasonJoinedAfterEligibility.
  ///
  /// In sw, this message translates to:
  /// **'Alijiunga baada ya tarehe ya ustahiki'**
  String get contributionExclusionReasonJoinedAfterEligibility;

  /// No description provided for @contributionExclusionReasonExitedDuringPeriod.
  ///
  /// In sw, this message translates to:
  /// **'Alitoka na kurudi wakati wa kipindi'**
  String get contributionExclusionReasonExitedDuringPeriod;

  /// No description provided for @contributionExclusionReasonExcludedDefault.
  ///
  /// In sw, this message translates to:
  /// **'Ameondolewa'**
  String get contributionExclusionReasonExcludedDefault;

  /// No description provided for @chargesListTitle.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yaliyotozwa'**
  String get chargesListTitle;

  /// No description provided for @chargesSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get chargesSearchHint;

  /// No description provided for @chargesEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Malipo Bado'**
  String get chargesEmptyTitle;

  /// No description provided for @chargesEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna mwanachama aliyetozwa kwenye kipindi hiki bado.'**
  String get chargesEmptyMessage;

  /// No description provided for @chargeBaseAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Kilichowekwa'**
  String get chargeBaseAmountLabel;

  /// No description provided for @chargePenaltyAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu'**
  String get chargePenaltyAmountLabel;

  /// No description provided for @chargeTotalAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla'**
  String get chargeTotalAmountLabel;

  /// No description provided for @enrollMemberTitle.
  ///
  /// In sw, this message translates to:
  /// **'Andikisha Mwanachama'**
  String get enrollMemberTitle;

  /// No description provided for @enrollMemberSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get enrollMemberSearchHint;

  /// No description provided for @enrollMemberAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi *'**
  String get enrollMemberAmountLabel;

  /// No description provided for @enrollMemberSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama ameandikishwa kwenye kipindi.'**
  String get enrollMemberSuccessMessage;

  /// No description provided for @enrollMemberEmptyResults.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna mwanachama aliyepatikana'**
  String get enrollMemberEmptyResults;

  /// No description provided for @contributionErrorNameRequired.
  ///
  /// In sw, this message translates to:
  /// **'Jina linahitajika.'**
  String get contributionErrorNameRequired;

  /// No description provided for @contributionErrorMemberSavingsNotAvailable.
  ///
  /// In sw, this message translates to:
  /// **'Akiba ya mwanachama haipatikani bado.'**
  String get contributionErrorMemberSavingsNotAvailable;

  /// No description provided for @contributionErrorAccountingLocked.
  ///
  /// In sw, this message translates to:
  /// **'Aina na utaratibu wa uhasibu haviwezi kubadilishwa baada ya kipindi kufunguliwa.'**
  String get contributionErrorAccountingLocked;

  /// No description provided for @contributionErrorSetupConfigLocked.
  ///
  /// In sw, this message translates to:
  /// **'Mpangilio huu umefungwa baada ya kipindi kufunguliwa.'**
  String get contributionErrorSetupConfigLocked;

  /// No description provided for @contributionErrorTypeInactive.
  ///
  /// In sw, this message translates to:
  /// **'Aina hii ya mchango haitumiki.'**
  String get contributionErrorTypeInactive;

  /// No description provided for @contributionErrorSetupInactive.
  ///
  /// In sw, this message translates to:
  /// **'Mpangilio huu haitumiki.'**
  String get contributionErrorSetupInactive;

  /// No description provided for @contributionErrorDuplicateName.
  ///
  /// In sw, this message translates to:
  /// **'Jina hilo tayari linatumika kwenye kikundi hiki.'**
  String get contributionErrorDuplicateName;

  /// No description provided for @contributionErrorInvalidDates.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe za kipindi si sahihi.'**
  String get contributionErrorInvalidDates;

  /// No description provided for @contributionErrorDueDateRequired.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya mwisho ya malipo inahitajika.'**
  String get contributionErrorDueDateRequired;

  /// No description provided for @contributionErrorDuplicateMonthlyPeriod.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi cha mwezi huu tayari kipo.'**
  String get contributionErrorDuplicateMonthlyPeriod;

  /// No description provided for @contributionErrorPeriodNotEditable.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki hakiwezi kuhaririwa tena.'**
  String get contributionErrorPeriodNotEditable;

  /// No description provided for @contributionErrorSetupNotCustomAmount.
  ///
  /// In sw, this message translates to:
  /// **'Mpangilio huu hautumii kiasi tofauti kwa kila mwanachama.'**
  String get contributionErrorSetupNotCustomAmount;

  /// No description provided for @contributionErrorMembershipNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama hakupatikana.'**
  String get contributionErrorMembershipNotFound;

  /// No description provided for @contributionErrorInvalidAmount.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi lazima kiwe zaidi ya sifuri.'**
  String get contributionErrorInvalidAmount;

  /// No description provided for @contributionErrorPeriodNotPreviewable.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki hakiwezi kuhakikiwa kwa sasa.'**
  String get contributionErrorPeriodNotPreviewable;

  /// No description provided for @contributionErrorPeriodNotOpenable.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki hakiwezi kufunguliwa kwa sasa.'**
  String get contributionErrorPeriodNotOpenable;

  /// No description provided for @contributionErrorMissingCustomAmounts.
  ///
  /// In sw, this message translates to:
  /// **'Baadhi ya wanachama wanaostahili hawana kiasi kilichowekwa.'**
  String get contributionErrorMissingCustomAmounts;

  /// No description provided for @contributionErrorPeriodNotOpen.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki halijafunguliwa.'**
  String get contributionErrorPeriodNotOpen;

  /// No description provided for @contributionErrorMemberAlreadyCharged.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu tayari ametozwa kwenye kipindi hiki.'**
  String get contributionErrorMemberAlreadyCharged;

  /// No description provided for @contributionErrorAmountRequired.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi kinahitajika.'**
  String get contributionErrorAmountRequired;

  /// No description provided for @contributionErrorPeriodNotCancellable.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki hakiwezi kusitishwa tena.'**
  String get contributionErrorPeriodNotCancellable;

  /// No description provided for @contributionErrorNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Haikupatikana.'**
  String get contributionErrorNotFound;

  /// No description provided for @contributionErrorNoPenaltyPolicy.
  ///
  /// In sw, this message translates to:
  /// **'Kipindi hiki hakina kanuni ya adhabu iliyowekwa.'**
  String get contributionErrorNoPenaltyPolicy;

  /// No description provided for @contributionErrorPermissionDenied.
  ///
  /// In sw, this message translates to:
  /// **'Huna ruhusa ya kufanya hivyo.'**
  String get contributionErrorPermissionDenied;

  /// No description provided for @contributionErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuunganisha. Jaribu tena.'**
  String get contributionErrorNetwork;

  /// No description provided for @contributionErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Jaribu tena.'**
  String get contributionErrorUnexpected;

  /// No description provided for @contributionErrorAdjustmentAmountRequired.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha marekebisho kinahitajika na hakiwezi kuwa sifuri.'**
  String get contributionErrorAdjustmentAmountRequired;

  /// No description provided for @contributionErrorAdjustmentReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya marekebisho inahitajika.'**
  String get contributionErrorAdjustmentReasonRequired;

  /// No description provided for @contributionErrorAdjustmentWouldMakeObligationNegative.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho haya yangefanya deni kuwa hasi.'**
  String get contributionErrorAdjustmentWouldMakeObligationNegative;

  /// No description provided for @contributionErrorWaiverAmountMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha msamaha lazima kiwe zaidi ya sifuri.'**
  String get contributionErrorWaiverAmountMustBePositive;

  /// No description provided for @contributionErrorWaiverReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya msamaha inahitajika.'**
  String get contributionErrorWaiverReasonRequired;

  /// No description provided for @contributionErrorWaiverExceedsNetAssessed.
  ///
  /// In sw, this message translates to:
  /// **'Msamaha huu unazidi jumla ya deni lililowekwa kwa sasa.'**
  String get contributionErrorWaiverExceedsNetAssessed;

  /// No description provided for @contributionErrorOpeningBalanceAmountMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha deni la mwanzo lazima kiwe zaidi ya sifuri.'**
  String get contributionErrorOpeningBalanceAmountMustBePositive;

  /// No description provided for @contributionErrorOpeningBalanceAlreadyImported.
  ///
  /// In sw, this message translates to:
  /// **'Deni la mwanzo la mwanachama huyu tayari limeingizwa.'**
  String get contributionErrorOpeningBalanceAlreadyImported;

  /// No description provided for @contributionComponentBase.
  ///
  /// In sw, this message translates to:
  /// **'Deni Msingi'**
  String get contributionComponentBase;

  /// No description provided for @contributionComponentPenalty.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu'**
  String get contributionComponentPenalty;

  /// No description provided for @contributionComponentAdjustment.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho'**
  String get contributionComponentAdjustment;

  /// No description provided for @contributionComponentWaiver.
  ///
  /// In sw, this message translates to:
  /// **'Msamaha wa Deni'**
  String get contributionComponentWaiver;

  /// No description provided for @contributionComponentOpeningBalance.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Mwanzo'**
  String get contributionComponentOpeningBalance;

  /// No description provided for @contributionComponentReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu'**
  String get contributionComponentReasonLabel;

  /// No description provided for @contributionComponentDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe'**
  String get contributionComponentDateLabel;

  /// No description provided for @contributionNetAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Deni Lililowekwa'**
  String get contributionNetAssessedLabel;

  /// No description provided for @contributionCurrentNetAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Sasa Lililowekwa'**
  String get contributionCurrentNetAssessedLabel;

  /// No description provided for @contributionEffectiveDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe Itakayotumika'**
  String get contributionEffectiveDateFieldLabel;

  /// No description provided for @chargeDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Malipo'**
  String get chargeDetailTitle;

  /// No description provided for @sectionChargeBreakdown.
  ///
  /// In sw, this message translates to:
  /// **'Mchanganuo wa Malipo'**
  String get sectionChargeBreakdown;

  /// No description provided for @addAdjustmentAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Marekebisho'**
  String get addAdjustmentAction;

  /// No description provided for @waiveObligationAction.
  ///
  /// In sw, this message translates to:
  /// **'Samehe Deni'**
  String get waiveObligationAction;

  /// No description provided for @viewMemberSummaryAction.
  ///
  /// In sw, this message translates to:
  /// **'Ona Muhtasari wa Mwanachama'**
  String get viewMemberSummaryAction;

  /// No description provided for @memberSummaryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Muhtasari wa Deni la Mwanachama'**
  String get memberSummaryTitle;

  /// No description provided for @addAdjustmentTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Marekebisho'**
  String get addAdjustmentTitle;

  /// No description provided for @adjustmentDirectionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Marekebisho'**
  String get adjustmentDirectionLabel;

  /// No description provided for @adjustmentIncreaseOption.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Deni'**
  String get adjustmentIncreaseOption;

  /// No description provided for @adjustmentReduceOption.
  ///
  /// In sw, this message translates to:
  /// **'Punguza Deni'**
  String get adjustmentReduceOption;

  /// No description provided for @adjustmentAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi *'**
  String get adjustmentAmountFieldLabel;

  /// No description provided for @adjustmentReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu *'**
  String get adjustmentReasonFieldLabel;

  /// No description provided for @adjustmentSubmitAction.
  ///
  /// In sw, this message translates to:
  /// **'Wasilisha Marekebisho'**
  String get adjustmentSubmitAction;

  /// No description provided for @adjustmentSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho yamewekwa.'**
  String get adjustmentSuccessMessage;

  /// No description provided for @waiveObligationTitle.
  ///
  /// In sw, this message translates to:
  /// **'Samehe Deni'**
  String get waiveObligationTitle;

  /// No description provided for @waiverTypeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Msamaha'**
  String get waiverTypeLabel;

  /// No description provided for @waiverPartialOption.
  ///
  /// In sw, this message translates to:
  /// **'Sehemu'**
  String get waiverPartialOption;

  /// No description provided for @waiverFullOption.
  ///
  /// In sw, this message translates to:
  /// **'Yote'**
  String get waiverFullOption;

  /// No description provided for @waiverAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha Kusamehe *'**
  String get waiverAmountFieldLabel;

  /// No description provided for @waiverReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu *'**
  String get waiverReasonFieldLabel;

  /// No description provided for @waiverMaximumLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Juu cha Msamaha'**
  String get waiverMaximumLabel;

  /// No description provided for @waiverRemainingAfterLabel.
  ///
  /// In sw, this message translates to:
  /// **'Itakayobaki Baada ya Msamaha'**
  String get waiverRemainingAfterLabel;

  /// No description provided for @waiverSubmitAction.
  ///
  /// In sw, this message translates to:
  /// **'Wasilisha Msamaha'**
  String get waiverSubmitAction;

  /// No description provided for @waiverSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Deni limesamehewa.'**
  String get waiverSuccessMessage;

  /// No description provided for @openingBalancesEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Madeni ya Mwanzo'**
  String get openingBalancesEntryTitle;

  /// No description provided for @openingBalancesEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza madeni ya wanachama kabla ya Umoja'**
  String get openingBalancesEntrySubtitle;

  /// No description provided for @openingBalancesTitle.
  ///
  /// In sw, this message translates to:
  /// **'Madeni ya Mwanzo'**
  String get openingBalancesTitle;

  /// No description provided for @openingBalancesEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Deni la Mwanzo'**
  String get openingBalancesEmptyTitle;

  /// No description provided for @openingBalancesEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna deni la mwanzo lililoingizwa.'**
  String get openingBalancesEmptyMessage;

  /// No description provided for @openingBalanceImportAction.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza Madeni ya Mwanzo'**
  String get openingBalanceImportAction;

  /// No description provided for @openingBalanceImportTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza Madeni ya Mwanzo'**
  String get openingBalanceImportTitle;

  /// No description provided for @openingBalanceContributionTypeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Mchango'**
  String get openingBalanceContributionTypeLabel;

  /// No description provided for @openingBalanceEffectiveDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Mwanzo'**
  String get openingBalanceEffectiveDateLabel;

  /// No description provided for @openingBalanceSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get openingBalanceSearchHint;

  /// No description provided for @openingBalanceAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get openingBalanceAmountFieldLabel;

  /// No description provided for @openingBalancePreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki'**
  String get openingBalancePreviewAction;

  /// No description provided for @openingBalanceMemberCountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Idadi ya Wanachama'**
  String get openingBalanceMemberCountLabel;

  /// No description provided for @openingBalanceTotalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Deni la Mwanzo'**
  String get openingBalanceTotalLabel;

  /// No description provided for @openingBalanceAlreadyImportedBadge.
  ///
  /// In sw, this message translates to:
  /// **'Tayari Imeingizwa'**
  String get openingBalanceAlreadyImportedBadge;

  /// No description provided for @openingBalanceConfirmImportAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Kuingiza'**
  String get openingBalanceConfirmImportAction;

  /// No description provided for @openingBalanceImportSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Madeni ya mwanzo yameingizwa.'**
  String get openingBalanceImportSuccessMessage;

  /// No description provided for @openingBalanceCannotImportMessage.
  ///
  /// In sw, this message translates to:
  /// **'Baadhi ya wanachama tayari wana deni la mwanzo. Ondoa au badilisha kiasi chao kabla ya kuendelea.'**
  String get openingBalanceCannotImportMessage;

  /// No description provided for @financialAccountsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti za Fedha'**
  String get financialAccountsTitle;

  /// No description provided for @homeFinancialAccountsShortcutSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Fedha taslimu, benki na pesa za simu'**
  String get homeFinancialAccountsShortcutSubtitle;

  /// No description provided for @financialAccountsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Akaunti za Fedha'**
  String get financialAccountsEmptyTitle;

  /// No description provided for @financialAccountsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna akaunti ya fedha iliyoundwa.'**
  String get financialAccountsEmptyMessage;

  /// No description provided for @financialAccountsSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta akaunti'**
  String get financialAccountsSearchHint;

  /// No description provided for @financialAccountNewAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Akaunti'**
  String get financialAccountNewAction;

  /// No description provided for @financialAccountNewTitle.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti Mpya ya Fedha'**
  String get financialAccountNewTitle;

  /// No description provided for @sectionFinancialAccountDetails.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Akaunti'**
  String get sectionFinancialAccountDetails;

  /// No description provided for @financialAccountEditTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Akaunti ya Fedha'**
  String get financialAccountEditTitle;

  /// No description provided for @financialAccountNameFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la Akaunti *'**
  String get financialAccountNameFieldLabel;

  /// No description provided for @financialAccountTypeFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Akaunti'**
  String get financialAccountTypeFieldLabel;

  /// No description provided for @financialAccountTypeCash.
  ///
  /// In sw, this message translates to:
  /// **'Taslimu'**
  String get financialAccountTypeCash;

  /// No description provided for @financialAccountTypeBank.
  ///
  /// In sw, this message translates to:
  /// **'Benki'**
  String get financialAccountTypeBank;

  /// No description provided for @financialAccountTypeMobileMoney.
  ///
  /// In sw, this message translates to:
  /// **'Pesa ya Simu'**
  String get financialAccountTypeMobileMoney;

  /// No description provided for @financialAccountOpeningBalanceFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Mwanzo (si lazima)'**
  String get financialAccountOpeningBalanceFieldLabel;

  /// No description provided for @financialAccountOpeningBalanceDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Salio la Mwanzo'**
  String get financialAccountOpeningBalanceDateLabel;

  /// No description provided for @financialAccountSavedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya fedha imehifadhiwa.'**
  String get financialAccountSavedMessage;

  /// No description provided for @financialAccountBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio'**
  String get financialAccountBalanceLabel;

  /// No description provided for @financialAccountActiveBadge.
  ///
  /// In sw, this message translates to:
  /// **'Inatumika'**
  String get financialAccountActiveBadge;

  /// No description provided for @financialAccountInactiveBadge.
  ///
  /// In sw, this message translates to:
  /// **'Haitumiki'**
  String get financialAccountInactiveBadge;

  /// No description provided for @financialAccountActivateAction.
  ///
  /// In sw, this message translates to:
  /// **'Washa Akaunti'**
  String get financialAccountActivateAction;

  /// No description provided for @financialAccountDeactivateAction.
  ///
  /// In sw, this message translates to:
  /// **'Zima Akaunti'**
  String get financialAccountDeactivateAction;

  /// No description provided for @financialAccountEditAction.
  ///
  /// In sw, this message translates to:
  /// **'Hariri'**
  String get financialAccountEditAction;

  /// No description provided for @financialAccountEntriesTitle.
  ///
  /// In sw, this message translates to:
  /// **'Miamala'**
  String get financialAccountEntriesTitle;

  /// No description provided for @financialAccountEntriesEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna miamala kwenye akaunti hii.'**
  String get financialAccountEntriesEmptyMessage;

  /// No description provided for @financialAccountEntryTypeInflow.
  ///
  /// In sw, this message translates to:
  /// **'Kuingia'**
  String get financialAccountEntryTypeInflow;

  /// No description provided for @financialAccountEntryTypeOutflow.
  ///
  /// In sw, this message translates to:
  /// **'Kutoka'**
  String get financialAccountEntryTypeOutflow;

  /// No description provided for @financialAccountEntryTypeTransferIn.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho Ulioingia'**
  String get financialAccountEntryTypeTransferIn;

  /// No description provided for @financialAccountEntryTypeTransferOut.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho Ulioondoka'**
  String get financialAccountEntryTypeTransferOut;

  /// No description provided for @financialAccountTransferAction.
  ///
  /// In sw, this message translates to:
  /// **'Hamisha Fedha'**
  String get financialAccountTransferAction;

  /// No description provided for @financialAccountTransferToLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho kwenda {accountName}'**
  String financialAccountTransferToLedgerLabel(Object accountName);

  /// No description provided for @financialAccountTransferFromLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho kutoka {accountName}'**
  String financialAccountTransferFromLedgerLabel(Object accountName);

  /// No description provided for @financialAccountTransferTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hamisha Fedha Kati ya Akaunti'**
  String get financialAccountTransferTitle;

  /// No description provided for @financialAccountTransferFromLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kutoka Akaunti'**
  String get financialAccountTransferFromLabel;

  /// No description provided for @financialAccountTransferToLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kwenda Akaunti'**
  String get financialAccountTransferToLabel;

  /// No description provided for @financialAccountTransferAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi *'**
  String get financialAccountTransferAmountLabel;

  /// No description provided for @financialAccountTransferDescriptionFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (si lazima)'**
  String get financialAccountTransferDescriptionFieldLabel;

  /// No description provided for @financialAccountTransferSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho umefanikiwa.'**
  String get financialAccountTransferSuccessMessage;

  /// No description provided for @financialAccountTransferSubmitAction.
  ///
  /// In sw, this message translates to:
  /// **'Hamisha'**
  String get financialAccountTransferSubmitAction;

  /// No description provided for @financialAccountErrorNameRequired.
  ///
  /// In sw, this message translates to:
  /// **'Jina la akaunti linahitajika.'**
  String get financialAccountErrorNameRequired;

  /// No description provided for @financialAccountErrorDuplicateName.
  ///
  /// In sw, this message translates to:
  /// **'Jina hilo la akaunti tayari linatumika kwenye kikundi hiki.'**
  String get financialAccountErrorDuplicateName;

  /// No description provided for @financialAccountErrorOpeningBalanceMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Salio la mwanzo lazima liwe zaidi ya sifuri.'**
  String get financialAccountErrorOpeningBalanceMustBePositive;

  /// No description provided for @financialAccountErrorNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya fedha haikupatikana.'**
  String get financialAccountErrorNotFound;

  /// No description provided for @financialAccountErrorTransferSameAccount.
  ///
  /// In sw, this message translates to:
  /// **'Haiwezekani kuhamisha fedha kwenye akaunti ile ile.'**
  String get financialAccountErrorTransferSameAccount;

  /// No description provided for @financialAccountErrorTransferAmountMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha kuhamisha lazima kiwe zaidi ya sifuri.'**
  String get financialAccountErrorTransferAmountMustBePositive;

  /// No description provided for @financialAccountErrorInsufficientBalance.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya kutoa haina salio la kutosha kwa uhamisho huu.'**
  String get financialAccountErrorInsufficientBalance;

  /// No description provided for @financialAccountErrorAccountInactive.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti hii ya fedha haitumiki.'**
  String get financialAccountErrorAccountInactive;

  /// No description provided for @financialAccountErrorEffectiveDateRequired.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya uhamisho inahitajika.'**
  String get financialAccountErrorEffectiveDateRequired;

  /// No description provided for @financialAccountErrorPermissionDenied.
  ///
  /// In sw, this message translates to:
  /// **'Huna ruhusa ya kufanya hivyo.'**
  String get financialAccountErrorPermissionDenied;

  /// No description provided for @financialAccountErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuunganisha. Jaribu tena.'**
  String get financialAccountErrorNetwork;

  /// No description provided for @financialAccountErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Jaribu tena.'**
  String get financialAccountErrorUnexpected;

  /// No description provided for @supabaseConfigMissing.
  ///
  /// In sw, this message translates to:
  /// **'Mipangilio ya Supabase haipo (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY haijawekwa).'**
  String get supabaseConfigMissing;

  /// No description provided for @backAction.
  ///
  /// In sw, this message translates to:
  /// **'Rudi'**
  String get backAction;

  /// No description provided for @doneAction.
  ///
  /// In sw, this message translates to:
  /// **'Imekamilika'**
  String get doneAction;

  /// No description provided for @paymentsEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Malipo'**
  String get paymentsEntryTitle;

  /// No description provided for @paymentsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Tazama historia ya malipo yote'**
  String get paymentsEntrySubtitle;

  /// No description provided for @recordPaymentEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Malipo'**
  String get recordPaymentEntryTitle;

  /// No description provided for @recordPaymentEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi malipo ya nje kutoka kwa mwanachama'**
  String get recordPaymentEntrySubtitle;

  /// No description provided for @memberWalletEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Mwanachama'**
  String get memberWalletEntryTitle;

  /// No description provided for @memberWalletEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Tazama na tumia salio la mwanachama'**
  String get memberWalletEntrySubtitle;

  /// No description provided for @paymentsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Malipo'**
  String get paymentsTitle;

  /// No description provided for @paymentsSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta malipo'**
  String get paymentsSearchHint;

  /// No description provided for @paymentsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Malipo'**
  String get paymentsEmptyTitle;

  /// No description provided for @paymentsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna malipo yaliyorekodiwa.'**
  String get paymentsEmptyMessage;

  /// No description provided for @recordPaymentAction.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Malipo'**
  String get recordPaymentAction;

  /// No description provided for @paymentMethodCash.
  ///
  /// In sw, this message translates to:
  /// **'Taslimu'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodBankTransfer.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho wa Benki'**
  String get paymentMethodBankTransfer;

  /// No description provided for @paymentMethodMobileMoney.
  ///
  /// In sw, this message translates to:
  /// **'Pesa za Simu'**
  String get paymentMethodMobileMoney;

  /// No description provided for @paymentMethodOther.
  ///
  /// In sw, this message translates to:
  /// **'Nyingine'**
  String get paymentMethodOther;

  /// No description provided for @paymentStatusPosted.
  ///
  /// In sw, this message translates to:
  /// **'Imerekodiwa'**
  String get paymentStatusPosted;

  /// No description provided for @paymentStatusReversed.
  ///
  /// In sw, this message translates to:
  /// **'Imebatilishwa'**
  String get paymentStatusReversed;

  /// No description provided for @walletEntryTypePaymentCredit.
  ///
  /// In sw, this message translates to:
  /// **'Salio Lililoongezwa'**
  String get walletEntryTypePaymentCredit;

  /// No description provided for @walletEntryTypeAllocationDebit.
  ///
  /// In sw, this message translates to:
  /// **'Salio Lililotumika'**
  String get walletEntryTypeAllocationDebit;

  /// No description provided for @walletEntryTypeReversal.
  ///
  /// In sw, this message translates to:
  /// **'Kubatilishwa'**
  String get walletEntryTypeReversal;

  /// No description provided for @memberPickerSearchHint.
  ///
  /// In sw, this message translates to:
  /// **'Tafuta mwanachama'**
  String get memberPickerSearchHint;

  /// No description provided for @memberPickerEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Mwanachama'**
  String get memberPickerEmptyTitle;

  /// No description provided for @memberPickerEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna mwanachama aliyepatikana kwa utafutaji huu.'**
  String get memberPickerEmptyMessage;

  /// No description provided for @paymentAmountInvalidError.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi sahihi, mwanachama, na akaunti ya fedha.'**
  String get paymentAmountInvalidError;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Malipo'**
  String get recordPaymentTitle;

  /// No description provided for @recordPaymentAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi *'**
  String get recordPaymentAmountLabel;

  /// No description provided for @recordPaymentDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe'**
  String get recordPaymentDateLabel;

  /// No description provided for @recordPaymentMethodLabel.
  ///
  /// In sw, this message translates to:
  /// **'Njia ya Malipo'**
  String get recordPaymentMethodLabel;

  /// No description provided for @recordPaymentAccountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya Fedha'**
  String get recordPaymentAccountLabel;

  /// No description provided for @recordPaymentReferenceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kumbukumbu ya Nje (si lazima)'**
  String get recordPaymentReferenceLabel;

  /// No description provided for @recordPaymentNotesLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (si lazima)'**
  String get recordPaymentNotesLabel;

  /// No description provided for @recordPaymentPreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesha Mgawanyo'**
  String get recordPaymentPreviewAction;

  /// No description provided for @recordPaymentConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Malipo'**
  String get recordPaymentConfirmAction;

  /// No description provided for @recordPaymentSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Malipo yamerekodiwa kikamilifu.'**
  String get recordPaymentSuccessMessage;

  /// No description provided for @paymentPreviewAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha Malipo'**
  String get paymentPreviewAmountLabel;

  /// No description provided for @paymentPreviewWillSettleLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mgawanyo wa Malipo'**
  String get paymentPreviewWillSettleLabel;

  /// No description provided for @paymentPreviewNoOutstandingMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna deni lililobaki la kulipa.'**
  String get paymentPreviewNoOutstandingMessage;

  /// No description provided for @paymentPreviewTotalAllocatedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kinalipa Madeni'**
  String get paymentPreviewTotalAllocatedLabel;

  /// No description provided for @paymentPreviewWalletRemainingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio Litakalobaki'**
  String get paymentPreviewWalletRemainingLabel;

  /// No description provided for @paymentPreviewAccountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya Fedha Itakayopokea'**
  String get paymentPreviewAccountLabel;

  /// No description provided for @viewReceiptAction.
  ///
  /// In sw, this message translates to:
  /// **'Tazama Risiti'**
  String get viewReceiptAction;

  /// No description provided for @receiptTitle.
  ///
  /// In sw, this message translates to:
  /// **'Risiti'**
  String get receiptTitle;

  /// No description provided for @receiptMemberLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama'**
  String get receiptMemberLabel;

  /// No description provided for @paymentDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Malipo'**
  String get paymentDetailTitle;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get paymentAmountLabel;

  /// No description provided for @paymentAllocationsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mgawanyo wa Malipo'**
  String get paymentAllocationsTitle;

  /// No description provided for @reversalReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya Kubatilisha *'**
  String get reversalReasonLabel;

  /// No description provided for @reversePaymentAction.
  ///
  /// In sw, this message translates to:
  /// **'Batili Malipo'**
  String get reversePaymentAction;

  /// No description provided for @reversePaymentTitle.
  ///
  /// In sw, this message translates to:
  /// **'Batili Malipo'**
  String get reversePaymentTitle;

  /// No description provided for @reversePaymentWarningMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kitendo hiki hakiwezi kutenduliwa. Malipo asilia yatabaki kwenye kumbukumbu, lakini deni litarudi kuwa halijalipwa.'**
  String get reversePaymentWarningMessage;

  /// No description provided for @reversePaymentConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Kubatilisha'**
  String get reversePaymentConfirmAction;

  /// No description provided for @reversePaymentSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Malipo yamebatilishwa.'**
  String get reversePaymentSuccessMessage;

  /// No description provided for @memberWalletTitle.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Mwanachama'**
  String get memberWalletTitle;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Sasa'**
  String get walletBalanceLabel;

  /// No description provided for @walletHistoryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Historia ya Salio'**
  String get walletHistoryTitle;

  /// No description provided for @walletHistoryEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna historia ya salio.'**
  String get walletHistoryEmptyMessage;

  /// No description provided for @allocateWalletAction.
  ///
  /// In sw, this message translates to:
  /// **'Tumia Salio'**
  String get allocateWalletAction;

  /// No description provided for @allocateWalletTitle.
  ///
  /// In sw, this message translates to:
  /// **'Tumia Salio la Mwanachama'**
  String get allocateWalletTitle;

  /// No description provided for @allocateWalletSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Salio limetumika kulipa deni.'**
  String get allocateWalletSuccessMessage;

  /// No description provided for @paymentErrorAmountMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi lazima kiwe zaidi ya sifuri.'**
  String get paymentErrorAmountMustBePositive;

  /// No description provided for @paymentErrorFinancialAccountInactive.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti hii ya fedha haifanyi kazi.'**
  String get paymentErrorFinancialAccountInactive;

  /// No description provided for @paymentErrorIdempotencyKeyConflict.
  ///
  /// In sw, this message translates to:
  /// **'Ombi hili linagongana na lililotangulia. Tafadhali onyesha upya na ujaribu tena.'**
  String get paymentErrorIdempotencyKeyConflict;

  /// No description provided for @paymentErrorAlreadyReversed.
  ///
  /// In sw, this message translates to:
  /// **'Malipo haya tayari yamebatilishwa.'**
  String get paymentErrorAlreadyReversed;

  /// No description provided for @paymentErrorReversalBlockedWalletCreditConsumed.
  ///
  /// In sw, this message translates to:
  /// **'Malipo haya hayawezi kubatilishwa: salio la mwanachama lililoongezwa tayari limetumika.'**
  String get paymentErrorReversalBlockedWalletCreditConsumed;

  /// No description provided for @paymentErrorReversalReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kubatilisha inahitajika.'**
  String get paymentErrorReversalReasonRequired;

  /// No description provided for @paymentErrorWalletInsufficientBalance.
  ///
  /// In sw, this message translates to:
  /// **'Salio la mwanachama halitoshi kwa mgawanyo huu.'**
  String get paymentErrorWalletInsufficientBalance;

  /// No description provided for @paymentErrorWalletNothingToAllocate.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna deni lililobaki la kutumia salio hili dhidi yake.'**
  String get paymentErrorWalletNothingToAllocate;

  /// No description provided for @paymentErrorNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Haipatikani.'**
  String get paymentErrorNotFound;

  /// No description provided for @paymentErrorPermissionDenied.
  ///
  /// In sw, this message translates to:
  /// **'Huna ruhusa ya kufanya hivyo.'**
  String get paymentErrorPermissionDenied;

  /// No description provided for @paymentErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Imeshindikana kuunganisha. Jaribu tena.'**
  String get paymentErrorNetwork;

  /// No description provided for @paymentErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Jaribu tena.'**
  String get paymentErrorUnexpected;

  /// No description provided for @paymentSummaryOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni Lililobaki'**
  String get paymentSummaryOutstandingLabel;

  /// No description provided for @outstandingObligationsSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Madeni Yaliyobaki'**
  String get outstandingObligationsSectionTitle;

  /// No description provided for @outstandingObligationsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama hana deni lililobaki.'**
  String get outstandingObligationsEmptyMessage;

  /// No description provided for @viewAllObligationsAction.
  ///
  /// In sw, this message translates to:
  /// **'Angalia Yote'**
  String get viewAllObligationsAction;
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
