/// Prediction for one hour, built from the same hour 1–4 weeks back.
class HourPrediction {
  final DateTime timestamp;
  /// Weeks of history (0–4). With 0, [mean], [min] and [max] are null.
  final int samples;
  final double? mean;
  final int? min;
  final int? max;

  HourPrediction({
    required this.timestamp,
    required this.samples,
    this.mean,
    this.min,
    this.max,
  });

  factory HourPrediction.fromJson(Map<String, dynamic> json) {
    return HourPrediction(
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      samples: json['samples'] as int,
      mean: (json['mean'] as num?)?.toDouble(),
      min: json['min'] as int?,
      max: json['max'] as int?,
    );
  }
}
