import 'package:flutter/material.dart';
import '../models/hour_prediction.dart';
import '../theme.dart';
import '../utils/plural.dart';

const _weekdays = ['pn', 'wt', 'śr', 'czw', 'pt', 'sob', 'nd'];
const _labelWidth = 40.0;

/// Light blue through vivid blue to navy for t in [0, 1].
Color _heat(double t) => t < 0.5
    ? Color.lerp(Palette.heatLow, Palette.heatMid, t * 2)!
    : Color.lerp(Palette.heatMid, Palette.heatHigh, (t - 0.5) * 2)!;

/// Weekdays across, core hours down, shaded by usual count over the coming 7 days.
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
    final now = DateTime.now();
    final label = archivo(11, color: Palette.muted);

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (var day = 1; day <= 7; day++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _weekdays[day - 1],
                    textAlign: TextAlign.center,
                    style: day == now.weekday ? archivo(11, weight: FontWeight.w700) : label,
                  ),
                ),
              ),
          ],
        ),
        for (var h = fromHour; h < toHour; h++)
          Row(
            children: [
              SizedBox(width: _labelWidth, child: Text(h % 3 == 0 ? '$h:00' : '', style: label)),
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: _cell(day, h, cells[(day, h)], maxMean, isNow: day == now.weekday && h == now.hour),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('mniej osób', style: label),
            const SizedBox(width: 6),
            Container(
              width: 72,
              height: 8,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                gradient: LinearGradient(colors: [Palette.heatLow, Palette.heatMid, Palette.heatHigh]),
              ),
            ),
            const SizedBox(width: 6),
            Text('więcej osób', style: label),
          ],
        ),
      ],
    );
  }

  Widget _cell(int day, int hour, HourPrediction? p, double maxMean, {required bool isNow}) {
    final mean = p?.mean;
    final when = '${_weekdays[day - 1]} $hour:00';
    final message = mean == null
        ? '$when\nbrak danych'
        : '$when\nzwykle ok. ${mean.round()} (${p!.min}–${p.max})\nna podstawie ${weeksGenitive(p.samples)}';

    final color = mean == null
        ? Palette.panel
        : _heat(maxMean <= 0 ? 0 : mean / maxMean);
    const corner = BorderRadius.all(Radius.circular(2));
    final cell = isNow
        // Ink ring with a white gap, visible on light and dark cells alike.
        ? Container(
            height: 20,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: Palette.panel,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: corner,
            ),
            child: ColoredBox(color: color),
          )
        : Container(
            height: 20,
            decoration: BoxDecoration(
              color: color,
              border: mean == null ? Border.all(color: Palette.line) : null,
              borderRadius: corner,
            ),
          );
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Padding(padding: const EdgeInsets.all(1), child: cell),
    );
  }
}
