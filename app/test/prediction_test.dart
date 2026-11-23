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
import 'package:crowdness_app/services/api_service.dart';
import 'package:crowdness_app/services/data_aggregator.dart';
import 'package:crowdness_app/widgets/status_block.dart';
import 'package:crowdness_app/utils/plural.dart';
import 'package:crowdness_app/widgets/week_heatmap.dart';

void main() {
  test('server url normalization', () {
    expect(ApiService.normalizeServerUrl(' inzynierka.bieda.it/ '), 'https://inzynierka.bieda.it');
    expect(ApiService.normalizeServerUrl('http://10.0.0.1:3000'), 'http://10.0.0.1:3000');
    expect(ApiService.normalizeServerUrl(''), isNull);
    expect(ApiService.normalizeServerUrl('://'), isNull);
  });

  HourPrediction hp(DateTime t, double? mean) =>
      HourPrediction(timestamp: t, samples: mean == null ? 0 : 2, mean: mean, min: mean?.round(), max: mean?.round());

  test('quietest upcoming hour today', () {
    final now = DateTime(2026, 7, 6, 10, 30);
    final preds = [
      hp(DateTime(2026, 7, 6, 8), 0), // past
      hp(DateTime(2026, 7, 6, 10), 9),
      hp(DateTime(2026, 7, 6, 12), 3),
      hp(DateTime(2026, 7, 6, 13), null),
      hp(DateTime(2026, 7, 7, 9), 1), // tomorrow
    ];
    expect(DataAggregator.quietestHour(preds, now)!.timestamp.hour, 12);
    // Quietest is the current hour: nothing to suggest.
    expect(DataAggregator.quietestHour([hp(DateTime(2026, 7, 6, 10), 1), ...preds], now), isNull);
  });

  test('next-hour trend', () {
    final t = DateTime(2026);
    expect(DataAggregator.trend(hp(t, 4), hp(t, 10)), CrowdComparison.busier);
    expect(DataAggregator.trend(hp(t, 10), hp(t, 4)), CrowdComparison.quieter);
    expect(DataAggregator.trend(hp(t, 10), hp(t, 11)), isNull);
    expect(DataAggregator.trend(hp(t, 10), null), isNull);
  });

  test('last reading text', () {
    final now = DateTime(2026, 7, 6, 10, 30);
    expect(lastSeenText(DateTime(2026, 7, 6, 8), now), 'ostatni odczyt dziś ok. 8:00');
    expect(lastSeenText(DateTime(2026, 7, 5, 22), now), 'ostatni odczyt wczoraj ok. 22:00');
  });

  test('status for offline, no history and busier', () {
    final p = HourPrediction(timestamp: DateTime(2026), samples: 2, mean: 5, min: 4, max: 6);
    expect(statusInfo(null, p).label, 'Brak sygnału');
    expect(statusInfo(3, null).label, isNull);
    expect(statusInfo(3, null).caption, 'jeszcze uczymy się tego miejsca');
    expect(statusInfo(7, p).label, 'Tłoczniej niż zwykle');
    expect(statusInfo(7, p).caption, 'zwykle 4–6 o tej porze');
  });

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

  test('no recent records means offline, not 0', () {
    expect(DataAggregator.getCurrentCrowdLevel([]), isNull);
  });

  test('polish plurals', () {
    expect([1, 3, 5, 12, 22, 25].map(people), ['1 osoba', '3 osoby', '5 osób', '12 osób', '22 osoby', '25 osób']);
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
      await tester.tap(find.text('Cała doba').last);
      await tester.pumpAndSettle();
    }, () => mock);

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('na podstawie 3 z 4 tygodni'), findsOneWidget);
    expect(find.text('Tłoczniej niż zwykle'), findsOneWidget);
    expect(find.text('ok. 9 osób'), findsOneWidget);

    await tester.scrollUntilVisible(find.byType(WeekHeatmap), 200);
    expect(find.byType(WeekHeatmap), findsOneWidget);
  });
}
