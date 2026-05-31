class Place {
  final String id;
  final String name;
  final double currentCrowdLevel; // 0.0 to 1.0
  final List<TrendInfo> trends;
  final String summaryText;

  Place({
    required this.id,
    required this.name,
    required this.currentCrowdLevel,
    required this.trends,
    required this.summaryText,
  });
}

class TrendInfo {
  final int hour; // 0-23
  final double crowdLevel; // 0.0 to 1.0

  TrendInfo({
    required this.hour,
    required this.crowdLevel,
  });
}
