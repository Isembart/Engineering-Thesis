import 'package:flutter/material.dart';
import '../models/hour_prediction.dart';
import 'status_block.dart';

/// Status pill with the usual range beside it, and any [extra] lines (hints, last reading) below.
class CrowdComparisonRow extends StatelessWidget {
  final double? current;
  final HourPrediction? prediction;
  final List<String> extra;

  const CrowdComparisonRow({
    super.key,
    required this.current,
    required this.prediction,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final s = statusInfo(current, prediction);
    final label = s.label;
    final lines = [?s.caption, ...extra];
    const textStyle = TextStyle(color: Colors.black54, fontSize: 13);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (label != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label, style: TextStyle(color: s.color, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              if (lines.isNotEmpty) Expanded(child: Text(lines.first, style: textStyle)),
            ],
          ),
          for (final line in lines.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line, style: textStyle),
            ),
        ],
      ),
    );
  }
}
