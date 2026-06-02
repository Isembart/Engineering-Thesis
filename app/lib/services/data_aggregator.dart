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
  /// Aggregates records into fixed intervals.
  /// Generates a bucket for every interval between start and end, padding missing data with 0.
  static List<AggregatedBucket> aggregateToFixedBuckets(
      List<BoardDataRecord> records, DateTime start, DateTime end, int bucketSizeMinutes) {
    
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
    int bucketMs = bucketSizeMinutes * 60 * 1000;
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
          endTime: current.add(Duration(minutes: bucketSizeMinutes)),
          averageClients: avg,
        ));
      } else {
        // Pad empty intervals with 0
        result.add(AggregatedBucket(
          startTime: current,
          endTime: current.add(Duration(minutes: bucketSizeMinutes)),
          averageClients: 0.0,
        ));
      }
      current = current.add(Duration(minutes: bucketSizeMinutes));
    }

    return result;
  }

  /// Calculates the average clients in the sliding window of the last 15 minutes relative to `now`.
  static double getCurrentCrowdLevel(List<BoardDataRecord> records, DateTime now) {
    final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));
    
    final recentRecords = records.where((r) => r.timestamp.isAfter(fifteenMinsAgo) && r.timestamp.isBefore(now.add(const Duration(seconds: 1)))).toList();
    
    if (recentRecords.isEmpty) {
      return 0.0;
    }

    double sum = 0;
    for (var r in recentRecords) {
      sum += r.clientsCount;
    }
    return sum / recentRecords.length;
  }
}
