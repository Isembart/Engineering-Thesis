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
  static double getCurrentCrowdLevel(List<BoardDataRecord> records) {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.clientsCount).reduce((a, b) => a + b) / records.length;
  }

  /// Where [current] falls against the typical range; null without history.
  static CrowdComparison? compare(double current, HourPrediction p) {
    if (p.samples == 0 || p.min == null || p.max == null) return null;
    if (current > p.max!) return CrowdComparison.busier;
    if (current < p.min!) return CrowdComparison.quieter;
    return CrowdComparison.usual;
  }
}
