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
  String get authLoginSubtitle => 'Ingiza namba yako ya simu na PIN.';

  @override
  String get authPinLabel => 'PIN';

  @override
  String get loginButton => 'Ingia';

  @override
  String get authFirstTimeLink => 'Mara ya kwanza? Thibitisha namba kwa OTP';

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
  String get pinSetupSubtitle => 'PIN hii itatumika kuingia Umoja siku zijazo.';

  @override
  String get pinConfirmTitle => 'Thibitisha PIN';

  @override
  String get pinConfirmSubtitle => 'Weka PIN yako tena kuthibitisha.';

  @override
  String get pinMismatch => 'PIN hazifanani. Jaribu tena.';

  @override
  String get pinSetupSaveError => 'Imeshindikana kuhifadhi PIN. Jaribu tena.';

  @override
  String get pinForgot => 'Umesahau PIN?';

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
  String get authErrorInvalidCredentials => 'Namba ya simu au PIN si sahihi.';

  @override
  String get authErrorPinLocked => 'Jaribu tena baada ya dakika chache.';

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
  String get contributionsTitle => 'Michango';

  @override
  String get homeContributionsShortcutSubtitle =>
      'Angalia na simamia michango ya kikundi';

  @override
  String get contributionTypesEntryTitle => 'Aina za Michango';

  @override
  String get contributionTypesEntrySubtitle =>
      'Simamia aina za michango za kikundi';

  @override
  String get contributionSetupsEntryTitle => 'Mipangilio ya Michango';

  @override
  String get contributionSetupsEntrySubtitle =>
      'Simamia jinsi michango inavyotozwa';

  @override
  String get contributionPeriodsEntryTitle => 'Vipindi vya Michango';

  @override
  String get contributionPeriodsEntrySubtitle =>
      'Simamia vipindi na malipo ya michango';

  @override
  String get contributionTypesTitle => 'Aina za Michango';

  @override
  String get contributionTypesSearchHint => 'Tafuta aina ya mchango';

  @override
  String get addContributionTypeAction => 'Ongeza Aina ya Mchango';

  @override
  String get contributionTypesEmptyTitle => 'Jaza Orodha ya Aina za Michango';

  @override
  String get contributionTypesEmptyMessage =>
      'Ongeza aina ya kwanza ya mchango.';

  @override
  String get contributionTypesEmptyFilteredTitle =>
      'Hakuna aina ya mchango iliyopatikana';

  @override
  String get contributionTypesEmptyFilteredMessage =>
      'Jaribu kubadilisha maneno ya utafutaji au kichujio.';

  @override
  String get editContributionTypeTitle => 'Hariri Aina ya Mchango';

  @override
  String get sectionContributionTypeDetails => 'Taarifa za Aina ya Mchango';

  @override
  String get sectionContributionClassification =>
      'Uainishaji na Utaratibu wa Uhasibu';

  @override
  String get contributionTypeNameLabel => 'Jina la aina ya mchango *';

  @override
  String get contributionTypeDescriptionLabel => 'Maelezo (si lazima)';

  @override
  String get contributionCategoryLabel => 'Aina';

  @override
  String get contributionAccountingTreatmentLabel => 'Utaratibu wa Uhasibu';

  @override
  String get contributionTypeActiveLabel => 'Inatumika';

  @override
  String get contributionInactiveBadgeLabel => 'Haitumiki';

  @override
  String get contributionDisplayOrderLabel =>
      'Mpangilio wa Kuonyesha (si lazima)';

  @override
  String get contributionFilterActiveOnly => 'Zinazotumika';

  @override
  String get contributionFilterInactiveOnly => 'Hazitumiki';

  @override
  String get contributionCategoryGeneral => 'Jumla';

  @override
  String get contributionCategorySocial => 'Kijamii';

  @override
  String get contributionCategoryShare => 'Hisa';

  @override
  String get contributionTreatmentGroupIncome => 'Pato la Kikundi';

  @override
  String get contributionTreatmentPassThrough => 'Si Pato la Kikundi';

  @override
  String get contributionTreatmentPassThroughHelp =>
      'Fedha hukusanywa kwa kusudi maalum na hazitambuliki kama pato la kawaida la kikundi.';

  @override
  String get contributionTreatmentShareCapital => 'Mtaji wa Hisa';

  @override
  String get contributionTreatmentMemberSavingsUnavailable =>
      'Akiba ya Mwanachama (Haipatikani bado)';

  @override
  String get contributionSetupsTitle => 'Mipangilio ya Michango';

  @override
  String get addContributionSetupAction => 'Ongeza Mpangilio';

  @override
  String get contributionSetupsEmptyTitle => 'Jaza Orodha ya Mipangilio';

  @override
  String get contributionSetupsEmptyMessage =>
      'Ongeza mpangilio wa kwanza wa mchango.';

  @override
  String get contributionSetupsEmptyFilteredTitle =>
      'Hakuna mpangilio uliopatikana';

  @override
  String get contributionSetupsEmptyFilteredMessage =>
      'Jaribu kubadilisha kichujio.';

  @override
  String get editContributionSetupTitle => 'Hariri Mpangilio';

  @override
  String get sectionContributionSetupDetails => 'Taarifa za Mpangilio';

  @override
  String get sectionContributionChargingRules => 'Kanuni za Utozaji';

  @override
  String get sectionContributionDueDateRules => 'Kanuni za Tarehe ya Malipo';

  @override
  String get sectionContributionPenaltyRules => 'Kanuni za Adhabu';

  @override
  String get contributionSetupNameLabel => 'Jina la mpangilio *';

  @override
  String get contributionSetupDescriptionLabel => 'Maelezo (si lazima)';

  @override
  String get contributionSetupTypeLabel => 'Aina ya Mchango';

  @override
  String get contributionScheduleModeLabel => 'Utaratibu wa Muda';

  @override
  String get contributionAmountModeLabel => 'Utaratibu wa Kiasi';

  @override
  String get contributionFixedAmountLabel => 'Kiasi *';

  @override
  String get contributionDefaultDueDayLabel =>
      'Siku ya Mwisho ya Malipo (1–31)';

  @override
  String get contributionDefaultDueMonthOffsetLabel =>
      'Nyongeza ya Mwezi kwa Tarehe ya Mwisho';

  @override
  String get contributionPenaltyModeLabel => 'Utaratibu wa Adhabu';

  @override
  String get contributionPenaltyGraceDaysLabel => 'Siku za Neema';

  @override
  String get contributionPenaltyValueLabel => 'Kiwango cha Adhabu *';

  @override
  String get contributionPenaltyCapAmountLabel =>
      'Kiwango cha Juu cha Adhabu (si lazima)';

  @override
  String get contributionSetupActiveLabel => 'Inatumika';

  @override
  String get contributionScheduleMonthly => 'Kila Mwezi';

  @override
  String get contributionScheduleOnDemand => 'Inapohitajika';

  @override
  String get contributionScheduleOneTime => 'Mara Moja';

  @override
  String get contributionAmountFixed => 'Kiasi Kimoja';

  @override
  String get contributionAmountCustomPerMember =>
      'Kiasi Tofauti kwa Kila Mwanachama';

  @override
  String get contributionPenaltyNone => 'Hakuna';

  @override
  String get contributionPenaltyFixedOnce => 'Kiasi Maalum (Mara Moja)';

  @override
  String get contributionPenaltyFixedRecurring => 'Kiasi Maalum (Kinachorudia)';

  @override
  String get contributionPenaltyPercentageOnce => 'Asilimia (Mara Moja)';

  @override
  String get contributionPenaltyPercentageRecurring => 'Asilimia (Inayorudia)';

  @override
  String get contributionPeriodsTitle => 'Vipindi vya Michango';

  @override
  String get addContributionPeriodAction => 'Ongeza Kipindi';

  @override
  String get contributionPeriodsEmptyTitle => 'Jaza Orodha ya Vipindi';

  @override
  String get contributionPeriodsEmptyMessage =>
      'Ongeza kipindi cha kwanza cha mchango.';

  @override
  String get contributionPeriodsEmptyFilteredTitle =>
      'Hakuna kipindi kilichopatikana';

  @override
  String get contributionPeriodsEmptyFilteredMessage =>
      'Jaribu kubadilisha kichujio.';

  @override
  String get contributionPeriodStatusDraft => 'Rasimu';

  @override
  String get contributionPeriodStatusScheduled => 'Imepangwa';

  @override
  String get contributionPeriodStatusOpen => 'Iko Wazi';

  @override
  String get contributionPeriodStatusClosed => 'Imefungwa';

  @override
  String get contributionPeriodStatusCancelled => 'Imesitishwa';

  @override
  String get newContributionPeriodTitle => 'Kipindi Kipya cha Mchango';

  @override
  String get contributionPeriodSetupLabel => 'Mpangilio wa Mchango *';

  @override
  String get contributionPeriodLabelLabel => 'Jina la Kipindi *';

  @override
  String get contributionPeriodMonthLabel => 'Mwezi';

  @override
  String get contributionPeriodYearLabel => 'Mwaka';

  @override
  String get contributionMonthJanuary => 'Januari';

  @override
  String get contributionMonthFebruary => 'Februari';

  @override
  String get contributionMonthMarch => 'Machi';

  @override
  String get contributionMonthApril => 'Aprili';

  @override
  String get contributionMonthMay => 'Mei';

  @override
  String get contributionMonthJune => 'Juni';

  @override
  String get contributionMonthJuly => 'Julai';

  @override
  String get contributionMonthAugust => 'Agosti';

  @override
  String get contributionMonthSeptember => 'Septemba';

  @override
  String get contributionMonthOctober => 'Oktoba';

  @override
  String get contributionMonthNovember => 'Novemba';

  @override
  String get contributionMonthDecember => 'Desemba';

  @override
  String get contributionPeriodStartLabel => 'Tarehe ya Kuanza';

  @override
  String get contributionPeriodEndLabel => 'Tarehe ya Mwisho';

  @override
  String get contributionPeriodCreatedTitle => 'Kipindi Kimetengenezwa';

  @override
  String contributionPeriodCreatedDueDateMessage(String date) {
    return 'Tarehe ya mwisho ya malipo: $date';
  }

  @override
  String get contributionPeriodDetailTitle => 'Kipindi cha Mchango';

  @override
  String get editContributionPeriodTitle => 'Hariri Kipindi';

  @override
  String get sectionContributionPeriodDates => 'Tarehe Muhimu';

  @override
  String get contributionObligationDateLabel => 'Tarehe ya Wajibu';

  @override
  String get contributionEligibilityDateLabel => 'Tarehe ya Ustahiki';

  @override
  String get contributionDueDateLabel => 'Tarehe ya Mwisho ya Malipo';

  @override
  String get contributionScheduledOpenDateLabel =>
      'Tarehe ya Kufungua Iliyopangwa';

  @override
  String get sectionContributionSnapshot => 'Taarifa Zilizohifadhiwa';

  @override
  String get sectionContributionSummary => 'Muhtasari';

  @override
  String get contributionExcludedCountLabel => 'Waliotolewa';

  @override
  String get contributionCustomAmountCountLabel => 'Waliowekewa Kiasi Maalum';

  @override
  String get contributionTotalMembersChargedLabel => 'Waliotozwa';

  @override
  String get contributionTotalBaseAssessedLabel => 'Jumla Iliyotozwa';

  @override
  String get contributionTotalPenaltyAssessedLabel =>
      'Jumla ya Adhabu Zilizotozwa';

  @override
  String get contributionPenaltyChargeCountLabel => 'Malipo Yenye Adhabu';

  @override
  String get contributionNoPenaltyPolicyMessage =>
      'Hakuna kanuni ya adhabu iliyowekwa kwa kipindi hiki.';

  @override
  String get editExclusionsAction => 'Simamia Walioondolewa';

  @override
  String get configureCustomAmountsAction => 'Weka Kiasi kwa Kila Mwanachama';

  @override
  String get previewAndOpenAction => 'Hakiki na Fungua';

  @override
  String get cancelPeriodAction => 'Sitisha Kipindi';

  @override
  String get viewChargesAction => 'Angalia Madeni';

  @override
  String get enrollMemberAction => 'Andikisha Mwanachama';

  @override
  String get closePeriodAction => 'Funga Kipindi';

  @override
  String get cancelPeriodConfirmTitle => 'Sitisha kipindi hiki?';

  @override
  String get cancelPeriodConfirmMessage => 'Hatua hii haiwezi kutenduliwa.';

  @override
  String get closePeriodConfirmTitle => 'Funga kipindi hiki?';

  @override
  String get closePeriodConfirmMessage =>
      'Baada ya kufungwa, wanachama wapya wataweza kuongezwa tu kwa kuandikishwa mmoja mmoja.';

  @override
  String get periodCancelledMessage => 'Kipindi kimesitishwa.';

  @override
  String get periodClosedMessage => 'Kipindi kimefungwa.';

  @override
  String get periodOpenedMessage => 'Kipindi kimefunguliwa.';

  @override
  String get assessPenaltiesAction => 'Tathmini Adhabu';

  @override
  String get assessPenaltiesConfirmTitle => 'Tathmini adhabu za kipindi hiki?';

  @override
  String get assessPenaltiesConfirmMessage =>
      'Hii itaangalia kila malipo yaliyochelewa na kutoza adhabu yoyote mpya inayostahili. Ni salama kuendesha tena — haitaweka adhabu mara mbili.';

  @override
  String get assessPenaltiesResultTitle => 'Adhabu Zimetathminiwa';

  @override
  String assessPenaltiesResultCreatedCount(Object count) {
    return 'Adhabu Mpya Zilizowekwa: $count';
  }

  @override
  String assessPenaltiesResultAlreadyCurrentCount(Object count) {
    return 'Zilizokuwa Sahihi Tayari: $count';
  }

  @override
  String get assessPenaltiesResultTotalThisRun => 'Jumla ya Adhabu Mpya';

  @override
  String get openPreviewTitle => 'Hakiki Kufungua Kipindi';

  @override
  String openPreviewEligibleCount(int count) {
    return 'Wanachama Wanaostahili: $count';
  }

  @override
  String openPreviewExcludedCount(int count) {
    return 'Wanachama Walioondolewa: $count';
  }

  @override
  String openPreviewMissingAmountCount(int count) {
    return 'Wanaokosa Kiasi: $count';
  }

  @override
  String get openPreviewExpectedTotal => 'Jumla Itakayotozwa';

  @override
  String get openPreviewMissingAmountWarning =>
      'Weka kiasi kwa wanachama wote kabla ya kufungua kipindi hiki.';

  @override
  String get openPreviewConfirmTitle => 'Fungua kipindi hiki?';

  @override
  String get openPreviewConfirmMessage =>
      'Hatua hii itatoza malipo kwa wanachama wote wanaostahili na haiwezi kutenduliwa.';

  @override
  String get openPreviewConfirmButton => 'Fungua Kipindi';

  @override
  String get sectionEligibleMembers => 'Wanachama Wanaostahili';

  @override
  String get sectionExcludedMembers => 'Wanachama Walioondolewa';

  @override
  String get sectionMissingAmountMembers => 'Wanaokosa Kiasi';

  @override
  String get customAmountEditorTitle => 'Weka Kiasi kwa Kila Mwanachama';

  @override
  String get customAmountFieldLabel => 'Kiasi';

  @override
  String get customAmountMissingBadge => 'Haijawekwa';

  @override
  String get customAmountSaveAction => 'Hifadhi Kiasi';

  @override
  String get customAmountSavedMessage => 'Kiasi vimehifadhiwa.';

  @override
  String get customAmountSearchHint => 'Tafuta mwanachama';

  @override
  String get exclusionsScreenTitle => 'Simamia Walioondolewa';

  @override
  String get exclusionSheetTitle => 'Ondoa kwenye Kipindi Hiki';

  @override
  String get exclusionReasonLabel => 'Sababu (si lazima)';

  @override
  String get excludeMemberAction => 'Ondoa kwenye Kipindi Hiki';

  @override
  String get removeExclusionAction => 'Rudisha kwenye Kipindi';

  @override
  String get memberExcludedMessage =>
      'Mwanachama ameondolewa kwenye kipindi hiki.';

  @override
  String get memberExclusionRemovedMessage =>
      'Mwanachama amerudishwa kwenye kipindi hiki.';

  @override
  String get contributionExclusionReasonSuspended => 'Amesitishwa';

  @override
  String get contributionExclusionReasonExited => 'Ametoka';

  @override
  String get contributionExclusionReasonJoinedAfterEligibility =>
      'Alijiunga baada ya tarehe ya ustahiki';

  @override
  String get contributionExclusionReasonExitedDuringPeriod =>
      'Alitoka na kurudi wakati wa kipindi';

  @override
  String get contributionExclusionReasonExcludedDefault => 'Ameondolewa';

  @override
  String get chargesListTitle => 'Malipo Yaliyotozwa';

  @override
  String get chargesSearchHint => 'Tafuta mwanachama';

  @override
  String get chargesEmptyTitle => 'Hakuna Malipo Bado';

  @override
  String get chargesEmptyMessage =>
      'Hakuna mwanachama aliyetozwa kwenye kipindi hiki bado.';

  @override
  String get chargeBaseAmountLabel => 'Kiasi Kilichowekwa';

  @override
  String get chargePenaltyAmountLabel => 'Adhabu';

  @override
  String get chargeTotalAmountLabel => 'Jumla';

  @override
  String get enrollMemberTitle => 'Andikisha Mwanachama';

  @override
  String get enrollMemberSearchHint => 'Tafuta mwanachama';

  @override
  String get enrollMemberAmountLabel => 'Kiasi *';

  @override
  String get enrollMemberSuccessMessage =>
      'Mwanachama ameandikishwa kwenye kipindi.';

  @override
  String get enrollMemberEmptyResults => 'Hakuna mwanachama aliyepatikana';

  @override
  String get contributionErrorNameRequired => 'Jina linahitajika.';

  @override
  String get contributionErrorMemberSavingsNotAvailable =>
      'Akiba ya mwanachama haipatikani bado.';

  @override
  String get contributionErrorAccountingLocked =>
      'Aina na utaratibu wa uhasibu haviwezi kubadilishwa baada ya kipindi kufunguliwa.';

  @override
  String get contributionErrorSetupConfigLocked =>
      'Mpangilio huu umefungwa baada ya kipindi kufunguliwa.';

  @override
  String get contributionErrorTypeInactive => 'Aina hii ya mchango haitumiki.';

  @override
  String get contributionErrorSetupInactive => 'Mpangilio huu haitumiki.';

  @override
  String get contributionErrorDuplicateName =>
      'Jina hilo tayari linatumika kwenye kikundi hiki.';

  @override
  String get contributionErrorInvalidDates => 'Tarehe za kipindi si sahihi.';

  @override
  String get contributionErrorDueDateRequired =>
      'Tarehe ya mwisho ya malipo inahitajika.';

  @override
  String get contributionErrorDuplicateMonthlyPeriod =>
      'Kipindi cha mwezi huu tayari kipo.';

  @override
  String get contributionErrorPeriodNotEditable =>
      'Kipindi hiki hakiwezi kuhaririwa tena.';

  @override
  String get contributionErrorSetupNotCustomAmount =>
      'Mpangilio huu hautumii kiasi tofauti kwa kila mwanachama.';

  @override
  String get contributionErrorMembershipNotFound => 'Mwanachama hakupatikana.';

  @override
  String get contributionErrorInvalidAmount =>
      'Kiasi lazima kiwe zaidi ya sifuri.';

  @override
  String get contributionErrorPeriodNotPreviewable =>
      'Kipindi hiki hakiwezi kuhakikiwa kwa sasa.';

  @override
  String get contributionErrorPeriodNotOpenable =>
      'Kipindi hiki hakiwezi kufunguliwa kwa sasa.';

  @override
  String get contributionErrorMissingCustomAmounts =>
      'Baadhi ya wanachama wanaostahili hawana kiasi kilichowekwa.';

  @override
  String get contributionErrorPeriodNotOpen => 'Kipindi hiki halijafunguliwa.';

  @override
  String get contributionErrorMemberAlreadyCharged =>
      'Mwanachama huyu tayari ametozwa kwenye kipindi hiki.';

  @override
  String get contributionErrorAmountRequired => 'Kiasi kinahitajika.';

  @override
  String get contributionErrorPeriodNotCancellable =>
      'Kipindi hiki hakiwezi kusitishwa tena.';

  @override
  String get contributionErrorNotFound => 'Haikupatikana.';

  @override
  String get contributionErrorNoPenaltyPolicy =>
      'Kipindi hiki hakina kanuni ya adhabu iliyowekwa.';

  @override
  String get contributionErrorPermissionDenied =>
      'Huna ruhusa ya kufanya hivyo.';

  @override
  String get contributionErrorNetwork =>
      'Imeshindikana kuunganisha. Jaribu tena.';

  @override
  String get contributionErrorUnexpected => 'Hitilafu imetokea. Jaribu tena.';

  @override
  String get contributionErrorAdjustmentAmountRequired =>
      'Kiasi cha marekebisho kinahitajika na hakiwezi kuwa sifuri.';

  @override
  String get contributionErrorAdjustmentReasonRequired =>
      'Sababu ya marekebisho inahitajika.';

  @override
  String get contributionErrorAdjustmentWouldMakeObligationNegative =>
      'Marekebisho haya yangefanya deni kuwa hasi.';

  @override
  String get contributionErrorWaiverAmountMustBePositive =>
      'Kiasi cha msamaha lazima kiwe zaidi ya sifuri.';

  @override
  String get contributionErrorWaiverReasonRequired =>
      'Sababu ya msamaha inahitajika.';

  @override
  String get contributionErrorWaiverExceedsNetAssessed =>
      'Msamaha huu unazidi jumla ya deni lililowekwa kwa sasa.';

  @override
  String get contributionErrorOpeningBalanceAmountMustBePositive =>
      'Kiasi cha deni la mwanzo lazima kiwe zaidi ya sifuri.';

  @override
  String get contributionErrorOpeningBalanceAlreadyImported =>
      'Deni la mwanzo la mwanachama huyu tayari limeingizwa.';

  @override
  String get contributionComponentBase => 'Deni Msingi';

  @override
  String get contributionComponentPenalty => 'Adhabu';

  @override
  String get contributionComponentAdjustment => 'Marekebisho';

  @override
  String get contributionComponentWaiver => 'Msamaha wa Deni';

  @override
  String get contributionComponentOpeningBalance => 'Deni la Mwanzo';

  @override
  String get contributionComponentReasonLabel => 'Sababu';

  @override
  String get contributionComponentDateLabel => 'Tarehe';

  @override
  String get contributionNetAssessedLabel => 'Jumla ya Deni Lililowekwa';

  @override
  String get contributionCurrentNetAssessedLabel => 'Deni la Sasa Lililowekwa';

  @override
  String get contributionEffectiveDateFieldLabel => 'Tarehe Itakayotumika';

  @override
  String get chargeDetailTitle => 'Maelezo ya Malipo';

  @override
  String get sectionChargeBreakdown => 'Mchanganuo wa Malipo';

  @override
  String get addAdjustmentAction => 'Ongeza Marekebisho';

  @override
  String get waiveObligationAction => 'Samehe Deni';

  @override
  String get viewMemberSummaryAction => 'Ona Muhtasari wa Mwanachama';

  @override
  String get memberSummaryTitle => 'Muhtasari wa Deni la Mwanachama';

  @override
  String get addAdjustmentTitle => 'Ongeza Marekebisho';

  @override
  String get adjustmentDirectionLabel => 'Aina ya Marekebisho';

  @override
  String get adjustmentIncreaseOption => 'Ongeza Deni';

  @override
  String get adjustmentReduceOption => 'Punguza Deni';

  @override
  String get adjustmentAmountFieldLabel => 'Kiasi *';

  @override
  String get adjustmentReasonFieldLabel => 'Sababu *';

  @override
  String get adjustmentSubmitAction => 'Wasilisha Marekebisho';

  @override
  String get adjustmentSuccessMessage => 'Marekebisho yamewekwa.';

  @override
  String get waiveObligationTitle => 'Samehe Deni';

  @override
  String get waiverTypeLabel => 'Aina ya Msamaha';

  @override
  String get waiverPartialOption => 'Sehemu';

  @override
  String get waiverFullOption => 'Yote';

  @override
  String get waiverAmountFieldLabel => 'Kiasi cha Kusamehe *';

  @override
  String get waiverReasonFieldLabel => 'Sababu *';

  @override
  String get waiverMaximumLabel => 'Kiwango cha Juu cha Msamaha';

  @override
  String get waiverRemainingAfterLabel => 'Itakayobaki Baada ya Msamaha';

  @override
  String get waiverSubmitAction => 'Wasilisha Msamaha';

  @override
  String get waiverSuccessMessage => 'Deni limesamehewa.';

  @override
  String get openingBalancesEntryTitle => 'Madeni ya Mwanzo';

  @override
  String get openingBalancesEntrySubtitle =>
      'Ingiza madeni ya wanachama kabla ya Umoja';

  @override
  String get openingBalancesTitle => 'Madeni ya Mwanzo';

  @override
  String get openingBalancesEmptyTitle => 'Hakuna Deni la Mwanzo';

  @override
  String get openingBalancesEmptyMessage =>
      'Bado hakuna deni la mwanzo lililoingizwa.';

  @override
  String get openingBalanceImportAction => 'Ingiza Madeni ya Mwanzo';

  @override
  String get openingBalanceImportTitle => 'Ingiza Madeni ya Mwanzo';

  @override
  String get openingBalanceContributionTypeLabel => 'Aina ya Mchango';

  @override
  String get openingBalanceEffectiveDateLabel => 'Tarehe ya Mwanzo';

  @override
  String get openingBalanceSearchHint => 'Tafuta mwanachama';

  @override
  String get openingBalanceAmountFieldLabel => 'Kiasi';

  @override
  String get openingBalancePreviewAction => 'Hakiki';

  @override
  String get openingBalanceMemberCountLabel => 'Idadi ya Wanachama';

  @override
  String get openingBalanceTotalLabel => 'Jumla ya Deni la Mwanzo';

  @override
  String get openingBalanceAlreadyImportedBadge => 'Tayari Imeingizwa';

  @override
  String get openingBalanceConfirmImportAction => 'Thibitisha Kuingiza';

  @override
  String get openingBalanceImportSuccessMessage =>
      'Madeni ya mwanzo yameingizwa.';

  @override
  String get openingBalanceCannotImportMessage =>
      'Baadhi ya wanachama tayari wana deni la mwanzo. Ondoa au badilisha kiasi chao kabla ya kuendelea.';

  @override
  String get financialAccountsTitle => 'Akaunti za Fedha';

  @override
  String get homeFinancialAccountsShortcutSubtitle =>
      'Fedha taslimu, benki na pesa za simu';

  @override
  String get financialAccountsEmptyTitle => 'Hakuna Akaunti za Fedha';

  @override
  String get financialAccountsEmptyMessage =>
      'Bado hakuna akaunti ya fedha iliyoundwa.';

  @override
  String get financialAccountsSearchHint => 'Tafuta akaunti';

  @override
  String get financialAccountNewAction => 'Ongeza Akaunti';

  @override
  String get financialAccountNewTitle => 'Akaunti Mpya ya Fedha';

  @override
  String get sectionFinancialAccountDetails => 'Maelezo ya Akaunti';

  @override
  String get financialAccountEditTitle => 'Hariri Akaunti ya Fedha';

  @override
  String get financialAccountNameFieldLabel => 'Jina la Akaunti *';

  @override
  String get financialAccountTypeFieldLabel => 'Aina ya Akaunti';

  @override
  String get financialAccountTypeCash => 'Taslimu';

  @override
  String get financialAccountTypeBank => 'Benki';

  @override
  String get financialAccountTypeMobileMoney => 'Pesa ya Simu';

  @override
  String get financialAccountOpeningBalanceFieldLabel =>
      'Salio la Mwanzo (si lazima)';

  @override
  String get financialAccountOpeningBalanceDateLabel =>
      'Tarehe ya Salio la Mwanzo';

  @override
  String get financialAccountSavedMessage => 'Akaunti ya fedha imehifadhiwa.';

  @override
  String get financialAccountBalanceLabel => 'Salio';

  @override
  String get financialAccountActiveBadge => 'Inatumika';

  @override
  String get financialAccountInactiveBadge => 'Haitumiki';

  @override
  String get financialAccountActivateAction => 'Washa Akaunti';

  @override
  String get financialAccountDeactivateAction => 'Zima Akaunti';

  @override
  String get financialAccountEditAction => 'Hariri';

  @override
  String get financialAccountEntriesTitle => 'Miamala';

  @override
  String get financialAccountEntriesEmptyMessage =>
      'Bado hakuna miamala kwenye akaunti hii.';

  @override
  String get financialAccountEntryTypeInflow => 'Kuingia';

  @override
  String get financialAccountEntryTypeOutflow => 'Kutoka';

  @override
  String get financialAccountEntryTypeTransferIn => 'Uhamisho Ulioingia';

  @override
  String get financialAccountEntryTypeTransferOut => 'Uhamisho Ulioondoka';

  @override
  String get financialAccountTransferAction => 'Hamisha Fedha';

  @override
  String financialAccountTransferToLedgerLabel(Object accountName) {
    return 'Uhamisho kwenda $accountName';
  }

  @override
  String financialAccountTransferFromLedgerLabel(Object accountName) {
    return 'Uhamisho kutoka $accountName';
  }

  @override
  String get financialAccountTransferTitle => 'Hamisha Fedha Kati ya Akaunti';

  @override
  String get financialAccountTransferFromLabel => 'Kutoka Akaunti';

  @override
  String get financialAccountTransferToLabel => 'Kwenda Akaunti';

  @override
  String get financialAccountTransferAmountLabel => 'Kiasi *';

  @override
  String get financialAccountTransferDescriptionFieldLabel =>
      'Maelezo (si lazima)';

  @override
  String get financialAccountTransferSuccessMessage => 'Uhamisho umefanikiwa.';

  @override
  String get financialAccountTransferSubmitAction => 'Hamisha';

  @override
  String get financialAccountErrorNameRequired =>
      'Jina la akaunti linahitajika.';

  @override
  String get financialAccountErrorDuplicateName =>
      'Jina hilo la akaunti tayari linatumika kwenye kikundi hiki.';

  @override
  String get financialAccountErrorOpeningBalanceMustBePositive =>
      'Salio la mwanzo lazima liwe zaidi ya sifuri.';

  @override
  String get financialAccountErrorNotFound => 'Akaunti ya fedha haikupatikana.';

  @override
  String get financialAccountErrorTransferSameAccount =>
      'Haiwezekani kuhamisha fedha kwenye akaunti ile ile.';

  @override
  String get financialAccountErrorTransferAmountMustBePositive =>
      'Kiasi cha kuhamisha lazima kiwe zaidi ya sifuri.';

  @override
  String get financialAccountErrorInsufficientBalance =>
      'Akaunti ya kutoa haina salio la kutosha kwa uhamisho huu.';

  @override
  String get financialAccountErrorAccountInactive =>
      'Akaunti hii ya fedha haitumiki.';

  @override
  String get financialAccountErrorEffectiveDateRequired =>
      'Tarehe ya uhamisho inahitajika.';

  @override
  String get financialAccountErrorPermissionDenied =>
      'Huna ruhusa ya kufanya hivyo.';

  @override
  String get financialAccountErrorNetwork =>
      'Imeshindikana kuunganisha. Jaribu tena.';

  @override
  String get financialAccountErrorUnexpected =>
      'Hitilafu imetokea. Jaribu tena.';

  @override
  String get supabaseConfigMissing =>
      'Mipangilio ya Supabase haipo (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY haijawekwa).';

  @override
  String get backAction => 'Rudi';

  @override
  String get doneAction => 'Imekamilika';

  @override
  String get paymentsEntryTitle => 'Malipo';

  @override
  String get paymentsEntrySubtitle => 'Tazama historia ya malipo yote';

  @override
  String get recordPaymentEntryTitle => 'Rekodi Malipo';

  @override
  String get recordPaymentEntrySubtitle =>
      'Rekodi malipo ya nje kutoka kwa mwanachama';

  @override
  String get memberWalletEntryTitle => 'Salio la Mwanachama';

  @override
  String get memberWalletEntrySubtitle => 'Tazama na tumia salio la mwanachama';

  @override
  String get paymentsTitle => 'Malipo';

  @override
  String get paymentsSearchHint => 'Tafuta malipo';

  @override
  String get paymentsEmptyTitle => 'Hakuna Malipo';

  @override
  String get paymentsEmptyMessage => 'Bado hakuna malipo yaliyorekodiwa.';

  @override
  String get recordPaymentAction => 'Rekodi Malipo';

  @override
  String get paymentMethodCash => 'Taslimu';

  @override
  String get paymentMethodBankTransfer => 'Uhamisho wa Benki';

  @override
  String get paymentMethodMobileMoney => 'Pesa za Simu';

  @override
  String get paymentMethodOther => 'Nyingine';

  @override
  String get paymentStatusPosted => 'Imerekodiwa';

  @override
  String get paymentStatusReversed => 'Imebatilishwa';

  @override
  String get walletEntryTypePaymentCredit => 'Salio kutoka malipo';

  @override
  String get walletEntryTypeAllocationDebit => 'Salio limetumika kulipa deni';

  @override
  String get walletEntryTypeReversal => 'Salio limerudishwa';

  @override
  String walletEntrySourceReceiptLabel(Object receiptNumber) {
    return 'Risiti $receiptNumber';
  }

  @override
  String get memberPickerSearchHint => 'Tafuta mwanachama';

  @override
  String get memberPickerEmptyTitle => 'Hakuna Mwanachama';

  @override
  String get memberPickerEmptyMessage =>
      'Hakuna mwanachama aliyepatikana kwa utafutaji huu.';

  @override
  String get paymentAmountInvalidError =>
      'Weka kiasi sahihi, mwanachama, na akaunti ya fedha.';

  @override
  String get recordPaymentTitle => 'Rekodi Malipo';

  @override
  String get recordPaymentAmountLabel => 'Kiasi *';

  @override
  String get recordPaymentDateLabel => 'Tarehe';

  @override
  String get recordPaymentMethodLabel => 'Njia ya Malipo';

  @override
  String get recordPaymentAccountLabel => 'Akaunti ya Fedha';

  @override
  String get recordPaymentReferenceLabel => 'Kumbukumbu ya Nje (si lazima)';

  @override
  String get recordPaymentNotesLabel => 'Maelezo (si lazima)';

  @override
  String get recordPaymentPreviewAction => 'Onyesha Mgawanyo';

  @override
  String get recordPaymentConfirmAction => 'Thibitisha Malipo';

  @override
  String get recordPaymentSuccessMessage => 'Malipo yamerekodiwa kikamilifu.';

  @override
  String get paymentPreviewAmountLabel => 'Kiasi cha Malipo';

  @override
  String get paymentPreviewWillSettleLabel => 'Mgawanyo wa Malipo';

  @override
  String get paymentPreviewNoOutstandingMessage =>
      'Hakuna deni lililobaki la kulipa.';

  @override
  String get paymentPreviewTotalAllocatedLabel => 'Kinalipa Madeni';

  @override
  String get paymentPreviewWalletRemainingLabel => 'Salio Litakalobaki';

  @override
  String get paymentPreviewAccountLabel => 'Akaunti ya Fedha Itakayopokea';

  @override
  String get viewReceiptAction => 'Tazama Risiti';

  @override
  String get receiptTitle => 'Risiti';

  @override
  String get receiptMemberLabel => 'Mwanachama';

  @override
  String get paymentDetailTitle => 'Maelezo ya Malipo';

  @override
  String get paymentAmountLabel => 'Kiasi';

  @override
  String get paymentAllocationsTitle => 'Mgawanyo wa Malipo';

  @override
  String get reversalReasonLabel => 'Sababu ya Kubatilisha *';

  @override
  String get reversePaymentAction => 'Batili Malipo';

  @override
  String get reversePaymentTitle => 'Batili Malipo';

  @override
  String get reversePaymentWarningMessage =>
      'Kitendo hiki hakiwezi kutenduliwa. Malipo asilia yatabaki kwenye kumbukumbu, lakini deni litarudi kuwa halijalipwa.';

  @override
  String get reversePaymentConfirmAction => 'Thibitisha Kubatilisha';

  @override
  String get reversePaymentSuccessMessage => 'Malipo yamebatilishwa.';

  @override
  String get memberWalletTitle => 'Salio la Mwanachama';

  @override
  String get walletBalanceLabel => 'Salio la Sasa';

  @override
  String get walletHistoryTitle => 'Historia ya Salio';

  @override
  String get walletHistoryEmptyMessage => 'Bado hakuna historia ya salio.';

  @override
  String get allocateWalletAction => 'Tumia Salio';

  @override
  String get allocateWalletTitle => 'Tumia Salio la Mwanachama';

  @override
  String get allocateWalletSuccessMessage => 'Salio limetumika kulipa deni.';

  @override
  String get paymentErrorAmountMustBePositive =>
      'Kiasi lazima kiwe zaidi ya sifuri.';

  @override
  String get paymentErrorFinancialAccountInactive =>
      'Akaunti hii ya fedha haifanyi kazi.';

  @override
  String get paymentErrorIdempotencyKeyConflict =>
      'Ombi hili linagongana na lililotangulia. Tafadhali onyesha upya na ujaribu tena.';

  @override
  String get paymentErrorAlreadyReversed =>
      'Malipo haya tayari yamebatilishwa.';

  @override
  String get paymentErrorReversalBlockedWalletCreditConsumed =>
      'Malipo haya hayawezi kubatilishwa: salio la mwanachama lililoongezwa tayari limetumika.';

  @override
  String get paymentErrorReversalReasonRequired =>
      'Sababu ya kubatilisha inahitajika.';

  @override
  String get paymentErrorWalletInsufficientBalance =>
      'Salio la mwanachama halitoshi kwa mgawanyo huu.';

  @override
  String get paymentErrorWalletNothingToAllocate =>
      'Hakuna deni lililobaki la kutumia salio hili dhidi yake.';

  @override
  String get paymentErrorNotFound => 'Haipatikani.';

  @override
  String get paymentErrorPermissionDenied => 'Huna ruhusa ya kufanya hivyo.';

  @override
  String get paymentErrorNetwork => 'Imeshindikana kuunganisha. Jaribu tena.';

  @override
  String get paymentErrorUnexpected => 'Hitilafu imetokea. Jaribu tena.';

  @override
  String get paymentSummaryOutstandingLabel => 'Deni Lililobaki';

  @override
  String get outstandingObligationsSectionTitle => 'Madeni Yaliyobaki';

  @override
  String get outstandingObligationsEmptyMessage =>
      'Mwanachama hana deni lililobaki.';

  @override
  String get viewAllObligationsAction => 'Angalia Yote';

  @override
  String get sectionCharges => 'Madeni';

  @override
  String get memberChargesTitle => 'Madeni';

  @override
  String get memberChargesTotalAllocatedLabel => 'Malipo Yaliyogawiwa';

  @override
  String get memberChargesEmptyOutstandingMessage => 'Hakuna deni lililobaki.';

  @override
  String get memberChargesEmptyMessage =>
      'Hakuna madeni yanayolingana na kichujio hiki.';

  @override
  String get filterOutstanding => 'Deni Lililobaki';

  @override
  String get filterSettled => 'Imelipwa';

  @override
  String get filterOverdue => 'Imechelewa';

  @override
  String get chargeOutstandingLabel => 'Deni Lililobaki';
}
