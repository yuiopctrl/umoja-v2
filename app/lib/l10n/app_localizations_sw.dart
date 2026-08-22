// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Umoja';

  @override
  String get continueButton => 'Endelea';

  @override
  String get cancelButton => 'Ghairi';

  @override
  String get closeButton => 'Funga';

  @override
  String get saveButton => 'Hifadhi';

  @override
  String get editAction => 'Hariri';

  @override
  String get signOutButtonLabel => 'Toka';

  @override
  String get languageSelectorLabel => 'Lugha';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageEnglish => 'English';

  @override
  String get authWelcomeTitle => 'Karibu Umoja';

  @override
  String get authPhoneSubtitle => 'Ingiza namba yako ya simu kuendelea.';

  @override
  String get authPhoneLabel => 'Namba ya simu';

  @override
  String get authPhoneHint => '0712345678';

  @override
  String get otpTitle => 'Thibitisha Namba';

  @override
  String otpSubtitle(String phone) {
    return 'Weka msimbo uliotumwa kwa $phone';
  }

  @override
  String get otpCodeLabel => 'Namba ya uthibitisho';

  @override
  String get otpVerifyButton => 'Thibitisha';

  @override
  String get otpChangeNumber => 'Badilisha Namba';

  @override
  String get otpResend => 'Tuma Tena';

  @override
  String otpResendCountdown(int seconds) {
    return 'Baada ya ${seconds}s';
  }

  @override
  String get pinSetupTitle => 'Tengeneza PIN';

  @override
  String get pinSetupSubtitle =>
      'Tengeneza namba nne za siri kufungua programu haraka.';

  @override
  String get pinConfirmTitle => 'Thibitisha PIN';

  @override
  String get pinConfirmSubtitle => 'Weka tena PIN yako kuthibitisha.';

  @override
  String get pinMismatch => 'PIN hazifanani. Jaribu tena.';

  @override
  String get pinSetupSaveError => 'Imeshindikana kuhifadhi PIN. Jaribu tena.';

  @override
  String get pinUnlockTitle => 'Ingiza PIN';

  @override
  String get pinUnlockSubtitle => 'Fungua programu kuendelea.';

  @override
  String get pinUnlockButton => 'Fungua';

  @override
  String get pinForgot => 'Umesahau PIN?';

  @override
  String get pinInvalid => 'PIN si sahihi.';

  @override
  String get pinTooManyAttempts =>
      'Umejaribu mara nyingi. Subiri kidogo kabla ya kujaribu tena.';

  @override
  String get pinRecoveryVerifyTitle => 'Thibitisha Namba Yako';

  @override
  String get pinRecoveryVerifySubtitle =>
      'Weka msimbo uliotumwa kuthibitisha namba yako.';

  @override
  String pinRecoveryVerifySubtitleWithPhone(String phone) {
    return 'Weka msimbo uliotumwa kwa $phone';
  }

  @override
  String get lockToPinAction => 'Toka';

  @override
  String get switchAccountAction => 'Tumia namba nyingine';

  @override
  String get switchAccountConfirmTitle => 'Tumia namba nyingine ya simu?';

  @override
  String get switchAccountConfirmMessage =>
      'Utatoka kwenye akaunti hii kwenye kifaa hiki. Utahitaji kuthibitisha namba mpya kwa OTP.';

  @override
  String get switchAccountConfirmButton => 'Tumia Namba Nyingine';

  @override
  String get profileOnboardingTitle => 'Kamilisha Wasifu Wako';

  @override
  String get fullNameLabel => 'Jina kamili';

  @override
  String get fullNameRequiredError => 'Weka jina lako kamili.';

  @override
  String get phoneReadOnlyLabel => 'Simu';

  @override
  String get profileSaveError =>
      'Imeshindikana kuhifadhi wasifu wako. Jaribu tena.';

  @override
  String get groupOnboardingTitle => 'Tengeneza Kikundi Chako';

  @override
  String get groupOnboardingSubtitle =>
      'Huna kikundi kinachofanya kazi kwa sasa. Tengeneza kimoja kuendelea.';

  @override
  String get groupNameLabel => 'Jina la kikundi';

  @override
  String get groupDescriptionLabel => 'Maelezo (si lazima)';

  @override
  String get createGroupButton => 'Tengeneza Kikundi';

  @override
  String get groupNameRequiredError => 'Jina la kikundi linahitajika.';

  @override
  String get groupSaveError =>
      'Imeshindikana kutengeneza kikundi. Jaribu tena.';

  @override
  String get homeTitle => 'Nyumbani';

  @override
  String get roleAdmin => 'Msimamizi';

  @override
  String get roleTreasurer => 'Mweka Hazina';

  @override
  String get roleSecretary => 'Katibu';

  @override
  String get roleChairperson => 'Mwenyekiti';

  @override
  String get roleMember => 'Mwanachama';

  @override
  String get statusActive => 'Hai';

  @override
  String get statusSuspended => 'Amesitishwa';

  @override
  String get statusExited => 'Ametoka';

  @override
  String get retryButton => 'Jaribu Tena';

  @override
  String get accountDisabledTitle => 'Ufikiaji wa akaunti umezimwa';

  @override
  String get accountDisabledMessage =>
      'Ufikiaji wa akaunti yako umezimwa. Wasiliana na msimamizi wa kikundi kama unadhani hii ni kosa.';

  @override
  String get contextErrorTitle => 'Imeshindikana kupakia akaunti';

  @override
  String get contextErrorMessage =>
      'Hatukuweza kupakia akaunti yako. Angalia mtandao wako kisha ujaribu tena.';

  @override
  String get groupClosedTitle => 'Kikundi kimefungwa';

  @override
  String get groupClosedMessage =>
      'Kikundi hiki kimefungwa na hakifanyi kazi tena.';

  @override
  String get groupSuspendedTitle => 'Ufikiaji wa kikundi umesitishwa';

  @override
  String get groupSuspendedMessage =>
      'Kikundi hiki kimesitishwa kwa sasa. Wasiliana na msimamizi wa kikundi kwa maelezo zaidi.';

  @override
  String get membershipRestrictedTitle => 'Uanachama umezuiwa';

  @override
  String get membershipRestrictedMessage =>
      'Uanachama wako kwenye kikundi hiki kwa sasa umesitishwa, kwa hiyo hakipatikani. Bado unaweza kutengeneza kikundi kipya.';

  @override
  String get createNewGroupAction => 'Tengeneza Kikundi Kipya';

  @override
  String get selectGroupTitle => 'Chagua Kikundi';

  @override
  String get noRolesShort => 'Hakuna majukumu';

  @override
  String get homeGreetingPlain => 'Habari';

  @override
  String homeGreetingNamed(String name) {
    return 'Habari, $name';
  }

  @override
  String get homeMembersShortcutSubtitle =>
      'Angalia na simamia wanachama wa kikundi';

  @override
  String get rolesNone => 'Majukumu: hakuna';

  @override
  String rolesList(String roles) {
    return 'Majukumu: $roles';
  }

  @override
  String get membersTitle => 'Wanachama';

  @override
  String get membersSearchHint => 'Tafuta mwanachama';

  @override
  String get clearSearchTooltip => 'Futa utafutaji';

  @override
  String get filterAll => 'Wote';

  @override
  String get filterActive => 'Hai';

  @override
  String get filterSuspended => 'Waliositishwa';

  @override
  String get filterExited => 'Waliotoka';

  @override
  String get addMemberAction => 'Ongeza Mwanachama';

  @override
  String get membersEmptyFilteredTitle => 'Hakuna mwanachama aliyepatikana';

  @override
  String get membersEmptyFilteredMessage =>
      'Jaribu kubadilisha maneno ya utafutaji au kichujio.';

  @override
  String get membersEmptyTitle => 'Jaza Orodha ya Wanachama';

  @override
  String get membersEmptyMessage => 'Ongeza mwanachama wa kwanza wa kikundi.';

  @override
  String get loadMoreAction => 'Onyesha Zaidi';

  @override
  String get paginationPrevious => 'Iliyotangulia';

  @override
  String get paginationNext => 'Ifuatayo';

  @override
  String paginationPageIndicator(int page, int total) {
    return 'Ukurasa $page / $total';
  }

  @override
  String get memberDetailTitle => 'Mwanachama';

  @override
  String get sectionIdentity => 'Taarifa za Mwanachama';

  @override
  String get sectionMembership => 'Uanachama';

  @override
  String get sectionRoles => 'Majukumu';

  @override
  String get sectionActions => 'Vitendo';

  @override
  String get manageRolesAction => 'Simamia Majukumu';

  @override
  String get memberNumberLabel => 'Namba ya mwanachama';

  @override
  String get phoneLabel => 'Simu';

  @override
  String get accountLinkedLabel => 'Akaunti ya kuingia: Imeunganishwa';

  @override
  String get accountNotLinkedLabel => 'Akaunti ya kuingia: Haijaunganishwa';

  @override
  String get joinedLabel => 'Alijiunga';

  @override
  String get exitedLabel => 'Alitoka';

  @override
  String get noRolesAssigned => 'Hakuna jukumu lililopangwa.';

  @override
  String get suspendButton => 'Sitisha';

  @override
  String get reactivateButton => 'Rudisha';

  @override
  String get markExitedButton => 'Weka Ametoka';

  @override
  String get rejoinButton => 'Rudisha kwenye Kikundi';

  @override
  String get suspendConfirmTitle => 'Sitisha mwanachama?';

  @override
  String get suspendConfirmMessage =>
      'Mwanachama huyu hataweza kushiriki shughuli za kikundi hadi atakaporudishwa.';

  @override
  String get exitConfirmTitle => 'Weka mwanachama kama ametoka?';

  @override
  String get exitConfirmMessage => 'Hatua hii haiwezi kutenduliwa hapa.';

  @override
  String get reactivateConfirmTitle => 'Rudisha mwanachama?';

  @override
  String get reactivateConfirmMessage =>
      'Mwanachama huyu ataweza kushiriki shughuli za kikundi tena.';

  @override
  String get rejoinConfirmTitle => 'Mrudishe mwanachama kwenye kikundi?';

  @override
  String get rejoinConfirmMessage =>
      'Mwanachama ataweza kushiriki shughuli za kikundi tena kuanzia leo. Historia ya awali ya kuondoka kwake inabaki kwenye kumbukumbu.';

  @override
  String get statusChangeSuccessActive => 'Mwanachama amerudishwa.';

  @override
  String get statusChangeSuccessSuspended => 'Mwanachama amesitishwa.';

  @override
  String get statusChangeSuccessExited =>
      'Mwanachama ameondolewa kwenye kikundi.';

  @override
  String get rejoinSuccessMessage => 'Mwanachama amerudishwa kwenye kikundi.';

  @override
  String get refreshFailedMessage =>
      'Imeshindikana kupakia upya taarifa mpya. Bado inaweza kuonyesha taarifa za zamani.';

  @override
  String get editMemberTitle => 'Hariri Mwanachama';

  @override
  String get formSectionContact => 'Mawasiliano';

  @override
  String get formFullNameLabel => 'Jina kamili *';

  @override
  String get phoneOptionalLabel => 'Namba ya simu (si lazima)';

  @override
  String get memberNumberAutoNote =>
      'Namba ya mwanachama itatengenezwa kiotomatiki.';

  @override
  String get memberNameRequiredError => 'Jina kamili linahitajika.';

  @override
  String get memberSaveError =>
      'Imeshindikana kuhifadhi mwanachama. Jaribu tena.';

  @override
  String get rolesSheetSubtitle => 'Chagua majukumu ya mwanachama huyu.';

  @override
  String get moreTitle => 'Zaidi';

  @override
  String get accountSectionTitle => 'Akaunti';

  @override
  String get currentGroupSectionTitle => 'Kikundi cha Sasa';

  @override
  String get actionsSectionTitle => 'Vitendo';

  @override
  String get securitySectionTitle => 'Usalama';

  @override
  String get switchGroupAction => 'Badili Kikundi';

  @override
  String get authErrorInvalidPhone =>
      'Namba hiyo ya simu haikubaliki. Tafadhali ikague na ujaribu tena.';

  @override
  String get authErrorInvalidOtp => 'Namba ya uthibitisho si sahihi.';

  @override
  String get authErrorOtpExpired => 'Muda wa msimbo huu umeisha. Omba mpya.';

  @override
  String get authErrorTooManyRequests =>
      'Umejaribu mara nyingi. Tafadhali subiri kidogo kisha ujaribu tena.';

  @override
  String get authErrorNetwork => 'Imeshindikana kuunganisha. Jaribu tena.';

  @override
  String get authErrorUnexpected => 'Hitilafu imetokea. Jaribu tena.';

  @override
  String get memberErrorAccountDisabled =>
      'Ufikiaji wa akaunti yako umezimwa. Wasiliana na msimamizi wa kikundi.';

  @override
  String get memberErrorLastAdminRequired =>
      'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.';

  @override
  String get memberErrorInvalidStatusTransition =>
      'Mwanachama huyu tayari ametoka na hawezi kurudishwa kwa njia hii.';

  @override
  String get memberErrorDuplicateMemberNumber =>
      'Namba hiyo ya mwanachama tayari inatumika kwenye kikundi hiki.';

  @override
  String get memberErrorPermissionDenied => 'Huna ruhusa ya kufanya hivyo.';

  @override
  String get memberErrorNotFound => 'Mwanachama hakupatikana.';

  @override
  String get memberErrorNetwork => 'Imeshindikana kuunganisha. Jaribu tena.';

  @override
  String get memberErrorUnexpected => 'Hitilafu imetokea. Jaribu tena.';

  @override
  String get memberErrorRejoinConflict =>
      'Mwanachama huyu tayari ana uanachama mwingine amilifu kwenye kikundi hiki.';

  @override
  String get supabaseConfigMissing =>
      'Mipangilio ya Supabase haipo (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY haijawekwa).';
}
