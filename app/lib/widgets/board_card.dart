import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../utils/mac_address_formatter.dart';
import 'crowd_comparison_row.dart';
import 'status_block.dart';

String boardDisplayName(Board board, [String? name]) {
  name ??= board.name;
  return (name != null && name.isNotEmpty) ? name : MacAddressFormatter.format(board.boardMac);
}

/// One place on the home list. Display only: the home screen loads the data.
class BoardCard extends StatelessWidget {
  final Board board;
  /// Null means offline.
  final double? current;
  final HourPrediction? prediction;
  /// Extra lines, e.g. the last reading of an offline board.
  final List<String> extra;
  final VoidCallback onTap;

  const BoardCard({
    super.key,
    required this.board,
    required this.current,
    required this.prediction,
    this.extra = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = current;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                boardDisplayName(board),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              if (board.firmwareVersion != null)
                ValueListenableBuilder<bool>(
                  valueListenable: ApiService.isAdmin,
                  builder: (context, isAdmin, _) => isAdmin
                      ? Text(
                          'Firmware v${board.firmwareVersion}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        )
                      : const SizedBox.shrink(),
                ),
              const SizedBox(height: 12),
              if (count != null)
                Text(
                  countText(count),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              CrowdComparisonRow(current: count, prediction: prediction, extra: extra),
            ],
          ),
        ),
      ),
    );
  }
}
