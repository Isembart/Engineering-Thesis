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
  /// Aggregates records into fixed 15-minute intervals.
  /// Generates a bucket for every interval between start and end, padding missing data with 0.
  static List<AggregatedBucket> aggregateToFixed15MinBuckets(
      List<BoardDataRecord> records, DateTime start, DateTime end) {
    
    Map<DateTime, List<int>> buckets = {};

    for (var record in records) {
      // Find the start of the 15-minute bucket
      int minuteBucket = (record.timestamp.minute ~/ 15) * 15;
      DateTime bucketStart = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
        record.timestamp.hour,
        minuteBucket,
      );

      buckets.putIfAbsent(bucketStart, () => []).add(record.clientsCount);
    }

    List<AggregatedBucket> result = [];
    
    // Normalize start time to the nearest 15-min boundary
    DateTime current = DateTime(start.year, start.month, start.day, start.hour, (start.minute ~/ 15) * 15);
    
    while (current.isBefore(end)) {
      if (buckets.containsKey(current)) {
        final counts = buckets[current]!;
        double avg = counts.reduce((a, b) => a + b) / counts.length;
        result.add(AggregatedBucket(
          startTime: current,
          endTime: current.add(const Duration(minutes: 15)),
          averageClients: avg,
        ));
      } else {
        // Pad empty intervals with 0
        result.add(AggregatedBucket(
          startTime: current,
          endTime: current.add(const Duration(minutes: 15)),
          averageClients: 0.0,
        ));
      }
      current = current.add(const Duration(minutes: 15));
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
