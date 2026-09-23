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

  /// No description provided for @modulesSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Huduma'**
  String get modulesSectionTitle;

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
  /// **'Angalia Madeni'**
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
  /// **'Ongeza'**
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

  /// No description provided for @financialAccountErrorAmountMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi lazima kiwe zaidi ya sifuri.'**
  String get financialAccountErrorAmountMustBePositive;

  /// No description provided for @financialAccountErrorCategoryWrongType.
  ///
  /// In sw, this message translates to:
  /// **'Kategoria hiyo haiwezi kutumika kwa aina hii ya kiingilio.'**
  String get financialAccountErrorCategoryWrongType;

  /// No description provided for @financialAccountErrorCategoryInactive.
  ///
  /// In sw, this message translates to:
  /// **'Kategoria hii haifanyi kazi tena.'**
  String get financialAccountErrorCategoryInactive;

  /// No description provided for @financialAccountErrorIdempotencyKeyConflict.
  ///
  /// In sw, this message translates to:
  /// **'Ombi hili linagongana na lililotangulia. Tafadhali onyesha upya na ujaribu tena.'**
  String get financialAccountErrorIdempotencyKeyConflict;

  /// No description provided for @financialAccountErrorReversalReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kubatilisha inahitajika.'**
  String get financialAccountErrorReversalReasonRequired;

  /// No description provided for @financialAccountErrorEntryAlreadyReversed.
  ///
  /// In sw, this message translates to:
  /// **'Kiingilio hiki tayari kimebatilishwa.'**
  String get financialAccountErrorEntryAlreadyReversed;

  /// No description provided for @financialAccountErrorAdjustmentReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu inahitajika.'**
  String get financialAccountErrorAdjustmentReasonRequired;

  /// No description provided for @financialAccountErrorReconciliationCancellationReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kufuta inahitajika.'**
  String get financialAccountErrorReconciliationCancellationReasonRequired;

  /// No description provided for @financialAccountErrorReconciliationAlreadyCancelled.
  ///
  /// In sw, this message translates to:
  /// **'Ulinganishaji huu tayari umefutwa.'**
  String get financialAccountErrorReconciliationAlreadyCancelled;

  /// No description provided for @financialAccountPaymentLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo ya Mwanachama — Risiti {receiptNumber}'**
  String financialAccountPaymentLedgerLabel(String receiptNumber);

  /// No description provided for @financialAccountPaymentReversalLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yamebatilishwa — Risiti {receiptNumber}'**
  String financialAccountPaymentReversalLedgerLabel(String receiptNumber);

  /// No description provided for @financialAccountManualIncomeLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato — {category}'**
  String financialAccountManualIncomeLedgerLabel(String category);

  /// No description provided for @financialAccountExpenseLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi — {category}'**
  String financialAccountExpenseLedgerLabel(String category);

  /// No description provided for @financialAccountManualIncomeReversalLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato Yamerekebishwa — {category}'**
  String financialAccountManualIncomeReversalLedgerLabel(String category);

  /// No description provided for @financialAccountExpenseReversalLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi Yamerekebishwa — {category}'**
  String financialAccountExpenseReversalLedgerLabel(String category);

  /// No description provided for @financialAccountAdjustmentLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho ya Fedha — {reason}'**
  String financialAccountAdjustmentLedgerLabel(String reason);

  /// No description provided for @financeTitle.
  ///
  /// In sw, this message translates to:
  /// **'Fedha'**
  String get financeTitle;

  /// No description provided for @financeAccountsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia akaunti za fedha taslimu, benki, na simu'**
  String get financeAccountsEntrySubtitle;

  /// No description provided for @financialPositionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hali ya Fedha'**
  String get financialPositionTitle;

  /// No description provided for @financialPositionEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Mapato, matumizi, na mahali fedha za kikundi zilipo'**
  String get financialPositionEntrySubtitle;

  /// No description provided for @financialPositionPickRangeAction.
  ///
  /// In sw, this message translates to:
  /// **'Chagua Kipindi'**
  String get financialPositionPickRangeAction;

  /// No description provided for @financialPositionClearRangeAction.
  ///
  /// In sw, this message translates to:
  /// **'Futa'**
  String get financialPositionClearRangeAction;

  /// No description provided for @financialPositionTotalBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Fedha'**
  String get financialPositionTotalBalanceLabel;

  /// No description provided for @financialPositionIncomeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato'**
  String get financialPositionIncomeLabel;

  /// No description provided for @financialPositionExpenseLabel.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi'**
  String get financialPositionExpenseLabel;

  /// No description provided for @financialPositionNetResultLabel.
  ///
  /// In sw, this message translates to:
  /// **'Matokeo Halisi'**
  String get financialPositionNetResultLabel;

  /// No description provided for @financialPositionAccountsSectionTitle.
  ///
  /// In sw, this message translates to:
  /// **'Fedha kwa Akaunti'**
  String get financialPositionAccountsSectionTitle;

  /// No description provided for @financialPositionNoAccountsMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna akaunti za fedha bado.'**
  String get financialPositionNoAccountsMessage;

  /// No description provided for @financialPositionOtherClassificationsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Uainishaji Mwingine'**
  String get financialPositionOtherClassificationsTitle;

  /// No description provided for @financialPositionPassThroughLabel.
  ///
  /// In sw, this message translates to:
  /// **'Fedha Zisizo Pato la Kikundi'**
  String get financialPositionPassThroughLabel;

  /// No description provided for @financialPositionShareCapitalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Hisa Uliopokelewa'**
  String get financialPositionShareCapitalLabel;

  /// No description provided for @financialPositionWalletLiabilityLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Salio la Wanachama'**
  String get financialPositionWalletLiabilityLabel;

  /// No description provided for @financialPositionOutstandingObligationsLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Wanachama Lililobaki'**
  String get financialPositionOutstandingObligationsLabel;

  /// No description provided for @recordIncomeTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Mapato'**
  String get recordIncomeTitle;

  /// No description provided for @recordExpenseTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Matumizi'**
  String get recordExpenseTitle;

  /// No description provided for @recordIncomeAction.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Mapato'**
  String get recordIncomeAction;

  /// No description provided for @recordExpenseAction.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi Matumizi'**
  String get recordExpenseAction;

  /// No description provided for @recordIncomeConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Mapato'**
  String get recordIncomeConfirmAction;

  /// No description provided for @recordExpenseConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Matumizi'**
  String get recordExpenseConfirmAction;

  /// No description provided for @manualEntryValidationError.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi sahihi na chagua kategoria.'**
  String get manualEntryValidationError;

  /// No description provided for @manualEntryAmountRequiredError.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi sahihi.'**
  String get manualEntryAmountRequiredError;

  /// No description provided for @manualEntryCategoryRequiredError.
  ///
  /// In sw, this message translates to:
  /// **'Chagua kategoria.'**
  String get manualEntryCategoryRequiredError;

  /// No description provided for @referenceDisplayLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kumbukumbu'**
  String get referenceDisplayLabel;

  /// No description provided for @manualEntryNoIncomeCategoriesMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna kategoria za mapato zilizowekwa kwa kikundi hiki.'**
  String get manualEntryNoIncomeCategoriesMessage;

  /// No description provided for @manualEntryNoExpenseCategoriesMessage.
  ///
  /// In sw, this message translates to:
  /// **'Bado hakuna kategoria za matumizi zilizowekwa kwa kikundi hiki.'**
  String get manualEntryNoExpenseCategoriesMessage;

  /// No description provided for @manualEntryManageCategoriesAction.
  ///
  /// In sw, this message translates to:
  /// **'Simamia Kategoria'**
  String get manualEntryManageCategoriesAction;

  /// No description provided for @financeCategoriesEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza na simamia kategoria za mapato/matumizi'**
  String get financeCategoriesEntrySubtitle;

  /// No description provided for @recordIncomeSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mapato yamerekodiwa.'**
  String get recordIncomeSuccessMessage;

  /// No description provided for @recordExpenseSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi yamerekodiwa.'**
  String get recordExpenseSuccessMessage;

  /// No description provided for @incomeCategoryFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Mapato'**
  String get incomeCategoryFieldLabel;

  /// No description provided for @expenseCategoryFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Matumizi'**
  String get expenseCategoryFieldLabel;

  /// No description provided for @amountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get amountFieldLabel;

  /// No description provided for @effectiveDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe'**
  String get effectiveDateFieldLabel;

  /// No description provided for @descriptionFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo'**
  String get descriptionFieldLabel;

  /// No description provided for @referenceFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kumbukumbu (hiari)'**
  String get referenceFieldLabel;

  /// No description provided for @financialCategoriesTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kategoria za Fedha'**
  String get financialCategoriesTitle;

  /// No description provided for @financialCategoryTypeIncome.
  ///
  /// In sw, this message translates to:
  /// **'Mapato'**
  String get financialCategoryTypeIncome;

  /// No description provided for @financialCategoryTypeExpense.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi'**
  String get financialCategoryTypeExpense;

  /// No description provided for @addCategoryAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Kategoria'**
  String get addCategoryAction;

  /// No description provided for @categoryNameFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina la Kategoria'**
  String get categoryNameFieldLabel;

  /// No description provided for @seedDefaultCategoriesAction.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza Kategoria za Kawaida'**
  String get seedDefaultCategoriesAction;

  /// No description provided for @cashbookTitle.
  ///
  /// In sw, this message translates to:
  /// **'Miamala ya Fedha'**
  String get cashbookTitle;

  /// No description provided for @cashbookFilterPayments.
  ///
  /// In sw, this message translates to:
  /// **'Malipo'**
  String get cashbookFilterPayments;

  /// No description provided for @cashbookFilterIncome.
  ///
  /// In sw, this message translates to:
  /// **'Mapato'**
  String get cashbookFilterIncome;

  /// No description provided for @cashbookFilterExpense.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi'**
  String get cashbookFilterExpense;

  /// No description provided for @cashbookFilterTransfers.
  ///
  /// In sw, this message translates to:
  /// **'Uhamisho'**
  String get cashbookFilterTransfers;

  /// No description provided for @cashbookFilterAdjustments.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho'**
  String get cashbookFilterAdjustments;

  /// No description provided for @cashbookEntryReversedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Imerekebishwa'**
  String get cashbookEntryReversedLabel;

  /// No description provided for @viewCashbookAction.
  ///
  /// In sw, this message translates to:
  /// **'Angalia Miamala'**
  String get viewCashbookAction;

  /// No description provided for @reconciliationTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ulinganishaji wa Akaunti'**
  String get reconciliationTitle;

  /// No description provided for @reconciliationAction.
  ///
  /// In sw, this message translates to:
  /// **'Linganisha'**
  String get reconciliationAction;

  /// No description provided for @systemBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Mfumo'**
  String get systemBalanceLabel;

  /// No description provided for @statementBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Taarifa'**
  String get statementBalanceLabel;

  /// No description provided for @differenceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tofauti'**
  String get differenceLabel;

  /// No description provided for @reconciliationDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Ulinganishaji'**
  String get reconciliationDateLabel;

  /// No description provided for @reconciliationNotesLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (hiari)'**
  String get reconciliationNotesLabel;

  /// No description provided for @reconciliationSaveAction.
  ///
  /// In sw, this message translates to:
  /// **'Hifadhi Ulinganishaji'**
  String get reconciliationSaveAction;

  /// No description provided for @reconciliationBalancedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Imelingana'**
  String get reconciliationBalancedMessage;

  /// No description provided for @reconciliationDiscrepancyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tofauti Imepatikana'**
  String get reconciliationDiscrepancyLabel;

  /// No description provided for @reconciliationHistoryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Historia ya Ulinganishaji'**
  String get reconciliationHistoryTitle;

  /// No description provided for @reconciliationHistoryEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna ulinganishaji uliorekodiwa bado.'**
  String get reconciliationHistoryEmptyMessage;

  /// No description provided for @reconciliationCancelledLabel.
  ///
  /// In sw, this message translates to:
  /// **'Imefutwa'**
  String get reconciliationCancelledLabel;

  /// No description provided for @lastReconciledLabel.
  ///
  /// In sw, this message translates to:
  /// **'Ulinganishaji wa Mwisho'**
  String get lastReconciledLabel;

  /// No description provided for @cancelReconciliationConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Futa Ulinganishaji?'**
  String get cancelReconciliationConfirmTitle;

  /// No description provided for @cancelReconciliationConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi hii ya ulinganishaji itawekwa alama imefutwa. Ushahidi wa asili unabaki, hauandikwi upya.'**
  String get cancelReconciliationConfirmMessage;

  /// No description provided for @cancelReconciliationConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Futa Ulinganishaji'**
  String get cancelReconciliationConfirmAction;

  /// No description provided for @cancelReconciliationDefaultReason.
  ///
  /// In sw, this message translates to:
  /// **'Imefutwa na mtumiaji'**
  String get cancelReconciliationDefaultReason;

  /// No description provided for @financialAdjustmentTitle.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho ya Fedha'**
  String get financialAdjustmentTitle;

  /// No description provided for @financialAdjustmentAction.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho ya Fedha'**
  String get financialAdjustmentAction;

  /// No description provided for @financialAdjustmentConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Marekebisho'**
  String get financialAdjustmentConfirmAction;

  /// No description provided for @financialAdjustmentSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho ya fedha yamerekodiwa.'**
  String get financialAdjustmentSuccessMessage;

  /// No description provided for @financialAdjustmentReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu'**
  String get financialAdjustmentReasonFieldLabel;

  /// No description provided for @adjustmentDecreaseOption.
  ///
  /// In sw, this message translates to:
  /// **'Punguza'**
  String get adjustmentDecreaseOption;

  /// No description provided for @entryReversalTitle.
  ///
  /// In sw, this message translates to:
  /// **'Batilisha Kiingilio'**
  String get entryReversalTitle;

  /// No description provided for @entryReversalConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Kubatilisha'**
  String get entryReversalConfirmAction;

  /// No description provided for @entryReversalSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kiingilio kimebatilishwa.'**
  String get entryReversalSuccessMessage;

  /// No description provided for @entryAlreadyReversedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Kiingilio hiki tayari kimebatilishwa.'**
  String get entryAlreadyReversedMessage;

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

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Historia ya Malipo'**
  String get paymentHistoryTitle;

  /// No description provided for @receiptsEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Risiti'**
  String get receiptsEntryTitle;

  /// No description provided for @receiptsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Tazama na chapisha risiti za malipo'**
  String get receiptsEntrySubtitle;

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
  /// **'Salio kutoka malipo'**
  String get walletEntryTypePaymentCredit;

  /// No description provided for @walletEntryTypeAllocationDebit.
  ///
  /// In sw, this message translates to:
  /// **'Salio limetumika kulipa deni'**
  String get walletEntryTypeAllocationDebit;

  /// No description provided for @walletEntryTypeReversal.
  ///
  /// In sw, this message translates to:
  /// **'Salio limerudishwa'**
  String get walletEntryTypeReversal;

  /// No description provided for @walletEntrySourceReceiptLabel.
  ///
  /// In sw, this message translates to:
  /// **'Risiti {receiptNumber}'**
  String walletEntrySourceReceiptLabel(Object receiptNumber);

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

  /// No description provided for @paymentErrorReversalBlockedSubsequentActivity.
  ///
  /// In sw, this message translates to:
  /// **'Haiwezekani kubatilisha malipo haya. Kuna shughuli nyingine ya mkopo iliyofanyika baada ya malipo haya — kuyabatilisha kunaweza kuharibu ratiba ya sasa ya malipo ya mkopo.'**
  String get paymentErrorReversalBlockedSubsequentActivity;

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

  /// No description provided for @paymentSummaryContributionsSectionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Michango'**
  String get paymentSummaryContributionsSectionLabel;

  /// No description provided for @paymentSummaryLoansSectionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mikopo'**
  String get paymentSummaryLoansSectionLabel;

  /// No description provided for @paymentSummaryDueNowLabel.
  ///
  /// In sw, this message translates to:
  /// **'Inadaiwa Sasa'**
  String get paymentSummaryDueNowLabel;

  /// No description provided for @paymentSummaryOverdueLabel.
  ///
  /// In sw, this message translates to:
  /// **'Imechelewa'**
  String get paymentSummaryOverdueLabel;

  /// No description provided for @paymentSummaryTotalPayableNowLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla Inayolipwa Sasa'**
  String get paymentSummaryTotalPayableNowLabel;

  /// No description provided for @paymentSummaryUpcomingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Zijazo (Bado Hazijafika)'**
  String get paymentSummaryUpcomingLabel;

  /// No description provided for @paymentSummaryNoActiveLoansMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama hana mkopo unaoendelea.'**
  String get paymentSummaryNoActiveLoansMessage;

  /// No description provided for @sectionCharges.
  ///
  /// In sw, this message translates to:
  /// **'Madeni'**
  String get sectionCharges;

  /// No description provided for @memberChargesTitle.
  ///
  /// In sw, this message translates to:
  /// **'Madeni'**
  String get memberChargesTitle;

  /// No description provided for @memberChargesTotalAllocatedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yaliyogawiwa'**
  String get memberChargesTotalAllocatedLabel;

  /// No description provided for @memberChargesEmptyOutstandingMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna deni lililobaki.'**
  String get memberChargesEmptyOutstandingMessage;

  /// No description provided for @memberChargesEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna madeni yanayolingana na kichujio hiki.'**
  String get memberChargesEmptyMessage;

  /// No description provided for @filterOutstanding.
  ///
  /// In sw, this message translates to:
  /// **'Deni Lililobaki'**
  String get filterOutstanding;

  /// No description provided for @filterSettled.
  ///
  /// In sw, this message translates to:
  /// **'Imelipwa'**
  String get filterSettled;

  /// No description provided for @filterOverdue.
  ///
  /// In sw, this message translates to:
  /// **'Imechelewa'**
  String get filterOverdue;

  /// No description provided for @chargeOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni Lililobaki'**
  String get chargeOutstandingLabel;

  /// No description provided for @loansTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mikopo'**
  String get loansTitle;

  /// No description provided for @homeLoansShortcutSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Aina za mikopo na akaunti za mikopo'**
  String get homeLoansShortcutSubtitle;

  /// No description provided for @homePaymentsShortcutSubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekodi malipo, historia, risiti na salio la mwanachama'**
  String get homePaymentsShortcutSubtitle;

  /// No description provided for @loanAccountsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti za Mikopo'**
  String get loanAccountsTitle;

  /// No description provided for @loanAccountsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Angalia na tengeneza mikopo ya wanachama'**
  String get loanAccountsEntrySubtitle;

  /// No description provided for @loanProductsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Aina za Mikopo'**
  String get loanProductsTitle;

  /// No description provided for @loanProductsEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Simamia sera za mikopo za kikundi'**
  String get loanProductsEntrySubtitle;

  /// No description provided for @loanProductNewAction.
  ///
  /// In sw, this message translates to:
  /// **'Aina Mpya ya Mkopo'**
  String get loanProductNewAction;

  /// No description provided for @loanProductActiveBadge.
  ///
  /// In sw, this message translates to:
  /// **'Inatumika'**
  String get loanProductActiveBadge;

  /// No description provided for @loanProductInactiveBadge.
  ///
  /// In sw, this message translates to:
  /// **'Haitumiki'**
  String get loanProductInactiveBadge;

  /// No description provided for @loanProductsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Aina za Mikopo'**
  String get loanProductsEmptyTitle;

  /// No description provided for @loanProductsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna aina za mikopo zilizowekwa kwa kikundi hiki bado.'**
  String get loanProductsEmptyMessage;

  /// No description provided for @loanProductEditTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Aina ya Mkopo'**
  String get loanProductEditTitle;

  /// No description provided for @loanProductNewTitle.
  ///
  /// In sw, this message translates to:
  /// **'Aina Mpya ya Mkopo'**
  String get loanProductNewTitle;

  /// No description provided for @sectionLoanProductDetails.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Aina ya Mkopo'**
  String get sectionLoanProductDetails;

  /// No description provided for @loanProductCodeFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Msimbo'**
  String get loanProductCodeFieldLabel;

  /// No description provided for @loanProductNameFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jina'**
  String get loanProductNameFieldLabel;

  /// No description provided for @loanProductDescriptionFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (hiari)'**
  String get loanProductDescriptionFieldLabel;

  /// No description provided for @sectionLoanProductTerms.
  ///
  /// In sw, this message translates to:
  /// **'Masharti ya Mkopo'**
  String get sectionLoanProductTerms;

  /// No description provided for @loanProductMinimumPrincipalFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Chini cha Mkopo'**
  String get loanProductMinimumPrincipalFieldLabel;

  /// No description provided for @loanProductMaximumPrincipalFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Juu cha Mkopo (hiari)'**
  String get loanProductMaximumPrincipalFieldLabel;

  /// No description provided for @loanProductMinimumTermFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Muda wa Chini (miezi)'**
  String get loanProductMinimumTermFieldLabel;

  /// No description provided for @loanProductMaximumTermFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Muda wa Juu (miezi)'**
  String get loanProductMaximumTermFieldLabel;

  /// No description provided for @loanProductInterestRateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Riba (%)'**
  String get loanProductInterestRateFieldLabel;

  /// No description provided for @loanProductInterestRateBasisFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Msingi wa Riba'**
  String get loanProductInterestRateBasisFieldLabel;

  /// No description provided for @loanProductInterestMethodFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Njia ya Riba'**
  String get loanProductInterestMethodFieldLabel;

  /// No description provided for @loanInterestRateBasisMonthly.
  ///
  /// In sw, this message translates to:
  /// **'Kila Mwezi'**
  String get loanInterestRateBasisMonthly;

  /// No description provided for @loanInterestRateBasisAnnual.
  ///
  /// In sw, this message translates to:
  /// **'Kila Mwaka'**
  String get loanInterestRateBasisAnnual;

  /// No description provided for @loanInterestMethodFlat.
  ///
  /// In sw, this message translates to:
  /// **'Riba Tambarare'**
  String get loanInterestMethodFlat;

  /// No description provided for @loanInterestMethodReducingBalance.
  ///
  /// In sw, this message translates to:
  /// **'Riba Inayopungua'**
  String get loanInterestMethodReducingBalance;

  /// No description provided for @sectionLoanProductPenalty.
  ///
  /// In sw, this message translates to:
  /// **'Sera ya Adhabu'**
  String get sectionLoanProductPenalty;

  /// No description provided for @loanProductPenaltyEnabledFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Wezesha Adhabu'**
  String get loanProductPenaltyEnabledFieldLabel;

  /// No description provided for @loanProductPenaltyTypeFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Adhabu'**
  String get loanProductPenaltyTypeFieldLabel;

  /// No description provided for @loanProductPenaltyFrequencyFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Marudio ya Adhabu'**
  String get loanProductPenaltyFrequencyFieldLabel;

  /// No description provided for @loanProductPenaltyGraceDaysFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Siku za Msamaha'**
  String get loanProductPenaltyGraceDaysFieldLabel;

  /// No description provided for @loanProductPenaltyFixedAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Maalum cha Adhabu'**
  String get loanProductPenaltyFixedAmountFieldLabel;

  /// No description provided for @loanProductPenaltyRateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha Adhabu (%)'**
  String get loanProductPenaltyRateFieldLabel;

  /// No description provided for @loanPenaltyTypeFixed.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Maalum'**
  String get loanPenaltyTypeFixed;

  /// No description provided for @loanPenaltyTypePercentage.
  ///
  /// In sw, this message translates to:
  /// **'Asilimia'**
  String get loanPenaltyTypePercentage;

  /// No description provided for @loanPenaltyFrequencyOnce.
  ///
  /// In sw, this message translates to:
  /// **'Mara Moja'**
  String get loanPenaltyFrequencyOnce;

  /// No description provided for @loanPenaltyFrequencyRecurringMonthly.
  ///
  /// In sw, this message translates to:
  /// **'Kila Mwezi'**
  String get loanPenaltyFrequencyRecurringMonthly;

  /// No description provided for @loanPenaltyPolicyDescriptionFixedOnce.
  ///
  /// In sw, this message translates to:
  /// **'TSh {amount} baada ya siku {graceDays} za msamaha, hukadiriwa mara moja.'**
  String loanPenaltyPolicyDescriptionFixedOnce(String amount, int graceDays);

  /// No description provided for @loanPenaltyPolicyDescriptionFixedRecurring.
  ///
  /// In sw, this message translates to:
  /// **'TSh {amount} baada ya siku {graceDays} za msamaha, hukadiriwa kila mwezi ikiwa bado imechelewa.'**
  String loanPenaltyPolicyDescriptionFixedRecurring(
    String amount,
    int graceDays,
  );

  /// No description provided for @loanPenaltyPolicyDescriptionPercentageOnce.
  ///
  /// In sw, this message translates to:
  /// **'Asilimia {rate} ya salio la awamu lililobaki baada ya siku {graceDays} za msamaha, hukadiriwa mara moja.'**
  String loanPenaltyPolicyDescriptionPercentageOnce(String rate, int graceDays);

  /// No description provided for @loanPenaltyPolicyDescriptionPercentageRecurring.
  ///
  /// In sw, this message translates to:
  /// **'Asilimia {rate} ya salio la awamu lililobaki baada ya siku {graceDays} za msamaha, hukadiriwa kila mwezi ikiwa bado imechelewa.'**
  String loanPenaltyPolicyDescriptionPercentageRecurring(
    String rate,
    int graceDays,
  );

  /// No description provided for @loanPenaltyPolicyDisabledLabel.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna sera ya adhabu'**
  String get loanPenaltyPolicyDisabledLabel;

  /// No description provided for @loanPenaltySnapshotTitle.
  ///
  /// In sw, this message translates to:
  /// **'Masharti ya Adhabu'**
  String get loanPenaltySnapshotTitle;

  /// No description provided for @loanStatusDraft.
  ///
  /// In sw, this message translates to:
  /// **'Rasimu'**
  String get loanStatusDraft;

  /// No description provided for @loanStatusSubmitted.
  ///
  /// In sw, this message translates to:
  /// **'Imewasilishwa'**
  String get loanStatusSubmitted;

  /// No description provided for @loanStatusApproved.
  ///
  /// In sw, this message translates to:
  /// **'Imeidhinishwa'**
  String get loanStatusApproved;

  /// No description provided for @loanStatusRejected.
  ///
  /// In sw, this message translates to:
  /// **'Imekataliwa'**
  String get loanStatusRejected;

  /// No description provided for @loanStatusCancelled.
  ///
  /// In sw, this message translates to:
  /// **'Imeghairiwa'**
  String get loanStatusCancelled;

  /// No description provided for @loanStatusDisbursed.
  ///
  /// In sw, this message translates to:
  /// **'Imetolewa'**
  String get loanStatusDisbursed;

  /// No description provided for @loanStatusActive.
  ///
  /// In sw, this message translates to:
  /// **'Inaendelea'**
  String get loanStatusActive;

  /// No description provided for @loanStatusClosed.
  ///
  /// In sw, this message translates to:
  /// **'Imefungwa'**
  String get loanStatusClosed;

  /// No description provided for @newLoanAction.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo Mpya'**
  String get newLoanAction;

  /// No description provided for @loanAccountsEmptyTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna Mikopo'**
  String get loanAccountsEmptyTitle;

  /// No description provided for @loanAccountsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna akaunti za mikopo zilizotengenezwa bado.'**
  String get loanAccountsEmptyMessage;

  /// No description provided for @newLoanTitle.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo Mpya'**
  String get newLoanTitle;

  /// No description provided for @newLoanFormValidationError.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi sahihi cha mkopo na muda.'**
  String get newLoanFormValidationError;

  /// No description provided for @loanAccountPrincipalFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha Mkopo'**
  String get loanAccountPrincipalFieldLabel;

  /// No description provided for @loanAccountTermFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Muda (miezi)'**
  String get loanAccountTermFieldLabel;

  /// No description provided for @loanAccountFirstRepaymentDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Kwanza ya Kulipa'**
  String get loanAccountFirstRepaymentDateFieldLabel;

  /// No description provided for @loanSchedulePreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesha Ratiba'**
  String get loanSchedulePreviewAction;

  /// No description provided for @loanScheduleTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba ya Marejesho'**
  String get loanScheduleTitle;

  /// No description provided for @loanInstallmentNumberLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu {number}'**
  String loanInstallmentNumberLabel(int number);

  /// No description provided for @loanTotalInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Riba'**
  String get loanTotalInterestLabel;

  /// No description provided for @loanTotalRepayableLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Kulipwa'**
  String get loanTotalRepayableLabel;

  /// No description provided for @loanSaveDraftAction.
  ///
  /// In sw, this message translates to:
  /// **'Hifadhi Rasimu'**
  String get loanSaveDraftAction;

  /// No description provided for @loanDraftSavedMessage.
  ///
  /// In sw, this message translates to:
  /// **'Rasimu ya mkopo imehifadhiwa.'**
  String get loanDraftSavedMessage;

  /// No description provided for @loanAccountDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Mkopo'**
  String get loanAccountDetailTitle;

  /// No description provided for @loanCancelDraftConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi Rasimu ya Mkopo?'**
  String get loanCancelDraftConfirmTitle;

  /// No description provided for @loanCancelDraftConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Rasimu hii ya mkopo itaghairiwa. Hatua hii haiwezi kutenduliwa.'**
  String get loanCancelDraftConfirmMessage;

  /// No description provided for @loanCancelDraftAction.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi Rasimu'**
  String get loanCancelDraftAction;

  /// No description provided for @loanRegenerateScheduleAction.
  ///
  /// In sw, this message translates to:
  /// **'Tengeneza Ratiba Upya'**
  String get loanRegenerateScheduleAction;

  /// No description provided for @loanEditTermsAction.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Mkopo'**
  String get loanEditTermsAction;

  /// No description provided for @loanEditTermsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Hariri Masharti ya Mkopo'**
  String get loanEditTermsTitle;

  /// No description provided for @loanSubmitAction.
  ///
  /// In sw, this message translates to:
  /// **'Wasilisha kwa Idhini'**
  String get loanSubmitAction;

  /// No description provided for @loanSubmitConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Wasilisha kwa Idhini?'**
  String get loanSubmitConfirmTitle;

  /// No description provided for @loanSubmitConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mkopaji: {borrower}\nNamba ya Mkopo: {loanNumber}\nAina ya Mkopo: {product}\nMkopo Mkuu: {principal}\nRiba: {rate}% {method}\nMuda: Miezi {term}\nJumla ya Riba: {totalInterest}\nJumla ya Kulipwa: {totalRepayable}\nTarehe ya Kwanza ya Kulipa: {firstRepaymentDate}\n\nBaada ya kuwasilisha, masharti haya yatafungwa na hayataweza kuhaririwa tena.'**
  String loanSubmitConfirmMessage(
    String borrower,
    String loanNumber,
    String product,
    String principal,
    String rate,
    String method,
    String term,
    String totalInterest,
    String totalRepayable,
    String firstRepaymentDate,
  );

  /// No description provided for @loanApproveAction.
  ///
  /// In sw, this message translates to:
  /// **'Idhinisha'**
  String get loanApproveAction;

  /// No description provided for @loanApproveConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Idhinisha Mkopo?'**
  String get loanApproveConfirmTitle;

  /// No description provided for @loanApproveConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hatua hii itaidhinisha mkopo kwa ajili ya kutolewa.'**
  String get loanApproveConfirmMessage;

  /// No description provided for @loanRejectAction.
  ///
  /// In sw, this message translates to:
  /// **'Kataa'**
  String get loanRejectAction;

  /// No description provided for @loanRejectTitle.
  ///
  /// In sw, this message translates to:
  /// **'Kataa Mkopo'**
  String get loanRejectTitle;

  /// No description provided for @loanRejectionReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya Kukataa'**
  String get loanRejectionReasonLabel;

  /// No description provided for @loanRejectConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Kukataa'**
  String get loanRejectConfirmAction;

  /// No description provided for @loanCancelAction.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi Mkopo'**
  String get loanCancelAction;

  /// No description provided for @loanCancelTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi Mkopo'**
  String get loanCancelTitle;

  /// No description provided for @loanCancellationReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya Kughairi'**
  String get loanCancellationReasonLabel;

  /// No description provided for @loanCancelConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Kughairi'**
  String get loanCancelConfirmAction;

  /// No description provided for @loanReasonLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu'**
  String get loanReasonLabel;

  /// No description provided for @loanDisburseAction.
  ///
  /// In sw, this message translates to:
  /// **'Toa Mkopo'**
  String get loanDisburseAction;

  /// No description provided for @loanDisburseTitle.
  ///
  /// In sw, this message translates to:
  /// **'Toa Mkopo'**
  String get loanDisburseTitle;

  /// No description provided for @loanDisburseConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Toa Mkopo?'**
  String get loanDisburseConfirmTitle;

  /// No description provided for @loanDisburseConfirmMessage.
  ///
  /// In sw, this message translates to:
  /// **'Unakaribia kutoa {amount} kutoka {account} kwenda kwa {borrower}. Hatua hii itapunguza salio la akaunti uliyochagua.'**
  String loanDisburseConfirmMessage(
    String amount,
    String account,
    String borrower,
  );

  /// No description provided for @loanDisburseAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get loanDisburseAmountLabel;

  /// No description provided for @loanDisburseFinancialAccountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya Fedha'**
  String get loanDisburseFinancialAccountLabel;

  /// No description provided for @loanDisburseAvailableBalanceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio Lililopo'**
  String get loanDisburseAvailableBalanceLabel;

  /// No description provided for @loanDisburseEffectiveDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Utekelezaji'**
  String get loanDisburseEffectiveDateLabel;

  /// No description provided for @loanDisburseReferenceFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kumbukumbu (hiari)'**
  String get loanDisburseReferenceFieldLabel;

  /// No description provided for @loanDisburseNotesFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (hiari)'**
  String get loanDisburseNotesFieldLabel;

  /// No description provided for @loanDisbursementDetailTitle.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Utoaji'**
  String get loanDisbursementDetailTitle;

  /// No description provided for @loanErrorNameRequired.
  ///
  /// In sw, this message translates to:
  /// **'Jina na msimbo vinahitajika.'**
  String get loanErrorNameRequired;

  /// No description provided for @loanErrorDuplicateCode.
  ///
  /// In sw, this message translates to:
  /// **'Msimbo huo tayari unatumika katika kikundi hiki.'**
  String get loanErrorDuplicateCode;

  /// No description provided for @loanErrorMinimumPrincipalMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha chini cha mkopo lazima kiwe zaidi ya sifuri.'**
  String get loanErrorMinimumPrincipalMustBePositive;

  /// No description provided for @loanErrorMaximumPrincipalBelowMinimum.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha juu cha mkopo hakiwezi kuwa chini ya kiwango cha chini.'**
  String get loanErrorMaximumPrincipalBelowMinimum;

  /// No description provided for @loanErrorMinimumTermMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Muda wa chini lazima uwe zaidi ya sifuri.'**
  String get loanErrorMinimumTermMustBePositive;

  /// No description provided for @loanErrorMaximumTermBelowMinimum.
  ///
  /// In sw, this message translates to:
  /// **'Muda wa juu hauwezi kuwa chini ya muda wa chini.'**
  String get loanErrorMaximumTermBelowMinimum;

  /// No description provided for @loanErrorInterestRateInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiwango sahihi cha riba.'**
  String get loanErrorInterestRateInvalid;

  /// No description provided for @loanErrorProductInactive.
  ///
  /// In sw, this message translates to:
  /// **'Aina hii ya mkopo haitumiki tena.'**
  String get loanErrorProductInactive;

  /// No description provided for @loanErrorPrincipalMustBePositive.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha mkopo lazima kiwe zaidi ya sifuri.'**
  String get loanErrorPrincipalMustBePositive;

  /// No description provided for @loanErrorPrincipalBelowProductMinimum.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha mkopo kiko chini ya kiwango cha chini cha aina hii ya mkopo.'**
  String get loanErrorPrincipalBelowProductMinimum;

  /// No description provided for @loanErrorPrincipalAboveProductMaximum.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha mkopo kiko juu ya kiwango cha juu cha aina hii ya mkopo.'**
  String get loanErrorPrincipalAboveProductMaximum;

  /// No description provided for @loanErrorTermOutOfProductRange.
  ///
  /// In sw, this message translates to:
  /// **'Muda uko nje ya kiwango kinachoruhusiwa cha aina hii ya mkopo.'**
  String get loanErrorTermOutOfProductRange;

  /// No description provided for @loanErrorBorrowerNotActive.
  ///
  /// In sw, this message translates to:
  /// **'Mwanachama huyu si mwanachama anayeendelea wa kikundi.'**
  String get loanErrorBorrowerNotActive;

  /// No description provided for @loanErrorNotDraft.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu si rasimu tena na hauwezi kuhaririwa.'**
  String get loanErrorNotDraft;

  /// No description provided for @loanErrorNotFound.
  ///
  /// In sw, this message translates to:
  /// **'Haikupatikana.'**
  String get loanErrorNotFound;

  /// No description provided for @loanErrorPermissionDenied.
  ///
  /// In sw, this message translates to:
  /// **'Huna ruhusa ya kufanya hivyo.'**
  String get loanErrorPermissionDenied;

  /// No description provided for @loanErrorNetwork.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu ya mtandao. Angalia muunganisho wako na ujaribu tena.'**
  String get loanErrorNetwork;

  /// No description provided for @loanErrorUnexpected.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu imetokea. Tafadhali jaribu tena.'**
  String get loanErrorUnexpected;

  /// No description provided for @loanErrorScheduleMismatch.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba ya mkopo huu haipo au haiendani na masharti yake. Jaribu kuitengeneza upya kwanza.'**
  String get loanErrorScheduleMismatch;

  /// No description provided for @loanErrorNotSubmitted.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu haujawasilishwa kusubiri idhini.'**
  String get loanErrorNotSubmitted;

  /// No description provided for @loanErrorRejectionReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kukataa inahitajika.'**
  String get loanErrorRejectionReasonRequired;

  /// No description provided for @loanErrorCancellationReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kughairi inahitajika.'**
  String get loanErrorCancellationReasonRequired;

  /// No description provided for @loanErrorNotCancellable.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu hauwezi kughairiwa tena.'**
  String get loanErrorNotCancellable;

  /// No description provided for @loanErrorNotApproved.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu lazima uidhinishwe kabla ya kutolewa.'**
  String get loanErrorNotApproved;

  /// No description provided for @loanErrorAlreadyDisbursed.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu tayari umetolewa.'**
  String get loanErrorAlreadyDisbursed;

  /// No description provided for @loanErrorFinancialAccountInactive.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti hii ya fedha haitumiki.'**
  String get loanErrorFinancialAccountInactive;

  /// No description provided for @loanErrorInsufficientBalance.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya fedha iliyochaguliwa haina salio la kutosha kwa mgawanyo huu.'**
  String get loanErrorInsufficientBalance;

  /// No description provided for @loanErrorPenaltyConfigInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Kamilisha aina ya adhabu, marudio, na siku za msamaha.'**
  String get loanErrorPenaltyConfigInvalid;

  /// No description provided for @loanErrorPenaltyFixedAmountRequired.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi maalum cha adhabu kinahitajika kwa aina ya adhabu ya Kiasi Maalum.'**
  String get loanErrorPenaltyFixedAmountRequired;

  /// No description provided for @loanErrorPenaltyRateRequired.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango cha adhabu kinahitajika kwa aina ya adhabu ya Asilimia.'**
  String get loanErrorPenaltyRateRequired;

  /// No description provided for @loanErrorOpeningOriginalPrincipalInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa awali lazima uwe zaidi ya sifuri.'**
  String get loanErrorOpeningOriginalPrincipalInvalid;

  /// No description provided for @loanErrorOpeningPrincipalArrearsExceedsOutstanding.
  ///
  /// In sw, this message translates to:
  /// **'Deni la mtaji lililopita haliwezi kuzidi mtaji uliobaki mwanzoni.'**
  String get loanErrorOpeningPrincipalArrearsExceedsOutstanding;

  /// No description provided for @loanErrorOpeningArrearsDueDateInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Weka tarehe sahihi ya malipo ya deni, isiyozidi tarehe ya salio la awali.'**
  String get loanErrorOpeningArrearsDueDateInvalid;

  /// No description provided for @loanErrorOpeningArrearsInstallmentInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Kila awamu yenye deni la nyuma inahitaji tarehe ya kulipa na kiasi kimoja angalau kikubwa kuliko sifuri.'**
  String get loanErrorOpeningArrearsInstallmentInvalid;

  /// No description provided for @loanErrorOpeningArrearsDuplicateDueDate.
  ///
  /// In sw, this message translates to:
  /// **'Awamu mbili za deni la nyuma haziwezi kuwa na tarehe moja ya kulipa.'**
  String get loanErrorOpeningArrearsDuplicateDueDate;

  /// No description provided for @loanErrorOpeningSimpleArrearsBelowContractual.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya deni la nyuma ulilolisajili ni ndogo kuliko kiasi cha mkataba kwa awamu hizi zisizolipwa. Angalia namba, au tumia Ingiza kwa Maelezo kama historia ya mkopo huu ni ngumu zaidi.'**
  String get loanErrorOpeningSimpleArrearsBelowContractual;

  /// No description provided for @loanErrorOpeningSimpleInputInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Angalia masharti ya awali ya mkopo — riba ya mkataba, kiasi cha awamu, idadi ya awamu zisizolipwa, na jumla ya deni lazima viwe sahihi.'**
  String get loanErrorOpeningSimpleInputInvalid;

  /// No description provided for @loanErrorOpeningRemainingScheduleInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba iliyobaki haiendani — angalia idadi ya awamu na tarehe inayofuata.'**
  String get loanErrorOpeningRemainingScheduleInvalid;

  /// No description provided for @loanErrorOpeningNoOutstandingPosition.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna salio la mkopo linalodaiwa la kuhamishwa.'**
  String get loanErrorOpeningNoOutstandingPosition;

  /// No description provided for @loanAllocationDueDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Kulipa'**
  String get loanAllocationDueDateLabel;

  /// No description provided for @loanComponentInterest.
  ///
  /// In sw, this message translates to:
  /// **'Riba'**
  String get loanComponentInterest;

  /// No description provided for @loanComponentPrincipal.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji'**
  String get loanComponentPrincipal;

  /// No description provided for @loanComponentPenalty.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu ya Mkopo'**
  String get loanComponentPenalty;

  /// No description provided for @loanInstallmentStatusUpcoming.
  ///
  /// In sw, this message translates to:
  /// **'Inakuja'**
  String get loanInstallmentStatusUpcoming;

  /// No description provided for @loanInstallmentStatusDue.
  ///
  /// In sw, this message translates to:
  /// **'Inadaiwa'**
  String get loanInstallmentStatusDue;

  /// No description provided for @loanInstallmentStatusPartiallyPaid.
  ///
  /// In sw, this message translates to:
  /// **'Imelipwa Kiasi'**
  String get loanInstallmentStatusPartiallyPaid;

  /// No description provided for @loanInstallmentStatusPaid.
  ///
  /// In sw, this message translates to:
  /// **'Imelipwa'**
  String get loanInstallmentStatusPaid;

  /// No description provided for @loanInstallmentStatusOverdue.
  ///
  /// In sw, this message translates to:
  /// **'Imechelewa'**
  String get loanInstallmentStatusOverdue;

  /// No description provided for @loanSummaryPrincipalRepaidLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Uliolipwa'**
  String get loanSummaryPrincipalRepaidLabel;

  /// No description provided for @loanSummaryPrincipalOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Unaodaiwa'**
  String get loanSummaryPrincipalOutstandingLabel;

  /// No description provided for @loanSummaryInterestRecognizedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Iliyopatikana'**
  String get loanSummaryInterestRecognizedLabel;

  /// No description provided for @loanSummaryInterestOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Inayodaiwa'**
  String get loanSummaryInterestOutstandingLabel;

  /// No description provided for @loanSummaryTotalOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla Inayodaiwa'**
  String get loanSummaryTotalOutstandingLabel;

  /// No description provided for @loanSummaryNextDueDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yanayofuata'**
  String get loanSummaryNextDueDateLabel;

  /// No description provided for @loanSummaryOverdueAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Kilichochelewa'**
  String get loanSummaryOverdueAmountLabel;

  /// No description provided for @loanSummaryPenaltyPaidLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu Iliyolipwa'**
  String get loanSummaryPenaltyPaidLabel;

  /// No description provided for @loanSummaryPenaltyOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu Iliyobaki'**
  String get loanSummaryPenaltyOutstandingLabel;

  /// No description provided for @financialPositionFundedLoanPrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo Mkuu Uliotolewa Unaodaiwa'**
  String get financialPositionFundedLoanPrincipalLabel;

  /// No description provided for @financialPositionScheduledUnearnedInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Iliyopangwa Isiyopatikana Bado'**
  String get financialPositionScheduledUnearnedInterestLabel;

  /// No description provided for @financialPositionRecognizedLoanInterestIncomeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato ya Riba ya Mikopo Yaliyopatikana'**
  String get financialPositionRecognizedLoanInterestIncomeLabel;

  /// No description provided for @financialPositionLoanPenaltiesOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu za Mikopo Zinazodaiwa'**
  String get financialPositionLoanPenaltiesOutstandingLabel;

  /// No description provided for @financialPositionRecognizedLoanPenaltyIncomeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato ya Adhabu ya Mikopo Yaliyopatikana'**
  String get financialPositionRecognizedLoanPenaltyIncomeLabel;

  /// No description provided for @loanPenaltiesEntryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu'**
  String get loanPenaltiesEntryTitle;

  /// No description provided for @loanPenaltiesEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Awamu zilizochelewa, historia ya adhabu, na ukadiriaji'**
  String get loanPenaltiesEntrySubtitle;

  /// No description provided for @loanPenaltiesScreenTitle.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu za Mikopo'**
  String get loanPenaltiesScreenTitle;

  /// No description provided for @loanPenaltyAssessActionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kadiria Adhabu'**
  String get loanPenaltyAssessActionLabel;

  /// No description provided for @loanPenaltyAssessmentDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Ukadiriaji'**
  String get loanPenaltyAssessmentDateFieldLabel;

  /// No description provided for @loanPenaltyAssessmentResultAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Zilizokadiriwa'**
  String get loanPenaltyAssessmentResultAssessedLabel;

  /// No description provided for @loanPenaltyAssessmentResultSkippedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Zilizorukwa'**
  String get loanPenaltyAssessmentResultSkippedLabel;

  /// No description provided for @loanPenaltyAssessmentResultTotalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Kiasi'**
  String get loanPenaltyAssessmentResultTotalLabel;

  /// No description provided for @loanPenaltyAssessmentResultEligibleLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Zinazostahili'**
  String get loanPenaltyAssessmentResultEligibleLabel;

  /// No description provided for @loanPenaltyHistoryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Historia ya Adhabu'**
  String get loanPenaltyHistoryTitle;

  /// No description provided for @loanPenaltyHistoryEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna adhabu zilizokadiriwa kwa mkopo huu.'**
  String get loanPenaltyHistoryEmptyMessage;

  /// No description provided for @loanPenaltiesOutstandingTotalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Adhabu Zinazodaiwa'**
  String get loanPenaltiesOutstandingTotalLabel;

  /// No description provided for @loanPenaltyOccurrenceLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tukio {number}'**
  String loanPenaltyOccurrenceLabel(int number);

  /// No description provided for @loanPenaltyOriginOpeningLabel.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Awali'**
  String get loanPenaltyOriginOpeningLabel;

  /// No description provided for @loanPenaltyOriginAssessedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Ilikadiriwa'**
  String get loanPenaltyOriginAssessedLabel;

  /// No description provided for @addExistingLoanAction.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza Mkopo Uliopo'**
  String get addExistingLoanAction;

  /// No description provided for @existingLoanEntrySubtitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza mkopo uliokwisha kutolewa kabla ya Umoja'**
  String get existingLoanEntrySubtitle;

  /// No description provided for @migratedLoanFormTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza Mkopo Uliopo'**
  String get migratedLoanFormTitle;

  /// No description provided for @sectionMigratedLoanDetails.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo ya Mkopo Uliopo'**
  String get sectionMigratedLoanDetails;

  /// No description provided for @sectionMigratedLoanOpeningPosition.
  ///
  /// In sw, this message translates to:
  /// **'Salio la Awali'**
  String get sectionMigratedLoanOpeningPosition;

  /// No description provided for @sectionMigratedLoanArrears.
  ///
  /// In sw, this message translates to:
  /// **'Madeni Yaliyopita'**
  String get sectionMigratedLoanArrears;

  /// No description provided for @sectionMigratedLoanRemainingSchedule.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba Iliyobaki'**
  String get sectionMigratedLoanRemainingSchedule;

  /// No description provided for @sectionMigratedLoanReview.
  ///
  /// In sw, this message translates to:
  /// **'Kagua'**
  String get sectionMigratedLoanReview;

  /// No description provided for @originalLoanNumberFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Namba ya Awali ya Mkopo (hiari)'**
  String get originalLoanNumberFieldLabel;

  /// No description provided for @originalDisbursementDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Awali ya Mkopo'**
  String get originalDisbursementDateFieldLabel;

  /// No description provided for @openingAsOfDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Salio la Awali'**
  String get openingAsOfDateFieldLabel;

  /// No description provided for @originalPrincipalFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Awali'**
  String get originalPrincipalFieldLabel;

  /// No description provided for @openingPrincipalOutstandingFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Uliobaki Mwanzoni'**
  String get openingPrincipalOutstandingFieldLabel;

  /// No description provided for @openingPrincipalArrearsFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Mtaji Lililopita'**
  String get openingPrincipalArrearsFieldLabel;

  /// No description provided for @openingInterestArrearsFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Riba Lililopita'**
  String get openingInterestArrearsFieldLabel;

  /// No description provided for @openingPenaltyArrearsFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Adhabu Lililopita'**
  String get openingPenaltyArrearsFieldLabel;

  /// No description provided for @arrearsDueDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Malipo ya Deni'**
  String get arrearsDueDateFieldLabel;

  /// No description provided for @remainingInstallmentCountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Zilizobaki'**
  String get remainingInstallmentCountFieldLabel;

  /// No description provided for @nextDueDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe Inayofuata'**
  String get nextDueDateFieldLabel;

  /// No description provided for @futureScheduledInterestFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Itakayokuja'**
  String get futureScheduledInterestFieldLabel;

  /// No description provided for @migratedLoanNotesFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo (hiari)'**
  String get migratedLoanNotesFieldLabel;

  /// No description provided for @migratedLoanPostAction.
  ///
  /// In sw, this message translates to:
  /// **'Weka Salio la Awali la Mkopo'**
  String get migratedLoanPostAction;

  /// No description provided for @loanOriginLabel.
  ///
  /// In sw, this message translates to:
  /// **'Chanzo cha Mkopo'**
  String get loanOriginLabel;

  /// No description provided for @loanOriginMigratedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Umehamishwa / Salio la Awali'**
  String get loanOriginMigratedLabel;

  /// No description provided for @loanOriginNewLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mpya'**
  String get loanOriginNewLabel;

  /// No description provided for @accountingImpactTitle.
  ///
  /// In sw, this message translates to:
  /// **'Athari za Kihasibu'**
  String get accountingImpactTitle;

  /// No description provided for @financialAccountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Akaunti ya Fedha'**
  String get financialAccountLabel;

  /// No description provided for @financialAccountNoneLabel.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna'**
  String get financialAccountNoneLabel;

  /// No description provided for @cashbookImpactLabel.
  ///
  /// In sw, this message translates to:
  /// **'Athari kwa Kitabu cha Fedha'**
  String get cashbookImpactLabel;

  /// No description provided for @incomeRecognizedNowLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mapato Yaliyotambuliwa Sasa'**
  String get incomeRecognizedNowLabel;

  /// No description provided for @expenseRecognizedNowLabel.
  ///
  /// In sw, this message translates to:
  /// **'Matumizi Yaliyotambuliwa Sasa'**
  String get expenseRecognizedNowLabel;

  /// No description provided for @fundedPrincipalReceivableChangeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo Mkuu Uliotolewa Unaodaiwa'**
  String get fundedPrincipalReceivableChangeLabel;

  /// No description provided for @futureScheduledPrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Utakaokuja'**
  String get futureScheduledPrincipalLabel;

  /// No description provided for @migratedBadgeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Umehamishwa / Salio la Awali'**
  String get migratedBadgeLabel;

  /// No description provided for @originalDisbursementDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Awali ya Mkopo'**
  String get originalDisbursementDateLabel;

  /// No description provided for @openingAsOfDateLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya Salio la Awali'**
  String get openingAsOfDateLabel;

  /// No description provided for @originalPrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Awali'**
  String get originalPrincipalLabel;

  /// No description provided for @sectionMigratedLoanHistoricalArrears.
  ///
  /// In sw, this message translates to:
  /// **'Madeni ya Awamu Zilizopita'**
  String get sectionMigratedLoanHistoricalArrears;

  /// No description provided for @addArrearsInstallmentAction.
  ///
  /// In sw, this message translates to:
  /// **'+ Ongeza Awamu Yenye Deni'**
  String get addArrearsInstallmentAction;

  /// No description provided for @arrearsRowPrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Uliobaki'**
  String get arrearsRowPrincipalLabel;

  /// No description provided for @arrearsRowInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Iliyobaki'**
  String get arrearsRowInterestLabel;

  /// No description provided for @arrearsRowPenaltyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu ya Awali'**
  String get arrearsRowPenaltyLabel;

  /// No description provided for @arrearsRowTotalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla'**
  String get arrearsRowTotalLabel;

  /// No description provided for @totalHistoricalArrearsLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Madeni Yaliyopita'**
  String get totalHistoricalArrearsLabel;

  /// No description provided for @historicalArrearsEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna madeni ya awamu zilizopita yaliyoongezwa — mkopo huu una ratiba ya baadaye tu.'**
  String get historicalArrearsEmptyMessage;

  /// No description provided for @removeAction.
  ///
  /// In sw, this message translates to:
  /// **'Ondoa'**
  String get removeAction;

  /// No description provided for @saveAction.
  ///
  /// In sw, this message translates to:
  /// **'Hifadhi'**
  String get saveAction;

  /// No description provided for @cancelAction.
  ///
  /// In sw, this message translates to:
  /// **'Ghairi'**
  String get cancelAction;

  /// No description provided for @simpleImportModeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza kwa Urahisi'**
  String get simpleImportModeLabel;

  /// No description provided for @detailedImportModeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Ingiza kwa Maelezo'**
  String get detailedImportModeLabel;

  /// No description provided for @simpleImportModeDescription.
  ///
  /// In sw, this message translates to:
  /// **'Weka masharti ya awali ya mkopo na jumla ya deni lililobaki. Umoja itajenga upya ratiba ya mkataba na kutenganisha adhabu zilizoletwa kutoka nyuma.'**
  String get simpleImportModeDescription;

  /// No description provided for @contractedInterestFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba ya Mkataba'**
  String get contractedInterestFieldLabel;

  /// No description provided for @monthlyInstallmentAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu ya Mkataba kwa Mwezi'**
  String get monthlyInstallmentAmountFieldLabel;

  /// No description provided for @historicalUnpaidCountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Ambazo Hazijalipwa'**
  String get historicalUnpaidCountFieldLabel;

  /// No description provided for @totalHistoricalArrearsFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Deni la Nyuma'**
  String get totalHistoricalArrearsFieldLabel;

  /// No description provided for @contractualArrearsLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Marejesho'**
  String get contractualArrearsLabel;

  /// No description provided for @openingLegacyPenaltyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu ya Deni la Nyuma'**
  String get openingLegacyPenaltyLabel;

  /// No description provided for @sectionSchedulePreview.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki Ratiba ya Marejesho'**
  String get sectionSchedulePreview;

  /// No description provided for @historicalOverdueInstallmentsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Awamu za Nyuma Zilizochelewa'**
  String get historicalOverdueInstallmentsTitle;

  /// No description provided for @futureRemainingInstallmentsTitle.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Zijazo Zilizobaki'**
  String get futureRemainingInstallmentsTitle;

  /// No description provided for @previewScheduleAction.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki Ratiba'**
  String get previewScheduleAction;

  /// No description provided for @editScheduleInputsAction.
  ///
  /// In sw, this message translates to:
  /// **'Rudi / Hariri'**
  String get editScheduleInputsAction;

  /// No description provided for @continueToReviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Endelea Kuhakiki'**
  String get continueToReviewAction;

  /// No description provided for @sectionReviewAndConfirm.
  ///
  /// In sw, this message translates to:
  /// **'Hakiki na Thibitisha'**
  String get sectionReviewAndConfirm;

  /// No description provided for @confirmAndAddExistingLoanAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha na Ingiza Mkopo'**
  String get confirmAndAddExistingLoanAction;

  /// No description provided for @migratedLoanConfirmationSafetyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu ulikuwepo kabla ya Umoja. Kuuingiza kunasajili salio la awali tu. Hakuna fedha zinazohama wala mapato yanayotambuliwa.'**
  String get migratedLoanConfirmationSafetyMessage;

  /// No description provided for @originalPrincipalSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Awali'**
  String get originalPrincipalSummaryLabel;

  /// No description provided for @contractedInterestSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba ya Mkataba'**
  String get contractedInterestSummaryLabel;

  /// No description provided for @contractualTotalSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Mkataba'**
  String get contractualTotalSummaryLabel;

  /// No description provided for @historicalUnpaidInstallmentsSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu za Nyuma Zisizolipwa'**
  String get historicalUnpaidInstallmentsSummaryLabel;

  /// No description provided for @historicalContractualDebtSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Deni la Mkataba la Nyuma'**
  String get historicalContractualDebtSummaryLabel;

  /// No description provided for @remainingFutureInstallmentsSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Awamu Zijazo Zilizobaki'**
  String get remainingFutureInstallmentsSummaryLabel;

  /// No description provided for @futureContractualTotalSummaryLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Mkataba Ijayo'**
  String get futureContractualTotalSummaryLabel;

  /// No description provided for @originalLoanTermFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Awamu za Mkopo'**
  String get originalLoanTermFieldLabel;

  /// No description provided for @originalLoanTermHelperText.
  ///
  /// In sw, this message translates to:
  /// **'Idadi ya jumla ya awamu katika mkataba wa awali wa mkopo.'**
  String get originalLoanTermHelperText;

  /// No description provided for @paidBeforeUmojaLabel.
  ///
  /// In sw, this message translates to:
  /// **'Zilizolipwa Kabla ya Umoja'**
  String get paidBeforeUmojaLabel;

  /// No description provided for @cashbookFilterLoanDisbursements.
  ///
  /// In sw, this message translates to:
  /// **'Utoaji wa Mikopo'**
  String get cashbookFilterLoanDisbursements;

  /// No description provided for @financialAccountLoanDisbursementLedgerLabel.
  ///
  /// In sw, this message translates to:
  /// **'Utoaji wa Mkopo — {loanNumber} ({borrower})'**
  String financialAccountLoanDisbursementLedgerLabel(
    String loanNumber,
    String borrower,
  );

  /// No description provided for @loanErrorLoanNotActive.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu haupo katika hali ya kutumika.'**
  String get loanErrorLoanNotActive;

  /// No description provided for @loanErrorAlreadyFullySettled.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo huu tayari umelipwa kikamilifu.'**
  String get loanErrorAlreadyFullySettled;

  /// No description provided for @loanErrorPrepaymentAmountInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi cha malipo ya awali ambacho hakizidi salio la awamu zijazo.'**
  String get loanErrorPrepaymentAmountInvalid;

  /// No description provided for @loanErrorPrepaymentBlockedOverduePenalty.
  ///
  /// In sw, this message translates to:
  /// **'Futa faini iliyochelewa kwa malipo ya kawaida kabla ya kulipa awali sehemu ya mtaji.'**
  String get loanErrorPrepaymentBlockedOverduePenalty;

  /// No description provided for @loanErrorPrepaymentBlockedOverdueInterest.
  ///
  /// In sw, this message translates to:
  /// **'Futa riba iliyochelewa kwa malipo ya kawaida kabla ya kulipa awali sehemu ya mtaji.'**
  String get loanErrorPrepaymentBlockedOverdueInterest;

  /// No description provided for @loanErrorPrepaymentReversalBlockedSubsequentActivity.
  ///
  /// In sw, this message translates to:
  /// **'Malipo haya ya awali hayawezi kufutwa kwa sababu shughuli nyingine tayari zimerekodiwa dhidi ya ratiba yake iliyohesabiwa upya.'**
  String get loanErrorPrepaymentReversalBlockedSubsequentActivity;

  /// No description provided for @loanErrorRestructureReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya kurekebisha mkopo inahitajika.'**
  String get loanErrorRestructureReasonRequired;

  /// No description provided for @loanErrorRestructureInputInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Angalia idadi ya awamu inayopendekezwa, tarehe ya awamu ya kwanza, na kiwango cha riba.'**
  String get loanErrorRestructureInputInvalid;

  /// No description provided for @loanErrorRestructureBlockedOverdueBalance.
  ///
  /// In sw, this message translates to:
  /// **'Futa kila salio lililochelewa kwa malipo ya kawaida kabla ya kurekebisha mkopo huu.'**
  String get loanErrorRestructureBlockedOverdueBalance;

  /// No description provided for @loanErrorRestructureNothingRemaining.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna kilichobaki kwenye mkopo huu cha kurekebisha.'**
  String get loanErrorRestructureNothingRemaining;

  /// No description provided for @loanEarlySettlementAction.
  ///
  /// In sw, this message translates to:
  /// **'Ulipaji wa Awali Kamili'**
  String get loanEarlySettlementAction;

  /// No description provided for @loanPrepayPrincipalAction.
  ///
  /// In sw, this message translates to:
  /// **'Malipo ya Awali ya Mtaji'**
  String get loanPrepayPrincipalAction;

  /// No description provided for @loanRestructureAction.
  ///
  /// In sw, this message translates to:
  /// **'Rekebisha Mkopo'**
  String get loanRestructureAction;

  /// No description provided for @loanEarlySettlementTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ulipaji wa Awali Kamili'**
  String get loanEarlySettlementTitle;

  /// No description provided for @loanEarlySettlementQuoteTitle.
  ///
  /// In sw, this message translates to:
  /// **'Makadirio ya Ulipaji'**
  String get loanEarlySettlementQuoteTitle;

  /// No description provided for @loanEarlySettlementOverduePenaltyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Faini Iliyochelewa'**
  String get loanEarlySettlementOverduePenaltyLabel;

  /// No description provided for @loanEarlySettlementOverdueInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Iliyochelewa'**
  String get loanEarlySettlementOverdueInterestLabel;

  /// No description provided for @loanEarlySettlementOverduePrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Uliochelewa'**
  String get loanEarlySettlementOverduePrincipalLabel;

  /// No description provided for @loanEarlySettlementCurrentPenaltyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Faini Inayolipika Sasa'**
  String get loanEarlySettlementCurrentPenaltyLabel;

  /// No description provided for @loanEarlySettlementCurrentInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba Inayolipika Sasa'**
  String get loanEarlySettlementCurrentInterestLabel;

  /// No description provided for @loanEarlySettlementCurrentPrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji Unaolipika Sasa'**
  String get loanEarlySettlementCurrentPrincipalLabel;

  /// No description provided for @loanEarlySettlementFuturePrincipalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Baadaye (unaolipwa mapema)'**
  String get loanEarlySettlementFuturePrincipalLabel;

  /// No description provided for @loanEarlySettlementFutureUnearnedInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba ya Baadaye Isiyopatikana (haitatozwa)'**
  String get loanEarlySettlementFutureUnearnedInterestLabel;

  /// No description provided for @loanEarlySettlementTotalLabel.
  ///
  /// In sw, this message translates to:
  /// **'Jumla ya Kiasi cha Ulipaji'**
  String get loanEarlySettlementTotalLabel;

  /// No description provided for @loanEarlySettlementFinancialAccountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Chanzo cha Fedha'**
  String get loanEarlySettlementFinancialAccountFieldLabel;

  /// No description provided for @loanEarlySettlementPaymentMethodFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Njia ya Malipo'**
  String get loanEarlySettlementPaymentMethodFieldLabel;

  /// No description provided for @loanEarlySettlementConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Lipa Mkopo Mapema'**
  String get loanEarlySettlementConfirmAction;

  /// No description provided for @loanEarlySettlementSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo umelipwa mapema kikamilifu.'**
  String get loanEarlySettlementSuccessMessage;

  /// No description provided for @loanEarlySettlementSafetyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hii inalipa faini yoyote iliyobaki, riba inayolipika sasa, na mtaji wote uliobaki (hata usiopaswa kulipwa bado). Riba ya baadaye haitatozwa kamwe.'**
  String get loanEarlySettlementSafetyMessage;

  /// No description provided for @loanPrepaymentTitle.
  ///
  /// In sw, this message translates to:
  /// **'Malipo ya Awali ya Mtaji'**
  String get loanPrepaymentTitle;

  /// No description provided for @loanPrepaymentAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha Malipo ya Awali'**
  String get loanPrepaymentAmountFieldLabel;

  /// No description provided for @loanPrepaymentTreatmentFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Urekebishaji wa Ratiba'**
  String get loanPrepaymentTreatmentFieldLabel;

  /// No description provided for @loanPrepaymentReduceTermLabel.
  ///
  /// In sw, this message translates to:
  /// **'Punguza Muda (dumisha kiasi cha awamu)'**
  String get loanPrepaymentReduceTermLabel;

  /// No description provided for @loanPrepaymentReduceInstallmentLabel.
  ///
  /// In sw, this message translates to:
  /// **'Punguza Awamu (dumisha muda)'**
  String get loanPrepaymentReduceInstallmentLabel;

  /// No description provided for @loanPrepaymentPreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesho la Awali'**
  String get loanPrepaymentPreviewAction;

  /// No description provided for @loanPrepaymentNewScheduleTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba Ijayo Iliyohesabiwa Upya'**
  String get loanPrepaymentNewScheduleTitle;

  /// No description provided for @loanPrepaymentConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Malipo ya Awali'**
  String get loanPrepaymentConfirmAction;

  /// No description provided for @loanPrepaymentSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Malipo ya awali ya mtaji yamerekodiwa.'**
  String get loanPrepaymentSuccessMessage;

  /// No description provided for @loanPrepaymentFinancialAccountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Chanzo cha Fedha'**
  String get loanPrepaymentFinancialAccountFieldLabel;

  /// No description provided for @loanPrepaymentPaymentMethodFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Njia ya Malipo'**
  String get loanPrepaymentPaymentMethodFieldLabel;

  /// No description provided for @loanPrepaymentFuturePrincipalBeforeLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Baadaye Kabla'**
  String get loanPrepaymentFuturePrincipalBeforeLabel;

  /// No description provided for @loanPrepaymentFuturePrincipalAfterLabel.
  ///
  /// In sw, this message translates to:
  /// **'Mtaji wa Baadaye Baada'**
  String get loanPrepaymentFuturePrincipalAfterLabel;

  /// No description provided for @loanRestructureTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekebisha Mkopo'**
  String get loanRestructureTitle;

  /// No description provided for @loanRestructureReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu'**
  String get loanRestructureReasonFieldLabel;

  /// No description provided for @loanRestructureNewTermFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Muda Mpya (idadi ya awamu)'**
  String get loanRestructureNewTermFieldLabel;

  /// No description provided for @loanRestructureNewFirstInstallmentDateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe Mpya ya Awamu ya Kwanza'**
  String get loanRestructureNewFirstInstallmentDateFieldLabel;

  /// No description provided for @loanRestructureNewInterestRateFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiwango Kipya cha Riba (acha wazi kudumisha cha sasa)'**
  String get loanRestructureNewInterestRateFieldLabel;

  /// No description provided for @loanRestructurePreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesha Ratiba Inayopendekezwa'**
  String get loanRestructurePreviewAction;

  /// No description provided for @loanRestructureNewScheduleTitle.
  ///
  /// In sw, this message translates to:
  /// **'Ratiba Mpya Inayopendekezwa'**
  String get loanRestructureNewScheduleTitle;

  /// No description provided for @loanRestructureConfirmAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Urekebishaji'**
  String get loanRestructureConfirmAction;

  /// No description provided for @loanRestructureSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Mkopo umerekebishwa.'**
  String get loanRestructureSuccessMessage;

  /// No description provided for @loanRestructureSafetyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hii inabadilisha ratiba ya mkataba ijayo pekee. Historia iliyokwisha lipwa haibadiliki kamwe, na hii imezuiwa iwapo salio lolote lililochelewa lipo.'**
  String get loanRestructureSafetyMessage;

  /// No description provided for @loanErrorWaiverExceedsOutstanding.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha msamaha kinazidi kiasi kinachodaiwa sasa.'**
  String get loanErrorWaiverExceedsOutstanding;

  /// No description provided for @loanErrorAdjustmentTargetInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Deni hili halikupatikana kwenye mkopo huu.'**
  String get loanErrorAdjustmentTargetInvalid;

  /// No description provided for @loanErrorFutureInterestNotWaivable.
  ///
  /// In sw, this message translates to:
  /// **'Riba ya siku zijazo isiyofikia wakati wake haiwezi kusamehewa au kurekebishwa.'**
  String get loanErrorFutureInterestNotWaivable;

  /// No description provided for @loanErrorPrincipalAdjustmentProhibited.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha mtaji hakiwezi kusamehewa au kurekebishwa.'**
  String get loanErrorPrincipalAdjustmentProhibited;

  /// No description provided for @loanErrorCorrectionIncreaseNotAllowed.
  ///
  /// In sw, this message translates to:
  /// **'Kuongeza riba kwa njia ya urekebishaji hairuhusiwi.'**
  String get loanErrorCorrectionIncreaseNotAllowed;

  /// No description provided for @loanErrorCorrectionIncreaseExceedsBound.
  ///
  /// In sw, this message translates to:
  /// **'Ongezeko hili linazidi kiwango cha juu kinachoruhusiwa kwa adhabu hii.'**
  String get loanErrorCorrectionIncreaseExceedsBound;

  /// No description provided for @loanErrorCorrectionIncreasePolicyUnavailable.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu hii haina sera iliyorekodiwa ya kutegemeza ongezeko.'**
  String get loanErrorCorrectionIncreasePolicyUnavailable;

  /// No description provided for @loanErrorCorrectionDecreaseExceedsOutstanding.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha urekebishaji kinazidi kiasi kinachodaiwa sasa.'**
  String get loanErrorCorrectionDecreaseExceedsOutstanding;

  /// No description provided for @loanErrorFutureInterestNotCorrectable.
  ///
  /// In sw, this message translates to:
  /// **'Riba ya siku zijazo isiyofikia wakati wake haiwezi kurekebishwa.'**
  String get loanErrorFutureInterestNotCorrectable;

  /// No description provided for @loanErrorAdjustmentEffectiveDateRequired.
  ///
  /// In sw, this message translates to:
  /// **'Tarehe ya kutekeleza inahitajika kwa hatua hii.'**
  String get loanErrorAdjustmentEffectiveDateRequired;

  /// No description provided for @loanErrorAdjustmentAmountInvalid.
  ///
  /// In sw, this message translates to:
  /// **'Weka kiasi kikubwa zaidi ya sifuri.'**
  String get loanErrorAdjustmentAmountInvalid;

  /// No description provided for @loanErrorAdjustmentReasonRequired.
  ///
  /// In sw, this message translates to:
  /// **'Chagua sababu sahihi.'**
  String get loanErrorAdjustmentReasonRequired;

  /// No description provided for @loanErrorAdjustmentOtherNoteRequired.
  ///
  /// In sw, this message translates to:
  /// **'Weka maelezo yanayoeleza \"Nyingine\".'**
  String get loanErrorAdjustmentOtherNoteRequired;

  /// No description provided for @loanErrorAdjustmentAlreadyReversed.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho haya tayari yamebatilishwa.'**
  String get loanErrorAdjustmentAlreadyReversed;

  /// No description provided for @loanErrorAdjustmentReversalBlockedSubsequentActivity.
  ///
  /// In sw, this message translates to:
  /// **'Haiwezi kubatilishwa kwa sababu shughuli nyingine tayari imerekodiwa dhidi yake.'**
  String get loanErrorAdjustmentReversalBlockedSubsequentActivity;

  /// No description provided for @loanErrorAdjustmentReversalNotSupported.
  ///
  /// In sw, this message translates to:
  /// **'Kubatilisha hakiwezi kubatilishwa tena.'**
  String get loanErrorAdjustmentReversalNotSupported;

  /// No description provided for @loanWaiveObligationAction.
  ///
  /// In sw, this message translates to:
  /// **'Samehe Deni'**
  String get loanWaiveObligationAction;

  /// No description provided for @loanCorrectObligationAction.
  ///
  /// In sw, this message translates to:
  /// **'Rekebisha Deni'**
  String get loanCorrectObligationAction;

  /// No description provided for @loanObligationWaiveTitle.
  ///
  /// In sw, this message translates to:
  /// **'Samehe Deni'**
  String get loanObligationWaiveTitle;

  /// No description provided for @loanObligationCorrectTitle.
  ///
  /// In sw, this message translates to:
  /// **'Rekebisha Deni'**
  String get loanObligationCorrectTitle;

  /// No description provided for @loanObligationTargetPenaltyLabel.
  ///
  /// In sw, this message translates to:
  /// **'Adhabu'**
  String get loanObligationTargetPenaltyLabel;

  /// No description provided for @loanObligationTargetInterestLabel.
  ///
  /// In sw, this message translates to:
  /// **'Riba'**
  String get loanObligationTargetInterestLabel;

  /// No description provided for @loanObligationAmountFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi'**
  String get loanObligationAmountFieldLabel;

  /// No description provided for @loanObligationReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu'**
  String get loanObligationReasonFieldLabel;

  /// No description provided for @loanObligationNoteFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Maelezo'**
  String get loanObligationNoteFieldLabel;

  /// No description provided for @loanObligationPreviewAction.
  ///
  /// In sw, this message translates to:
  /// **'Onyesho la Awali'**
  String get loanObligationPreviewAction;

  /// No description provided for @loanObligationCurrentOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kinachodaiwa Sasa'**
  String get loanObligationCurrentOutstandingLabel;

  /// No description provided for @loanObligationWaiverAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi cha Msamaha'**
  String get loanObligationWaiverAmountLabel;

  /// No description provided for @loanObligationRemainingOutstandingLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kinachodaiwa Kilichobaki'**
  String get loanObligationRemainingOutstandingLabel;

  /// No description provided for @loanObligationCashImpactLabel.
  ///
  /// In sw, this message translates to:
  /// **'Athari ya Fedha'**
  String get loanObligationCashImpactLabel;

  /// No description provided for @loanObligationPaymentCreatedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Malipo Yameundwa'**
  String get loanObligationPaymentCreatedLabel;

  /// No description provided for @loanObligationReceiptCreatedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Risiti Imeundwa'**
  String get loanObligationReceiptCreatedLabel;

  /// No description provided for @loanObligationNoLabel.
  ///
  /// In sw, this message translates to:
  /// **'Hapana'**
  String get loanObligationNoLabel;

  /// No description provided for @loanObligationConfirmWaiverAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Msamaha'**
  String get loanObligationConfirmWaiverAction;

  /// No description provided for @loanObligationWaiverSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Deni limesamehewa.'**
  String get loanObligationWaiverSuccessMessage;

  /// No description provided for @loanObligationCorrectionTypeFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Aina ya Urekebishaji'**
  String get loanObligationCorrectionTypeFieldLabel;

  /// No description provided for @loanObligationCorrectionDecreaseLabel.
  ///
  /// In sw, this message translates to:
  /// **'Punguza'**
  String get loanObligationCorrectionDecreaseLabel;

  /// No description provided for @loanObligationCorrectionIncreaseLabel.
  ///
  /// In sw, this message translates to:
  /// **'Ongeza'**
  String get loanObligationCorrectionIncreaseLabel;

  /// No description provided for @loanObligationSourceOriginalAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Tathmini Halisi'**
  String get loanObligationSourceOriginalAmountLabel;

  /// No description provided for @loanObligationPriorNetCorrectionsLabel.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho ya Awali'**
  String get loanObligationPriorNetCorrectionsLabel;

  /// No description provided for @loanObligationCurrentEffectiveAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Halisi cha Sasa'**
  String get loanObligationCurrentEffectiveAmountLabel;

  /// No description provided for @loanObligationProposedCorrectionLabel.
  ///
  /// In sw, this message translates to:
  /// **'Urekebishaji Unaopendekezwa'**
  String get loanObligationProposedCorrectionLabel;

  /// No description provided for @loanObligationNewEffectiveAmountLabel.
  ///
  /// In sw, this message translates to:
  /// **'Kiasi Halisi Kipya'**
  String get loanObligationNewEffectiveAmountLabel;

  /// No description provided for @loanObligationConfirmCorrectionAction.
  ///
  /// In sw, this message translates to:
  /// **'Thibitisha Urekebishaji'**
  String get loanObligationConfirmCorrectionAction;

  /// No description provided for @loanObligationCorrectionSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Urekebishaji umewekwa.'**
  String get loanObligationCorrectionSuccessMessage;

  /// No description provided for @loanObligationReasonHardship.
  ///
  /// In sw, this message translates to:
  /// **'Ugumu wa Kimaisha'**
  String get loanObligationReasonHardship;

  /// No description provided for @loanObligationReasonCommitteeDecision.
  ///
  /// In sw, this message translates to:
  /// **'Uamuzi wa Kamati'**
  String get loanObligationReasonCommitteeDecision;

  /// No description provided for @loanObligationReasonGoodwill.
  ///
  /// In sw, this message translates to:
  /// **'Nia Njema'**
  String get loanObligationReasonGoodwill;

  /// No description provided for @loanObligationReasonSettlementConcession.
  ///
  /// In sw, this message translates to:
  /// **'Punguzo la Malipo'**
  String get loanObligationReasonSettlementConcession;

  /// No description provided for @loanObligationReasonAssessmentError.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu ya Tathmini'**
  String get loanObligationReasonAssessmentError;

  /// No description provided for @loanObligationReasonDataEntryError.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu ya Kuingiza Data'**
  String get loanObligationReasonDataEntryError;

  /// No description provided for @loanObligationReasonMigrationError.
  ///
  /// In sw, this message translates to:
  /// **'Hitilafu ya Uhamishaji'**
  String get loanObligationReasonMigrationError;

  /// No description provided for @loanObligationReasonOther.
  ///
  /// In sw, this message translates to:
  /// **'Nyingine'**
  String get loanObligationReasonOther;

  /// No description provided for @loanObligationHistoryTitle.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho na Misamaha'**
  String get loanObligationHistoryTitle;

  /// No description provided for @loanObligationHistoryEmptyMessage.
  ///
  /// In sw, this message translates to:
  /// **'Hakuna msamaha au urekebishaji uliorekodiwa kwa mkopo huu.'**
  String get loanObligationHistoryEmptyMessage;

  /// No description provided for @loanObligationHistoryReversedLabel.
  ///
  /// In sw, this message translates to:
  /// **'Imebatilishwa'**
  String get loanObligationHistoryReversedLabel;

  /// No description provided for @loanObligationReverseAction.
  ///
  /// In sw, this message translates to:
  /// **'Batilisha'**
  String get loanObligationReverseAction;

  /// No description provided for @loanObligationReverseConfirmTitle.
  ///
  /// In sw, this message translates to:
  /// **'Batilisha marekebisho haya?'**
  String get loanObligationReverseConfirmTitle;

  /// No description provided for @loanObligationReverseReasonFieldLabel.
  ///
  /// In sw, this message translates to:
  /// **'Sababu ya Kubatilisha'**
  String get loanObligationReverseReasonFieldLabel;

  /// No description provided for @loanObligationReverseSuccessMessage.
  ///
  /// In sw, this message translates to:
  /// **'Marekebisho yamebatilishwa.'**
  String get loanObligationReverseSuccessMessage;
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
