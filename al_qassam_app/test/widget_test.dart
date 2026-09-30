import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_qassam_app/main.dart';

void main() {
  testWidgets('AlQassamApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AlQassamApp(),
      ),
    );

    // Verify main screen renders without error
    expect(find.byType(AlQassamApp), findsOneWidget);
  });
}
