import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/plural.dart';

/// "ok. 8 osób", or "pusto" for an empty room.
String countText(double count) {
  final n = count.round();
  return n == 0 ? 'pusto' : 'ok. ${people(n)}';
}

/// "ostatni odczyt dziś ok. 14:00" / "wczoraj ok. 22:00". Records are hourly buckets,
/// so only the hour is known.
String lastSeenText(DateTime lastSeen, DateTime now) {
  final day = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
  final today = DateTime(now.year, now.month, now.day);
  final when = day == today
      ? 'dziś'
      : day == DateTime(now.year, now.month, now.day - 1)
          ? 'wczoraj'
          : DateFormat('d MMM').format(lastSeen);
  return 'ostatni odczyt $when ok. ${DateFormat('H:00').format(lastSeen)}';
}

/// Caption for an offline board: when it last sent anything in the past 24 hours.
/// Null when the server could not be asked.
Future<String?> offlineNote(ApiService api, int mac, DateTime now) async {
  try {
    final records = await api.getBoardData(mac, start: now.subtract(const Duration(hours: 24)), end: now);
    if (records.isEmpty) return 'brak odczytów od doby';
    final last = records.map((r) => r.timestamp).reduce((a, b) => b.isAfter(a) ? b : a);
    return lastSeenText(last, now);
  } catch (_) {
    return null; // unknown, not "nothing for a day"
  }
}

typedef StatusInfo = ({String? label, Color color, String? caption});

/// What to show for a place: the pill label, its color, and the line beside it.
/// [current] null means offline: nothing arrived in the last 15 minutes.
/// A null label means there is no history to compare with.
StatusInfo statusInfo(double? current, HourPrediction? prediction) {
  final c = current;
  final p = prediction;
  if (c == null) return (label: 'Brak sygnału', color: Colors.grey.shade600, caption: null);
  final comparison = p == null ? null : DataAggregator.compare(c, p);
  if (comparison == null) {
    return (label: null, color: Colors.grey.shade600, caption: 'jeszcze uczymy się tego miejsca');
  }
  final (label, color) = switch (comparison) {
    CrowdComparison.busier => ('Tłoczniej niż zwykle', const Color(0xFFEF4444)),
    CrowdComparison.quieter => ('Luźniej niż zwykle', const Color(0xFF22C55E)),
    CrowdComparison.usual => ('Jak zwykle', Colors.grey.shade600),
  };
  final range = p!.min == p.max ? '${p.min}' : '${p.min}–${p.max}';
  return (label: label, color: color, caption: 'zwykle $range o tej porze');
}
