import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';

void main() {
  testWidgets('Umoja app starts and renders the foundation screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: UmojaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Umoja v2'), findsOneWidget);
    expect(find.text('Application foundation is ready.'), findsOneWidget);
  });
}
