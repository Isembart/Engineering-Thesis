import 'package:flutter/material.dart';
import '../models/hour_prediction.dart';
import '../services/data_aggregator.dart';

/// "Busier than usual" style label plus the usual count for this hour.
/// Renders nothing when there is no history to compare with.
class CrowdComparisonRow extends StatelessWidget {
  final double current;
  final HourPrediction? prediction;

  const CrowdComparisonRow({super.key, required this.current, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final comparison = p == null ? null : DataAggregator.compare(current, p);
    if (comparison == null) return const SizedBox.shrink();

    final (label, color) = switch (comparison) {
      CrowdComparison.busier => ('Busier than usual', const Color(0xFFEF4444)),
      CrowdComparison.quieter => ('Quieter than usual', const Color(0xFF22C55E)),
      CrowdComparison.usual => ('As usual', Colors.grey.shade600),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Usually ~${p!.mean!.toStringAsFixed(0)} at this hour (${p.min}–${p.max})',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
