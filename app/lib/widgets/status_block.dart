import 'package:flutter/material.dart';
import '../models/hour_prediction.dart';
import '../services/data_aggregator.dart';
import '../theme.dart';
import '../utils/plural.dart';

/// "ok. 8 osób", or "pusto" for an empty room.
String countText(double count) {
  final n = count.round();
  return n == 0 ? 'pusto' : 'ok. ${people(n)}';
}

typedef StatusInfo = ({String title, Color color, Color textColor, List<String> captions});

/// What to show for a place: status word, its colors, and the lines under it.
/// [current] null means offline: nothing arrived in the last 15 minutes.
StatusInfo statusInfo(double? current, HourPrediction? prediction) {
  final c = current;
  final p = prediction;
  if (c == null) {
    return (title: 'Brak sygnału', color: Palette.offline, textColor: Palette.ink, captions: const []);
  }
  final comparison = p == null ? null : DataAggregator.compare(c, p);
  if (comparison == null) {
    final count = countText(c);
    return (
      title: count[0].toUpperCase() + count.substring(1),
      color: Palette.learning,
      textColor: Palette.ink,
      captions: const ['jeszcze uczymy się tego miejsca'],
    );
  }
  final range = p!.min == p.max ? '${p.min}' : '${p.min}–${p.max}';
  final captions = [countText(c), 'zwykle $range o tej porze'];
  return switch (comparison) {
    CrowdComparison.quieter =>
      (title: 'Luźniej niż zwykle', color: Palette.quieter, textColor: Palette.ink, captions: captions),
    CrowdComparison.usual => (title: 'Jak zwykle', color: Palette.usual, textColor: Colors.white, captions: captions),
    CrowdComparison.busier =>
      (title: 'Tłoczniej niż zwykle', color: Palette.busier, textColor: Colors.white, captions: captions),
  };
}

/// The large signage block on the details screen: a full-width color band with the
/// status, and the caption lines under it. Sits flush inside a panel, so it has no radius.
class StatusBlock extends StatelessWidget {
  final double? current;
  final HourPrediction? prediction;

  const StatusBlock({super.key, required this.current, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final s = statusInfo(current, prediction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Band(
          info: s,
          offline: current == null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          style: archivo(30, weight: FontWeight.w700, spacing: -0.3),
        ),
        if (s.captions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, line) in s.captions.indexed)
                  Text(
                    line,
                    style: i == 0 && s.captions.length > 1
                        ? archivo(18, weight: FontWeight.w600)
                        : archivo(14, color: Palette.muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact status label that sits on one line with the place name.
class StatusTag extends StatelessWidget {
  final StatusInfo info;
  final bool offline;

  const StatusTag({super.key, required this.info, required this.offline});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: _Band(
          info: info,
          offline: offline,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          style: archivo(14, weight: FontWeight.w700),
        ),
      );
}

/// Status color with its text; fades to a new color when a refresh changes the status.
class _Band extends StatelessWidget {
  final StatusInfo info;
  final bool offline;
  final EdgeInsets padding;
  final TextStyle style;

  const _Band({required this.info, required this.offline, required this.padding, required this.style});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        color: info.color,
        child: CustomPaint(
          painter: offline ? const _Hatch() : null,
          child: Padding(
            padding: padding,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: style.copyWith(color: info.textColor),
              child: Text(info.title),
            ),
          ),
        ),
      );
}

/// Diagonal lines that mark a board as offline, so it never reads as an empty room.
class _Hatch extends CustomPainter {
  const _Hatch();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.panel.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Hatch oldDelegate) => false;
}
