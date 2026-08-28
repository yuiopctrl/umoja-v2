// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Umoja';

  @override
  String get continueButton => 'Continue';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get closeButton => 'Close';

  @override
  String get saveButton => 'Save';

  @override
  String get editAction => 'Edit';

  @override
  String get signOutButtonLabel => 'Sign Out';

  @override
  String get languageSelectorLabel => 'Language';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageEnglish => 'English';

  @override
  String get authWelcomeTitle => 'Welcome to Umoja';

  @override
  String get authPhoneSubtitle => 'Enter your phone number to continue.';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authPhoneHint => '0712345678';

  @override
  String get authLoginSubtitle => 'Enter your phone number and PIN.';

  @override
  String get authPinLabel => 'PIN';

  @override
  String get loginButton => 'Log In';

  @override
  String get authFirstTimeLink => 'First time? Verify by OTP';

  @override
  String get otpTitle => 'Verify Number';

  @override
  String otpSubtitle(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get otpCodeLabel => 'Verification code';

  @override
  String get otpVerifyButton => 'Verify';

  @override
  String get otpChangeNumber => 'Change Number';

  @override
  String get otpResend => 'Resend Code';

  @override
  String otpResendCountdown(int seconds) {
    return 'In ${seconds}s';
  }

  @override
  String get pinSetupTitle => 'Create PIN';

  @override
  String get pinSetupSubtitle =>
      'This PIN will be used to sign in to Umoja next time.';

  @override
  String get pinConfirmTitle => 'Confirm PIN';

  @override
  String get pinConfirmSubtitle => 'Enter your PIN again to confirm.';

  @override
  String get pinMismatch => 'PINs don\'t match. Try again.';

  @override
  String get pinSetupSaveError => 'Could not save your PIN. Please try again.';

  @override
  String get pinForgot => 'Forgot PIN?';

  @override
  String get pinRecoveryVerifyTitle => 'Verify Your Number';

  @override
  String get pinRecoveryVerifySubtitle =>
      'Enter the code sent to verify your number.';

  @override
  String pinRecoveryVerifySubtitleWithPhone(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get profileOnboardingTitle => 'Complete Your Profile';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get fullNameRequiredError => 'Enter your full name.';

  @override
  String get phoneReadOnlyLabel => 'Phone';

  @override
  String get profileSaveError =>
      'Could not save your profile. Please try again.';

  @override
  String get groupOnboardingTitle => 'Create Your Group';

  @override
  String get groupOnboardingSubtitle =>
      'You currently have no active group. Create one to continue.';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupDescriptionLabel => 'Description (optional)';

  @override
  String get createGroupButton => 'Create Group';

  @override
  String get groupNameRequiredError => 'Group name is required.';

  @override
  String get groupSaveError => 'Could not create the group. Please try again.';

  @override
  String get homeTitle => 'Home';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleTreasurer => 'Treasurer';

  @override
  String get roleSecretary => 'Secretary';

  @override
  String get roleChairperson => 'Chairperson';

  @override
  String get roleMember => 'Member';

  @override
  String get statusActive => 'Active';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusExited => 'Exited';

  @override
  String get retryButton => 'Retry';

  @override
  String get accountDisabledTitle => 'Account access disabled';

  @override
  String get accountDisabledMessage =>
      'Your account access has been disabled. Contact your group administrator if you believe this is a mistake.';

  @override
  String get contextErrorTitle => 'Unable to load account';

  @override
  String get contextErrorMessage =>
      'We could not load your account. Check your connection and try again.';

  @override
  String get groupClosedTitle => 'Group is closed';

  @override
  String get groupClosedMessage =>
      'This group has been closed and is no longer active.';

  @override
  String get groupSuspendedTitle => 'Group access is suspended';

  @override
  String get groupSuspendedMessage =>
      'This group is currently suspended. Contact the group administrator for more information.';

  @override
  String get membershipRestrictedTitle => 'Membership restricted';

  @override
  String get membershipRestrictedMessage =>
      'Your membership in this group is currently suspended, so it is not available. You can still create a new group.';

  @override
  String get createNewGroupAction => 'Create New Group';

  @override
  String get selectGroupTitle => 'Select a Group';

  @override
  String get noRolesShort => 'No roles';

  @override
  String get homeGreetingPlain => 'Hi';

  @override
  String homeGreetingNamed(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeMembersShortcutSubtitle => 'View and manage group members';

  @override
  String get rolesNone => 'Roles: none';

  @override
  String rolesList(String roles) {
    return 'Roles: $roles';
  }

  @override
  String get membersTitle => 'Members';

  @override
  String get membersSearchHint => 'Search member';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterSuspended => 'Suspended';

  @override
  String get filterExited => 'Exited';

  @override
  String get addMemberAction => 'Add Member';

  @override
  String get membersEmptyFilteredTitle => 'No members found';

  @override
  String get membersEmptyFilteredMessage =>
      'Try changing your search or filter.';

  @override
  String get membersEmptyTitle => 'Build Your Member List';

  @override
  String get membersEmptyMessage => 'Add the group\'s first member.';

  @override
  String get loadMoreAction => 'Show More';

  @override
  String get paginationPrevious => 'Previous';

  @override
  String get paginationNext => 'Next';

  @override
  String paginationPageIndicator(int page, int total) {
    return 'Page $page / $total';
  }

  @override
  String get memberDetailTitle => 'Member';

  @override
  String get sectionIdentity => 'Member Information';

  @override
  String get sectionMembership => 'Membership';

  @override
  String get sectionRoles => 'Roles';

  @override
  String get sectionActions => 'Actions';

  @override
  String get manageRolesAction => 'Manage Roles';

  @override
  String get memberNumberLabel => 'Member number';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get accountLinkedLabel => 'Login account: Linked';

  @override
  String get accountNotLinkedLabel => 'Login account: Not linked';

  @override
  String get joinedLabel => 'Joined';

  @override
  String get exitedLabel => 'Exited';

  @override
  String get noRolesAssigned => 'No roles assigned.';

  @override
  String get suspendButton => 'Suspend';

  @override
  String get reactivateButton => 'Reactivate';

  @override
  String get markExitedButton => 'Mark as Exited';

  @override
  String get rejoinButton => 'Rejoin Group';

  @override
  String get suspendConfirmTitle => 'Suspend member?';

  @override
  String get suspendConfirmMessage =>
      'This member will not be able to participate in group activities until reactivated.';

  @override
  String get exitConfirmTitle => 'Mark this member as exited?';

  @override
  String get exitConfirmMessage => 'This action cannot be undone here.';

  @override
  String get reactivateConfirmTitle => 'Reactivate member?';

  @override
  String get reactivateConfirmMessage =>
      'This member will be able to participate in group activities again.';

  @override
  String get rejoinConfirmTitle => 'Rejoin this member to the group?';

  @override
  String get rejoinConfirmMessage =>
      'The member will be able to participate in group activities again, starting today. Their earlier exit history is preserved on record.';

  @override
  String get statusChangeSuccessActive => 'Member reactivated.';

  @override
  String get statusChangeSuccessSuspended => 'Member suspended.';

  @override
  String get statusChangeSuccessExited => 'Member removed from the group.';

  @override
  String get rejoinSuccessMessage => 'Member rejoined the group.';

  @override
  String get refreshFailedMessage =>
      'Could not reload the latest data. It may still show older information.';

  @override
  String get editMemberTitle => 'Edit Member';

  @override
  String get formSectionContact => 'Contact';

  @override
  String get formFullNameLabel => 'Full name *';

  @override
  String get phoneOptionalLabel => 'Phone number (optional)';

  @override
  String get memberNumberAutoNote =>
      'The member number will be generated automatically.';

  @override
  String get memberNameRequiredError => 'Full name is required.';

  @override
  String get memberSaveError => 'Could not save the member. Please try again.';

  @override
  String get rolesSheetSubtitle => 'Choose this member\'s roles.';

  @override
  String get moreTitle => 'More';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get currentGroupSectionTitle => 'Current Group';

  @override
  String get actionsSectionTitle => 'Actions';

  @override
  String get securitySectionTitle => 'Security';

  @override
  String get switchGroupAction => 'Switch Group';

  @override
  String get authErrorInvalidPhone =>
      'That phone number could not be used. Please check it and try again.';

  @override
  String get authErrorInvalidOtp =>
      'That code is not correct. Please check and try again.';

  @override
  String get authErrorOtpExpired => 'This code has expired. Request a new one.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get authErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get authErrorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get authErrorInvalidCredentials => 'Phone number or PIN is incorrect.';

  @override
  String get authErrorPinLocked => 'Try again in a few minutes.';

  @override
  String get memberErrorAccountDisabled =>
      'Your account access has been disabled. Contact your group administrator.';

  @override
  String get memberErrorLastAdminRequired =>
      'The group must keep at least one active administrator.';

  @override
  String get memberErrorInvalidStatusTransition =>
      'This member has already exited and cannot be reactivated this way.';

  @override
  String get memberErrorDuplicateMemberNumber =>
      'That member number is already used in this group.';

  @override
  String get memberErrorPermissionDenied =>
      'You do not have permission to do that.';

  @override
  String get memberErrorNotFound => 'Member not found.';

  @override
  String get memberErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get memberErrorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get memberErrorRejoinConflict =>
      'This member already has another active membership in this group.';

  @override
  String get contributionsTitle => 'Contributions';

  @override
  String get homeContributionsShortcutSubtitle =>
      'View and manage group contributions';

  @override
  String get contributionTypesEntryTitle => 'Contribution Types';

  @override
  String get contributionTypesEntrySubtitle =>
      'Manage the group\'s contribution types';

  @override
  String get contributionSetupsEntryTitle => 'Contribution Setups';

  @override
  String get contributionSetupsEntrySubtitle =>
      'Manage how contributions are charged';

  @override
  String get contributionPeriodsEntryTitle => 'Contribution Periods';

  @override
  String get contributionPeriodsEntrySubtitle =>
      'Manage contribution periods and charges';

  @override
  String get contributionTypesTitle => 'Contribution Types';

  @override
  String get contributionTypesSearchHint => 'Search contribution type';

  @override
  String get addContributionTypeAction => 'Add Contribution Type';

  @override
  String get contributionTypesEmptyTitle => 'Build Your Contribution Type List';

  @override
  String get contributionTypesEmptyMessage =>
      'Add the group\'s first contribution type.';

  @override
  String get contributionTypesEmptyFilteredTitle =>
      'No contribution type found';

  @override
  String get contributionTypesEmptyFilteredMessage =>
      'Try changing your search or filter.';

  @override
  String get editContributionTypeTitle => 'Edit Contribution Type';

  @override
  String get sectionContributionTypeDetails => 'Contribution Type Details';

  @override
  String get sectionContributionClassification =>
      'Classification & Accounting Treatment';

  @override
  String get contributionTypeNameLabel => 'Contribution type name *';

  @override
  String get contributionTypeDescriptionLabel => 'Description (optional)';

  @override
  String get contributionCategoryLabel => 'Category';

  @override
  String get contributionAccountingTreatmentLabel => 'Accounting Treatment';

  @override
  String get contributionTypeActiveLabel => 'Active';

  @override
  String get contributionInactiveBadgeLabel => 'Inactive';

  @override
  String get contributionDisplayOrderLabel => 'Display Order (optional)';

  @override
  String get contributionFilterActiveOnly => 'Active';

  @override
  String get contributionFilterInactiveOnly => 'Inactive';

  @override
  String get contributionCategoryGeneral => 'General';

  @override
  String get contributionCategorySocial => 'Social';

  @override
  String get contributionCategoryShare => 'Share';

  @override
  String get contributionTreatmentGroupIncome => 'Group Income';

  @override
  String get contributionTreatmentPassThrough => 'Not Group Income';

  @override
  String get contributionTreatmentPassThroughHelp =>
      'Funds are collected for a specific purpose and are not recognized as ordinary group income.';

  @override
  String get contributionTreatmentShareCapital => 'Share Capital';

  @override
  String get contributionTreatmentMemberSavingsUnavailable =>
      'Member Savings (Not yet available)';

  @override
  String get contributionSetupsTitle => 'Contribution Setups';

  @override
  String get addContributionSetupAction => 'Add Setup';

  @override
  String get contributionSetupsEmptyTitle => 'Build Your Setup List';

  @override
  String get contributionSetupsEmptyMessage =>
      'Add the first contribution setup.';

  @override
  String get contributionSetupsEmptyFilteredTitle => 'No setup found';

  @override
  String get contributionSetupsEmptyFilteredMessage =>
      'Try changing your filter.';

  @override
  String get editContributionSetupTitle => 'Edit Setup';

  @override
  String get sectionContributionSetupDetails => 'Contribution Setup Details';

  @override
  String get sectionContributionChargingRules => 'Charging Rules';

  @override
  String get sectionContributionDueDateRules => 'Due-Date Rules';

  @override
  String get sectionContributionPenaltyRules => 'Penalty Rules';

  @override
  String get contributionSetupNameLabel => 'Setup name *';

  @override
  String get contributionSetupDescriptionLabel => 'Description (optional)';

  @override
  String get contributionSetupTypeLabel => 'Contribution Type';

  @override
  String get contributionScheduleModeLabel => 'Schedule';

  @override
  String get contributionAmountModeLabel => 'Amount Mode';

  @override
  String get contributionFixedAmountLabel => 'Amount *';

  @override
  String get contributionDefaultDueDayLabel => 'Due Day (1–31)';

  @override
  String get contributionDefaultDueMonthOffsetLabel =>
      'Month Offset for Due Date';

  @override
  String get contributionPenaltyModeLabel => 'Penalty Mode';

  @override
  String get contributionPenaltyGraceDaysLabel => 'Grace Days';

  @override
  String get contributionPenaltyValueLabel => 'Penalty Value *';

  @override
  String get contributionPenaltyCapAmountLabel => 'Penalty Cap (optional)';

  @override
  String get contributionSetupActiveLabel => 'Active';

  @override
  String get contributionScheduleMonthly => 'Monthly';

  @override
  String get contributionScheduleOnDemand => 'On Demand';

  @override
  String get contributionScheduleOneTime => 'One Time';

  @override
  String get contributionAmountFixed => 'Single Amount';

  @override
  String get contributionAmountCustomPerMember => 'Custom Amount Per Member';

  @override
  String get contributionPenaltyNone => 'None';

  @override
  String get contributionPenaltyFixedOnce => 'Fixed Amount (Once)';

  @override
  String get contributionPenaltyFixedRecurring => 'Fixed Amount (Recurring)';

  @override
  String get contributionPenaltyPercentageOnce => 'Percentage (Once)';

  @override
  String get contributionPenaltyPercentageRecurring => 'Percentage (Recurring)';

  @override
  String get contributionPeriodsTitle => 'Contribution Periods';

  @override
  String get addContributionPeriodAction => 'Add Period';

  @override
  String get contributionPeriodsEmptyTitle => 'Build Your Period List';

  @override
  String get contributionPeriodsEmptyMessage =>
      'Add the first contribution period.';

  @override
  String get contributionPeriodsEmptyFilteredTitle => 'No period found';

  @override
  String get contributionPeriodsEmptyFilteredMessage =>
      'Try changing your filter.';

  @override
  String get contributionPeriodStatusDraft => 'Draft';

  @override
  String get contributionPeriodStatusScheduled => 'Scheduled';

  @override
  String get contributionPeriodStatusOpen => 'Open';

  @override
  String get contributionPeriodStatusClosed => 'Closed';

  @override
  String get contributionPeriodStatusCancelled => 'Cancelled';

  @override
  String get newContributionPeriodTitle => 'New Contribution Period';

  @override
  String get contributionPeriodSetupLabel => 'Contribution Setup *';

  @override
  String get contributionPeriodLabelLabel => 'Period Label *';

  @override
  String get contributionPeriodMonthLabel => 'Month';

  @override
  String get contributionPeriodYearLabel => 'Year';

  @override
  String get contributionMonthJanuary => 'January';

  @override
  String get contributionMonthFebruary => 'February';

  @override
  String get contributionMonthMarch => 'March';

  @override
  String get contributionMonthApril => 'April';

  @override
  String get contributionMonthMay => 'May';

  @override
  String get contributionMonthJune => 'June';

  @override
  String get contributionMonthJuly => 'July';

  @override
  String get contributionMonthAugust => 'August';

  @override
  String get contributionMonthSeptember => 'September';

  @override
  String get contributionMonthOctober => 'October';

  @override
  String get contributionMonthNovember => 'November';

  @override
  String get contributionMonthDecember => 'December';

  @override
  String get contributionPeriodStartLabel => 'Start Date';

  @override
  String get contributionPeriodEndLabel => 'End Date';

  @override
  String get contributionPeriodCreatedTitle => 'Period Created';

  @override
  String contributionPeriodCreatedDueDateMessage(String date) {
    return 'Due date: $date';
  }

  @override
  String get contributionPeriodDetailTitle => 'Contribution Period';

  @override
  String get editContributionPeriodTitle => 'Edit Contribution Period';

  @override
  String get sectionContributionPeriodDates => 'Key Dates';

  @override
  String get contributionObligationDateLabel => 'Obligation Date';

  @override
  String get contributionEligibilityDateLabel => 'Eligibility Date';

  @override
  String get contributionDueDateLabel => 'Due Date';

  @override
  String get contributionScheduledOpenDateLabel => 'Scheduled Open Date';

  @override
  String get sectionContributionSnapshot => 'Recorded Configuration';

  @override
  String get sectionContributionSummary => 'Summary';

  @override
  String get contributionExcludedCountLabel => 'Excluded';

  @override
  String get contributionCustomAmountCountLabel => 'With Custom Amount Set';

  @override
  String get contributionTotalMembersChargedLabel => 'Members Charged';

  @override
  String get contributionTotalBaseAssessedLabel => 'Total Assessed';

  @override
  String get contributionTotalPenaltyAssessedLabel =>
      'Total Penalties Assessed';

  @override
  String get contributionPenaltyChargeCountLabel => 'Charges With a Penalty';

  @override
  String get contributionNoPenaltyPolicyMessage =>
      'No penalty policy is configured for this period.';

  @override
  String get editExclusionsAction => 'Manage Exclusions';

  @override
  String get configureCustomAmountsAction => 'Set Per-Member Amounts';

  @override
  String get previewAndOpenAction => 'Preview & Open';

  @override
  String get cancelPeriodAction => 'Cancel Period';

  @override
  String get viewChargesAction => 'View Charges';

  @override
  String get enrollMemberAction => 'Enroll Member';

  @override
  String get closePeriodAction => 'Close Period';

  @override
  String get cancelPeriodConfirmTitle => 'Cancel this period?';

  @override
  String get cancelPeriodConfirmMessage => 'This action cannot be undone.';

  @override
  String get closePeriodConfirmTitle => 'Close this period?';

  @override
  String get closePeriodConfirmMessage =>
      'After closing, new members can only be added by enrolling them individually.';

  @override
  String get periodCancelledMessage => 'Period cancelled.';

  @override
  String get periodClosedMessage => 'Period closed.';

  @override
  String get periodOpenedMessage => 'Period opened.';

  @override
  String get assessPenaltiesAction => 'Assess Penalties';

  @override
  String get assessPenaltiesConfirmTitle => 'Assess penalties for this period?';

  @override
  String get assessPenaltiesConfirmMessage =>
      'This checks every overdue charge and posts any newly-due penalty. Running it again is always safe — it never creates duplicates.';

  @override
  String get assessPenaltiesResultTitle => 'Penalties Assessed';

  @override
  String assessPenaltiesResultCreatedCount(Object count) {
    return 'New Penalties Posted: $count';
  }

  @override
  String assessPenaltiesResultAlreadyCurrentCount(Object count) {
    return 'Already Up To Date: $count';
  }

  @override
  String get assessPenaltiesResultTotalThisRun => 'New Penalty Total';

  @override
  String get openPreviewTitle => 'Preview Opening This Period';

  @override
  String openPreviewEligibleCount(int count) {
    return 'Eligible Members: $count';
  }

  @override
  String openPreviewExcludedCount(int count) {
    return 'Excluded Members: $count';
  }

  @override
  String openPreviewMissingAmountCount(int count) {
    return 'Missing Amount: $count';
  }

  @override
  String get openPreviewExpectedTotal => 'Expected Total Assessment';

  @override
  String get openPreviewMissingAmountWarning =>
      'Set an amount for every member before opening this period.';

  @override
  String get openPreviewConfirmTitle => 'Open this period?';

  @override
  String get openPreviewConfirmMessage =>
      'This will charge every eligible member and cannot be undone.';

  @override
  String get openPreviewConfirmButton => 'Open Period';

  @override
  String get sectionEligibleMembers => 'Eligible Members';

  @override
  String get sectionExcludedMembers => 'Excluded Members';

  @override
  String get sectionMissingAmountMembers => 'Missing Amount';

  @override
  String get customAmountEditorTitle => 'Set Per-Member Amounts';

  @override
  String get customAmountFieldLabel => 'Amount';

  @override
  String get customAmountMissingBadge => 'Not set';

  @override
  String get customAmountSaveAction => 'Save Amounts';

  @override
  String get customAmountSavedMessage => 'Amounts saved.';

  @override
  String get customAmountSearchHint => 'Search member';

  @override
  String get exclusionsScreenTitle => 'Manage Exclusions';

  @override
  String get exclusionSheetTitle => 'Remove From This Period';

  @override
  String get exclusionReasonLabel => 'Reason (optional)';

  @override
  String get excludeMemberAction => 'Remove From This Period';

  @override
  String get removeExclusionAction => 'Restore To Period';

  @override
  String get memberExcludedMessage => 'Member removed from this period.';

  @override
  String get memberExclusionRemovedMessage => 'Member restored to this period.';

  @override
  String get contributionExclusionReasonSuspended => 'Suspended';

  @override
  String get contributionExclusionReasonExited => 'Exited';

  @override
  String get contributionExclusionReasonJoinedAfterEligibility =>
      'Joined after the eligibility date';

  @override
  String get contributionExclusionReasonExitedDuringPeriod =>
      'Exited and rejoined during this period';

  @override
  String get contributionExclusionReasonExcludedDefault => 'Removed';

  @override
  String get chargesListTitle => 'Posted Charges';

  @override
  String get chargesSearchHint => 'Search member';

  @override
  String get chargesEmptyTitle => 'No Charges Yet';

  @override
  String get chargesEmptyMessage =>
      'No member has been charged in this period yet.';

  @override
  String get chargeBaseAmountLabel => 'Assessed Amount';

  @override
  String get chargePenaltyAmountLabel => 'Penalty';

  @override
  String get chargeTotalAmountLabel => 'Total';

  @override
  String get enrollMemberTitle => 'Enroll Member';

  @override
  String get enrollMemberSearchHint => 'Search member';

  @override
  String get enrollMemberAmountLabel => 'Amount *';

  @override
  String get enrollMemberSuccessMessage => 'Member enrolled into the period.';

  @override
  String get enrollMemberEmptyResults => 'No member found';

  @override
  String get contributionErrorNameRequired => 'A name is required.';

  @override
  String get contributionErrorMemberSavingsNotAvailable =>
      'Member savings is not available yet.';

  @override
  String get contributionErrorAccountingLocked =>
      'Category/accounting treatment cannot change once a period has posted charges.';

  @override
  String get contributionErrorSetupConfigLocked =>
      'This configuration is locked once a period has posted charges.';

  @override
  String get contributionErrorTypeInactive =>
      'This contribution type is inactive.';

  @override
  String get contributionErrorSetupInactive =>
      'This contribution setup is inactive.';

  @override
  String get contributionErrorDuplicateName =>
      'That name is already used in this group.';

  @override
  String get contributionErrorInvalidDates => 'Invalid period dates.';

  @override
  String get contributionErrorDueDateRequired => 'A due date is required.';

  @override
  String get contributionErrorDuplicateMonthlyPeriod =>
      'A period already exists for this month.';

  @override
  String get contributionErrorPeriodNotEditable =>
      'This period can no longer be edited.';

  @override
  String get contributionErrorSetupNotCustomAmount =>
      'This setup does not use per-member amounts.';

  @override
  String get contributionErrorMembershipNotFound => 'Member not found.';

  @override
  String get contributionErrorInvalidAmount =>
      'Amount must be greater than zero.';

  @override
  String get contributionErrorPeriodNotPreviewable =>
      'This period can no longer be previewed.';

  @override
  String get contributionErrorPeriodNotOpenable =>
      'This period can no longer be opened.';

  @override
  String get contributionErrorMissingCustomAmounts =>
      'Some eligible members are missing a configured amount.';

  @override
  String get contributionErrorPeriodNotOpen => 'This period is not open.';

  @override
  String get contributionErrorMemberAlreadyCharged =>
      'This member already has a charge for this period.';

  @override
  String get contributionErrorAmountRequired => 'An amount is required.';

  @override
  String get contributionErrorPeriodNotCancellable =>
      'This period can no longer be cancelled.';

  @override
  String get contributionErrorNotFound => 'Not found.';

  @override
  String get contributionErrorNoPenaltyPolicy =>
      'This period has no penalty policy configured.';

  @override
  String get contributionErrorPermissionDenied =>
      'You do not have permission to do that.';

  @override
  String get contributionErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get contributionErrorUnexpected =>
      'Something went wrong. Please try again.';

  @override
  String get contributionErrorAdjustmentAmountRequired =>
      'An adjustment amount is required and cannot be zero.';

  @override
  String get contributionErrorAdjustmentReasonRequired =>
      'A reason is required for this adjustment.';

  @override
  String get contributionErrorAdjustmentWouldMakeObligationNegative =>
      'This adjustment would make the obligation negative.';

  @override
  String get contributionErrorWaiverAmountMustBePositive =>
      'The waiver amount must be greater than zero.';

  @override
  String get contributionErrorWaiverReasonRequired =>
      'A reason is required for this waiver.';

  @override
  String get contributionErrorWaiverExceedsNetAssessed =>
      'This waiver exceeds the current net assessed obligation.';

  @override
  String get contributionErrorOpeningBalanceAmountMustBePositive =>
      'Opening balance amounts must be greater than zero.';

  @override
  String get contributionErrorOpeningBalanceAlreadyImported =>
      'An opening balance for this member has already been imported.';

  @override
  String get contributionComponentBase => 'Base';

  @override
  String get contributionComponentPenalty => 'Penalty';

  @override
  String get contributionComponentAdjustment => 'Adjustment';

  @override
  String get contributionComponentWaiver => 'Waiver';

  @override
  String get contributionComponentOpeningBalance => 'Opening Balance';

  @override
  String get contributionComponentReasonLabel => 'Reason';

  @override
  String get contributionComponentDateLabel => 'Date';

  @override
  String get contributionNetAssessedLabel => 'Net Assessed';

  @override
  String get contributionCurrentNetAssessedLabel => 'Current Net Assessed';

  @override
  String get contributionEffectiveDateFieldLabel => 'Effective Date';

  @override
  String get chargeDetailTitle => 'Charge Details';

  @override
  String get sectionChargeBreakdown => 'Charge Breakdown';

  @override
  String get addAdjustmentAction => 'Add Adjustment';

  @override
  String get waiveObligationAction => 'Waive Obligation';

  @override
  String get viewMemberSummaryAction => 'View Member Summary';

  @override
  String get memberSummaryTitle => 'Member Contribution Obligation Summary';

  @override
  String get addAdjustmentTitle => 'Add Adjustment';

  @override
  String get adjustmentDirectionLabel => 'Adjustment Type';

  @override
  String get adjustmentIncreaseOption => 'Increase Obligation';

  @override
  String get adjustmentReduceOption => 'Reduce Obligation';

  @override
  String get adjustmentAmountFieldLabel => 'Amount *';

  @override
  String get adjustmentReasonFieldLabel => 'Reason *';

  @override
  String get adjustmentSubmitAction => 'Submit Adjustment';

  @override
  String get adjustmentSuccessMessage => 'Adjustment posted.';

  @override
  String get waiveObligationTitle => 'Waive Obligation';

  @override
  String get waiverTypeLabel => 'Waiver Type';

  @override
  String get waiverPartialOption => 'Partial';

  @override
  String get waiverFullOption => 'Full';

  @override
  String get waiverAmountFieldLabel => 'Amount to Waive *';

  @override
  String get waiverReasonFieldLabel => 'Reason *';

  @override
  String get waiverMaximumLabel => 'Maximum Waiver';

  @override
  String get waiverRemainingAfterLabel => 'Remaining After Waiver';

  @override
  String get waiverSubmitAction => 'Submit Waiver';

  @override
  String get waiverSuccessMessage => 'Obligation waived.';

  @override
  String get openingBalancesEntryTitle => 'Opening Balances';

  @override
  String get openingBalancesEntrySubtitle =>
      'Import member balances from before Umoja';

  @override
  String get openingBalancesTitle => 'Opening Balances';

  @override
  String get openingBalancesEmptyTitle => 'No Opening Balances';

  @override
  String get openingBalancesEmptyMessage =>
      'No opening balances have been imported yet.';

  @override
  String get openingBalanceImportAction => 'Import Opening Balances';

  @override
  String get openingBalanceImportTitle => 'Import Opening Balances';

  @override
  String get openingBalanceContributionTypeLabel => 'Contribution Type';

  @override
  String get openingBalanceEffectiveDateLabel => 'Effective Date';

  @override
  String get openingBalanceSearchHint => 'Search member';

  @override
  String get openingBalanceAmountFieldLabel => 'Amount';

  @override
  String get openingBalancePreviewAction => 'Preview';

  @override
  String get openingBalanceMemberCountLabel => 'Member Count';

  @override
  String get openingBalanceTotalLabel => 'Total Opening Obligation';

  @override
  String get openingBalanceAlreadyImportedBadge => 'Already Imported';

  @override
  String get openingBalanceConfirmImportAction => 'Confirm Import';

  @override
  String get openingBalanceImportSuccessMessage => 'Opening balances imported.';

  @override
  String get openingBalanceCannotImportMessage =>
      'Some members already have an opening balance. Remove or change their amount before continuing.';

  @override
  String get financialAccountsTitle => 'Financial Accounts';

  @override
  String get homeFinancialAccountsShortcutSubtitle =>
      'Cash, bank, and mobile money';

  @override
  String get financialAccountsEmptyTitle => 'No Financial Accounts';

  @override
  String get financialAccountsEmptyMessage =>
      'No financial account has been created yet.';

  @override
  String get financialAccountsSearchHint => 'Search accounts';

  @override
  String get financialAccountNewAction => 'Add Account';

  @override
  String get financialAccountNewTitle => 'New Financial Account';

  @override
  String get sectionFinancialAccountDetails => 'Account Details';

  @override
  String get financialAccountEditTitle => 'Edit Financial Account';

  @override
  String get financialAccountNameFieldLabel => 'Account Name *';

  @override
  String get financialAccountTypeFieldLabel => 'Account Type';

  @override
  String get financialAccountTypeCash => 'Cash';

  @override
  String get financialAccountTypeBank => 'Bank';

  @override
  String get financialAccountTypeMobileMoney => 'Mobile Money';

  @override
  String get financialAccountOpeningBalanceFieldLabel =>
      'Opening Balance (optional)';

  @override
  String get financialAccountOpeningBalanceDateLabel => 'Opening Balance Date';

  @override
  String get financialAccountSavedMessage => 'Financial account saved.';

  @override
  String get financialAccountBalanceLabel => 'Balance';

  @override
  String get financialAccountActiveBadge => 'Active';

  @override
  String get financialAccountInactiveBadge => 'Inactive';

  @override
  String get financialAccountActivateAction => 'Activate Account';

  @override
  String get financialAccountDeactivateAction => 'Deactivate Account';

  @override
  String get financialAccountEditAction => 'Edit';

  @override
  String get financialAccountEntriesTitle => 'Entries';

  @override
  String get financialAccountEntriesEmptyMessage =>
      'No entries have been posted for this account yet.';

  @override
  String get financialAccountEntryTypeInflow => 'Inflow';

  @override
  String get financialAccountEntryTypeOutflow => 'Outflow';

  @override
  String get financialAccountEntryTypeTransferIn => 'Transfer In';

  @override
  String get financialAccountEntryTypeTransferOut => 'Transfer Out';

  @override
  String get financialAccountTransferAction => 'Transfer Funds';

  @override
  String financialAccountTransferToLedgerLabel(Object accountName) {
    return 'Transfer to $accountName';
  }

  @override
  String financialAccountTransferFromLedgerLabel(Object accountName) {
    return 'Transfer from $accountName';
  }

  @override
  String get financialAccountTransferTitle => 'Transfer Between Accounts';

  @override
  String get financialAccountTransferFromLabel => 'From Account';

  @override
  String get financialAccountTransferToLabel => 'To Account';

  @override
  String get financialAccountTransferAmountLabel => 'Amount *';

  @override
  String get financialAccountTransferDescriptionFieldLabel =>
      'Description (optional)';

  @override
  String get financialAccountTransferSuccessMessage => 'Transfer successful.';

  @override
  String get financialAccountTransferSubmitAction => 'Transfer';

  @override
  String get financialAccountErrorNameRequired =>
      'An account name is required.';

  @override
  String get financialAccountErrorDuplicateName =>
      'That account name is already used in this group.';

  @override
  String get financialAccountErrorOpeningBalanceMustBePositive =>
      'The opening balance must be greater than zero.';

  @override
  String get financialAccountErrorNotFound => 'Financial account not found.';

  @override
  String get financialAccountErrorTransferSameAccount =>
      'Cannot transfer an account to itself.';

  @override
  String get financialAccountErrorTransferAmountMustBePositive =>
      'The transfer amount must be greater than zero.';

  @override
  String get financialAccountErrorInsufficientBalance =>
      'The source account does not have enough balance for this transfer.';

  @override
  String get financialAccountErrorAccountInactive =>
      'This financial account is inactive.';

  @override
  String get financialAccountErrorEffectiveDateRequired =>
      'An effective date is required for this transfer.';

  @override
  String get financialAccountErrorPermissionDenied =>
      'You do not have permission to do that.';

  @override
  String get financialAccountErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get financialAccountErrorUnexpected =>
      'Something went wrong. Please try again.';

  @override
  String get supabaseConfigMissing =>
      'Supabase configuration missing (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set).';

  @override
  String get backAction => 'Back';

  @override
  String get doneAction => 'Done';

  @override
  String get paymentsEntryTitle => 'Payments';

  @override
  String get paymentsEntrySubtitle => 'View the full payment history';

  @override
  String get recordPaymentEntryTitle => 'Record Payment';

  @override
  String get recordPaymentEntrySubtitle =>
      'Record an external payment from a member';

  @override
  String get memberWalletEntryTitle => 'Member Wallet Balance';

  @override
  String get memberWalletEntrySubtitle =>
      'View and allocate a member\'s wallet balance';

  @override
  String get paymentsTitle => 'Payments';

  @override
  String get paymentsSearchHint => 'Search payments';

  @override
  String get paymentsEmptyTitle => 'No Payments';

  @override
  String get paymentsEmptyMessage => 'No payments have been recorded yet.';

  @override
  String get recordPaymentAction => 'Record Payment';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodBankTransfer => 'Bank Transfer';

  @override
  String get paymentMethodMobileMoney => 'Mobile Money';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentStatusPosted => 'Posted';

  @override
  String get paymentStatusReversed => 'Reversed';

  @override
  String get walletEntryTypePaymentCredit => 'Credited';

  @override
  String get walletEntryTypeAllocationDebit => 'Allocated';

  @override
  String get walletEntryTypeReversal => 'Reversed';

  @override
  String get memberPickerSearchHint => 'Search member';

  @override
  String get memberPickerEmptyTitle => 'No Member Found';

  @override
  String get memberPickerEmptyMessage => 'No member matched this search.';

  @override
  String get paymentAmountInvalidError =>
      'Enter a valid amount, member, and financial account.';

  @override
  String get recordPaymentTitle => 'Record Payment';

  @override
  String get recordPaymentAmountLabel => 'Amount *';

  @override
  String get recordPaymentDateLabel => 'Date';

  @override
  String get recordPaymentMethodLabel => 'Payment Method';

  @override
  String get recordPaymentAccountLabel => 'Financial Account';

  @override
  String get recordPaymentReferenceLabel => 'External Reference (optional)';

  @override
  String get recordPaymentNotesLabel => 'Notes (optional)';

  @override
  String get recordPaymentPreviewAction => 'Preview Allocation';

  @override
  String get recordPaymentConfirmAction => 'Confirm Payment';

  @override
  String get recordPaymentSuccessMessage => 'Payment recorded successfully.';

  @override
  String get paymentPreviewAmountLabel => 'Payment Amount';

  @override
  String get paymentPreviewWillSettleLabel => 'Will Settle';

  @override
  String get paymentPreviewNoOutstandingMessage =>
      'There is no outstanding amount to settle.';

  @override
  String get paymentPreviewTotalAllocatedLabel => 'Settles Debt';

  @override
  String get paymentPreviewWalletRemainingLabel => 'Wallet Remaining';

  @override
  String get paymentPreviewAccountLabel => 'Account Receiving Funds';

  @override
  String get viewReceiptAction => 'View Receipt';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptMemberLabel => 'Member';

  @override
  String get paymentDetailTitle => 'Payment Detail';

  @override
  String get paymentAmountLabel => 'Amount';

  @override
  String get paymentAllocationsTitle => 'Payment Allocations';

  @override
  String get reversalReasonLabel => 'Reversal Reason *';

  @override
  String get reversePaymentAction => 'Reverse Payment';

  @override
  String get reversePaymentTitle => 'Reverse Payment';

  @override
  String get reversePaymentWarningMessage =>
      'This cannot be undone. The original payment stays on record, but the debt it settled becomes outstanding again.';

  @override
  String get reversePaymentConfirmAction => 'Confirm Reversal';

  @override
  String get reversePaymentSuccessMessage => 'Payment reversed.';

  @override
  String get memberWalletTitle => 'Member Wallet Balance';

  @override
  String get walletBalanceLabel => 'Current Balance';

  @override
  String get walletHistoryTitle => 'Wallet History';

  @override
  String get walletHistoryEmptyMessage => 'No wallet history yet.';

  @override
  String get allocateWalletAction => 'Allocate Balance';

  @override
  String get allocateWalletTitle => 'Allocate Member Wallet';

  @override
  String get allocateWalletSuccessMessage =>
      'Wallet balance allocated against outstanding debt.';

  @override
  String get paymentErrorAmountMustBePositive =>
      'The amount must be greater than zero.';

  @override
  String get paymentErrorFinancialAccountInactive =>
      'This financial account is inactive.';

  @override
  String get paymentErrorIdempotencyKeyConflict =>
      'This submission conflicts with an earlier one. Please refresh and try again.';

  @override
  String get paymentErrorAlreadyReversed =>
      'This payment has already been reversed.';

  @override
  String get paymentErrorReversalBlockedWalletCreditConsumed =>
      'This payment cannot be reversed: the wallet credit it created has already been used.';

  @override
  String get paymentErrorReversalReasonRequired =>
      'A reversal reason is required.';

  @override
  String get paymentErrorWalletInsufficientBalance =>
      'The wallet does not have enough balance for this allocation.';

  @override
  String get paymentErrorWalletNothingToAllocate =>
      'There is no outstanding amount to allocate against.';

  @override
  String get paymentErrorNotFound => 'Not found.';

  @override
  String get paymentErrorPermissionDenied =>
      'You do not have permission to do that.';

  @override
  String get paymentErrorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get paymentErrorUnexpected =>
      'Something went wrong. Please try again.';

  @override
  String get paymentSummaryOutstandingLabel => 'Outstanding Balance';

  @override
  String get outstandingObligationsSectionTitle => 'Outstanding Obligations';

  @override
  String get outstandingObligationsEmptyMessage =>
      'This member has no outstanding debt.';

  @override
  String get viewAllObligationsAction => 'View All';
}
