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
  String get supabaseConfigMissing =>
      'Supabase configuration missing (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set).';
}
