import 'package:flutter/material.dart';
import '../models/hour_prediction.dart';

const _quiet = Color(0xFF22C55E);
const _medium = Color(0xFFF59E0B);
const _busy = Color(0xFFEF4444);
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Green → amber → red for t in [0, 1].
Color heatColor(double t) => t < 0.5
    ? Color.lerp(_quiet, _medium, t * 2)!
    : Color.lerp(_medium, _busy, (t - 0.5) * 2)!;

/// Weekdays × core hours, coloured by usual count over the coming 7 days.
class WeekHeatmap extends StatelessWidget {
  final List<HourPrediction> week;
  final int fromHour;
  /// Exclusive.
  final int toHour;

  const WeekHeatmap({super.key, required this.week, required this.fromHour, required this.toHour});

  @override
  Widget build(BuildContext context) {
    final cells = <(int, int), HourPrediction>{
      for (final p in week) (p.timestamp.weekday, p.timestamp.hour): p,
    };
    final maxMean = week.map((p) => p.mean ?? 0).fold<double>(0, (a, b) => b > a ? b : a);
    final hours = [for (var h = fromHour; h < toHour; h++) h];
    final labelStyle = TextStyle(color: Colors.grey.shade500, fontSize: 10);

    return Column(
      children: [
        for (var day = 1; day <= 7; day++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text(_weekdays[day - 1], style: labelStyle)),
                for (final h in hours) Expanded(child: _cell(day, h, cells[(day, h)], maxMean)),
              ],
            ),
          ),
        Row(
          children: [
            const SizedBox(width: 32),
            for (final h in hours)
              Expanded(
                child: Text(h % 3 == 0 ? '$h' : '',
                    style: labelStyle, softWrap: false, overflow: TextOverflow.visible),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Quiet', style: labelStyle),
            const SizedBox(width: 4),
            Container(
              width: 80,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: [_quiet, _medium, _busy]),
              ),
            ),
            const SizedBox(width: 4),
            Text('Busy', style: labelStyle),
          ],
        ),
      ],
    );
  }

  Widget _cell(int day, int hour, HourPrediction? p, double maxMean) {
    final mean = p?.mean;
    final label = '${_weekdays[day - 1]} ${hour.toString().padLeft(2, '0')}:00';
    final message = mean == null
        ? '$label: no data'
        : '$label: ~${mean.toStringAsFixed(0)} (${p!.min}–${p.max}), ${p.samples} '
            '${p.samples == 1 ? 'week' : 'weeks'}';
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        decoration: BoxDecoration(
          color: mean == null
              ? Colors.grey.shade200
              : heatColor(maxMean <= 0 ? 0 : mean / maxMean),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
