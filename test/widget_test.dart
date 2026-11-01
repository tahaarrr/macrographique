import 'package:flutter_test/flutter_test.dart';
import 'package:macrographique/main.dart';
import 'package:macrographique/screens/home_screen.dart';

void main() {
  testWidgets('App smoke test - verifies RapportEssaiApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RapportEssaiApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
