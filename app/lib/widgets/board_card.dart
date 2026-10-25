import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/hour_prediction.dart';
import '../services/api_service.dart';
import '../services/data_aggregator.dart';
import '../utils/mac_address_formatter.dart';
import '../screens/details_screen.dart';
import 'crowd_comparison_row.dart';

class BoardCard extends StatefulWidget {
  final Board board;
  final VoidCallback? onBoardUpdated;

  const BoardCard({Key? key, required this.board, this.onBoardUpdated}) : super(key: key);

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  double _currentCrowd = 0;
  HourPrediction? _prediction;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      // Fetch high-resolution data for the current level
      final recentStart = now.subtract(const Duration(minutes: 15));
      final recentRecords = await _apiService.getBoardData(
        widget.board.boardMac,
        start: recentStart,
        end: now,
      );

      final current = DataAggregator.getCurrentCrowdLevel(recentRecords);

      // Optional: without it the card shows only the count.
      final hourStart = DateTime(now.year, now.month, now.day, now.hour);
      final predictions = await _apiService
          .getBoardPrediction(widget.board.boardMac, hourStart, hourStart.add(const Duration(hours: 1)))
          .catchError((_) => <HourPrediction>[]);

      if (mounted) {
        setState(() {
          _currentCrowd = current;
          _prediction = predictions.firstOrNull;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.board.name;
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : MacAddressFormatter.format(widget.board.boardMac);

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(board: widget.board),
          ),
        );
        if (!mounted) return;
        await _loadData();
        if (updated == true) {
          widget.onBoardUpdated?.call();
        }
      },
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
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (widget.board.firmwareVersion != null)
              Text(
                'Firmware v${widget.board.firmwareVersion}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currentCrowd.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 8),
                    child: Text(
                      'Clients (Last 15m)',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            if (!_isLoading)
              CrowdComparisonRow(current: _currentCrowd, prediction: _prediction),
          ],
        ),
      ),
    );
  }
}
