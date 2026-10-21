import '../models/board_data_record.dart';

class AggregatedBucket {
  final DateTime startTime;
  final DateTime endTime;
  final double averageClients;

  AggregatedBucket({
    required this.startTime,
    required this.endTime,
    required this.averageClients,
  });
}

class DataAggregator {
  /// The server always returns epoch-aligned 1-hour buckets.
  static const bucketSize = Duration(hours: 1);

  /// Generates a bucket for every hour between start and end, padding missing data with 0.
  static List<AggregatedBucket> aggregateToFixedBuckets(
      List<BoardDataRecord> records, DateTime start, DateTime end) {

    Map<DateTime, List<int>> buckets = {};

    for (var record in records) {
      // The backend already aggregates and returns timestamps exactly on the bucket boundary.
      // However, we still group by exact timestamp to pad empty gaps.
      buckets.putIfAbsent(record.timestamp, () => []).add(record.clientsCount);
    }

    List<AggregatedBucket> result = [];
    
    // Normalize start time to the nearest boundary.
    // To handle larger than 60 mins (e.g. 1 day), we calculate by epoch.
    int startEpoch = start.millisecondsSinceEpoch;
    int bucketMs = bucketSize.inMilliseconds;
    int normalizedStartMs = (startEpoch ~/ bucketMs) * bucketMs;
    DateTime current = DateTime.fromMillisecondsSinceEpoch(normalizedStartMs, isUtc: start.isUtc).toLocal();
    
    // If the original logic for minute boundary is preferred:
    // This simple normalization works perfectly for minutes, hours, and up to days.
    
    while (current.isBefore(end)) {
      if (buckets.containsKey(current)) {
        final counts = buckets[current]!;
        double avg = counts.reduce((a, b) => a + b) / counts.length;
        result.add(AggregatedBucket(
          startTime: current,
          endTime: current.add(bucketSize),
          averageClients: avg,
        ));
      } else {
        // Pad empty intervals with 0
        result.add(AggregatedBucket(
          startTime: current,
          endTime: current.add(bucketSize),
          averageClients: 0.0,
        ));
      }
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
}
