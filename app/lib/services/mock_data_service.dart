import '../models/place.dart';

class MockDataService {
  static List<Place> getPlaces() {
    return [
      Place(
        id: '1',
        name: 'Gym',
        currentCrowdLevel: 0.5,
        summaryText: 'Usually more people on Tuesdays around 20:00',
        trends: _generateMockTrends(0.2, 0.9, peakHour: 19),
      ),
      Place(
        id: '2',
        name: 'Library',
        currentCrowdLevel: 0.8,
        summaryText: 'Quiet in the mornings, peak study hours at 14:00',
        trends: _generateMockTrends(0.1, 0.8, peakHour: 14),
      ),
      Place(
        id: '3',
        name: 'Cafeteria',
        currentCrowdLevel: 0.1,
        summaryText: 'Busiest during lunch break (12:00 - 13:00)',
        trends: _generateMockTrends(0.05, 0.9, peakHour: 12),
      ),
    ];
  }

  static List<TrendInfo> _generateMockTrends(double baseLevel, double peakLevel, {required int peakHour}) {
    List<TrendInfo> trends = [];
    for (int i = 0; i < 24; i++) {
      double level = baseLevel;
      // create a bell curve around the peak hour
      int diff = (i - peakHour).abs();
      if (diff > 12) diff = 24 - diff;
      
      if (diff < 4) {
        level = peakLevel - (diff * 0.15);
      }
      
      if (level < 0) level = 0.0;
      if (level > 1) level = 1.0;
      
      trends.add(TrendInfo(hour: i, crowdLevel: level));
    }
    return trends;
  }
}
