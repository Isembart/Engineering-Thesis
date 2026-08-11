import 'package:flutter_test/flutter_test.dart';
import 'package:crowdness_app/main.dart';

void main() {
  testWidgets('app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const CrowdnessApp());
    await tester.pump();

    expect(find.text('Crowdness Tracker'), findsOneWidget);
  });
}
