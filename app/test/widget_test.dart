import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crowdness_app/main.dart';
import 'package:crowdness_app/models/board.dart';
import 'package:crowdness_app/screens/details_screen.dart';
import 'package:crowdness_app/services/api_service.dart';

void main() {
  testWidgets('app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const CrowdnessApp());
    await tester.pump();

    expect(find.text('Crowdness Tracker'), findsOneWidget);
  });

  testWidgets('board admin controls exist only in admin mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => ApiService.isAdmin.value = false);

    await tester.pumpWidget(MaterialApp(home: DetailsScreen(board: Board(id: 1, boardMac: 1))));
    await tester.pump();
    expect(find.byIcon(Icons.tune), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);

    ApiService.isAdmin.value = true;
    await tester.pump();
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
