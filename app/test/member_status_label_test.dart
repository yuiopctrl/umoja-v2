import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/presentation/widgets/member_status_badge.dart';
import 'package:umoja/l10n/app_localizations_en.dart';
import 'package:umoja/l10n/app_localizations_sw.dart';

void main() {
  final sw = AppLocalizationsSw();
  final en = AppLocalizationsEn();

  group('memberStatusLabel', () {
    test('maps backend enum values to their Kiswahili display label', () {
      expect(memberStatusLabel(sw, 'ACTIVE'), 'Hai');
      expect(memberStatusLabel(sw, 'SUSPENDED'), 'Amesitishwa');
      expect(memberStatusLabel(sw, 'EXITED'), 'Ametoka');
    });

    test('maps backend enum values to their English display label', () {
      expect(memberStatusLabel(en, 'ACTIVE'), 'Active');
      expect(memberStatusLabel(en, 'SUSPENDED'), 'Suspended');
      expect(memberStatusLabel(en, 'EXITED'), 'Exited');
    });

    test('never returns the raw backend enum for a known status', () {
      for (final status in ['ACTIVE', 'SUSPENDED', 'EXITED']) {
        expect(memberStatusLabel(sw, status), isNot(status));
        expect(memberStatusLabel(en, status), isNot(status));
      }
    });
  });
}
