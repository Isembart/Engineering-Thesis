import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crowdness_app/models/board.dart';
import 'package:crowdness_app/models/board_data_record.dart';
import 'package:crowdness_app/models/hour_prediction.dart';
import 'package:crowdness_app/screens/details_screen.dart';
import 'package:crowdness_app/services/data_aggregator.dart';
import 'package:crowdness_app/widgets/week_heatmap.dart';

void main() {
  test('missing hours are null, not 0', () {
    final start = DateTime(2026, 7, 6, 8);
    final records = [
      BoardDataRecord(id: 1, boardId: 1, timestamp: start, clientsCount: 0),
      BoardDataRecord(id: 2, boardId: 1, timestamp: start.add(const Duration(hours: 2)), clientsCount: 4),
    ];
    final buckets = DataAggregator.aggregateToFixedBuckets(records, start, DateTime(2026, 7, 6, 11));
    expect(buckets.map((b) => b.averageClients), [0.0, null, 4.0]);
  });

  test('compare against the typical range', () {
    final p = HourPrediction(timestamp: DateTime(2026), samples: 2, mean: 5, min: 4, max: 6);
    expect(DataAggregator.compare(7, p), CrowdComparison.busier);
    expect(DataAggregator.compare(3, p), CrowdComparison.quieter);
    expect(DataAggregator.compare(6, p), CrowdComparison.usual);
    expect(DataAggregator.compare(7, HourPrediction(timestamp: DateTime(2026), samples: 0)), isNull);
  });

  testWidgets('details screen renders line chart, heatmap and comparison', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Data for today with a gap at 01:00; every predicted hour has range 4–6,
    // except hours more than 2 days ahead, which have no history.
    final mock = MockClient((req) async {
      if (req.url.path == '/get-board-data') {
        return http.Response(jsonEncode([
          for (final h in [0, 2, 3])
            {
              'id': h,
              'board_id': 1,
              'timestamp': today.add(Duration(hours: h)).toUtc().toIso8601String(),
              'clients_count': 9,
            },
        ]), 200);
      }
      final start = DateTime.parse(req.url.queryParameters['start']!);
      final end = DateTime.parse(req.url.queryParameters['end']!);
      final hours = <Map<String, dynamic>>[];
      for (var t = start; t.isBefore(end); t = t.add(const Duration(hours: 1))) {
        final known = t.isBefore(today.add(const Duration(days: 2)));
        hours.add({
          'timestamp': t.toUtc().toIso8601String(),
          'samples': known ? 3 : 0,
          'mean': known ? 5.0 : null,
          'min': known ? 4 : null,
          'max': known ? 6 : null,
        });
      }
      return http.Response(jsonEncode(hours), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: DetailsScreen(board: Board(id: 1, boardMac: 1))));
      await tester.pumpAndSettle();
      // Switch to the full day so the gap at 01:00 is inside the chart.
      await tester.tap(find.text('6:00-23:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Day').last);
      await tester.pumpAndSettle();
    }, () => mock);

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Based on 3 of 4 weeks'), findsOneWidget);
    expect(find.text('Busier than usual'), findsOneWidget);
    // Date picker weeks start on Monday: the "M" header sits left of both "S" headers.
    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();
    final mondayX = tester.getTopLeft(find.text('M')).dx;
    for (final s in find.text('S').evaluate()) {
      expect(mondayX, lessThan(tester.getTopLeft(find.byWidget(s.widget)).dx));
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byType(WeekHeatmap), 200);
    expect(find.byType(WeekHeatmap), findsOneWidget);
  });
}
