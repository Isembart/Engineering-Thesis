import '../models/board_data_record.dart';
import '../models/hour_prediction.dart';

class AggregatedBucket {
  final DateTime startTime;
  final DateTime endTime;
  /// Null when the board sent nothing that hour (offline), which is not the same as 0.
  final double? averageClients;

  AggregatedBucket({
    required this.startTime,
    required this.endTime,
    required this.averageClients,
  });
}

enum CrowdComparison { quieter, usual, busier }

class DataAggregator {
  /// The server always returns epoch-aligned 1-hour buckets.
  static const bucketSize = Duration(hours: 1);

  /// Generates a bucket for every hour between start and end; hours without data get null.
  static List<AggregatedBucket> aggregateToFixedBuckets(
      List<BoardDataRecord> records, DateTime start, DateTime end) {
    final buckets = <int, List<int>>{};
    for (final record in records) {
      buckets.putIfAbsent(record.timestamp.millisecondsSinceEpoch, () => []).add(record.clientsCount);
    }

    final bucketMs = bucketSize.inMilliseconds;
    var current = DateTime.fromMillisecondsSinceEpoch(
        (start.millisecondsSinceEpoch ~/ bucketMs) * bucketMs);

    final result = <AggregatedBucket>[];
    while (current.isBefore(end)) {
      final counts = buckets[current.millisecondsSinceEpoch];
      result.add(AggregatedBucket(
        startTime: current,
        endTime: current.add(bucketSize),
        averageClients: counts == null ? null : counts.reduce((a, b) => a + b) / counts.length,
      ));
      current = current.add(bucketSize);
    }
    return result;
  }

  /// Averages the records the server returned for the recent window.
  /// The server filters raw rows by start/end before bucketing, so these are
  /// already limited to the window even though they are stamped on the hour.
  /// Null when the board sent nothing in the window (offline), which is not the same as 0.
  static double? getCurrentCrowdLevel(List<BoardDataRecord> records) {
    if (records.isEmpty) return null;
    return records.map((r) => r.clientsCount).reduce((a, b) => a + b) / records.length;
  }

  /// Where [current] falls against the typical range; null without history.
  static CrowdComparison? compare(double current, HourPrediction p) {
    if (p.samples == 0 || p.min == null || p.max == null) return null;
    if (current > p.max!) return CrowdComparison.busier;
    if (current < p.min!) return CrowdComparison.quieter;
    return CrowdComparison.usual;
  }

  /// Today's upcoming hour (from [fromHour]) with the lowest usual count.
  /// Null without history, or when the quietest hour is the current one.
  static HourPrediction? quietestHour(List<HourPrediction> predictions, DateTime now, {int fromHour = 0}) {
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    final upcoming = predictions.where((p) =>
        p.mean != null &&
        !p.timestamp.isBefore(hourStart) &&
        p.timestamp.day == now.day &&
        p.timestamp.hour >= fromHour);
    if (upcoming.isEmpty) return null;
    final best = upcoming.reduce((a, b) => b.mean! < a.mean! ? b : a);
    return best.timestamp.isAtSameMomentAs(hourStart) ? null : best;
  }

  // ponytail: fixed heuristic thresholds, tune once there is real data.
  static const _trendRatio = 1.25;
  static const _trendMinDiff = 2.0;

  /// Whether the next hour is usually clearly busier or quieter than this one.
  /// Null when either hour has no history or the change is small.
  static CrowdComparison? trend(HourPrediction? current, HourPrediction? next) {
    final a = current?.mean, b = next?.mean;
    if (a == null || b == null) return null;
    if (b - a >= _trendMinDiff && b > a * _trendRatio) return CrowdComparison.busier;
    if (a - b >= _trendMinDiff && a > b * _trendRatio) return CrowdComparison.quieter;
    return null;
  }
}
