import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/presentation/widgets/member_role_label.dart';
import 'package:umoja/l10n/app_localizations_en.dart';
import 'package:umoja/l10n/app_localizations_sw.dart';

const _roleCodes = ['ADMIN', 'TREASURER', 'SECRETARY', 'CHAIRPERSON', 'MEMBER'];

void main() {
  final sw = AppLocalizationsSw();
  final en = AppLocalizationsEn();

  test('memberRoleLabel maps backend role codes to their Kiswahili label', () {
    expect(memberRoleLabel(sw, 'ADMIN'), 'Msimamizi');
    expect(memberRoleLabel(sw, 'TREASURER'), 'Mweka Hazina');
    expect(memberRoleLabel(sw, 'SECRETARY'), 'Katibu');
    expect(memberRoleLabel(sw, 'CHAIRPERSON'), 'Mwenyekiti');
    expect(memberRoleLabel(sw, 'MEMBER'), 'Mwanachama');
  });

  test('memberRoleLabel maps backend role codes to their English label', () {
    expect(memberRoleLabel(en, 'ADMIN'), 'Administrator');
    expect(memberRoleLabel(en, 'TREASURER'), 'Treasurer');
    expect(memberRoleLabel(en, 'SECRETARY'), 'Secretary');
    expect(memberRoleLabel(en, 'CHAIRPERSON'), 'Chairperson');
    expect(memberRoleLabel(en, 'MEMBER'), 'Member');
  });

  test('never returns the raw backend role code in either language', () {
    for (final code in _roleCodes) {
      expect(memberRoleLabel(sw, code), isNot(code));
      expect(memberRoleLabel(en, code), isNot(code));
    }
  });
}
